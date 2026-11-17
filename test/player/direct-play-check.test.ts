import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Verdict = { ok: boolean; reason: string | null; streamFormat: string | null };
type Call =
  | { query: "video"; request: { codec: string; profile: string; level: string; container: string } }
  | { query: "audio"; request: { codec: string; chcnt: number; container: string } };
type Result = { verdict: Verdict; calls: Call[] };

type Probe = { video: boolean; audio: boolean; videoMode: string; stb: boolean; hdcp22: boolean; hdr10: boolean };
type Stream = Record<string, unknown>;

const probe1080: Probe = { video: true, audio: true, videoMode: "1080p", stb: true, hdcp22: false, hdr10: false };
const probe4kStb: Probe = { ...probe1080, videoMode: "2160p60", hdcp22: true };

const h264: Stream = { codec_type: "video", codec_name: "h264", profile: "High", level: 41, width: 1920, height: 1080 };
const hevc: Stream = { codec_type: "video", codec_name: "hevc", profile: "Main", level: 153, width: 1920, height: 1080 };
const aac: Stream = { codec_type: "audio", codec_name: "aac", channels: 2 };

function media(streams: Stream[], fields: Record<string, unknown> = {}) {
  return {
    mime_type: "video/x-matroska",
    format: { name: "matroska", bit_rate: 8_000_000 },
    streams,
    playback_issues: [],
    ...fields,
  };
}

const pass = (streamFormat: "mp4" | "mkv"): Verdict => ({ ok: true, reason: null, streamFormat });
const reject = (reason: string): Verdict => ({ ok: false, reason, streamFormat: null });
const videoCall = (codec: string, profile: string, level: string, container: string): Call => ({
  query: "video",
  request: { codec, profile, level, container },
});
const audioCall = (codec: string, chcnt: number, container: string): Call => ({
  query: "audio",
  request: { codec, chcnt, container },
});

type Case = { mediaInfo: unknown; probe?: Probe; expected: Verdict; calls?: Call[] };

const avcHighMkv = videoCall("mpeg4 avc", "high", "4.1", "mkv");
const aacMkv = audioCall("aac", 2, "mkv");

