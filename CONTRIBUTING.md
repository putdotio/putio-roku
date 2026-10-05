# Contributing

Thanks for contributing to `putio-roku`

## Setup

Prerequisites:

- Node.js from `.node-version`
- `pnpm`

Install the Node-based Roku toolchain:

```bash
pnpm install --frozen-lockfile
```

Build-only commands such as `pnpm verify` need no env file. For device work,
copy the sample and set your Roku target and Developer Mode password:

```bash
cp .env.example .env
```

Maintainers with the shared encrypted test payload render the shared test
account and fixtures into `.env.local` with `pnpm roku secrets-setup`; use that
account for hardware-backed checks so screenshots, navigation, playback, and
track selection run against stable fixtures. [Live Test setup](./live-test/README.md#setup)
covers both paths and the variables each check needs.

If you need help enabling Developer Mode on the device itself, use the [Sideloading guide](./docs/SIDELOADING.md)

## Run Locally

Check that the Roku developer endpoint is reachable:

```bash
pnpm roku check-roku-dev-target
```

Build and reinstall the app on the configured Roku device:

```bash
pnpm sideload
```

`pnpm sideload` removes the previously installed developer app, builds a fresh ZIP, validates the target, and reinstalls the app. `pnpm roku build-dev` and `pnpm roku build-lab` build explicit variants; `pnpm roku help --all` lists every task.

See [Live Test](./live-test/README.md) for hardware-backed checks and the
debug loop, and [Roku variants and Lab](./docs/ROKU_VARIANTS.md) for the
development/Lab packaging split and the Roku-specific design asset adapter.

## Validation

Run the standard repo verification before opening or updating a pull request:

```bash
pnpm verify
```

It runs every static check, then builds a fresh ZIP for the selected variant;
the steps are `verify` in [scripts/roku-task/build.ts](./scripts/roku-task/build.ts).
`pnpm roku check-markdown-format` runs the Markdown formatting check alone;
`pnpm exec oxfmt "**/*.md"` fixes it.

Build the release-style ZIP used by automation:

```bash
pnpm artifact
```

`pnpm artifact` always rebuilds the production variant before writing
`dist/apps/putio-roku-v2.zip`.

## Development Notes

Source conventions, the layout grid, icon and font pipelines, and secret
boundaries: [Rules](./AGENTS.md#rules) and [Build And Config](./AGENTS.md#build-and-config).

## Pull Requests

- Keep changes focused and explicit
- Add or update validation when behavior changes
- Prefer small follow-up pull requests over mixing unrelated cleanup into the same branch
- Upload proof screenshots or recordings with `gh pr create --attach ./file.png` or `gh pr comment <n> --attach ./file.mp4`; only curated `.vref/` references are committed

## CI And Delivery

[CI](./.github/workflows/ci.yml) runs `pnpm verify` and an offline check of relative Markdown links and anchors on pull requests and manual dispatch. On pushes to `main`, [Release](./.github/workflows/release.yml) calls the same CI job before release evaluation unless the head commit contains `[skip ci]`; there the job also audits `.github/` changes with Actionlint and Zizmor. Publishing, versioning, and recovery are in [Release workflow](./docs/RELEASE.md).
