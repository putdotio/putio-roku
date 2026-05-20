# Live Test

Hardware-backed checks for the put.io Roku app. Use these when a change needs
proof from a real Roku device instead of only a ZIP build.

## Setup

Copy the sample environment file and fill in the local device values:

```bash
cp .env.example .env
```

Required for read-only device checks:

```bash
ROKU_DEV_TARGET=<roku-ip>
# or ROKIT_TARGET=<roku-ip>
```

Required for sideload install checks:

```bash
ROKU_DEV_PASSWORD=<developer-mode-password>
# or ROKIT_PASSWORD=<developer-mode-password>
```

Optional for player UI screenshot review pages:

```bash
PLAYER_UI_REFERENCE_IMAGE=<path-to-reference-image>
```

Optional for authenticated harness setup:

```bash
PUTIO_CLI_PROFILE=devs-fe-auto
PUTIO_CLI_CONFIG_PATH=.putio-cli/devs-fe-auto.json
PUTIO_HARNESS_ACCOUNT_ITEM=putio-test-account
```

Keep `.env` local. Device IPs, Developer Mode passwords, signing keys, and
download tokens do not belong in git. `.putio-cli/` is ignored and may contain
local put.io CLI auth state for the testing account.

Install the repo toolchain before running smoke or install checks:

```bash
pnpm install --frozen-lockfile
```

The Make targets load `.env` automatically. If you call `pnpm roku:live`
directly, export `ROKU_DEV_TARGET` or `ROKIT_TARGET` in the shell first. The
scenario script uses `@putdotio/rokit` for generic Roku device control and keeps
put.io-specific playback assertions in this repo.

## Commands

```bash
make smoke
make live-test
make live-test-control
make live-test-press KEYS="Back Info"
make live-test-deeplink CONTENT_ID=<file-id>
make live-test-playback CONTENT_ID=<file-id>
make live-test-playback-remote CONTENT_ID=<file-id>
make live-test-playback-type TYPE=<hls|mp4>
make live-test-playback-type-smoke TYPE=<hls|mp4> CONTENT_ID=<file-id>
make live-test-playback-error-dialog CONTENT_ID=<bad-file-id>
make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>
make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>
make live-test-flow-smoke
make live-test-flow FLOWS=auth,files,dialogs
make live-test-flow-full PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>
make test-live
make lab-install STORY=<story-id>
make lab-screenshot STORY=<story-id>
make visual-capture NAME=<short-screen-name>
make visual-capture-pages
make visual-capture-lab
make visual-validate
make visual-gallery
make live-test-launch
make live-test-install
make putio-auth-status
make putio-auth-prepare
make live-test-auth-reset
make live-test-auth-refresh
make live-test-auth-prepare
make console
```

- `make smoke` type-checks the live-test harness, checks Roku source
  formatting, runs BrighterScript/`bslint`, and builds a fresh sideload ZIP.
- `make live-test` proves the configured Roku responds to ECP, exposes the
  developer installer, and returns active-app/device metadata.
- `make live-test-control` launches the sideloaded developer app, sends remote
  keypresses over ECP, and asserts the developer app remains active.
- `make live-test-press KEYS="Back Info"` sends explicit remote keypresses over
  ECP. Use this for manual-but-headless navigation while watching console logs.
- `make live-test-deeplink CONTENT_ID=<file-id> [MEDIA_TYPE=movie]` launches the
  developer app through Roku deep linking. The app treats `contentID` as a
  put.io video file id and opens the video details screen after authentication.
- `make live-test-playback CONTENT_ID=<file-id> [MEDIA_TYPE=movie] [START_FROM=continue]`
  launches through Roku deep linking, accepts the start-from prompt when it
  appears, and waits until `videoPlayerScreen` is visible.
- `make live-test-playback-remote CONTENT_ID=<file-id> [MEDIA_TYPE=movie] [START_FROM=continue]`
  launches through Roku deep linking, drives the start-from prompt with remote
  keypresses, waits briefly for the dev app SceneGraph when available, and then
  confirms `videoPlayerScreen` is visible. Use it when repeated relaunches make
  the device unstable during HLS startup.
- `make live-test-playback-type TYPE=<hls|mp4>` updates the `playbackType`
  config value for the prepared `PUTIO_CLI_PROFILE`. This is useful for direct
  API config checks, but the live playback smoke uses the Roku Settings UI so
  it exercises the app token and the real persisted app preference.
- `make live-test-playback-type-smoke TYPE=<hls|mp4> CONTENT_ID=<file-id> [MEDIA_TYPE=movie] [START_FROM=continue]`
  opens Settings on the Roku app, sets the playback preference, opens the
  requested file, asserts the requested file id in the player SceneGraph, and
  checks the Roku media-player container matches the selected type.
