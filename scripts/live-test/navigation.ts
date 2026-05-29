import {
  readSceneGraphFailure,
  sceneGraphContainsText,
} from "@putdotio/rokit";
import {
  appSceneGraphReadyTimeoutMs,
  exitAppDialogTitle,
  sceneGraphPollIntervalMs,
} from "./constants.ts";
import { formatErrorMessage } from "./errors.ts";
import {
  configuredAppId,
  isActiveMediaPlayerState,
  launchApp,
  pressKey,
  queryMediaPlayerStateSafe,
  querySceneGraph,
  waitForDevAppSceneGraphReady,
  waitForSceneGraphAssertion,
} from "./rokit-device.ts";
import {
  assertNamedNodeVisible,
  hasVisibleNode,
  hasVisibleRouteScreen,
  readListFocusIndex,
  readNamedNodeIntegerAttribute,
} from "./scenegraph.ts";
import { sleep } from "./timing.ts";

export type ReturnHomeGuard = {
  readonly assertNotAuthScreen: (xml: string) => void;
  readonly waitForBootstrapScreen: (target: string, timeoutMs?: number) => Promise<string>;
};

export async function dismissExitDialogIfVisible(target: string): Promise<void> {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const xml = await querySceneGraph(target);
    if (!sceneGraphContainsText(xml, exitAppDialogTitle)) {
      return;
    }

    await pressKey(target, attempt % 2 === 0 ? "Back" : "Select");
    await sleep(750);
  }

  const xml = await querySceneGraph(target);
  if (!sceneGraphContainsText(xml, exitAppDialogTitle)) {
    return;
  }

  await pressKey(target, "Home");
  await sleep(1_500);
  await launchApp(target, configuredAppId());
  await waitForDevAppSceneGraphReady(target, appSceneGraphReadyTimeoutMs);
  await waitForSceneGraphAssertion(
    target,
    "expected exit dialog to close",
    (currentXml) => {
      if (sceneGraphContainsText(currentXml, exitAppDialogTitle)) {
        throw new Error("exit dialog is still visible");
      }
    },
    10_000,
  );
}

export async function leaveActivePlaybackSurface(target: string): Promise<void> {
  let lastState = "active playback";

  for (let attempt = 0; attempt < 6; attempt += 1) {
    const mediaState = await queryMediaPlayerStateSafe(target);
    let playerVisible = false;

    try {
      playerVisible = hasVisibleNode(
        await querySceneGraph(target),
        "VideoPlayerScreen",
        "videoPlayerScreen",
      );
    } catch {
      playerVisible = isActiveMediaPlayerState(mediaState);
    }

    if (!playerVisible && !isActiveMediaPlayerState(mediaState)) {
      return;
    }

    lastState = `playerVisible=${playerVisible.toString()} media-player=${mediaState ?? "unknown"}`;
    await pressKey(target, "Back");
    await sleep(2_000);
  }

  throw new Error(`could not leave active playback before relaunch: ${lastState}`);
}

