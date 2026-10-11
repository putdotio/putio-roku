import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { beforeAll, describe, expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

type SentryEvent = {
  message: string;
  tags: Record<string, string>;
  user?: Record<string, string>;
};

type DriverResult = {
  sends: Record<"no_dsn" | "no_account" | "key_missing" | "enabled" | "disabled", boolean>;
  playback_failure: SentryEvent;
  source_request_failure: SentryEvent;
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

  it.each(["playback_failure", "source_request_failure"] as const)(
    "keeps account data, filenames, titles, URLs and tokens out of %s",
    (name) => {
      expect(JSON.stringify(result[name]).toLowerCase()).not.toContain("secret");
    },
  );

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
      audio_codec: "aac",
      source_kind: "hls",
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
