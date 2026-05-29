# Roku Variants And Lab

Notes for Roku build variants, Lab packaging, and the Roku-specific
design-system adapter. For commands, use [Contributing](../CONTRIBUTING.md) and
[Live Test](../live-test/README.md).

## Roku Constraint

Roku sideloading uses a single developer-channel slot. Locally built ZIPs can
have different titles, assets, and app config, but when they are sideloaded they
replace the same `dev` channel.

Same-device coexistence needs a non-sideloaded lane for one of the apps:

- public or beta Roku app for the stable normal app, plus sideload for Lab
- separate physical Roku devices
- manual replacement of the single sideload slot

The practical local default is: keep Lab fast and sideloaded, and use a Roku
beta/public lane only when a persistent normal app must coexist on the same
device.

## Variants

| Variant | Title | Lab code | Use |
| --- | --- | --- | --- |
| `production` | `put.io` | excluded | release artifact |
| `development` | `put.io Dev` | excluded | normal app development |
| `lab` | `put.io Lab` | included | component and visual work |

## Packaging Contract

Variant selection happens at the packaging boundary:

- `ROKU_VARIANT=production|development|lab`
- `ROKU_APP_TITLE` overrides the variant title
- `PUTIO_ROKU_APP_ID` sets the put.io OAuth/app id in the generated build config
- `ROKU_OUT_FILE` sets an explicit ZIP output path

[scripts/package-roku.ts](../scripts/package-roku.ts) renders the variant
manifest and `source/BuildConfig.brs` as package-time overrides, then delegates
ZIP creation to `@putdotio/rokit`. It does not edit checked-in source files.

Lab behavior is controlled by the generated build config. The checked-in
[source/BuildConfig.brs](../source/BuildConfig.brs) stays production-safe.

## Design Adapter

Roku consumes `@putdotio/design` and owns only the Roku adapter here.

- [scripts/generate-roku-assets.ts](../scripts/generate-roku-assets.ts) reads
  `@putdotio/design/assets/logo-retro-dark.svg` plus channel-art tokens, then
  writes `images/generated/<variant>/`
- [scripts/generate-roku-design.ts](../scripts/generate-roku-design.ts) reads
  `@putdotio/design/tokens` and writes
  [source/DesignTokens.brs](../source/DesignTokens.brs)
- app colors should go through `designTokenColor` / `DialogStyle`; raw app
  color literals belong only in generated files, generators, tests, and docs

Escape hatches for testing unreleased design work:

- `PUTIO_DESIGN_ASSETS_DIR`
- `PUTIO_DESIGN_TOKENS_PATH`

Normal builds use the installed package, not a sibling checkout.

## Boundaries

- Do not fork app code per variant.
- Do not pretend different local manifest ids can coexist through sideloading.
- Do not move Roku layout geometry into generic design tokens; keep Roku screen,
  focus, and autoscale-grid metrics in
  [UiMetrics.brs](../components/shared/UiMetrics/UiMetrics.brs).
- Do not generate Roku-native token files inside `putio-design`; this repo owns
  the Roku adaptation.
