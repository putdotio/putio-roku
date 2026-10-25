# Distribution

[Release](../.github/workflows/release.yml) runs semantic-release on every push
to `main`. Releasing commit types are in [AGENTS.md](../AGENTS.md#delivery).

## Public URLs

- Latest ZIP: [roku.put.io/v2.zip](https://roku.put.io/v2.zip)
- Immutable ZIPs: `https://roku.put.io/releases/v2/<version>.zip`, for example [2.8.4](https://roku.put.io/releases/v2/2.8.4.zip)
- GitHub Release asset: `putio-roku-v<version>.zip`, for example [putio-roku-v2.8.4.zip](https://github.com/putdotio/putio-roku/releases/download/v2.8.4/putio-roku-v2.8.4.zip)

`v2.zip` changes only after a verified GitHub Release is published. The deploy
handoff is that Release asset, not Actions artifact storage. Old
`releases/v2/` objects are never purged.

## Versioning

The Roku `manifest` owns the app version (`major_version`, `minor_version`,
zero-padded `build_version`). [prepare-release.ts](../scripts/prepare-release.ts)
syncs `package.json` to it and refuses to move the version backward.

## Recover

Run the release workflow from `main` with the exact existing tag. Recovery
checks that the tag belongs to `main`, then resumes its draft or production
deploy. An already-published Release is validated but never changed. A missing
Release fails the run.

## GitHub Configuration

[release.yml](../.github/workflows/release.yml) names every input. The release
bot's client ID (variable) and private key (secret) live in the `release`
Environment. `PUTIO_ROKU_SENTRY_DSN` (see
[Error reporting](./roku-variants.md#error-reporting)) and the AWS deploy inputs
are repository variables.

The AWS role must trust GitHub Actions OIDC only for production deploys from
`putdotio/putio-roku` on `main`.
