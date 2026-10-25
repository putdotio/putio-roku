# Roku Visual Reference

Curated Roku screenshots for product review, store submission prep, and design
comparison. This is not a visual regression suite: raw captures stay in
`dist/tmp/`, and only curated screenshots with stable names are committed here.
[manifest.json](./manifest.json) lists them; `index.html` is generated.

Each release publishes this gallery to [roku.put.io/vref](https://roku.put.io/vref/).
The site never purges, so a removed or renamed screenshot stays at its old URL,
and public git history keeps it too. Keep unsafe captures out; do not plan to
remove them later.

## Rules

- Commit only curated screenshots with stable names; raw and timestamped captures stay under `dist/tmp/`
- Use synthetic or public-safe file names and account state
- Never commit IP addresses, tokens, device passwords, or private account data
- Prefer exact Roku screenshots over reconstructed browser mockups
- Capture with the brand faces bundled: run `pnpm roku fonts-setup` first and confirm the build did not log "Packaged without licensed brand fonts". `visual-validate` checks the manifest and files, never pixels, so entries carry a `gt-america` tag to make a fonts-less batch visible.

## Workflow

Capture the current Roku screen:

```sh
NAME=<short-screen-name> pnpm roku visual-capture
```

Capture the stable AppDialog Lab stories (rebuilds with `ROKU_VARIANT=lab`):

```sh
pnpm roku visual-capture-lab
```

Capture the main app pages, plus the image viewer when you pass an image fixture:

```sh
IMAGE_CONTENT_ID=<image-file-id> pnpm roku visual-capture-pages
```

Commit a raw capture as a curated reference:

```sh
pnpm exec vref screenshot add dist/tmp/visual/captures/<stamp>/<name>.jpg \
  --quality 90 \
  --json '{"id":"<name>","title":"<Title>","group":"Main pages","platform":"Roku","device":"Roku 720p","file":"screenshots/roku-720p/<name>.webp","tags":["gt-america"],"notes":["<what the screen shows>"]}'
```

`vref` reads size, viewport, and capture time from the image. Add `--dry-run`
to preview the entry, and `--force` to replace an existing reference. Keep
`--quality 90`: the device emits JPEG, so lossless WebP only preserves JPEG
artifacts at about twice the bytes.

Rebuild the gallery, or validate the manifest and files without rewriting it:

```sh
pnpm roku visual-gallery
pnpm roku visual-validate
```
