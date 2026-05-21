import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const repoRoot = fileURLToPath(new URL("../..", import.meta.url));
const componentsRoot = join(repoRoot, "components");

function readRepoFile(path: string): string {
  return readFileSync(join(repoRoot, path), "utf8");
}

function listFiles(dir: string, suffix: string): string[] {
  const entries = readdirSync(dir);
  const files: string[] = [];

  for (const entry of entries) {
    const absolutePath = join(dir, entry);
    const stat = statSync(absolutePath);

    if (stat.isDirectory()) {
      files.push(...listFiles(absolutePath, suffix));
    } else if (entry.endsWith(suffix)) {
      files.push(relative(repoRoot, absolutePath));
    }
  }

  return files;
}

describe("Roku UI metrics", () => {
  it("keeps component XML free of duplicate tag attributes", () => {
    const xmlFiles = listFiles(componentsRoot, ".xml");

    for (const filePath of xmlFiles) {
      const xml = readRepoFile(filePath);
      const tags = xml.matchAll(/<[^!?/][^>]*>/g);

      for (const tag of tags) {
        const seenAttributes = new Set<string>();
        const attributes = tag[0].matchAll(/\s([A-Za-z_:][\w:.-]*)\s*=/g);

        for (const attribute of attributes) {
          const attributeName = attribute[1];

          expect(
            seenAttributes.has(attributeName),
            `${filePath} has duplicate "${attributeName}" in ${tag[0]}`,
          ).toBe(false);
          seenAttributes.add(attributeName);
        }
      }
    }
  });

  it("keeps DialogStyle consumers wired to the shared FHD metrics helper", () => {
    const dialogStyleXmlFiles = listFiles(componentsRoot, ".xml").filter((filePath) =>
      readRepoFile(filePath).includes("DialogStyle/DialogStyle.brs"),
    );

    expect(dialogStyleXmlFiles).not.toHaveLength(0);

    for (const filePath of dialogStyleXmlFiles) {
      const xml = readRepoFile(filePath);
      const uiMetricsIndex = xml.indexOf("UiMetrics/UiMetrics.brs");
      const dialogStyleIndex = xml.indexOf("DialogStyle/DialogStyle.brs");

      expect(uiMetricsIndex, `${filePath} should import UiMetrics`).toBeGreaterThanOrEqual(0);
      expect(uiMetricsIndex, `${filePath} should import UiMetrics before DialogStyle`).toBeLessThan(dialogStyleIndex);
    }
  });

  it("keeps primary list rows on the FHD-to-HD grid", () => {
    expect(readRepoFile("components/shared/UiMetrics/UiMetrics.brs")).toContain("return 1920");
    expect(readRepoFile("components/shared/UiMetrics/UiMetrics.brs")).toContain("return 1080");
    expect(readRepoFile("components/shared/UiMetrics/UiMetrics.brs")).toContain("return 3");

    const listDefaults = [
      "components/shared/ListItem/ListItemData.xml",
      "components/screens/Files/FileListItemData.xml",
      "components/screens/History/HistoryListItemData.xml",
    ];

    for (const filePath of listDefaults) {
      expect(readRepoFile(filePath), `${filePath} should use a grid-safe row width`).toContain('value="1716"');
    }
  });

  it("keeps shared dialog chrome on grid-safe borders", () => {
    const dialogXmlFiles = [
      "components/shared/AppDialog/AppDialog.xml",
      "components/shared/DeleteFileDialog/DeleteFileDialog.xml",
      "components/shared/TrackMenu/TrackMenu.xml",
      "components/shared/ContinueWatchingPrompt/ContinueWatchingPrompt.xml",
      "components/shared/VideoConversionStatus/VideoConversionStatus.xml",
    ];

    for (const filePath of dialogXmlFiles) {
      const xml = readRepoFile(filePath);

      expect(xml, `${filePath} should avoid 1px dialog borders`).not.toMatch(/\b(?:width|height)="1"/);
    }
  });
});
