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

The Roku `manifest` is the source of truth for the checked-in app version; semantic-release publishes matching `v<major>.<minor>.<build>` tags.

- `manifest` owns `major_version`, `minor_version`, and zero-padded `build_version`
- `package.json` uses the derived semantic version, for example `2.8.4`

During a semantic-release run, `scripts/prepare-release.ts <version>` refuses to move the app backward from the manifest version, syncs the manifest and `package.json`, builds the ZIP with `pnpm artifact` (always the production variant, ignoring local development or Lab overrides), and stages the hosted and GitHub Release artifacts. The release bot then commits the version fields back to `main` with `[skip ci]`, so the Git tag, Roku manifest, and package metadata stay aligned.

## Flow

1. Pull requests and `main` pushes run `pnpm verify`
2. The release workflow runs on `main` after verification
3. semantic-release analyzes Conventional Commits
4. When a release is due, `scripts/prepare-release.ts` syncs the version, builds one ZIP, and stages it as:
   - `dist/public/v2.zip`
   - `dist/public/releases/v2/<version>.zip`
   - `dist/release/putio-roku-v<version>.zip`
5. The release bot commits the synced version fields back to `main` and creates
   a draft GitHub Release
6. The workflow resolves the exact tag, uploads the ZIP to that mutable draft,
   verifies the one-asset manifest, and publishes the Release
7. The production deploy job downloads the verified published ZIP, stages it as
   `dist/public/v2.zip` and `dist/public/releases/v2/<version>.zip`, then
   publishes `dist/public` to [roku.put.io](https://roku.put.io/v2.zip) with SST

Release and production deploy jobs run fresh dependency installs with
package-manager caching disabled and no persisted checkout credentials before
publishing artifacts or assuming the AWS deploy role. The GitHub App release token is
minted after the initial install and font preparation; semantic-release receives
it only at the release boundary. Recovery checkouts also leave Git credentials
unpersisted. The deploy handoff uses the GitHub Release asset directly instead
of GitHub Actions artifact storage.

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

Release job environment: `release`

- `PUTIO_RELEASE_BOT_CLIENT_ID`
- `PUTIO_RELEASE_BOT_PRIVATE_KEY`
- `PUTIO_ROKU_SENTRY_DSN` (see [Error reporting](./ROKU_VARIANTS.md#error-reporting))

Production deploy job environment: `production`

- `AWS_DEPLOY_ROLE_ARN`
- `AWS_REGION`
- `AWS_ROUTE53_ZONE_ID`
- `AWS_WILDCARD_CERT_ARN`
- `ROKU_DOMAIN`

Set these as repository variables on [putdotio/putio-roku](https://github.com/putdotio/putio-roku/settings/variables/actions).

The AWS role should trust GitHub Actions OIDC only for production deploys from
`putdotio/putio-roku` on `main`
