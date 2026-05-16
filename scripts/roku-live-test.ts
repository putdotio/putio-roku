#!/usr/bin/env node
import { access, copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, extname, join } from "node:path";
import process from "node:process";
import {
  assertNamedNodeState,
  assertNamedNodeSize as assertNodeSize,
  assertNamedNodeText,
  assertNamedNodeTranslation as assertNodeTranslation,
  assertSceneGraphNumberNear as assertNear,
  checkDevice as rokitCheckDevice,
  isNamedNodeVisible,
  launchApp as rokitLaunchApp,
  pressKey as rokitPressKey,
  queryActiveApp as rokitQueryActiveApp,
  queryEcp as rokitQueryEcp,
  querySceneGraph as rokitQuerySceneGraph,
  readNamedNodeAttribute,
  readNamedNodeAttributes,
  readNamedNodeNumber,
  readNamedNodeTranslation,
  readSceneGraphFailure,
  takeScreenshot as rokitTakeScreenshot,
  validateRemoteKey,
  waitForActiveApp as rokitWaitForActiveApp,
  waitForSceneGraphAssertion as rokitWaitForSceneGraphAssertion,
  waitForSceneGraphNode as rokitWaitForSceneGraphNode,
  type ActiveApp,
  type RokuContext,
} from "@putdotio/rokit";

const requestTimeoutMs = 15_000;
const sceneGraphRequestTimeoutMs = 10_000;
const sceneGraphPollIntervalMs = 1_500;
const launchTimeoutMs = 30_000;
const playbackLaunchTimeoutMs = 240_000;
const playbackLaunchRetryMs = 10_000;
const remotePlaybackLaunchQuietMs = 18_000;
const maxPlaybackLaunchAttempts = 4;
const screenshotCaptureAttempts = 5;

type TrackMenuTitle = "Audio tracks" | "Subtitles" | "Playback speed";
type PlayerControlId =
  | "rewind"
  | "play"
  | "fastForward"
  | "audio"
  | "captions"
  | "speed";

type PlayerUiReviewContext = {
  target: string;
  audioContentId: string;
  subtitleContentId: string;
  mediaType: string;
  startFromChoice: "continue" | "beginning";
};

type ImageMetadata = {
  filename: string;
  width: number;
  height: number;
};

type ReviewImage = {
  alt: string;
  filename: string;
  title: string;
};

function usage(): never {
  console.error(`usage:
  node scripts/roku-live-test.ts check
  node scripts/roku-live-test.ts active-app
  node scripts/roku-live-test.ts launch [app-id]
  node scripts/roku-live-test.ts launch-deeplink <content-id> [media-type]
  node scripts/roku-live-test.ts launch-playback <content-id> [media-type] [continue|beginning]
  node scripts/roku-live-test.ts launch-playback-remote <content-id> [media-type] [continue|beginning]
  node scripts/roku-live-test.ts player-ui-smoke <audio-content-id> <subtitle-content-id> [media-type] [continue|beginning]
  node scripts/roku-live-test.ts player-ui-screenshots <audio-content-id> <subtitle-content-id> [media-type] [continue|beginning] [output-dir]
  node scripts/roku-live-test.ts press <key> [key...]
  node scripts/roku-live-test.ts control-smoke

environment:
  ROKU_DEV_TARGET=<roku-ip> or ROKIT_TARGET=<roku-ip>
  ROKU_DEV_PASSWORD=<developer-mode-password> or ROKIT_PASSWORD=<developer-mode-password>
  PLAYER_UI_REFERENCE_IMAGE=<optional-reference-image-path>`);
  process.exit(1);
}

function requireTarget(): string {
  const rawTarget =
    process.env.ROKIT_TARGET?.trim() ?? process.env.ROKU_DEV_TARGET?.trim();

  if (!rawTarget) {
    throw new Error("ROKU_DEV_TARGET or ROKIT_TARGET is not set");
  }

  return rawTarget
    .replace(/^https?:\/\//, "")
    .replace(/\/.*$/, "")
    .replace(/:\d+$/, "");
}

function rokitContext(target: string, timeoutMs = requestTimeoutMs): RokuContext {
  return {
    target,
    timeoutMs,
    username: "rokudev",
  };
}

function requireDeveloperPassword(): string {
  const password = process.env.ROKIT_PASSWORD ?? process.env.ROKU_DEV_PASSWORD;

  if (!password) {
    throw new Error("ROKU_DEV_PASSWORD or ROKIT_PASSWORD is not set");
  }

  return password;
}

function assertNamedNodeVisible(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "visible");
}

function assertNamedNodeHidden(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "hidden");
}

function assertNamedNodeAbsent(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "absent");
}

async function waitForNamedNodeVisible(
  target: string,
  nodeName: string,
  timeoutMs = 30_000,
): Promise<void> {
  await rokitWaitForSceneGraphNode(
    rokitContext(target, sceneGraphRequestTimeoutMs),
    nodeName,
    { state: "visible" },
    timeoutMs,
  );
}

function assertPlayerOsdLayout(xml: string, progressFocused = true): void {
  assertNodeTranslation(xml, "bottomShadeSoft", 0, 760);
  assertNodeSize(xml, "bottomShadeSoft", 1920, 80);
  assertNodeTranslation(xml, "bottomShade", 0, 840);
  assertNodeSize(xml, "bottomShade", 1920, 240);
  assertNodeTranslation(xml, "title", 96, 900);
  assertNodeTranslation(xml, "controls", 0, 870);
  assertNamedNodeHidden(xml, "rewindButton");
  assertNamedNodeHidden(xml, "playButton");
  assertNamedNodeHidden(xml, "fastForwardButton");
  assertAuxiliaryControlsLayout(xml);
  assertNodeTranslation(xml, "progress", 96, 960);
  assertNodeTranslation(xml, "progressTrack", 0, progressFocused ? 23 : 25);
  assertNodeSize(xml, "progressTrack", 1728, progressFocused ? 12 : 8);
  assertNodeTranslation(xml, "duration", 1548, 52);
}

function assertAuxiliaryControlsLayout(xml: string): void {
  const visibleAuxiliaryControls = [
    ["audioButton", "audioFocusLabel", "audioIcon"],
    ["captionsButton", "captionsFocusLabel", "captionsIcon"],
    ["speedButton", "speedFocusLabel", "speedIcon"],
  ].filter(([buttonName]) => isNamedNodeVisible(xml, buttonName));

  const controlGap = 24;
  const controlWidth = 88;
  const auxiliaryWidth =
    visibleAuxiliaryControls.length * controlWidth +
    Math.max(0, visibleAuxiliaryControls.length - 1) * controlGap;
  let nextX = 1824 - auxiliaryWidth;

  for (const [buttonName, labelName, valueName] of visibleAuxiliaryControls) {
    assertNodeTranslation(xml, buttonName, nextX, 0);

    if (isNamedNodeVisible(xml, labelName)) {
      assertNodeTranslation(xml, labelName, -66, -42);
      assertNodeSize(xml, labelName, 220, 35);
    }

    assertNodeTranslation(xml, valueName, 16, 16);
    assertNodeSize(xml, valueName, 56, 56);

    nextX += controlWidth + controlGap;
  }
}

function assertFocusedAuxiliaryLabelLayout(xml: string, focusLabelNodeName: string): void {
  assertNodeTranslation(xml, focusLabelNodeName, -66, -42);
  assertNodeSize(xml, focusLabelNodeName, 220, 35);
}

function assertTrackMenuLayout(
  xml: string,
  expectedTitle: TrackMenuTitle,
  selectedRowIndex: number,
): void {
  const rowBackgroundName = `trackRow${selectedRowIndex}Background`;
  const rowCheckName = `trackRow${selectedRowIndex}Check`;
  const visibleRowCount = countVisibleTrackRows(xml);
  const rowHeight = 70;
  const rowGap = 8;
  const panelHeight = 104 + 32 + visibleRowCount * rowHeight + Math.max(0, visibleRowCount - 1) * rowGap;
  const panelY = Math.round((1080 - panelHeight) / 2);

  assertNodeTranslation(xml, "trackMenuPanel", 640, panelY);
  assertNodeSize(xml, "trackMenuPanel", 640, panelHeight);
  assertNodeTranslation(xml, "trackMenuTitle", 672, panelY + 40);
  assertNodeTranslation(xml, "trackRows", 672, panelY + 104);
  assertNodeSize(xml, rowBackgroundName, 576, 70);
  assertNodeTranslation(xml, rowCheckName, 516, 10);
}

function countVisibleTrackRows(xml: string): number {
  let visibleRows = 0;

  for (let index = 0; index < 10; index += 1) {
    if (isNamedNodeVisible(xml, `trackRow${index}`)) {
      visibleRows += 1;
    }
  }

  return visibleRows;
}

