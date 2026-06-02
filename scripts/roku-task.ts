import {
  artifact,
  checkRokuAssets,
  checkRokuDesign,
  checkRokuFormat,
  checkRokuLive,
  checkRokuStatic,
  clean,
  packageRoku,
  testLive,
  verify,
  visualGallery,
  visualValidate,
} from "./roku-task/build.ts";
import {
  activeApp,
  attachConsole,
  checkRokuDevTarget,
  deviceInfo,
  install,
  launch,
  reinstall,
  remove,
} from "./roku-task/device.ts";
import {
  debugSnapshot,
  labInstall,
  labLaunch,
  labScreenshot,
  liveTest,
  liveTestAuthPrepare,
  liveTestAuthRefresh,
  liveTestAuthReset,
  liveTestControl,
  liveTestDeepLink,
  liveTestFlow,
  liveTestFlowFull,
  liveTestFlowSmoke,
  liveTestInstall,
  liveTestPlayback,
  liveTestPlaybackErrorDialog,
  liveTestPlaybackRemote,
  liveTestPlaybackType,
  liveTestPlaybackTypeSmoke,
  liveTestPlayerUi,
  liveTestPlayerUiScreenshots,
  liveTestPress,
  putioAuthApproveDevice,
  putioAuthPrepare,
  putioAuthStatus,
  visualCapture,
  visualCaptureLab,
  visualCapturePages,
} from "./roku-task/live.ts";
import {
  loadEnvFiles,
  selectedVariantConfig,
  variantConfig,
} from "./roku-task/runtime.ts";
import {
  secretsClean,
  secretsSetup,
} from "./roku-task/secrets.ts";

type Task = () => Promise<void> | void;

loadEnvFiles([".env", ".env.local"]);

const tasks: Record<string, Task> = {
  "active-app": activeApp,
  artifact,
  build: () => packageRoku(selectedVariantConfig()),
  "build-dev": () => packageRoku(variantConfig("development")),
  "build-lab": () => packageRoku(variantConfig("lab")),
  "check-roku-assets": checkRokuAssets,
  "check-roku-design": checkRokuDesign,
  "check-roku-dev-target": checkRokuDevTarget,
  "check-roku-format": checkRokuFormat,
  "check-roku-live": checkRokuLive,
  "check-roku-static": checkRokuStatic,
  clean,
  console: attachConsole,
  "debug-snapshot": debugSnapshot,
  "device-info": deviceInfo,
  install,
  "lab-install": labInstall,
  "lab-launch": labLaunch,
  "lab-screenshot": labScreenshot,
  launch,
  "live-test": liveTest,
  "live-test-auth-prepare": liveTestAuthPrepare,
  "live-test-auth-refresh": liveTestAuthRefresh,
  "live-test-auth-reset": liveTestAuthReset,
  "live-test-control": liveTestControl,
  "live-test-deeplink": liveTestDeepLink,
  "live-test-flow": liveTestFlow,
  "live-test-flow-full": liveTestFlowFull,
  "live-test-flow-smoke": liveTestFlowSmoke,
  "live-test-install": liveTestInstall,
  "live-test-playback": liveTestPlayback,
  "live-test-playback-error-dialog": liveTestPlaybackErrorDialog,
  "live-test-playback-remote": liveTestPlaybackRemote,
  "live-test-playback-type": liveTestPlaybackType,
  "live-test-playback-type-smoke": liveTestPlaybackTypeSmoke,
  "live-test-player-ui": liveTestPlayerUi,
  "live-test-player-ui-screenshots": liveTestPlayerUiScreenshots,
  "live-test-press": liveTestPress,
  "putio-auth-approve-device": putioAuthApproveDevice,
  "putio-auth-prepare": putioAuthPrepare,
  "putio-auth-status": putioAuthStatus,
  remove,
  run: reinstall,
  "secrets-clean": secretsClean,
  "secrets-setup": secretsSetup,
  smoke: verify,
  "test-live": testLive,
  verify,
  "visual-capture": visualCapture,
  "visual-capture-lab": visualCaptureLab,
  "visual-capture-pages": visualCapturePages,
  "visual-gallery": visualGallery,
  "visual-validate": visualValidate,
};

async function main(): Promise<void> {
  const taskName = process.argv[2];
  if (taskName === undefined || taskName === "" || taskName === "help" || taskName === "--help") {
    printHelp();
    return;
  }

  const task = tasks[taskName];
  if (task === undefined) {
    throw new Error(`Unknown Roku task "${taskName}". Run pnpm roku help.`);
  }

  await task();
}

function printHelp(): void {
  console.log(`Usage: pnpm roku <task>

Common:
  verify smoke test-live build build-dev build-lab artifact run clean

Device:
  check-roku-dev-target install launch remove console active-app device-info

Live:
  live-test live-test-control live-test-playback live-test-player-ui
  live-test-flow-smoke live-test-flow live-test-flow-full debug-snapshot

Lab and visuals:
  lab-install lab-screenshot visual-capture visual-capture-pages
  visual-capture-lab visual-validate visual-gallery

Auth:
  secrets-setup secrets-clean putio-auth-status putio-auth-prepare
  putio-auth-approve-device live-test-auth-prepare live-test-auth-reset
  live-test-auth-refresh

Run pnpm roku help --all for every task.`);

  if (!process.argv.includes("--all")) {
    return;
  }

  console.log("\nAll tasks:");
  for (const taskName of Object.keys(tasks).sort()) {
    console.log(`  ${taskName}`);
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
