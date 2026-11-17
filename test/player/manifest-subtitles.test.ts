import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Track = { Description: string; Language: string; TrackName: string };
type Subtitle = { key: string; format: string; language: string; language_code: string };

const track = (Description: string, Language: string, n: number): Track => ({
  Description,
  Language,
  TrackName: `webvtt/${n}`,
});
const sub = (key: string, language: string, language_code: string, format = "srt"): Subtitle => ({
  key,
  format,
  language,
  language_code,
});

const episodeTracks = [
  track("English 1", "en", 1),
  track("English 2", "en", 2),
  track("English 3", "en", 3),
  track("English 4", "en", 4),
  track("Turkish 1", "tr", 5),
  track("Turkish 2", "tr", 6),
];
const episodeSubtitles = [
  sub("e1", "English", "eng"),
  sub("e2", "English", "eng"),
  sub("e3", "English", "eng"),
  sub("e4", "English", "eng"),
  sub("t1", "Turkish", "tur"),
  sub("t2", "Turkish", "tur"),
];

const cases: Record<string, { tracks: Track[]; subtitles: Subtitle[]; expected: (string | null)[] }> = {
  numbered_languages_match_in_order: {
    tracks: episodeTracks,
    subtitles: episodeSubtitles,
    expected: ["e1", "e2", "e3", "e4", "t1", "t2"],
  },
  single_track_languages_have_no_number: {
    tracks: [track("English", "en", 1), track("Turkish", "tr", 2)],
    subtitles: [sub("mkv-en", "English", "eng"), sub("os-tr", "Turkish", "tur")],
    expected: ["mkv-en", "os-tr"],
  },
  interleaved_languages_match_within_language: {
    tracks: [track("English 1", "en", 1), track("English 2", "en", 2), track("Turkish", "tr", 3)],
    subtitles: [sub("e1", "English", "eng"), sub("t1", "Turkish", "tur"), sub("e2", "English", "eng")],
    expected: ["e1", "e2", "t1"],
  },
  language_missing_a_subtitle_keeps_manifest_names: {
    tracks: [track("English 1", "en", 1), track("English 2", "en", 2), track("Turkish", "tr", 3)],
    subtitles: [...episodeSubtitles.slice(0, 3), sub("t1", "Turkish", "tur")],
    expected: [null, null, "t1"],
  },
  non_hls_formats_are_skipped: {
    tracks: [track("English", "en", 1)],
    subtitles: [sub("ass", "English", "eng", "ass"), sub("vtt", "English", "eng", "webvtt")],
    expected: ["vtt"],
  },
  undetermined_language_is_unknown: {
    tracks: [track("Unknown", "Unknown", 1)],
    subtitles: [sub("u1", "Undetermined", "und")],
    expected: ["u1"],
  },
  no_subtitles_keeps_manifest_names: {
    tracks: episodeTracks.slice(0, 2),
    subtitles: [],
    expected: [null, null],
  },
};

describe("matchManifestSubtitles", () => {
  let results: Record<string, (string | null)[]>;

  beforeAll(async () => {
    results = await runBrsCases(
      ["components/shared/Playback/ManifestSubtitles.brs"],
      "test/player/manifest-subtitles.brs",
      Object.fromEntries(Object.entries(cases).map(([name, c]) => [name, { tracks: c.tracks, subtitles: c.subtitles }])),
    );
  });

  it.each(Object.entries(cases))("%s", (name, { expected }) => {
    expect(results[name]).toEqual(expected);
  });
});

type NameCase =
  | { input: { kind: "label"; name: string }; expected: string }
  | { input: { kind: "match"; left: string; right: string }; expected: boolean };

const sidecarUrl = "https://api.put.io/v2/files/7/subtitles/abc?oauth_token=t";

const nameCases: Record<string, NameCase> = {
  label_drops_srt: { input: { kind: "label", name: "Sample.Show.S01E01.en.srt" }, expected: "Sample.Show.S01E01.en" },
  label_drops_uppercase_extension: { input: { kind: "label", name: "Sample.Show.S01E01.SRT" }, expected: "Sample.Show.S01E01" },
  label_drops_ttml: { input: { kind: "label", name: "Sample.Show.S01E01.ttml" }, expected: "Sample.Show.S01E01" },
  label_keeps_release_tag: { input: { kind: "label", name: "Sample.Show.S01E01.720p" }, expected: "Sample.Show.S01E01.720p" },
  label_keeps_inner_extension_text: { input: { kind: "label", name: "Sample.srt.Show" }, expected: "Sample.srt.Show" },
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