const cases: Record<string, Case> = {
  no_media_info: { mediaInfo: null, expected: reject("not_ready"), calls: [] },
  no_streams: { mediaInfo: media([]), expected: reject("not_ready"), calls: [] },
  playback_issue: {
    mediaInfo: media([h264, aac], { playback_issues: ["open_gop"] }),
    expected: reject("playback_issue"),
    calls: [],
  },
  playback_issue_before_container: {
    mediaInfo: media([h264, aac], { mime_type: "video/webm", playback_issues: ["late_moov"] }),
    expected: reject("playback_issue"),
  },
  webm_reported_as_matroska: {
    mediaInfo: media([h264, aac], { mime_type: "video/webm" }),
    expected: reject("container_unsupported"),
    calls: [],
  },
  audio_webm: {
    mediaInfo: media([h264, aac], { mime_type: "audio/webm" }),
    expected: reject("container_unsupported"),
  },
  avi: {
    mediaInfo: media([h264, aac], { mime_type: "video/x-msvideo", format: { name: "avi", bit_rate: 8_000_000 } }),
    expected: reject("container_unsupported"),
    calls: [],
  },
  raw_ffprobe_mp4_name: {
    mediaInfo: media([h264, aac], { mime_type: "video/mp4", format: { name: "mov,mp4,m4a,3gp,3g2,mj2", bit_rate: 8_000_000 } }),
    expected: pass("mp4"),
  },
  raw_ffprobe_matroska_name: {
    mediaInfo: media([h264, aac], { format: { name: "matroska,webm", bit_rate: 8_000_000 } }),
    expected: pass("mkv"),
  },
  raw_ffprobe_webm_by_mime: {
    mediaInfo: media([h264, aac], { mime_type: "video/webm", format: { name: "matroska,webm", bit_rate: 8_000_000 } }),
    expected: reject("container_unsupported"),
    calls: [],
  },
  missing_format: { mediaInfo: media([h264, aac], { format: null }), expected: reject("container_unsupported") },
  mkv: { mediaInfo: media([h264, aac]), expected: pass("mkv"), calls: [avcHighMkv, aacMkv] },
  mp4: {
    mediaInfo: media([h264, aac], { mime_type: "video/mp4", format: { name: "mp4", bit_rate: 8_000_000 } }),
    expected: pass("mp4"),
    calls: [videoCall("mpeg4 avc", "high", "4.1", "mp4"), audioCall("aac", 2, "mp4")],
  },
  mov: {
    mediaInfo: media([h264, aac], { mime_type: "video/quicktime", format: { name: "mov", bit_rate: 8_000_000 } }),
    expected: pass("mp4"),
  },
  m4v: {
    mediaInfo: media([h264, aac], { mime_type: "video/x-m4v", format: { name: "m4v", bit_rate: 8_000_000 } }),
    expected: pass("mp4"),
  },
  cover_art_skipped: {
    mediaInfo: media([{ codec_type: "video", codec_name: "mjpeg", width: 600, height: 600 }, h264, aac]),
    expected: pass("mkv"),
    calls: [avcHighMkv, aacMkv],
  },
  png_cover_art_only: {
    mediaInfo: media([{ codec_type: "video", codec_name: "png" }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  no_video_stream: { mediaInfo: media([aac]), expected: reject("video_unsupported"), calls: [] },
  vp9: {
    mediaInfo: media([{ ...h264, codec_name: "vp9", profile: "Profile 0" }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  av1: { mediaInfo: media([{ ...h264, codec_name: "av1", profile: "Main" }, aac]), expected: reject("video_unsupported") },
  h264_main: {
    mediaInfo: media([{ ...h264, profile: "Main" }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("mpeg4 avc", "main", "4.1", "mkv"), aacMkv],
  },
  h264_constrained_baseline: {
    mediaInfo: media([{ ...h264, profile: "Constrained Baseline", level: 31 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("mpeg4 avc", "main", "4.1", "mkv"), aacMkv],
  },
  h264_baseline: {
    mediaInfo: media([{ ...h264, profile: "Baseline", level: 30 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("mpeg4 avc", "main", "4.1", "mkv"), aacMkv],
  },
  h264_level_4_0_asks_for_4_1: {
    mediaInfo: media([{ ...h264, level: 40 }, aac]),
    expected: pass("mkv"),
    calls: [avcHighMkv, aacMkv],
  },
  h264_level_4_2: {
    mediaInfo: media([{ ...h264, level: 42 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("mpeg4 avc", "high", "4.2", "mkv"), aacMkv],
  },
  h264_high_10: {
    mediaInfo: media([{ ...h264, profile: "High 10" }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  h264_missing_profile: {
    mediaInfo: media([{ ...h264, profile: null }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  h264_real_level_above_4_2: {
    mediaInfo: media([{ ...h264, level: 51 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("mpeg4 avc", "high", "5.1", "mkv"), aacMkv],
  },
  h264_missing_level_is_hardest: {
    mediaInfo: media([{ ...h264, level: null }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("mpeg4 avc", "high", "6.2", "mkv"), aacMkv],
  },
  h264_unknown_level_is_hardest: {
    mediaInfo: media([{ ...h264, level: -99 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("mpeg4 avc", "high", "6.2", "mkv"), aacMkv],
  },
  h264_level_rejected_by_device: {
    mediaInfo: media([{ ...h264, level: 51 }, aac]),
    probe: { ...probe1080, video: false },
    expected: reject("video_unsupported"),
    calls: [videoCall("mpeg4 avc", "high", "5.1", "mkv")],
  },
  hevc_main: {
    mediaInfo: media([hevc, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "5.1", "mkv"), aacMkv],
  },
  hevc_level_5_2: {
    mediaInfo: media([{ ...hevc, level: 156 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "5.2", "mkv"), aacMkv],
  },
  hevc_level_4_1: {
    mediaInfo: media([{ ...hevc, level: 123 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "4.1", "mkv"), aacMkv],
  },
  hevc_level_5_0: {
    mediaInfo: media([{ ...hevc, level: 150 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "5.0", "mkv"), aacMkv],
  },
  hevc_level_3_1_asks_for_4_1: {
    mediaInfo: media([{ ...hevc, level: 93 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "4.1", "mkv"), aacMkv],
  },
  hevc_unknown_level_is_hardest: {
    mediaInfo: media([{ ...hevc, level: -99 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "6.2", "mkv"), aacMkv],
  },
  hevc_level_not_multiple_of_3_is_hardest: {
    mediaInfo: media([{ ...hevc, level: 152 }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "6.2", "mkv"), aacMkv],
  },
  hevc_missing_level_is_hardest: {
    mediaInfo: media([{ ...hevc, level: null }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "6.2", "mkv"), aacMkv],
  },
  hevc_rext: { mediaInfo: media([{ ...hevc, profile: "Rext" }, aac]), expected: reject("video_unsupported"), calls: [] },
  hevc_main_10_sdr: {
    mediaInfo: media([{ ...hevc, profile: "Main 10" }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  hevc_main_10_hdr10: {
    mediaInfo: media([{ ...hevc, profile: "Main 10" }, aac]),
    probe: { ...probe1080, hdr10: true },
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main 10", "5.1", "mkv"), aacMkv],
  },
  hevc_main_10_flagged_sdr: {
    mediaInfo: media([{ ...hevc, profile: "Main 10", hdr: false }, aac]),
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main 10", "5.1", "mkv"), aacMkv],
  },
  hdr_flag_without_hdr10_display: {
    mediaInfo: media([{ ...hevc, hdr: true }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  hdr_flag_on_hdr10_display: {
    mediaInfo: media([{ ...hevc, profile: "Main 10", hdr: true }, aac]),
    probe: { ...probe1080, hdr10: true },
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main 10", "5.1", "mkv"), aacMkv],
  },
  dolby_vision_profile_in_mkv: {
    mediaInfo: media([{ ...hevc, profile: "Main 10", hdr: true, dolby_vision_profile: 5 }, aac]),
    probe: { ...probe1080, hdr10: true },
    expected: reject("video_unsupported"),
    calls: [],
  },
  dolby_vision_profile_null_is_not_dolby_vision: {
    mediaInfo: media([{ ...hevc, hdr: false, dolby_vision_profile: null }, aac]),
    expected: pass("mkv"),
  },
  dolby_vision_dvh1: {
    mediaInfo: media([{ ...hevc, rfc6381_codec: "dvh1.05.06" }, aac], {
      mime_type: "video/mp4",
      format: { name: "mp4", bit_rate: 8_000_000 },
    }),
    expected: reject("video_unsupported"),
    calls: [],
  },
  dolby_vision_dvhe: {
    mediaInfo: media([{ ...hevc, rfc6381_codec: "dvhe.08.06" }, aac], {
      mime_type: "video/mp4",
      format: { name: "mp4", bit_rate: 8_000_000 },
    }),
    expected: reject("video_unsupported"),
  },
  uhd_on_1080p_mode: {
    mediaInfo: media([{ ...hevc, width: 3840, height: 2160 }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  uhd_stb_without_hdcp_2_2: {
    mediaInfo: media([{ ...hevc, width: 3840, height: 2160 }, aac]),
    probe: { ...probe4kStb, hdcp22: false },
    expected: reject("video_unsupported"),
    calls: [],
  },
  uhd_stb_with_hdcp_2_2: {
    mediaInfo: media([{ ...hevc, width: 3840, height: 2160 }, aac]),
    probe: probe4kStb,
    expected: pass("mkv"),
    calls: [videoCall("hevc", "main", "5.1", "mkv"), aacMkv],
  },
  uhd_tv_ignores_hdcp: {
    mediaInfo: media([{ ...hevc, width: 3840, height: 2160 }, aac]),
    probe: { ...probe1080, videoMode: "2160p60b10", stb: false, hdcp22: false },
    expected: pass("mkv"),
  },
  ultrawide_long_side: {
    mediaInfo: media([{ ...hevc, width: 2560, height: 1080 }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  portrait_long_side: {
    mediaInfo: media([{ ...h264, width: 1080, height: 2560 }, aac]),
    expected: reject("video_unsupported"),
    calls: [],
  },
  portrait_full_hd: {
    mediaInfo: media([{ ...h264, width: 1080, height: 1920 }, aac]),
    expected: pass("mkv"),
  },
  missing_size_leaves_the_device_to_decide: {
    mediaInfo: media([{ ...h264, width: null }, aac]),
    expected: pass("mkv"),
    calls: [avcHighMkv, aacMkv],
  },
  missing_size_on_4k_output: {
    mediaInfo: media([{ ...h264, width: null, height: null }, aac]),
    probe: probe4kStb,
    expected: pass("mkv"),
  },
  avc_bit_rate_at_peak: {
    mediaInfo: media([h264, aac], { format: { name: "matroska", bit_rate: 15_000_000 } }),
    expected: pass("mkv"),
  },
  avc_bit_rate_over_peak: {
    mediaInfo: media([h264, aac], { format: { name: "matroska", bit_rate: 15_000_001 } }),
    expected: reject("video_unsupported"),
    calls: [],
  },
  hevc_bit_rate_at_peak: {
    mediaInfo: media([hevc, aac], { format: { name: "matroska", bit_rate: "60000000" } }),
    expected: pass("mkv"),
  },
  hevc_bit_rate_over_peak: {
    mediaInfo: media([hevc, aac], { format: { name: "matroska", bit_rate: "60000001" } }),
    expected: reject("video_unsupported"),
  },
  missing_bit_rate_skips_the_cap: {
    mediaInfo: media([h264, aac], { format: { name: "matroska" } }),
    expected: pass("mkv"),
    calls: [avcHighMkv, aacMkv],
  },
  audio_rejected_by_device: {
    mediaInfo: media([h264, aac]),
    probe: { ...probe1080, audio: false },
    expected: reject("audio_unsupported"),
    calls: [avcHighMkv, aacMkv],
  },
  eac3_surround: {
    mediaInfo: media([h264, { codec_type: "audio", codec_name: "eac3", channels: 6 }]),
    expected: pass("mkv"),
    calls: [avcHighMkv, audioCall("eac3", 6, "mkv")],
  },
  audio_missing_channels_is_hardest: {
    mediaInfo: media([h264, { codec_type: "audio", codec_name: "ac3" }]),
    expected: pass("mkv"),
    calls: [avcHighMkv, audioCall("ac3", 8, "mkv")],
  },
  opus_unmapped: {
    mediaInfo: media([h264, { codec_type: "audio", codec_name: "opus", channels: 2 }]),
    expected: reject("audio_unsupported"),
    calls: [avcHighMkv],
  },
  truehd_unmapped: {
    mediaInfo: media([h264, { codec_type: "audio", codec_name: "truehd", channels: 8 }]),
    expected: reject("audio_unsupported"),
    calls: [avcHighMkv],
  },
  default_audio_stream_is_checked: {
    mediaInfo: media([
      h264,
      { ...aac, default: false },
      { codec_type: "audio", codec_name: "dts", channels: 6, default: true },
    ]),
    probe: { ...probe1080, audio: false },
    expected: reject("audio_unsupported"),
    calls: [avcHighMkv, audioCall("dts", 6, "mkv")],
  },
  default_audio_stream_after_unsupported_first: {
    mediaInfo: media([
      h264,
      { codec_type: "audio", codec_name: "truehd", channels: 8, default: false },
      { ...aac, default: true },
    ]),
    expected: pass("mkv"),
    calls: [avcHighMkv, aacMkv],
  },
  first_of_several_default_audio_streams: {
    mediaInfo: media([
      h264,
      { codec_type: "audio", codec_name: "truehd", channels: 8, default: false },
      { ...aac, default: true },
      { codec_type: "audio", codec_name: "dts", channels: 6, default: true },
    ]),
    expected: pass("mkv"),
    calls: [avcHighMkv, aacMkv],
  },
  first_audio_stream_only: {
    mediaInfo: media([h264, aac, { codec_type: "audio", codec_name: "truehd", channels: 8 }]),
    expected: pass("mkv"),
    calls: [avcHighMkv, aacMkv],
  },
  first_audio_stream_unmapped: {
    mediaInfo: media([h264, { codec_type: "audio", codec_name: "opus", channels: 2 }, aac]),
    expected: reject("audio_unsupported"),
  },
  no_audio_stream: {
    mediaInfo: media([h264, { codec_type: "subtitle" }]),
    expected: pass("mkv"),
    calls: [avcHighMkv],
  },
};

describe("checkDirectPlay", () => {
  let results: Record<string, Result>;

  beforeAll(async () => {
    const withProbe = Object.fromEntries(
      Object.entries(cases).map(([name, { mediaInfo, probe }]) => [name, { mediaInfo, probe: probe ?? probe1080 }]),
    );
    results = await runBrsCases<Result>(
      ["components/shared/Playback/DirectPlayCheck.brs", "test/player/fake-decoder-probe.brs"],
      "test/player/direct-play-check.brs",
      withProbe,
    );
  });

  it.each(Object.entries(cases))("%s", (name, { expected, calls }) => {
    expect(results[name].verdict).toEqual(expected);
    if (calls !== undefined) expect(results[name].calls).toEqual(calls);
  });
});
