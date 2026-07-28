import { mkdtemp, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import process from "node:process";

const manifestPath = "config/brand-fonts.json";

const fontsOutputDir = "fonts";
// Gitignored, and on the same filesystem as fonts/ so staged moves are atomic renames.
const stagingParentDir = "dist/tmp";
// The next two do different jobs and are deliberately not the same list.
//
// fontExtensions is what the importer owns inside fonts/: pruned, and counted as unlisted.
// It has to cover everything checkRokuFontBinaries (scripts/roku-task/build.ts) rejects,
// collections included, so a stray face can never sit in fonts/ unnoticed.
const fontExtensions = [".otf", ".ttf", ".ttc"] as const;

// fontFileNamePattern is what a manifest entry may name, and is narrower on purpose. A .ttc
// is a font collection while Roku's Font.uri takes a single face, so a collection is
// something to detect and clean up, never something to list as a brand face.
const fontFileNamePattern = /^[a-z0-9]+(?:-[a-z0-9]+)*\.(?:otf|ttf)$/;

// A ceiling on what a single response may buffer. Well above these faces (~200KB each) and
// far below anything that would exhaust memory, so it bounds a surprise error page or a
// misrouted large object without truncating a real font.
const downloadMaxBytes = 32 * 1024 * 1024;

// Accepted sfnt version tags. OTTO is CFF-based OpenType, which is what GT America ships as;
// 0x00010000 and "true" are TrueType, accepted because the manifest may name a .ttf. A
// collection tag ("ttcf") is deliberately absent -- Roku's Font.uri takes a single face.
const sfntVersions = new Set([0x4f54544f, 0x00010000, 0x74727565]);

interface BrandFontManifest {
  readonly baseUrl: string;
  readonly family: string;
  readonly files: readonly string[];
}

export interface BrandFontStatus {
  readonly directory: string;
  readonly family: string;
  readonly total: number;
  readonly verified: readonly string[];
  readonly missing: readonly string[];
  readonly invalid: readonly string[];
  readonly unlisted: readonly string[];
}

export async function syncBrandFonts(repoRoot: string): Promise<BrandFontStatus> {
  const manifest = await readBrandFontManifest(repoRoot);
  const targetDir = resolve(repoRoot, fontsOutputDir);
  await mkdir(targetDir, { recursive: true });

  // Prune before fetching: a face left behind by an older manifest counts as unlisted,
  // which withdraws the brand face from every build until someone notices.
  for (const entry of await pruneUnlistedFonts(targetDir, manifest.files)) {
    console.log(`  removed unlisted ${entry}`);
  }

  const before = await inspectBrandFonts(repoRoot, manifest);
  const outdated = manifest.files.filter(
    (name) => before.missing.includes(name) || before.invalid.includes(name),
  );

  if (outdated.length === 0) {
    console.log(`Brand fonts already present (${manifest.files.length} files).`);
    return before;
  }

  // Download and validate every outdated face before moving any of them, so a failed or
  // rejected download leaves fonts/ untouched. The staging directory lives under the
  // gitignored dist/ tree rather than the system temp dir so the moves are same-filesystem
  // renames; os.tmpdir() can be a different mount (notably on CI), where rename fails with
  // EXDEV. An interrupt between the renames themselves can still leave a partial set -- the
  // validity check on the next run reports it, and availability stays off until it is fixed.
  const stagingRoot = resolve(repoRoot, stagingParentDir);
  await mkdir(stagingRoot, { recursive: true });
  const stagingDir = await mkdtemp(join(stagingRoot, "brand-fonts-"));
  try {
    for (const name of outdated) {
      await writeFile(join(stagingDir, name), await downloadBrandFont(manifest, name));
    }
    for (const name of outdated) {
      await rename(join(stagingDir, name), join(targetDir, name));
      console.log(`  synced ${name}`);
    }
  } finally {
    await rm(stagingDir, { force: true, recursive: true });
  }

  console.log(`Brand fonts synced (${outdated.length} of ${manifest.files.length} files).`);
  return await inspectBrandFonts(repoRoot, manifest);
}

export async function checkBrandFonts(repoRoot: string): Promise<BrandFontStatus> {
  const status = await inspectBrandFonts(repoRoot);

  // Drift where a present file is not the face it claims to be, or an extra face would
  // ship, is a hard failure. Faces being absent is a legitimate state: the app falls back
  // to the Roku system font.
  if (status.invalid.length > 0 || status.unlisted.length > 0) {
    const details = [
      ...status.invalid.map((name) => `  not a usable ${status.family} face: ${name}`),
      ...status.unlisted.map((name) => `  unlisted: ${name}`),
    ];
    throw new Error(
      [`${fontsOutputDir}/ does not match ${manifestPath}; run pnpm roku fonts-setup:`, ...details].join("\n"),
    );
  }

  if (status.missing.length > 0) {
    console.log(
      `Brand fonts not synced (optional): ${status.missing.length} of ${status.total} files absent; run pnpm roku fonts-setup to fetch them.`,
    );
    return status;
  }

  console.log(`Brand fonts present and valid (${status.total} files).`);
  return status;
}

export async function inspectBrandFonts(
  repoRoot: string,
  preloaded?: BrandFontManifest,
): Promise<BrandFontStatus> {
  const manifest = preloaded ?? (await readBrandFontManifest(repoRoot));
  const directory = resolve(repoRoot, fontsOutputDir);

  const verified: string[] = [];
  const missing: string[] = [];
  const invalid: string[] = [];

  for (const name of manifest.files) {
    const contents = await readFileOrUndefined(join(directory, name));
    if (contents === undefined) {
      missing.push(name);
    } else if (brandFontRejection(contents, manifest.family) === undefined) {
      verified.push(name);
    } else {
      invalid.push(name);
    }
  }

  return {
    directory,
    family: manifest.family,
    invalid,
    missing,
    total: manifest.files.length,
    unlisted: await listUnlistedFonts(directory, manifest.files),
    verified,
  };
}

export async function readBrandFontManifest(repoRoot: string): Promise<BrandFontManifest> {
  const path = resolve(repoRoot, manifestPath);
  return parseBrandFontManifest(JSON.parse(await readFile(path, "utf8")));
}

export function parseBrandFontManifest(parsed: unknown): BrandFontManifest {
  if (!isObject(parsed)) {
    throw new Error(`Expected an object in ${manifestPath}`);
  }

  const { baseUrl, family } = parsed;
  if (typeof baseUrl !== "string" || !baseUrl.startsWith("https://") || baseUrl.endsWith("/")) {
    throw new Error(
      `${manifestPath} must set baseUrl to an https URL with no trailing slash: ${JSON.stringify(baseUrl)}`,
    );
  }
  if (typeof family !== "string" || family === "") {
    throw new Error(`${manifestPath} must name the expected font family`);
  }

  if (!Array.isArray(parsed.files)) {
    throw new Error(`${manifestPath} must contain a files array`);
  }
  if (parsed.files.length === 0) {
    throw new Error(`${manifestPath} must list at least one font file`);
  }

  const names = new Set<string>();
  for (const name of parsed.files) {
    if (typeof name !== "string" || !fontFileNamePattern.test(name)) {
      throw new Error(`Invalid brand font file name: ${JSON.stringify(name)}`);
    }
    if (names.has(name)) {
      throw new Error(`Duplicate brand font file: ${name}`);
    }

    names.add(name);
  }

  return { baseUrl, family, files: [...names] };
}

async function downloadBrandFont(manifest: BrandFontManifest, name: string): Promise<Buffer> {
  const url = `${manifest.baseUrl}/${name}`;

  let response: Response;
  try {
    response = await fetch(url);
  } catch (error) {
    throw new Error(`Could not reach ${url}. Check your network connection.`, { cause: error });
  }

  if (!response.ok) {
    throw new Error(
      `${url} returned HTTP ${response.status} ${response.statusText}. Check that the face is still published at ${manifest.baseUrl}.`,
    );
  }

  const contents = Buffer.from(await response.arrayBuffer());
  if (contents.byteLength > downloadMaxBytes) {
    throw new Error(`${url} returned ${contents.byteLength} bytes, above the ${downloadMaxBytes} ceiling`);
  }

  // Validate before the bytes are allowed anywhere near the destination directory. A CDN can
  // answer 200 with an error page or a redirect body, and writing that to fonts/ would leave
  // Roku silently falling back to the system font for the roles using this face -- mixed
  // typography on device, with the availability flag still on.
  const rejection = brandFontRejection(contents, manifest.family);
  if (rejection !== undefined) {
    throw new Error(`${url}: ${rejection}; refusing to write`);
  }

  return contents;
}

// Returns a reason string when the bytes are not a usable face of the expected family, or
// undefined when they are. This is what replaced digest pinning: the faces are fetched from
// put.io's own CDN over TLS, so the job here is catching a wrong or non-font response rather
// than defending against tampering.
export function brandFontRejection(contents: Buffer, family: string): string | undefined {
  if (contents.byteLength < 12) {
    return `only ${contents.byteLength} bytes, too short to be a font`;
  }

  const version = contents.readUInt32BE(0);
  if (!sfntVersions.has(version)) {
    return `not a single OpenType/TrueType face (sfnt version 0x${version.toString(16).padStart(8, "0")})`;
  }

  const tables = readTableDirectory(contents);
  if (tables === undefined) {
    return "its table directory runs past the end of the file";
  }

  // Every table must lie inside the file. This is what catches a truncated download: the
  // name table often sits early enough to read cleanly while the glyph outlines are gone,
  // so magic and family alone would happily accept a half-downloaded face.
  const clipped = [...tables].filter(([, table]) => table.offset + table.length > contents.byteLength);
  if (clipped.length > 0) {
    return `truncated: ${clipped.map(([tag]) => tag.trim()).join(", ")} run past the end of the file`;
  }

  // A face Roku can actually render needs its metrics and character map, plus outlines in
  // whichever flavour the sfnt version promised.
  const required = ["cmap", "head", "hhea", "hmtx", "maxp", "name", ...(version === 0x4f54544f ? ["CFF "] : ["glyf", "loca"])];
  const absent = required.filter((tag) => !tables.has(tag));
  if (absent.length > 0) {
    return `missing required ${absent.map((tag) => tag.trim()).join(", ")} table${absent.length > 1 ? "s" : ""}`;
  }

  const families = readFontFamilies(contents, tables);
  if (families.length === 0) {
    return "no readable family name in its name table";
  }
  // The Windows-platform family record carries the weight suffix ("GT America Rg") while the
  // typographic family record is clean ("GT America"), so match on the prefix.
  if (!families.some((candidate) => candidate.startsWith(family))) {
    return `family is ${families.map((name) => JSON.stringify(name)).join(" / ")}, expected ${JSON.stringify(family)}`;
  }

  return undefined;
}

interface SfntTable {
  readonly offset: number;
  readonly length: number;
}

// Reads the sfnt table directory, or undefined when the directory itself is clipped.
function readTableDirectory(contents: Buffer): Map<string, SfntTable> | undefined {
  const tableCount = contents.readUInt16BE(4);
  if (12 + tableCount * 16 > contents.byteLength) {
    return undefined;
  }

  const tables = new Map<string, SfntTable>();
  for (let index = 0; index < tableCount; index += 1) {
    const record = 12 + index * 16;
    tables.set(contents.toString("latin1", record, record + 4), {
      length: contents.readUInt32BE(record + 12),
      offset: contents.readUInt32BE(record + 8),
    });
  }

  return tables;
}

// Reads the sfnt name table and returns every family candidate it holds: nameID 16
// (typographic family) and nameID 1 (family).
function readFontFamilies(contents: Buffer, tables: Map<string, SfntTable>): readonly string[] {
  const nameTableOffset = tables.get("name")?.offset;
  if (nameTableOffset === undefined || nameTableOffset + 6 > contents.byteLength) {
    return [];
  }

  const recordCount = contents.readUInt16BE(nameTableOffset + 2);
  const storageOffset = nameTableOffset + contents.readUInt16BE(nameTableOffset + 4);
  const families: string[] = [];

  for (let index = 0; index < recordCount; index += 1) {
    const record = nameTableOffset + 6 + index * 12;
    if (record + 12 > contents.byteLength) {
      break;
    }

    const nameId = contents.readUInt16BE(record + 6);
    if (nameId !== 1 && nameId !== 16) {
      continue;
    }

    const length = contents.readUInt16BE(record + 8);
    const start = storageOffset + contents.readUInt16BE(record + 10);
    if (start + length > contents.byteLength) {
      continue;
    }

    // Platform 3 is Windows, whose name strings are UTF-16BE; platform 1 is Macintosh Roman.
    const raw = contents.subarray(start, start + length);
    const value = contents.readUInt16BE(record) === 3 ? decodeUtf16Be(raw) : raw.toString("latin1");
    if (value !== "") {
      families.push(value);
    }
  }

  return families;
}

function decodeUtf16Be(raw: Buffer): string {
  const swapped = Buffer.from(raw);
  swapped.swap16();
  return swapped.toString("utf16le");
}

async function listUnlistedFonts(
  directory: string,
  files: readonly string[],
): Promise<readonly string[]> {
  const expected = new Set(files);
  const entries = await readdirOrEmpty(directory);
  return entries.filter((entry) => isFontFile(entry) && !expected.has(entry));
}

async function pruneUnlistedFonts(
  directory: string,
  files: readonly string[],
): Promise<readonly string[]> {
  const unlisted = await listUnlistedFonts(directory, files);
  for (const entry of unlisted) {
    await rm(join(directory, entry), { force: true });
  }

  return unlisted;
}

function isFontFile(entry: string): boolean {
  // Case-insensitive so a hand-dropped EXTRA.OTF is reported as unlisted rather than
  // sitting in fonts/ unnoticed.
  const name = entry.toLowerCase();
  return fontExtensions.some((extension) => name.endsWith(extension));
}

async function readFileOrUndefined(path: string): Promise<Buffer | undefined> {
  try {
    return await readFile(path);
  } catch (error) {
    if (isMissingEntry(error)) {
      return undefined;
    }

    throw error;
  }
}

async function readdirOrEmpty(directory: string): Promise<readonly string[]> {
  try {
    return await readdir(directory);
  } catch (error) {
    if (isMissingEntry(error)) {
      return [];
    }

    throw error;
  }
}

function isMissingEntry(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function main(): Promise<void> {
  if (process.argv.includes("--check")) {
    await checkBrandFonts(process.cwd());
    return;
  }

  await syncBrandFonts(process.cwd());
}

if (process.argv[1] !== undefined && process.argv[1].endsWith("sync-brand-fonts.ts")) {
  await main();
}
