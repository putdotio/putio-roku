import { mkdir } from "node:fs/promises";
import { join } from "node:path";
import {
  assertNamedNodeState,
  assertNamedNodeText,
  launchApp as rokitLaunchApp,
  readNamedNodeAttribute,
  waitForSceneGraphNode as rokitWaitForSceneGraphNode,
} from "@putdotio/rokit";
import {
  exitAppDialogTitle,
  sceneGraphRequestTimeoutMs,
} from "./constants.ts";
import { rokuDesignColor } from "./design-colors.ts";
import { formatErrorMessage } from "./errors.ts";
import { imageRenderSmoke } from "./image.ts";
import {
  captureDeveloperScreenshot,
  configuredAppId,
  pressKey,
  requireDeveloperPassword,
  rokitContext,
  typeText,
  waitForNamedNodeVisible,
  waitForSceneGraphAssertion,
} from "./rokit-device.ts";
import { retryAsync, sleep } from "./timing.ts";

export const visualLabStories = [
  ["app-dialog-empty", "AppDialog / no message"],
  ["app-dialog-message", "AppDialog / message"],
  ["delete-dialog-short", "DeleteFileDialog / short file"],
  ["delete-dialog-long", "DeleteFileDialog / long file"],
  ["continue-watching", "ContinueWatchingPrompt"],
  ["continue-watching-beginning", "ContinueWatchingPrompt / beginning"],
  ["track-menu-audio", "TrackMenu / audio"],
  ["track-menu-subtitles", "TrackMenu / subtitles"],
  ["track-menu-subtitles-scroll", "TrackMenu / subtitles scroll"],
  ["track-menu-speed", "TrackMenu / playback speed"],
  ["conversion-status-converting", "VideoConversionStatus / converting"],
  ["conversion-status-error", "VideoConversionStatus / error"],
  ["list-item-generic", "ListItem"],
  ["list-item-files", "FileListItem"],
  ["list-item-file-watched-focused", "FileListItem / watched focused"],
  ["list-item-file-loading-focused", "FileListItem / loading focused"],
  ["list-item-history", "HistoryListItem"],
] as const;

export type VisualLabStory = (typeof visualLabStories)[number];

export const defaultVisualLabStoryIds = new Set<string>([
  "app-dialog-empty",
  "app-dialog-message",
]);

const labLaunchRetryCount = 24;
const labLaunchRetryDelayMs = 5_000;
const labCaptureRestartInterval = 5;

export function selectVisualLabStories(storyIds: readonly string[]): readonly VisualLabStory[] {
  if (storyIds.length === 0) {
    return visualLabStories.filter(([storyId]) => defaultVisualLabStoryIds.has(storyId));
  }

  const storiesById = new Map<string, VisualLabStory>(visualLabStories.map((story) => [story[0], story]));
  const selectedStories = storyIds.map((storyId) => storiesById.get(storyId));
  const unknownStoryIds = storyIds.filter((storyId, index) => selectedStories[index] === undefined);

  if (unknownStoryIds.length > 0) {
    throw new Error(`unknown lab story id(s): ${unknownStoryIds.join(", ")}`);
  }

  return selectedStories.filter((story): story is VisualLabStory => story !== undefined);
}

export type VisualPageCaptureOptions = {
  readonly includeAuth: boolean;
  readonly imageContentId?: string;
  readonly profile: string;
};

export type VisualCaptureDriver = {
  readonly assertListHasItems: (target: string, nodeName: string, timeoutMs?: number) => Promise<number>;
  readonly dismissExitDialogIfVisible: (target: string) => Promise<void>;
  readonly focusLastListItem: (target: string, nodeName: string) => Promise<void>;
  readonly leaveActivePlaybackSurface: (target: string) => Promise<void>;
  readonly openHomeItem: (target: string, index: number, expectedScreenName: string) => Promise<void>;
  readonly readListFocusIndex: (xml: string, nodeName: string) => number;
  readonly resetAuthState: (target: string) => Promise<void>;
  readonly returnToHomeScreen: (target: string) => Promise<void>;
  readonly waitForAnyRouteScreenVisible: (
    target: string,
    screenNames: readonly string[],
    timeoutMs?: number,
  ) => Promise<string>;
  readonly waitForAuthCode: (target: string) => Promise<string>;
  readonly waitForAuthReady: (target: string, profile: string) => Promise<void>;
  readonly waitForRouteScreenVisible: (
    target: string,
    screenName: string,
    timeoutMs?: number,
  ) => Promise<void>;
};

