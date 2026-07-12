import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import process from "node:process";
import { launchApp as rokitLaunchApp } from "@putdotio/rokit";
import {
  activeApp,
  checkRokuDevTarget,
  deviceInfo,
  install,
  launch,
  reinstall,
  remove,
} from "./device.ts";
import {
  appEcpId,
  debugArtifactDir,
  envOr,
  liveDebugEnv,
  liveEnv,
  liveSecretEnv,
  optionalEnv,
  putioAuthEnv,
  putioProfile,
  requireEnv,
  rokuContext,
  rokuTarget,
  run,
  runPnpm,
  runRokuLive,
  sideloadSecretEnv,
  sleep,
  splitWords,
  timestamp,
  tmpDir,
  withEnv,
} from "./runtime.ts";

export async function liveTest(): Promise<void> {
  await checkRokuDevTarget();
  await activeApp();
  await deviceInfo();
}

export function liveTestControl(): void {
  runRokuLive(["control-smoke"], liveEnv());
}

export function liveTestAuthRefresh(): void {
  runRokuLive(["auth-refresh-smoke"], liveEnv());
}

export function liveTestAuthReset(): void {
  runRokuLive(["auth-reset"], liveEnv());
}

export function liveTestPress(): void {
  const keys = requireEnv("KEYS", 'KEYS="Back Info" pnpm roku live-test-press');
  runRokuLive(["press", ...splitWords(keys)], liveEnv());
}

export function liveTestDeepLink(): void {
  runRokuLive([
    "launch-deeplink",
    requireEnv("CONTENT_ID", "CONTENT_ID=<file-id> pnpm roku live-test-deeplink"),
    envOr("MEDIA_TYPE", "movie"),
  ], liveEnv());
}

export function liveTestPlayback(): void {
  runRokuLive(playbackArgs("launch-playback", "CONTENT_ID=<file-id> pnpm roku live-test-playback"), liveEnv());
}

export function liveTestPlaybackRemote(): void {
  runRokuLive(playbackArgs("launch-playback-remote", "CONTENT_ID=<file-id> pnpm roku live-test-playback-remote"), liveEnv());
}

export function liveTestPlaybackType(): void {
  runRokuLive([
    "set-playback-type",
    requireEnv("TYPE", "TYPE=hls pnpm roku live-test-playback-type"),
    putioProfile(),
  ], putioAuthEnv(liveEnv()));
}

export function liveTestPlaybackTypeSmoke(): void {
  runRokuLive([
    "playback-type-smoke",
    requireEnv("TYPE", "TYPE=mp4 CONTENT_ID=<file-id> pnpm roku live-test-playback-type-smoke"),
    requireEnv("CONTENT_ID", "TYPE=mp4 CONTENT_ID=<file-id> pnpm roku live-test-playback-type-smoke"),
    envOr("MEDIA_TYPE", "movie"),
    envOr("START_FROM", "continue"),
  ], putioAuthEnv(liveEnv()));
}

export function liveTestPlaybackErrorDialog(): void {
  runRokuLive([
    "playback-error-dialog-smoke",
    requireEnv("CONTENT_ID", "CONTENT_ID=<bad-file-id> pnpm roku live-test-playback-error-dialog"),
    envOr("MEDIA_TYPE", "movie"),
    envOr("EXPECTED_TITLE", "Oops"),
    envOr("EXPECTED_MESSAGE", "File not found"),
  ], liveEnv());
}

export function liveTestPlayerUi(): void {
  runRokuLive([
    "player-ui-smoke",
    requireEnv("AUDIO_CONTENT_ID", "AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-player-ui"),
    requireEnv("SUBTITLE_CONTENT_ID", "AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-player-ui"),
    envOr("MEDIA_TYPE", "movie"),
    envOr("START_FROM", "continue"),
  ], liveEnv());
}

export function liveTestPlayerUiScreenshots(): void {
  const args = [
    "player-ui-screenshots",
    requireEnv("AUDIO_CONTENT_ID", "AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-player-ui-screenshots"),
    requireEnv("SUBTITLE_CONTENT_ID", "AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-player-ui-screenshots"),
    envOr("MEDIA_TYPE", "movie"),
    envOr("START_FROM", "continue"),
  ];
  const outputDir = optionalEnv("OUTPUT_DIR");
  runRokuLive(outputDir === undefined ? args : [...args, outputDir], {
    ...liveSecretEnv(),
    PLAYER_UI_REFERENCE_IMAGE: process.env.PLAYER_UI_REFERENCE_IMAGE ?? "",
  });
}

