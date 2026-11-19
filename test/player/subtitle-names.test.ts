import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Subtitle = { language?: string; language_code?: string; name?: string; url?: string };

type MenuItem = { label: string; selected: boolean; captionnumber?: number };
type LabelFields = { text: string; leadingEllipsis: boolean; ellipsisText: string };

type NameCase =
  | { input: { kind: "label"; name: string }; expected: string }
  | { input: { kind: "labels"; subtitles: Subtitle[] }; expected: string[] }
  | { input: { kind: "menu"; subtitles: Subtitle[]; selectedTrackName?: string }; expected: MenuItem[] }
  | {
      input: { kind: "manifestMenu"; tracks: { Description: string; TrackName: string }[]; selectedTrackName: string };
      expected: MenuItem[];
    }
  | { input: { kind: "match"; left: string; right: string }; expected: boolean };

const sidecarUrl = "https://api.put.io/v2/files/7/subtitles/abc?oauth_token=t";

function expectedCaptions(labels: string[], selected = 0): MenuItem[] {
  return [
    { label: "Off", selected: selected === 0 },
    ...labels.map((label, index) => ({ label, captionnumber: index + 1, selected: selected === index + 1 })),
  ];
}

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
    expected: expectedCaptions([
      "Turkish",
      "Unknown - abcdefghijklmnopqrstuvx",
      "Unknown - abcdefghijklmnopqrstuvy",
      "Unknown - abcdefghijklmnopqrstuvy (2)",
    ]),
  },
  wide_sidecars_keep_short_labels_and_literal_ordinals: {
    input: {
      kind: "menu",
      subtitles: [
        { language: "English", name: "W".repeat(17) + ".srt", url: sidecarUrl + "1" },
        { language: "English", name: "W".repeat(17) + ".vtt", url: sidecarUrl + "2" },
        { language: "English", name: "W".repeat(17) + " (2).srt", url: sidecarUrl + "3" },
      ],
      selectedTrackName: sidecarUrl + "2",
    },
    expected: expectedCaptions([
      "English - " + "W".repeat(17),
      "English - " + "W".repeat(17) + " (3)",
      "English - " + "W".repeat(17) + " (2)",
    ], 2),
  },
  captions_preserve_forced_and_normal_tails: {
    input: {
      kind: "menu",
      subtitles: [
        { language: "English", name: "Lily.S01E01.Forced.SDH.srt", url: sidecarUrl + "1" },
        { language: "English", name: "Lily.S01E01.Normal.SDH.srt", url: sidecarUrl + "2" },
      ],
    },
    expected: expectedCaptions(["English - Lily.S01E01.Forced.SDH", "English - Lily.S01E01.Normal.SDH"]),
  },
  manifest_menu_disambiguates_identical_names: {
    input: {
      kind: "manifestMenu",
      tracks: [
        { Description: "English", TrackName: "webvtt/1" },
        { Description: "English", TrackName: "webvtt/2" },
        { Description: "English (2)", TrackName: "webvtt/3" },
      ],
      selectedTrackName: "webvtt/2",
    },
    expected: expectedCaptions(["English", "English (3)", "English (2)"], 2),
  },
  wide_manifest_labels_keep_full_names_for_native_clipping: {
    input: {
      kind: "manifestMenu",
      tracks: ["i", "j", "l"].map((letter, index) => ({
        Description: "English - WWWWW" + letter + "W".repeat(25),
        TrackName: "webvtt/" + (index + 1),
      })),
      selectedTrackName: "webvtt/3",
    },
    expected: expectedCaptions([
      "English - WWWWWi" + "W".repeat(25),
      "English - WWWWWj" + "W".repeat(25),
      "English - WWWWWl" + "W".repeat(25),
    ], 3),
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
  let results: Record<string, NameCase["expected"]>;

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

it("sets native ellipsis for captions and resets the reused Label for other menus", async () => {
  const wideName = "English - " + "W".repeat(17);
  const { render } = await runBrsCases<LabelFields[]>(
    ["components/shared/TrackMenu/TrackMenu.brs"],
    "test/player/subtitle-names.brs",
    {
      render: {
        kind: "render",
        items: [
          { label: wideName, captionNumber: 1 },
          { label: wideName + " (3)", captionNumber: 2 },
          { label: "1.25x" },
        ],
      },
    },
  );
  expect(render).toEqual([
    { text: wideName, leadingEllipsis: true, ellipsisText: "[1] ..." },
    { text: wideName + " (3)", leadingEllipsis: true, ellipsisText: "[2] ..." },
    { text: "1.25x", leadingEllipsis: false, ellipsisText: "..." },
  ]);
});
