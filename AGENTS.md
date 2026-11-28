# Agent Guide

## Repo

- The put.io Roku app; users sideload the released ZIP from [roku.put.io/v2.zip](https://roku.put.io/v2.zip)
- Stack: BrightScript, SceneGraph, BrighterScript tooling

## Start Here

- [Contributing](./CONTRIBUTING.md): setup, sideload, checks
- `pnpm verify` steps: `verify` in [scripts/roku-task/build.ts](./scripts/roku-task/build.ts)

## Ways To Hurt Yourself

- **Taking over someone's Roku.** A Roku holds one sideloaded developer app (on a household TV, its put.io install). `pnpm sideload` and `pnpm roku` tasks that install or remove apps (`install`, `remove`, `harness-install`, `live-test-install`, `lab-install`, `lab-screenshot`, `visual-capture-lab`, `live-test-flow-smoke`, `live-test-flow-full`) replace it. Check what is on screen with `pnpm roku active-app`; read-only tasks (`pnpm roku check-roku-dev-target`, `pnpm roku device-info`) leave the device untouched
- **Leaking private values.** Checked-in defaults stay open-source-safe, and `.env.example` stays sanitized. Device IPs, passwords, OAuth client secrets, private keys and tokens stay out of git: local values live in ignored `.env`, `.env.local` and `.putio-cli/`, release credentials in GitHub Environments
- **Redistributing the brand font.** GT America is licensed; never commit, subset, convert, rename or re-host the faces, and never add them to `@putdotio/design`. `static.put.io` is the single source; `pnpm verify` catches only tracked `.otf`/`.ttf`/`.ttc` files

## Rules

- Source comments carry device quirks, invariants, and external constraints only, such as a Roku model's HLS behavior or a put.io API field's meaning; a magic number becomes a named value
- Author layout in 1920x1080 FHD coordinates; device screenshots come out at 1280x720. Take screen, centering, row, and 3px autoscale-grid values from [UiMetrics.brs](./components/shared/UiMetrics/UiMetrics.brs)
- Generic Roku ECP and SceneGraph control belongs in `@putdotio/rokit`; app-specific live-test flows belong in [scripts/roku-live-test.ts](./scripts/roku-live-test.ts) and `scripts/live-test/`
- Change icons in `config/phosphor-icons.json`, then run `pnpm roku icons`; it syncs `images/icons/*.png` and `third-party/phosphor-icons/LICENSE`
- Sentry events carry only allowlisted safe fields; [sentry-privacy.test.ts](./test/sentry/sentry-privacy.test.ts) pins them

## Proof

- Docs only: `pnpm verify`; no device proof
- Source, asset or config: `pnpm verify`, then device proof for behavior the change touches
- Modal or component UI: an isolated Lab story whenever it can show the change. `STORY=<story-id> pnpm roku lab-screenshot` installs the story and captures it; `STORY=<story-id> pnpm roku lab-install` installs it without taking a screenshot
- Auth, files, history, dialogs, settings or get-new-code: `pnpm roku live-test-flow-smoke`; broad routing, player or image refactors: `pnpm roku live-test-flow-full`
- Fast unit and contract suite (BrightScript playback/account/Sentry/update logic, Alchemy headers/state, live-test helpers): `pnpm roku test-live` (`vitest run`)
- Visual changes: screenshots uploaded with `gh pr create --attach ./file.png` or `gh pr comment <n> --attach ./file.png`, never committed

## Delivery

- Merging a releasing commit type ([.releaserc.json](./.releaserc.json)) ships to every user through [roku.put.io/v2.zip](https://roku.put.io/v2.zip); pick the type on purpose
- The AWS deploy role behind [Release](./.github/workflows/release.yml) must trust GitHub OIDC only for production deploys from `putdotio/putio-roku` on `main`
