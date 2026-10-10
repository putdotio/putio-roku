import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { beforeAll, describe, expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

type SentryEvent = {
  message: string;
  tags: Record<string, string>;
  extra: Record<string, unknown>;
};

type DriverResult = {
  gate: Record<"no_dsn" | "no_account" | "key_missing" | "enabled" | "disabled", boolean>;
  playback_failure: SentryEvent;
  source_request_failure: SentryEvent;
};

const forbidden = [
  "Synthetic.Secret.Movie",
  "Synthetic Secret Title",
  "synthetic-token-7f3a",
  "oauth_token",
  "api.example.invalid",
  "https://",
];

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

  it("follows the account's diagnostics_enabled setting", () => {
    expect(result.gate).toEqual({
      no_dsn: false,
      no_account: true,
      key_missing: true,
      enabled: true,
      disabled: false,
    });
  });

  it.each(["playback_failure", "source_request_failure"] as const)(
    "keeps filenames, titles, URLs and tokens out of %s",
    (name) => {
      const event = JSON.stringify(result[name]);

      for (const value of forbidden) {
        expect(event).not.toContain(value);
      }
    },
  );

  it("still reports the safe playback fields", () => {
    const { message, tags, extra } = result.playback_failure;

    expect(message).toBe("Roku playback failed: network");
    expect(tags).toMatchObject({
      file_id: "9001",
      roku_error_code: "-1",
      roku_error_category: "http",
      container_family: "matroska",
      video_codec: "h264",
      video_resolution: "1920x1080",
      audio_codec: "aac",
      source_kind: "hls",
    });
    expect(extra).toMatchObject({
      roku_error_info: { category: "http", source: "manifest", error_code: 403 },
      video_metadata: { width: 1920, height: 1080, codec: "h264", duration: 5400 },
      mp4_status: "COMPLETED",
    });
  });

  it("still reports the safe request failure fields", () => {
    expect(result.source_request_failure.extra).toEqual({
      file_id: 9001,
      error_type: "NotFound",
      status_code: 404,
    });
  });
});
