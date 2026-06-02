import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { listRepoFiles, readRepoFile, repoRoot } from "./repo-files.ts";

const appColorLiteralPattern = /#[0-9A-Fa-f]{3,8}|0x[0-9A-Fa-f]{6,8}|rgba?\([^)]*\)|hsla?\([^)]*\)/g;

describe("Roku design token usage", () => {
  it("loads DesignTokens before DialogStyle wherever DialogStyle is used", () => {
    const xmlFiles = listRepoFiles(join(repoRoot, "components"), ".xml");
    const dialogStyleXmlFiles = xmlFiles.filter((filePath) =>
      readRepoFile(filePath).includes("DialogStyle/DialogStyle.brs"),
    );

    expect(dialogStyleXmlFiles).not.toHaveLength(0);

    for (const filePath of dialogStyleXmlFiles) {
      const xml = readRepoFile(filePath);
      const designTokensIndex = xml.indexOf("source/DesignTokens.brs");
      const dialogStyleIndex = xml.indexOf("DialogStyle/DialogStyle.brs");

      expect(designTokensIndex, `${filePath} should import DesignTokens`).toBeGreaterThanOrEqual(0);
      expect(designTokensIndex, `${filePath} should import DesignTokens before DialogStyle`).toBeLessThan(dialogStyleIndex);
    }
  });

  it("keeps app color literals isolated to the generated token module", () => {
    const offenders: string[] = [];
    const allowedFiles = new Set(["source/DesignTokens.brs"]);
    const appFiles = [
      ...listRepoFiles(join(repoRoot, "source")),
      ...listRepoFiles(join(repoRoot, "components")),
    ];

    for (const filePath of appFiles) {
      if (!/\.(brs|xml)$/i.test(filePath) || allowedFiles.has(filePath)) {
        continue;
      }

      const matches = readRepoFile(filePath).match(appColorLiteralPattern);
      if (matches !== null) {
        offenders.push(`${filePath}: ${matches.join(", ")}`);
      }
    }

    expect(offenders).toEqual([]);
  });
});
