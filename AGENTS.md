# Agent Guide

## Repo

- Standalone Roku app repository for put.io
- Stack: BrightScript, SceneGraph, BrighterScript tooling

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md)
- [Live Test](./live-test/README.md)
- [Roku Visual Reference](./.vref/README.md)
- [Icon system](./docs/ICONS.md)
- [Font system](./docs/FONTS.md)
- [Security](./SECURITY.md)

## Commands

- `pnpm verify` type-checks the live-test harness, checks Roku formatting, runs Roku static checks, and builds a fresh ZIP; `pnpm smoke` is the same task
- `pnpm artifact` builds the production release ZIP
- `pnpm sideload` builds, validates the target, and reinstalls the app
- `pnpm roku help` lists every hardware and helper task; the tables in [Live Test](./live-test/README.md#commands) pair each task with its required variables

## Worktrees

`.worktreeinclude` carries `.env` files and synced `fonts/` into Codex and Claude
worktrees. Run `pnpm install --frozen-lockfile`; use `pnpm roku secrets-setup` if
env files are missing or stale and a maintainer supplied a SOPS payload, and
`pnpm roku fonts-setup` if the brand faces are missing.

## Rules

- Keep checked-in defaults open-source-safe
- Private device details, passwords, and signing keys stay out of git
- Source comments carry device quirks, invariants, and external constraints only; no section banners, no code narration, no commented-out debug code
- Update docs when setup, validation, or delivery expectations change
- Finish edits, `pnpm verify`, and Lab or live-test proof without pausing; ask before sideloading to a device someone else may be using, release actions, and secret changes
- Done means `pnpm verify` passed and the change was proven in Lab or the matching live-test flow, with screenshots captured for visual changes and uploaded to the pull request with `gh pr comment <n> --attach ./file.png`, never committed

## Build And Config

- Local overrides flow through optional `.env` and ignored `.env.local`; `.env.local` wins when both are present
- `PUTIO_ROKU_SOPS_FILE=/path/to/roku.sops.env pnpm roku secrets-setup` decrypts a maintainer-supplied SOPS payload into ignored mode-`0600` `.env.local`; keep the local Roku target in `.env`
- `.env.example` must stay sanitized and safe to publish
- `pnpm roku test-live` runs the Vitest contract tests for live-test flow wiring, fixture argument parsing, and Lab visual-capture registry drift
- Roku static checks are configured through `bsconfig.json` and `bslint.json`
- Runtime error reporting posts Sentry envelopes directly from `SentryTask`; the DSN is compiled in from `PUTIO_ROKU_SENTRY_DSN` at packaging time and stays empty in git, so local builds report nothing. Playback failures follow the `playback_failure` telemetry contract in [Roku variants and Lab](./docs/ROKU_VARIANTS.md#error-reporting)
- Roku layout is authored in 1920x1080 FHD coordinates even when device screenshots are 1280x720; use `components/shared/UiMetrics/UiMetrics.brs` for shared screen, centering, row, and 3px autoscale-grid values instead of scattering raw modal/list dimensions
- Headless Roku control uses `@putdotio/rokit` for generic Roku ECP/SceneGraph primitives and `scripts/roku-live-test.ts` for app-specific playback scenarios
- Live app regressions are grouped as flow suites: use `pnpm roku live-test-flow-smoke` for auth/files/dialogs/settings/get-new-code coverage and `pnpm roku live-test-flow-full` before shipping broad routing/player/image refactors
- `STORY=<story-id> pnpm roku lab-install` and `STORY=<story-id> pnpm roku lab-screenshot` open isolated Lab stories for modal/component UI work; use them before broader authenticated flows when the change can be proven in Lab
- Product glyphs use the pinned Phosphor pipeline in [Icon system](./docs/ICONS.md): edit `config/phosphor-icons.json`, run `pnpm roku icons`; never hand-edit `images/icons/*.png`, and keep brand/channel/splash art outside the icon set
- Brand typography uses licensed GT America faces per [Font system](./docs/FONTS.md): `pnpm roku fonts-setup` fetches them without a credential, they are **never committed** (`pnpm verify` fails if git tracks an `.otf`/`.ttf`/`.ttc`), and a clone without them builds and runs on the Roku system font. A face ships only when it is listed in `config/brand-fonts.json` and validates
- Curated Roku screenshots live in `.vref/`; capture, validate, and gallery commands and the public-safe rules are in [Roku Visual Reference](./.vref/README.md#workflow)

## CI

- [CI](https://github.com/putdotio/putio-roku/actions/workflows/ci.yml) is verify-only and should stay aligned with `pnpm verify`
- [Release](https://github.com/putdotio/putio-roku/actions/workflows/release.yml) verifies first, then semantic-release publishes official ZIPs only when a release is due
- [Latest Roku v2 ZIP](https://roku.put.io/v2.zip) is the official released sideload ZIP