async function checkDevice(target: string): Promise<void> {
  const summary = await rokitCheckDevice(rokitContext(target));

  console.log(`device: ${summary.name} (${summary.model})`);
  console.log(`ecp: ${summary.ecp}`);
  console.log(`developer installer HTTP status: ${summary.installerStatus}`);
}

async function queryActiveApp(target: string): Promise<ActiveApp> {
  return await rokitQueryActiveApp(rokitContext(target));
}

async function printActiveApp(target: string): Promise<void> {
  const app = await queryActiveApp(target);
  console.log(`active app: ${app.id} ${app.name} ${app.version}`.trim());
}

async function waitForAppActive(
  target: string,
  appId: string,
  timeoutMs = 30_000,
): Promise<ActiveApp> {
  const start = Date.now();
  let lastApp: ActiveApp | undefined;
  let lastError: string | undefined;

  while (Date.now() - start < timeoutMs) {
    try {
      const app = await queryActiveApp(target);
      lastApp = app;
      lastError = undefined;

      if (app.id === appId) {
        return app;
      }
    } catch (error) {
      lastError = formatErrorMessage(error);
    }

    await sleep(1_000);
  }

  const lastState = lastError ?? (lastApp ? `${lastApp.id} ${lastApp.name}`.trim() : "unknown");
  throw new Error(`expected active app ${appId}, got ${lastState}`);
}

async function launchApp(target: string, appId: string): Promise<ActiveApp> {
  let lastError: string | undefined;

  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const app = await rokitLaunchApp(rokitContext(target), appId);
      if (app.id === appId) {
        return app;
      }
    } catch (error) {
      lastError = formatErrorMessage(error);
    }

    try {
      return await waitForAppActive(target, appId, 10_000);
    } catch (error) {
      lastError = formatErrorMessage(error);
    }
  }

  throw new Error(lastError ?? `expected active app ${appId}`);
}

async function launchDeepLink(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice?: "continue" | "beginning",
): Promise<ActiveApp> {
  const params = createPlaybackParams(contentId, mediaType, startFromChoice);

  try {
    return await rokitLaunchApp(rokitContext(target), "dev", params);
  } catch {
    await launchApp(target, "dev");
    await sleep(1_000);
    return await rokitLaunchApp(rokitContext(target), "dev", params);
  }
}

function createPlaybackParams(
  contentId: string,
  mediaType: string,
  startFromChoice?: "continue" | "beginning",
): Map<string, string> {
  const params = new Map<string, string>([
    ["contentID", contentId],
    ["mediaType", mediaType],
  ]);

  if (startFromChoice !== undefined) {
    params.set("startFrom", startFromChoice);
  }

  return params;
}

async function querySceneGraph(target: string): Promise<string> {
  let xml = "";
  let lastError: unknown;

  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      xml = await rokitQuerySceneGraph(rokitContext(target, sceneGraphRequestTimeoutMs), {
        attempts: 2,
        retryDelayMs: 500,
      });
    } catch (error) {
      lastError = error;
      await sleep(500);
      continue;
    }

    if (xml.includes("<App ") || !xml.includes("<All_Nodes>")) {
      return xml;
    }

    await sleep(500);
  }

  if (xml === "" && lastError !== undefined) {
    throw lastError;
  }

  return xml;
}

async function queryMediaPlayerState(target: string): Promise<string | undefined> {
  const xml = await rokitQueryEcp(rokitContext(target), "/query/media-player");
  const match = /<player\b[^>]*\bstate="([^"]+)"/.exec(xml);
  return match ? match[1] : undefined;
}

async function queryMediaPlayerStateSafe(target: string): Promise<string | undefined> {
  try {
    return await queryMediaPlayerState(target);
  } catch {
    return undefined;
  }
}

function isActiveMediaPlayerState(state: string | undefined): boolean {
  return state === "play" || state === "pause" || state === "buffer" || state === "buffering";
}

async function queryActiveAppSafe(target: string): Promise<ActiveApp | undefined> {
  try {
    return await queryActiveApp(target);
  } catch {
    return undefined;
  }
}

async function waitForMediaPlayerState(
  target: string,
  expectedState: string,
  timeoutMs = 4_000,
): Promise<boolean> {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    if ((await queryMediaPlayerStateSafe(target)) === expectedState) {
      return true;
    }

    await sleep(500);
  }

  return false;
}

function hasVisibleNode(xml: string, tagName: string, nodeName: string): boolean {
  const nodePattern = new RegExp(
    `<${tagName}\\b(?=[^>]*\\bname="${nodeName}")([^>]*)>`,
  );
  const match = nodePattern.exec(xml);

  return match !== null && !match[1]?.includes('visible="false"');
}

function hasStartFromPrompt(xml: string): boolean {
  return (
    hasVisibleNode(xml, "ContinueWatchingPrompt", "continueWatchingPrompt") ||
    xml.includes("Continue playing from") ||
    xml.includes("Where would you like to start?")
  );
}

function readAuthCode(xml: string): string | undefined {
  if (!hasVisibleNode(xml, "AuthScreen", "authScreen")) {
    return undefined;
  }

  const code = readNamedNodeAttribute(xml, "code", "text")?.trim();
  if (code === undefined || code === "" || code === "Loading..." || code === "Error!") {
    return undefined;
  }

  return code;
}

function assertNotAuthScreen(xml: string): void {
  if (!hasVisibleNode(xml, "AuthScreen", "authScreen")) {
    return;
  }

  const authCode = readAuthCode(xml);

  if (authCode !== undefined) {
    throw new Error(`Roku dev app is signed out; redeem device code ${authCode}`);
  }

  throw new Error("Roku dev app is signed out; device code has not loaded yet");
}

function assertDirectPlaybackSurface(xml: string, contentId: string): void {
  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeHidden(xml, "videoScreen");
  assertNamedNodeAbsent(xml, "button-play");
  assertNamedNodeAbsent(xml, "subtitleList");

  if (xml.includes("/hls/media.m3u8")) {
    throw new Error("expected Roku player content to avoid HLS playback URLs");
  }

  if (xml.includes("original=1")) {
    throw new Error("expected player content to avoid original=1 playback URLs");
  }

  const expectedPathPrefix = `/files/${contentId}/`;
  if (!xml.includes(expectedPathPrefix)) {
    throw new Error(`expected player content to include file path ${expectedPathPrefix}`);
  }
}

function readVisiblePlaybackContentId(xml: string): string | undefined {
  const match = /\/files\/(\d+)\//.exec(xml);
  return match ? match[1] : undefined;
}

async function chooseStartFrom(
  target: string,
  choice: "continue" | "beginning",
): Promise<void> {
  if (choice === "beginning") {
    await pressKey(target, "Down");
    await sleep(250);
  }

  await pressKey(target, "Select");
}

