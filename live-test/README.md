# Live Test

Device checks for the put.io Roku app, for changes that need proof from a real
Roku instead of a ZIP build. Every install replaces the Roku's one sideloaded
app; read [Ways To Hurt Yourself](../AGENTS.md#ways-to-hurt-yourself) first.

## Setup

```bash
pnpm install --frozen-lockfile
```

Maintainers with the shared encrypted test payload render the test account,
harness credentials, Developer Mode password, and fixture file ids:

```bash
PUTIO_ROKU_SOPS_FILE=/path/to/roku.sops.env pnpm roku secrets-setup
```

It writes an ignored mode-`0600` `.env.local`; SOPS must find your authorized
age identity. With your own device or credentials, start from the sample:

```bash
cp .env.example .env
```

`pnpm roku` loads `.env` and then `.env.local`, which wins. `secrets-setup`
replaces `.env.local`, so keep the Roku target in `.env`. If you call
`node scripts/roku-live-test.ts` directly, export `ROKU_DEV_TARGET` or
`ROKIT_TARGET` first.

- Device checks need `ROKU_DEV_TARGET` (or `ROKIT_TARGET`); installs also need `ROKU_DEV_PASSWORD` (or `ROKIT_PASSWORD`)
- `ROKU_APP_ECP_ID` defaults to `dev`, which every sideloaded variant uses; set it only to drive a public or beta Roku app
- Harness auth uses the `PUTIO_*` values in [.env.example](../.env.example). Without `PUTIO_CLI_PROFILE`, scripts use `.putio-cli/default.json`
- `PLAYER_UI_TV_NATIVE_REFERENCE_DIR` optionally points at Android TV WebP captures named in [player-ui-review.ts](../scripts/live-test/player-ui-review.ts); missing captures are skipped

Keep `.env`, `.env.local`, and `.putio-cli/` local.

## Tasks

`pnpm roku help` lists the tasks; [scripts/roku-task/live.ts](../scripts/roku-task/live.ts)
shows what each reads. A task missing a required variable fails with an
example command, and `FLOWS` rejects unknown flow ids with the valid list.
Flow runs write to `dist/tmp/flows/`, player UI captures to
`dist/tmp/player-ui/`, and failure snapshots to `.local/roku-debug/`;
`OUTPUT_DIR` overrides the first two.

Story ids live in [visual-capture.ts](../scripts/live-test/visual-capture.ts).
`lab-screenshot` defaults to `app-dialog-empty`, and `visual-capture-lab`
captures the stable AppDialog stories unless you pass `STORIES="id ..."` or
`ALL=1`.

### Files fixture

The `files` flow, which the smoke and full suites include, needs a root-level
folder named `FILES_FOLDER_NAME` at zero-based row `FILES_FOLDER_INDEX` in the
test account. Its name must differ from the root title. The harness never
creates or changes it, and a missing fixture fails the run:

```bash
FILES_FOLDER_NAME="Navigation fixture" FILES_FOLDER_INDEX=2 FLOWS=files pnpm roku live-test-flow
```

## Debug Loop

Start with `pnpm verify`, then pick the smallest device proof for the change:

- `pnpm roku live-test` for a read-only check that the Roku answers ECP and exposes the installer
- `pnpm roku live-test-control` for launch and remote-control changes
- `CONTENT_ID=<file-id> pnpm roku live-test-playback` for playback routing
- `AUDIO_CONTENT_ID=<id> SUBTITLE_CONTENT_ID=<id> pnpm roku live-test-player-ui` for player controls and track menus. It asserts on SceneGraph state, because Roku screenshots do not always capture the video plane
- `pnpm roku live-test-flow-smoke` for auth, navigation, dialog, and settings changes
- `STORY=<story-id> pnpm roku lab-install` for isolated component work

Run `pnpm roku console` beside playback flows, and `pnpm roku debug-snapshot`
after a crash, ECP timeout, or failed capture.

If `live-test` passes but install fails with repeated HTTP `401`, Developer
Mode auth failed: check `ROKU_DEV_PASSWORD`. If authenticated GETs work and
only uploads fail, retry `pnpm roku install`; some Roku developer endpoints
drop multipart uploads intermittently.
