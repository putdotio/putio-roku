import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Plan = {
  action: "play" | "convert" | "unplayable";
  source: "hls" | "original" | "converted" | null;
  url: string | null;
  streamFormat: string | null;
  reason: string | null;
};

type Probe = { video: boolean; audio: boolean; videoMode: string; stb: boolean; hdcp22: boolean; hdr10: boolean };

const api = "https://api.put.io/v2/";
const token = "download-token";
const hlsUrl = `https://api.put.io/v2/files/7/hls/media.m3u8?oauth_token=${token}&max_subtitle_count=0`;
const audioUrl = `https://api.put.io/v2/files/7/stream.mp3?oauth_token=${token}`;
const streamUrl = "https://s1.put.io/stream/7?u=path&stream=1&oauth_token=download-token";
const mp4StreamUrl = "https://s1.put.io/stream/7.mp4?u=path&stream=1&oauth_token=download-token";

const playable: Probe = { video: true, audio: true, videoMode: "1080p", stb: true, hdcp22: false, hdr10: false };
const noVideo: Probe = { ...playable, video: false };
const noAudio: Probe = { ...playable, audio: false };

const h264 = { codec_type: "video", codec_name: "h264", profile: "High", level: 41, width: 1920, height: 1080 };
const aac = { codec_type: "audio", codec_name: "aac", channels: 2 };
const mkvInfo = { mime_type: "video/x-matroska", format: { name: "matroska", bit_rate: 8_000_000 }, streams: [h264, aac] };
const mp4Info = { mime_type: "video/mp4", format: { name: "mp4", bit_rate: 8_000_000 }, streams: [h264, aac] };
const webmInfo = { ...mkvInfo, mime_type: "video/webm" };

const video = (fields: Record<string, unknown>) => ({ id: 7, file_type: "VIDEO", media_info: mkvInfo, ...fields });
const ctx = (fields: Record<string, unknown> = {}) => ({ apiUrl: api, downloadToken: token, ...fields });

const play = (source: Plan["source"], url: string, streamFormat: string, reason: string | null = null): Plan => ({
  action: "play",
  source,
  url,
  streamFormat,
  reason,
});
const convert = (source: "hls" | "converted", reason: string | null = null): Plan => ({
  action: "convert",
  source,
  url: null,
  streamFormat: null,
  reason,
});
const unplayable = (reason: string): Plan => ({ action: "unplayable", source: null, url: null, streamFormat: null, reason });

