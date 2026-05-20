#!/usr/bin/env node
import { mkdir } from "node:fs/promises";
import { join } from "node:path";
import process from "node:process";
import {
  assertNamedNodeSize as assertNodeSize,
  assertNamedNodeText,
  assertSceneGraphNumberNear as assertNear,
  isNamedNodeVisible,
  readNamedNodeAttribute,
  readNamedNodeNumber,
  readNamedNodeTranslation,
  sceneGraphContainsText,
} from "@putdotio/rokit";
import {
  assertNotAuthScreen,
  authRefreshSmoke as authRefreshSmokeWithDriver,
  resetAuthState as resetAuthStateWithDriver,
  waitForAuthCode,
  waitForAuthReady,
  waitForBootstrapScreen,
  type AuthDriver,
} from "./live-test/auth.ts";
import {
  defaultFlowOutputDir,
  formatArtifactTimestamp,
  defaultPlayerUiOutputDir,
  defaultVisualLabOutputDir,
  defaultVisualPagesOutputDir,
} from "./live-test/artifacts.ts";
import {
  captureRokuDebugSnapshot,
  defaultDebugArtifactDir,
} from "./live-test/diagnostics.ts";
import {
  sceneGraphPollIntervalMs,
  trackMenuRowPoolSize,
} from "./live-test/constants.ts";
import { formatErrorMessage } from "./live-test/errors.ts";
import {
  ensureAppPlaybackTypeSetting as ensureAppPlaybackTypeSettingWithDriver,
  runAppFlow,
  type AppFlowDriver,
} from "./live-test/app-flows.ts";
import {
  appFlowOptionsFromArgs,
  emptyStringAsUndefined,
  startFromChoiceFromArg,
  type AppFlowOptions,
} from "./live-test/flow-options.ts";
import {
  appFlowSmokeSuite,
  fullAppFlowSuite,
  parseFlowList,
  runFlowSuite,
  type FlowId,
  type FlowRunContext,
} from "./live-test/flow-suite.ts";
import { imageRenderSmoke } from "./live-test/image.ts";
import {
  assertDirectPlaybackSurfaceOnDevice,
  assertPlaybackTypeSurfaceOnDevice,
  ensureMediaPlaying,
  launchPlayback,
  launchPlaybackWithRemoteStart,
  playbackTypeFromArg,
} from "./live-test/playback.ts";
import { capturePlayerUiScreenshots } from "./live-test/player-ui-review.ts";
import { putioProfileFromArg, setPlaybackTypeConfig } from "./live-test/putio-config.ts";
import {
  assertListHasItems,
  dismissExitDialogIfVisible,
  focusLastListItem,
  focusListItemByIndex,
  leaveActivePlaybackSurface,
  openHomeItem,
  returnToHomeScreen as returnToHomeScreenWithGuard,
  waitForAnyRouteScreenVisible,
  waitForRouteScreenVisible,
} from "./live-test/navigation.ts";
import {
  captureDeveloperScreenshot,
  checkDevice,
  controlSmoke,
  launchApp,
  launchDeepLink,
  pressKey,
  printActiveApp,
  queryActiveAppSafe,
  queryMediaPlayerStateSafe,
  queryMediaPlayerXmlSafe,
  querySceneGraph,
  readMediaPlayerPositionMs,
  requireDeveloperPassword,
  requireTarget,
  type ActiveApp,
  waitForDevAppSceneGraphReady,
  waitForMediaPlayerState,
  waitForNamedNodeVisible,
  waitForSceneGraphAssertion,
} from "./live-test/rokit-device.ts";
import {
  assertFocusedAuxiliaryLabelLayout,
  assertNamedNodeHidden,
  assertNamedNodeVisible,
  assertPlayerOsdLayout,
  assertTrackMenuLayout,
  hasVisibleNode,
  hasVisibleRouteScreen,
  readListFocusIndex,
  type TrackMenuTitle,
} from "./live-test/scenegraph.ts";
import { sleep } from "./live-test/timing.ts";
import { usage } from "./live-test/usage.ts";
import {
  captureVisualLabStories,
  captureVisualPages,
  visualLabStories,
  type VisualCaptureDriver,
} from "./live-test/visual-capture.ts";

type PlayerControlId =
  | "rewind"
  | "play"
  | "fastForward"
  | "audio"
  | "captions"
  | "speed";

