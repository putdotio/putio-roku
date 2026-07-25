import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtemp, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import process from "node:process";

const manifestPath = "config/brand-fonts.json";

const fontsOutputDir = "fonts";
// Gitignored, and on the same filesystem as fonts/ so staged moves are atomic renames.
const stagingParentDir = "dist/tmp";
// The extensions this importer owns: what it prunes, and what counts as unlisted. Must
// cover everything checkRokuFontBinaries treats as a font binary, collections included,
// because packaging bundles the whole fonts/ root -- an extension missing here would ship
// unlisted and unverified.
const fontExtensions = [".otf", ".ttf", ".ttc"] as const;

const fontFileNamePattern = /^[a-z0-9]+(?:-[a-z0-9]+)*\.(?:otf|ttf)$/;
const sha256Pattern = /^[0-9a-f]{64}$/;
const commitRefPattern = /^[0-9a-f]{40}$/;

// GitHub's raw contents endpoint tops out well below this; the cap only stops a
// surprise HTML error page from being buffered without bound.
const downloadMaxBytes = 32 * 1024 * 1024;

interface BrandFontFile {
  readonly name: string;
  readonly path: string;
  readonly sha256: string;
}

interface BrandFontManifest {
  readonly source: { readonly repository: string; readonly ref: string };
  readonly files: readonly BrandFontFile[];
}

export interface BrandFontStatus {
  readonly directory: string;
  readonly total: number;
  readonly verified: readonly string[];
  readonly missing: readonly string[];
  readonly stale: readonly string[];
  readonly unlisted: readonly string[];
}

export async function syncBrandFonts(repoRoot: string): Promise<BrandFontStatus> {
  const manifest = await readBrandFontManifest(repoRoot);
  const targetDir = resolve(repoRoot, fontsOutputDir);
  await mkdir(targetDir, { recursive: true });

  // Prune before fetching: the packaged ZIP bundles every font file in this directory,
  // so a face left behind by an older manifest would ship unlisted and unverified.
  for (const entry of await pruneUnlistedFonts(targetDir, manifest.files)) {
    console.log(`  removed unlisted ${entry}`);
  }

  const before = await inspectBrandFonts(repoRoot, manifest);
  const outdated = manifest.files.filter(
    (file) => before.missing.includes(file.name) || before.stale.includes(file.name),
  );

  if (outdated.length === 0) {
    console.log(`Brand fonts already up to date (${manifest.files.length} files).`);
    return before;
  }

  // Stage every download and move the set into place only once all of it verifies, so an
  // interrupted sync cannot leave a mixed old/new set behind. The staging directory lives
  // under the gitignored dist/ tree rather than the system temp dir so the moves are
  // same-filesystem renames; os.tmpdir() can be a different mount (notably on CI), where
  // rename fails with EXDEV.
  const stagingRoot = resolve(repoRoot, stagingParentDir);
  await mkdir(stagingRoot, { recursive: true });
  const stagingDir = await mkdtemp(join(stagingRoot, "brand-fonts-"));
  try {
    for (const file of outdated) {
      await writeFile(join(stagingDir, file.name), downloadVerifiedFont(manifest, file));
    }
    for (const file of outdated) {
      await rename(join(stagingDir, file.name), join(targetDir, file.name));
      console.log(`  synced ${file.name}`);
    }
  } finally {
    await rm(stagingDir, { force: true, recursive: true });
  }

  console.log(`Brand fonts synced (${outdated.length} of ${manifest.files.length} files).`);
  return await inspectBrandFonts(repoRoot, manifest);
}