export async function liveTestInstall(): Promise<void> {
  await reinstall();
  await withEnv({ ROKU_APP_ECP_ID: "dev" }, launch);
}

export async function labLaunch(): Promise<void> {
  await checkRokuDevTarget();
  const story = optionalEnv("STORY");
  console.log(`Launching lab app ${appEcpId()} on ${rokuTarget()}...`);
  const params = new Map<string, string>([["lab", "1"]]);
  if (story !== undefined) {
    params.set("story", story);
  }
  await rokitLaunchApp(rokuContext(10_000), appEcpId(), params);
  runPnpm(["exec", "rokit", "wait-node", story === undefined ? "listView" : "detailView", "visible", "--timeout-ms", "30000"], liveEnv());
  waitForStoryTitle(story);
}

export async function labInstall(): Promise<void> {
  await remove();
  await withEnv({ ROKU_VARIANT: "lab" }, install);
  await withEnv({ ROKU_APP_ECP_ID: "dev" }, labLaunch);
}

export async function labScreenshot(): Promise<void> {
  const storyName = envOr("STORY", "app-dialog-empty");
  await withEnv({ STORY: storyName }, labInstall);
  const outputPath = join(tmpDir, "lab", `${storyName}-${timestamp()}.jpg`);
  mkdirSync(dirname(outputPath), { recursive: true });
  await sleep(Number(envOr("LAB_SCREENSHOT_DELAY", "3")) * 1_000);
  runPnpm(["exec", "rokit", "screenshot", outputPath], liveSecretEnv());
}

export async function visualCapture(): Promise<void> {
  await checkRokuDevTarget();
  const name = requireEnv("NAME", "NAME=search-results pnpm roku visual-capture");
  const outputPath = join(tmpDir, "visual", "captures", timestamp(), `${name}.jpg`);
  mkdirSync(dirname(outputPath), { recursive: true });
  runPnpm(["exec", "rokit", "screenshot", outputPath], liveSecretEnv());
  console.log(outputPath);
}

export function visualCapturePages(): void {
  putioAuthPrepare();
  const args = ["visual-pages"];
  const outputDir = optionalEnv("OUTPUT_DIR");
  if (outputDir !== undefined) {
    args.push(outputDir);
  }
  if (optionalEnv("INCLUDE_AUTH") !== undefined) {
    args.push("--include-auth");
  }
  runRokuLive(args, putioAuthEnv({ ...liveSecretEnv(), IMAGE_CONTENT_ID: process.env.IMAGE_CONTENT_ID ?? "" }));
}

export async function visualCaptureLab(): Promise<void> {
  await labInstall();
  const args = ["visual-lab"];
  const outputDir = optionalEnv("OUTPUT_DIR");
  if (outputDir !== undefined) {
    args.push(outputDir);
  }
  args.push(...splitWords(process.env.STORIES ?? ""));
  if (optionalEnv("ALL") !== undefined) {
    args.push("--all");
  }
  runRokuLive(args, { ...sideloadSecretEnv(), ROKU_DEBUG_ARTIFACT_DIR: debugArtifactDir() });
}

export async function debugSnapshot(): Promise<void> {
  await checkRokuDevTarget();
  const outputDir = join(debugArtifactDir(), `snapshot-${timestamp()}`);
  runRokuLive(["debug-snapshot", outputDir], liveSecretEnv());
}

export function putioAuthStatus(): void {
  run("node", ["scripts/putio-auth-harness.ts", "auth-status", putioProfile()], putioAuthEnv());
}

export function putioAuthPrepare(): void {
  run("node", ["scripts/putio-auth-harness.ts", "auth-prepare", putioProfile()], putioAuthEnv());
}

export function putioAuthApproveDevice(): void {
  run("node", [
    "scripts/putio-auth-harness.ts",
    "auth-approve-device",
    requireEnv("CODE", "CODE=<device-code> pnpm roku putio-auth-approve-device"),
    putioProfile(),
  ], putioAuthEnv());
}

export function liveTestAuthPrepare(): void {
  putioAuthPrepare();
  runRokuLive(["auth-prepare", putioProfile()], putioAuthEnv(liveEnv()));
}

