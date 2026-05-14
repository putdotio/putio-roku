# Contributing

Thanks for contributing to `putio-roku`

## Setup

Prerequisites:

- `make`
- `zip`
- `curl`
- Node.js from `.node-version`
- `pnpm`

Optional local overrides live in `.env`:

```bash
cp .env.example .env
```

Supported variables:

- `ROKU_DEV_TARGET` for the IP address of a developer-enabled Roku device
- `ROKU_DEV_PASSWORD` for the Roku Developer Mode password when authenticated installs are required

If you need help enabling Developer Mode on the device itself, use the [Sideloading guide](./docs/SIDELOADING.md)

Install the Node-based Roku toolchain:

```bash
pnpm install --frozen-lockfile
```

## Run Locally

Check that the Roku developer endpoint is reachable:

```bash
make check-roku-dev-target
```

Build and reinstall the app on the configured Roku device:

```bash
make run
```

`make run` removes the previously installed developer app, builds a fresh ZIP, validates the target, and reinstalls the app.

Useful device-debug commands:

- `make smoke` runs the standard static checks and builds a fresh ZIP
- `pnpm check:roku` runs the BrighterScript compiler diagnostics and `bslint`
- `pnpm format:roku` checks BrightScript/BrighterScript formatting
- `make check-roku-dev-target` checks that the Roku developer endpoint is reachable
- `make live-test` runs read-only device reachability and state checks
- `make live-test-launch` opens the installed developer app and reports active app state
- `make live-test-install` builds, reinstalls, and launches this checkout on the device
- `make launch` opens the sideloaded developer app on the configured Roku
- `make active-app` prints the currently active Roku app from ECP
- `make device-info` prints the configured Roku device metadata from ECP
- `make console` attaches to the BrightScript debug console on port `8085`

See [Live Test](./live-test/README.md) for the hardware-backed debugging flow.

## Validation

Run the standard repo verification before opening or updating a pull request:

```bash
make verify
```

Build the release-style ZIP used by automation:

```bash
make artifact
```

`make verify` always runs the Node-based Roku static checks and creates a fresh app ZIP.

## Development Notes

- Keep checked-in defaults open-source-safe
- Keep device addresses, passwords, signing keys, and private release notes out of commits
- Prefer repo-relative doc links when adding or updating documentation
- Update docs when sideloading, validation, CI, or release expectations change

## Pull Requests

- Keep changes focused and explicit
- Add or update validation when behavior changes
- Prefer small follow-up pull requests over mixing unrelated cleanup into the same branch
- Re-run `make verify` before requesting review

## CI And Delivery

- [CI](https://github.com/putdotio/putio-roku/actions/workflows/ci.yml) runs `make verify` on pull requests and pushes to `main`
- [Release](https://github.com/putdotio/putio-roku/actions/workflows/release.yml) verifies first, then semantic-release publishes official ZIPs when Conventional Commits produce a release
- Released ZIPs are published to [GitHub Releases](https://github.com/putdotio/putio-roku/releases) and the [latest Roku v2 ZIP](https://roku.put.io/v2.zip)
