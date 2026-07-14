import {
  checkDevice,
  deleteInstalledChannel,
  installPackage,
  launchApp as rokitLaunchApp,
  queryEcp,
} from "@putdotio/rokit";
import { packageRoku } from "./build.ts";
import {
  appEcpId,
  appZipFile,
  envOr,
  rokuContext,
  rokuContextWithPassword,
  rokuTarget,
  run,
  selectedVariantConfig,
  sleep,
} from "./runtime.ts";

export async function checkRokuDevTarget(): Promise<void> {
  const target = rokuTarget();
  console.log(`Checking dev server at ${target}...`);

  for (let attempt = 1; attempt <= ecpWaitAttempts(); attempt += 1) {
    try {
      const summary = await checkDevice(rokuContext(4_000));
      console.log(`Device reports as "${summary.name}".`);
      console.log("Dev server is ready.");
      return;
    } catch {
      if (attempt === ecpWaitAttempts()) {
        throw new Error(`Roku ECP did not become ready after ${attempt} attempt(s).`);
      }
    }

    console.log(`Roku ECP is not ready yet; retrying (${attempt}/${ecpWaitAttempts()})...`);
    await sleep(5_000);
  }
}

export async function activeApp(): Promise<void> {
  await checkRokuDevTarget();
  console.log(await queryEcp(rokuContext(4_000), "/query/active-app"));
}

export async function deviceInfo(): Promise<void> {
  await checkRokuDevTarget();
  console.log(await queryEcp(rokuContext(4_000), "/query/device-info"));
}

export async function install(): Promise<void> {
  const config = selectedVariantConfig();
  await packageRoku(config);
  await checkRokuDevTarget();
  console.log(`Installing ${process.env.ROKU_APP_TITLE ?? config.title} (${config.variant})...`);

  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      const message = await installPackage(rokuContextWithPassword(), appZipFile(config));
      console.log(`Result: ${message}`);
      return;
    } catch (error) {
      if (attempt === 2) {
        throw error;
      }
    }

    console.log("Install attempt failed; retrying...");
    await sleep(2_000);
  }
}

export async function remove(): Promise<void> {
  await checkRokuDevTarget();
  console.log("Removing dev app...");
  const message = await deleteInstalledChannel(rokuContextWithPassword());
  console.log(`Result: ${message}`);
}

export async function reinstall(): Promise<void> {
  await remove();
  await install();
}

export async function launch(): Promise<void> {
  await checkRokuDevTarget();
  const target = rokuTarget();
  const appId = appEcpId();
  console.log(`Launching app ${appId} on ${target}...`);
  const app = await rokitLaunchApp(rokuContext(10_000), appId);
  console.log(`${app.id} ${app.name}`);
}

export async function attachConsole(): Promise<void> {
  await checkRokuDevTarget();
  console.log(`Attaching to BrightScript console at ${rokuTarget()}:${envOr("ROKU_DEV_CONSOLE_PORT", "8085")}. Press Ctrl-C to detach.`);
  run("nc", [rokuTarget(), envOr("ROKU_DEV_CONSOLE_PORT", "8085")]);
}

function ecpWaitAttempts(): number {
  const raw = envOr("ROKU_ECP_WAIT_ATTEMPTS", "24");
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1) {
    throw new Error(`ROKU_ECP_WAIT_ATTEMPTS must be a positive integer, got ${raw}`);
  }

  return value;
}
