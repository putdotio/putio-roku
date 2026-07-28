import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { hasVerifiedBrandFonts, verifiedBrandFontRoots } from "../../scripts/package-roku.ts";
import { brandFontRejection, parseBrandFontManifest } from "../../scripts/sync-brand-fonts.ts";
import { listRepoFiles, readRepoFile, repoRoot } from "./repo-files.ts";

const manifest = parseBrandFontManifest(JSON.parse(readRepoFile("config/brand-fonts.json")));
const manifestNames = new Set(manifest.files);
const fontReference = /pkg:\/fonts\/([A-Za-z0-9_.-]+\.(?:otf|ttf))/g;
const typographyPath = "components/shared/Typography/Typography.brs";
const family = "GT America";

function validManifest(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    baseUrl: "https://static.put.io/fonts/gt-america/desktop/otf",
    family,
    files: ["gt-america-standard-regular.otf"],
    ...overrides,
  };
}

// A minimal but structurally real sfnt: correct OTTO version, an in-bounds table directory
// carrying every table the validator requires, and a name table declaring the family. Built
// here rather than read from fonts/ so these tests hold on a fonts-less clone, which is the
// state CI runs in.
function sfnt(
  options: {
    family?: string;
    omit?: readonly string[];
    truncateBy?: number;
    platformId?: number;
    declaredNameLength?: number;
  } = {},
): Buffer {
  const value = Buffer.from(options.family ?? family, "latin1");
  const nameTable = Buffer.alloc(18 + value.length);
  nameTable.writeUInt16BE(0, 0); // format
  nameTable.writeUInt16BE(1, 2); // record count
  nameTable.writeUInt16BE(18, 4); // string storage offset
  nameTable.writeUInt16BE(options.platformId ?? 1, 6); // platform 1 (Macintosh), 3 (Windows)
  nameTable.writeUInt16BE(1, 12); // nameID 1 (family)
  nameTable.writeUInt16BE(options.declaredNameLength ?? value.length, 14);
  value.copy(nameTable, 18);

  const tables: readonly (readonly [string, Buffer])[] = (
    [
      ["CFF ", Buffer.alloc(4)],
      ["cmap", Buffer.alloc(4)],
      ["head", Buffer.alloc(4)],
      ["hhea", Buffer.alloc(4)],
      ["hmtx", Buffer.alloc(4)],
      ["maxp", Buffer.alloc(4)],
      ["name", nameTable],
    ] as const
  ).filter(([tag]) => !(options.omit ?? []).includes(tag));

  const directory = Buffer.alloc(tables.length * 16);
  const body: Buffer[] = [];
  let cursor = 12 + tables.length * 16;
  tables.forEach(([tag, data], index) => {
    directory.write(tag, index * 16, 4, "latin1");
    directory.writeUInt32BE(cursor, index * 16 + 8);
    directory.writeUInt32BE(data.length, index * 16 + 12);
    body.push(data);
    cursor += data.length;
  });

  const header = Buffer.alloc(12);
  header.write("OTTO", 0, 4, "latin1");
  header.writeUInt16BE(tables.length, 4);

  const full = Buffer.concat([header, directory, ...body]);
  return options.truncateBy === undefined ? full : full.subarray(0, full.byteLength - options.truncateBy);
}

describe("brand font manifest", () => {
  it("fetches from an https CDN base and names the expected family", () => {
    expect(manifest.baseUrl).toBe("https://static.put.io/fonts/gt-america/desktop/otf");
    expect(manifest.family).toBe(family);
    expect(manifest.files.length).toBeGreaterThan(0);
  });

  it("rejects malformed manifests", () => {
    expect(() => parseBrandFontManifest(validManifest({ baseUrl: undefined }))).toThrow("baseUrl");
    // Plain HTTP would make the fetch trivially interceptable, and the family check is the
    // only thing standing behind it now that digests are gone.
    expect(() => parseBrandFontManifest(validManifest({ baseUrl: "http://static.put.io/f" }))).toThrow("baseUrl");
    expect(() => parseBrandFontManifest(validManifest({ baseUrl: "https://static.put.io/f/" }))).toThrow("baseUrl");
    expect(() => parseBrandFontManifest(validManifest({ family: "" }))).toThrow("family");
    expect(() => parseBrandFontManifest(validManifest({ files: [] }))).toThrow("at least one font file");
    expect(() => parseBrandFontManifest(validManifest({ files: undefined }))).toThrow("files array");
    expect(() => parseBrandFontManifest(validManifest({ files: ["a.otf", "a.otf"] }))).toThrow("Duplicate");
    expect(() => parseBrandFontManifest(validManifest({ files: ["GT.woff2"] }))).toThrow("file name");
    // A collection holds several faces while Roku's Font.uri takes one, so .ttc may be
    // detected in fonts/ but never listed as a brand face.
    expect(() => parseBrandFontManifest(validManifest({ files: ["gt.ttc"] }))).toThrow("file name");
  });
});

