import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  defaultVisualLabStoryIds,
  selectVisualLabStories,
  visualLabStories,
} from "../../scripts/live-test/visual-capture.ts";

const repoRoot = process.cwd();

function labStoryIdsFromBrightScript(): readonly string[] {
  const labSource = readFileSync(join(repoRoot, "components/lab/Lab.brs"), "utf8");
  return Array.from(labSource.matchAll(/^\s+id: "([^"]+)"/gm), (match) => match[1]);
}

describe("visual Lab capture registry", () => {
  it("matches the BrightScript Lab story registry", () => {
    expect(visualLabStories.map(([storyId]) => storyId)).toEqual(labStoryIdsFromBrightScript());
  });

  it("selects stable AppDialog stories by default", () => {
    expect(selectVisualLabStories([]).map(([storyId]) => storyId)).toEqual([
      ...defaultVisualLabStoryIds,
    ]);
  });

  it("keeps explicit story order for targeted captures", () => {
    expect(
      selectVisualLabStories([
        "list-item-file-loading-focused",
        "list-item-file-watched-focused",
      ]).map(([storyId]) => storyId),
    ).toEqual([
      "list-item-file-loading-focused",
      "list-item-file-watched-focused",
    ]);
  });

  it("rejects unknown Lab stories before touching the device", () => {
    expect(() => selectVisualLabStories(["missing-story"])).toThrow("missing-story");
  });
});
