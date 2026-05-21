import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  captureVisualLabStorySequence,
  defaultVisualLabStoryIds,
  selectVisualLabStories,
  type VisualLabCaptureOperations,
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

describe("visual Lab capture sequence", () => {
  it("recovers failed list navigation by relaunching the current story", async () => {
    const actions: string[] = [];
    let shouldFailReturn = true;

    const operations = createVisualLabOperations(actions, {
      returnToStoryList: async () => {
        actions.push("return");
        if (shouldFailReturn) {
          shouldFailReturn = false;
          throw new Error("SceneGraph unavailable");
        }
      },
    });

    await captureVisualLabStorySequence(
      selectVisualLabStories(["app-dialog-empty", "app-dialog-message"]),
      operations,
    );

    expect(actions).toEqual([
      "leave-playback",
      "launch:app-dialog-empty",
      "capture:app-dialog-empty",
      "return",
      "recover:app-dialog-message:SceneGraph unavailable",
      "launch:app-dialog-message",
      "capture:app-dialog-message",
    ]);
  });

  it("restarts after each capture batch and relaunches the next story", async () => {
    const actions: string[] = [];
    const stories = selectVisualLabStories([
      "app-dialog-empty",
      "app-dialog-message",
      "delete-dialog-short",
    ]);

    await captureVisualLabStorySequence(stories, createVisualLabOperations(actions), 2);

    expect(actions).toEqual([
      "leave-playback",
      "launch:app-dialog-empty",
      "capture:app-dialog-empty",
      "return",
      "navigate:0->1:app-dialog-message",
      "open:app-dialog-message",
      "capture:app-dialog-message",
      "restart",
      "launch:delete-dialog-short",
      "capture:delete-dialog-short",
    ]);
  });
});

function createVisualLabOperations(
  actions: string[],
  overrides: Partial<VisualLabCaptureOperations> = {},
): VisualLabCaptureOperations {
  return {
    captureStory: async (storyId) => {
      actions.push(`capture:${storyId}`);
    },
    launchStory: async (storyId) => {
      actions.push(`launch:${storyId}`);
    },
    leaveActivePlaybackSurface: async () => {
      actions.push("leave-playback");
    },
    logRecovery: (storyId, error) => {
      actions.push(`recover:${storyId}:${error instanceof Error ? error.message : String(error)}`);
    },
    navigateStoryList: async (currentStoryIndex, nextStoryIndex, storyId) => {
      actions.push(`navigate:${currentStoryIndex}->${nextStoryIndex}:${storyId}`);
    },
    openFocusedStory: async (storyId) => {
      actions.push(`open:${storyId}`);
    },
    restartSession: async () => {
      actions.push("restart");
    },
    returnToStoryList: async () => {
      actions.push("return");
    },
    ...overrides,
  };
}
