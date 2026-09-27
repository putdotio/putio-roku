# Font system

Product typography uses **GT America**, the put.io brand typeface from the public design
system (`@putdotio/design` sets `typography.fontFamily.sans` to it), matching the web and
iOS apps. The faces are commercially licensed, so unlike icons they are not checked in: the
Roku app fetches them from put.io's own CDN at development and release time, and falls back
to the Roku system font when they are absent.

Roku's `Font` node accepts TrueType/OpenType only. The `woff2` files the web surfaces load
will not work here; the Roku app uses the desktop OTF cuts.

## Licensing boundary

The faces are licensed for use in the app. The rule this repo enforces is that **this
repository never becomes a distribution point**:

- Font binaries are never committed. `.gitignore` covers `/fonts/*.otf`, `/fonts/*.ttf` and
  `/fonts/*.ttc`, and `pnpm verify` fails outright if `git ls-files` ever reports one
- Nothing lands in git history and nothing is search-indexable from here
- The built app bundles them, as does the CDN that already serves the family to the web
  surfaces; that is inherent to shipping a typeface
- Do not subset, convert, rename, or re-host the faces, and do not add them to
  `@putdotio/design`; `static.put.io` is the single source

The boundary is scoped to git, not access: `static.put.io` already serves the faces to
every web surface over plain HTTPS with no credential, so anyone can run
`pnpm roku fonts-setup`. What the repo controls is that the binaries are not in its tree,
its history, or its packages.

## Syncing the faces

`config/brand-fonts.json` names the CDN directory, the expected family, and the faces to
fetch:

```json
{
  "baseUrl": "https://static.put.io/fonts/gt-america/desktop/otf",
  "family": "GT America",
  "files": ["gt-america-standard-regular.otf"]
}
```

- `pnpm roku fonts-setup` fetches every missing or invalid face into `fonts/`. It needs no
  credential and no tooling beyond Node, just network access to `static.put.io`. Each
  download is validated **before** writing, the whole set is staged under the gitignored
  `dist/tmp` so the moves into `fonts/` are same-filesystem renames and an interrupted sync
  cannot leave a mixed set, and any face `fonts/` holds that the manifest does not list is
  pruned
- `pnpm roku fonts-check` is offline and reports the state of `fonts/`

Validation checks *usability*, not tamper-resistance; the bytes come from put.io's own CDN
over TLS. A face is accepted
only when it is a single OpenType/TrueType face (not a `.ttc` collection), every table in
its directory lies inside the file, the tables Roku needs to render are present, and its
name table declares the expected family. That covers the failure modes a CDN actually
produces: a `200` carrying an error page, a half-finished download, or the wrong typeface
under the right filename. A truncated file often keeps its name table intact, so only the
table-bounds check catches it.

`fonts-check` treats absent faces as a legitimate optional state and succeeds. It fails when
a present face does not validate, or when `fonts/` holds a face the manifest does not list;
either would ship bytes nothing has checked. It is **not** part of `pnpm verify`, which must
pass on a fonts-less clone: that clone is a working development setup on the Roku system
font.

To change the faces, edit `config/brand-fonts.json` and run `pnpm roku fonts-setup`.
[brand-fonts.test.ts](../test/live-test/brand-fonts.test.ts) covers the manifest, the
validator failure modes, the ignore rules, and component face references.

## Packaging and fallback

`scripts/package-roku.ts` bundles the **manifest-listed faces individually**, and only when
every one of them is present *and validates*. It compiles the same answer into the generated
`source/BuildConfig.brs` as `buildConfigBrandFontsAvailable()`.

Listing files rather than bundling `fonts/` matters because package roots are copied
recursively: a stray `fonts/backup/unlicensed.otf` would ship unvalidated. Availability is
all-or-nothing because a partial set would flip the flag on while some roles resolved to
missing `pkg:/fonts/...` URIs, which Roku renders per label in the system font as mixed
typography. The runtime reads the flag rather than probing the filesystem, so a build
either has the complete verified set or uses the built-in `font:*SystemFont` values.

Any build packaged without the faces logs a line saying so, so a sideload or a screenshot
session cannot quietly capture the wrong typeface.

`.worktreeinclude` carries `/fonts` into agent worktrees so they inherit synced faces
instead of silently falling back.

## Release builds

The [Release](../.github/workflows/release.yml) workflow runs `pnpm roku fonts-setup` before
semantic-release builds the artifact and before rebuilding a font-enabled draft during
recovery (older tags without a brand-font manifest skip it). `fonts-setup` fails the release
on any download or validation problem, so a release from a tag with the brand-font manifest
always ships GT America. Recovering an older tag republishes its original system-font build.

[CI](../.github/workflows/ci.yml) stays fonts-less on purpose: it is the standing proof that
the system-font fallback still works.

## Type scale

`typographyRoles()` in [Typography.brs](../components/shared/Typography/Typography.brs) owns
the role table: size, weight, and the built-in each role replaces. Components never name a
font directly: they call `applyTypography(node, "<role>")` next to their
`setDialogNodeColor` calls, and a Vitest audit fails the build if a `font:*SystemFont`
literal reappears in a product component.

Each role's FHD size equals the built-in it replaces, so every Label height,
character-count wrap budget, and list-row baseline stays valid; the header comment in
`Typography.brs` records the measurement behind that. Roku does not publish its built-in
font sizes, so the Lab story `typography-gt-america` is the only reference. To change the
scale, edit the role table, redo the measurement, and re-shoot the story:

```bash
STORY=typography-gt-america pnpm roku lab-screenshot
```

Keep every size a multiple of the 3px `uiScaleGrid()` from `UiMetrics.brs` so it stays
whole-pixel when FHD is downscaled to 720p.

The character-count wrapping in `AppDialog`, `DeleteFileDialog` and
`ContinueWatchingPrompt` is unchanged from the system font, so wrap and truncation points
match it exactly. Raising those budgets is a behavior change that needs its own
measurement. GT America digits measure 105-107% of the system font, so a digit-heavy file
name is *wider* than before and there is no blanket margin to spend.

## Glyph coverage

GT America Standard carries **523 codepoints**: Latin, Turkish (including the dotted `İ` and
dotless `ı` via its `locl` forms), and accented Latin. It has no Greek, Cyrillic, Hebrew,
Arabic, Thai, CJK, Hiragana, Katakana, Hangul or emoji, and no symbol glyphs, notably no
`✓` (U+2713), `✔`, `★`, or `▶`. Interface symbols come from the Phosphor icon set instead
(see [Icon system](./ICONS.md)); do not reintroduce symbol characters as text.

Roku's `Font` node does not fall back per glyph, so a character the face lacks renders as
a placeholder box. File names are user content and often not Latin, but **this is not
specific to the brand face**: the `typography-gt-america` Lab story renders Cyrillic and
Japanese file names in both faces, and the system font shows placeholder boxes for exactly
the same characters. Readable non-Latin names need a coverage-adequate face for user
content, which is separate work.

Its figures are proportional, and unevenly so (`1` is about 60% the width of `0`), so text
whose digits change in place (clocks, counters, progress) needs a fixed-width container
or a measured layout rather than one that reflows per digit.
