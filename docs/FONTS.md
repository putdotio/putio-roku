# Font system

Product typography uses **GT America**, the put.io brand typeface from the public design
system (`@putdotio/design` sets `typography.fontFamily.sans` to it), matching the web and
iOS apps. The faces are commercially licensed, so unlike icons they are not checked in: the
Roku app fetches them from put.io's own CDN at development and release time, and falls back
to the Roku system font when they are absent.

Roku's `Font` node accepts TrueType/OpenType only. The `woff2` files the web surfaces load
will not work here — the Roku app uses the desktop OTF cuts.

## Licensing boundary

The faces are licensed for use in the app. The rule this repo enforces is that **this
repository never becomes a distribution point**:

- Font binaries are never committed. `.gitignore` covers `/fonts/*.otf`, `/fonts/*.ttf` and
  `/fonts/*.ttc`, and `pnpm verify` fails outright if `git ls-files` ever reports one
- Nothing lands in git history and nothing is search-indexable from here
- The built app bundles them, as does the CDN that already serves the family to the web
  surfaces; that is inherent to shipping a typeface
- Do not subset, convert, rename, or re-host the faces, and do not add them to
  `@putdotio/design` — `static.put.io` is the single source

Note what this boundary does **not** claim. `static.put.io` serves the faces over plain
HTTPS with no credential, so anyone who can read this repo can also run
`pnpm roku fonts-setup` and obtain them. That is unchanged by anything here — the same CDN
already serves the family to every web surface — and it is the reason the rule is scoped to
git rather than to access. What the repo controls is that the binaries are not in its tree,
its history, or its packages.

A clone without the faces is a fully working development setup. Every check in
`pnpm verify` passes without them, and the app renders in the Roku system font.

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
  credential and no tooling beyond Node — just network access to `static.put.io`. Each
  download is validated **before** writing, the whole set is staged under the gitignored
  `dist/tmp` so the moves into `fonts/` are same-filesystem renames and an interrupted sync
  cannot leave a mixed set, and any face `fonts/` holds that the manifest does not list is
  pruned
- `pnpm roku fonts-check` is offline and reports the state of `fonts/`

Validation is what replaced digest pinning, and it is deliberately about *usability* rather
than tamper-resistance — the bytes come from put.io's own CDN over TLS. A face is accepted
only when it is a single OpenType/TrueType face (not a `.ttc` collection), every table in
its directory lies inside the file, the tables Roku needs to render are present, and its
name table declares the expected family. That covers the failure modes a CDN actually
produces: a `200` carrying an error page, a half-finished download, or the wrong typeface
under the right filename. The truncation case is the one worth naming — a partial file often
keeps its name table intact, so the family reads fine while the outlines are gone, and only
the table-bounds check catches it.

`fonts-check` treats absent faces as a legitimate optional state and succeeds. It fails when
a present face does not validate, or when `fonts/` holds a face the manifest does not list —
either would ship bytes nothing has checked. It is deliberately **not** part of
`pnpm verify`, because `pnpm verify` must pass on a fonts-less clone.

To change the faces, edit `config/brand-fonts.json` and run `pnpm roku fonts-setup`. A
Vitest contract test (`test/live-test/brand-fonts.test.ts`) validates the manifest, exercises
the validator against error pages, truncation and wrong families, enforces the ignore rules,
and asserts components only reference faces the manifest lists.

## Packaging and fallback

`scripts/package-roku.ts` bundles the **manifest-listed faces individually**, and only when
every one of them is present *and validates*. It compiles the same answer into the generated
`source/BuildConfig.brs` as `buildConfigBrandFontsAvailable()`.

Two properties matter here. Package roots are copied recursively, so bundling the `fonts/`
directory would ship whatever else happened to be inside it — a nested
`fonts/backup/unlicensed.otf`, say — while only the listed faces had been validated; listing
the files makes what ships exactly what was checked. And availability is
all-or-nothing, because a partial or corrupt set would flip the flag on while individual
roles resolved to missing `pkg:/fonts/...` URIs, which Roku renders in the system font per
label and shows as mixed typography. The runtime reads the flag rather than probing the
filesystem, so a build either has the complete verified set or deliberately uses the
built-in `font:*SystemFont` values.

Any build packaged without the faces logs a line saying so, so a sideload or a screenshot
session cannot quietly capture the wrong typeface.

`.worktreeinclude` carries `/fonts` into agent worktrees so they inherit synced faces
instead of silently falling back.

