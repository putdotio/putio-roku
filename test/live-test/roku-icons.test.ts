import { readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { parseIconManifest } from "../../scripts/generate-roku-icons.ts";
import { listRepoFiles, readRepoFile, repoRoot } from "./repo-files.ts";

const manifest = parseIconManifest(JSON.parse(readRepoFile("config/phosphor-icons.json")));
const assetNames = new Set(manifest.icons.map((icon) => icon.asset));
const staticIconReference = /pkg:\/images\/icons\/([A-Za-z0-9_-]+)\.png/g;
// Names assigned as data and turned into `pkg:/images/icons/<name>.png` at runtime:
// `iconName:`/`iconName =` (Home/Settings/Files default), `icon:` (History event map),
// the uppercase-keyed file-type map, and Lab preview rows.
const dynamicIconReference = /(?:iconName|\bicon)\s*[:=]\s*"([a-z][a-z0-9-]*)"/g;
const fileTypeIconReference = /\b[A-Z][A-Z_]+:\s*"([a-z][a-z0-9-]*)"/g;
const labIconReference = /addGenericListItem\([^,]+,\s*"([a-z][a-z0-9-]*)"/g;

describe("Roku Phosphor icon manifest", () => {
  it("validates and pins @phosphor-icons/core", () => {
    expect(manifest.package.name).toBe("@phosphor-icons/core");
    expect(manifest.icons.length).toBeGreaterThan(0);
  });

  it("pins the same Phosphor version as package.json", () => {
    const pkg = JSON.parse(readRepoFile("package.json"));
    expect(pkg.devDependencies["@phosphor-icons/core"]).toBe(manifest.package.version);
  });

  it("rejects malformed manifests", () => {
    expect(() => parseIconManifest({ package: { name: "@phosphor-icons/core", version: "2.1.1" }, icons: "no" }))
      .toThrow("icons array");
    expect(() => parseIconManifest({
      package: { name: "@phosphor-icons/core", version: "2.1.1" },
      icons: [{ asset: "a", name: "x", weight: "regular" }, { asset: "a", name: "y", weight: "fill" }],
    })).toThrow("Duplicate");
    expect(() => parseIconManifest({
      package: { name: "@phosphor-icons/core", version: "2.1.1" },
      icons: [{ asset: "a", name: "x", weight: "heavy" }],
    })).toThrow("weight");
  });

  it("commits exactly the generated asset set", () => {
    const committed = readdirSync(join(repoRoot, "images/icons"))
      .filter((file) => file.endsWith(".png"))
      .map((file) => file.replace(/\.png$/, ""))
      .sort();
    expect(committed).toEqual([...assetNames].sort());
  });

  it("only references icon assets that exist in the manifest", () => {
    const offenders: string[] = [];
    const files = [
      ...listRepoFiles(join(repoRoot, "components")),
      ...listRepoFiles(join(repoRoot, "source")),
    ].filter((file) => /\.(brs|xml)$/i.test(file));

    const check = (file: string, asset: string | undefined) => {
      if (asset !== undefined && !assetNames.has(asset)) {
        offenders.push(`${file}: ${asset}`);
      }
    };

    for (const file of files) {
      const contents = readRepoFile(file);
      // Static URI references, in both BrightScript and XML.
      for (const match of contents.matchAll(staticIconReference)) check(file, match[1]);
      if (!file.endsWith(".brs")) continue;
      // Dynamically-constructed names (data assigned on the screens).
      for (const match of contents.matchAll(dynamicIconReference)) check(file, match[1]);
      for (const match of contents.matchAll(labIconReference)) check(file, match[1]);
      if (file.endsWith("FileListItem.brs")) {
        for (const match of contents.matchAll(fileTypeIconReference)) check(file, match[1]);
      }
    }

    expect(offenders).toEqual([]);
  });
});