const playerControlBackgroundNodes: Record<PlayerControlId, string> = {
  rewind: "rewindBackground",
  play: "playBackground",
  fastForward: "fastForwardBackground",
  audio: "audioBackground",
  captions: "captionsBackground",
  speed: "speedBackground",
};

async function authRefreshSmoke(target: string): Promise<void> {
  await authRefreshSmokeWithDriver(target, createAuthDriver());
}

async function resetAuthState(target: string): Promise<void> {
  await resetAuthStateWithDriver(target, createAuthDriver());
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
  const text = readNamedNodeAttribute(xml, "playerPosition", "text");

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

async function assertTrackMenu(
  target: string,
  expectedTitle: TrackMenuTitle,
  selectedRowIndex = 0,
): Promise<void> {
  await waitForSceneGraphAssertion(target, `expected ${expectedTitle} menu`, (xml) => {
    assertNamedNodeVisible(xml, "videoPlayerScreen");
    assertNamedNodeVisible(xml, "trackMenu");
    assertNamedNodeText(xml, "trackMenuTitle", expectedTitle);
    assertNamedNodeVisible(xml, "trackMenuRow0");
    assertNamedNodeVisible(xml, `trackMenuRow${selectedRowIndex}Background`);
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
  for (let rowIndex = 0; rowIndex < trackMenuRowPoolSize; rowIndex += 1) {
    const checkName = `trackMenuRow${rowIndex}Check`;

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

async function selectPreviousTrackMenuItem(target: string): Promise<void> {
  await pressKey(target, "Up");
  await sleep(250);
  await pressKey(target, "Select");
  await sleep(750);
}

async function readVideoNodeAttributeFromDevice(
  target: string,
  attributeName: string,
): Promise<string | undefined> {
  return readNamedNodeAttribute(await querySceneGraph(target), "video", attributeName);
}

async function waitForVideoNodeAttribute(
  target: string,
  attributeName: string,
  description: string,
  predicate: (value: string | undefined) => boolean,
  timeoutMs = 6_000,
): Promise<string | undefined> {
  const start = Date.now();
  let lastValue: string | undefined;

  while (Date.now() - start < timeoutMs) {
    lastValue = await readVideoNodeAttributeFromDevice(target, attributeName);
    if (predicate(lastValue)) {
      return lastValue;
    }

    await sleep(500);
  }

  throw new Error(
    `expected video.${attributeName} ${description}, got ${lastValue ?? "missing"}`,
  );
}

async function assertAudioTrackApplied(
  target: string,
  previousAudioTrack: string | undefined,
): Promise<void> {
  if (previousAudioTrack === undefined) {
    console.log("skipped Video.audioTrack assertion: Roku did not expose the field");
    return;
  }

  const selectedAudioTrack = await waitForVideoNodeAttribute(
    target,
    "audioTrack",
    "to change after audio menu selection",
    (value) => value !== undefined && value !== "" && value !== previousAudioTrack,
  );

  console.log(`asserted Video.audioTrack changed to ${selectedAudioTrack}`);
}

async function assertSubtitlesDisabled(target: string): Promise<void> {
  const initialCaptionMode = await readVideoNodeAttributeFromDevice(target, "globalCaptionMode");

  if (initialCaptionMode !== undefined) {
    await waitForVideoNodeAttribute(
      target,
      "globalCaptionMode",
      "to become Off after subtitle menu selection",
      (value) => value === "Off",
    );
  } else {
    console.log("skipped Video.globalCaptionMode assertion: Roku did not expose the field");
  }

  const subtitleTrack = await readVideoNodeAttributeFromDevice(target, "subtitleTrack");
  if (subtitleTrack !== undefined && subtitleTrack !== "") {
    throw new Error(`expected Video.subtitleTrack to be empty after disabling subtitles, got ${subtitleTrack}`);
  }

  const mediaPlayerXml = await queryMediaPlayerXmlSafe(target);
  const captions = mediaPlayerXml === undefined
    ? undefined
    : /<captions>([^<]*)<\/captions>/.exec(mediaPlayerXml)?.[1];
  if (captions !== undefined && captions !== "none") {
    throw new Error(`expected media-player captions to be none after disabling subtitles, got ${captions}`);
  }

  console.log("asserted subtitles disabled");
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
  const progressHeight = readNamedNodeNumber(xml, "playerProgressTrack", "height");

  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeVisible(xml, "osd");
  assertNamedNodeVisible(xml, "playerProgressThumb");
  assertPlayerOsdLayout(xml);

  if (progressHeight !== 12) {
    throw new Error(
      `expected focused progress track height 12, got ${progressHeight?.toString() ?? "missing"}`,
    );
  }
}

function assertPausedPositionGlyph(xml: string): void {
  assertNamedNodeVisible(xml, "playerPositionPauseIcon");
  assertNodeSize(xml, "playerPositionPauseIcon", 22, 22);

  const translation = readNamedNodeTranslation(xml, "playerPositionPauseIcon");
  const x = translation?.[0];
  const y = translation?.[1];
  const allowedX = [112, 158, 188];

  if (x === undefined || !allowedX.includes(x)) {
    throw new Error(`expected pause glyph x to follow position label, got ${x ?? "missing"}`);
  }

  assertNear(y, 56, "playerPositionPauseIcon y");
}

async function assertOsdHideRevealFlow(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);

  await sleep(3_750);
  assertNamedNodeHidden(await querySceneGraph(target), "osd");

  await pressKey(target, "Select");
  await waitForOsdVisible(target);
  console.log("asserted OSD auto-hides and reveals controls with Select");
}

async function assertOptionsRevealTrackControls(target: string): Promise<void> {
  await ensureOsdVisibleForActivation(target);

  await sleep(3_750);
  assertNamedNodeHidden(await querySceneGraph(target), "osd");

  await pressKey(target, "Info");
  await waitForSceneGraphAssertion(target, "expected Options to focus track controls", (xml) => {
    assertNamedNodeVisible(xml, "videoPlayerScreen");
    assertNamedNodeVisible(xml, "osd");

    const focusedControl = readFocusedPlaybackControl(xml);
    if (
      focusedControl !== "audio" &&
      focusedControl !== "captions" &&
      focusedControl !== "speed"
    ) {
      throw new Error(`expected Options to focus a track control, got ${focusedControl ?? "none"}`);
    }
  });
  console.log("asserted Options reveals and focuses track controls");
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
      const position = readNamedNodeAttribute(xml, "playerPosition", "text");
      const duration = readNamedNodeAttribute(xml, "playerDuration", "text");

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
    await assertPausedPositionGlyphBestEffort(target);
    return;
  }

  if (currentState !== "play") {
    await waitForMediaPlayerState(target, "play", 8_000);
  }

  await pressKey(target, "Play");
  if (await waitForMediaPlayerState(target, "pause")) {
    await waitForOsdVisible(target);
    await assertPausedPositionGlyphBestEffort(target);
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
      await assertPausedPositionGlyphBestEffort(target);
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
  await assertPausedPositionGlyphBestEffort(target);
}

async function assertPausedPositionGlyphBestEffort(target: string): Promise<void> {
  try {
    await waitForSceneGraphAssertion(
      target,
      "expected paused position glyph",
      assertPausedPositionGlyph,
      2_000,
    );
  } catch (error) {
    console.log(`skipped paused glyph assertion while stabilizing OSD: ${formatErrorMessage(error)}`);
  }
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
  await sleep(1_500);
  await assertProgressFocused(target);
  const afterFwd = await readPlayerPositionSecondsFromDevice(target);

  if (afterFwd <= before + 5) {
    throw new Error(
      `expected Fwd to seek forward, got before=${before}s afterFwd=${afterFwd}s`,
    );
  }

  await pressKey(target, "Rev");
  await sleep(1_500);
  await assertProgressFocused(target);
  const afterRev = await readPlayerPositionSecondsFromDevice(target);

  if (afterRev >= afterFwd) {
    throw new Error(
      `expected Rev to seek backward, got afterFwd=${afterFwd}s afterRev=${afterRev}s`,
    );
  }

  console.log(
    `asserted media seek keys: before=${before}s afterFwd=${afterFwd}s afterRev=${afterRev}s`,
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
  if (isNamedNodeVisible(xml, "playerProgressThumb")) {
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
      await waitForPlaybackControlFocusReady(target, controlId);
      return;
    }

    lastFocusedControl = readFocusedPlaybackControl(xml);
  }

  throw new Error(
    `expected ${controlId} control to be focused, got ${lastFocusedControl ?? "none"}`,
  );
}

async function waitForPlaybackControlFocusReady(
  target: string,
  controlId: PlayerControlId,
): Promise<void> {
  const backgroundNodeName = playerControlBackgroundNodes[controlId];

  await waitForSceneGraphAssertion(
    target,
    `expected ${controlId} focus background`,
    (xml) => {
      assertPlaybackControlFocused(xml, controlId);

      if (!isNamedNodeVisible(xml, backgroundNodeName)) {
        throw new Error(`expected ${backgroundNodeName} to be visible`);
      }

      const loadStatus = readNamedNodeAttribute(xml, backgroundNodeName, "loadStatus");
      if (loadStatus !== "3") {
        throw new Error(`expected ${backgroundNodeName} to load, got ${loadStatus ?? "none"}`);
      }
    },
    3_000,
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

async function isAudioControlAvailable(target: string): Promise<boolean> {
  return isNamedNodeVisible(await querySceneGraph(target), "audioButton");
}

async function openAudioMenuFromPlayback(target: string): Promise<void> {
  await focusAudioButtonFromPlayback(target);
  await activateFocusedTrackButton(target, "Audio tracks", "audio");
  await assertTrackMenu(target, "Audio tracks");
}

async function openAudioMenuForScreenshot(target: string): Promise<void> {
  await focusAudioButtonFromPlayback(target);
  await activateFocusedTrackButton(target, "Audio tracks", "audio");
  await waitForTrackMenuOpen(target, "Audio tracks", 10_000);
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
  await assertTrackMenu(target, "Subtitles", 1);
}

async function openSubtitleMenuForScreenshot(target: string): Promise<void> {
  await focusSubtitleButtonFromPlayback(target);
  await activateFocusedTrackButton(target, "Subtitles", "captions");
  await waitForTrackMenuOpen(target, "Subtitles", 10_000);
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

async function openSpeedMenuForScreenshot(target: string): Promise<void> {
  await focusSpeedButtonFromPlayback(target);
  await activateFocusedTrackButton(target, "Playback speed", "speed");
  await waitForTrackMenuOpen(target, "Playback speed", 10_000);
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

async function assertPlaybackSpeedAffectsPosition(target: string, expectedMinimumRate: number): Promise<void> {
  await ensureMediaPlaying(target);
  await sleep(1_000);

  const startPosition = readMediaPlayerPositionMs(await queryMediaPlayerXmlSafe(target));
  if (startPosition === undefined) {
    throw new Error("expected media-player position before playback speed measurement");
  }

  const wallClockMs = 8_000;
  await sleep(wallClockMs);

  const endPosition = readMediaPlayerPositionMs(await queryMediaPlayerXmlSafe(target));
  if (endPosition === undefined) {
    throw new Error("expected media-player position after playback speed measurement");
  }

  const mediaDeltaMs = endPosition - startPosition;
  const observedRate = mediaDeltaMs / wallClockMs;

  if (observedRate < expectedMinimumRate) {
    throw new Error(
      `expected playback speed to advance faster than realtime; observed ${observedRate.toFixed(2)}x (${mediaDeltaMs}ms over ${wallClockMs}ms)`,
    );
  }
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
    await assertPlaybackSpeedAffectsPosition(target, 1.1);
    console.log("asserted playback speed menu, selection, and media rate");
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
  await ensureAppPlaybackTypeSetting(target, "hls");

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
  await assertDirectPlaybackSurfaceOnDevice(target, audioContentId);
  await pausePlaybackForStableOsd(target);
  await smokePlaybackSpeedIfAvailable(target);

  if (await isAudioControlAvailable(target)) {
    await focusAudioButtonFromPlayback(target);
    await assertFocusRoundTrip(target, "audioFocusLabel");
    await openAudioMenuFromPlayback(target);
    console.log("asserted audio menu from player controls");
    const initialAudioTrack = await readVideoNodeAttributeFromDevice(target, "audioTrack");
    await selectNextTrackMenuItem(target);
    await assertAudioTrackApplied(target, initialAudioTrack);
    await reopenFocusedTrackMenu(target, "Audio tracks");
    await assertTrackMenu(target, "Audio tracks", 1);
    console.log("asserted audio track selection moves checkmark");
    await pressKey(target, "Back");
    await sleep(500);
  } else {
    console.log("skipped audio menu assertions: Roku did not expose multiple audio tracks");
  }

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
  await assertDirectPlaybackSurfaceOnDevice(target, subtitleContentId);
  await pausePlaybackForStableOsd(target);
  await focusSubtitleButtonFromPlayback(target);
  await assertFocusRoundTrip(target, "captionsFocusLabel");
  await openSubtitleMenuFromPlayback(target);
  assertNamedNodeHidden(await querySceneGraph(target), "audioButton");
  console.log("asserted subtitle menu from player controls");
  await selectPreviousTrackMenuItem(target);
  await assertSubtitlesDisabled(target);
  await reopenFocusedTrackMenu(target, "Subtitles");
  await assertTrackMenu(target, "Subtitles", 0);
  console.log("asserted subtitle off selection moves checkmark");
  await pressKey(target, "Back");
  await sleep(500);

  await pressKey(target, "Down");
  await sleep(500);
  await assertProgressFocused(target);
  console.log("asserted progress bar focus");

  await pressKey(target, "Play");
  await sleep(750);
  await assertOptionsRevealTrackControls(target);
  await assertOsdHideRevealFlow(target);
  await assertMediaPlayKeyToggles(target);
  await assertMediaKeysSeek(target);
}

async function playbackTypeSmoke(
  target: string,
  playbackType: "hls" | "mp4",
  contentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
): Promise<void> {
  await ensureAppPlaybackTypeSetting(target, playbackType);
  await leaveActivePlaybackSurface(target);

  const app = await launchPlaybackWithRemoteStart(
    target,
    contentId,
    mediaType,
    startFromChoice,
    { reuseExisting: false },
  );
  console.log(
    `opened ${playbackType} playback: ${app.id} ${app.name} ${app.version} contentID=${contentId}`,
  );
  await waitForPlayerClockReady(target);
  await assertPlaybackTypeSurfaceOnDevice(target, playbackType, contentId);
  console.log(`asserted ${playbackType} playback type for contentID=${contentId}`);
}

async function playbackErrorDialogSmoke(
  target: string,
  contentId: string,
  mediaType: string,
  expectedTitle: string,
  expectedMessageFragment: string,
): Promise<void> {
  await launchDeepLink(target, contentId, mediaType, "beginning");
  await waitForSceneGraphAssertion(
    target,
    `expected error dialog for contentID=${contentId}`,
    (xml) => {
      assertNotAuthScreen(xml);

      if (!sceneGraphContainsText(xml, expectedTitle)) {
        throw new Error(`expected dialog title/text to include "${expectedTitle}"`);
      }

      if (!sceneGraphContainsText(xml, expectedMessageFragment)) {
        throw new Error(`expected dialog message to include "${expectedMessageFragment}"`);
      }
    },
    30_000,
  );

  await pressKey(target, "Select");
  console.log(`asserted readable playback error dialog for contentID=${contentId}`);
}

async function ensureAppPlaybackTypeSetting(
  target: string,
  playbackType: "hls" | "mp4",
): Promise<void> {
  await ensureAppPlaybackTypeSettingWithDriver(target, playbackType, createAppFlowDriver());
}

async function returnToHomeScreen(target: string): Promise<void> {
  await returnToHomeScreenWithGuard(target, {
    assertNotAuthScreen,
    waitForBootstrapScreen,
  });
}

async function playerUiScreenshots(
  target: string,
  audioContentId: string,
  subtitleContentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
  outputDir: string,
): Promise<void> {
  const password = requireDeveloperPassword();

  await capturePlayerUiScreenshots(
    {
      assertDirectPlaybackSurfaceOnDevice: async (contentId) => {
        await assertDirectPlaybackSurfaceOnDevice(target, contentId);
      },
      assertFocusRoundTrip: async (focusLabelId) => {
        await assertFocusRoundTrip(target, focusLabelId);
      },
      assertProgressFocused: async () => {
        await assertProgressFocused(target);
      },
      captureScreenshot: async (outputPath) => {
        return await captureDeveloperScreenshot(target, password, outputPath);
      },
      focusAudioButtonFromPlayback: async () => {
        await focusAudioButtonFromPlayback(target);
      },
      focusInitialControlsForScreenshot: async () => {
        await focusInitialControlsForScreenshot(target);
      },
      focusProgressFromOpenMenu: async () => {
        await focusProgressFromOpenMenu(target);
      },
      focusSpeedButtonFromPlayback: async () => {
        await focusSpeedButtonFromPlayback(target);
      },
      focusSubtitleButtonFromPlayback: async () => {
        await focusSubtitleButtonFromPlayback(target);
      },
      isAudioControlAvailable: async () => await isAudioControlAvailable(target),
      isSpeedControlAvailable: async () => await isSpeedControlAvailable(target),
      launchPlaybackWithRemoteStart: async (contentId, launchMediaType, launchStartFromChoice) =>
        await launchPlaybackWithRemoteStart(
          target,
          contentId,
          launchMediaType,
          launchStartFromChoice,
        ),
      openAudioMenuFromPlayback: async () => {
        await openAudioMenuForScreenshot(target);
      },
      openSpeedMenuFromPlayback: async () => {
        await openSpeedMenuForScreenshot(target);
      },
      openSubtitleMenuFromPlayback: async () => {
        await openSubtitleMenuForScreenshot(target);
      },
      pausePlaybackForStableOsd: async () => {
        await pausePlaybackForStableOsd(target);
      },
      pressKey: async (key) => {
        await pressKey(target, key);
      },
      sleep,
      waitForPlayerClockReady: async () => {
        await waitForPlayerClockReady(target);
      },
    },
    {
      target,
      audioContentId,
      subtitleContentId,
      mediaType,
      startFromChoice,
    },
    outputDir,
  );
}

function createVisualCaptureDriver(): VisualCaptureDriver {
  return {
    assertListHasItems,
    dismissExitDialogIfVisible,
    focusLastListItem,
    leaveActivePlaybackSurface,
    openHomeItem,
    readListFocusIndex,
    resetAuthState,
    returnToHomeScreen,
    waitForAnyRouteScreenVisible,
    waitForAuthCode,
    waitForAuthReady,
    waitForRouteScreenVisible,
  };
}

function createAuthDriver(): AuthDriver {
  return {
    dismissExitDialogIfVisible,
    focusLastListItem,
    returnToHomeScreen,
    waitForDevAppSceneGraphReady,
    waitForRouteScreenVisible,
  };
}

function createAppFlowDriver(): AppFlowDriver {
  return {
    assertListHasItems,
    authRefreshSmoke,
    focusLastListItem,
    focusListItemByIndex,
    openHomeItem,
    playbackTypeSmoke,
    imageRenderSmoke,
    playerUiSmoke,
    resetAuthState,
    returnToHomeScreen,
    waitForAnyRouteScreenVisible,
    waitForAuthReady,
    waitForBootstrapScreen,
    waitForRouteScreenVisible,
  };
}

async function runNamedFlowSuite(
  target: string,
  suiteName: string,
  flows: readonly FlowId[],
  options: AppFlowOptions,
  rawArtifactDir?: string,
): Promise<void> {
  const artifactDir = emptyStringAsUndefined(rawArtifactDir) ?? defaultFlowOutputDir(suiteName);
  await mkdir(artifactDir, { recursive: true });
  await runFlowSuite(flows, { target, artifactDir }, async (flowId, context) => {
    await runAppFlow(flowId, context, options, createAppFlowDriver());
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
  } else if (command === "debug-snapshot") {
    const [rawOutputDir] = args;
    const outputDir = rawOutputDir ?? defaultDebugArtifactDir("snapshot");
    await captureRokuDebugSnapshot(target, outputDir);
    console.log(`debug snapshot: ${outputDir}`);
  } else if (command === "auth-reset") {
    await resetAuthState(target);
  } else if (command === "auth-refresh-smoke") {
    await authRefreshSmoke(target);
  } else if (command === "auth-prepare") {
    const [profile = process.env.PUTIO_CLI_PROFILE ?? "devs-fe-auto"] = args;
    await waitForAuthReady(target, profile);
  } else if (command === "flow-smoke") {
    const [rawArtifactDir] = args;
    await runNamedFlowSuite(
      target,
      "app-smoke",
      appFlowSmokeSuite,
      appFlowOptionsFromArgs([]),
      rawArtifactDir,
    );
  } else if (command === "flow-full") {
    const [
      playbackContentId,
      imageContentId,
      audioContentId,
      subtitleContentId,
      mediaType = "movie",
      rawStartFromChoice = "continue",
      rawArtifactDir,
    ] = args;

    if (!playbackContentId || !imageContentId || !audioContentId || !subtitleContentId) {
      usage();
    }

    await runNamedFlowSuite(
      target,
      "app-full",
      fullAppFlowSuite,
      {
        profile: putioProfileFromArg(),
        playbackContentId,
        imageContentId,
        audioContentId,
        subtitleContentId,
        mediaType,
        startFromChoice: startFromChoiceFromArg(rawStartFromChoice),
      },
      rawArtifactDir,
    );
  } else if (command === "flow") {
    const [rawFlowList, ...flowArgs] = args;

    if (!rawFlowList) {
      usage();
    }

    const flows = parseFlowList(rawFlowList);
    const artifactDir = flowArgs[5];
    await runNamedFlowSuite(
      target,
      "custom",
      flows,
      appFlowOptionsFromArgs(flowArgs),
      artifactDir,
    );
  } else if (command === "visual-pages") {
    const includeAuth = args.includes("--include-auth");
    const rawArtifactDir = args.find((arg) => !arg.startsWith("--"));
    await captureVisualPages(
      target,
      emptyStringAsUndefined(rawArtifactDir) ?? defaultVisualPagesOutputDir(),
      {
        includeAuth,
        imageContentId: emptyStringAsUndefined(process.env.IMAGE_CONTENT_ID),
        profile: putioProfileFromArg(),
      },
      createVisualCaptureDriver(),
    );
  } else if (command === "visual-lab") {
    const captureAll = args.includes("--all");
    const knownStoryIds = new Set<string>(visualLabStories.map(([storyId]) => storyId));
    const firstPositional = args.find((arg) => !arg.startsWith("--"));
    const rawArtifactDir = firstPositional !== undefined && !knownStoryIds.has(firstPositional)
      ? firstPositional
      : undefined;
    const storyIds = captureAll
      ? visualLabStories.map(([storyId]) => storyId)
      : args.filter((arg) => !arg.startsWith("--") && arg !== rawArtifactDir);
    await captureVisualLabStories(
      target,
      emptyStringAsUndefined(rawArtifactDir) ?? defaultVisualLabOutputDir(),
      storyIds,
      createVisualCaptureDriver(),
    );
  } else if (command === "set-playback-type") {
    const [rawPlaybackType, rawProfile] = args;

    if (!rawPlaybackType) {
      usage();
    }

    await setPlaybackTypeConfig(playbackTypeFromArg(rawPlaybackType), rawProfile);
  } else if (command === "image-render-smoke") {
    const [contentId] = args;

    if (!contentId) {
      usage();
    }

    await imageRenderSmoke(target, contentId);
  } else if (command === "playback-type-smoke") {
    const [
      rawPlaybackType,
      contentId,
      mediaType = "movie",
      rawStartFromChoice = "continue",
    ] = args;

    if (!rawPlaybackType || !contentId) {
      usage();
    }

    if (
      rawStartFromChoice !== "continue" &&
      rawStartFromChoice !== "beginning"
    ) {
      throw new Error("start-from choice must be continue or beginning");
    }

    await playbackTypeSmoke(
      target,
      playbackTypeFromArg(rawPlaybackType),
      contentId,
      mediaType,
      rawStartFromChoice,
    );
  } else if (command === "playback-error-dialog-smoke") {
    const [
      contentId,
      mediaType = "movie",
      expectedTitle = "Oops, an error occurred",
      expectedMessageFragment = "File not found",
    ] = args;

    if (!contentId) {
      usage();
    }

    await playbackErrorDialogSmoke(
      target,
      contentId,
      mediaType,
      expectedTitle,
      expectedMessageFragment,
    );
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
      rawOutputDir,
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
      rawOutputDir ?? defaultPlayerUiOutputDir(),
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

main().catch(async (error: unknown) => {
  console.error(`ERROR: ${formatErrorMessage(error)}`);

  const debugArtifactDir = process.env.ROKU_DEBUG_ARTIFACT_DIR;
  if (debugArtifactDir !== undefined && debugArtifactDir.trim() !== "") {
    try {
      const target = requireTarget();
      const outputDir = join(
        debugArtifactDir,
        `failure-${formatArtifactTimestamp(new Date())}`,
      );
      await captureRokuDebugSnapshot(target, outputDir);
      console.error(`debug snapshot: ${outputDir}`);
    } catch (diagnosticError) {
      console.error(`debug snapshot failed: ${formatErrorMessage(diagnosticError)}`);
    }
  }

  process.exit(1);
});
