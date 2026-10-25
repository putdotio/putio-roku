# Contributing

## Setup

Prerequisites: Node.js from `.node-version` and `pnpm`.

```bash
pnpm install --frozen-lockfile
```

Build-only commands such as `pnpm verify` need no env file. For device work,
copy the sample and set your Roku target and Developer Mode password:

```bash
cp .env.example .env
```

Maintainers with the shared encrypted test payload render the test account and
fixtures into `.env.local` with `pnpm roku secrets-setup`; use that account for
device checks so screenshots, navigation, playback, and track selection run
against stable fixtures. [Live Test setup](./live-test/README.md#setup) covers
both paths.

To enable Developer Mode on the device, follow the [Sideloading guide](./docs/sideloading.md#1-enable-developer-mode).

## Run Locally

Check that the Roku developer endpoint is reachable:

```bash
pnpm roku check-roku-dev-target
```

Build and reinstall the app on the configured Roku:

```bash
pnpm sideload
```

`pnpm roku build-dev` and `pnpm roku build-lab` build explicit
[variants](./docs/roku-variants.md); `pnpm roku help --all` lists every task.
[Live Test](./live-test/README.md) covers device checks and the debug loop.

## Checks

Run before opening or updating a pull request:

```bash
pnpm verify
```

`pnpm exec oxfmt "**/*.md"` fixes Markdown formatting failures.

Build the production release ZIP at `dist/apps/putio-roku-v2.zip`:

```bash
pnpm artifact
```

Source conventions and hazards: [AGENTS.md](./AGENTS.md).

## Pull Requests

- Keep changes focused; put unrelated cleanup in its own pull request
- Add or update checks when behavior changes
- Upload proof screenshots or recordings with `gh pr create --attach ./file.png` or `gh pr comment <n> --attach ./file.mp4`; commit only curated `.vref/` references

Merges to `main` release through [Release](./.github/workflows/release.yml); see [Delivery](./AGENTS.md#delivery).