- `make live-test-playback-error-dialog CONTENT_ID=<bad-file-id> [MEDIA_TYPE=movie] [EXPECTED_TITLE=Oops] [EXPECTED_MESSAGE="File not found"]`
  opens a negative playback route and asserts the error dialog stays visible
  with readable title/message text before dismissing it.
- `make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> [MEDIA_TYPE=movie] [START_FROM=continue]`
  opens playback through deep links, asserts direct player routing instead of
  the old play/subtitle preselection surface, opens the audio and subtitle
  pickers from the custom player controls, asserts the underlying `Video` node
  audio/caption fields when Roku exposes those tracks, asserts the tuned
  OSD/menu geometry, asserts the scrubber can receive focus, and checks Roku
  media seek keys move playback.
  It uses SceneGraph state because Roku developer screenshots capture the app UI
  plane but not always the video plane.
- `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> [MEDIA_TYPE=movie] [START_FROM=continue] [OUTPUT_DIR=<dir>]`
  drives the same playback path and saves screenshots under a timestamped
  `dist/tmp/player-ui/<run>/` directory unless `OUTPUT_DIR` is set:
  `play-focus.jpg`,
  `subtitle-button-focus.jpg`, `subtitle-menu.jpg`, `progress-focus.jpg`, and
  optional `audio-button-focus.jpg`, `audio-menu.jpg`,
  `speed-button-focus.jpg`, `speed-menu.jpg`, plus `review.html` for visual
  review. The review page includes the content IDs, proof commands, and the
  exported tv-native Android reference captures when the peer workspace repo is
  available. Set `PLAYER_UI_REFERENCE_IMAGE` to copy an extra reference image
  into the review page. It requires `ROKU_DEV_PASSWORD` because
  screenshots come from the Roku developer inspector.
- `make live-test-flow-smoke [OUTPUT_DIR=<dir>]` runs the app-level e2e smoke
  suite against a signed-in device: auth readiness, Files navigation, delete
  dialog open/dismiss, Settings navigation, Get new code, and auth restoration.
  It writes flow run output under a timestamped `dist/tmp/flows/app-smoke-*`
  directory unless `OUTPUT_DIR` is set.
- `make live-test-flow FLOWS=auth,files,dialogs [PLAYBACK_CONTENT_ID=<file-id>] [IMAGE_CONTENT_ID=<file-id>] [AUDIO_CONTENT_ID=<file-id>] [SUBTITLE_CONTENT_ID=<file-id>] [MEDIA_TYPE=movie] [START_FROM=continue] [OUTPUT_DIR=<dir>]`
  runs a custom comma-separated flow list. Available flows are `auth`,
  `get-new-code`, `files`, `history`, `dialogs`, `settings`, `logout`,
  `playback`, `image`, and `tracks`.
- `make live-test-flow-full PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> [MEDIA_TYPE=movie] [START_FROM=continue] [OUTPUT_DIR=<dir>]`
  runs the broader regression sweep: app smoke flows plus HLS playback, image
  rendering, track selection/player controls, logout, and auth restoration.
- `make test-live` runs the Vitest contract tests around the TypeScript
  harness. These catch flow-suite drift, fixture argument parsing regressions,
  and Lab story/capture registry mismatches without touching the Roku.
- The app-specific command entrypoint is `scripts/roku-live-test.ts`; shared
  flow definitions, CLI option parsing, put.io config helpers, artifact paths,
  auth/session handling, rokit device wrappers, navigation/focus helpers,
  playback launch assertions, SceneGraph parsing/assertions, visual capture
  drivers, usage text, and player UI review artifact generation live under
  `scripts/live-test/`.
- `make lab-install [STORY=app-dialog-empty]` installs this checkout and opens
  the Lab scene on a specific story. Available stories are
  `app-dialog-empty`, `app-dialog-message`, `delete-dialog-short`,
  `delete-dialog-long`, `continue-watching`, `continue-watching-beginning`,
  `track-menu-audio`, `track-menu-subtitles`,
  `track-menu-subtitles-scroll`, `track-menu-speed`,
  `conversion-status-converting`, `conversion-status-error`,
  `list-item-generic`, `list-item-files`, `list-item-file-watched-focused`,
  `list-item-file-loading-focused`, and `list-item-history`.
- `make lab-screenshot [STORY=app-dialog-empty] [LAB_SCREENSHOT_DELAY=3]`
  launches the same Lab story and writes
  a timestamped screenshot such as
  `dist/tmp/lab/<story>-YYYYMMDD-HHMMSS.jpg`. The delay gives Roku's
  developer screenshot endpoint time to capture the first rendered app frame.
