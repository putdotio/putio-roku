# Contributing

## Setup

Prerequisites: Node.js from `.node-version`, `pnpm`, and (for live harness tasks) the `putio` CLI on `PATH`.

```bash
pnpm install --frozen-lockfile
```

Build-only commands such as `pnpm verify` need no env file. For device work,
copy the sample and set your Roku target and Developer Mode password:

```bash
cp .env.example .env
```

For live harness and device tests, export the test account and fixture variables
in your shell or place them in the gitignored `.env.local` so screenshots,
navigation, playback, and track selection run against stable fixtures.

### Enable Developer Mode

On the Roku remote, press `HOME` three times, then `UP`, `UP`, `RIGHT`, `LEFT`,
`RIGHT`, `LEFT`, `RIGHT`. Enable Developer Mode, set the web installer
password, and note the IP address; the Roku reboots. To install a ZIP by hand,
open that IP in a browser, sign in as `rokudev`, and upload the ZIP unextracted.

## Run Locally

Check that the Roku developer endpoint is reachable:

```bash
pnpm roku check-roku-dev-target
```

Build and reinstall the app on the configured Roku:

```bash
pnpm sideload
```

Install this checkout as put.io Dev, already signed in to the test account:

```bash
pnpm roku harness-install
```

The first run on a host spends one device code and caches the app token in
`~/.cache/putio-roku`; later installs and `pnpm roku live-test-flow-smoke` or
`pnpm roku live-test-flow-full` reuse it. put.io limits device codes per IP. Signing out
in the app keeps the cached token valid.

`pnpm roku help --all` lists every task.

## Checks

Run before opening or updating a pull request:

```bash
pnpm verify
```

Fix formatting failures with `pnpm exec oxfmt "**/*.md" "scripts/**/*.ts"` (Markdown and scripts) or `pnpm exec bsfmt "source/**/*.{brs,bs}" "components/**/*.{brs,bs}"` (BrightScript).

Build the production release ZIP at `dist/apps/putio-roku-v2.zip`:

```bash
pnpm artifact
```

Source conventions and hazards: [AGENTS.md](./AGENTS.md).

## Pull Requests

Upload proof screenshots or recordings with `gh pr create --attach ./file.png` or `gh pr comment <n> --attach ./file.mp4`; never commit them.

Merges to `main` release through [Release](./.github/workflows/release.yml); see [Delivery](./AGENTS.md#delivery).
