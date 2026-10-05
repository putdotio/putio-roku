# Agent Guide

## Repo

- The put.io Roku app. Roku no longer supports private channels, so users install it by sideloading the released ZIP from [roku.put.io/v2.zip](https://roku.put.io/v2.zip)
- Stack: BrightScript, SceneGraph, BrighterScript tooling

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md)
- [Live Test](./live-test/README.md)
- [Roku Visual Reference](./.vref/README.md)
- [Icon system](./docs/ICONS.md)
- [Font system](./docs/FONTS.md)
- [Release workflow](./docs/RELEASE.md)
- [Security](https://github.com/putdotio/.github/blob/main/SECURITY.md)

## Commands

- `pnpm verify` (alias `pnpm smoke`) runs every static check and then builds a fresh ZIP; the steps are `verify` in [scripts/roku-task/build.ts](./scripts/roku-task/build.ts)
- `pnpm artifact` builds the production release ZIP
- `pnpm sideload` builds, validates the target, and reinstalls the app
- `pnpm roku help` lists common tasks and `pnpm roku help --all` every task; the tables in [Live Test](./live-test/README.md#commands) pair each task with its variables

## Worktrees

`.worktreeinclude` carries `.env` files and synced `fonts/` into Codex and Claude
worktrees. Run `pnpm install --frozen-lockfile`; use `pnpm roku secrets-setup` if
env files are missing or stale and a maintainer supplied a SOPS payload, and
`pnpm roku fonts-setup` if the brand faces are missing.

## Ways To Hurt Yourself

- **Taking over someone's Roku.** A Roku holds one sideloaded developer app, which on a household Roku is its put.io install, and `pnpm sideload`, `install`, `lab-install` and the live-test installs replace it. The configured target may be a TV someone is watching or testing another build on; `pnpm roku active-app` shows what is on screen. Read-only tasks such as `check-roku-dev-target` and `device-info` leave it alone
- **Publishing a screenshot forever.** Every release deploys `.vref/` to [roku.put.io/vref](https://roku.put.io/vref/), the site never purges, and this repository is public. A committed capture with real account data stays public even after you delete it
- **Leaking private values.** Checked-in defaults stay open-source-safe. Device IPs, passwords, signing keys and tokens stay out of git: local values live in ignored `.env`, `.env.local` and `.putio-cli/`, release credentials in GitHub Environments

## Rules

- Source comments carry device quirks, invariants, and external constraints only, such as a Roku model's HLS behavior or a put.io API field's meaning; no section banners, code narration, or commented-out debug code; name a value instead of annotating a magic number

## Proof

- Docs only: `pnpm verify`; no device proof
- Source, asset or config: `pnpm verify`, then device proof for behavior the change touches
- Modal or component UI: an isolated Lab story; prefer it over authenticated flows when it can show the change. `STORY=<story-id> pnpm roku lab-screenshot` installs the story and captures it; `lab-install` alone installs it for a look on the TV
- Auth, files, dialogs, settings or get-new-code: `pnpm roku live-test-flow-smoke`; broad routing, player or image refactors: `pnpm roku live-test-flow-full`
- Live-test flow wiring, fixture parsing or Lab capture registry: `pnpm roku test-live` (Vitest contract tests)
- Visual changes: screenshots uploaded with `gh pr comment <n> --attach ./file.png`, never committed outside curated `.vref/`

## Build And Config

- Local overrides flow through optional `.env` and ignored `.env.local`; `.env.local` wins. `secrets-setup` replaces `.env.local`, so keep the Roku target in `.env`. Setup: [Live Test](./live-test/README.md#setup)
- `.env.example` must stay sanitized and safe to publish
- Roku static checks are configured through `bsconfig.json` and `bslint.json`
- Runtime error reporting posts Sentry envelopes directly from `SentryTask`; the DSN is compiled in from `PUTIO_ROKU_SENTRY_DSN` at packaging time and stays empty in git, so local builds report nothing. Playback failures follow the `playback_failure` telemetry contract in [Roku variants and Lab](./docs/ROKU_VARIANTS.md#error-reporting)
- Roku layout is authored in 1920x1080 FHD coordinates even when device screenshots are 1280x720; use `components/shared/UiMetrics/UiMetrics.brs` for shared screen, centering, row, and 3px autoscale-grid values instead of scattering raw modal/list dimensions
- Headless Roku control uses `@putdotio/rokit` for generic Roku ECP/SceneGraph primitives and `scripts/roku-live-test.ts` for app-specific playback scenarios
- Product glyphs use the pinned Phosphor pipeline in [Icon system](./docs/ICONS.md): edit `config/phosphor-icons.json`, run `pnpm roku icons`; never hand-edit `images/icons/*.png`, and keep brand/channel/splash art outside the icon set
- Brand typography uses licensed GT America faces per [Font system](./docs/FONTS.md): `pnpm roku fonts-setup` fetches them without a credential, they are **never committed** (`pnpm verify` fails if git tracks an `.otf`/`.ttf`/`.ttc`), and a clone without them builds and runs on the Roku system font. A face ships only when it is listed in `config/brand-fonts.json` and validates
- Curated Roku screenshots live in `.vref/`; capture, validate, and gallery commands and the public-safe rules are in [Roku Visual Reference](./.vref/README.md#workflow)

## Delivery

- Open a pull request; [CI](./.github/workflows/ci.yml) runs `pnpm verify` and should stay aligned with it
- [Links](./.github/workflows/links.yml) checks relative Markdown links and anchors on pull requests and `main` pushes
- [Scan](./.github/workflows/scan.yml) runs Gitleaks and TruffleHog on pull requests, Actionlint and Zizmor on pull requests that change `.github/`, and all four weekly
- A push to `main` runs [Release](./.github/workflows/release.yml): verify, then semantic-release. A `feat`, `fix`, `perf`, revert or breaking commit publishes a GitHub Release ZIP and deploys it to [roku.put.io/v2.zip](https://roku.put.io/v2.zip) with the `.vref` gallery; other commit types release nothing. Versioning and recovery: [Release workflow](./docs/RELEASE.md)
