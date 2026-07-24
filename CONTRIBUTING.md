# Contributing

Thanks for contributing to `putio-roku`

## Setup

Prerequisites:

- Node.js from `.node-version`
- `pnpm`

Optional local overrides live in `.env` or `.env.local`. If your onboarding
includes Infisical access, render the shared testing-account values first:

```bash
pnpm roku secrets-setup
```

That reads the repo-owned Infisical path and writes an ignored `.env.local` with
the shared put.io test account, OAuth fields, and live-test fixture IDs. Set the
onboarding-provided `PUTIO_ROKU_INFISICAL_*` variables in this repo or worktree
shell before running the command. Keep using that same account for
hardware-backed Roku checks so
screenshots, file navigation, playback, and track-selection flows exercise
stable fixtures.

If you are using your own local device or credentials, copy the sample file:

```bash
cp .env.example .env
```

Then fill in the device and fixture values you have locally. The Infisical
setup command is only needed when you are using the shared test fixtures.

Supported variables:

- `ROKU_DEV_TARGET` or `ROKIT_TARGET` for the IP address of a developer-enabled Roku device
- `ROKU_DEV_PASSWORD` or `ROKIT_PASSWORD` for the Roku Developer Mode password when authenticated installs are required
- `ROKU_APP_ECP_ID` for the ECP app id to launch during live tests; defaults to `dev` for sideloaded packages
- `PLAYBACK_CONTENT_ID`, `IMAGE_CONTENT_ID`, `AUDIO_CONTENT_ID`, and `SUBTITLE_CONTENT_ID` for the full hardware-backed live-test sweep
- `PUTIO_CLI_PROFILE`, `PUTIO_CLI_CONFIG_PATH`, `PUTIO_TEST_USERNAME`, `PUTIO_TEST_PASSWORD`, `PUTIO_TEST_TOTP_REFERENCE`, `PUTIO_CLIENT_ID_FIRST_PARTY`, and `PUTIO_CLIENT_SECRET_FIRST_PARTY` for the Infisical-backed put.io CLI harness

If you need help enabling Developer Mode on the device itself, use the [Sideloading guide](./docs/SIDELOADING.md)

Install the Node-based Roku toolchain:

```bash
pnpm install --frozen-lockfile
```

## Run Locally

Check that the Roku developer endpoint is reachable:

```bash
pnpm roku check-roku-dev-target
```

Build and reinstall the app on the configured Roku device:

```bash
pnpm sideload
```

`pnpm sideload` removes the previously installed developer app, builds a fresh ZIP, validates the target, and reinstalls the app.

Useful commands:

- `pnpm verify` runs the full local gate and packages a fresh ZIP
- `pnpm artifact` builds the production release-style ZIP
- `pnpm sideload` builds, validates the target, and reinstalls the app
- `pnpm roku help` lists Roku helper tasks
- `pnpm roku build-dev` and `pnpm roku build-lab` build explicit variants
- `pnpm roku live-test`, `pnpm roku live-test-control`, and
  `CONTENT_ID=<file-id> pnpm roku live-test-playback` cover common hardware checks
- `STORY=<story-id> pnpm roku lab-install` opens an isolated Lab story

See [Live Test](./live-test/README.md) for the hardware-backed debugging flow.
See [Roku variants and Lab](./docs/ROKU_VARIANTS.md) for the
development/Lab packaging split and the Roku-specific design asset adapter.

## Validation

Run the standard repo verification before opening or updating a pull request:

```bash
pnpm verify
```

Build the release-style ZIP used by automation:

```bash
pnpm artifact
```

`pnpm artifact` always rebuilds the production variant before writing
`dist/apps/putio-roku-v2.zip`. `pnpm verify` always type-checks the live-test
harness, checks Roku source formatting, runs Roku static checks, and creates a
fresh app ZIP for the selected variant.

## Development Notes

- Keep checked-in defaults open-source-safe
- Keep device addresses, passwords, signing keys, and private release notes out of commits
- Author Roku UI in 1920x1080 logical coordinates, but keep visible edges and common spacing on the 3px grid exposed by `components/shared/UiMetrics/UiMetrics.brs`; many Roku devices output 1280x720 screenshots from the FHD scene and scale by 2/3
- Product glyphs use the pinned Phosphor icon system; edit `config/phosphor-icons.json` and run `pnpm roku icons` rather than hand-editing `images/icons/*.png`. See [Icon system](./docs/ICONS.md)
- Prefer repo-relative doc links when adding or updating documentation
- Update docs when sideloading, validation, CI, or release expectations change

## Pull Requests

- Keep changes focused and explicit
- Add or update validation when behavior changes
- Prefer small follow-up pull requests over mixing unrelated cleanup into the same branch
- Re-run `pnpm verify` before requesting review

## CI And Delivery

- [CI](https://github.com/putdotio/putio-roku/actions/workflows/ci.yml) runs `pnpm verify` on pull requests and pushes to `main`
- [Release](https://github.com/putdotio/putio-roku/actions/workflows/release.yml) verifies first, then semantic-release publishes official ZIPs when Conventional Commits produce a release
- Released ZIPs are published to [GitHub Releases](https://github.com/putdotio/putio-roku/releases) and the [latest Roku v2 ZIP](https://roku.put.io/v2.zip)
