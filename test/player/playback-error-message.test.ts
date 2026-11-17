import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Dialog = { title: string; messageLines: string[]; buttons: string[] };
type Input = { reason: string; method: "hls" | "file"; source?: string; unplayable?: boolean };

const cantPlay = "Can't play this file";
const noConvertedCopy = "This file has no converted version.";

const cases: Record<string, { input: Input; expected: Dialog }> = {
  direct_play_unsupported_video_names_the_missing_copy: {
    input: { reason: "video_unsupported", method: "file", unplayable: true },
    expected: {
      title: cantPlay,
      messageLines: ["This Roku can't decode the video.", noConvertedCopy],
      buttons: ["Play with Standard", "Back"],
    },
  },
  direct_play_rescue_without_copy_keeps_the_code: {
    input: { reason: "decoder_error", method: "file", unplayable: true },
    expected: {
      title: cantPlay,
      messageLines: ["The original file failed to play.", noConvertedCopy],
      buttons: ["Play with Standard", "Back"],
    },
  },
  direct_play_not_ready_skips_the_missing_copy: {
    input: { reason: "not_ready", method: "file", unplayable: true },
    expected: {
      title: cantPlay,
      messageLines: ["This video isn't ready to play yet."],
      buttons: ["Play with Standard", "Back"],
    },
  },
  direct_play_converted_copy_failure_offers_standard: {
    input: { reason: "decoder_error", method: "file", source: "converted" },
    expected: {
      title: cantPlay,
      messageLines: ["This video failed to play."],
      buttons: ["Play with Standard", "Back"],
    },
  },
  standard_container_unsupported_blames_the_format: {
    input: { reason: "container_unsupported", method: "hls", source: "hls" },
    expected: { title: cantPlay, messageLines: ["This file format can't be streamed."], buttons: ["Back"] },
  },
  standard_decoder_error_only_goes_back: {
    input: { reason: "decoder_error", method: "hls", source: "hls" },
    expected: { title: cantPlay, messageLines: ["This video failed to play."], buttons: ["Back"] },
  },
  standard_unknown_reason_falls_back: {
    input: { reason: "unknown", method: "hls", source: "hls" },
    expected: { title: cantPlay, messageLines: ["Something went wrong while playing."], buttons: ["Back"] },
  },
  standard_unplayable_skips_the_missing_copy: {
    input: { reason: "not_ready", method: "hls", unplayable: true },
    expected: { title: cantPlay, messageLines: ["This video isn't ready to play yet."], buttons: ["Back"] },
  },
  standard_not_ready_only_goes_back: {
    input: { reason: "not_ready", method: "hls" },
    expected: { title: cantPlay, messageLines: ["This video isn't ready to play yet."], buttons: ["Back"] },
  },
  expired_link_retries: {
    input: { reason: "link_expired", method: "file", source: "original" },
    expected: { title: "Playback link expired", messageLines: ["Try again to get a fresh link."], buttons: ["Retry", "Back"] },
  },
  stopped_after_first_frame_retries: {
    input: { reason: "playback_stopped", method: "hls", source: "hls" },
    expected: {
      title: "Playback stopped",
      messageLines: ["Something went wrong while playing."],
      buttons: ["Retry", "Back"],
    },
  },
  direct_play_conversion_failure_retries: {
    input: { reason: "conversion_failed", method: "file", unplayable: true },
    expected: { title: cantPlay, messageLines: ["The conversion failed."], buttons: ["Retry", "Back"] },
  },
  standard_conversion_failure_retries: {
    input: { reason: "conversion_failed", method: "hls", unplayable: true },
    expected: { title: cantPlay, messageLines: ["The conversion failed."], buttons: ["Retry", "Back"] },
  },
  connection_lost_retries: {
    input: { reason: "connection_lost", method: "file", source: "original" },
    expected: {
      title: "Playback stopped",
      messageLines: ["Connection lost. Check your internet and try again."],
      buttons: ["Retry", "Back"],
    },
  },
};

describe("playback error dialog", () => {
  let results: Record<string, Dialog>;

  beforeAll(async () => {
    const inputs = Object.fromEntries(Object.entries(cases).map(([name, { input }]) => [name, input]));
    results = await runBrsCases<Dialog>(
      ["components/shared/PlaybackConfig.brs", "components/shared/PlaybackErrorMessage.brs"],
      "test/player/playback-error-message.brs",
      inputs,
    );
  });

  it.each(Object.entries(cases))("%s", (name, { expected }) => {
    expect(results[name]).toEqual(expected);
  });

  it("never names HLS, MP4, the Settings switch or a Roku error code", () => {
    for (const { messageLines, buttons } of Object.values(results)) {
      expect([...messageLines, ...buttons].join(" ")).not.toMatch(/HLS|MP4|Settings|Error -?\d/);
    }
  });
});
