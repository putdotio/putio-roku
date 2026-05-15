# Agent Guide

## Repo

- Standalone Roku app repository for put.io
- Stack: BrightScript, SceneGraph, BrighterScript tooling

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md)
- [Live Test](./live-test/README.md)
- [Security](./SECURITY.md)

## Commands

- `make verify`
- `make smoke`
- `make live-test`
- `make live-test-control`
- `make live-test-press KEYS="Back Info"`
- `make live-test-deeplink CONTENT_ID=<file-id>`
- `make live-test-playback CONTENT_ID=<file-id>`
- `make live-test-playback-remote CONTENT_ID=<file-id>`
- `make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
- `make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>`
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

- Local overrides flow through optional `.env`
- `.env.example` must stay sanitized and safe to publish
- `make verify` runs the Node-based Roku static checks and builds a fresh ZIP
- Roku static checks are configured through `bsconfig.json` and `bslint.json`
- Headless Roku control uses `@putdotio/rokit` for generic Roku ECP/SceneGraph primitives and `scripts/roku-live-test.ts` for app-specific playback scenarios

## CI

- [CI](https://github.com/putdotio/putio-roku/actions/workflows/ci.yml) is verify-only and should stay aligned with `make verify`
- [Release](https://github.com/putdotio/putio-roku/actions/workflows/release.yml) verifies first, then semantic-release publishes official ZIPs only when a release is due
- [Latest Roku v2 ZIP](https://roku.put.io/v2.zip) is the official released sideload ZIP
