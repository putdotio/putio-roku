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
```

Required for sideload install checks:

```bash
ROKU_DEV_PASSWORD=<developer-mode-password>
```

Keep `.env` local. Device IPs, Developer Mode passwords, signing keys, and
download tokens do not belong in git.

Install the repo toolchain before running smoke or install checks:

```bash
pnpm install --frozen-lockfile
```

## Commands

```bash
make smoke
make live-test
make live-test-launch
make live-test-install
make console
```

- `make smoke` runs BrighterScript/`bslint` and builds a fresh sideload ZIP.
- `make live-test` proves the configured Roku responds to ECP, exposes the
  developer installer, and returns active-app/device metadata.
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
3. Run `make live-test-install` after code changes that must be reproduced on
   hardware.
4. In another terminal, run `make console` before launching playback flows so
   BrightScript compile/runtime/player logs are visible.

If `make live-test` passes but `make live-test-install` fails with HTTP `401`,
the device is reachable but `ROKU_DEV_PASSWORD` is missing or incorrect.

## Readiness Grade

- Bootable: partial. The app can be packaged locally and launched on a
  configured developer-enabled Roku.
- Testable: partial. `make smoke` and CI prove static checks plus packaging;
  hardware behavior still needs a real device.
- Observable: partial. ECP state and the BrightScript console are available
  through Make targets.
- Verifiable: partial. `make verify` is deterministic locally/CI; real
  playback/subtitle proof is hardware-backed through this runbook.
