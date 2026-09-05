import {
  isNamedNodeVisible,
  assertNamedNodeText,
  readNamedNodeAttribute,
  sceneGraphContainsText,
} from "@putdotio/rokit";
import { appSceneGraphReadyTimeoutMs } from "./constants.ts";
import type { AppFlowOptions } from "./flow-options.ts";
import type { FlowId, FlowRunContext } from "./flow-suite.ts";
import {
  pressKey,
  querySceneGraph,
  waitForSceneGraphAssertion,
} from "./rokit-device.ts";
import {
  assertNamedNodeHidden,
  assertNamedNodeVisible,
  hasVisibleComponent,
  readNamedNodeIntegerAttribute,
} from "./scenegraph.ts";
import { rokuDesignColor } from "./design-colors.ts";

export type AppFlowDriver = {
  readonly assertListHasItems: (target: string, nodeName: string, timeoutMs?: number) => Promise<number>;
  readonly authRefreshSmoke: (target: string) => Promise<void>;
  readonly focusLastListItem: (target: string, nodeName: string) => Promise<void>;
  readonly focusListItemByIndex: (
    target: string,
    nodeName: string,
    targetIndex: number,
  ) => Promise<void>;
  readonly openHomeItem: (target: string, index: number, expectedScreenName: string) => Promise<void>;
  readonly playbackTypeSmoke: (
    target: string,
    playbackType: "hls" | "mp4",
    contentId: string,
    mediaType: string,
    startFromChoice: "continue" | "beginning",
  ) => Promise<void>;
  readonly imageRenderSmoke: (target: string, contentId: string) => Promise<void>;
  readonly playerUiSmoke: (
    target: string,
    audioContentId: string,
    subtitleContentId: string,
    mediaType: string,
    startFromChoice: "continue" | "beginning",
  ) => Promise<void>;
  readonly resetAuthState: (target: string) => Promise<void>;
  readonly returnToHomeScreen: (target: string) => Promise<void>;
  readonly waitForAnyRouteScreenVisible: (
    target: string,
    screenNames: readonly string[],
    timeoutMs?: number,
  ) => Promise<string>;
  readonly waitForAuthReady: (target: string, profile: string) => Promise<void>;
  readonly waitForBootstrapScreen: (target: string, timeoutMs?: number) => Promise<string>;
  readonly waitForRouteScreenVisible: (
    target: string,
    screenName: string,
    timeoutMs?: number,
  ) => Promise<void>;
};

export async function runAppFlow(
  flowId: FlowId,
  context: FlowRunContext,
  options: AppFlowOptions,
  driver: AppFlowDriver,
): Promise<void> {
  switch (flowId) {
    case "auth":
      await authFlowSmoke(context.target, options.profile, driver);
      return;
    case "get-new-code":
      await driver.authRefreshSmoke(context.target);
      await driver.waitForAuthReady(context.target, options.profile);
      return;
    case "files":
      await filesNavigationFlowSmoke(context.target, options, driver);
      return;
    case "history":
      await historyFlowSmoke(context.target, options.historyExpectedText, driver);
      return;
    case "dialogs":
      await deleteDialogFlowSmoke(context.target, driver);
      return;
    case "settings":
      await settingsFlowSmoke(context.target, driver);
      return;
    case "logout":
      await driver.resetAuthState(context.target);
      await driver.waitForAuthReady(context.target, options.profile);
      return;
    case "playback":
      if (options.playbackContentId === undefined) {
        throw new Error("playback flow requires PLAYBACK_CONTENT_ID or a playback-content-id argument");
      }

      await driver.playbackTypeSmoke(
        context.target,
        "hls",
        options.playbackContentId,
        options.mediaType,
        options.startFromChoice,
      );
      return;
    case "image":
      if (options.imageContentId === undefined) {
        throw new Error("image flow requires IMAGE_CONTENT_ID");
      }

      await driver.imageRenderSmoke(context.target, options.imageContentId);
      return;
    case "tracks":
      if (options.audioContentId === undefined || options.subtitleContentId === undefined) {
        throw new Error(
          "tracks flow requires AUDIO_CONTENT_ID and SUBTITLE_CONTENT_ID or matching arguments",
        );
      }

      await driver.playerUiSmoke(
        context.target,
        options.audioContentId,
        options.subtitleContentId,
        options.mediaType,
        options.startFromChoice,
      );
      return;
  }
}

