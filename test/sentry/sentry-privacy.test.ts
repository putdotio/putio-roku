import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { beforeAll, describe, expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

type SentryEvent = {
  message: string;
  fingerprint?: string[];
  tags: Record<string, string>;
  user?: Record<string, string>;
};

type DriverResult = {
  sends: Record<"no_dsn" | "no_account" | "key_missing" | "enabled" | "disabled", boolean>;
  playback_failure: SentryEvent;
  playback_rescue_engine: SentryEvent;
  playback_rescue_watchdog: SentryEvent;
  playback_rescue_preflight: SentryEvent;
  source_request_failure: SentryEvent;
  conversion_failure: SentryEvent;
};

const deviceTags = ["connection_type", "roku_model", "roku_os", "video_mode"];

const mediaTags = [
  "container_family",
  "file_id",
  "video_codec",
  "video_profile",
  "video_resolution",
  "audio_codec",
];

const allowedTags = {
  playback_failure: [
    ...deviceTags,
    ...mediaTags,
    "telemetry_event",
    "schema_version",
    "player",
    "playback_outcome",
    "playback_terminal",
    "playback_failure_mode",
    "playback_started",
    "streaming_method",
    "playback_source",
    "roku_error_code",
    "roku_error_category",
    "roku_error_source",
    "roku_error_info_code",
    "source_kind",
    "stream_format",
  ],
  playback_rescue: [
    ...deviceTags,
    ...mediaTags,
    "telemetry_event",
    "schema_version",
    "player",
    "streaming_method",
    "rescue_reason",
    "rescue_trigger",
    "rescue_from_source",
    "rescue_to_source",
    "rescue_outcome",
    "roku_error_code",
    "roku_error_category",
    "roku_error_info_code",
    "video_level",
    "audio_channels",
    "audio_output_channel",
  ],
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

  it.each([
    "playback_failure",
    "playback_rescue_engine",
    "playback_rescue_watchdog",
    "playback_rescue_preflight",
    "source_request_failure",
    "conversion_failure",
  ] as const)("keeps account data, filenames, titles, URLs and tokens out of %s", (name) => {
    expect(JSON.stringify(result[name]).toLowerCase()).not.toContain("secret");
  });

  it.each([
    ["playback_failure", allowedTags.playback_failure],
    ["playback_rescue_engine", allowedTags.playback_rescue],
    ["playback_rescue_watchdog", allowedTags.playback_rescue],
    ["playback_rescue_preflight", allowedTags.playback_rescue],
    ["source_request_failure", allowedTags.source_request_failure],
    ["conversion_failure", allowedTags.conversion_failure],
  ] as const)("sends only allowlisted tags on %s", (name, tags) => {
    expect(Object.keys(result[name].tags).sort()).toEqual([...tags].sort());
  });

  it("still reports the safe playback fields", () => {
    const { message, tags, user } = result.playback_failure;

    expect(message).toBe("Roku playback failed: network");
    expect(user).toEqual({ id: "4242" });
    expect(tags).toMatchObject({
      file_id: "9001",
      roku_error_code: "-1",
      roku_error_category: "http",
      roku_error_info_code: "403",
      container_family: "matroska",
      video_codec: "h264",
      video_resolution: "1920x1080",
      audio_codec: "dts",
      source_kind: "hls",
      streaming_method: "file",
      playback_source: "original",
    });
  });

  it("reports an engine rescue with its trigger, sources and media facts", () => {
    const { message, fingerprint, tags } = result.playback_rescue_engine;

    expect(message).toBe("Roku playback rescued: container_unsupported");
    expect(fingerprint).toEqual(["roku-rescue", "container_unsupported"]);
    expect(tags).toMatchObject({
      telemetry_event: "playback_rescue",
      streaming_method: "file",
      rescue_reason: "container_unsupported",
      rescue_trigger: "engine",
      rescue_from_source: "original",
      rescue_to_source: "converted",
      rescue_outcome: "play",
      roku_error_code: "-5",
      roku_error_category: "http",
      roku_error_info_code: "403",
      container_family: "matroska",
      video_codec: "h264",
      video_profile: "high",
      video_level: "41",
      video_resolution: "1920x1080",
      audio_codec: "dts",
      audio_channels: "6",
    });
  });

  it("reports a start timeout as a watchdog rescue without Roku error fields", () => {
    expect(result.playback_rescue_watchdog.tags).toMatchObject({
      rescue_reason: "decoder_error",
      rescue_trigger: "watchdog",
      rescue_from_source: "original",
      rescue_to_source: "converted",
      roku_error_code: "none",
      roku_error_category: "none",
      roku_error_info_code: "none",
    });
  });

  it("reports a preflight rescue without Roku error fields", () => {
    expect(result.playback_rescue_preflight.tags).toMatchObject({
      rescue_reason: "audio_unsupported",
      rescue_trigger: "preflight",
      rescue_to_source: "converted",
      rescue_outcome: "convert",
      roku_error_code: "none",
      roku_error_category: "none",
      roku_error_info_code: "none",
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
