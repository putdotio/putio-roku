# Icon system

Product interface glyphs use [Phosphor Icons](https://github.com/phosphor-icons/core),
matching the public put.io design system and the iOS and web apps. The Roku app pins the
upstream package, generates a selected set of monochrome PNG "templates" offline, and
tints them at runtime, so builds never depend on the network.

## Visual contract

put.io's TV identity is yellow-forward, matching the Android TV app and the design
system's "folder/file emphasis" yellow. Glyphs are white 128×128 templates recolored at
runtime — do not bake color into the assets.

- Browse, navigation, settings, and file-type glyphs are brand-yellow (`primary`)
- Use fill weight for filled/active/transport glyphs (folder, play, pause, active captions)
- Semantic history states keep their meaning: complete and warning events are `primary`
  (yellow), errors are `danger` (red), incidental events are muted (`textMuted`)
- The watched-eye badge is muted (`textMuted`)
- Player transport glyphs render white on the dark video overlay (untinted); the audio
  player tints the focused control `primary`
- Do not replace brand artwork, channel posters, splash art, loaders, or focus art with
  Phosphor glyphs — those stay outside this system

SceneGraph `Poster` nodes recolor the white templates with `blendColor`, sourced from
design tokens through `setDialogNodeColor(node, "<token>")` / `designTokenColor(...)`.
Generic list rows carry an `iconColor` field (`components/shared/ListItem/ListItemData.xml`,
default `primary`). Poster nodes that display an icon set `loadDisplayMode="scaleToFit"` so
the shared 128px source scales crisply to any control size (22–128px).

## Updating icons

`config/phosphor-icons.json` pins the upstream package version and lists the selected icons.
Each entry maps a Roku **`asset`** name (the generated `images/icons/<asset>.png` filename,
referenced from BrightScript/XML) to a Phosphor **`name`** and **`weight`** (`regular` or
`fill`):

```json
{ "asset": "file-folder", "name": "folder", "weight": "fill" }
```

1. Edit the selected icon list in `config/phosphor-icons.json`
2. If changing the pinned version, bump `@phosphor-icons/core` in `package.json` to the
   exact same version and run `pnpm install`
3. Run `pnpm roku icons` to regenerate `images/icons/` and refresh the checked-in license
4. Reference new assets from components as `pkg:/images/icons/<asset>.png`
5. Run `pnpm verify` and recapture affected visual references (see below)

`pnpm roku check-roku-icons` is offline and part of `pnpm verify`. It regenerates the icons
from the manifest and fails when the committed PNGs, the pinned version, or the checked-in
license drift from `config/phosphor-icons.json`. Do not hand-edit the generated
`images/icons/*.png` files — the generator prunes anything not in the manifest.

The generator (`scripts/generate-roku-icons.ts`) reads SVGs from the pinned
`@phosphor-icons/core` package, forces `currentColor` to white, and rasterizes to PNG with
`@resvg/resvg-js`. A Vitest contract test (`test/live-test/roku-icons.test.ts`) validates the
manifest, keeps it in lockstep with `package.json`, and asserts components only reference
generated assets.

Phosphor Icons is distributed under the MIT license, checked in at
`third-party/phosphor-icons/LICENSE`.