// Digest pinning is gone, so this is what stands between a bad response and a build that
// advertises the brand face while rendering the system font. Every case here is one the
// importer must refuse to write and the availability gate must refuse to enable.
describe("brand font validation", () => {
  it("accepts a real face of the expected family", () => {
    expect(brandFontRejection(sfnt(), family)).toBeUndefined();
    // The Windows-platform record carries a weight suffix, so a prefix match is required.
    expect(brandFontRejection(sfnt({ family: "GT America Rg" }), family)).toBeUndefined();
  });

  it("refuses anything that is not a usable face of that family", () => {
    // A CDN answering 200 with an error page is the failure this replaced digests for.
    expect(brandFontRejection(Buffer.from("<!DOCTYPE html><title>404</title>"), family)).toMatch("not a single");
    expect(brandFontRejection(Buffer.alloc(0), family)).toMatch("too short");
    expect(brandFontRejection(sfnt({ family: "Comic Sans MS" }), family)).toMatch("expected");
    expect(brandFontRejection(sfnt({ omit: ["name"] }), family)).toMatch("missing required name");
    expect(brandFontRejection(sfnt({ omit: ["CFF "] }), family)).toMatch("missing required CFF");
  });

  // A truncated download is the case a digest caught for free and a header check does not:
  // the name table sits early enough to read cleanly while the outlines are gone, so magic
  // and family both pass. Table bounds are what close it.
  it("refuses a truncated face, down to a single lost byte", () => {
    expect(brandFontRejection(sfnt({ truncateBy: 1 }), family)).toMatch("truncated");
    expect(brandFontRejection(sfnt({ truncateBy: 8 }), family)).toMatch("truncated");
  });

  // A malformed face must be classified, never thrown on. Decoding a UTF-16 name record with
  // an odd byte count throws RangeError out of Buffer.swap16, which would abort packaging and
  // verify instead of letting the build fall back to the system font.
  it("classifies a malformed name record instead of throwing", () => {
    const malformed = sfnt({ declaredNameLength: 9, platformId: 3 });

    expect(() => brandFontRejection(malformed, family)).not.toThrow();
    expect(brandFontRejection(malformed, family)).toMatch("no readable family name");
  });
});