export function liveTestFlowSmoke(): void {
  putioAuthPrepare();
  const args = ["flow-smoke"];
  const outputDir = optionalEnv("OUTPUT_DIR");
  if (outputDir !== undefined) {
    args.push(outputDir);
  }
  runRokuLive(args, putioAuthEnv(liveDebugEnv()));
}

export function liveTestFlow(): void {
  putioAuthPrepare();
  const flows = requireEnv("FLOWS", "FLOWS=auth,files,dialogs pnpm roku live-test-flow");
  const args = [
    "flow",
    flows,
    process.env.PLAYBACK_CONTENT_ID ?? "",
    process.env.AUDIO_CONTENT_ID ?? "",
    process.env.SUBTITLE_CONTENT_ID ?? "",
    envOr("MEDIA_TYPE", "movie"),
    envOr("START_FROM", "continue"),
  ];
  const outputDir = optionalEnv("OUTPUT_DIR");
  if (outputDir !== undefined) {
    args.push(outputDir);
  }
  runRokuLive(args, putioAuthEnv(flowEnv()));
}

export function liveTestFlowFull(): void {
  putioAuthPrepare();
  const args = [
    "flow-full",
    requireEnv("PLAYBACK_CONTENT_ID", "PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-flow-full"),
    requireEnv("IMAGE_CONTENT_ID", "PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-flow-full"),
    requireEnv("AUDIO_CONTENT_ID", "PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-flow-full"),
    requireEnv("SUBTITLE_CONTENT_ID", "PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-flow-full"),
    envOr("MEDIA_TYPE", "movie"),
    envOr("START_FROM", "continue"),
  ];
  const outputDir = optionalEnv("OUTPUT_DIR");
  if (outputDir !== undefined) {
    args.push(outputDir);
  }
  runRokuLive(args, putioAuthEnv(flowEnv()));
}

function playbackArgs(command: string, example: string): readonly string[] {
  return [
    command,
    requireEnv("CONTENT_ID", example),
    envOr("MEDIA_TYPE", "movie"),
    envOr("START_FROM", "continue"),
  ];
}

function flowEnv(): NodeJS.ProcessEnv {
  return {
    ...liveDebugEnv(),
    AUDIO_CONTENT_ID: process.env.AUDIO_CONTENT_ID ?? "",
    HISTORY_EXPECTED_TEXT: process.env.HISTORY_EXPECTED_TEXT ?? "",
    IMAGE_CONTENT_ID: process.env.IMAGE_CONTENT_ID ?? "",
    MEDIA_TYPE: envOr("MEDIA_TYPE", "movie"),
    PLAYBACK_CONTENT_ID: process.env.PLAYBACK_CONTENT_ID ?? "",
    START_FROM: envOr("START_FROM", "continue"),
    SUBTITLE_CONTENT_ID: process.env.SUBTITLE_CONTENT_ID ?? "",
  };
}

function waitForStoryTitle(story: string | undefined): void {
  if (story === undefined) {
    return;
  }

  const expectedTitle = storyTitle(story);
  if (expectedTitle !== undefined) {
    runPnpm(["exec", "rokit", "wait-node", "storyTitle", "text", expectedTitle, "--timeout-ms", "10000"], liveEnv());
  }
}

function storyTitle(story: string): string | undefined {
  const titles: Record<string, string> = {
    "app-dialog-empty": "AppDialog / no message",
    "app-dialog-message": "AppDialog / message",
    "continue-watching": "ContinueWatchingPrompt",
    "continue-watching-beginning": "ContinueWatchingPrompt / beginning",
    "conversion-status-converting": "VideoConversionStatus / converting",
    "conversion-status-error": "VideoConversionStatus / error",
    "delete-dialog-long": "DeleteFileDialog / long file",
    "delete-dialog-short": "DeleteFileDialog / short file",
    "list-item-file-loading-focused": "FileListItem / loading focused",
    "list-item-file-watched-focused": "FileListItem / watched focused",
    "list-item-files": "FileListItem",
    "list-item-generic": "ListItem",
    "list-item-history": "HistoryListItem",
    "track-menu-audio": "TrackMenu / audio",
    "track-menu-speed": "TrackMenu / playback speed",
    "track-menu-subtitles": "TrackMenu / subtitles",
    "track-menu-subtitles-scroll": "TrackMenu / subtitles scroll",
  };

  return titles[story];
}
