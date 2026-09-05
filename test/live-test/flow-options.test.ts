import { afterEach, describe, expect, it, vi } from "vitest";
import {
  appFlowOptionsFromArgs,
  emptyStringAsUndefined,
  startFromChoiceFromArg,
} from "../../scripts/live-test/flow-options.ts";

describe("live-test flow options", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("reads image and history fixtures from environment", () => {
    vi.stubEnv("PUTIO_CLI_PROFILE", "fixture-profile");
    vi.stubEnv("IMAGE_CONTENT_ID", "image-123");
    vi.stubEnv("FILES_FOLDER_NAME", "Fixture folder");
    vi.stubEnv("FILES_FOLDER_INDEX", "2");
    vi.stubEnv("HISTORY_EXPECTED_TEXT", "transfer_completed");

    expect(appFlowOptionsFromArgs(["video-123", "audio-123", "subtitle-123"])).toMatchObject({
      profile: "fixture-profile",
      playbackContentId: "video-123",
      imageContentId: "image-123",
      filesFolderName: "Fixture folder",
      filesFolderIndex: 2,
      audioContentId: "audio-123",
      subtitleContentId: "subtitle-123",
      historyExpectedText: "transfer_completed",
      mediaType: "movie",
      startFromChoice: "continue",
    });
  });

  it.each(["-1", "1.5", "NaN", "Infinity", "9007199254740992"])("rejects invalid folder index %s", (value) => {
    vi.stubEnv("FILES_FOLDER_INDEX", value);
    expect(() => appFlowOptionsFromArgs([])).toThrow("FILES_FOLDER_INDEX");
  });

  it("supports beginning playback starts", () => {
    expect(startFromChoiceFromArg("beginning")).toBe("beginning");
  });

  it("rejects unknown playback starts", () => {
    expect(() => startFromChoiceFromArg("later")).toThrow("start-from choice");
  });

  it("normalizes empty strings to undefined", () => {
    expect(emptyStringAsUndefined("   ")).toBeUndefined();
    expect(emptyStringAsUndefined("value")).toBe("value");
  });
});
