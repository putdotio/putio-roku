import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Subtitle = { language?: string; language_code?: string; name?: string };

type NameCase =
  | { input: { kind: "label"; name: string }; expected: string }
  | { input: { kind: "labels"; subtitles: Subtitle[] }; expected: string[] }
  | { input: { kind: "match"; left: string; right: string }; expected: boolean };

const sidecarUrl = "https://api.put.io/v2/files/7/subtitles/abc?oauth_token=t";

const nameCases: Record<string, NameCase> = {
  label_drops_srt: { input: { kind: "label", name: "Sample.Show.S01E01.en.srt" }, expected: "Sample.Show.S01E01.en" },
  label_drops_uppercase_extension: { input: { kind: "label", name: "Sample.Show.S01E01.SRT" }, expected: "Sample.Show.S01E01" },
  label_drops_ttml: { input: { kind: "label", name: "Sample.Show.S01E01.ttml" }, expected: "Sample.Show.S01E01" },
  label_drops_any_final_extension: { input: { kind: "label", name: "Sample.Show.S01E01.720p" }, expected: "Sample.Show.S01E01" },
  label_keeps_leading_dot_name: { input: { kind: "label", name: ".hidden" }, expected: ".hidden" },
  label_keeps_name_of_only_leading_dots: { input: { kind: "label", name: "..srt" }, expected: "..srt" },
  label_drops_extension_after_leading_dots: { input: { kind: "label", name: "..hidden.srt" }, expected: "..hidden" },
  sidecar_labels_match_hls_names: {
    input: {
      kind: "labels",
      subtitles: [
        { language: "Undetermined", language_code: "und", name: "Sample.srt" },
        { language: "English", language_code: "eng", name: "Sample.srt" },
        { language: "English", language_code: "eng", name: "Sample.vtt" },
        { language: "English", language_code: "eng", name: "sample.srt" },
        { language: "Turkish", language_code: "tur" },
        { language: "", language_code: "", name: "Other.srt" },
      ],
    },
    expected: [
      "Unknown - Sample",
      "English - Sample",
      "English - Sample (2)",
      "English - sample",
      "Turkish",
      "Unknown - Other",
    ],
  },
  roku_prefixed_sidecar_matches: {
    input: { kind: "match", left: `<dev_9b1_1a>${sidecarUrl}`, right: sidecarUrl },
    expected: true,
  },
  manifest_track_matches_itself: { input: { kind: "match", left: "webvtt/2", right: "webvtt/2" }, expected: true },
  manifest_track_1_does_not_match_track_10: {
    input: { kind: "match", left: "webvtt/10", right: "webvtt/1" },
    expected: false,
  },
};

describe("subtitle names", () => {
  let results: Record<string, string | boolean>;

  beforeAll(async () => {
    results = await runBrsCases(
      ["components/shared/Playback/ManifestSubtitles.brs"],
      "test/player/subtitle-names.brs",
      Object.fromEntries(Object.entries(nameCases).map(([name, c]) => [name, c.input])),
    );
  });

  it.each(Object.entries(nameCases))("%s", (name, { expected }) => {
    expect(results[name]).toEqual(expected);
  });
});
