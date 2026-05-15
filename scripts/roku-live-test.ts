#!/usr/bin/env node
import { access, copyFile, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, extname, join } from "node:path";
import process from "node:process";
import {
  assertNamedNodeState,
  checkDevice as rokitCheckDevice,
  isNamedNodeVisible,
  launchApp as rokitLaunchApp,
  pressKey as rokitPressKey,
  queryActiveApp as rokitQueryActiveApp,
  querySceneGraph as rokitQuerySceneGraph,
  readNamedNodeAttribute,
  readNamedNodeAttributes,
  takeScreenshot as rokitTakeScreenshot,
  validateRemoteKey,
  waitForActiveApp as rokitWaitForActiveApp,
  type ActiveApp,
  type RokuContext,
} from "@putdotio/rokit";

const requestTimeoutMs = 10_000;
const sceneGraphRequestTimeoutMs = 4_000;
const sceneGraphPollIntervalMs = 1_500;
const launchTimeoutMs = 10_000;
const playbackLaunchTimeoutMs = 90_000;

type TrackMenuTitle = "Audio tracks" | "Subtitle tracks" | "Playback speed";

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
  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    const xml = await querySceneGraph(target);

    if (isNamedNodeVisible(xml, nodeName)) {
      return;
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected SceneGraph node "${nodeName}" to become visible`);
}

function assertNamedNodeText(
  xml: string,
  nodeName: string,
  expectedText: string,
): void {
  const text = readNamedNodeAttribute(xml, nodeName, "text");

  if (text !== expectedText) {
    throw new Error(
      `expected "${nodeName}" text "${expectedText}", got "${text ?? "missing"}"`,
    );
  }
}

function readNamedNodeBoundsHeight(
  xml: string,
  nodeName: string,
): string | undefined {
  const bounds = readNamedNodeAttribute(xml, nodeName, "bounds");

  if (!bounds) {
    return undefined;
  }

  const parts = bounds
    .replace(/[{}]/g, "")
    .split(",")
    .map((part) => part.trim());

  return parts[3];
}

function readNamedNodeNumber(
  xml: string,
  nodeName: string,
  attributeName: "height" | "width",
): number | undefined {
  const value = readNamedNodeAttribute(xml, nodeName, attributeName);

  if (value !== undefined) {
    const numberValue = Number(value);
    return Number.isFinite(numberValue) ? numberValue : undefined;
  }

  const bounds = readNamedNodeAttribute(xml, nodeName, "bounds");

  if (!bounds) {
    return undefined;
  }

  const parts = parseSceneGraphNumberList(bounds);
  const index = attributeName === "width" ? 2 : 3;

  return parts[index];
}

function parseSceneGraphNumberList(value: string): number[] {
  return value
    .replace(/[\[\]{}]/g, "")
    .split(",")
    .map((part) => Number(part.trim()))
    .filter((part) => Number.isFinite(part));
}

function readNamedNodeTranslation(
  xml: string,
  nodeName: string,
): [number, number] | undefined {
  const translation = readNamedNodeAttribute(xml, nodeName, "translation");

  if (!translation) {
    return undefined;
  }

  const parts = parseSceneGraphNumberList(translation);

  if (parts.length < 2) {
    return undefined;
  }

  return [parts[0], parts[1]];
}

function assertNear(
  actual: number | undefined,
  expected: number,
  label: string,
  tolerance = 1,
): void {
  if (actual === undefined || Math.abs(actual - expected) > tolerance) {
    throw new Error(
      `expected ${label} ${expected}, got ${actual ?? "missing"}`,
    );
  }
}

function assertNodeTranslation(
  xml: string,
  nodeName: string,
  expectedX: number,
  expectedY: number,
): void {
  const translation = readNamedNodeTranslation(xml, nodeName);

  assertNear(translation?.[0], expectedX, `${nodeName} x`);
  assertNear(translation?.[1], expectedY, `${nodeName} y`);
}

function assertNodeSize(
  xml: string,
  nodeName: string,
  expectedWidth: number,
  expectedHeight: number,
): void {
  assertNear(readNamedNodeNumber(xml, nodeName, "width"), expectedWidth, `${nodeName} width`);
  assertNear(readNamedNodeNumber(xml, nodeName, "height"), expectedHeight, `${nodeName} height`);
}

function assertPlayerOsdLayout(xml: string, progressFocused = true): void {
  assertNodeTranslation(xml, "bottomShadeSoft", 0, 700);
  assertNodeSize(xml, "bottomShadeSoft", 1920, 80);
  assertNodeTranslation(xml, "bottomShade", 0, 780);
  assertNodeSize(xml, "bottomShade", 1920, 300);
  assertNodeTranslation(xml, "title", 96, 820);
  assertNodeTranslation(xml, "controls", 0, 810);
  assertNodeTranslation(xml, "rewindButton", 804, 0);
  assertNodeTranslation(xml, "playButton", 916, 0);
  assertNodeTranslation(xml, "fastForwardButton", 1028, 0);
  assertNodeSize(xml, "rewindButton", 88, 88);
  assertNodeSize(xml, "playButton", 88, 88);
  assertNodeSize(xml, "fastForwardButton", 88, 88);
  assertNodeTranslation(xml, "rewindIcon", 16, 16);
  assertNodeTranslation(xml, "playIcon", 16, 16);
  assertNodeTranslation(xml, "fastForwardIcon", 16, 16);
  assertNodeSize(xml, "rewindIcon", 56, 56);
  assertNodeSize(xml, "playIcon", 56, 56);
  assertNodeSize(xml, "fastForwardIcon", 56, 56);
  assertAuxiliaryControlsLayout(xml);
  assertNodeTranslation(xml, "progress", 96, 934);
  assertNodeTranslation(xml, "progressTrack", 0, progressFocused ? 24 : 25);
  assertNodeSize(xml, "progressTrack", 1728, progressFocused ? 10 : 8);
  assertNodeTranslation(xml, "duration", 1548, 52);
}

function assertAuxiliaryControlsLayout(xml: string): void {
  const visibleAuxiliaryControls = [
    ["audioButton", "audioFocusLabel", "audioIcon"],
    ["captionsButton", "captionsFocusLabel", "captionsIcon"],
    ["speedButton", "speedFocusLabel", "speedText"],
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

    if (valueName === "speedText") {
      assertNodeTranslation(xml, valueName, 0, 21);
      assertNodeSize(xml, valueName, 88, 38);
    } else {
      assertNodeTranslation(xml, valueName, 16, 16);
      assertNodeSize(xml, valueName, 56, 56);
    }

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

  if (expectedTitle === "Audio tracks") {
    assertNodeTranslation(xml, "trackMenuPanel", 580, 364);
    assertNodeSize(xml, "trackMenuPanel", 760, 352);
    assertNodeTranslation(xml, "trackMenuTitle", 640, 422);
    assertNodeTranslation(xml, "trackRows", 620, 512);
    assertNodeSize(xml, rowBackgroundName, 680, 92);
    assertNodeTranslation(xml, rowCheckName, 608, 21);
    return;
  }

  if (expectedTitle === "Playback speed") {
    assertNodeTranslation(xml, "trackMenuPanel", 580, 180);
    assertNodeSize(xml, "trackMenuPanel", 760, 628);
    assertNodeTranslation(xml, "trackMenuTitle", 640, 238);
    assertNodeTranslation(xml, "trackRows", 620, 328);
    assertNodeSize(xml, rowBackgroundName, 680, 92);
    assertNodeTranslation(xml, rowCheckName, 608, 21);
    return;
  }

  assertNodeTranslation(xml, "trackMenuPanel", 280, 272);
  assertNodeSize(xml, "trackMenuPanel", 1160, 536);
  assertNodeTranslation(xml, "trackMenuTitle", 340, 330);
  assertNodeTranslation(xml, "trackRows", 320, 420);
  assertNodeSize(xml, rowBackgroundName, 1080, 92);
  assertNodeTranslation(xml, rowCheckName, 1008, 21);
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

async function launchApp(target: string, appId: string): Promise<ActiveApp> {
  return await rokitLaunchApp(rokitContext(target), appId);
}

async function launchDeepLink(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice?: "continue" | "beginning",
): Promise<ActiveApp> {
  const params = new Map<string, string>([
    ["contentID", contentId],
    ["mediaType", mediaType],
  ]);
  if (startFromChoice !== undefined) {
    params.set("startFrom", startFromChoice);
  }

  try {
    return await rokitLaunchApp(rokitContext(target), "dev", params);
  } catch {
    await launchApp(target, "dev");
    await sleep(1_000);
    return await rokitLaunchApp(rokitContext(target), "dev", params);
  }
}

async function querySceneGraph(target: string): Promise<string> {
  return await rokitQuerySceneGraph(rokitContext(target, sceneGraphRequestTimeoutMs), {
    attempts: 3,
    retryDelayMs: 500,
  });
}

function hasVisibleNode(xml: string, tagName: string, nodeName: string): boolean {
  const nodePattern = new RegExp(
    `<${tagName}\\b(?=[^>]*\\bname="${nodeName}")([^>]*)>`,
  );
  const match = nodePattern.exec(xml);

  return match !== null && !match[1]?.includes('visible="false"');
}

function hasStartFromDialog(xml: string): boolean {
  return xml.includes("Where would you like to start?");
}

function assertHlsDirectPlaybackSurface(xml: string): void {
  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeHidden(xml, "videoScreen");
  assertNamedNodeAbsent(xml, "button-play");
  assertNamedNodeAbsent(xml, "subtitleList");

  if (!xml.includes("media.m3u8")) {
    throw new Error("expected player content to use the HLS media.m3u8 playlist");
  }

  if (xml.includes("original=1")) {
    throw new Error("expected player content to avoid original=1 playback URLs");
  }
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
  const app = await launchDeepLink(
    target,
    contentId,
    mediaType,
    startFromChoice,
  );
  const start = Date.now();
  let didChooseStartFrom = false;
  let lastState = "unknown";

  while (Date.now() - start < playbackLaunchTimeoutMs) {
    let xml: string;

    try {
      xml = await querySceneGraph(target);
    } catch (error) {
      lastState = `scene graph unavailable: ${formatErrorMessage(error)}`;
      await sleep(sceneGraphPollIntervalMs);
      continue;
    }

    if (!didChooseStartFrom && hasStartFromDialog(xml)) {
      didChooseStartFrom = true;
      await chooseStartFrom(target, startFromChoice);
      lastState = "startFromDialog";
    } else if (hasStartFromDialog(xml)) {
      lastState = "startFromDialog";
    } else if (hasVisibleNode(xml, "VideoPlayerScreen", "videoPlayerScreen")) {
      assertHlsDirectPlaybackSurface(xml);
      return app;
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
    `expected videoPlayerScreen after deeplink, last visible state: ${lastState}`,
  );
}

async function launchPlaybackWithRemoteStart(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
): Promise<ActiveApp> {
  await pressKey(target, "Home");
  await sleep(2_000);
  const app = await launchApp(target, "dev");
  const params = new Map<string, string>([
    ["contentID", contentId],
    ["mediaType", mediaType],
    ["startFrom", startFromChoice],
  ]);

  await sleep(4_000);
  await rokitLaunchApp(rokitContext(target), "dev", params);
  await sleep(5_000);

  const start = Date.now();
  let didChooseStartFrom = false;
  let lastState = "unknown";

  while (Date.now() - start < 30_000) {
    try {
      const xml = await querySceneGraph(target);

      if (!didChooseStartFrom && hasStartFromDialog(xml)) {
        didChooseStartFrom = true;
        await chooseStartFrom(target, startFromChoice);
        lastState = "startFromDialog";
      } else if (hasStartFromDialog(xml)) {
        lastState = "startFromDialog";
      } else if (hasVisibleNode(xml, "VideoPlayerScreen", "videoPlayerScreen")) {
        assertHlsDirectPlaybackSurface(xml);
        return app;
      } else if (hasVisibleNode(xml, "VideoScreen", "videoScreen")) {
        lastState = "videoScreen";
      } else if (hasVisibleNode(xml, "SearchScreen", "searchScreen")) {
        lastState = "searchScreen";
      } else if (hasVisibleNode(xml, "HomeScreen", "homeScreen")) {
        lastState = "homeScreen";
      }
    } catch (error) {
      lastState = `scene graph unavailable: ${formatErrorMessage(error)}`;
      await sleep(sceneGraphPollIntervalMs);
      continue;
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(
    `expected videoPlayerScreen after remote-assisted deeplink, last visible state: ${lastState}`,
  );
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

async function assertTrackMenu(
  target: string,
  expectedTitle: TrackMenuTitle,
  selectedRowIndex = 0,
): Promise<void> {
  const xml = await querySceneGraph(target);

  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeVisible(xml, "trackMenu");
  assertNamedNodeText(xml, "trackMenuTitle", expectedTitle);
  assertNamedNodeVisible(xml, "trackRow0");
  assertNamedNodeVisible(xml, `trackRow${selectedRowIndex}Background`);
  assertSelectedTrackRow(xml, selectedRowIndex);
  assertTrackMenuLayout(xml, expectedTitle, selectedRowIndex);
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
  for (let rowIndex = 0; rowIndex < 6; rowIndex += 1) {
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
): Promise<void> {
  await pressKey(target, "Select");
  await waitForTrackMenuOpen(target, expectedTitle);
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

async function focusProgressFromOpenMenu(target: string): Promise<void> {
  await pressKey(target, "Select");
  await sleep(750);
  await pressKey(target, "Up");
  await sleep(500);
  await assertProgressFocused(target);
}

async function assertProgressFocused(target: string): Promise<void> {
  const xml = await querySceneGraph(target);
  const progressHeight =
    readNamedNodeAttribute(xml, "progressTrack", "height") ??
    readNamedNodeBoundsHeight(xml, "progressTrack");

  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeVisible(xml, "osd");
  assertNamedNodeVisible(xml, "progressThumb");
  assertPlayerOsdLayout(xml);

  if (progressHeight !== "10") {
    throw new Error(`expected focused progress track height 10, got ${progressHeight ?? "missing"}`);
  }
}

async function assertOsdHideRevealFlow(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);

  await sleep(5_750);
  assertNamedNodeHidden(await querySceneGraph(target), "osd");

  await pressKey(target, "Select");
  await sleep(350);
  await assertProgressFocused(target);
  console.log("asserted OSD auto-hides and reveals on progress with Select");
}

async function assertOsdVisible(target: string): Promise<void> {
  const xml = await querySceneGraph(target);

  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeVisible(xml, "osd");
}

async function waitForPlayerClockReady(
  target: string,
  timeoutMs = 30_000,
): Promise<void> {
  const start = Date.now();
  let lastError: string | undefined;

  while (Date.now() - start < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);
      const position = readNamedNodeAttribute(xml, "position", "text");
      const duration = readNamedNodeAttribute(xml, "duration", "text");

      if (
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
  await sleep(350);
  await assertOsdVisible(target);
}

async function pausePlaybackForStableOsd(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  await pressKey(target, "Play");
  await sleep(750);
  await assertOsdVisible(target);
}

async function focusPlayButtonForScreenshot(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  await pressKey(target, "Down");
  await sleep(300);
  await assertPlayButtonFocused(target);
}

async function assertPlayButtonFocused(target: string): Promise<void> {
  const xml = await querySceneGraph(target);

  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeVisible(xml, "osd");
  assertNamedNodeVisible(xml, "playBackground");
  assertNamedNodeHidden(xml, "progressThumb");
  assertPlayerOsdLayout(xml, false);
}

async function assertMediaKeysSeek(target: string): Promise<void> {
  const before = readPlayerPositionSeconds(await querySceneGraph(target));
  await pressKey(target, "Fwd");
  await sleep(2_000);
  const afterFwd = readPlayerPositionSeconds(await querySceneGraph(target));
  await pressKey(target, "Rev");
  await sleep(2_000);
  const afterRev = readPlayerPositionSeconds(await querySceneGraph(target));

  if (afterFwd <= before + 5) {
    throw new Error(
      `expected Fwd to advance playback, got before=${before}s afterFwd=${afterFwd}s`,
    );
  }

  if (afterRev >= afterFwd) {
    throw new Error(
      `expected Rev to move playback backward, got afterFwd=${afterFwd}s afterRev=${afterRev}s`,
    );
  }

  console.log(
    `asserted media seek keys: before=${before}s afterFwd=${afterFwd}s afterRev=${afterRev}s`,
  );
}

async function assertMediaPlayKeyToggles(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  const beforePause = readPlayerPositionSeconds(await querySceneGraph(target));
  await pressKey(target, "Play");
  await sleep(1_500);
  const pausedAt = readPlayerPositionSeconds(await querySceneGraph(target));
  await sleep(1_500);
  const stillPausedAt = readPlayerPositionSeconds(await querySceneGraph(target));

  if (stillPausedAt > pausedAt + 1) {
    throw new Error(
      `expected Play key to pause playback, got before=${beforePause}s pausedAt=${pausedAt}s stillPausedAt=${stillPausedAt}s`,
    );
  }

  await pressKey(target, "Play");
  await sleep(2_000);
  const resumedAt = readPlayerPositionSeconds(await querySceneGraph(target));

  if (resumedAt <= stillPausedAt) {
    throw new Error(
      `expected Play key to resume playback, got stillPausedAt=${stillPausedAt}s resumedAt=${resumedAt}s`,
    );
  }

  console.log(
    `asserted Play key toggles playback: before=${beforePause}s paused=${pausedAt}s resumed=${resumedAt}s`,
  );
}

async function focusControlFromPlayback(
  target: string,
  focusLabelNodeName: string,
): Promise<void> {
  await ensureOsdVisibleForActivation(target);
  await pressKey(target, "Down");
  await sleep(250);

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const xml = await querySceneGraph(target);

    if (isNamedNodeVisible(xml, focusLabelNodeName)) {
      assertFocusedAuxiliaryLabelLayout(xml, focusLabelNodeName);
      return;
    }

    await pressKey(target, "Right");
    await sleep(250);
  }

  const xml = await querySceneGraph(target);
  assertNamedNodeVisible(xml, focusLabelNodeName);
  assertFocusedAuxiliaryLabelLayout(xml, focusLabelNodeName);
}

async function assertFocusRoundTrip(
  target: string,
  focusLabelNodeName: string,
): Promise<void> {
  await assertNamedNodeVisible(await querySceneGraph(target), focusLabelNodeName);
  await pressKey(target, "Up");
  await sleep(300);
  await assertProgressFocused(target);
  await pressKey(target, "Down");
  await sleep(300);
  assertNamedNodeVisible(await querySceneGraph(target), focusLabelNodeName);
}

async function focusAudioButtonFromPlayback(target: string): Promise<void> {
  await waitForNamedNodeVisible(target, "audioButton");
  await focusControlFromPlayback(target, "audioFocusLabel");
}

async function openAudioMenuFromPlayback(target: string): Promise<void> {
  if (!isNamedNodeVisible(await querySceneGraph(target), "audioFocusLabel")) {
    await focusAudioButtonFromPlayback(target);
  }
  await activateFocusedTrackButton(target, "Audio tracks");
  await assertTrackMenu(target, "Audio tracks");
}

async function focusSubtitleButtonFromPlayback(target: string): Promise<void> {
  await waitForNamedNodeVisible(target, "captionsButton");
  await focusControlFromPlayback(target, "captionsFocusLabel");
}

async function openSubtitleMenuFromPlayback(target: string): Promise<void> {
  if (!isNamedNodeVisible(await querySceneGraph(target), "captionsFocusLabel")) {
    await focusSubtitleButtonFromPlayback(target);
  }
  await activateFocusedTrackButton(target, "Subtitle tracks");
  await assertTrackMenu(target, "Subtitle tracks");
}

async function focusSpeedButtonFromPlayback(target: string): Promise<void> {
  await waitForNamedNodeVisible(target, "speedButton");
  await ensureOsdVisibleForActivation(target);
  await pressKey(target, "Down");
  await sleep(250);

  for (let attempt = 0; attempt < 10; attempt += 1) {
    const xml = await querySceneGraph(target);

    if (isSpeedButtonFocused(xml)) {
      return;
    }

    await pressKey(target, "Right");
    await sleep(250);
  }

  const xml = await querySceneGraph(target);
  if (!isSpeedButtonFocused(xml)) {
    throw new Error("expected speed control to be focused");
  }
}

function isSpeedButtonFocused(xml: string): boolean {
  return (
    isNamedNodeVisible(xml, "speedFocusLabel") ||
    readNamedNodeAttribute(xml, "speedText", "color") === "0xFDCE45FF"
  );
}

async function isSpeedControlAvailable(target: string): Promise<boolean> {
  return isNamedNodeVisible(await querySceneGraph(target), "speedButton");
}

async function openSpeedMenuFromPlayback(target: string): Promise<void> {
  if (!isSpeedButtonFocused(await querySceneGraph(target))) {
    await focusSpeedButtonFromPlayback(target);
  }
  await activateFocusedTrackButton(target, "Playback speed");
  await assertTrackMenu(target, "Playback speed", 2);
}

async function assertSpeedFocusRoundTrip(target: string): Promise<void> {
  const focusedXml = await querySceneGraph(target);
  if (!isSpeedButtonFocused(focusedXml)) {
    throw new Error("expected speed control to be focused");
  }

  await pressKey(target, "Up");
  await sleep(300);
  await assertProgressFocused(target);
  await pressKey(target, "Down");
  await sleep(300);

  if (!isSpeedButtonFocused(await querySceneGraph(target))) {
    throw new Error("expected speed control focus after progress round trip");
  }
}

async function assertSpeedValueLabel(target: string, expectedLabel: string): Promise<void> {
  const actualLabel = readNamedNodeAttribute(await querySceneGraph(target), "speedText", "text");

  if (actualLabel !== expectedLabel) {
    throw new Error(`expected speed label "${expectedLabel}", got "${actualLabel ?? "missing"}"`);
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
  if (await isSpeedControlAvailable(target)) {
    await focusSpeedButtonFromPlayback(target);
    await assertSpeedFocusRoundTrip(target);
    await openSpeedMenuFromPlayback(target);
    await selectNextTrackMenuItem(target);
    await sleep(750);
    await assertSpeedValueLabel(target, "1.25x");
    console.log("asserted playback speed menu and selection");
  } else {
    console.log("skipped playback speed menu: Roku Video.playbackSpeed is unavailable");
  }

  await focusAudioButtonFromPlayback(target);
  await assertFocusRoundTrip(target, "audioFocusLabel");
  await openAudioMenuFromPlayback(target);
  console.log("asserted audio menu from player controls");
  await selectNextTrackMenuItem(target);
  await pressKey(target, "Select");
  await sleep(750);
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
  await focusSubtitleButtonFromPlayback(target);
  await assertFocusRoundTrip(target, "captionsFocusLabel");
  await openSubtitleMenuFromPlayback(target);
  assertNamedNodeHidden(await querySceneGraph(target), "audioButton");
  console.log("asserted subtitle menu from player controls");
  await selectNextTrackMenuItem(target);
  await pressKey(target, "Select");
  await sleep(750);
  await assertTrackMenu(target, "Subtitle tracks", 1);
  console.log("asserted subtitle selection moves checkmark");
  await pressKey(target, "Back");
  await sleep(500);

  await pressKey(target, "Up");
  await sleep(500);
  await assertProgressFocused(target);
  console.log("asserted progress bar focus");

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
  return await rokitTakeScreenshot({ ...rokitContext(target), password }, outputPath);
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
  await focusPlayButtonForScreenshot(target);
  const playFocusPath = await captureDeveloperScreenshot(
    target,
    password,
    join(outputDir, "play-focus.jpg"),
  );
  console.log(`captured play focus screenshot: ${playFocusPath}`);
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
    await pressKey(target, "Back");
    await sleep(500);
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
      "reference-tv-native.jpg",
      "reference-tv-native.jpeg",
      "reference-tv-native.png",
      "reference-tv-native.webp",
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
  const referenceImagePath = await copyOptionalReferenceImage(outputDir);
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
    ...(referenceImagePath === undefined ? [] : [referenceImagePath]),
  ]);
  const reviewPath = join(outputDir, "review.html");
  const generatedAt = new Date().toISOString();
  const smokeCommand = `make live-test-player-ui AUDIO_CONTENT_ID=${context.audioContentId} SUBTITLE_CONTENT_ID=${context.subtitleContentId} MEDIA_TYPE=${context.mediaType} START_FROM=${context.startFromChoice}`;
  const screenshotCommand = `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=${context.audioContentId} SUBTITLE_CONTENT_ID=${context.subtitleContentId} MEDIA_TYPE=${context.mediaType} START_FROM=${context.startFromChoice}`;
  const nativeCapturePanel =
    referenceImagePath === undefined
      ? ""
      : `
      <section class="panel wide">
        <h2>tv-native Android capture</h2>
        <img src="./${referenceImagePath}" alt="tv-native Android player UI capture" />
      </section>`;
  const sourceReferencePanel = `
      <section class="panel wide reference-panel">
        <h2>tv-native source reference</h2>
        <div class="reference-stage">
          <div class="reference-video"></div>
          <div class="reference-modal">
            <strong>Audio tracks</strong>
            <div class="reference-row is-selected"><span>Spanish (s2-default) (es)</span><span>✓</span></div>
            <div class="reference-row"><span>Italian (t1-nondefault) (it)</span></div>
          </div>
          <div class="reference-controls">
            <div class="reference-control-top">
              <div class="reference-title">multi-audio-hls</div>
              <div class="reference-actions" aria-hidden="true">
                <div class="reference-label">Language</div>
                <div class="reference-icon">♪</div>
                <div class="reference-icon">▤</div>
                <div class="reference-icon">↻</div>
              </div>
            </div>
            <div class="reference-progress">
              <div class="reference-progress-fill"></div>
              <div class="reference-progress-thumb"></div>
            </div>
            <div class="reference-times"><span>02:54</span><span>06:36</span></div>
          </div>
        </div>
        <p class="reference-note">
          Source-derived fallback while Android SDK is unavailable: controls use <code>rgba(0,0,0,.75)</code>,
          active rows use <code>component-bg-active</code>, modal root uses <code>app-bg</code>,
          focused option labels appear above the icon row, and the seekbar track is 12px in tv-native.
        </p>
      </section>`;
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

      .reference-panel {
        background: #0b0b0b;
      }

      .reference-stage {
        aspect-ratio: 16 / 9;
        background:
          radial-gradient(circle at 28% 28%, rgba(255, 255, 255, 0.16), transparent 18%),
          linear-gradient(135deg, #182418 0%, #0f191d 42%, #26304f 100%);
        overflow: hidden;
        position: relative;
      }

      .reference-stage::after {
        background: rgba(0, 0, 0, 0.3);
        content: "";
        inset: 0;
        position: absolute;
      }

      .reference-modal {
        background: #151515f8;
        border: 1px solid #2f2f2f;
        color: #eeeeee;
        left: 50%;
        padding: 36px;
        position: absolute;
        top: 50%;
        transform: translate(-50%, -50%);
        width: min(520px, 38%);
        z-index: 2;
      }

      .reference-modal strong {
        color: #bdbdbd;
        display: block;
        font-size: 34px;
        margin-bottom: 26px;
      }

      .reference-row {
        align-items: center;
        color: #f0f0f0;
        display: flex;
        font-size: 30px;
        gap: 18px;
        justify-content: space-between;
        min-height: 62px;
        padding: 0 22px;
      }

      .reference-row.is-selected {
        background: hsl(0 0% 17.9%);
      }

      .reference-controls {
        background: rgba(0, 0, 0, 0.75);
        bottom: 0;
        box-sizing: border-box;
        left: 0;
        padding: 16px 4% 2%;
        position: absolute;
        width: 100%;
        z-index: 3;
      }

      .reference-control-top,
      .reference-times {
        align-items: end;
        display: flex;
        justify-content: space-between;
      }

      .reference-title {
        color: #eeeeee;
        font-size: 42px;
        font-weight: 650;
        max-width: 72%;
      }

      .reference-actions {
        align-items: end;
        display: grid;
        gap: 8px 16px;
        grid-template-columns: repeat(3, 64px);
        justify-items: center;
      }

      .reference-label {
        color: #bdbdbd;
        font-size: 22px;
        grid-column: 1 / -1;
      }

      .reference-icon {
        align-items: center;
        color: #eeeeee;
        display: flex;
        font-size: 34px;
        height: 64px;
        justify-content: center;
        width: 64px;
      }

      .reference-icon:first-of-type {
        background: hsl(0 0% 17.9%);
        border-radius: 999px;
        color: #fdce45;
      }

      .reference-progress {
        background: hsl(0 0% 43.9%);
        height: 12px;
        margin-top: 28px;
        position: relative;
        width: 100%;
      }

      .reference-progress-fill {
        background: #fdce45;
        height: 12px;
        width: 38%;
      }

      .reference-progress-thumb {
        background: #fdce45;
        border: 4px solid rgba(255, 255, 255, 0.25);
        border-radius: 999px;
        height: 28px;
        left: calc(38% - 14px);
        position: absolute;
        top: -12px;
        width: 28px;
      }

      .reference-times {
        color: #c7c7c7;
        font-size: 24px;
        margin-top: 16px;
      }

      .reference-note {
        color: #b8b8b8;
        line-height: 1.45;
        margin: 12px 0 0;
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
        <li>Transport focus, progress focus, and right-side labels have SceneGraph geometry assertions.</li>
        <li>OSD auto-hide/reveal flow is covered by live smoke.</li>
        <li>Remote Play, Fast Forward, and Rewind keys are covered by live smoke.</li>
      </ul>
    </section>
    <section class="captures" aria-label="Captured image metadata">
      <ul>${imageMetadataItems}</ul>
    </section>
    <div class="grid">${sourceReferencePanel}${nativeCapturePanel}
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
        <img src="./play-focus.jpg" alt="Roku play focus" />
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