export async function ensureAppPlaybackTypeSetting(
  target: string,
  playbackType: "hls" | "mp4",
  driver: Pick<
    AppFlowDriver,
    "focusLastListItem" | "focusListItemByIndex" | "returnToHomeScreen" | "waitForRouteScreenVisible"
  >,
): Promise<void> {
  await driver.returnToHomeScreen(target);
  await driver.focusLastListItem(target, "list");
  await pressKey(target, "Select");
  await driver.waitForRouteScreenVisible(target, "settingsScreen", 15_000);
  await driver.focusListItemByIndex(target, "settingsList", 2);

  const currentPlaybackType = await waitForSettingsPlaybackType(target);
  if (currentPlaybackType !== playbackType) {
    await pressKey(target, "Select");
    await waitForSettingsPlaybackType(target, playbackType);
  }

  await pressKey(target, "Back");
  await driver.waitForRouteScreenVisible(target, "homeScreen", 15_000);
  console.log(`asserted app playback type setting: ${playbackType}`);
}

async function authFlowSmoke(
  target: string,
  profile: string,
  driver: Pick<AppFlowDriver, "waitForAuthReady" | "waitForBootstrapScreen">,
): Promise<void> {
  await driver.waitForAuthReady(target, profile);
  const screenName = await driver.waitForBootstrapScreen(target, appSceneGraphReadyTimeoutMs);
  if (screenName === "authScreen") {
    throw new Error("expected authenticated app screen after auth prepare");
  }

  console.log(`asserted authenticated bootstrap screen: ${screenName}`);
}

async function filesNavigationFlowSmoke(
  target: string,
  options: AppFlowOptions,
  driver: Pick<
    AppFlowDriver,
    "assertListHasItems" | "focusListItemByIndex" | "openHomeItem" | "returnToHomeScreen"
  >,
): Promise<void> {
  const { filesFolderName, filesFolderIndex } = options;
  if (filesFolderName === undefined || filesFolderIndex === undefined) {
    throw new Error("files flow requires FILES_FOLDER_NAME and FILES_FOLDER_INDEX for a prepared root folder");
  }
  await driver.returnToHomeScreen(target);
  await driver.openHomeItem(target, 0, "filesScreen");
  await driver.assertListHasItems(target, "fileList");
  const originalTitle = readFilesFolderTitle(await querySceneGraph(target));
  if (originalTitle === filesFolderName) {
    throw new Error("files fixture must have a different title from the root folder");
  }

  await driver.focusListItemByIndex(target, "fileList", filesFolderIndex);
  await waitForSceneGraphAssertion(target, "expected fixture folder focus", (xml) => {
    assertFilesFolder(xml, originalTitle, filesFolderIndex);
  }, 15_000);
  await pressKey(target, "Select");
  await waitForSceneGraphAssertion(target, "expected fixture folder destination", (xml) => {
    assertFilesFolder(xml, filesFolderName);
  }, 30_000);
  await pressKey(target, "Back");
  await waitForSceneGraphAssertion(target, "expected original folder and focus after Back", (xml) => {
    assertFilesFolder(xml, originalTitle, filesFolderIndex);
  }, 30_000);
  console.log("asserted fixture folder opens and Back restores the parent and selected row");
}

function filesScreenXml(xml: string): string {
  const screen = /<FilesScreen\b[^>]*>[\s\S]*?<\/FilesScreen>/u.exec(xml)?.[0];
  if (screen === undefined || !hasVisibleComponent(screen, "FilesScreen")) {
    throw new Error("expected visible Files screen");
  }
  return screen;
}

function readFilesFolderTitle(xml: string): string {
  const screen = filesScreenXml(xml);
  const title = readNamedNodeAttribute(screen, "titleLabel", "text");
  if (title === undefined || title === "") throw new Error("expected Files folder title");
  return title;
}

