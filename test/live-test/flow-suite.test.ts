import { describe, expect, it } from "vitest";
import {
  appFlowSmokeSuite,
  fullAppFlowSuite,
  parseFlowId,
  parseFlowList,
} from "../../scripts/live-test/flow-suite.ts";

describe("live-test flow suites", () => {
  it("keeps the full suite as smoke plus media and auth cleanup flows", () => {
    expect(fullAppFlowSuite).toEqual([
      ...appFlowSmokeSuite,
      "playback",
      "image",
      "tracks",
      "logout",
      "auth",
    ]);
  });

  it("accepts every flow used by the full suite", () => {
    expect(fullAppFlowSuite.map(parseFlowId)).toEqual(fullAppFlowSuite);
  });

  it("parses custom comma-separated flow lists", () => {
    expect(parseFlowList("auth, files, image, tracks")).toEqual([
      "auth",
      "files",
      "image",
      "tracks",
    ]);
  });
});
