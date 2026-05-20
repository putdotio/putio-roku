import { execFile as execFileCallback } from "node:child_process";
import process from "node:process";
import { promisify } from "node:util";
import {
  readNamedNodeAttribute,
  readSceneGraphFailure,
} from "@putdotio/rokit";
import {
  appSceneGraphReadyTimeoutMs,
  authPrepareTimeoutMs,
  sceneGraphPollIntervalMs,
} from "./constants.ts";
import { formatErrorMessage } from "./errors.ts";
import {
  launchApp,
  pressKey,
  querySceneGraph,
  waitForNamedNodeVisible,
} from "./rokit-device.ts";
import {
  hasVisibleRouteScreen,
} from "./scenegraph.ts";
import { sleep } from "./timing.ts";

const execFile = promisify(execFileCallback);

export type AuthDriver = {
  readonly dismissExitDialogIfVisible: (target: string) => Promise<void>;
  readonly focusLastListItem: (target: string, nodeName: string) => Promise<void>;
  readonly returnToHomeScreen: (target: string) => Promise<void>;
  readonly waitForDevAppSceneGraphReady: (target: string, timeoutMs?: number) => Promise<void>;
  readonly waitForRouteScreenVisible: (
    target: string,
    screenName: string,
    timeoutMs?: number,
  ) => Promise<void>;
};

export function readAuthCode(xml: string): string | undefined {
  if (!hasVisibleRouteScreen(xml, "authScreen")) {
    return undefined;
  }

  const tileCode = Array.from({ length: 6 }, (_, index) =>
    readNamedNodeAttribute(xml, `codeChar${index}`, "text")?.trim() ?? "",
  ).join("");
  const code = tileCode.length === 6 ? tileCode : readNamedNodeAttribute(xml, "code", "text")?.trim();

  if (code === undefined || code === "" || code === "Loading..." || code === "Error!") {
    return undefined;
  }

  return code;
}

export async function waitForAuthCode(target: string, timeoutMs = 30_000): Promise<string> {
  const startedAt = Date.now();
  let lastState = "waiting for auth code";

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);
      const code = readAuthCode(xml);

      if (code !== undefined) {
        return code;
      }

      lastState = hasVisibleRouteScreen(xml, "authScreen")
        ? "auth screen visible without code"
        : "auth screen not visible";
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected auth code to load: ${lastState}`);
}

export async function waitForBootstrapScreen(target: string, timeoutMs = 30_000): Promise<string> {
  const startedAt = Date.now();
  const screenNames = [
    "authScreen",
    "homeScreen",
    "searchScreen",
    "historyScreen",
    "filesScreen",
    "videoScreen",
    "videoPlayerScreen",
    "audioScreen",
    "imageScreen",
    "settingsScreen",
  ];
  let lastState = "waiting for app screen";

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);

      for (const screenName of screenNames) {
        if (hasVisibleRouteScreen(xml, screenName)) {
          return screenName;
        }
      }

      lastState = readSceneGraphFailure(xml) ?? "no app screen visible";
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected app bootstrap screen: ${lastState}`);
}

