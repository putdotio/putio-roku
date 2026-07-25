# Font system

Product typography uses **GT America**, the put.io brand typeface from the public design
system (`@putdotio/design` sets `typography.fontFamily.sans` to it), matching the web and
iOS apps. The faces are commercially licensed, so unlike icons they are not checked in:
the Roku app pins them by digest, syncs them from the private `putdotio/putio-static` repo
at development and release time, and falls back to the Roku system font when they are
absent.

Roku's `Font` node accepts TrueType/OpenType only. The `woff2` files the web surfaces load
will not work here — the Roku app uses the OTF cuts from `putio-static`.

## Licensing boundary

The faces are licensed for use in the app. The rule this repo enforces is that **the
repository never becomes a distribution point**:

- Font binaries are never committed. `.gitignore` covers `/fonts/*.otf`, `/fonts/*.ttf` and
  `/fonts/*.ttc`, and `pnpm verify` fails outright if `git ls-files` ever reports one
- Nothing lands in git history, nothing is search-indexable, and contributors and CI
  clones never receive the faces
- The built app bundles them, as does the CDN that already serves the family to the web
  surfaces; that is inherent to shipping a typeface
- Do not subset, rename, convert, or re-host the faces, and do not add them to
  `@putdotio/design` — `putio-static` is the single source

A clone without the faces is a fully working development setup. Every check in
`pnpm verify` passes without them, and the app renders in the Roku system font.

## Syncing the faces

`config/brand-fonts.json` pins the source repository, the exact commit, and a sha256 digest
per face. Each entry maps a destination file name in `fonts/` to its upstream path:

```json
{
  "name": "gt-america-standard-regular.otf",
  "path": "public/fonts/gt-america/desktop/otf/gt-america-standard-regular.otf",
  "sha256": "6b1eb2a461e5c827ac615bc8aca268ec6b67250d61fc87f100671aca3db82515"
}
```

- `pnpm roku fonts-setup` fetches every missing or changed face into `fonts/`. It needs the
  GitHub CLI authenticated as an account that can read `putdotio/putio-static`
  (`gh auth login`, or `GH_TOKEN` in CI), verifies each download against its pinned digest
  **before** writing, stages the whole set under the gitignored `dist/tmp` so the moves into
  `fonts/` are same-filesystem renames and an interrupted sync cannot leave a mixed set, and
  prunes any face `fonts/` holds that the manifest does not list
- `pnpm roku fonts-check` is offline and reports the state of `fonts/`

`fonts-check` treats absent faces as a legitimate optional state and succeeds. It fails
when a face is present but does not match its pinned digest, or when `fonts/` holds a face
the manifest does not list — either would ship unverified bytes. It is deliberately **not**
part of `pnpm verify`, because `pnpm verify` must pass on a fonts-less clone.

To change the pinned faces, update `config/brand-fonts.json` with the new commit, upstream
paths, and digests, then run `pnpm roku fonts-setup`. A Vitest contract test
(`test/live-test/brand-fonts.test.ts`) validates the manifest, enforces the ignore rules,
and asserts components only reference faces the manifest pins.

## Packaging and fallback

`scripts/package-roku.ts` bundles the **manifest-listed faces individually**, and only when
every one of them is present *and matches its digest*. It compiles the same answer into the
generated `source/BuildConfig.brs` as `buildConfigBrandFontsAvailable()`.

Two properties matter here. Package roots are copied recursively, so bundling the `fonts/`
directory would ship whatever else happened to be inside it — a nested
`fonts/backup/unlicensed.otf`, say — while only the pinned faces had been digest-checked;
listing the files makes what ships exactly what was verified. And availability is
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

The [Release](../.github/workflows/release.yml) workflow mints a `putio-static`
contents:read token and runs `pnpm roku fonts-setup` before semantic-release builds the
artifact, so the published `v2.zip` ships GT America. `fonts-setup` fails the release on any
download or digest problem, so reaching the build means every pinned face is on disk.

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

GT America Standard covers Latin, Turkish (including the dotted `İ` and dotless `ı` via its
`locl` forms), and the accented Latin the app renders in user file names. It does **not**
include symbol glyphs — notably no `✓` (U+2713), `✔`, `★`, or `▶`. Interface symbols come
from the Phosphor icon set instead (see [Icon system](./ICONS.md)); do not reintroduce
symbol characters as text.

Its figures are proportional, and unevenly so (`1` is about 60% the width of `0`), so text
whose digits change in place — clocks, counters, progress — needs a fixed-width container
or a measured layout rather than one that reflows per digit.
