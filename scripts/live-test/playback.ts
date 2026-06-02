import {
  isNamedNodeVisible,
  readMediaPlayerContainer,
  readSceneGraphFailure,
} from "@putdotio/rokit";
import { assertNotAuthScreen } from "./auth.ts";
import {
  maxPlaybackLaunchAttempts,
  playbackLaunchInitialSettleMs,
  playbackLaunchPostPromptSettleMs,
  playbackLaunchRetryMs,
  playbackLaunchSceneGraphPollIntervalMs,
  playbackLaunchTimeoutMs,
  sceneGraphPollIntervalMs,
} from "./constants.ts";
import { formatErrorMessage } from "./errors.ts";
import { leaveActivePlaybackSurface } from "./navigation.ts";
import {
  assertMediaPlayerContainer,
  configuredAppId,
  isActiveMediaPlayerState,
  launchDeepLink,
  pressKey,
  queryActiveAppSafe,
  queryMediaPlayerStateSafe,
  queryMediaPlayerXmlSafe,
  querySceneGraph,
  waitForMediaPlayerState,
  waitForSceneGraphAssertion,
  type ActiveApp,
} from "./rokit-device.ts";
import {
  assertNamedNodeAbsent,
  assertNamedNodeHidden,
  assertNamedNodeHiddenOrAbsent,
  assertNamedNodeVisible,
  escapeRegExp,
  hasVisibleNode,
  hasVisibleRouteScreen,
} from "./scenegraph.ts";
import { sleep } from "./timing.ts";
import { createPlaybackLaunchRetry } from "../roku-playback-launch.ts";

export function playbackTypeFromArg(value: string): "hls" | "mp4" {
  if (value === "hls" || value === "mp4") {
    return value;
  }

  throw new Error("playback type must be hls or mp4");
}

export async function assertHlsPlaybackSurfaceOnDevice(
  target: string,
  contentId: string,
): Promise<void> {
  const xml = await querySceneGraph(target);

  try {
    assertHlsPlaybackSurface(xml, contentId);
    return;
  } catch (error) {
    assertDirectPlaybackSurface(xml, contentId);

    const mediaPlayerXml = await queryMediaPlayerXmlSafe(target);
    if (
      hasVisibleRouteScreen(xml, "videoPlayerScreen") &&
      mediaPlayerXml !== undefined &&
      readMediaPlayerContainer(mediaPlayerXml) === "hls" &&
      isActiveMediaPlayerState(await queryMediaPlayerStateSafe(target))
    ) {
      return;
    }

    throw error;
  }
}

export async function assertDirectPlaybackSurfaceOnDevice(
  target: string,
  contentId: string,
): Promise<void> {
  const xml = await querySceneGraph(target);
  assertDirectPlaybackSurface(xml, contentId);
}

export async function assertPlaybackTypeSurfaceOnDevice(
  target: string,
  playbackType: "hls" | "mp4",
  contentId: string,
): Promise<void> {
  if (playbackType === "hls") {
    await assertHlsPlaybackSurfaceOnDevice(target, contentId);
    await assertMediaPlayerContainer(target, "hls");
  } else {
    await assertDirectPlaybackSurfaceOnDevice(target, contentId);
    await assertMediaPlayerContainer(target, "mp4");
  }
}

export async function ensureMediaPlaying(target: string): Promise<void> {
  if ((await queryMediaPlayerStateSafe(target)) === "play") {
    return;
  }

  await pressKey(target, "Play");
  if (!(await waitForMediaPlayerState(target, "play", 8_000))) {
    throw new Error("expected media-player to resume playback");
  }
}

function hasStartFromPrompt(xml: string): boolean {
  return hasVisibleNode(xml, "ContinueWatchingPrompt", "continueWatchingPrompt");
}

function assertDirectPlaybackSurface(xml: string, contentId: string): void {
  assertNamedNodeVisible(xml, "videoPlayerScreen");
  assertNamedNodeHiddenOrAbsent(xml, "videoScreen");
  assertNamedNodeAbsent(xml, "button-play");
  assertNamedNodeAbsent(xml, "subtitleList");

  if (xml.includes("original=1")) {
    throw new Error("expected player content to avoid original=1 playback URLs");
  }

  const hasFilesPlaybackPath = xml.includes(`/files/${contentId}/`);
  const hasStreamPlaybackPath = new RegExp(`/stream/${escapeRegExp(contentId)}(?:\\.|[/?&]|$)`).test(xml);
  if (!hasFilesPlaybackPath && !hasStreamPlaybackPath) {
    throw new Error(`expected player content to include playback path for ${contentId}`);
  }
}

function assertHlsPlaybackSurface(xml: string, contentId: string): void {
  assertDirectPlaybackSurface(xml, contentId);

  if (!xml.includes("/hls/") && !xml.includes(".m3u8")) {
    throw new Error(`expected player content for ${contentId} to use an HLS URL`);
  }
}

