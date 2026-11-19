import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { beforeAll, describe, expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

type SentryEvent = {
  message: string;
  level: string;
  fingerprint?: string[];
  tags: Record<string, string>;
  user?: Record<string, string>;
};

const playbackEvents = [
  "playback_failure",
  "playback_failure_hevc_original",
  "playback_rescue_engine",
  "playback_rescue_watchdog",
  "playback_rescue_preflight",
] as const;

type DriverResult = {
  sends: Record<"no_dsn" | "no_account" | "key_missing" | "enabled" | "disabled", boolean>;
  source_request_failure: SentryEvent;
  conversion_failure: SentryEvent;
} & Record<(typeof playbackEvents)[number], SentryEvent>;

const deviceTags = ["connection_type", "roku_model", "roku_os", "video_mode"];

// Playback failure reports, schema 2: https://app.notion.com/p/41dd546ba2f5812a8688d64d3aa3df21
const playbackTags = [
  "telemetry_event",
  "schema_version",
  "platform",
  "player",
  "playback_outcome",
  "playback_terminal",
  "playback_started",
  "failure_mode",
  "streaming_method",
  "source_kind",
  "device_check",
  "rescue_reason",
  "rescue_to",
  "engine_error_domain",
  "engine_error_category",
  "engine_error_code",
  "source_request_status",
  "file_id",
  "container_family",
  "video_codec",
  "video_profile",
  "video_level",
  "video_bit_depth",
  "video_resolution",
  "video_hdr",
  "audio_codec",
  "audio_channels",
];

const allowedTags = {
  conversion_failure: [
    ...deviceTags,
    "telemetry_event",
    "schema_version",
    "player",
    "conversion_status",
    "streaming_method",
    "file_id",
  ],
  source_request_failure: [
    ...deviceTags,
    "telemetry_event",
    "file_id",
    "source_request_error_type",
    "source_request_status_code",
  ],
};

function sink(): NodeJS.WriteStream {
  return new Writable({ write: (_chunk, _encoding, done) => done() }) as NodeJS.WriteStream;
}

async function runDriver(): Promise<DriverResult> {
  const files = [
    "source/BuildConfig.brs",
    "components/shared/Sentry/Sentry.brs",
    "components/shared/Playback/DirectPlayCheck.brs",
    "components/shared/Sentry/PlaybackTelemetry.brs",
    "test/sentry/sentry-privacy.brs",
  ].map((file) => join(repoRoot, file));
  const [output] = await execute(files, {
    root: repoRoot,
    componentDirs: [],
    stdout: sink(),
    stderr: sink(),
  });

  return JSON.parse(String(output)) as DriverResult;
}

describe("Sentry reporting", () => {
  let result: DriverResult;

  beforeAll(async () => {
    result = await runDriver();
  });

  it("sends only with a DSN and the account's diagnostics_enabled not false", () => {
    expect(result.sends).toEqual({
      no_dsn: false,
      no_account: true,
      key_missing: true,
      enabled: true,
      disabled: false,
    });
  });

  it.each([...playbackEvents, "source_request_failure", "conversion_failure"] as const)(
    "keeps account data, filenames, titles, URLs and tokens out of %s",
    (name) => {
      expect(JSON.stringify(result[name]).toLowerCase()).not.toContain("secret");
    },
  );

  it.each(playbackEvents)("sends %s anonymously with exactly the contract's tags", (name) => {
    expect(result[name].user).toBeUndefined();
    expect(Object.keys(result[name].tags).sort()).toEqual([...playbackTags].sort());
  });

  it.each([
    ["source_request_failure", allowedTags.source_request_failure],
    ["conversion_failure", allowedTags.conversion_failure],
  ] as const)("sends only allowlisted tags on %s", (name, tags) => {
    expect(Object.keys(result[name].tags).sort()).toEqual([...tags].sort());
  });

  it("reports an HEVC Main 10 original failing to decode in Direct play as the contract's example", () => {
    const { message, level, fingerprint, tags } = result.playback_failure_hevc_original;

    expect(message).toBe("playback failed: decode");
    expect(level).toBe("error");
    expect(fingerprint).toEqual(["roku", "failed", "decode", "-5"]);
    expect(tags).toMatchObject({
      telemetry_event: "playback_failure",
      schema_version: "2",
      platform: "roku",
      player: "roku",
      playback_outcome: "failed",
      playback_terminal: "true",
      playback_started: "false",
      failure_mode: "decode",
      streaming_method: "file",
      source_kind: "original",
      device_check: "pass",
      engine_error_domain: "mediaerror",
      engine_error_code: "-5",
      source_request_status: "none",
      container_family: "matroska",
      video_codec: "hevc",
      video_profile: "main 10",
      audio_codec: "eac3",
      rescue_reason: "none",
      rescue_to: "none",
    });
  });

  it("lets a definitive source status outrank the engine code", () => {
    expect(result.playback_failure.tags).toMatchObject({
      failure_mode: "source_gone",
      source_request_status: "404",
      engine_error_domain: "http",
      engine_error_code: "-1",
      source_kind: "hls",
      device_check: "skipped",
      playback_started: "true",
    });
  });

  it("reports an engine rescue as a warning-level playback_failure", () => {
    const { message, level, fingerprint, tags } = result.playback_rescue_engine;

    expect(message).toBe("playback rescued: container_unsupported");
    expect(level).toBe("warning");
    expect(fingerprint).toEqual(["roku", "rescued", "container_unsupported", "-5"]);
    expect(tags).toMatchObject({
      telemetry_event: "playback_failure",
      playback_outcome: "rescued",
      playback_terminal: "false",
      playback_started: "false",
      failure_mode: "decode",
      rescue_reason: "container_unsupported",
      rescue_to: "converted",
      streaming_method: "file",
      source_kind: "original",
      device_check: "pass",
      engine_error_domain: "mediaerror",
      engine_error_code: "-5",
      file_id: "9001",
      container_family: "matroska",
      video_codec: "h264",
      video_profile: "high",
      video_level: "41",
      video_resolution: "1920x1080",
      audio_codec: "dts",
      audio_channels: "6",
    });
  });

  it("reports a start timeout rescue without engine error fields", () => {
    expect(result.playback_rescue_watchdog.tags).toMatchObject({
      playback_outcome: "rescued",
      rescue_reason: "decoder_error",
      failure_mode: "unknown",
      engine_error_domain: "none",
      engine_error_code: "none",
    });
  });

  it("reports a preflight rescue with the failed device check", () => {
    expect(result.playback_rescue_preflight.tags).toMatchObject({
      playback_outcome: "rescued",
      failure_mode: "none",
      rescue_reason: "audio_unsupported",
      rescue_to: "converted",
      source_kind: "original",
      device_check: "fail",
      engine_error_code: "none",
    });
  });

  it("reports a failed conversion with its status and method", () => {
    const { message, fingerprint, tags } = result.conversion_failure;

    expect(message).toBe("Roku conversion failed: NOT_AVAILABLE");
    expect(fingerprint).toEqual(["roku-conversion-failure", "NOT_AVAILABLE"]);
    expect(tags).toMatchObject({
      telemetry_event: "playback_conversion_failure",
      conversion_status: "NOT_AVAILABLE",
      streaming_method: "hls",
      file_id: "9001",
    });
  });

  it("still reports the safe request failure fields", () => {
    expect(result.source_request_failure.tags).toMatchObject({
      file_id: "9001",
      source_request_error_type: "NotFound",
      source_request_status_code: "404",
    });
  });
});
