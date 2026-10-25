# Font system

Product typography uses **GT America**, the put.io brand typeface from
`@putdotio/design`. Roku's `Font` node takes only TrueType or OpenType, so the
app uses the desktop OTF cuts, not the web `woff2` files. A build without the
faces runs on the Roku system font.

## Licensing boundary

The faces are commercially licensed. This repository must never become a
distribution point:

- Never commit font binaries. `.gitignore` covers them, and `pnpm verify` fails if git tracks one
- Do not subset, convert, rename, or re-host the faces, and do not add them to `@putdotio/design`; `static.put.io` is the single source

`static.put.io` serves the faces without a credential, so anyone can run
`pnpm roku fonts-setup`. The boundary covers the repository tree and history,
not access.

## Changing the faces

Edit [config/brand-fonts.json](../config/brand-fonts.json), then run
`pnpm roku fonts-setup`. `pnpm roku fonts-check` reports the state of `fonts/`
offline. What a valid face is lives in
[sync-brand-fonts.ts](../scripts/sync-brand-fonts.ts), and
[brand-fonts.test.ts](../test/live-test/brand-fonts.test.ts) pins it.

`fonts-check` is not part of `pnpm verify`, which must pass on a clone without
the faces. [CI](../.github/workflows/ci.yml) stays fonts-less on purpose: it
proves the system-font fallback. The [Release](../.github/workflows/release.yml)
workflow runs `fonts-setup` first, so a release fails rather than ship without
GT America.

A build bundles the faces only when every face in the manifest is present and
valid; otherwise it uses the system font for every role and logs
"Packaged without licensed brand fonts". Check for that line before a
screenshot session.

## Type scale

`typographyRoles()` in [Typography.brs](../components/shared/Typography/Typography.brs)
owns the role table, and its header records why each size equals the built-in
it replaces. Components call `applyTypography(node, "<role>")` and never name a
font; a Vitest audit fails on any `font:*SystemFont` literal in a product
component.

To change the scale, edit the role table, redo the measurement, and re-shoot
the story:

```bash
STORY=typography-gt-america pnpm roku lab-screenshot
```

- Keep every size a multiple of the 3px `uiScaleGrid()` from `UiMetrics.brs`, so it stays whole-pixel at 720p
- The character-count wrap budgets in `AppDialog`, `DeleteFileDialog` and `ContinueWatchingPrompt` match the system font. Raising them is a behavior change that needs its own measurement; GT America digits run wider, so there is no margin to spend

## Glyph coverage

GT America Standard covers Latin, accented Latin, and Turkish (dotted `İ` and
dotless `ı` through `locl`). It has no Greek, Cyrillic, Hebrew, Arabic, Thai,
CJK, Hangul, emoji, or symbols such as `✓`, `★`, or `▶`. Interface symbols come
from the [Icon system](./icons.md); do not use symbol characters as text.

Roku does not fall back per glyph, so missing characters render as boxes. The
system font has the same gaps for non-Latin file names; readable non-Latin
names need a separate coverage face.

Figures are proportional, so text whose digits change in place (clocks,
counters, progress) needs a fixed-width container or a measured layout.