function readVisiblePlaybackContentId(xml: string): string | undefined {
  const match = /\/(?:files|stream)\/(\d+)(?:\/|\.|[?&]|$)/.exec(xml);
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

export async function launchPlayback(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
): Promise<ActiveApp> {
  const initialApp = await launchDeepLink(target, contentId, mediaType, startFromChoice);
  const start = Date.now();
  let didChooseStartFrom = false;
  let lastStartFromChoiceAt = 0;
  const retry = createPlaybackLaunchRetry({
    afterLaunch: async () => {
      await sleep(1_500);
    },
    formatError: formatErrorMessage,
    initialApp,
    initialLastLaunchAtMs: Date.now(),
    initialState: "unknown",
    launch: async () => await launchDeepLink(target, contentId, mediaType, startFromChoice),
    launchLabel: "deeplink",
    maxAttempts: maxPlaybackLaunchAttempts,
    onRetry: () => {
      didChooseStartFrom = false;
      lastStartFromChoiceAt = 0;
    },
    retryDelayMs: playbackLaunchRetryMs,
  });

  while (Date.now() - start < playbackLaunchTimeoutMs) {
    let xml: string;

    try {
      xml = await querySceneGraph(target);
    } catch (error) {
      const mediaState = await queryMediaPlayerStateSafe(target);
      const activeApp = await queryActiveAppSafe(target);
      retry.setLastState(
        `scene graph unavailable: ${formatErrorMessage(error)}; ` +
          `media-player=${mediaState ?? "unknown"}; ` +
          `active-app=${activeApp ? activeApp.id : "unknown"}`,
      );
      if (!isActiveMediaPlayerState(mediaState) && activeApp?.id !== configuredAppId()) {
        await retry.maybeRetry(retry.lastState);
      }
      await sleep(sceneGraphPollIntervalMs);
      continue;
    }

    assertNotAuthScreen(xml);

    if (!didChooseStartFrom && hasStartFromPrompt(xml)) {
      didChooseStartFrom = true;
      lastStartFromChoiceAt = Date.now();
      await chooseStartFrom(target, startFromChoice);
      retry.setLastState("startFromPrompt");
    } else if (hasStartFromPrompt(xml)) {
      retry.setLastState("startFromPrompt");
      if (Date.now() - lastStartFromChoiceAt >= playbackLaunchRetryMs) {
        lastStartFromChoiceAt = Date.now();
        await chooseStartFrom(target, startFromChoice);
      }
    } else if (hasVisibleRouteScreen(xml, "videoPlayerScreen")) {
      try {
        assertDirectPlaybackSurface(xml, contentId);
        return retry.app;
      } catch (error) {
        const visibleContentId = readVisiblePlaybackContentId(xml);
        let didRetry = false;
        if (visibleContentId !== undefined && visibleContentId !== contentId) {
          didRetry = await retry.maybeRetry(`stale content ${visibleContentId}`);
        }
        if (!didRetry) {
          retry.setLastState(formatErrorMessage(error));
        }
      }
    } else if (hasVisibleRouteScreen(xml, "videoScreen")) {
      retry.setLastState("videoScreen");
    } else if (hasVisibleRouteScreen(xml, "searchScreen")) {
      retry.setLastState("searchScreen");
      await retry.maybeRetry(retry.lastState);
    } else if (hasVisibleRouteScreen(xml, "homeScreen")) {
      retry.setLastState("homeScreen");
      await retry.maybeRetry(retry.lastState);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  try {
    const xml = await querySceneGraph(target);
    assertDirectPlaybackSurface(xml, contentId);
    return retry.app;
  } catch {
    throw new Error(
      `expected videoPlayerScreen after deeplink, last visible state: ${retry.lastState}`,
    );
  }
}

export async function launchPlaybackWithRemoteStart(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice: "continue" | "beginning",
  options: { readonly reuseExisting?: boolean } = {},
): Promise<ActiveApp> {
  if (options.reuseExisting !== false) {
    const existingPlaybackApp = await findExistingPlaybackSurface(target, contentId);
    if (existingPlaybackApp !== undefined) {
      await closePlaybackTransientOverlays(target);
      return existingPlaybackApp;
    }
  }

  await leaveActivePlaybackSurface(target);

  const initialApp = await launchDeepLink(target, contentId, mediaType, startFromChoice);
  let didChooseStartFrom = false;
  let lastStartFromChoiceAt = 0;
  const retry = createPlaybackLaunchRetry({
    formatError: formatErrorMessage,
    initialApp,
    initialState: "playback deeplink launch",
    launch: async () => await launchDeepLink(target, contentId, mediaType, startFromChoice),
    launchLabel: "playback launch",
    maxAttempts: maxPlaybackLaunchAttempts,
    onRetry: () => {
      didChooseStartFrom = false;
      lastStartFromChoiceAt = 0;
    },
    retryDelayMs: playbackLaunchRetryMs,
  });

  await sleep(playbackLaunchInitialSettleMs);
  const start = Date.now();

  while (Date.now() - start < playbackLaunchTimeoutMs) {
    const mediaState = await queryMediaPlayerStateSafe(target);

    let xml: string;

    try {
      xml = await querySceneGraph(target);
    } catch (error) {
      retry.setLastState(
        `scene graph unavailable: ${formatErrorMessage(error)}; media-player=${mediaState ?? "unknown"}`,
      );
      await sleep(playbackLaunchSceneGraphPollIntervalMs);
      continue;
    }

    assertNotAuthScreen(xml);

    const sceneGraphFailure = readSceneGraphFailure(xml);
    if (sceneGraphFailure !== undefined) {
      const activeApp = await queryActiveAppSafe(target);
      retry.setLastState(
        `scene graph failed: ${sceneGraphFailure}; active-app=${activeApp?.id ?? "unknown"}; media-player=${mediaState ?? "unknown"}`,
      );

      if (!isActiveMediaPlayerState(mediaState)) {
        await retry.maybeRetry(retry.lastState);
      }
    } else if (!didChooseStartFrom && hasStartFromPrompt(xml)) {
      didChooseStartFrom = true;
      lastStartFromChoiceAt = Date.now();
      await chooseStartFrom(target, startFromChoice);
      await sleep(playbackLaunchPostPromptSettleMs);
      retry.setLastState("startFromPrompt");
    } else if (hasStartFromPrompt(xml)) {
      retry.setLastState("startFromPrompt");
      if (Date.now() - lastStartFromChoiceAt >= playbackLaunchRetryMs) {
        lastStartFromChoiceAt = Date.now();
        await chooseStartFrom(target, startFromChoice);
        await sleep(playbackLaunchPostPromptSettleMs);
      }
    } else if (hasVisibleRouteScreen(xml, "videoPlayerScreen")) {
      try {
        assertDirectPlaybackSurface(xml, contentId);
        return retry.app;
      } catch (error) {
        const visibleContentId = readVisiblePlaybackContentId(xml);
        let didRetry = false;
        if (visibleContentId !== undefined && visibleContentId !== contentId) {
          didRetry = await retry.maybeRetry(`stale content ${visibleContentId}`);
        }
        if (!didRetry) {
          retry.setLastState(formatErrorMessage(error));
        }
      }
    } else if (hasVisibleRouteScreen(xml, "videoScreen")) {
      retry.setLastState("videoScreen");
    } else if (hasVisibleRouteScreen(xml, "searchScreen")) {
      retry.setLastState("searchScreen");
    } else if (hasVisibleRouteScreen(xml, "homeScreen")) {
      retry.setLastState("homeScreen");

      if (Date.now() - start >= playbackLaunchRetryMs) {
        await retry.maybeRetry(retry.lastState);
      }
    }

    await sleep(playbackLaunchSceneGraphPollIntervalMs);
  }

  try {
    const xml = await querySceneGraph(target);
    assertDirectPlaybackSurface(xml, contentId);
    return retry.app;
  } catch (error) {
    const mediaState = await queryMediaPlayerStateSafe(target);
    const mediaPlayerXml = await queryMediaPlayerXmlSafe(target);

    if (
      isActiveMediaPlayerState(mediaState) &&
      mediaPlayerXml !== undefined &&
      readMediaPlayerContainer(mediaPlayerXml) !== undefined
    ) {
      await sleep(5_000);
      const xml = await querySceneGraph(target);
      assertDirectPlaybackSurface(xml, contentId);
      return retry.app;
    }

    retry.setLastState(`${retry.lastState}; final check: ${formatErrorMessage(error)}`);
  }

  throw new Error(
    `expected videoPlayerScreen after playback deeplink, last visible state: ${retry.lastState}`,
  );
}

async function findExistingPlaybackSurface(
  target: string,
  contentId: string,
): Promise<ActiveApp | undefined> {
  const activeApp = await queryActiveAppSafe(target);
  if (activeApp?.id !== configuredAppId()) {
    return undefined;
  }

  try {
    const xml = await querySceneGraph(target);
    if (!hasVisibleRouteScreen(xml, "videoPlayerScreen")) {
      return undefined;
    }

    assertDirectPlaybackSurface(xml, contentId);
    return activeApp;
  } catch {
    return undefined;
  }
}

async function closePlaybackTransientOverlays(target: string): Promise<void> {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const xml = await querySceneGraph(target);
    if (!isNamedNodeVisible(xml, "trackMenu")) {
      return;
    }

    await pressKey(target, "Back");
    await sleep(750);
  }

  await waitForSceneGraphAssertion(
    target,
    "expected track menu to close before reusing playback surface",
    (xml) => {
      assertNamedNodeHidden(xml, "trackMenu");
    },
    5_000,
  );
}
