# Agent Guide

## Repo

- The put.io Roku app. Roku no longer supports private channels, so users install it by sideloading the released ZIP from [roku.put.io/v2.zip](https://roku.put.io/v2.zip)
- Stack: BrightScript, SceneGraph, BrighterScript tooling

## Start Here

- [Contributing](./CONTRIBUTING.md): setup, sideload, checks
- [Live Test](./live-test/README.md): before any device proof

## Commands

- `pnpm verify` (alias `pnpm smoke`) runs every static check and then builds a fresh ZIP; the steps are `verify` in [scripts/roku-task/build.ts](./scripts/roku-task/build.ts)
- `pnpm artifact` builds the production release ZIP
- `pnpm sideload` builds, validates the target, and reinstalls the app
- `pnpm roku help` lists common tasks and `pnpm roku help --all` every task; a task missing a required variable fails with an example command

## Worktrees

`.worktreeinclude` carries `.env` files and synced `fonts/` into Codex and Claude
worktrees. Run `pnpm install --frozen-lockfile`; use `pnpm roku secrets-setup` if
env files are missing or stale and a maintainer supplied a SOPS payload, and
`pnpm roku fonts-setup` if the brand faces are missing.

## Ways To Hurt Yourself

- **Taking over someone's Roku.** A Roku holds one sideloaded developer app, which on a household Roku is its put.io install, and `pnpm sideload`, `install`, `lab-install` and the live-test installs replace it. The configured target may be a TV someone is watching or testing another build on; `pnpm roku active-app` shows what is on screen. Read-only tasks such as `check-roku-dev-target` and `device-info` leave it alone
- **Leaking private values.** Checked-in defaults stay open-source-safe, and `.env.example` stays sanitized. Device IPs, passwords, signing keys and tokens stay out of git: local values live in ignored `.env`, `.env.local` and `.putio-cli/`, release credentials in GitHub Environments
- **Redistributing the brand font.** GT America is licensed; never commit, subset, convert, rename or re-host the faces, and never add them to `@putdotio/design`. `static.put.io` is the single source; `pnpm verify` catches only tracked `.otf`/`.ttf`/`.ttc` files

## Rules

- Source comments carry device quirks, invariants, and external constraints only, such as a Roku model's HLS behavior or a put.io API field's meaning; no section banners, code narration, or commented-out debug code; name a value instead of annotating a magic number
- Author layout in 1920x1080 FHD coordinates even though device screenshots are 1280x720; take screen, centering, row, and 3px autoscale-grid values from [UiMetrics.brs](./components/shared/UiMetrics/UiMetrics.brs) instead of raw modal or list dimensions
- Generic Roku ECP and SceneGraph control belongs in `@putdotio/rokit`; app-specific playback scenarios belong in [scripts/roku-live-test.ts](./scripts/roku-live-test.ts)
- Edit `config/phosphor-icons.json` and run `pnpm roku icons`; never hand-edit `images/icons/*.png`
- Sentry events carry only allowlisted safe fields; [sentry-privacy.test.ts](./test/sentry/sentry-privacy.test.ts) pins them

## Proof

- Docs only: `pnpm verify`; no device proof
- Source, asset or config: `pnpm verify`, then device proof for behavior the change touches
- Modal or component UI: an isolated Lab story; prefer it over authenticated flows when it can show the change. `STORY=<story-id> pnpm roku lab-screenshot` installs the story and captures it; `lab-install` alone installs it for a look on the TV
- Auth, files, dialogs, settings or get-new-code: `pnpm roku live-test-flow-smoke`; broad routing, player or image refactors: `pnpm roku live-test-flow-full`
- Live-test flow wiring, fixture parsing or Lab capture registry: `pnpm roku test-live` (Vitest contract tests)
- Visual changes: screenshots uploaded with `gh pr comment <n> --attach ./file.png`, never committed

## Delivery

- Open a pull request; [CI](./.github/workflows/ci.yml) runs `pnpm verify`
- Merging a releasing commit type ([.releaserc.json](./.releaserc.json)) ships to every user through [roku.put.io/v2.zip](https://roku.put.io/v2.zip); pick the type on purpose
- A release that stops halfway: dispatch [Release](./.github/workflows/release.yml) from `main` with the existing tag; it resumes the draft or deploy and never changes a published Release
- The AWS deploy role behind [Release](./.github/workflows/release.yml) must trust GitHub OIDC only for production deploys from `putdotio/putio-roku` on `main`