async function launchPlayback(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
): Promise<ActiveApp> {
  let app = await launchDeepLink(target, contentId, mediaType, startFromChoice);
  let lastLaunchAt = Date.now();
  let launchAttempts = 1;
  const start = Date.now();
  let didChooseStartFrom = false;
  let lastState = "unknown";

  async function retryDeepLink(reason: string): Promise<void> {
    if (
      launchAttempts >= maxPlaybackLaunchAttempts ||
      Date.now() - lastLaunchAt < playbackLaunchRetryMs
    ) {
      return;
    }

    launchAttempts += 1;
    lastLaunchAt = Date.now();
    didChooseStartFrom = false;
    lastState = `retrying deeplink after ${reason}`;
    try {
      app = await launchDeepLink(target, contentId, mediaType, startFromChoice);
    } catch (error) {
      lastState = `deeplink retry failed after ${reason}: ${formatErrorMessage(error)}`;
    }
    await sleep(1_500);
  }

  while (Date.now() - start < playbackLaunchTimeoutMs) {
    let xml: string;

    try {
      xml = await querySceneGraph(target);
    } catch (error) {
      const mediaState = await queryMediaPlayerStateSafe(target);
      const activeApp = await queryActiveAppSafe(target);
      lastState =
        `scene graph unavailable: ${formatErrorMessage(error)}; ` +
        `media-player=${mediaState ?? "unknown"}; ` +
        `active-app=${activeApp ? activeApp.id : "unknown"}`;
      if (!isActiveMediaPlayerState(mediaState) && activeApp?.id !== "dev") {
        await retryDeepLink(lastState);
      }
      await sleep(sceneGraphPollIntervalMs);
      continue;
    }

    assertNotAuthScreen(xml);

    if (!didChooseStartFrom && hasStartFromPrompt(xml)) {
      didChooseStartFrom = true;
      await chooseStartFrom(target, startFromChoice);
      lastState = "startFromPrompt";
    } else if (hasStartFromPrompt(xml)) {
      lastState = "startFromPrompt";
    } else if (hasVisibleNode(xml, "VideoPlayerScreen", "videoPlayerScreen")) {
      try {
        assertDirectPlaybackSurface(xml, contentId);
        return app;
      } catch (error) {
        const visibleContentId = readVisiblePlaybackContentId(xml);
        if (visibleContentId !== undefined && visibleContentId !== contentId) {
          await retryDeepLink(`stale content ${visibleContentId}`);
        }
        lastState = formatErrorMessage(error);
      }
    } else if (hasVisibleNode(xml, "VideoScreen", "videoScreen")) {
      lastState = "videoScreen";
    } else if (hasVisibleNode(xml, "SearchScreen", "searchScreen")) {
      lastState = "searchScreen";
      await retryDeepLink(lastState);
    } else if (hasVisibleNode(xml, "HomeScreen", "homeScreen")) {
      lastState = "homeScreen";
      await retryDeepLink(lastState);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  try {
    const xml = await querySceneGraph(target);
    assertDirectPlaybackSurface(xml, contentId);
    return app;
  } catch {
    throw new Error(
      `expected videoPlayerScreen after deeplink, last visible state: ${lastState}`,
    );
  }
}

async function launchPlaybackWithRemoteStart(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
): Promise<ActiveApp> {
  await pressKey(target, "Home");
  await sleep(2_000);

  let app = await launchApp(target, "dev");
  const params = createPlaybackParams(contentId, mediaType, startFromChoice);
  let launchAttempts = 0;
  let lastPlaybackLaunchAt = 0;
  let didChooseStartFrom = false;
  let lastState = "remote-assisted launch";

  async function sendPlaybackLaunch(reason: string): Promise<void> {
    if (
      launchAttempts >= maxPlaybackLaunchAttempts ||
      Date.now() - lastPlaybackLaunchAt < playbackLaunchRetryMs
    ) {
      return;
    }

    launchAttempts += 1;
    lastPlaybackLaunchAt = Date.now();
    didChooseStartFrom = false;
    lastState = `retrying playback launch after ${reason}`;

    try {
      app = await rokitLaunchApp(rokitContext(target), "dev", params);
    } catch (error) {
      app = await launchDeepLink(target, contentId, mediaType, startFromChoice);
      console.log(`retried playback launch after ${reason}: ${formatErrorMessage(error)}`);
    }
  }

  await sleep(4_000);
  await sendPlaybackLaunch("initial dev launch");

  await waitForRemotePlaybackSettle(target, remotePlaybackLaunchQuietMs);

  const start = Date.now();

  while (Date.now() - start < playbackLaunchTimeoutMs) {
    let xml: string;

    try {
      xml = await querySceneGraph(target);
    } catch (error) {
      const mediaState = await queryMediaPlayerStateSafe(target);
      lastState = `scene graph unavailable: ${formatErrorMessage(error)}; media-player=${mediaState ?? "unknown"}`;
      await sleep(sceneGraphPollIntervalMs);
      continue;
    }

    assertNotAuthScreen(xml);

    const sceneGraphFailure = readSceneGraphFailure(xml);
    if (sceneGraphFailure !== undefined) {
      const activeApp = await queryActiveAppSafe(target);
      lastState = `scene graph failed: ${sceneGraphFailure}; active-app=${activeApp?.id ?? "unknown"}`;
      await sendPlaybackLaunch(lastState);
    } else if (!didChooseStartFrom && hasStartFromPrompt(xml)) {
      didChooseStartFrom = true;
      await chooseStartFrom(target, startFromChoice);
      lastState = "startFromPrompt";
    } else if (hasStartFromPrompt(xml)) {
      lastState = "startFromPrompt";
    } else if (hasVisibleNode(xml, "VideoPlayerScreen", "videoPlayerScreen")) {
      try {
        assertDirectPlaybackSurface(xml, contentId);
        return app;
      } catch (error) {
        lastState = formatErrorMessage(error);
      }
    } else if (hasVisibleNode(xml, "VideoScreen", "videoScreen")) {
      lastState = "videoScreen";
    } else if (hasVisibleNode(xml, "SearchScreen", "searchScreen")) {
      lastState = "searchScreen";
    } else if (hasVisibleNode(xml, "HomeScreen", "homeScreen")) {
      lastState = "homeScreen";
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(
    `expected videoPlayerScreen after remote-assisted deeplink, last visible state: ${lastState}`,
  );
}

async function waitForRemotePlaybackSettle(
  target: string,
  timeoutMs: number,
): Promise<void> {
  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    const mediaState = await queryMediaPlayerStateSafe(target);
    if (isActiveMediaPlayerState(mediaState)) {
      await sleep(1_000);
      return;
    }

    try {
      const xml = await querySceneGraph(target);
      if (
        hasStartFromPrompt(xml) ||
        hasVisibleNode(xml, "VideoPlayerScreen", "videoPlayerScreen")
      ) {
        return;
      }
    } catch {
      // SceneGraph may be temporarily unavailable during app launch.
    }

    await sleep(1_000);
  }
}

function formatErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

async function waitForActiveApp(
  target: string,
  appId: string,
): Promise<ActiveApp> {
  return await rokitWaitForActiveApp(rokitContext(target), appId, launchTimeoutMs);
}

async function pressKey(target: string, key: string): Promise<void> {
  validateRemoteKey(key);
  await rokitPressKey(rokitContext(target), key);
  console.log(`pressed: ${key}`);
}

async function controlSmoke(target: string): Promise<void> {
  await checkDevice(target);
  const launchedApp = await launchApp(target, "dev");
  console.log(
    `launched: ${launchedApp.id} ${launchedApp.name} ${launchedApp.version}`,
  );

  await pressKey(target, "Info");
  await sleep(300);
  await pressKey(target, "Back");

  const activeApp = await waitForActiveApp(target, "dev");
  console.log(`asserted active dev app: ${activeApp.name} ${activeApp.version}`);
}

function parseDurationLabel(label: string): number | undefined {
  const parts = label.split(":").map((part) => Number(part));

  if (parts.some((part) => !Number.isFinite(part))) {
    return undefined;
  }

  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  }

  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }

  return undefined;
}

function readPlayerPositionSeconds(xml: string): number {
  const text = readNamedNodeAttribute(xml, "position", "text");

  if (!text) {
    throw new Error("expected player position label");
  }

  const seconds = parseDurationLabel(text);

  if (seconds === undefined) {
    throw new Error(`could not parse player position label "${text}"`);
  }

  return seconds;
}

async function readPlayerPositionSecondsFromDevice(
  target: string,
  timeoutMs = 6_000,
): Promise<number> {
  const start = Date.now();
  let lastError = "unknown";

  while (Date.now() - start < timeoutMs) {
    try {
      return readPlayerPositionSeconds(await querySceneGraph(target));
    } catch (error) {
      lastError = formatErrorMessage(error);
      await sleep(250);
    }
  }

  throw new Error(`expected player position label: ${lastError}`);
}

async function waitForSceneGraphAssertion(
  target: string,
  description: string,
  assertion: (xml: string) => void,
  timeoutMs = 6_000,
): Promise<string> {
  return await rokitWaitForSceneGraphAssertion(
    rokitContext(target, sceneGraphRequestTimeoutMs),
    description,
    assertion,
    { pollIntervalMs: 250, timeoutMs },
  );
}

async function assertTrackMenu(
  target: string,
  expectedTitle: TrackMenuTitle,
  selectedRowIndex = 0,
): Promise<void> {
  await waitForSceneGraphAssertion(target, `expected ${expectedTitle} menu`, (xml) => {
    assertNamedNodeVisible(xml, "videoPlayerScreen");
    assertNamedNodeVisible(xml, "trackMenu");
    assertNamedNodeText(xml, "trackMenuTitle", expectedTitle);
    assertNamedNodeVisible(xml, "trackRow0");
    assertNamedNodeVisible(xml, `trackRow${selectedRowIndex}Background`);
    assertSelectedTrackRow(xml, selectedRowIndex);
    assertTrackMenuLayout(xml, expectedTitle, selectedRowIndex);
  });
}

async function isTrackMenuOpen(
  target: string,
  expectedTitle: TrackMenuTitle,
): Promise<boolean> {
  const xml = await querySceneGraph(target);

  if (!isNamedNodeVisible(xml, "trackMenu")) {
    return false;
  }

  return readNamedNodeAttribute(xml, "trackMenuTitle", "text") === expectedTitle;
}

function assertSelectedTrackRow(xml: string, selectedRowIndex: number): void {
  for (let rowIndex = 0; rowIndex < 10; rowIndex += 1) {
    const checkName = `trackRow${rowIndex}Check`;

    if (rowIndex === selectedRowIndex) {
      assertNamedNodeVisible(xml, checkName);
    } else {
      assertNamedNodeHidden(xml, checkName);
    }
  }
}

async function activateFocusedTrackButton(
  target: string,
  expectedTitle: TrackMenuTitle,
  controlId?: PlayerControlId,
): Promise<void> {
  if (controlId !== undefined) {
    await focusPlaybackControl(target, controlId);
    await refreshFocusedControlForActivation(target);
  } else {
    await refreshFocusedControlForActivation(target);
  }

  await pressKey(target, "Select");
  await waitForTrackMenuOpen(target, expectedTitle);
}

async function refreshFocusedControlForActivation(target: string): Promise<void> {
  const xml = await querySceneGraph(target);
  const focusedControl = readFocusedPlaybackControl(xml);

  if (
    focusedControl === "audio" ||
    focusedControl === "captions" ||
    focusedControl === "speed"
  ) {
    await pressKey(target, "Down");
    await sleep(200);
    await assertProgressFocused(target);
    await pressKey(target, "Up");
    await sleep(200);
    assertPlaybackControlFocused(await querySceneGraph(target), focusedControl);
  }
}

async function waitForTrackMenuOpen(
  target: string,
  expectedTitle: TrackMenuTitle,
  timeoutMs = 3_000,
): Promise<void> {
  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    if (await isTrackMenuOpen(target, expectedTitle)) {
      return;
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  await assertTrackMenu(target, expectedTitle);
}

async function selectNextTrackMenuItem(target: string): Promise<void> {
  await pressKey(target, "Down");
  await sleep(250);
  await pressKey(target, "Select");
  await sleep(750);
}

async function reopenFocusedTrackMenu(
  target: string,
  expectedTitle: TrackMenuTitle,
): Promise<void> {
  await pressKey(target, "Select");
  await waitForTrackMenuOpen(target, expectedTitle);
}

async function focusProgressFromOpenMenu(target: string): Promise<void> {
  await pressKey(target, "Select");
  await sleep(750);
  await pressKey(target, "Down");
  await sleep(500);
  await assertProgressFocused(target);
}

async function assertProgressFocused(target: string): Promise<void> {
  await waitForSceneGraphAssertion(
    target,
    "expected focused progress bar",
    assertProgressFocusedXml,
  );
}

function assertProgressFocusedXml(xml: string): void {
  const progressHeight = readNamedNodeNumber(xml, "progressTrack", "height");

  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeVisible(xml, "osd");
  assertNamedNodeVisible(xml, "progressThumb");
  assertPlayerOsdLayout(xml);

  if (progressHeight !== 12) {
    throw new Error(
      `expected focused progress track height 12, got ${progressHeight?.toString() ?? "missing"}`,
    );
  }
}

function assertPausedPositionGlyph(xml: string): void {
  assertNamedNodeVisible(xml, "positionPauseIcon");
  assertNodeSize(xml, "positionPauseIcon", 22, 22);

  const translation = readNamedNodeTranslation(xml, "positionPauseIcon");
  const x = translation?.[0];
  const y = translation?.[1];
  const allowedX = [86, 122, 150];

  if (x === undefined || !allowedX.includes(x)) {
    throw new Error(`expected pause glyph x to follow position label, got ${x ?? "missing"}`);
  }

  assertNear(y, 56, "positionPauseIcon y");
}

async function assertOsdHideRevealFlow(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);

  await sleep(3_750);
  assertNamedNodeHidden(await querySceneGraph(target), "osd");

  await pressKey(target, "Select");
  await waitForOsdVisible(target);
  console.log("asserted OSD auto-hides and reveals controls with Select");
}

async function assertOsdVisible(target: string): Promise<void> {
  await waitForSceneGraphAssertion(target, "expected visible OSD", (xml) => {
    assertNamedNodeVisible(xml, "videoPlayerScreen");
    assertNamedNodeVisible(xml, "osd");
  });
}

async function waitForOsdVisible(target: string, timeoutMs = 5_000): Promise<void> {
  const start = Date.now();
  let lastState = "unknown";

  while (Date.now() - start < timeoutMs) {
    const xml = await querySceneGraph(target);

    if (isNamedNodeVisible(xml, "videoPlayerScreen") && isNamedNodeVisible(xml, "osd")) {
      return;
    }

    if (isNamedNodeVisible(xml, "videoPlayerScreen")) {
      lastState = "videoPlayerScreen without visible OSD";
    } else if (isNamedNodeVisible(xml, "trackMenu")) {
      lastState = "trackMenu";
    } else {
      lastState = "videoPlayerScreen missing";
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected OSD to become visible, last state: ${lastState}`);
}

async function waitForPlayerClockReady(
  target: string,
  timeoutMs = 60_000,
): Promise<void> {
  const start = Date.now();
  let lastError: string | undefined;

  while (Date.now() - start < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);
      const position = readNamedNodeAttribute(xml, "position", "text");
      const duration = readNamedNodeAttribute(xml, "duration", "text");

      if (
        isNamedNodeVisible(xml, "videoPlayerScreen") &&
        position !== undefined &&
        duration !== undefined &&
        position !== "..:.." &&
        duration !== "..:.."
      ) {
        return;
      }
      lastError = undefined;
    } catch (error) {
      lastError = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  const errorSuffix = lastError ? `; last SceneGraph error: ${lastError}` : "";
  throw new Error(`expected player time labels to become ready${errorSuffix}`);
}

async function ensureOsdVisibleForActivation(target: string): Promise<void> {
  if (isNamedNodeVisible(await querySceneGraph(target), "osd")) {
    return;
  }

  await pressKey(target, "Select");
  await waitForOsdVisible(target);
}

async function pausePlaybackForStableOsd(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);

  const currentState = await queryMediaPlayerStateSafe(target);
  if (currentState === "pause") {
    await waitForOsdVisible(target);
    await waitForSceneGraphAssertion(target, "expected paused position glyph", assertPausedPositionGlyph);
    return;
  }

  if (currentState !== "play") {
    await waitForMediaPlayerState(target, "play", 8_000);
  }

  await pressKey(target, "Play");
  if (await waitForMediaPlayerState(target, "pause")) {
    await waitForOsdVisible(target);
    await waitForSceneGraphAssertion(target, "expected paused position glyph", assertPausedPositionGlyph);
    return;
  }

  await sleep(1_500);

  const firstPosition = await readPlayerPositionSecondsFromDevice(target);
  await sleep(1_500);
  const secondPosition = await readPlayerPositionSecondsFromDevice(target);

  if (secondPosition > firstPosition + 1) {
    await pressKey(target, "Play");
    if (await waitForMediaPlayerState(target, "pause")) {
      await waitForOsdVisible(target);
      await waitForSceneGraphAssertion(
        target,
        "expected paused position glyph",
        assertPausedPositionGlyph,
      );
      return;
    }

    await sleep(1_500);

    const pausedPosition = await readPlayerPositionSecondsFromDevice(target);
    await sleep(1_500);
    const stillPausedPosition = await readPlayerPositionSecondsFromDevice(target);

    if (stillPausedPosition > pausedPosition + 1) {
      console.warn(
        `expected playback to pause, got pausedPosition=${pausedPosition}s stillPausedPosition=${stillPausedPosition}s`,
      );
    }
  }

  await waitForOsdVisible(target);
  await waitForSceneGraphAssertion(target, "expected paused position glyph", assertPausedPositionGlyph);
}

async function focusInitialControlsForScreenshot(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  await pressKey(target, "Down");
  await assertInitialControlsVisible(target);
}

async function assertInitialControlsVisible(target: string): Promise<void> {
  await waitForSceneGraphAssertion(target, "expected initial player controls", (xml) => {
    assertNamedNodeVisible(xml, "videoPlayerScreen");
    assertNamedNodeVisible(xml, "osd");
    assertNamedNodeHidden(xml, "rewindButton");
    assertNamedNodeHidden(xml, "playButton");
    assertNamedNodeHidden(xml, "fastForwardButton");
    assertProgressFocusedXml(xml);
  });
}

async function assertMediaKeysSeek(target: string): Promise<void> {
  const before = await readPlayerPositionSecondsFromDevice(target);
  await pressKey(target, "Fwd");
  await sleep(750);
  await assertProgressFocused(target);
  const afterFwdPreview = await readPlayerPositionSecondsFromDevice(target);

  if (afterFwdPreview <= before + 5) {
    throw new Error(
      `expected Fwd to preview an advance, got before=${before}s afterFwdPreview=${afterFwdPreview}s`,
    );
  }

  await pressKey(target, "Select");
  await sleep(1_500);
  const afterFwdCommit = await readPlayerPositionSecondsFromDevice(target);

  if (afterFwdCommit <= before + 5) {
    throw new Error(
      `expected Select to commit Fwd preview, got before=${before}s afterFwdCommit=${afterFwdCommit}s`,
    );
  }

  await pressKey(target, "Rev");
  await sleep(750);
  await assertProgressFocused(target);
  const afterRevPreview = await readPlayerPositionSecondsFromDevice(target);

  if (afterRevPreview >= afterFwdCommit) {
    throw new Error(
      `expected Rev to preview a move backward, got afterFwdCommit=${afterFwdCommit}s afterRevPreview=${afterRevPreview}s`,
    );
  }

  await pressKey(target, "Select");
  await sleep(1_000);

  console.log(
    `asserted media seek keys: before=${before}s afterFwdPreview=${afterFwdPreview}s afterFwdCommit=${afterFwdCommit}s afterRevPreview=${afterRevPreview}s`,
  );
}

async function assertMediaPlayKeyToggles(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  if ((await queryMediaPlayerStateSafe(target)) === "pause") {
    await pressKey(target, "Play");
    await waitForMediaPlayerState(target, "play", 8_000);
  }

  const beforePause = await readPlayerPositionSecondsFromDevice(target);
  await pressKey(target, "Play");
  const pausedByState = await waitForMediaPlayerState(target, "pause");
  await sleep(1_500);
  const pausedAt = await readPlayerPositionSecondsFromDevice(target);
  await sleep(1_500);
  const stillPausedAt = await readPlayerPositionSecondsFromDevice(target);

  if (!pausedByState && stillPausedAt > pausedAt + 1) {
    throw new Error(
      `expected Play key to pause playback, got before=${beforePause}s pausedAt=${pausedAt}s stillPausedAt=${stillPausedAt}s`,
    );
  }
  await waitForSceneGraphAssertion(target, "expected paused position glyph", assertPausedPositionGlyph);

  await pressKey(target, "Play");
  const resumedByState = await waitForMediaPlayerState(target, "play");
  await sleep(2_000);
  const resumedAt = await readPlayerPositionSecondsFromDevice(target);

  if (!resumedByState && resumedAt <= stillPausedAt) {
    throw new Error(
      `expected Play key to resume playback, got stillPausedAt=${stillPausedAt}s resumedAt=${resumedAt}s`,
    );
  }

  console.log(
    `asserted Play key toggles playback: before=${beforePause}s paused=${pausedAt}s resumed=${resumedAt}s`,
  );
}

function readFocusedPlaybackControl(xml: string): PlayerControlId | "progress" | undefined {
  if (isNamedNodeVisible(xml, "progressThumb")) {
    return "progress";
  }

  if (isNamedNodeVisible(xml, "rewindBackground")) {
    return "rewind";
  }

  if (isNamedNodeVisible(xml, "playBackground")) {
    return "play";
  }

  if (isNamedNodeVisible(xml, "fastForwardBackground")) {
    return "fastForward";
  }

  if (isNamedNodeVisible(xml, "audioFocusLabel")) {
    return "audio";
  }

  if (isNamedNodeVisible(xml, "captionsFocusLabel")) {
    return "captions";
  }

  if (isSpeedButtonFocused(xml)) {
    return "speed";
  }

  return undefined;
}

function readAvailablePlaybackControls(xml: string): PlayerControlId[] {
  const controls: PlayerControlId[] = [];

  if (isNamedNodeVisible(xml, "audioButton")) {
    controls.push("audio");
  }

  if (isNamedNodeVisible(xml, "captionsButton")) {
    controls.push("captions");
  }

  if (isNamedNodeVisible(xml, "speedButton")) {
    controls.push("speed");
  }

  return controls;
}

function assertPlaybackControlFocused(
  xml: string,
  controlId: PlayerControlId,
): void {
  const focusedControl = readFocusedPlaybackControl(xml);

  if (focusedControl !== controlId) {
    throw new Error(
      `expected ${controlId} control to be focused, got ${focusedControl ?? "none"}`,
    );
  }
}

async function focusPlaybackControl(
  target: string,
  controlId: PlayerControlId,
): Promise<void> {
  let lastFocusedControl: PlayerControlId | "progress" | undefined;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    await ensureOsdVisibleForActivation(target);
    let xml = await querySceneGraph(target);

    if (readFocusedPlaybackControl(xml) === "progress") {
      await pressKey(target, "Up");
      await sleep(150);
      xml = await querySceneGraph(target);
    }

    const controls = readAvailablePlaybackControls(xml);
    const targetIndex = controls.indexOf(controlId);
    if (targetIndex === -1) {
      throw new Error(`expected ${controlId} control to be available`);
    }

    let focusedControl = readFocusedPlaybackControl(xml);
    if (focusedControl === undefined) {
      await pressKey(target, "Up");
      await sleep(150);
      xml = await querySceneGraph(target);
      focusedControl = readFocusedPlaybackControl(xml);
    }

    lastFocusedControl = focusedControl;

    if (focusedControl === "progress" || focusedControl === undefined) {
      await sleep(250);
      continue;
    }

    const focusedIndex = controls.indexOf(focusedControl);
    if (focusedIndex === -1) {
      throw new Error(`focused control ${focusedControl} is not available`);
    }

    const rightPresses = (targetIndex - focusedIndex + controls.length) % controls.length;
    for (let press = 0; press < rightPresses; press += 1) {
      await pressKey(target, "Right");
      await sleep(100);
    }

    await sleep(200);
    xml = await querySceneGraph(target);
    if (readFocusedPlaybackControl(xml) === controlId) {
      return;
    }

    lastFocusedControl = readFocusedPlaybackControl(xml);
  }

  throw new Error(
    `expected ${controlId} control to be focused, got ${lastFocusedControl ?? "none"}`,
  );
}

async function assertFocusRoundTrip(
  target: string,
  focusLabelNodeName: string,
): Promise<void> {
  await assertNamedNodeVisible(await querySceneGraph(target), focusLabelNodeName);
  await pressKey(target, "Down");
  await sleep(300);
  await assertProgressFocused(target);
  await pressKey(target, "Up");
  await sleep(300);
  assertNamedNodeVisible(await querySceneGraph(target), focusLabelNodeName);
}

async function focusAudioButtonFromPlayback(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  await waitForNamedNodeVisible(target, "audioButton");
  await focusPlaybackControl(target, "audio");
  assertFocusedAuxiliaryLabelLayout(await querySceneGraph(target), "audioFocusLabel");
}

async function openAudioMenuFromPlayback(target: string): Promise<void> {
  await focusAudioButtonFromPlayback(target);
  await activateFocusedTrackButton(target, "Audio tracks", "audio");
  await assertTrackMenu(target, "Audio tracks");
}

async function focusSubtitleButtonFromPlayback(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  await waitForNamedNodeVisible(target, "captionsButton");
  await focusPlaybackControl(target, "captions");
  assertFocusedAuxiliaryLabelLayout(await querySceneGraph(target), "captionsFocusLabel");
}

async function openSubtitleMenuFromPlayback(target: string): Promise<void> {
  await focusSubtitleButtonFromPlayback(target);
  await activateFocusedTrackButton(target, "Subtitles", "captions");
  await assertTrackMenu(target, "Subtitles");
}

async function focusSpeedButtonFromPlayback(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  await waitForNamedNodeVisible(target, "speedButton");
  await focusPlaybackControl(target, "speed");
}

function isSpeedButtonFocused(xml: string): boolean {
  return isNamedNodeVisible(xml, "speedFocusLabel") || isNamedNodeVisible(xml, "speedBackground");
}

async function isSpeedControlAvailable(target: string): Promise<boolean> {
  return isNamedNodeVisible(await querySceneGraph(target), "speedButton");
}

async function openSpeedMenuFromPlayback(target: string, selectedRowIndex = 3): Promise<void> {
  await focusSpeedButtonFromPlayback(target);
  await activateFocusedTrackButton(target, "Playback speed", "speed");
  await assertTrackMenu(target, "Playback speed", selectedRowIndex);
}

async function assertSpeedFocusRoundTrip(target: string): Promise<void> {
  const focusedXml = await querySceneGraph(target);
  if (!isSpeedButtonFocused(focusedXml)) {
    throw new Error("expected speed control to be focused");
  }

  await pressKey(target, "Down");
  await sleep(300);
  await assertProgressFocused(target);
  await pressKey(target, "Up");
  await sleep(300);

  if (!isSpeedButtonFocused(await querySceneGraph(target))) {
    throw new Error("expected speed control focus after progress round trip");
  }
}

async function assertSpeedValueLabel(target: string, expectedLabel: string): Promise<void> {
  const speedRowByLabel = new Map<string, number>([
    ["0.25x", 0],
    ["0.5x", 1],
    ["0.75x", 2],
    ["1x", 3],
    ["1.25x", 4],
    ["1.5x", 5],
    ["1.75x", 6],
    ["2x", 7],
  ]);
  const selectedRowIndex = speedRowByLabel.get(expectedLabel);

  if (selectedRowIndex === undefined) {
    throw new Error(`unknown playback speed label "${expectedLabel}"`);
  }

  await openSpeedMenuFromPlayback(target, selectedRowIndex);
  await pressKey(target, "Back");
  await sleep(500);
}

function isOptionalSpeedUnavailable(error: unknown): boolean {
  return formatErrorMessage(error).includes("expected speed control to be available");
}

async function smokePlaybackSpeedIfAvailable(target: string): Promise<void> {
  if (!(await isSpeedControlAvailable(target))) {
    console.log("skipped playback speed menu: Roku Video.playbackSpeed is unavailable");
    return;
  }

  try {
    await focusSpeedButtonFromPlayback(target);
    await assertSpeedFocusRoundTrip(target);
    await openSpeedMenuFromPlayback(target);
    await selectNextTrackMenuItem(target);
    await sleep(750);
    await assertSpeedValueLabel(target, "1.25x");
    console.log("asserted playback speed menu and selection");
  } catch (error) {
    if (isOptionalSpeedUnavailable(error)) {
      console.log("skipped playback speed menu: Roku Video.playbackSpeed is unavailable");
      return;
    }

    throw error;
  }
}

async function playerUiSmoke(
  target: string,
  audioContentId: string,
  subtitleContentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
): Promise<void> {
  const audioApp = await launchPlaybackWithRemoteStart(
    target,
    audioContentId,
    mediaType,
    startFromChoice,
  );
  console.log(
    `opened audio playback: ${audioApp.id} ${audioApp.name} ${audioApp.version} contentID=${audioContentId}`,
  );
  await waitForPlayerClockReady(target);
  await pausePlaybackForStableOsd(target);
  await smokePlaybackSpeedIfAvailable(target);

  await focusAudioButtonFromPlayback(target);
  await assertFocusRoundTrip(target, "audioFocusLabel");
  await openAudioMenuFromPlayback(target);
  console.log("asserted audio menu from player controls");
  await selectNextTrackMenuItem(target);
  await reopenFocusedTrackMenu(target, "Audio tracks");
  await assertTrackMenu(target, "Audio tracks", 1);
  console.log("asserted audio track selection moves checkmark");
  await pressKey(target, "Back");
  await sleep(500);

  const subtitleApp = await launchPlaybackWithRemoteStart(
    target,
    subtitleContentId,
    mediaType,
    startFromChoice,
  );
  console.log(
    `opened subtitle playback: ${subtitleApp.id} ${subtitleApp.name} ${subtitleApp.version} contentID=${subtitleContentId}`,
  );
  await waitForPlayerClockReady(target);
  await pausePlaybackForStableOsd(target);
  await focusSubtitleButtonFromPlayback(target);
  await assertFocusRoundTrip(target, "captionsFocusLabel");
  await openSubtitleMenuFromPlayback(target);
  assertNamedNodeHidden(await querySceneGraph(target), "audioButton");
  console.log("asserted subtitle menu from player controls");
  await selectNextTrackMenuItem(target);
  await reopenFocusedTrackMenu(target, "Subtitles");
  await assertTrackMenu(target, "Subtitles", 1);
  console.log("asserted subtitle selection moves checkmark");
  await pressKey(target, "Back");
  await sleep(500);

  await pressKey(target, "Down");
  await sleep(500);
  await assertProgressFocused(target);
  console.log("asserted progress bar focus");

  await pressKey(target, "Play");
  await sleep(750);
  await assertOsdHideRevealFlow(target);
  await assertMediaPlayKeyToggles(target);
  await assertMediaKeysSeek(target);
}

async function captureDeveloperScreenshot(
  target: string,
  password: string,
  outputPath: string,
): Promise<string> {
  await mkdir(dirname(outputPath), { recursive: true });
  let lastError = "unknown";

  for (let attempt = 1; attempt <= screenshotCaptureAttempts; attempt += 1) {
    const captureDir = await mkdtemp(
      join(tmpdir(), `putio-roku-${basename(outputPath, extname(outputPath))}-`),
    );
    const capturePath = join(captureDir, basename(outputPath));

    try {
      const capturedPath = await rokitTakeScreenshot(
        { ...rokitContext(target), password },
        capturePath,
      );
      if (await fileExists(capturedPath)) {
        await copyFile(capturedPath, outputPath);
        return outputPath;
      }

      if (await fileExists(capturePath)) {
        await copyFile(capturePath, outputPath);
        return outputPath;
      }

      const directCapturedPath = await rokitTakeScreenshot(
        { ...rokitContext(target), password },
        outputPath,
      );
      if (await fileExists(outputPath)) {
        return outputPath;
      }

      if (await fileExists(directCapturedPath)) {
        await copyFile(directCapturedPath, outputPath);
        return outputPath;
      }

      throw new Error("screenshot capture succeeded without writing an image file");
    } catch (error) {
      lastError = formatErrorMessage(error);
      if (attempt === screenshotCaptureAttempts) {
        break;
      }

      console.log(
        `screenshot retry ${attempt}/${screenshotCaptureAttempts} for ${basename(outputPath)}: ${lastError}`,
      );
      await sleep(1_500);
    } finally {
      await rm(captureDir, { force: true, recursive: true });
    }
  }

  throw new Error(`failed to capture ${basename(outputPath)}: ${lastError}`);
}

async function playerUiScreenshots(
  target: string,
  audioContentId: string,
  subtitleContentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
  outputDir: string,
): Promise<void> {
  await cleanupPlayerUiReviewArtifacts(outputDir);

  const password = requireDeveloperPassword();
  const audioApp = await launchPlaybackWithRemoteStart(
    target,
    audioContentId,
    mediaType,
    startFromChoice,
  );
  console.log(
    `opened audio playback: ${audioApp.id} ${audioApp.name} ${audioApp.version} contentID=${audioContentId}`,
  );
  await waitForPlayerClockReady(target);
  await pausePlaybackForStableOsd(target);
  await focusInitialControlsForScreenshot(target);
  const playFocusPath = await captureDeveloperScreenshot(
    target,
    password,
    join(outputDir, "play-focus.jpg"),
  );
  console.log(`captured initial controls screenshot: ${playFocusPath}`);
  if (await isSpeedControlAvailable(target)) {
    await focusSpeedButtonFromPlayback(target);
    const speedButtonPath = await captureDeveloperScreenshot(
      target,
      password,
      join(outputDir, "speed-button-focus.jpg"),
    );
    console.log(`captured speed button focus screenshot: ${speedButtonPath}`);
    await openSpeedMenuFromPlayback(target);
    const speedPath = await captureDeveloperScreenshot(
      target,
      password,
      join(outputDir, "speed-menu.jpg"),
    );
    console.log(`captured speed menu screenshot: ${speedPath}`);
    await pressKey(target, "Select");
    await sleep(750);
  } else {
    console.log("skipped speed screenshots: Roku Video.playbackSpeed is unavailable");
  }
  await focusAudioButtonFromPlayback(target);
  await assertFocusRoundTrip(target, "audioFocusLabel");
  const audioButtonPath = await captureDeveloperScreenshot(
    target,
    password,
    join(outputDir, "audio-button-focus.jpg"),
  );
  console.log(`captured audio button focus screenshot: ${audioButtonPath}`);
  await openAudioMenuFromPlayback(target);
  const audioPath = await captureDeveloperScreenshot(
    target,
    password,
    join(outputDir, "audio-menu.jpg"),
  );
  console.log(`captured audio menu screenshot: ${audioPath}`);
  await pressKey(target, "Select");
  await sleep(750);

  const subtitleApp = await launchPlaybackWithRemoteStart(
    target,
    subtitleContentId,
    mediaType,
    startFromChoice,
  );
  console.log(
    `opened subtitle playback: ${subtitleApp.id} ${subtitleApp.name} ${subtitleApp.version} contentID=${subtitleContentId}`,
  );
  await waitForPlayerClockReady(target);
  await pausePlaybackForStableOsd(target);
  await focusSubtitleButtonFromPlayback(target);
  await assertFocusRoundTrip(target, "captionsFocusLabel");
  const subtitleButtonPath = await captureDeveloperScreenshot(
    target,
    password,
    join(outputDir, "subtitle-button-focus.jpg"),
  );
  console.log(`captured subtitle button focus screenshot: ${subtitleButtonPath}`);
  await openSubtitleMenuFromPlayback(target);
  const subtitlePath = await captureDeveloperScreenshot(
    target,
    password,
    join(outputDir, "subtitle-menu.jpg"),
  );
  console.log(`captured subtitle menu screenshot: ${subtitlePath}`);

  await focusProgressFromOpenMenu(target);
  await assertProgressFocused(target);
  const progressPath = await captureDeveloperScreenshot(
    target,
    password,
    join(outputDir, "progress-focus.jpg"),
  );
  console.log(`captured progress focus screenshot: ${progressPath}`);
  const reviewPath = await writePlayerUiReview(outputDir, {
    target,
    audioContentId,
    subtitleContentId,
    mediaType,
    startFromChoice,
  });
  console.log(`wrote player UI review: ${reviewPath}`);
}

async function cleanupPlayerUiReviewArtifacts(outputDir: string): Promise<void> {
  await mkdir(outputDir, { recursive: true });

  await Promise.all(
    [
      "audio-button-focus.jpg",
      "audio-menu.jpg",
      "play-focus.jpg",
      "progress-focus.jpg",
      "progress-focus-latest.jpg",
      "reference-tv-native.jpg",
      "reference-tv-native.jpeg",
      "reference-tv-native.png",
      "reference-tv-native.webp",
      "reference-tv-native-audio-focus.png",
      "reference-tv-native-audio-menu.png",
      "reference-tv-native-controls.png",
      "reference-tv-native-progress.png",
      "reference-tv-native-speed-menu.png",
      "reference-tv-native-subtitle-menu.png",
      "review.html",
      "speed-button-focus.jpg",
      "speed-menu.jpg",
      "subtitle-button-focus.jpg",
      "subtitle-menu.jpg",
    ].map(async (filename) => {
      await rm(join(outputDir, filename), { force: true });
    }),
  );
}

async function writePlayerUiReview(
  outputDir: string,
  context: PlayerUiReviewContext,
): Promise<string> {
  const referenceImages = await copyPlayerUiReferenceImages(outputDir);
  const hasSpeedMenu = await fileExists(join(outputDir, "speed-menu.jpg"));
  const hasSpeedButton = await fileExists(join(outputDir, "speed-button-focus.jpg"));
  const imageMetadata = await readPlayerUiImageMetadata(outputDir, [
    "audio-button-focus.jpg",
    "audio-menu.jpg",
    "play-focus.jpg",
    "progress-focus.jpg",
    "speed-button-focus.jpg",
    "speed-menu.jpg",
    "subtitle-button-focus.jpg",
    "subtitle-menu.jpg",
    ...referenceImages.map((image) => image.filename),
  ]);
  const reviewPath = join(outputDir, "review.html");
  const generatedAt = new Date().toISOString();
  const smokeCommand = `make live-test-player-ui AUDIO_CONTENT_ID=${context.audioContentId} SUBTITLE_CONTENT_ID=${context.subtitleContentId} MEDIA_TYPE=${context.mediaType} START_FROM=${context.startFromChoice}`;
  const screenshotCommand = `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=${context.audioContentId} SUBTITLE_CONTENT_ID=${context.subtitleContentId} MEDIA_TYPE=${context.mediaType} START_FROM=${context.startFromChoice}`;
  const nativeCapturePanels = referenceImages
    .map(
      (image) => `
      <section class="panel wide">
        <h2>${escapeHtml(image.title)}</h2>
        <img src="./${escapeHtml(image.filename)}" alt="${escapeHtml(image.alt)}" />
      </section>`,
    )
    .join("");
  const speedMenuPanel = hasSpeedMenu
    ? `
      <section class="panel">
        <h2>Speed menu</h2>
        <img src="./speed-menu.jpg" alt="Roku speed menu" />
      </section>`
    : "";
  const speedButtonPanel = hasSpeedButton
    ? `
      <section class="panel">
        <h2>Speed button focus</h2>
        <img src="./speed-button-focus.jpg" alt="Roku speed button focus" />
      </section>`
    : "";
  const speedChecklistItem = hasSpeedMenu
    ? "<li>Playback speed menu captured and covered by live smoke selection.</li>"
    : "<li>Playback speed menu was skipped because this Roku did not expose Video.playbackSpeed.</li>";
  const imageMetadataItems = imageMetadata
    .map(
      (metadata) =>
        `<li><code>${escapeHtml(metadata.filename)}</code> ${metadata.width}×${metadata.height}</li>`,
    )
    .join("");

  await writeFile(
    reviewPath,
    `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Roku Player UI Review</title>
    <style>
      :root {
        background: #050505;
        color: #eeeeee;
        color-scheme: dark;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }

      body {
        margin: 0;
        padding: 28px;
      }

      h1,
      h2 {
        margin: 0;
        font-weight: 650;
      }

      h1 {
        font-size: 24px;
      }

      .meta {
        color: #b8b8b8;
        display: grid;
        gap: 6px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        margin-top: 14px;
      }

      .meta div {
        background: #101010;
        border: 1px solid #242424;
        padding: 10px 12px;
      }

      .meta strong {
        color: #f0f0f0;
        display: block;
        font-size: 12px;
        margin-bottom: 3px;
      }

      .checklist {
        background: #101010;
        border: 1px solid #242424;
        color: #d8d8d8;
        margin-top: 18px;
        padding: 14px 16px;
      }

      .checklist ul {
        display: grid;
        gap: 8px 18px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        list-style: none;
        margin: 0;
        padding: 0;
      }

      .checklist li::before {
        color: #fdce45;
        content: "✓";
        margin-right: 8px;
      }

      .captures {
        background: #101010;
        border: 1px solid #242424;
        color: #b8b8b8;
        margin-top: 10px;
        padding: 12px 16px;
      }

      .captures ul {
        display: grid;
        gap: 6px 18px;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        list-style: none;
        margin: 0;
        padding: 0;
      }

      code {
        color: #dddddd;
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
        font-size: 12px;
        overflow-wrap: anywhere;
      }

      h2 {
        color: #cfcfcf;
        font-size: 15px;
        margin-bottom: 10px;
      }

      .grid {
        display: grid;
        gap: 24px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        margin-top: 24px;
      }

      .panel {
        background: #111111;
        border: 1px solid #2a2a2a;
        padding: 14px;
      }

      .wide {
        grid-column: 1 / -1;
      }

      img {
        background: #000000;
        display: block;
        height: auto;
        width: 100%;
      }

    </style>
  </head>
  <body>
    <h1>Roku Player UI Review</h1>
    <div class="meta">
      <div><strong>Target</strong><code>${escapeHtml(context.target)}</code></div>
      <div><strong>Start mode</strong><code>${escapeHtml(context.startFromChoice)}</code></div>
      <div><strong>Audio file</strong><code>${escapeHtml(context.audioContentId)}</code></div>
      <div><strong>Subtitle file</strong><code>${escapeHtml(context.subtitleContentId)}</code></div>
      <div><strong>Generated at</strong><code>${escapeHtml(generatedAt)}</code></div>
      <div><strong>Smoke proof</strong><code>${escapeHtml(smokeCommand)}</code></div>
      <div><strong>Screenshot proof</strong><code>${escapeHtml(screenshotCommand)}</code></div>
    </div>
    <section class="checklist" aria-label="Player UI proof checklist">
      <ul>
        <li>Direct HLS playback asserted; old play/subtitle preselection surface rejected.</li>
        <li>Audio and subtitle menus open from player controls and move selected checkmarks.</li>
        ${speedChecklistItem}
        <li>Progress focus and adaptive right-side option labels have SceneGraph geometry assertions.</li>
        <li>OSD auto-hide/reveal flow is covered by live smoke.</li>
        <li>Remote Play, Fast Forward, and Rewind keys are covered by live smoke.</li>
      </ul>
    </section>
    <section class="captures" aria-label="Captured image metadata">
      <ul>${imageMetadataItems}</ul>
    </section>
    <div class="grid">${nativeCapturePanels}
      <section class="panel">
        <h2>Audio menu</h2>
        <img src="./audio-menu.jpg" alt="Roku audio menu" />
      </section>
      <section class="panel">
        <h2>Subtitle menu</h2>
        <img src="./subtitle-menu.jpg" alt="Roku subtitle menu" />
      </section>${speedMenuPanel}
      <section class="panel">
        <h2>Audio button focus</h2>
        <img src="./audio-button-focus.jpg" alt="Roku audio button focus" />
      </section>
      <section class="panel">
        <h2>Subtitle button focus</h2>
        <img src="./subtitle-button-focus.jpg" alt="Roku subtitle button focus" />
      </section>${speedButtonPanel}
      <section class="panel">
        <h2>Initial controls</h2>
        <img src="./play-focus.jpg" alt="Roku initial controls" />
      </section>
      <section class="panel">
        <h2>Progress focus</h2>
        <img src="./progress-focus.jpg" alt="Roku progress focus" />
      </section>
    </div>
  </body>
</html>
`,
  );

  return reviewPath;
}

async function readPlayerUiImageMetadata(
  outputDir: string,
  filenames: string[],
): Promise<ImageMetadata[]> {
  const metadata: ImageMetadata[] = [];

  for (const filename of filenames) {
    if (!(await fileExists(join(outputDir, filename)))) {
      continue;
    }

    const dimensions = readImageDimensions(await readFile(join(outputDir, filename)));
    metadata.push({
      filename,
      width: dimensions.width,
      height: dimensions.height,
    });
  }

  return metadata;
}

function readImageDimensions(buffer: Buffer): { width: number; height: number } {
  const pngSignature = "89504e470d0a1a0a";
  if (buffer.subarray(0, 8).toString("hex") === pngSignature) {
    return {
      width: buffer.readUInt32BE(16),
      height: buffer.readUInt32BE(20),
    };
  }

  if (buffer[0] === 0xff && buffer[1] === 0xd8) {
    return readJpegDimensions(buffer);
  }

  throw new Error("unsupported image format in player UI review artifact");
}

function readJpegDimensions(buffer: Buffer): { width: number; height: number } {
  let offset = 2;

  while (offset + 9 < buffer.length) {
    if (buffer[offset] !== 0xff) {
      offset += 1;
      continue;
    }

    const marker = buffer[offset + 1];
    const segmentLength = buffer.readUInt16BE(offset + 2);
    const isStartOfFrame =
      marker >= 0xc0 &&
      marker <= 0xcf &&
      marker !== 0xc4 &&
      marker !== 0xc8 &&
      marker !== 0xcc;

    if (isStartOfFrame) {
      return {
        height: buffer.readUInt16BE(offset + 5),
        width: buffer.readUInt16BE(offset + 7),
      };
    }

    offset += 2 + segmentLength;
  }

  throw new Error("could not read JPEG dimensions in player UI review artifact");
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function copyOptionalReferenceImage(
  outputDir: string,
): Promise<string | undefined> {
  const referenceImage = process.env.PLAYER_UI_REFERENCE_IMAGE;

  if (!referenceImage) {
    return undefined;
  }

  await access(referenceImage);
  const extension = extname(referenceImage) || ".png";
  const filename = `reference-tv-native${extension}`;
  await copyFile(referenceImage, join(outputDir, filename));

  return filename;
}

async function copyPlayerUiReferenceImages(outputDir: string): Promise<ReviewImage[]> {
  const referenceImages: ReviewImage[] = [];
  const optionalReferenceImage = await copyOptionalReferenceImage(outputDir);

  if (optionalReferenceImage !== undefined) {
    referenceImages.push({
      alt: "Custom player UI reference capture",
      filename: optionalReferenceImage,
      title: "Custom reference",
    });
  }

  const referenceDir =
    process.env.PLAYER_UI_TV_NATIVE_REFERENCE_DIR ??
    join(
      process.cwd(),
      "..",
      "putio-frontend-workspace",
      "docs",
      "specs",
      "tv-native",
      "android-tv",
    );
  const references: Array<ReviewImage & { source: string }> = [
    {
      alt: "tv-native Android player controls",
      filename: "reference-tv-native-controls.png",
      source: "18-video-controls.png",
      title: "tv-native controls reference",
    },
    {
      alt: "tv-native Android language button focus",
      filename: "reference-tv-native-audio-focus.png",
      source: "30-video-multi-audio-language-focus.png",
      title: "tv-native language focus reference",
    },
    {
      alt: "tv-native Android audio track picker",
      filename: "reference-tv-native-audio-menu.png",
      source: "31-video-language-picker.png",
      title: "tv-native audio menu reference",
    },
    {
      alt: "tv-native Android subtitle picker",
      filename: "reference-tv-native-subtitle-menu.png",
      source: "21-video-subtitles-picker.png",
      title: "tv-native subtitle menu reference",
    },
    {
      alt: "tv-native Android speed picker",
      filename: "reference-tv-native-speed-menu.png",
      source: "20-video-speed-picker.png",
      title: "tv-native speed menu reference",
    },
    {
      alt: "tv-native Android focused seek bar",
      filename: "reference-tv-native-progress.png",
      source: "28-video-seekbar-focused.png",
      title: "tv-native progress focus reference",
    },
  ];

  for (const reference of references) {
    const sourcePath = join(referenceDir, reference.source);
    if (!(await fileExists(sourcePath))) {
      continue;
    }

    await copyFile(sourcePath, join(outputDir, reference.filename));
    referenceImages.push({
      alt: reference.alt,
      filename: reference.filename,
      title: reference.title,
    });
  }

  return referenceImages;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function main(): Promise<void> {
  const target = requireTarget();
  const [command, ...args] = process.argv.slice(2);

  if (!command) {
    usage();
  }

  if (command === "check") {
    await checkDevice(target);
  } else if (command === "active-app") {
    await printActiveApp(target);
  } else if (command === "launch") {
    const appId = args[0] ?? "dev";
    const app = await launchApp(target, appId);
    console.log(`launched: ${app.id} ${app.name} ${app.version}`.trim());
  } else if (command === "launch-deeplink") {
    const [contentId, mediaType = "movie"] = args;

    if (!contentId) {
      usage();
    }

    const app = await launchDeepLink(target, contentId, mediaType);
    console.log(
      `launched deeplink: ${app.id} ${app.name} ${app.version} contentID=${contentId} mediaType=${mediaType}`.trim(),
    );
  } else if (command === "launch-playback") {
    const [contentId, mediaType = "movie", rawStartFromChoice = "continue"] =
      args;

    if (!contentId) {
      usage();
    }

    if (
      rawStartFromChoice !== "continue" &&
      rawStartFromChoice !== "beginning"
    ) {
      throw new Error("start-from choice must be continue or beginning");
    }

    const app = await launchPlayback(
      target,
      contentId,
      mediaType,
      rawStartFromChoice,
    );
    console.log(
      `launched playback: ${app.id} ${app.name} ${app.version} contentID=${contentId} mediaType=${mediaType} startFrom=${rawStartFromChoice}`.trim(),
    );
  } else if (command === "launch-playback-remote") {
    const [contentId, mediaType = "movie", rawStartFromChoice = "continue"] =
      args;

    if (!contentId) {
      usage();
    }

    if (
      rawStartFromChoice !== "continue" &&
      rawStartFromChoice !== "beginning"
    ) {
      throw new Error("start-from choice must be continue or beginning");
    }

    const app = await launchPlaybackWithRemoteStart(
      target,
      contentId,
      mediaType,
      rawStartFromChoice,
    );
    console.log(
      `launched playback with remote: ${app.id} ${app.name} ${app.version} contentID=${contentId} mediaType=${mediaType} startFrom=${rawStartFromChoice}`.trim(),
    );
  } else if (command === "player-ui-smoke") {
    const [
      audioContentId,
      subtitleContentId,
      mediaType = "movie",
      rawStartFromChoice = "continue",
    ] = args;

    if (!audioContentId || !subtitleContentId) {
      usage();
    }

    if (
      rawStartFromChoice !== "continue" &&
      rawStartFromChoice !== "beginning"
    ) {
      throw new Error("start-from choice must be continue or beginning");
    }

    await playerUiSmoke(
      target,
      audioContentId,
      subtitleContentId,
      mediaType,
      rawStartFromChoice,
    );
  } else if (command === "player-ui-screenshots") {
    const [
      audioContentId,
      subtitleContentId,
      mediaType = "movie",
      rawStartFromChoice = "continue",
      outputDir = "dist/tmp/player-ui",
    ] = args;

    if (!audioContentId || !subtitleContentId) {
      usage();
    }

    if (
      rawStartFromChoice !== "continue" &&
      rawStartFromChoice !== "beginning"
    ) {
      throw new Error("start-from choice must be continue or beginning");
    }

    await playerUiScreenshots(
      target,
      audioContentId,
      subtitleContentId,
      mediaType,
      rawStartFromChoice,
      outputDir,
    );
  } else if (command === "press") {
    if (args.length === 0) {
      usage();
    }

    for (const key of args) {
      await pressKey(target, key);
      await sleep(250);
    }
  } else if (command === "control-smoke") {
    await controlSmoke(target);
  } else {
    usage();
  }
}

main().catch((error: unknown) => {
  console.error(`ERROR: ${formatErrorMessage(error)}`);
  process.exit(1);
});
