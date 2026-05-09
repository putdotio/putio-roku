# Release Workflow

Official Roku sideload releases are semantic-release driven from `main`.

## Public URLs

- Latest released Roku v2 ZIP: `https://roku.put.io/v2.zip`
- Immutable hosted releases: `https://roku.put.io/releases/v2/<version>.zip`
- GitHub Releases attach `putio-roku-v<version>.zip`

`v2.zip` updates only when semantic-release creates a new release. Regular `main` pushes that do not produce a release leave the public ZIP unchanged.

Hosted immutable release ZIPs remain in the bucket after later releases. The SST deploy does not purge prior `releases/v2/` objects.

## Flow

1. Pull requests and `main` pushes run `make verify`
2. The release workflow runs on `main` after verification
3. semantic-release analyzes Conventional Commits
4. When a release is due, `scripts/prepare-release.sh` builds one ZIP and stages it as:
   - `dist/public/v2.zip`
   - `dist/public/releases/v2/<version>.zip`
   - `dist/release/putio-roku-v<version>.zip`
5. The GitHub Release receives the `dist/release` ZIP
6. The production deploy job publishes `dist/public` to `roku.put.io` with SST

## GitHub Configuration

Release job environment: `release`

- `PUTIO_RELEASE_BOT_APP_ID`
- `PUTIO_RELEASE_BOT_PRIVATE_KEY`

Production deploy job environment: `production`

- `AWS_DEPLOY_ROLE_ARN`
- `AWS_REGION`, defaults to `eu-west-1`
- `AWS_ROUTE53_ZONE_ID`
- `AWS_WILDCARD_CERT_ARN`
- `ROKU_DOMAIN`, defaults to `roku.put.io`

Set these as repository variables on `putdotio/putio-roku`.

The AWS role should trust GitHub Actions OIDC only for production deploys from
`putdotio/putio-roku` on `main`