describe("brand font availability", () => {
  // Availability must mean "every listed face present AND a real face of the family". A
  // partial or corrupt directory would flip the compiled flag on and leave roles resolving to
  // missing pkg:/fonts URIs, which Roku renders in the system font per label as mixed
  // typography. The fixture mints its own manifest so no repo fonts/ is needed.
  function fixture(faces: Readonly<Record<string, Buffer>>, listed?: readonly string[]): string {
    const root = mkdtempSync(join(tmpdir(), "putio-roku-fonts-fixture-"));
    mkdirSync(join(root, "config"), { recursive: true });
    writeFileSync(
      join(root, "config/brand-fonts.json"),
      JSON.stringify(validManifest({ files: listed ?? Object.keys(faces) })),
    );

    mkdirSync(join(root, "fonts"), { recursive: true });
    for (const [name, contents] of Object.entries(faces)) {
      writeFileSync(join(root, "fonts", name), contents);
    }

    return root;
  }

  const a = "gt-america-standard-regular.otf";
  const b = "gt-america-standard-medium.otf";

  it("enables the flag only when every listed face validates", async () => {
    await expect(hasVerifiedBrandFonts(fixture({ [a]: sfnt(), [b]: sfnt() }))).resolves.toBe(true);
  });

  it("rejects a partial, corrupt or polluted fonts directory", async () => {
    // present but only one of two listed faces
    await expect(hasVerifiedBrandFonts(fixture({ [a]: sfnt() }, [a, b]))).resolves.toBe(false);
    // both present, one holding a CDN error page
    await expect(
      hasVerifiedBrandFonts(fixture({ [a]: sfnt(), [b]: Buffer.from("<html>404</html>") })),
    ).resolves.toBe(false);
    // both present, one truncated mid-download
    await expect(hasVerifiedBrandFonts(fixture({ [a]: sfnt(), [b]: sfnt({ truncateBy: 1 }) }))).resolves.toBe(false);
    // both present, one is a different typeface entirely
    await expect(
      hasVerifiedBrandFonts(fixture({ [a]: sfnt(), [b]: sfnt({ family: "Helvetica" }) })),
    ).resolves.toBe(false);
    // all listed faces validate, but an unlisted face would ship unvalidated beside them
    await expect(
      hasVerifiedBrandFonts(fixture({ [a]: sfnt(), "gt-america-standard-black.otf": sfnt() }, [a])),
    ).resolves.toBe(false);
  });

  // Package roots are copied recursively, so bundling the fonts/ directory would ship
  // whatever else sits in it while only the listed faces had been validated.
  it("bundles the listed faces individually, never the fonts directory", async () => {
    const root = fixture({ [a]: sfnt(), [b]: sfnt() });
    await expect(verifiedBrandFontRoots(root)).resolves.toEqual([`fonts/${a}`, `fonts/${b}`]);

    // A nested file is not reported as unlisted (the scan is one level deep), so the roots
    // themselves have to stay exactly the manifest files or it would ship.
    mkdirSync(join(root, "fonts", "backup"), { recursive: true });
    writeFileSync(join(root, "fonts", "backup", "unlicensed.otf"), "not licensed");
    await expect(verifiedBrandFontRoots(root)).resolves.toEqual([`fonts/${a}`, `fonts/${b}`]);

    // An unlisted face beside them, uppercase included, withdraws the brand face entirely.
    writeFileSync(join(root, "fonts", "EXTRA.OTF"), sfnt());
    await expect(verifiedBrandFontRoots(root)).resolves.toEqual([]);
  });

  it("treats a missing fonts directory as unavailable", async () => {
    const root = fixture({ [a]: sfnt() });
    rmSync(join(root, "fonts"), { recursive: true, force: true });

    await expect(hasVerifiedBrandFonts(root)).resolves.toBe(false);
  });
});

describe("brand font boundary", () => {
  // The licensed faces may live in a working tree but must never enter this public repo's
  // history. verify() runs the authoritative `git ls-files` guard; this pins the ignore
  // rules that keep an accidental `git add fonts/` from ever staging them.
  it("gitignores every font extension the importer owns", () => {
    const gitignore = readRepoFile(".gitignore");

    // Must cover every extension checkRokuFontBinaries fails on, so the ignore rules and
    // the verify gate agree on what "a font binary" is.
    expect(gitignore).toContain("/fonts/*.otf");
    expect(gitignore).toContain("/fonts/*.ttf");
    expect(gitignore).toContain("/fonts/*.ttc");
  });

  it("has the importer own every extension the verify gate rejects", () => {
    // An extension the importer does not prune or count as unlisted sits in fonts/
    // unnoticed and unverified. Keep it in step with .gitignore and checkRokuFontBinaries.
    const importer = readRepoFile("scripts/sync-brand-fonts.ts");
    const declared = /const fontExtensions = \[([^\]]+)\]/.exec(importer)?.[1] ?? "";

    for (const extension of [".otf", ".ttf", ".ttc"]) {
      expect(declared, `fontExtensions must include ${extension}`).toContain(extension);
    }
  });

  it("carries synced faces into agent worktrees", () => {
    expect(readRepoFile(".worktreeinclude")).toContain("/fonts");
  });

  it("compiles font availability into BuildConfig for the runtime fallback", () => {
    expect(readRepoFile("source/BuildConfig.brs")).toContain("function buildConfigBrandFontsAvailable() as boolean");
  });
});

