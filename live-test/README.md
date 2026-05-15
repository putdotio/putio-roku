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

Keep `.env` local. Device IPs, Developer Mode passwords, signing keys, and
download tokens do not belong in git.

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
make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>
make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>
make live-test-launch
make live-test-install
make console
```

- `make smoke` runs BrighterScript/`bslint` and builds a fresh sideload ZIP.
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
  keypresses, avoids startup SceneGraph polling, and then confirms
  `videoPlayerScreen` is visible. Use it when repeated SceneGraph polling makes
  the device unstable during HLS startup.
- `make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> [MEDIA_TYPE=movie] [START_FROM=continue]`
  opens playback through deep links, asserts direct HLS playback instead of the
  old play/subtitle preselection surface, opens the audio and subtitle pickers
  from the custom player controls, asserts the tuned OSD/menu geometry, asserts
  the scrubber can receive focus, and checks Roku media seek keys move playback.
  It uses SceneGraph state because Roku developer screenshots capture the app UI
  plane but not always the video plane.
- `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> [MEDIA_TYPE=movie] [START_FROM=continue] [OUTPUT_DIR=dist/tmp/player-ui]`
  drives the same playback path and saves `play-focus.jpg`,
  `audio-button-focus.jpg`, `audio-menu.jpg`, `subtitle-button-focus.jpg`,
  `subtitle-menu.jpg`, `speed-button-focus.jpg`, `speed-menu.jpg`,
  `progress-focus.jpg`, and `review.html` for visual
  review. The review page includes the content IDs, proof commands, and the
  exported tv-native Android reference captures when the peer handbook repo is
  available. Set `PLAYER_UI_REFERENCE_IMAGE` to copy an extra reference image
  into the review page. It requires `ROKU_DEV_PASSWORD` because
  screenshots come from the Roku developer inspector.
- `make live-test-launch` opens the installed developer app and prints the
  active app state.
- `make live-test-install` removes the existing developer app, installs this
  checkout, launches it, and prints the active app state. It requires
  `ROKU_DEV_PASSWORD`.
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
6. Run `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
   when a visual player UI change needs repeatable screenshot artifacts.
7. Run `make live-test-install` after code changes that must be reproduced on
   hardware.
8. In another terminal, run `make console` before launching playback flows so
   BrightScript compile/runtime/player logs are visible.

If `make live-test` passes but install fails with repeated HTTP `401`, the
device is reachable but Developer Mode auth failed. Check `ROKU_DEV_PASSWORD`
first; if authenticated GETs work and only uploads fail, retry `make install`
because some Roku developer endpoints intermittently close multipart uploads.

## Readiness Grade

- Bootable: partial. The app can be packaged locally and launched on a
  configured developer-enabled Roku.
- Testable: partial. `make smoke` and CI prove static checks plus packaging;
  hardware behavior still needs a real device.
- Observable: partial. ECP state and the BrightScript console are available
  through Make targets.
- Verifiable: partial. `make verify` is deterministic locally/CI; real
  playback/subtitle proof is hardware-backed through this runbook, with
  headless launch, remote-control coverage through `make live-test-control`,
  and custom player UI behavior plus geometry assertions through
  `make live-test-player-ui`.