export type VisualLabCaptureOperations = {
  readonly captureStory: (storyId: string) => Promise<void>;
  readonly launchStory: (storyId: string, expectedTitle: string) => Promise<void>;
  readonly leaveActivePlaybackSurface: () => Promise<void>;
  readonly logRecovery: (storyId: string, error: unknown) => void;
  readonly navigateStoryList: (
    currentStoryIndex: number,
    nextStoryIndex: number,
    storyId: string,
    expectedTitle: string,
  ) => Promise<void>;
  readonly openFocusedStory: (storyId: string, expectedTitle: string) => Promise<void>;
  readonly restartSession: () => Promise<void>;
  readonly returnToStoryList: () => Promise<void>;
};

export async function captureVisualPages(
  target: string,
  outputDir: string,
  options: VisualPageCaptureOptions,
  driver: VisualCaptureDriver,
): Promise<void> {
  const password = requireDeveloperPassword();
  await mkdir(outputDir, { recursive: true });
  console.log(`visual page captures: ${outputDir}`);

  const capturePage = async (name: string): Promise<void> => {
    await sleep(1_500);
    const outputPath = join(outputDir, `${name}.jpg`);
    const capturedPath = await captureDeveloperScreenshot(target, password, outputPath);
    console.log(`visual page captured: ${name} ${capturedPath}`);
    await sleep(2_000);
  };

  if (options.includeAuth) {
    await driver.resetAuthState(target);
    await driver.waitForAuthCode(target);
    await capturePage("auth");
    await driver.waitForAuthReady(target, options.profile);
  } else {
    await driver.waitForAuthReady(target, options.profile);
  }

  await driver.returnToHomeScreen(target);
  await capturePage("home");

  await driver.openHomeItem(target, 0, "filesScreen");
  await driver.assertListHasItems(target, "fileList");
  await capturePage("files");

  await pressKey(target, "Info");
  await waitForNamedNodeVisible(target, "deleteFileDialog", 10_000);
  await pressKey(target, "Up");
  await waitForNamedNodeColor(target, "deleteButtonBackground", rokuDesignColor("dangerFocused"), 10_000);
  await capturePage("file-delete-dialog");
  await pressKey(target, "Back");
  await waitForSceneGraphAssertion(
    target,
    "expected delete dialog to close before visual capture navigation continues",
    (xml) => {
      assertNamedNodeHidden(xml, "deleteFileDialog");
      assertNamedNodeVisible(xml, "fileList");
    },
    10_000,
  );

  if (options.imageContentId !== undefined) {
    await imageRenderSmoke(target, options.imageContentId);
    await capturePage("image");
  } else {
    console.log("visual page skipped: IMAGE_CONTENT_ID is not set");
  }

  await captureSearchStates(target, capturePage, driver);

  await driver.returnToHomeScreen(target);
  const homeItemCount = await driver.assertListHasItems(target, "list");
  if (homeItemCount > 3) {
    await driver.openHomeItem(target, 2, "historyScreen");
    await driver.waitForAnyRouteScreenVisible(target, ["historyScreen"], 15_000);
    await capturePage("history");
  } else {
    console.log("visual page skipped: history home item is disabled for this account");
  }

  await driver.returnToHomeScreen(target);
  await driver.focusLastListItem(target, "list");
  await pressKey(target, "Select");
  await driver.waitForRouteScreenVisible(target, "settingsScreen", 15_000);
  await driver.assertListHasItems(target, "settingsList");
  await capturePage("settings");

  await pressKey(target, "Back");
  await driver.waitForRouteScreenVisible(target, "homeScreen", 15_000);

  await captureExitDialog(target, capturePage, driver);
  await driver.waitForRouteScreenVisible(target, "homeScreen", 15_000);
}

