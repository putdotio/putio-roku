# Contributing

Thanks for contributing to `putio-roku`

## Setup

Prerequisites:

- Node.js from `.node-version`
- `pnpm`

Optional local overrides live in `.env` or `.env.local`. If a maintainer gave
you access to the shared encrypted test payload, render it first:

```bash
PUTIO_ROKU_SOPS_FILE=/path/to/roku.sops.env pnpm roku secrets-setup
```

That writes an ignored mode-`0600` `.env.local` with the shared put.io test
account, OAuth fields, Roku Developer Mode password, and live-test fixture IDs.
Keep using that same account for hardware-backed Roku checks so screenshots,
file navigation, playback, and track-selection flows exercise stable fixtures.

If you are using your own local device or credentials, copy the sample file:

```bash
cp .env.example .env
```

Then fill in the device and fixture values you have locally. Keep the device IP
in `.env`; rerunning `secrets-setup` replaces `.env.local`. The variables each
check needs are listed in [Live Test setup](./live-test/README.md#setup).

If you need help enabling Developer Mode on the device itself, use the [Sideloading guide](./docs/SIDELOADING.md)

Install the Node-based Roku toolchain:

```bash
pnpm install --frozen-lockfile
```

## Run Locally

Check that the Roku developer endpoint is reachable:

```bash
pnpm roku check-roku-dev-target
```

Build and reinstall the app on the configured Roku device:

```bash
pnpm sideload
```

`pnpm sideload` removes the previously installed developer app, builds a fresh ZIP, validates the target, and reinstalls the app. `pnpm roku build-dev` and `pnpm roku build-lab` build explicit variants; `pnpm roku help` lists every helper task.

See [Live Test](./live-test/README.md) for hardware-backed checks and the
debug loop, and [Roku variants and Lab](./docs/ROKU_VARIANTS.md) for the
development/Lab packaging split and the Roku-specific design asset adapter.

## Validation

Run the standard repo verification before opening or updating a pull request:

```bash
pnpm verify
```

Build the release-style ZIP used by automation:

```bash
pnpm artifact
```

`pnpm artifact` always rebuilds the production variant before writing
`dist/apps/putio-roku-v2.zip`. `pnpm verify` type-checks the live-test
harness, checks Roku source formatting, runs Roku static checks, and creates a
fresh app ZIP for the selected variant.

## Development Notes

- Source conventions, layout grid, icon and font pipelines, and secret boundaries: [Rules](./AGENTS.md#rules) and [Build And Config](./AGENTS.md#build-and-config) in `AGENTS.md`
- Reserve source comments for device quirks, invariants, and external constraints the code cannot express, such as a Roku model's HLS behavior or a put.io API field's meaning. Do not add `''' Section` banners, restate the function name below them, or leave commented-out debug code; name a value instead of annotating a magic number
- Prefer repo-relative doc links when adding or updating documentation

## Pull Requests

- Keep changes focused and explicit
- Add or update validation when behavior changes
- Prefer small follow-up pull requests over mixing unrelated cleanup into the same branch
- Upload proof screenshots or recordings with `gh pr create --attach ./file.png` or `gh pr comment <n> --attach ./file.mp4`; only curated `.vref/` references are committed

## CI And Delivery

[CI](https://github.com/putdotio/putio-roku/actions/workflows/ci.yml) runs `pnpm verify` on pull requests and pushes to `main`. Release publishing, versioning, and recovery are in [Release workflow](./docs/RELEASE.md)
