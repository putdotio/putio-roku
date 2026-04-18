# Contributing

Thanks for contributing to `putio-roku`.

## Setup

- Prerequisites:
  - `make`
  - `zip`
  - `curl`
- Optional local overrides:
  - copy `.env.example` to `.env`
  - set `ROKU_DEV_TARGET` when you want to sideload to a developer-enabled Roku device
  - set `ROKU_DEV_PASSWORD` when your device requires authenticated installs

## Run Locally

- Build and install the app on a configured Roku developer device:

```bash
cp .env.example .env
make run
```

- Verify device connectivity without reinstalling:

```bash
make check-roku-dev-target
```

## Validation

- Run the repo-local verification command before opening or updating a pull request:

```bash
make verify
```

- Build the release-style zip used by delivery automation:

```bash
make artifact
```

## CI And Delivery

- `.github/workflows/ci.yml`
  - runs `make verify` on pull requests and default-branch pushes
- `.github/workflows/deploy.yml`
  - verifies first
  - builds `dist/apps/putio-roku-v2.zip`
  - uploads the artifact to GitHub Actions and the existing distribution bucket on default-branch pushes

## Development Notes

- Keep repo-stored defaults open-source-safe
- Do not commit real device addresses, passwords, signing keys, or private release notes
- `make verify` always builds a fresh zip
- `make check` also runs the BrightScript desktop checker when the local Roku toolchain is available

## Pull Requests

- Keep changes focused and explicit
- Add or update validation when behavior changes
- Update docs when setup, CI, or delivery expectations change
- Prefer follow-up pull requests over mixing unrelated cleanup into the same branch
