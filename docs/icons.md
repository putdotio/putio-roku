# Icon system

Interface glyphs use [Phosphor Icons](https://github.com/phosphor-icons/core),
like the put.io design system and the iOS and web apps. The app pins the
package, generates monochrome PNG templates offline, and tints them at runtime,
so builds never need the network.

## Visual contract

put.io's TV identity is yellow-forward, like the Android TV app. Glyphs are
white 128×128 templates tinted at runtime; do not bake color into the assets.

- Browse, navigation, settings, and file-type glyphs are brand yellow (`primary`)
- Filled, active, and transport glyphs (folder, play, pause, active captions) use the `fill` weight
- History states keep their meaning: complete and warning are `primary`, errors are `danger`, incidental events are `textMuted`
- The watched-eye badge is `textMuted`
- Player transport glyphs stay white on the dark video overlay; the audio player tints the focused control `primary`
- Brand artwork, channel posters, splash art, loaders, and focus art stay outside the icon set

Tint a `Poster` through `setDialogNodeColor(node, "<token>")` or
`designTokenColor(...)`, never a raw color. List rows take an `iconColor` field
(default `primary`) from
[ListItemData.xml](../components/shared/ListItem/ListItemData.xml). Icon posters
set `loadDisplayMode="scaleToFit"` so the 128px source scales to any control
size.

## Updating icons

1. Edit [config/phosphor-icons.json](../config/phosphor-icons.json). Each entry maps a Roku `asset` name (`images/icons/<asset>.png`) to a Phosphor `name` and `weight`
2. To change the pinned version, set `@phosphor-icons/core` in `package.json` to the same exact version and run `pnpm install`
3. Run `pnpm roku icons` to regenerate `images/icons/` and the license in `third-party/phosphor-icons/`
4. Reference new assets as `pkg:/images/icons/<asset>.png`
5. Run `pnpm verify` and recapture affected [visual references](../.vref/README.md)

`pnpm verify` regenerates the icons and fails when the committed PNGs, pinned
version, or license drift from the manifest. Never hand-edit
`images/icons/*.png`; the generator prunes anything not in the manifest.
