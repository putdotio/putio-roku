import process from "node:process";
import {
  assertMediaPlayerContainer as rokitAssertMediaPlayerContainer,
  captureScreenshot as rokitCaptureScreenshot,
  checkDevice as rokitCheckDevice,
  isActiveMediaPlayerState,
  launchApp as rokitLaunchApp,
  pressKey as rokitPressKey,
  queryActiveApp as rokitQueryActiveApp,
  queryMediaPlayerXml as rokitQueryMediaPlayerXml,
  queryMediaPlayerXmlSafe as rokitQueryMediaPlayerXmlSafe,
  querySceneGraph as rokitQuerySceneGraph,
  readMediaPlayerPositionMs as rokitReadMediaPlayerPositionMs,
  readMediaPlayerState as rokitReadMediaPlayerState,
  readSceneGraphFailure,
  validateRemoteKey,
  waitForActiveApp as rokitWaitForActiveApp,
  waitForMediaPlayerState as rokitWaitForMediaPlayerState,
  waitForSceneGraphAssertion as rokitWaitForSceneGraphAssertion,
  waitForSceneGraphNode as rokitWaitForSceneGraphNode,
  type ActiveApp,
  type RokuContext,
} from "@putdotio/rokit";
import {
  appSceneGraphReadyTimeoutMs,
  launchTimeoutMs,
  requestTimeoutMs,
  sceneGraphPollIntervalMs,
  sceneGraphRequestTimeoutMs,
  screenshotCaptureAttempts,
} from "./constants.ts";
import { formatErrorMessage } from "./errors.ts";
import { sleep } from "./timing.ts";

export type { ActiveApp, RokuContext };
export { isActiveMediaPlayerState };