const cases: Record<string, { file: unknown; method?: string; sameSourceAs?: Plan; ctx: unknown; expected: Plan }> = {
  audio_standard: {
    file: { id: 7, file_type: "AUDIO", stream_url: streamUrl },
    method: "hls",
    ctx: ctx(),
    expected: { action: "play", source: "original", url: audioUrl, streamFormat: null, reason: null },
  },
  audio_direct_play: {
    file: { id: 7, file_type: "AUDIO", stream_url: streamUrl, need_convert: true },
    method: "file",
    ctx: ctx({ probe: noAudio }),
    expected: { action: "play", source: "original", url: audioUrl, streamFormat: null, reason: null },
  },
  audio_without_token: {
    file: { id: 7, file_type: "AUDIO", stream_url: streamUrl },
    method: "hls",
    ctx: { apiUrl: api },
    expected: unplayable("not_ready"),
  },
  no_file: { file: null, method: "file", ctx: ctx({ probe: playable }), expected: unplayable("not_ready") },
  no_ctx: { file: video({ need_convert: false }), method: "file", ctx: null, expected: unplayable("not_ready") },
  s1_no_conversion_needed: {
    file: video({ need_convert: false, is_mp4_available: false, stream_url: streamUrl }),
    method: "hls",
    ctx: ctx({ probe: playable }),
    expected: play("hls", hlsUrl, "hls"),
  },
  s1_converted_copy: {
    file: video({ need_convert: true, is_mp4_available: true, mp4_stream_url: mp4StreamUrl }),
    method: "hls",
    ctx: ctx(),
    expected: play("hls", hlsUrl, "hls"),
  },
  s1_unknown_method: { file: video({ need_convert: false }), method: "mp4", ctx: ctx(), expected: play("hls", hlsUrl, "hls") },
  s1_missing_method: { file: video({ need_convert: false }), ctx: ctx(), expected: play("hls", hlsUrl, "hls") },
  s2_needs_conversion: {
    file: video({ need_convert: true, is_mp4_available: false, stream_url: streamUrl }),
    method: "hls",
    ctx: ctx({ probe: playable }),
    expected: convert("hls"),
  },
  s2_need_convert_missing: {
    file: video({ is_mp4_available: false, stream_url: streamUrl }),
    method: "hls",
    ctx: ctx(),
    expected: convert("hls"),
  },
  standard_without_token: {
    file: video({ need_convert: false }),
    method: "hls",
    ctx: { apiUrl: api },
    expected: unplayable("not_ready"),
  },
  d1_original_mkv: {
    file: video({ need_convert: true, is_mp4_available: false, stream_url: streamUrl }),
    method: "file",
    ctx: ctx({ probe: playable }),
    expected: play("original", streamUrl, "mkv"),
  },
  d1_original_mp4_over_copy: {
    file: video({
      media_info: mp4Info,
      need_convert: false,
      is_mp4_available: true,
      stream_url: streamUrl,
      mp4_stream_url: mp4StreamUrl,
    }),
    method: "file",
    ctx: ctx({ probe: playable }),
    expected: play("original", streamUrl, "mp4"),
  },
  d2_check_failed: {
    file: video({ need_convert: false, is_mp4_available: true, stream_url: streamUrl, mp4_stream_url: mp4StreamUrl }),
    method: "file",
    ctx: ctx({ probe: noVideo }),
    expected: play("converted", mp4StreamUrl, "mp4", "video_unsupported"),
  },
  d2_no_stream_url: {
    file: video({ need_convert: false, is_mp4_available: true, mp4_stream_url: mp4StreamUrl }),
    method: "file",
    ctx: ctx({ probe: playable }),
    expected: play("converted", mp4StreamUrl, "mp4", "not_ready"),
  },
  d2_no_media_info: {
    file: video({
      media_info: null,
      need_convert: false,
      is_mp4_available: true,
      stream_url: streamUrl,
      mp4_stream_url: mp4StreamUrl,
    }),
    method: "file",
    ctx: ctx({ probe: playable }),
    expected: play("converted", mp4StreamUrl, "mp4", "not_ready"),
  },
  d2_rescue: {
    file: video({ need_convert: false, is_mp4_available: true, stream_url: streamUrl, mp4_stream_url: mp4StreamUrl }),
    method: "file",
    ctx: ctx({ probe: playable, originalFailed: true, failureReason: "container_unsupported" }),
    expected: play("converted", mp4StreamUrl, "mp4", "container_unsupported"),
  },
  d2_rescue_overrides_check: {
    file: video({ need_convert: false, is_mp4_available: true, stream_url: streamUrl, mp4_stream_url: mp4StreamUrl }),
    method: "file",
    ctx: ctx({ probe: noAudio, originalFailed: true, failureReason: "decoder_error" }),
    expected: play("converted", mp4StreamUrl, "mp4", "decoder_error"),
  },
  d2_rescue_without_reason: {
    file: video({ need_convert: false, is_mp4_available: true, stream_url: streamUrl, mp4_stream_url: mp4StreamUrl }),
    method: "file",
    ctx: ctx({ probe: playable, originalFailed: true }),
    expected: play("converted", mp4StreamUrl, "mp4", "decoder_error"),
  },
  d3_convert: {
    file: video({ need_convert: true, is_mp4_available: false, stream_url: streamUrl }),
    method: "file",
    ctx: ctx({ probe: noAudio }),
    expected: convert("converted", "audio_unsupported"),
  },
  d3_need_convert_missing: {
    file: video({ is_mp4_available: false, stream_url: streamUrl }),
    method: "file",
    ctx: ctx({ probe: noVideo }),
    expected: convert("converted", "video_unsupported"),
  },
  d3_rescue_convert: {
    file: video({ need_convert: true, is_mp4_available: false, stream_url: streamUrl }),
    method: "file",
    ctx: ctx({ probe: playable, originalFailed: true, failureReason: "decoder_error" }),
    expected: convert("converted", "decoder_error"),
  },
  d4_unplayable: {
    file: video({ media_info: webmInfo, need_convert: false, is_mp4_available: false, stream_url: streamUrl }),
    method: "file",
    ctx: ctx({ probe: playable }),
    expected: unplayable("container_unsupported"),
  },
  d4_no_urls: {
    file: video({ media_info: mp4Info, need_convert: false, is_mp4_available: false }),
    method: "file",
    ctx: ctx({ probe: playable }),
    expected: unplayable("not_ready"),
  },
  same_source_hls_keeps_manifest: {
    file: video({ need_convert: false }),
    sameSourceAs: play("hls", "https://api.put.io/v2/files/7/hls/media.m3u8?oauth_token=old", "hls"),
    ctx: ctx(),
    expected: play("hls", hlsUrl, "hls"),
  },
  same_source_original_takes_fresh_stream_url: {
    file: video({ need_convert: false, is_mp4_available: true, stream_url: streamUrl, mp4_stream_url: mp4StreamUrl }),
    sameSourceAs: play("original", "https://s1.put.io/stream/7?expired", "mkv"),
    ctx: ctx(),
    expected: play("original", streamUrl, "mkv"),
  },
  same_source_converted_keeps_reason: {
    file: video({ need_convert: false, is_mp4_available: true, stream_url: streamUrl, mp4_stream_url: mp4StreamUrl }),
    sameSourceAs: play("converted", "https://s1.put.io/stream/7.mp4?expired", "mp4", "video_unsupported"),
    ctx: ctx(),
    expected: play("converted", mp4StreamUrl, "mp4", "video_unsupported"),
  },
  same_source_audio_keeps_mp3: {
    file: { id: 7, file_type: "AUDIO", stream_url: streamUrl },
    sameSourceAs: { action: "play", source: "original", url: audioUrl, streamFormat: null, reason: null },
    ctx: ctx(),
    expected: { action: "play", source: "original", url: audioUrl, streamFormat: null, reason: null },
  },
  same_source_original_without_url_expires: {
    file: video({ need_convert: false, is_mp4_available: true, mp4_stream_url: mp4StreamUrl }),
    sameSourceAs: play("original", "https://s1.put.io/stream/7?expired", "mp4"),
    ctx: ctx(),
    expected: unplayable("link_expired"),
  },
};

describe("resolvePlaybackPlan", () => {
  let results: Record<string, Plan>;

  beforeAll(async () => {
    results = await runBrsCases<Plan>(
      [
        "components/shared/PlaybackConfig.brs",
        "components/shared/PlaybackUtils.brs",
        "components/shared/Playback/DirectPlayCheck.brs",
        "components/shared/Playback/PlaybackResolver.brs",
        "test/player/fake-decoder-probe.brs",
      ],
      "test/player/playback-resolver.brs",
      cases,
    );
  });

  it.each(Object.entries(cases))("%s", (name, { expected }) => {
    expect(results[name]).toEqual(expected);
  });
});
