import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { hasVerifiedBrandFonts, verifiedBrandFontRoots } from "../../scripts/package-roku.ts";
import { parseBrandFontManifest } from "../../scripts/sync-brand-fonts.ts";
import { listRepoFiles, readRepoFile, repoRoot } from "./repo-files.ts";

const manifest = parseBrandFontManifest(JSON.parse(readRepoFile("config/brand-fonts.json")));
const manifestNames = new Set(manifest.files.map((file) => file.name));
const fontReference = /pkg:\/fonts\/([A-Za-z0-9_.-]+\.(?:otf|ttf))/g;
const typographyPath = "components/shared/Typography/Typography.brs";
const validRef = "0".repeat(40);

function validFile(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    name: "gt-america-standard-regular.otf",
    path: "public/fonts/gt-america/desktop/otf/gt-america-standard-regular.otf",
    sha256: "a".repeat(64),
    ...overrides,
  };
}

function validManifest(files: readonly unknown[]): Record<string, unknown> {
  return { files, source: { ref: validRef, repository: "putdotio/putio-static" } };
}

describe("brand font manifest", () => {
  it("pins the private source repository at a full commit SHA", () => {
    expect(manifest.source.repository).toBe("putdotio/putio-static");
    expect(manifest.source.ref).toMatch(/^[0-9a-f]{40}$/);
    expect(manifest.files.length).toBeGreaterThan(0);
  });

  it("pins every face to an upstream path and a sha256 digest", () => {
    const offenders = manifest.files.filter(
      (file) =>
        !/^[0-9a-f]{64}$/.test(file.sha256) ||
        !file.path.startsWith("public/fonts/") ||
        !file.path.endsWith(file.name),
    );

    expect(offenders).toEqual([]);
  });

  it("rejects malformed manifests", () => {
    expect(() => parseBrandFontManifest({ files: [validFile()] })).toThrow("source.repository");
    expect(() =>
      parseBrandFontManifest({ files: [validFile()], source: { ref: "abc", repository: "a/b" } }),
    ).toThrow("40-character commit SHA");
    expect(() => parseBrandFontManifest(validManifest([]))).toThrow("at least one font file");
    expect(() => parseBrandFontManifest({ source: { ref: validRef, repository: "a/b" } })).toThrow("files array");
    expect(() => parseBrandFontManifest(validManifest([validFile(), validFile()]))).toThrow("Duplicate");
    expect(() => parseBrandFontManifest(validManifest([validFile({ sha256: "nope" })]))).toThrow("sha256");
    expect(() => parseBrandFontManifest(validManifest([validFile({ name: "GT.woff2" })]))).toThrow("file name");
    expect(() => parseBrandFontManifest(validManifest([validFile({ path: "../etc/passwd" })]))).toThrow("source path");
    expect(() => parseBrandFontManifest(validManifest([{ ...validFile(), extra: 1 }]))).toThrow(
      "only name, path and sha256",
    );
  });
});

describe("brand font availability", () => {
  // Availability must mean "every pinned face present AND matching its digest". A partial or
  // corrupt directory would flip the compiled flag on and leave roles resolving to missing
  // pkg:/fonts URIs, which Roku renders in the system font per label as mixed typography.
  // The fixture mints its own manifest so the digests are real and no repo fonts/ is needed.
  function fixture(faces: Readonly<Record<string, string>>, pinned?: readonly string[]): string {
    const root = mkdtempSync(join(tmpdir(), "putio-roku-fonts-fixture-"));
    const names = pinned ?? Object.keys(faces);
    mkdirSync(join(root, "config"), { recursive: true });
    writeFileSync(
      join(root, "config/brand-fonts.json"),
      JSON.stringify({
        files: names.map((name) => ({
          name,
          path: `public/fonts/gt-america/desktop/otf/${name}`,
          sha256: createHash("sha256").update(`bytes-of-${name}`).digest("hex"),
        })),
        source: { ref: validRef, repository: "putdotio/putio-static" },
      }),
    );

    mkdirSync(join(root, "fonts"), { recursive: true });
    for (const [name, contents] of Object.entries(faces)) {
      writeFileSync(join(root, "fonts", name), contents);
    }

    return root;
  }

  const face = (name: string): string => `bytes-of-${name}`;
  const a = "gt-america-standard-regular.otf";
  const b = "gt-america-standard-medium.otf";

  it("enables the flag only when every pinned face verifies", async () => {
    await expect(hasVerifiedBrandFonts(fixture({ [a]: face(a), [b]: face(b) }))).resolves.toBe(true);
  });

  it("rejects a partial, corrupt or polluted fonts directory", async () => {
    // present but only one of two pinned faces
    await expect(hasVerifiedBrandFonts(fixture({ [a]: face(a) }, [a, b]))).resolves.toBe(false);
    // both present, one with the wrong bytes
    await expect(hasVerifiedBrandFonts(fixture({ [a]: face(a), [b]: "corrupted" }))).resolves.toBe(false);
    // all pinned faces verify, but an unlisted face would ship unverified beside them
    await expect(
      hasVerifiedBrandFonts(fixture({ [a]: face(a), "gt-america-standard-black.otf": "x" }, [a])),
    ).resolves.toBe(false);
  });

  // Package roots are copied recursively, so bundling the fonts/ directory would ship
  // whatever else sits in it while only the pinned faces had been digest-checked.
  it("bundles the pinned faces individually, never the fonts directory", async () => {
    const root = fixture({ [a]: face(a), [b]: face(b) });
    await expect(verifiedBrandFontRoots(root)).resolves.toEqual([`fonts/${a}`, `fonts/${b}`]);

    // A nested file is not reported as unlisted (the scan is one level deep), so the roots
    // themselves have to stay exactly the manifest files or it would ship.
    mkdirSync(join(root, "fonts", "backup"), { recursive: true });
    writeFileSync(join(root, "fonts", "backup", "unlicensed.otf"), "not licensed");
    await expect(verifiedBrandFontRoots(root)).resolves.toEqual([`fonts/${a}`, `fonts/${b}`]);

    // An unlisted face beside them, uppercase included, withdraws the brand face entirely.
    writeFileSync(join(root, "fonts", "EXTRA.OTF"), "stray");
    await expect(verifiedBrandFontRoots(root)).resolves.toEqual([]);
  });

  it("treats a missing fonts directory as unavailable", async () => {
    const root = fixture({ [a]: face(a) });
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
