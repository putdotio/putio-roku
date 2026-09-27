# Release Workflow

Official Roku sideload releases are semantic-release driven from `main`.

## Public URLs

- Latest released Roku v2 ZIP: [roku.put.io/v2.zip](https://roku.put.io/v2.zip)
- Immutable hosted releases: `https://roku.put.io/releases/v2/<version>.zip`, for example [2.8.4](https://roku.put.io/releases/v2/2.8.4.zip)
- GitHub Releases attach `putio-roku-v<version>.zip`, for example [putio-roku-v2.8.4.zip](https://github.com/putdotio/putio-roku/releases/download/v2.8.4/putio-roku-v2.8.4.zip)

`v2.zip` updates only from a verified published GitHub Release. Regular `main`
pushes that do not produce a release leave the public ZIP unchanged. Hosted
immutable release ZIPs remain in the bucket after later releases; the SST deploy
does not purge prior `releases/v2/` objects.

## Versioning

The Roku `manifest` owns the checked-in app version (`major_version`,
`minor_version`, zero-padded `build_version`); semantic-release publishes the
matching `v<major>.<minor>.<build>` tag, and `package.json` carries the derived
semantic version, for example `2.8.4`.

## Flow

1. Pull requests run `pnpm verify` in CI; `main` pushes run it in the release workflow
2. semantic-release analyzes Conventional Commits
3. When a release is due, [scripts/prepare-release.ts](../scripts/prepare-release.ts)
   refuses to move the version backward, syncs `manifest` and `package.json`,
   builds the production ZIP with `pnpm artifact` (ignoring local development or
   Lab overrides), and stages it for hosting and the GitHub Release
4. The release bot commits the synced version fields back to `main` with
   `[skip ci]` and creates a draft GitHub Release
5. The workflow resolves the exact tag, uploads the ZIP to that mutable draft,
   verifies the one-asset manifest, and publishes the Release
6. The production deploy job downloads the verified published ZIP, stages it as
   `dist/public/v2.zip` and `dist/public/releases/v2/<version>.zip` beside the
   [`.vref` gallery](../.vref/README.md), then publishes `dist/public` to
   [roku.put.io](https://roku.put.io/v2.zip) with SST

Release and deploy jobs install fresh without package-manager caching or
persisted checkout credentials. The GitHub App release token is minted after
install and font sync and reaches semantic-release only at the release step.
The deploy handoff is the GitHub Release asset, not GitHub Actions artifact
storage.

## Recover

Run the release workflow from `main` with the exact existing tag. Recovery
validates that the stable tag belongs to `main`, checks out that tag, and resumes
its draft or production deploy. A draft rebuilds its ZIP only when needed and is
published after exact asset validation. When the tag contains the brand-font
manifest, recovery syncs and validates the licensed faces before rebuilding;
older tags without that manifest keep their original font behavior. An
already-published Release is validated but never mutated. An unavailable
expected Release fails closed.

## GitHub Configuration

[release.yml](../.github/workflows/release.yml) names every input. The release
bot's client ID (variable) and private key (secret) live in the `release`
Environment. `PUTIO_ROKU_SENTRY_DSN` (see
[Error reporting](./ROKU_VARIANTS.md#error-reporting)) and the AWS deploy
inputs used by the `production` deploy job are repository variables.

The AWS role should trust GitHub Actions OIDC only for production deploys from
`putdotio/putio-roku` on `main`.
