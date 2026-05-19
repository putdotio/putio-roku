# Roku Visual Reference

This directory stores curated Roku screenshots for product review, store
submission prep, and design comparison. It is intentionally lighter than a
visual regression suite: raw captures stay in `dist/tmp/`, and only curated
screenshots with stable names are committed here.

## Structure

- `manifest.json` lists the curated screenshots and their capture metadata.
- `screenshots/roku-720p/` contains committed 1280x720 Roku captures.
- `index.html` is the generated gallery for quick review.

## Workflow

Capture a raw screenshot from the current Roku state:

```sh
make visual-capture NAME=<short-screen-name>
```

Rebuild the static gallery:

```sh
make visual-gallery
```

The gallery command delegates to `vref`. Install `@putdotio/vref` as a dev
dependency after the package is published, or set `VREF_BIN` to a local built
CLI while migrating:

```sh
VREF_BIN=/path/to/vref/dist/cli.js make visual-gallery
```

## Rules

- Commit only curated screenshots with stable names.
- Keep timestamped/raw captures under `dist/tmp/`.
- Use synthetic or public-safe filenames and account state.
- Do not commit IP addresses, tokens, device passwords, or private account data.
- Prefer exact Roku screenshots over reconstructed browser mockups.
