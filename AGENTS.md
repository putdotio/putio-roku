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

- `pnpm verify`
- `pnpm smoke`
- `pnpm artifact`
- `pnpm sideload`
- `pnpm roku help`
- `pnpm roku icons`
- `pnpm roku fonts-setup`
- `pnpm roku fonts-check`
- `pnpm roku secrets-setup`
- `pnpm roku live-test`
- `pnpm roku live-test-control`
- `CONTENT_ID=<file-id> pnpm roku live-test-playback`
- `AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-player-ui`
- `pnpm roku live-test-flow-smoke`
- `FLOWS=auth,files,dialogs pnpm roku live-test-flow`
- `PLAYBACK_CONTENT_ID=<video-file-id> IMAGE_CONTENT_ID=<image-file-id> AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id> pnpm roku live-test-flow-full`
- `pnpm roku test-live`
- `STORY=<story-id> pnpm roku lab-install`
- `STORY=<story-id> pnpm roku lab-screenshot`
- `pnpm roku visual-capture-pages`
- `pnpm roku visual-capture-lab`
- `pnpm roku visual-validate`
- `pnpm roku visual-gallery`
- `pnpm roku live-test-install`
- `pnpm roku console`

## Worktrees

`.worktreeinclude` carries `.env` files and synced `fonts/` into Codex and Claude
worktrees. Run `pnpm install --frozen-lockfile`; use `pnpm roku secrets-setup` if
env files are missing or stale and a maintainer supplied a SOPS payload, and
`pnpm roku fonts-setup` if the brand faces are.

## Rules

- Keep checked-in defaults open-source-safe
- Private device details, passwords, and signing keys stay out of git
- Source comments carry device quirks, invariants, and external constraints only; no section banners, no code narration, no commented-out debug code
- Update docs when setup, validation, or delivery expectations change

## Build And Config

- Local overrides flow through optional `.env` and ignored `.env.local`; `.env.local` wins when both are present
- `PUTIO_ROKU_SOPS_FILE=/path/to/roku.sops.env pnpm roku secrets-setup` decrypts a maintainer-supplied SOPS payload into ignored mode-`0600` `.env.local`; keep the local Roku target in `.env`
- `.env.example` must stay sanitized and safe to publish
- `pnpm verify` type-checks the live-test harness, checks Roku formatting, runs Roku static checks, and builds a fresh ZIP
- `pnpm roku test-live` runs the Vitest contract tests for live-test flow wiring, fixture argument parsing, and Lab visual-capture registry drift
- Roku static checks are configured through `bsconfig.json` and `bslint.json`
- Roku layout is authored in 1920x1080 FHD coordinates even when device screenshots are 1280x720; use `components/shared/UiMetrics/UiMetrics.brs` for shared screen, centering, row, and 3px autoscale-grid values instead of scattering raw modal/list dimensions
- Headless Roku control uses `@putdotio/rokit` for generic Roku ECP/SceneGraph primitives and `scripts/roku-live-test.ts` for app-specific playback scenarios
- Live app regressions are grouped as flow suites: use `pnpm roku live-test-flow-smoke` for auth/files/dialogs/settings/get-new-code coverage and `pnpm roku live-test-flow-full` before shipping broad routing/player/image refactors
- `STORY=<story-id> pnpm roku lab-install` and `STORY=<story-id> pnpm roku lab-screenshot` open isolated Lab stories for modal/component UI work; use them before broader authenticated flows when the change can be proven in Lab
- Product glyphs use the pinned Phosphor pipeline in [Icon system](./docs/ICONS.md): edit `config/phosphor-icons.json`, run `pnpm roku icons`, and the `check-roku-icons` gate in `pnpm verify` blocks drift. Generated `images/icons/*.png` are white 128px templates tinted at runtime via `blendColor`/`designTokenColor`; do not hand-edit them, and keep brand/channel/splash art outside the icon set
- Brand typography uses licensed GT America faces per [Font system](./docs/FONTS.md): they are pinned by sha256 in `config/brand-fonts.json`, synced from private `putio-static` with `pnpm roku fonts-setup`, and **never committed** — `pnpm verify` fails if git ever tracks an `.otf`/`.ttf`/`.ttc`. A clone without them is fully working: packaging bundles the manifest-listed faces individually and only when every one matches its pinned digest, and compiles `buildConfigBrandFontsAvailable()` into `source/BuildConfig.brs` so the runtime falls back to `font:*SystemFont`. Dropping a face into `fonts/` by hand is not enough — it must match the manifest. `pnpm roku fonts-check` is intentionally outside `pnpm verify`
- Curated Roku screenshots live in `.vref/`; use `NAME=<short-screen-name> pnpm roku visual-capture`, `pnpm roku visual-capture-pages`, or `pnpm roku visual-capture-lab`, update public-safe references manually, validate with `pnpm roku visual-validate`, and rebuild the gallery with `pnpm roku visual-gallery`. `pnpm roku visual-capture-lab` captures stable AppDialog stories by default; pass explicit `STORIES` or `ALL=1` only when probing heavier Lab components deliberately.

## CI

- [CI](https://github.com/putdotio/putio-roku/actions/workflows/ci.yml) is verify-only and should stay aligned with `pnpm verify`
- [Release](https://github.com/putdotio/putio-roku/actions/workflows/release.yml) verifies first, then semantic-release publishes official ZIPs only when a release is due
- [Latest Roku v2 ZIP](https://roku.put.io/v2.zip) is the official released sideload ZIP
