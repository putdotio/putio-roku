import process from "node:process";

export function usage(): never {
  console.error(`usage:
  node scripts/roku-live-test.ts check
  node scripts/roku-live-test.ts active-app
  node scripts/roku-live-test.ts auth-reset
  node scripts/roku-live-test.ts auth-refresh-smoke
  node scripts/roku-live-test.ts auth-prepare [profile]
  node scripts/roku-live-test.ts flow-smoke [artifact-dir]
  node scripts/roku-live-test.ts flow-full <playback-content-id> <audio-content-id> <subtitle-content-id> [media-type] [continue|beginning] [artifact-dir]
  node scripts/roku-live-test.ts flow <auth,get-new-code,files,dialogs,settings,logout,playback,tracks> [playback-content-id] [audio-content-id] [subtitle-content-id] [media-type] [continue|beginning] [artifact-dir]
  node scripts/roku-live-test.ts visual-pages [artifact-dir] [--include-auth]
  node scripts/roku-live-test.ts visual-lab [artifact-dir] [story-id...]
  node scripts/roku-live-test.ts set-playback-type <hls|mp4> [profile]
  node scripts/roku-live-test.ts playback-type-smoke <hls|mp4> <content-id> [media-type] [continue|beginning]
  node scripts/roku-live-test.ts playback-error-dialog-smoke <content-id> [media-type] [expected-title] [expected-message-fragment]
  node scripts/roku-live-test.ts launch [app-id]
  node scripts/roku-live-test.ts launch-deeplink <content-id> [media-type]
  node scripts/roku-live-test.ts launch-playback <content-id> [media-type] [continue|beginning]
  node scripts/roku-live-test.ts launch-playback-remote <content-id> [media-type] [continue|beginning]
  node scripts/roku-live-test.ts player-ui-smoke <audio-content-id> <subtitle-content-id> [media-type] [continue|beginning]
  node scripts/roku-live-test.ts player-ui-screenshots <audio-content-id> <subtitle-content-id> [media-type] [continue|beginning] [output-dir]
  node scripts/roku-live-test.ts press <key> [key...]
  node scripts/roku-live-test.ts control-smoke

environment:
  ROKU_DEV_TARGET=<roku-ip> or ROKIT_TARGET=<roku-ip>
  ROKU_DEV_PASSWORD=<developer-mode-password> or ROKIT_PASSWORD=<developer-mode-password>
  PUTIO_CLI_PROFILE=devs-fe-auto
  PUTIO_CLI_CONFIG_PATH=.putio-cli/devs-fe-auto.json
  PLAYER_UI_REFERENCE_IMAGE=<optional-reference-image-path>`);
  process.exit(1);
}