export async function focusLastListItem(target: string, nodeName: string): Promise<void> {
  const startedAt = Date.now();
  let count = 0;
  let focusItem = 0;
  let lastState = `${nodeName} has no items`;

  while (Date.now() - startedAt < 15_000) {
    try {
      const xml = await querySceneGraph(target);
      count = readNamedNodeIntegerAttribute(xml, nodeName, "count");
      focusItem = readNamedNodeIntegerAttribute(xml, nodeName, "focusItem");

      if (count > 0) {
        break;
      }

      lastState = `${nodeName} count is ${count}`;
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  if (count < 1) {
    throw new Error(`expected ${nodeName} to contain at least one item: ${lastState}`);
  }

  const targetIndex = count - 1;
  if (focusItem < 0 || focusItem >= count) {
    throw new Error(`expected ${nodeName}.focusItem to be inside 0..${targetIndex}`);
  }

  for (let step = focusItem; step < targetIndex; step += 1) {
    await pressKey(target, "Down");
    await sleep(900);
  }

  for (let step = focusItem; step > targetIndex; step -= 1) {
    await pressKey(target, "Up");
    await sleep(900);
  }
}

export async function focusListItemByIndex(
  target: string,
  nodeName: string,
  targetIndex: number,
): Promise<void> {
  if (targetIndex < 0) {
    throw new Error(`expected ${nodeName} target index to be non-negative`);
  }

  const startedAt = Date.now();
  let count = 0;
  let focusItem = 0;
  let lastState = `${nodeName} has no items`;

  while (Date.now() - startedAt < 15_000) {
    try {
      const xml = await querySceneGraph(target);
      count = readNamedNodeIntegerAttribute(xml, nodeName, "count");
      focusItem = readListFocusIndex(xml, nodeName);

      if (count > targetIndex) {
        break;
      }

      lastState = `${nodeName} count is ${count}`;
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  if (count <= targetIndex) {
    throw new Error(`expected ${nodeName} to contain item ${targetIndex}: ${lastState}`);
  }

  if (focusItem < 0 || focusItem >= count) {
    throw new Error(`expected ${nodeName}.focusItem to be inside 0..${count - 1}`);
  }

  const direction = focusItem <= targetIndex ? "Down" : "Up";
  const stepCount = Math.abs(targetIndex - focusItem);
  for (let step = 0; step < stepCount; step += 1) {
    await pressKey(target, direction);
    await sleep(900);
  }
}

export async function assertListHasItems(
  target: string,
  nodeName: string,
  timeoutMs = 30_000,
): Promise<number> {
  const startedAt = Date.now();
  let lastState = `${nodeName} has no items`;

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);
      assertNamedNodeVisible(xml, nodeName);
      const count = readNamedNodeIntegerAttribute(xml, nodeName, "count");

      if (count > 0) {
        return count;
      }

      lastState = `${nodeName} count is ${count}`;
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected ${nodeName} to contain items: ${lastState}`);
}

export async function returnToHomeScreen(
  target: string,
  guard: ReturnHomeGuard,
): Promise<void> {
  await launchApp(target, configuredAppId());
  await waitForDevAppSceneGraphReady(target, appSceneGraphReadyTimeoutMs);

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const xml = await querySceneGraph(target);

    if (hasVisibleRouteScreen(xml, "homeScreen")) {
      await dismissExitDialogIfVisible(target);
      await waitForRouteScreenVisible(target, "homeScreen", 15_000);
      return;
    }

    guard.assertNotAuthScreen(xml);
    await pressKey(target, "Back");
    await sleep(900);
  }

  const screenName = await guard.waitForBootstrapScreen(target, 5_000);
  if (screenName !== "homeScreen") {
    throw new Error(`expected to return to homeScreen, got ${screenName}`);
  }

  await dismissExitDialogIfVisible(target);
  await waitForRouteScreenVisible(target, "homeScreen", 15_000);
}

export async function openHomeItem(
  target: string,
  index: number,
  expectedScreenName: string,
): Promise<void> {
  await waitForRouteScreenVisible(target, "homeScreen", 15_000);
  await assertListHasItems(target, "list", 15_000);
  await focusListItemByIndex(target, "list", index);
  await pressKey(target, "Select");
  await waitForRouteScreenVisible(target, expectedScreenName, 30_000);
}

export async function waitForRouteScreenVisible(
  target: string,
  screenName: string,
  timeoutMs = 30_000,
): Promise<void> {
  const startedAt = Date.now();
  let lastState = `${screenName} not visible`;

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);

      if (hasVisibleRouteScreen(xml, screenName)) {
        return;
      }

      lastState = readSceneGraphFailure(xml) ?? `${screenName} not visible`;
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected ${screenName} to be visible: ${lastState}`);
}

export async function waitForAnyRouteScreenVisible(
  target: string,
  screenNames: readonly string[],
  timeoutMs = 30_000,
): Promise<string> {
  const startedAt = Date.now();
  let lastState = "waiting for route";

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);
      for (const screenName of screenNames) {
        if (hasVisibleRouteScreen(xml, screenName)) {
          return screenName;
        }
      }

      lastState = readSceneGraphFailure(xml) ?? `none of ${screenNames.join(", ")} visible`;
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected one of ${screenNames.join(", ")} to be visible: ${lastState}`);
}
