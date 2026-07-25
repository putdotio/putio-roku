import { join } from "node:path";
import { describe, expect, it } from "vitest";
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

describe("brand font boundary", () => {
  // The licensed faces may live in a working tree but must never enter this public repo's
  // history. verify() runs the authoritative `git ls-files` guard; this pins the ignore
  // rules that keep an accidental `git add fonts/` from ever staging them.
  it("gitignores every font extension the importer owns", () => {
    const gitignore = readRepoFile(".gitignore");

    expect(gitignore).toContain("/fonts/*.otf");
    expect(gitignore).toContain("/fonts/*.ttf");
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