export async function checkBrandFonts(repoRoot: string): Promise<BrandFontStatus> {
  const status = await inspectBrandFonts(repoRoot);

  // Drift where a present file is wrong, or an extra face would ship, is a hard failure.
  // Faces being absent is a legitimate state: the app falls back to the Roku system font.
  if (status.stale.length > 0 || status.unlisted.length > 0) {
    const details = [
      ...status.stale.map((name) => `  stale checksum: ${name}`),
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

  console.log(`Brand fonts present and verified (${status.total} files).`);
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
  const stale: string[] = [];

  for (const file of manifest.files) {
    const contents = await readFileOrUndefined(join(directory, file.name));
    if (contents === undefined) {
      missing.push(file.name);
    } else if (sha256(contents) === file.sha256) {
      verified.push(file.name);
    } else {
      stale.push(file.name);
    }
  }

  return {
    directory,
    missing,
    stale,
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

  const source = parsed.source;
  if (!isObject(source) || typeof source.repository !== "string" || source.repository === "") {
    throw new Error(`${manifestPath} must pin source.repository as an owner/name string`);
  }
  if (typeof source.ref !== "string" || !commitRefPattern.test(source.ref)) {
    throw new Error(`${manifestPath} must pin source.ref to a full 40-character commit SHA`);
  }

  if (!Array.isArray(parsed.files)) {
    throw new Error(`${manifestPath} must contain a files array`);
  }
  if (parsed.files.length === 0) {
    throw new Error(`${manifestPath} must list at least one font file`);
  }

  const names = new Set<string>();
  const files = parsed.files.map((entry, index) => validateFontFile(entry, index, names));

  return { files, source: { ref: source.ref, repository: source.repository } };
}

function validateFontFile(entry: unknown, index: number, names: Set<string>): BrandFontFile {
  if (!isObject(entry)) {
    throw new Error(`Font at index ${index} must be an object`);
  }

  const keys = Object.keys(entry).sort();
  if (keys.join(",") !== "name,path,sha256") {
    throw new Error(`Font at index ${index} must contain only name, path and sha256`);
  }

  const { name, path, sha256: digest } = entry;
  if (typeof name !== "string" || !fontFileNamePattern.test(name)) {
    throw new Error(`Invalid brand font file name: ${JSON.stringify(name)}`);
  }
  if (typeof path !== "string" || path === "" || path.startsWith("/") || path.includes("..")) {
    throw new Error(`Invalid brand font source path for ${name}: ${JSON.stringify(path)}`);
  }
  if (typeof digest !== "string" || !sha256Pattern.test(digest)) {
    throw new Error(`Invalid brand font sha256 for ${name}: ${JSON.stringify(digest)}`);
  }
  if (names.has(name)) {
    throw new Error(`Duplicate brand font file: ${name}`);
  }

  names.add(name);
  return { name, path, sha256: digest };
}

function downloadVerifiedFont(manifest: BrandFontManifest, file: BrandFontFile): Buffer {
  const endpoint = `repos/${manifest.source.repository}/contents/${file.path}?ref=${manifest.source.ref}`;
  const result = spawnSync("gh", ["api", endpoint, "--header", "Accept: application/vnd.github.raw"], {
    maxBuffer: downloadMaxBytes,
  });

  if (result.error !== undefined) {
    throw new Error(
      `Could not run gh to fetch ${file.name}. Install the GitHub CLI from https://cli.github.com and run gh auth login.`,
      { cause: result.error },
    );
  }
  if (result.status !== 0) {
    throw new Error(
      [
        `gh api failed for ${file.name} (status ${result.status ?? "unknown"}).`,
        `Check that gh is authenticated (gh auth login, or GH_TOKEN in CI) as an account that can read ${manifest.source.repository}.`,
        String(result.stderr).trim(),
      ].join(" "),
    );
  }

  // Verify before the bytes are allowed anywhere near the destination directory.
  const contents = result.stdout;
  const actual = sha256(contents);
  if (actual !== file.sha256) {
    throw new Error(
      `${file.name}: checksum mismatch (expected ${file.sha256}, got ${actual}); refusing to write`,
    );
  }

  return contents;
}


async function listUnlistedFonts(
  directory: string,
  files: readonly BrandFontFile[],
): Promise<readonly string[]> {
  const expected = new Set(files.map((file) => file.name));
  const entries = await readdirOrEmpty(directory);
  return entries.filter((entry) => isFontFile(entry) && !expected.has(entry));
}

async function pruneUnlistedFonts(
  directory: string,
  files: readonly BrandFontFile[],
): Promise<readonly string[]> {
  const unlisted = await listUnlistedFonts(directory, files);
  for (const entry of unlisted) {
    await rm(join(directory, entry), { force: true });
  }

  return unlisted;
}

function isFontFile(entry: string): boolean {
  return fontExtensions.some((extension) => entry.endsWith(extension));
}

function sha256(contents: Buffer): string {
  return createHash("sha256").update(contents).digest("hex");
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