function assertFilesFolder(xml: string, expectedTitle: string, focusIndex?: number): void {
  const screen = filesScreenXml(xml);
  assertNamedNodeText(screen, "titleLabel", expectedTitle);
  assertNamedNodeHidden(screen, "loading");
  if (focusIndex !== undefined) {
    assertNamedNodeVisible(screen, "fileList");
    const focusAttribute = readNamedNodeAttribute(screen, "fileList", "focusItem") === undefined
      ? "itemFocused"
      : "focusItem";
    if (readNamedNodeIntegerAttribute(screen, "fileList", focusAttribute) !== focusIndex) {
      throw new Error("expected Files selection to return to the fixture row");
    }
  }
}

async function historyFlowSmoke(
  target: string,
  expectedText: string | undefined,
  driver: Pick<
    AppFlowDriver,
    "assertListHasItems" | "openHomeItem" | "returnToHomeScreen" | "waitForRouteScreenVisible"
  >,
): Promise<void> {
  await driver.returnToHomeScreen(target);
  const homeItemCount = await driver.assertListHasItems(target, "list");
  if (homeItemCount <= 3) {
    console.log("history flow skipped: History home item is disabled for this account");
    return;
  }

  await driver.openHomeItem(target, 2, "historyScreen");
  await driver.waitForRouteScreenVisible(target, "historyScreen", 15_000);
  if (expectedText !== undefined) {
    await waitForSceneGraphAssertion(
      target,
      `expected history to render ${expectedText}`,
      (xml) => {
        if (!sceneGraphContainsText(xml, expectedText)) {
          throw new Error(`expected History screen to show ${expectedText}`);
        }
      },
      15_000,
    );
    await pressKey(target, "Back");
    await driver.waitForRouteScreenVisible(target, "homeScreen", 15_000);
    console.log(`asserted history renders ${expectedText}`);
    return;
  }

  await waitForSceneGraphAssertion(
    target,
    "expected history to render rows or an empty state",
    (xml) => {
      if (isNamedNodeVisible(xml, "emptyState") || hasVisibleComponent(xml, "HistoryListItem")) {
        return;
      }

      throw new Error("expected History screen to show rows or the empty history state");
    },
    15_000,
  );
  await pressKey(target, "Back");
  await driver.waitForRouteScreenVisible(target, "homeScreen", 15_000);
  console.log("asserted history renders rows or an empty state");
}

async function deleteDialogFlowSmoke(
  target: string,
  driver: Pick<AppFlowDriver, "assertListHasItems" | "openHomeItem" | "returnToHomeScreen">,
): Promise<void> {
  await driver.returnToHomeScreen(target);
  await driver.openHomeItem(target, 0, "filesScreen");
  await driver.assertListHasItems(target, "fileList");
  await pressKey(target, "Info");
  await waitForSceneGraphAssertion(
    target,
    "expected delete dialog",
    (xml) => {
      assertNamedNodeVisible(xml, "deleteFileDialog");
      assertNamedNodeVisible(xml, "deleteButtonBackground");
      assertNamedNodeVisible(xml, "cancelButtonBackground");
      assertNamedNodeText(xml, "deleteButtonLabel", "Delete file");
      assertNamedNodeText(xml, "cancelButtonLabel", "Cancel");
    },
    10_000,
  );
  await pressKey(target, "Up");
  await waitForSceneGraphAssertion(
    target,
    "expected destructive delete action to receive focus",
    (xml) => {
      assertNamedNodeVisible(xml, "deleteFileDialog");
      assertSceneGraphNodeColor(xml, "deleteButtonBackground", rokuDesignColor("dangerFocused"));
    },
    10_000,
  );
  await pressKey(target, "Back");
  await waitForSceneGraphAssertion(
    target,
    "expected delete dialog to close",
    (xml) => {
      assertNamedNodeHidden(xml, "deleteFileDialog");
      assertNamedNodeVisible(xml, "fileList");
    },
    10_000,
  );
  await driver.returnToHomeScreen(target);
  await pressKey(target, "Back");
  await waitForSceneGraphAssertion(
    target,
    "expected exit app dialog",
    (xml) => {
      assertNamedNodeVisible(xml, "appDialog");
      assertNamedNodeText(xml, "titleLabel", "Exit put.io?");
      assertNamedNodeText(xml, "button0Label", "OK");
      assertNamedNodeText(xml, "button1Label", "Cancel");
    },
    10_000,
  );
  await pressKey(target, "Select");
  await waitForSceneGraphAssertion(
    target,
    "expected exit app dialog cancel to return to home",
    (xml) => {
      assertNamedNodeHidden(xml, "appDialog");
      assertNamedNodeVisible(xml, "homeScreen");
    },
    10_000,
  );
  console.log("asserted delete and exit dialogs trap focus and dismiss safely");
}