export async function captureVisualLabStories(
  target: string,
  outputDir: string,
  storyIds: readonly string[],
  driver: Pick<VisualCaptureDriver, "leaveActivePlaybackSurface">,
): Promise<void> {
  const selectedStories = selectVisualLabStories(storyIds);
  const password = requireDeveloperPassword();
  await mkdir(outputDir, { recursive: true });
  console.log(`visual lab captures: ${outputDir}`);

  await captureVisualLabStorySequence(selectedStories, {
    captureStory: async (storyId) => {
      await sleep(1_500);
      const outputPath = join(outputDir, `${storyId}.jpg`);
      const capturedPath = await captureDeveloperScreenshot(target, password, outputPath);
      console.log(`visual lab captured: ${storyId} ${capturedPath}`);
      await sleep(2_000);
    },
    launchStory: async (storyId, expectedTitle) => await launchLabStory(target, storyId, expectedTitle),
    leaveActivePlaybackSurface: async () => await driver.leaveActivePlaybackSurface(target),
    logRecovery: (storyId, error) => {
      console.log(`visual lab recovered by relaunching ${storyId}: ${formatVisualCaptureError(error)}`);
    },
    navigateStoryList: async (currentStoryIndex, storyIndex, storyId, expectedTitle) =>
      await navigateLabStoryList(target, currentStoryIndex, storyIndex, storyId, expectedTitle),
    openFocusedStory: async (storyId, expectedTitle) =>
      await openFocusedLabStory(target, storyId, expectedTitle),
    restartSession: async () => await restartLabCaptureSession(target),
    returnToStoryList: async () => await returnToLabStoryList(target),
  });
}

export async function captureVisualLabStorySequence(
  selectedStories: readonly VisualLabStory[],
  operations: VisualLabCaptureOperations,
  restartInterval = labCaptureRestartInterval,
): Promise<void> {
  await operations.leaveActivePlaybackSurface();

  let currentStoryIndex = -1;

  for (let selectedIndex = 0; selectedIndex < selectedStories.length; selectedIndex += 1) {
    const [storyId, expectedTitle] = selectedStories[selectedIndex];
    const storyIndex = visualLabStories.findIndex(([knownStoryId]) => knownStoryId === storyId);

    if (storyIndex < 0) {
      throw new Error(`unknown lab story id: ${storyId}`);
    }

    if (currentStoryIndex < 0) {
      await operations.launchStory(storyId, expectedTitle);
    } else {
      try {
        await operations.returnToStoryList();
        await operations.navigateStoryList(currentStoryIndex, storyIndex, storyId, expectedTitle);
        await operations.openFocusedStory(storyId, expectedTitle);
      } catch (error) {
        operations.logRecovery(storyId, error);
        await operations.launchStory(storyId, expectedTitle);
      }
    }

    currentStoryIndex = storyIndex;
    await operations.captureStory(storyId);

    if (selectedIndex < selectedStories.length - 1 && (selectedIndex + 1) % restartInterval === 0) {
      await operations.restartSession();
      currentStoryIndex = -1;
    }
  }
}

async function captureExitDialog(
  target: string,
  capturePage: (name: string) => Promise<void>,
  driver: Pick<VisualCaptureDriver, "dismissExitDialogIfVisible" | "returnToHomeScreen">,
): Promise<void> {
  await driver.returnToHomeScreen(target);
  await pressKey(target, "Back");
  await waitForSceneGraphAssertion(
    target,
    "expected exit app dialog",
    (xml) => {
      assertNamedNodeVisible(xml, "appDialog");
      assertNamedNodeText(xml, "titleLabel", exitAppDialogTitle);
    },
    10_000,
  );
  await pressKey(target, "Up");
  await waitForNamedNodeColor(target, "button0Background", rokuDesignColor("primary"), 10_000);
  await capturePage("exit-app-dialog");
  await driver.dismissExitDialogIfVisible(target);
}

async function captureSearchStates(
  target: string,
  capturePage: (name: string) => Promise<void>,
  driver: Pick<
    VisualCaptureDriver,
    "assertListHasItems" | "openHomeItem" | "readListFocusIndex" | "returnToHomeScreen"
  >,
): Promise<void> {
  await driver.returnToHomeScreen(target);
  await driver.openHomeItem(target, 1, "searchScreen");
  await waitForNamedNodeVisible(target, "keyboard", 15_000);
  await capturePage("search-empty");

  await typeText(target, "sintel");
  await driver.assertListHasItems(target, "searchFileList", 20_000);
  await capturePage("search-results");

  await pressKey(target, "Info");
  await waitForSceneGraphAssertion(
    target,
    "expected first search result to receive focus",
    (xml) => {
      assertNamedNodeVisible(xml, "searchFileList");
      const focused = driver.readListFocusIndex(xml, "searchFileList");
      if (focused !== 0) {
        throw new Error(`expected searchFileList focus index 0, got ${focused}`);
      }
    },
    10_000,
  );
  await capturePage("search-result-focused");
}

