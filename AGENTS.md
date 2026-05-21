# Agent Guide

## Repo

- Standalone Roku app repository for put.io
- Stack: BrightScript, SceneGraph, BrighterScript tooling

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md)
- [Live Test](./live-test/README.md)
- [Roku Visual Reference](./.vref/README.md)
- [Security](./SECURITY.md)

## Commands

- `make verify`
- `make smoke`
- `make secrets-setup`
- `make live-test`
- `make live-test-control`
- `make live-test-press KEYS="Back Info"`
- `make live-test-deeplink CONTENT_ID=<file-id>`
- `make live-test-playback CONTENT_ID=<file-id>`
- `make live-test-playback-remote CONTENT_ID=<file-id>`
- `make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
- `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
- `make live-test-flow-smoke`
- `make live-test-flow FLOWS=auth,files,dialogs`
- `make live-test-flow-full PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
- `make test-live`
- `make lab-install STORY=<story-id>`
- `make lab-screenshot STORY=<story-id>`
- `make visual-capture NAME=<short-screen-name>`
- `make visual-capture-pages`
- `make visual-capture-lab`
- `make visual-validate`
- `make visual-gallery`
- `make live-test-launch`
- `make live-test-install`
- `make console`
- `make artifact`
- `make run`
- `make check-roku-live`
- `make check-roku-dev-target`
- `pnpm check:live`
- `pnpm check:roku`
- `pnpm roku:live control-smoke`
- `pnpm format:roku`

## Rules

- Keep checked-in defaults open-source-safe
- Private device details, passwords, and signing keys stay out of git
- Update docs when setup, validation, or delivery expectations change

## Build And Config

- Local overrides flow through optional `.env` and ignored `.env.local`; `.env.local` wins when both are present
- Put.io team members can run `make secrets-setup` to render shared testing-account and live-test fixture values from the `putio-roku` 1Password secure note into `.env.local`, then fill local Roku device values there
- `.env.example` must stay sanitized and safe to publish
- `make verify` type-checks the live-test harness, checks Roku formatting, runs Roku static checks, and builds a fresh ZIP
- `make test-live` runs the Vitest contract tests for live-test flow wiring, fixture argument parsing, and Lab visual-capture registry drift
- Roku static checks are configured through `bsconfig.json` and `bslint.json`
- Roku layout is authored in 1920x1080 FHD coordinates even when device screenshots are 1280x720; use `components/shared/UiMetrics/UiMetrics.brs` for shared screen, centering, row, and 3px autoscale-grid values instead of scattering raw modal/list dimensions
- Headless Roku control uses `@putdotio/rokit` for generic Roku ECP/SceneGraph primitives and `scripts/roku-live-test.ts` for app-specific playback scenarios
- Live app regressions are grouped as flow suites: use `make live-test-flow-smoke` for auth/files/dialogs/settings/get-new-code coverage and `make live-test-flow-full` before shipping broad routing/player/image refactors
- `make lab-install STORY=<story-id>` and `make lab-screenshot STORY=<story-id>` open isolated Lab stories for modal/component UI work; use them before broader authenticated flows when the change can be proven in Lab
- Curated Roku screenshots live in `.vref/`; use `make visual-capture`, `make visual-capture-pages`, or `make visual-capture-lab`, update public-safe references manually, validate with `make visual-validate`, and rebuild the gallery with `make visual-gallery`. `make visual-capture-lab` captures stable AppDialog stories by default; pass explicit `STORIES` or `ALL=1` only when probing heavier Lab components deliberately.

## CI

- [CI](https://github.com/putdotio/putio-roku/actions/workflows/ci.yml) is verify-only and should stay aligned with `make verify`
- [Release](https://github.com/putdotio/putio-roku/actions/workflows/release.yml) verifies first, then semantic-release publishes official ZIPs only when a release is due
- [Latest Roku v2 ZIP](https://roku.put.io/v2.zip) is the official released sideload ZIP
