import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Subtitle = { language?: string; language_code?: string; name?: string; url?: string };

type NameCase =
  | { input: { kind: "label"; name: string }; expected: string }
  | { input: { kind: "labels" | "menu"; subtitles: Subtitle[] }; expected: string[] }
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
  labels_reserve_original_names_and_keep_partial_language: {
    input: {
      kind: "labels",
      subtitles: [
        { language: "English", name: "Sample.srt" },
        { language: "English", name: "Sample.vtt" },
        { language: "English", name: "Sample (2).srt" },
        { language_code: "eng", name: "Sample.srt" },
        { language_code: "tur", name: "Sample.srt" },
        { language: "Undetermined", name: "Sample.srt" },
      ],
    },
    expected: [
      "English - Sample",
      "English - Sample (3)",
      "English - Sample (2)",
      "eng - Sample",
      "tur - Sample",
      "Unknown - Sample",
    ],
  },
  captions_keep_names_distinguishable_and_nameless_labels_exact: {
    input: {
      kind: "menu",
      subtitles: [
        { language: "Turkish", language_code: "tur", url: sidecarUrl },
        { name: "abcdefghijklmnopqrstuvx.srt", url: sidecarUrl },
        { name: "abcdefghijklmnopqrstuvy.srt", url: sidecarUrl },
        { name: "abcdefghijklmnopqrstuvy.vtt", url: sidecarUrl },
      ],
    },
    expected: [
      "Turkish",
      "Unknown - abcde...jklmnopqrstuvx",
      "Unknown - abcde...jklmnopqrstuvy",
      "Unknown - abcde...nopqrstuvy (2)",
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
  let results: Record<string, string | string[] | boolean>;

  beforeAll(async () => {
    results = await runBrsCases(
      [
        "components/shared/Playback/ManifestSubtitles.brs",
        "components/screens/VideoPlayer/VideoPlayer.brs",
        "components/screens/VideoPlayer/VideoPlayerTrackMenu.brs",
      ],
      "test/player/subtitle-names.brs",
      Object.fromEntries(Object.entries(nameCases).map(([name, c]) => [name, c.input])),
    );
  });

  it.each(Object.entries(nameCases))("%s", (name, { expected }) => {
    expect(results[name]).toEqual(expected);
  });
});