export function requireTarget(): string {
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

export function configuredAppId(): string {
  const appId = process.env.ROKU_APP_ECP_ID?.trim();
  return appId !== undefined && appId !== "" ? appId : "dev";
}

export function rokitContext(target: string, timeoutMs = requestTimeoutMs): RokuContext {
  return {
    target,
    timeoutMs,
    username: "rokudev",
  };
}

export function requireDeveloperPassword(): string {
  const password = process.env.ROKIT_PASSWORD ?? process.env.ROKU_DEV_PASSWORD;

  if (!password) {
    throw new Error("ROKU_DEV_PASSWORD or ROKIT_PASSWORD is not set");
  }

  return password;
}

export async function waitForNamedNodeVisible(
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

export async function checkDevice(target: string): Promise<void> {
  const summary = await rokitCheckDevice(rokitContext(target));

  console.log(`device: ${summary.name} (${summary.model})`);
  console.log(`ecp: ${summary.ecp}`);
  console.log(`developer installer HTTP status: ${summary.installerStatus}`);
}

export async function controlSmoke(target: string): Promise<void> {
  await checkDevice(target);
  const appId = configuredAppId();
  const launchedApp = await launchApp(target, appId);
  console.log(
    `launched: ${launchedApp.id} ${launchedApp.name} ${launchedApp.version}`,
  );

  await pressKey(target, "Info");
  await sleep(300);
  await pressKey(target, "Back");

  const activeApp = await waitForActiveApp(target, appId);
  console.log(`asserted active app ${appId}: ${activeApp.name} ${activeApp.version}`);
}

export async function queryActiveApp(target: string): Promise<ActiveApp> {
  return await rokitQueryActiveApp(rokitContext(target));
}

export async function printActiveApp(target: string): Promise<void> {
  const app = await queryActiveApp(target);
  console.log(`active app: ${app.id} ${app.name} ${app.version}`.trim());
}

export async function launchApp(target: string, appId: string): Promise<ActiveApp> {
  return await rokitLaunchApp(rokitContext(target), appId);
}

export async function launchDeepLink(
  target: string,
  contentId: string,
  mediaType: string,
  startFromChoice?: "continue" | "beginning",
): Promise<ActiveApp> {
  const params = createPlaybackParams(contentId, mediaType, startFromChoice);
  const appId = configuredAppId();

  try {
    return await rokitLaunchApp(rokitContext(target), appId, params);
  } catch {
    await launchApp(target, appId);
    await sleep(1_000);
    return await rokitLaunchApp(rokitContext(target), appId, params);
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

export async function querySceneGraph(target: string): Promise<string> {
  return await rokitQuerySceneGraph(rokitContext(target, sceneGraphRequestTimeoutMs), {
    attempts: 8,
    requireAppNode: true,
    requireComplete: true,
    retryDelayMs: 500,
  });
}

export async function queryMediaPlayerState(target: string): Promise<string | undefined> {
  return rokitReadMediaPlayerState(await rokitQueryMediaPlayerXml(rokitContext(target)));
}

export async function queryMediaPlayerStateSafe(target: string): Promise<string | undefined> {
  try {
    return await queryMediaPlayerState(target);
  } catch {
    return undefined;
  }
}

export async function queryMediaPlayerXmlSafe(target: string): Promise<string | undefined> {
  return await rokitQueryMediaPlayerXmlSafe(rokitContext(target));
}

export function readMediaPlayerPositionMs(xml: string | undefined): number | undefined {
  return xml === undefined ? undefined : rokitReadMediaPlayerPositionMs(xml);
}

export async function assertMediaPlayerContainer(
  target: string,
  expectedContainer: "hls" | "mp4",
): Promise<void> {
  let lastError: string | undefined;

  for (let attempt = 0; attempt < 15; attempt += 1) {
    try {
      await rokitAssertMediaPlayerContainer(rokitContext(target), expectedContainer);
      return;
    } catch (error) {
      lastError = formatErrorMessage(error);
      await sleep(1_000);
    }
  }

  throw new Error(lastError ?? `expected media-player container ${expectedContainer}`);
}

export async function queryActiveAppSafe(target: string): Promise<ActiveApp | undefined> {
  try {
    return await queryActiveApp(target);
  } catch {
    return undefined;
  }
}

export async function waitForDevAppSceneGraphReady(
  target: string,
  timeoutMs = appSceneGraphReadyTimeoutMs,
): Promise<void> {
  const start = Date.now();
  const appId = configuredAppId();
  let lastState = `waiting for app ${appId} SceneGraph`;

  while (Date.now() - start < timeoutMs) {
    const activeApp = await queryActiveAppSafe(target);
    if (activeApp?.id !== appId) {
      lastState = `active-app=${activeApp?.id ?? "unknown"}`;
      await sleep(sceneGraphPollIntervalMs);
      continue;
    }

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

  throw new Error(`dev app SceneGraph did not settle within ${timeoutMs}ms: ${lastState}`);
}

export async function waitForMediaPlayerState(
  target: string,
  expectedState: string,
  timeoutMs = 4_000,
): Promise<boolean> {
  try {
    await rokitWaitForMediaPlayerState(rokitContext(target), expectedState, timeoutMs);
    return true;
  } catch {
    return false;
  }
}

export async function waitForActiveApp(
  target: string,
  appId: string,
): Promise<ActiveApp> {
  return await rokitWaitForActiveApp(rokitContext(target), appId, launchTimeoutMs);
}

export async function pressKey(target: string, key: string): Promise<void> {
  validateRemoteKey(key);
  await rokitPressKey(rokitContext(target), key);
  console.log(`pressed: ${key}`);
}

export async function typeText(target: string, text: string): Promise<void> {
  for (const char of text) {
    await pressKey(target, `Lit_${encodeURIComponent(char)}`);
    await sleep(250);
  }
}

export async function waitForSceneGraphAssertion(
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

export async function captureDeveloperScreenshot(
  target: string,
  password: string,
  outputPath: string,
): Promise<string> {
  return await rokitCaptureScreenshot({ ...rokitContext(target), password }, outputPath, {
    attempts: screenshotCaptureAttempts,
    tempDirPrefix: "putio-roku-screenshot",
  });
}