async function settingsFlowSmoke(
  target: string,
  driver: Pick<
    AppFlowDriver,
    | "assertListHasItems"
    | "focusLastListItem"
    | "focusListItemByIndex"
    | "returnToHomeScreen"
    | "waitForRouteScreenVisible"
  >,
): Promise<void> {
  await driver.returnToHomeScreen(target);
  await driver.focusLastListItem(target, "list");
  await pressKey(target, "Select");
  await driver.waitForRouteScreenVisible(target, "settingsScreen", 15_000);
  const settingsCount = await driver.assertListHasItems(target, "settingsList");
  if (settingsCount < 6) {
    throw new Error(`expected settings list to include core rows, got ${settingsCount}`);
  }

  await driver.focusListItemByIndex(target, "settingsList", 2);
  await pressKey(target, "Select");
  await waitForSceneGraphAssertion(
    target,
    "expected playback type setting to remain visible after selection",
    (xml) => {
      assertNamedNodeVisible(xml, "settingsScreen");
      assertNamedNodeVisible(xml, "settingsList");
      if (!sceneGraphContainsText(xml, "Video playback type")) {
        throw new Error("expected settings list to include playback type row");
      }
      if (!sceneGraphContainsText(xml, "Version")) {
        throw new Error("expected settings list to include version row");
      }
      if (!sceneGraphContainsText(xml, "Log out")) {
        throw new Error("expected settings list to keep logout as a row");
      }
      if (!sceneGraphContainsText(xml, "Device")) {
        throw new Error("expected settings list to include device info row");
      }
    },
    15_000,
  );
  await pressKey(target, "Back");
  await driver.waitForRouteScreenVisible(target, "homeScreen", 15_000);
  console.log("asserted settings navigation and playback type row interaction");
}

async function waitForSettingsPlaybackType(
  target: string,
  expectedPlaybackType?: "hls" | "mp4",
): Promise<"hls" | "mp4"> {
  let observedPlaybackType: "hls" | "mp4" | undefined;

  await waitForSceneGraphAssertion(
    target,
    "expected settings playback type value",
    (xml) => {
      assertNamedNodeVisible(xml, "settingsScreen");
      assertNamedNodeVisible(xml, "settingsList");
      if (!sceneGraphContainsText(xml, "Video playback type")) {
        throw new Error("expected settings list to include playback type row");
      }
      if (sceneGraphContainsText(xml, "Saving")) {
        throw new Error("settings playback type update still saving");
      }

      observedPlaybackType = readSettingsPlaybackType(xml);
      if (observedPlaybackType === undefined) {
        throw new Error("expected settings playback type value to be visible");
      }
      if (
        expectedPlaybackType !== undefined &&
        observedPlaybackType !== expectedPlaybackType
      ) {
        throw new Error(
          `expected settings playback type ${expectedPlaybackType}, got ${observedPlaybackType}`,
        );
      }
    },
    20_000,
  );

  if (observedPlaybackType === undefined) {
    throw new Error("expected settings playback type value");
  }

  return observedPlaybackType;
}

function readSettingsPlaybackType(xml: string): "hls" | "mp4" | undefined {
  if (sceneGraphContainsText(xml, "HLS")) {
    return "hls";
  }

  if (sceneGraphContainsText(xml, "MP4")) {
    return "mp4";
  }

  return undefined;
}

function assertSceneGraphNodeColor(
  xml: string,
  nodeName: string,
  expectedColor: string,
): void {
  const color = readNamedNodeAttribute(xml, nodeName, "color");
  if (normalizeSceneGraphColor(color) !== normalizeSceneGraphColor(expectedColor)) {
    throw new Error(`expected ${nodeName} color ${expectedColor}, got ${color ?? "missing"}`);
  }
}

function normalizeSceneGraphColor(color: string | undefined): string | undefined {
  if (color === undefined) {
    return undefined;
  }

  const normalizedColor = color.trim().toLowerCase();
  if (normalizedColor.startsWith("#")) {
    return `0x${normalizedColor.slice(1)}`;
  }

  return normalizedColor;
}
