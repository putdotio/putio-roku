#!/usr/bin/env node
import process from "node:process";

const ecpPort = 8060;
const requestTimeoutMs = 10_000;
const launchTimeoutMs = 10_000;

const remoteKeys = [
  "Home",
  "Rev",
  "Fwd",
  "Play",
  "Select",
  "Left",
  "Right",
  "Down",
  "Up",
  "Back",
  "InstantReplay",
  "Info",
  "Backspace",
  "Search",
  "Enter",
  "VolumeDown",
  "VolumeMute",
  "VolumeUp",
  "PowerOff",
  "ChannelUp",
  "ChannelDown",
  "InputTuner",
  "InputHDMI1",
  "InputHDMI2",
  "InputHDMI3",
  "InputHDMI4",
] as const;

type RemoteKey = (typeof remoteKeys)[number] | `Lit_${string}`;

type ActiveApp = {
  id: string;
  name: string;
  type: string;
  version: string;
};

function usage(): never {
  console.error(`usage:
  node scripts/roku-live-test.ts check
  node scripts/roku-live-test.ts active-app
  node scripts/roku-live-test.ts launch [app-id]
  node scripts/roku-live-test.ts launch-deeplink <content-id> [media-type]
  node scripts/roku-live-test.ts press <key> [key...]
  node scripts/roku-live-test.ts control-smoke

environment:
  ROKU_DEV_TARGET=<roku-ip>`);
  process.exit(1);
}

function requireTarget(): string {
  const rawTarget = process.env.ROKU_DEV_TARGET?.trim();

  if (!rawTarget) {
    throw new Error("ROKU_DEV_TARGET is not set");
  }

  return rawTarget
    .replace(/^https?:\/\//, "")
    .replace(/\/.*$/, "")
    .replace(/:\d+$/, "");
}

function ecpUrl(target: string, path: string): URL {
  return new URL(path, `http://${target}:${ecpPort}`);
}

function installerUrl(target: string): URL {
  return new URL("/", `http://${target}`);
}

async function fetchText(url: URL, method = "GET"): Promise<string> {
  const response = await fetch(url, {
    method,
    signal: AbortSignal.timeout(requestTimeoutMs),
  });

  if (!response.ok) {
    throw new Error(`${method} ${url.href} returned HTTP ${response.status}`);
  }

  return await response.text();
}

async function postOk(url: URL): Promise<void> {
  const response = await fetch(url, {
    method: "POST",
    signal: AbortSignal.timeout(requestTimeoutMs),
  });

  if (!response.ok) {
    throw new Error(`POST ${url.href} returned HTTP ${response.status}`);
  }
}

async function fetchInstallerStatus(target: string): Promise<number> {
  const response = await fetch(installerUrl(target), {
    signal: AbortSignal.timeout(requestTimeoutMs),
  });

  return response.status;
}

function readXmlTag(xml: string, tag: string): string | undefined {
  const pattern = new RegExp(`<${tag}>([^<]*)</${tag}>`);
  return pattern.exec(xml)?.[1]?.trim();
}

function readActiveApp(xml: string): ActiveApp {
  const match = /<app\s+([^>]*)>([^<]*)<\/app>/.exec(xml);

  if (!match) {
    throw new Error("active app response did not include an app node");
  }

  const attributes = match[1] ?? "";

  return {
    id: readXmlAttribute(attributes, "id") ?? "",
    name: match[2]?.trim() ?? "",
    type: readXmlAttribute(attributes, "type") ?? "",
    version: readXmlAttribute(attributes, "version") ?? "",
  };
}

function readXmlAttribute(attributes: string, name: string): string | undefined {
  const pattern = new RegExp(`${name}="([^"]*)"`);
  return pattern.exec(attributes)?.[1];
}

async function checkDevice(target: string): Promise<void> {
  const deviceInfo = await fetchText(ecpUrl(target, "/query/device-info"));
  const name =
    readXmlTag(deviceInfo, "friendly-device-name") ??
    readXmlTag(deviceInfo, "friendlyName") ??
    "unknown";
  const model = readXmlTag(deviceInfo, "model-name") ?? "unknown model";
  const installerStatus = await fetchInstallerStatus(target);

  console.log(`device: ${name} (${model})`);
  console.log(`ecp: http://${target}:${ecpPort}`);
  console.log(`developer installer HTTP status: ${installerStatus}`);
}

async function queryActiveApp(target: string): Promise<ActiveApp> {
  const xml = await fetchText(ecpUrl(target, "/query/active-app"));
  return readActiveApp(xml);
}

async function printActiveApp(target: string): Promise<void> {
  const app = await queryActiveApp(target);
  console.log(`active app: ${app.id} ${app.name} ${app.version}`.trim());
}

async function launchApp(target: string, appId: string): Promise<ActiveApp> {
  await postOk(ecpUrl(target, `/launch/${encodeURIComponent(appId)}`));
  return await waitForActiveApp(target, appId);
}

async function launchDeepLink(
  target: string,
  contentId: string,
  mediaType: string,
): Promise<ActiveApp> {
  const url = ecpUrl(target, "/launch/dev");
  url.searchParams.set("contentID", contentId);
  url.searchParams.set("mediaType", mediaType);

  await postOk(url);
  return await waitForActiveApp(target, "dev");
}

async function waitForActiveApp(
  target: string,
  appId: string,
): Promise<ActiveApp> {
  const start = Date.now();
  let lastApp: ActiveApp | undefined;

  while (Date.now() - start < launchTimeoutMs) {
    lastApp = await queryActiveApp(target);

    if (lastApp.id === appId) {
      return lastApp;
    }

    await sleep(500);
  }

  const last = lastApp ? `${lastApp.id} ${lastApp.name}` : "unknown";
  throw new Error(`expected active app ${appId}, got ${last}`);
}

async function pressKey(target: string, key: string): Promise<void> {
  assertRemoteKey(key);
  await postOk(ecpUrl(target, `/keypress/${encodeURIComponent(key)}`));
  console.log(`pressed: ${key}`);
}

function assertRemoteKey(key: string): asserts key is RemoteKey {
  if (key.startsWith("Lit_")) {
    return;
  }

  if (!remoteKeys.includes(key as (typeof remoteKeys)[number])) {
    throw new Error(`unsupported remote key: ${key}`);
  }
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
  const message = error instanceof Error ? error.message : String(error);
  console.error(`ERROR: ${message}`);
  process.exit(1);
});