async function waitForNamedNodeColor(
  target: string,
  nodeName: string,
  expectedColor: string,
  timeoutMs: number,
): Promise<void> {
  await waitForSceneGraphAssertion(
    target,
    `expected ${nodeName} color ${expectedColor}`,
    (xml) => {
      const color = readNamedNodeAttribute(xml, nodeName, "color");
      if (normalizeSceneGraphColor(color) !== normalizeSceneGraphColor(expectedColor)) {
        throw new Error(`expected ${nodeName} color ${expectedColor}, got ${color ?? "missing"}`);
      }
    },
    timeoutMs,
  );
}

function normalizeSceneGraphColor(color: string | undefined): string | undefined {
  if (color === undefined) {
    return undefined;
  }

  return color.replace(/^#/, "").replace(/^0x/i, "").toUpperCase();
}

async function launchLabStory(target: string, storyId: string, expectedTitle: string): Promise<void> {
  await retryAsync(
    async () => {
      await rokitLaunchApp(
        rokitContext(target),
        configuredAppId(),
        new Map([
          ["lab", "1"],
          ["story", storyId],
        ]),
      );

      await rokitWaitForSceneGraphNode(
        rokitContext(target, sceneGraphRequestTimeoutMs),
        "detailView",
        { state: "visible" },
        15_000,
      );
    },
    {
      attempts: labLaunchRetryCount,
      delayMs: labLaunchRetryDelayMs,
      onRetry: (error, attempt) => {
        console.log(`visual lab launch retry ${attempt}/${labLaunchRetryCount}: ${formatVisualCaptureError(error)}`);
      },
    },
  );

  await waitForSceneGraphAssertion(
    target,
    `expected lab story ${storyId}`,
    (xml) => {
      assertNamedNodeText(xml, "storyTitle", expectedTitle);
    },
    15_000,
  );
}

async function restartLabCaptureSession(target: string): Promise<void> {
  try {
    await pressKey(target, "Home");
  } catch (error) {
    console.log(`visual lab Home cooldown skipped: ${formatVisualCaptureError(error)}`);
  }

  await sleep(5_000);
}

function formatVisualCaptureError(error: unknown): string {
  return formatErrorMessage(error);
}

async function returnToLabStoryList(target: string): Promise<void> {
  await pressKey(target, "Left");
  await rokitWaitForSceneGraphNode(
    rokitContext(target, sceneGraphRequestTimeoutMs),
    "listView",
    { state: "visible" },
    15_000,
  );
}

async function navigateLabStoryList(
  target: string,
  currentStoryIndex: number,
  nextStoryIndex: number,
  storyId: string,
  expectedTitle: string,
): Promise<void> {
  if (nextStoryIndex < 0) {
    throw new Error(`unknown lab story id: ${storyId}`);
  }

  const direction = nextStoryIndex > currentStoryIndex ? "Down" : "Up";
  const pressCount = Math.abs(nextStoryIndex - currentStoryIndex);

  for (let i = 0; i < pressCount; i += 1) {
    await pressKey(target, direction);
    await sleep(250);
  }

  await waitForSceneGraphAssertion(
    target,
    `expected lab list story ${storyId}`,
    (xml) => {
      assertNamedNodeText(xml, "listStoryTitle", expectedTitle);
    },
    15_000,
  );
}

async function openFocusedLabStory(target: string, storyId: string, expectedTitle: string): Promise<void> {
  await pressKey(target, "Select");
  await rokitWaitForSceneGraphNode(
    rokitContext(target, sceneGraphRequestTimeoutMs),
    "detailView",
    { state: "visible" },
    15_000,
  );
  await waitForSceneGraphAssertion(
    target,
    `expected lab story ${storyId}`,
    (xml) => {
      assertNamedNodeText(xml, "storyTitle", expectedTitle);
    },
    15_000,
  );
}

function assertNamedNodeVisible(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "visible");
}

function assertNamedNodeHidden(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "hidden");
}