export async function authRefreshSmoke(target: string, driver: AuthDriver): Promise<void> {
  await resetAuthState(target, driver);
  await driver.waitForDevAppSceneGraphReady(target, appSceneGraphReadyTimeoutMs);

  const firstCode = await waitForAuthCode(target);
  await pressKey(target, "Select");

  const startedAt = Date.now();
  let lastCode = firstCode;

  while (Date.now() - startedAt < 30_000) {
    const nextCode = await waitForAuthCode(target, 10_000);
    lastCode = nextCode;

    if (nextCode !== firstCode) {
      console.log(`auth refresh smoke: ${firstCode} -> ${nextCode}`);
      return;
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`expected Select on auth screen to refresh code; code stayed ${lastCode}`);
}

export async function waitForAuthReady(target: string, profile: string): Promise<void> {
  await launchApp(target, "dev");
  await waitForDevAppSceneGraphReadyLocal(target, appSceneGraphReadyTimeoutMs);

  const startedAt = Date.now();
  let approvedCode: string | undefined;
  let lastState = "waiting for auth state";

  while (Date.now() - startedAt < authPrepareTimeoutMs) {
    try {
      const xml = await querySceneGraph(target);

      if (!hasVisibleRouteScreen(xml, "authScreen")) {
        console.log(`auth ready: profile=${profile}`);
        return;
      }

      const code = readAuthCode(xml);
      lastState = code === undefined ? "auth code has not loaded yet" : "auth screen waiting for approval";

      if (code !== undefined && code !== approvedCode) {
        await approveAuthCodeWithHarness(code, profile);
        approvedCode = code;
        console.log(`approved auth code for profile=${profile}`);
      }
    } catch (error) {
      lastState = formatErrorMessage(error);
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  throw new Error(`Roku dev app is still signed out after auth prepare: ${lastState}`);
}

export async function resetAuthState(target: string, driver: AuthDriver): Promise<void> {
  await launchApp(target, "dev");
  await driver.waitForDevAppSceneGraphReady(target, appSceneGraphReadyTimeoutMs);
  await waitForBootstrapScreen(target, appSceneGraphReadyTimeoutMs);

  let xml = await querySceneGraph(target);

  if (hasVisibleRouteScreen(xml, "authScreen")) {
    console.log("auth reset: already signed out");
    return;
  }

  await driver.returnToHomeScreen(target);
  xml = await querySceneGraph(target);

  if (hasVisibleRouteScreen(xml, "authScreen")) {
    console.log("auth reset: already signed out");
    return;
  }

  if (!hasVisibleRouteScreen(xml, "homeScreen")) {
    throw new Error("expected homeScreen to be visible");
  }

  await driver.dismissExitDialogIfVisible(target);
  await driver.focusLastListItem(target, "list");
  await pressKey(target, "Select");
  await sleep(3_000);
  await driver.waitForRouteScreenVisible(target, "settingsScreen", 15_000);
  await waitForNamedNodeVisible(target, "settingsList", 15_000);

  await driver.focusLastListItem(target, "settingsList");
  await pressKey(target, "Select");
  await sleep(5_000);
  await driver.waitForRouteScreenVisible(target, "authScreen", 15_000);
  console.log("auth reset: signed out");
}

export function assertNotAuthScreen(xml: string): void {
  if (!hasVisibleRouteScreen(xml, "authScreen")) {
    return;
  }

  const authCode = readAuthCode(xml);

  if (authCode !== undefined) {
    throw new Error(`Roku dev app is signed out; redeem device code ${authCode}`);
  }

  throw new Error("Roku dev app is signed out; device code has not loaded yet");
}

async function approveAuthCodeWithHarness(code: string, profile: string): Promise<void> {
  await execFile(
    process.execPath,
    ["scripts/putio-auth-harness.ts", "auth-approve-device", code, profile],
    {
      cwd: process.cwd(),
      env: {
        ...process.env,
        PUTIO_CLI_PROFILE: profile,
      },
      maxBuffer: 1024 * 1024,
    },
  );
}

async function waitForDevAppSceneGraphReadyLocal(target: string, timeoutMs: number): Promise<void> {
  const startedAt = Date.now();
  let lastState = "waiting for SceneGraph";

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const xml = await querySceneGraph(target);
      const sceneGraphFailure = readSceneGraphFailure(xml);

      if (sceneGraphFailure === undefined) {
        return;
      }

      lastState = `scene graph failed: ${sceneGraphFailure}`;
    } catch (error) {
      lastState = `scene graph unavailable: ${formatErrorMessage(error)}`;
    }

    await sleep(sceneGraphPollIntervalMs);
  }

  console.log(`continuing auth before dev app SceneGraph settled: ${lastState}`);
}