## Release builds

The [Release](../.github/workflows/release.yml) workflow runs `pnpm roku fonts-setup` before
semantic-release builds the artifact and before reconstructing a font-enabled draft during
release recovery, so the published `v2.zip` ships GT America. Recovery skips this step for
older tags that have no brand-font manifest. No credential or token is involved — the faces
come from `static.put.io` over plain HTTPS. `fonts-setup` fails the release on any download
or validation problem, so reaching the build means every listed face is on disk and is a
real GT America face.

[CI](../.github/workflows/ci.yml) is verify-only and stays deliberately fonts-less: it is
the standing proof that the system-font fallback still works.

## Type scale

`components/shared/Typography/Typography.brs` owns the Roku type scale. Components never
name a font directly: they call `applyTypography(node, "<role>")` next to their existing
`setDialogNodeColor` calls, and a Vitest audit fails the build if a `font:*SystemFont`
literal reappears in a product component.

| Role | Size | Weight | Replaces | Used by |
|---|---|---|---|---|
| `h1` | 45 | bold | `font:LargeBoldSystemFont` | screen and dialog titles, empty-state heading, pairing code |
| `h2` | 36 | medium | `font:MediumBoldSystemFont` | list-item titles, button labels, player time |
| `body` | 36 | regular | `font:MediumSystemFont` | dialog body, track menu rows, empty-state body |
| `small` | 33 | regular | `font:SmallSystemFont` | captions, file names, focus tooltips |
| `label` | 33 | medium | `font:SmallBoldSystemFont` | player skip badges |
| `caption` | 27 | regular | `font:SmallestSystemFont` | list-item descriptions |

Sizes are authored in FHD and are **identical to the built-in each role replaces**. That is
a measurement, not a coincidence: the Lab story `typography-gt-america` renders every role
in the built-in beside GT America at the same size and one and two 3px grid steps up, and
GT America lands within a few percent of the built-in at matching size (94-95% on
cap-height strings, 105-107% on digits). One step up measured 6-9% oversized. Keeping the
sizes fixed means every Label height, character-count wrap budget and list-row baseline
stays valid, so the brand face is a drop-in.

The character-count wrapping in `AppDialog`, `DeleteFileDialog` and
`ContinueWatchingPrompt` is left exactly as it was, deliberately: the budgets are counted in
characters, so wrap and truncation points are identical to the system font and the migration
cannot change where a string breaks. Raising them would be a behaviour change needing its
own measurement — note that while GT America is narrower on average, its digits measure
105-107%, so a digit-heavy file name is *wider* than the system font rendered it and there
is no blanket safety margin to spend.

To change the scale, edit the role table and re-shoot the Lab story:

```bash
STORY=typography-gt-america pnpm roku lab-screenshot
```

Roku does not publish its built-in font sizes, so that story is the only source of truth
for what a role is being compared against. Keep every size a multiple of the 3px
`uiScaleGrid()` from `UiMetrics.brs` so it stays whole-pixel when FHD is downscaled to 720p.

## Glyph coverage

GT America Standard carries **523 codepoints**: Latin, Turkish (including the dotted `İ` and
dotless `ı` via its `locl` forms), and accented Latin. It has no Greek, Cyrillic, Hebrew,
Arabic, Thai, CJK, Hiragana, Katakana, Hangul or emoji, and no symbol glyphs — notably no
`✓` (U+2713), `✔`, `★`, or `▶`. Interface symbols come from the Phosphor icon set instead
(see [Icon system](./ICONS.md)); do not reintroduce symbol characters as text.

File names are user content and are frequently not Latin, so be clear about what happens
there. Roku's `Font` node does not fall back per glyph, so a character the face lacks renders
as a placeholder box rather than as text. **This is not specific to the brand face**: the
`typography-gt-america` Lab story renders Cyrillic and Japanese file names in both faces
side by side, and the Roku system font shows hollow placeholder boxes for exactly the same
characters where GT America shows crosshatched ones. Non-Latin file names were unreadable on
this device before the migration and are equally unreadable after it — the brand face neither
causes nor fixes that. Serving those names properly would need a coverage-adequate face for
user content, which is a separate piece of work; the Lab row exists so the state is visible
rather than assumed.

Its figures are proportional, and unevenly so (`1` is about 60% the width of `0`), so text
whose digits change in place — clocks, counters, progress — needs a fixed-width container
or a measured layout rather than one that reflows per digit.