describe("brand font references", () => {
  it("only references faces the manifest pins", () => {
    const offenders: string[] = [];

    for (const directory of ["components", "source"]) {
      for (const file of listRepoFiles(join(repoRoot, directory))) {
        for (const [, name] of readRepoFile(file).matchAll(fontReference)) {
          if (!manifestNames.has(name)) {
            offenders.push(`${file}: ${name}`);
          }
        }
      }
    }

    expect(offenders).toEqual([]);
  });

  // The audit above only sees literal URIs, and the shipping path has none: brandFontUri
  // builds them by concatenation, so a repin to renamed faces would leave every component
  // requesting names the manifest no longer contains -- a whole-app silent fallback with the
  // availability flag still true. Compose the URI the way the runtime does and check it.
  it("resolves every role through brandFontUri to a pinned face", () => {
    const typography = readRepoFile(typographyPath);
    const shape = /return "(pkg:\/fonts\/[^"]*)" \+ face \+ "(\.[A-Za-z]+)"/.exec(typography);

    expect(shape, "brandFontUri no longer composes prefix + face + extension; update this audit").not.toBeNull();
    const [, prefix, extension] = shape ?? [];
    const faces = new Set(Array.from(typography.matchAll(/face: "(\w+)"/g), (match) => match[1]));

    expect(faces.size).toBeGreaterThan(0);
    const offenders = Array.from(faces)
      .map((face) => `${prefix}${face}${extension}`.replace("pkg:/fonts/", ""))
      .filter((name) => !manifestNames.has(name));

    expect(offenders).toEqual([]);
  });

  // Unknown roles resolve to body silently, and the XML font attributes that used to pin
  // these labels are gone, so a typo would leave a label on the wrong role with no signal.
  it("only applies roles the scale defines", () => {
    const roles = new Set(
      Array.from(readRepoFile(typographyPath).matchAll(/^\s{8}(\w+): \{ face:/gm), (match) => match[1]),
    );
    const offenders: string[] = [];

    for (const file of listRepoFiles(join(repoRoot, "components"))) {
      for (const [, role] of readRepoFile(file).matchAll(/applyTypography\([^,]+,\s*"(\w+)"\)/g)) {
        if (!roles.has(role)) {
          offenders.push(`${file}: ${role}`);
        }
      }
    }

    expect(offenders).toEqual([]);
  });
});

describe("type scale", () => {
  const typography = readRepoFile(typographyPath);

  it("defines every role with a size and a system fallback", () => {
    const roles = Array.from(
      typography.matchAll(/^\s{8}(\w+): \{ face: "(\w+)", size: (\d+), system: "(font:\w+)" \}/gm),
      ([, role, face, size, system]) => ({ face, role, size: Number(size), system }),
    );

    expect(roles.map((entry) => entry.role)).toEqual(["h1", "h2", "body", "small", "label", "caption"]);
    expect(roles.every((entry) => ["regular", "medium", "bold"].includes(entry.face))).toBe(true);
    // Sizes are measured against the built-ins they replace and must stay on the 3px
    // autoscale grid so they land on whole pixels when Roku downscales FHD to 720p.
    expect(roles.every((entry) => entry.size % 3 === 0)).toBe(true);
    expect(new Set(roles.map((entry) => entry.system)).size).toBe(roles.length);
  });

  // The completeness proof for the migration: type is applied through the scale, not
  // scattered across markup. Mirrors the color-literal audit in roku-design-usage.test.ts.
  it("keeps built-in font literals out of product components", () => {
    const offenders: string[] = [];

    for (const file of listRepoFiles(join(repoRoot, "components"))) {
      // components/lab is a development-only harness excluded from production builds; its
      // typography story renders the built-ins deliberately to A/B them against GT America.
      if (file === typographyPath || file.startsWith("components/lab/")) {
        continue;
      }

      const source = readRepoFile(file).replace(/<!--[\s\S]*?-->/g, "");
      for (const [literal] of source.matchAll(/font:\w+SystemFont/g)) {
        offenders.push(`${file}: ${literal}`);
      }
    }

    expect(offenders).toEqual([]);
  });
});