- `make visual-capture NAME=<short-screen-name>` captures the current Roku app
  state into `dist/tmp/visual/captures/<timestamp>/<short-screen-name>.jpg`.
- `make visual-capture-pages [OUTPUT_DIR=<dir>] [INCLUDE_AUTH=1]` drives the
  main Roku pages and saves raw screenshots under `dist/tmp/visual/pages/`.
  `INCLUDE_AUTH=1` signs out, captures Auth, then restores the testing account;
  do not commit Auth captures unless the activation code is redacted or
  otherwise public-safe.
- `make visual-capture-lab [OUTPUT_DIR=<dir>] [STORIES="story-id ..."] [ALL=1]`
  drives Lab stories and saves raw screenshots under `dist/tmp/visual/lab/`.
  Without `STORIES` or `ALL=1`, it captures the stable shared AppDialog
  stories. Use `ALL=1` deliberately because broad Lab sweeps are heavier than
  targeted story captures.
- `make visual-validate` validates `.vref/manifest.json` and committed
  screenshot assets without rewriting the gallery.
- `make visual-gallery` rebuilds the static visual reference gallery from
  `.vref/manifest.json` with `@putdotio/vref`.
- `make live-test-launch` opens the installed developer app and prints the
  active app state.
- `make live-test-install` removes the existing developer app, installs this
  checkout, launches it, and prints the active app state. It requires
  `ROKU_DEV_PASSWORD`.
- `make putio-auth-status [PUTIO_CLI_PROFILE=devs-fe-auto]` checks the local
  put.io CLI auth state without exposing token material.
- `make putio-auth-prepare [PUTIO_CLI_PROFILE=devs-fe-auto]` materializes local
  testing-account auth into the ignored `PUTIO_CLI_CONFIG_PATH` through the
  approved 1Password-backed `devs-fe-auto` setup.
- `make live-test-auth-reset` launches the Roku developer app, drives Settings >
  Log out through remote keypresses, and waits for the auth screen.
- `make live-test-auth-refresh` signs the app out when needed, waits for the
  auth screen device code, presses Select on Get new code, and asserts a new
  code is rendered.
- `make live-test-auth-prepare [PUTIO_CLI_PROFILE=devs-fe-auto]` launches the
  Roku developer app, reads the visible device code from SceneGraph when the app
  is signed out, approves it with the prepared testing account, and waits until
  the app reaches an authenticated state.
- `make console` attaches to the BrightScript debug console on port `8085`.

For a one-off install without saving the password in `.env`, pass it as a Make
variable:

```bash
make ROKU_DEV_PASSWORD=<developer-mode-password> live-test-install
```

## Debug Loop

1. Run `make smoke` before touching the device.
2. Run `make live-test` to confirm the configured target is the expected Roku.
3. Run `make live-test-control` to prove the agent can launch and control the
   app without the physical remote.
4. Run `make live-test-playback CONTENT_ID=<file-id>` for playback bugs tied to
   a known put.io video file.
5. Run `make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
   for custom player UI changes that affect track menus, scrubber focus, or
   media-key seek behavior.
6. Run `make live-test-flow-smoke` after navigation/auth/dialog/router changes
   to cover the regular app shell flows before touching playback-heavy checks.
7. Run `make live-test-flow-full PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
   before shipping broad refactors that could affect auth, routing, files,
   dialogs, settings, logout, playback, image rendering, or track selection.
8. Run `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
   when a visual player UI change needs repeatable screenshot artifacts.
9. Run `make lab-install STORY=<story-id>` or
   `make lab-screenshot STORY=<story-id>` for modal/component visual changes
   that can be isolated from authenticated app state.
10. Run `make live-test-install` after code changes that must be reproduced on
   hardware.
11. In another terminal, run `make console` before launching playback flows so
   BrightScript compile/runtime/player logs are visible.

If `make live-test` passes but install fails with repeated HTTP `401`, the
device is reachable but Developer Mode auth failed. Check `ROKU_DEV_PASSWORD`
first; if authenticated GETs work and only uploads fail, retry `make install`
because some Roku developer endpoints intermittently close multipart uploads.

## Readiness Grade

- Bootable: partial. The app can be packaged locally and launched on a
  configured developer-enabled Roku.
- Testable: partial. `make smoke` and CI prove live-test type safety, Roku
  formatting, static checks, and packaging; hardware behavior still needs a
  real device.
- Observable: partial. ECP state and the BrightScript console are available
  through Make targets.
- Verifiable: partial. `make verify` is deterministic locally/CI; real
  playback/subtitle proof is hardware-backed through this runbook, with
  headless launch, remote-control coverage through `make live-test-control`,
  and custom player UI behavior plus geometry assertions through
  `make live-test-player-ui`.
