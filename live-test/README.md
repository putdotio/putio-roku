# Live Test

Hardware-backed checks for the put.io Roku app. Use these when a change needs
proof from a real Roku device instead of only a ZIP build.

## Setup

If your onboarding includes Infisical access, render the shared testing-account
and fixture values first, then fill in the local device values in the generated
file:

```bash
pnpm roku secrets-setup
```

`pnpm roku secrets-setup` writes `.env.local` from the repo-owned Infisical path.
Set the onboarding-provided `PUTIO_ROKU_INFISICAL_*` variables in this repo or
worktree shell before running the command. The generated file includes the
approved put.io CLI profile, harness credentials, OAuth fields, and the file IDs
used by `pnpm roku live-test-flow-full`.

If you are using your own local device or credentials, copy the sample
environment file:

```bash
cp .env.example .env
```

Required for read-only device checks:

```bash
ROKU_DEV_TARGET=<roku-ip>
# or ROKIT_TARGET=<roku-ip>
# Optional; defaults to dev for sideloaded packages.
ROKU_APP_ECP_ID=<roku-app-id>
```

Use `ROKU_APP_ECP_ID` when driving a Roku beta or public app whose ECP id is not
the sideload-only `dev` id. Sideloaded `production`, `development`, and `lab`
ZIPs all still launch as `dev`.

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
PUTIO_TEST_USERNAME=<testing-account-username>
PUTIO_TEST_PASSWORD=<testing-account-password>
PUTIO_TEST_TOTP_REFERENCE=<testing-account-totp-secret>
PUTIO_CLIENT_ID_FIRST_PARTY=<oauth-client-id>
PUTIO_CLIENT_SECRET_FIRST_PARTY=<oauth-client-secret>
```

Keep `.env` and `.env.local` local. Device IPs, Developer Mode passwords,
signing keys, and download tokens do not belong in git. `.putio-cli/` is ignored
and may contain local put.io CLI auth state for the testing account.

Install the repo toolchain before running smoke or install checks:

```bash
pnpm install --frozen-lockfile
```

The pnpm Roku runner loads `.env` and `.env.local` automatically, with
`.env.local` winning when both are present. If you call
`node scripts/roku-live-test.ts` directly, export `ROKU_DEV_TARGET` or
`ROKIT_TARGET` in the shell first. The scenario script uses `@putdotio/rokit`
for generic Roku device control and keeps put.io-specific playback assertions
in this repo.

## Commands

Use `pnpm roku <task>` for hardware and helper tasks. Put repeated values in
`.env.local`; set one-off values inline when a row lists required or optional
variables.

### Basic Checks

| Use | Command | Variables |
| --- | --- | --- |
| Local smoke gate | `pnpm smoke` | None |
| Harness contract tests | `pnpm roku test-live` | None |
| Read-only device check | `pnpm roku live-test` | `ROKU_DEV_TARGET` or `ROKIT_TARGET` |
| Launch and remote-control smoke | `pnpm roku live-test-control` | Optional: `ROKU_APP_ECP_ID` |
| Send explicit remote keys | `pnpm roku live-test-press` | Required: `KEYS` |
| Launch the configured app id | `pnpm roku launch` | Optional: `ROKU_APP_ECP_ID` |
| Reinstall and launch this checkout | `pnpm roku live-test-install` | Required: `ROKU_DEV_PASSWORD` |
| Attach BrightScript console | `pnpm roku console` | Optional: `ROKU_DEV_CONSOLE_PORT` |
| Capture crash/debug state | `pnpm roku debug-snapshot` | Optional: `ROKU_DEBUG_ARTIFACT_DIR` |

`pnpm smoke` type-checks the live-test harness, checks Roku formatting, runs
BrighterScript/`bslint`, and builds a fresh sideload ZIP. `pnpm roku live-test`
proves the Roku responds to ECP, exposes the developer installer, and returns
active-app/device metadata.

### Playback

| Use | Command | Inputs |
| --- | --- | --- |
| Deep link to a file | `pnpm roku live-test-deeplink` | `CONTENT_ID`; optional `MEDIA_TYPE` |
| Open playback | `pnpm roku live-test-playback` | `CONTENT_ID`; optional `MEDIA_TYPE`, `START_FROM` |
| Open playback with remote prompt handling | `pnpm roku live-test-playback-remote` | Same as playback |
| Set API playback preference | `pnpm roku live-test-playback-type` | `TYPE`; optional `PUTIO_CLI_PROFILE` |
| Verify selected playback type | `pnpm roku live-test-playback-type-smoke` | `TYPE`, `CONTENT_ID`; optional start knobs |
| Verify playback error dialog | `pnpm roku live-test-playback-error-dialog` | `CONTENT_ID`; optional expected text |
| Verify custom player controls | `pnpm roku live-test-player-ui` | Track fixture ids; optional start knobs |
| Capture player UI screenshots | `pnpm roku live-test-player-ui-screenshots` | Track fixture ids and Developer Mode password |

Playback commands launch the configured app id; `ROKU_APP_ECP_ID` defaults to
`dev` for sideloaded builds. `pnpm roku live-test-player-ui` uses SceneGraph state
for the assertions because Roku developer screenshots capture the app UI plane
but not always the video plane. Track fixture ids are `AUDIO_CONTENT_ID` and
`SUBTITLE_CONTENT_ID`; start knobs are `MEDIA_TYPE` and `START_FROM`. The
screenshot command also accepts `OUTPUT_DIR` and `PLAYER_UI_REFERENCE_IMAGE`,
then writes focused-control captures and a `review.html` page under
`dist/tmp/player-ui/<run>/` by default.

### Flow Suites

| Use | Command | Inputs |
| --- | --- | --- |
| App shell smoke | `pnpm roku live-test-flow-smoke` | Prepared test account; optional `OUTPUT_DIR` |
| Custom flow list | `pnpm roku live-test-flow` | `FLOWS`; optional fixture ids/output |
| Full regression sweep | `pnpm roku live-test-flow-full` | Full fixture ids; optional start knobs/output |

Available custom flows are `auth`, `get-new-code`, `files`, `history`,
`dialogs`, `settings`, `logout`, `playback`, `image`, and `tracks`. Flow runs
write output under `dist/tmp/flows/` unless `OUTPUT_DIR` is set. Full fixture
ids are `PLAYBACK_CONTENT_ID`, `IMAGE_CONTENT_ID`, `AUDIO_CONTENT_ID`, and
`SUBTITLE_CONTENT_ID`; custom flows accept the same ids when the selected flows
need them. Failure snapshots go under `.local/roku-debug/` when ECP is still
reachable.

### Lab And Visuals

| Use | Command | Inputs |
| --- | --- | --- |
| Install Lab and open a story | `pnpm roku lab-install` | Developer Mode password; optional `STORY` |
| Capture a Lab story | `pnpm roku lab-screenshot` | Developer Mode password; optional `STORY`, delay |
| Capture current screen | `pnpm roku visual-capture` | `NAME` and Developer Mode password |
| Capture main app pages | `pnpm roku visual-capture-pages` | Test account, Developer Mode password, optional page knobs |
| Capture Lab stories | `pnpm roku visual-capture-lab` | Developer Mode password; optional story selection |
| Validate visual reference assets | `pnpm roku visual-validate` | None |
| Rebuild visual reference gallery | `pnpm roku visual-gallery` | None |

`pnpm roku lab-install` builds the `ROKU_VARIANT=lab` package and relaunches the
developer-channel process with `lab=1`. `STORY` defaults to `app-dialog-empty`;
story ids are defined in `scripts/live-test/visual-capture.ts` and mirrored by
the Lab component tests. `pnpm roku visual-capture-lab` captures the stable
AppDialog stories by default; use `STORIES="story-id ..."` for targeted
captures and `ALL=1` only for deliberate broad sweeps. Page capture knobs are
`OUTPUT_DIR`, `INCLUDE_AUTH`, and `IMAGE_CONTENT_ID`; Lab screenshot delay is
`LAB_SCREENSHOT_DELAY`.

### Auth Helpers

| Use | Command | Inputs |
| --- | --- | --- |
| Check local put.io CLI auth state | `pnpm roku putio-auth-status` | Optional `PUTIO_CLI_PROFILE` |
| Prepare ignored test-account auth | `pnpm roku putio-auth-prepare` | Test-account env; optional profile |
| Approve a visible Roku device code | `pnpm roku putio-auth-approve-device` | `CODE`; optional profile |
| Reset Roku app auth | `pnpm roku live-test-auth-reset` | Reachable Roku; optional app id |
| Refresh the visible device code | `pnpm roku live-test-auth-refresh` | Reachable Roku; optional app id |
| Prepare Roku app auth end-to-end | `pnpm roku live-test-auth-prepare` | Test account and Roku; optional profile/app id |

For a one-off install without saving the password in `.env`, pass it as an
environment variable:

```bash
ROKU_DEV_PASSWORD=<developer-mode-password> pnpm roku live-test-install
```

## Debug Loop

Start with `pnpm smoke`, then pick the smallest hardware proof that matches the
change:

- `pnpm roku live-test-control` for launch/remote-control changes
- `CONTENT_ID=<file-id> pnpm roku live-test-playback` for playback routing
- `AUDIO_CONTENT_ID=<id> SUBTITLE_CONTENT_ID=<id> pnpm roku live-test-player-ui`
  for player controls and track menus
- `pnpm roku live-test-flow-smoke` for auth/navigation/dialog/settings changes
- `STORY=<story-id> pnpm roku lab-install` for isolated component work

Use `pnpm roku console` beside playback flows and `pnpm roku debug-snapshot`
after a crash, ECP timeout, or visual capture failure.

If `pnpm roku live-test` passes but install fails with repeated HTTP `401`, the
device is reachable but Developer Mode auth failed. Check `ROKU_DEV_PASSWORD`
first; if authenticated GETs work and only uploads fail, retry
`pnpm roku install` because some Roku developer endpoints intermittently close
multipart uploads.
