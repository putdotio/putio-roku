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
- `PUTIO_ROKU_SENTRY_DSN` compiles the public Sentry DSN into the build config;
  unset or empty disables runtime error reporting (see [Error reporting](#error-reporting))

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

## Error reporting

Sentry has no BrightScript SDK, so the app posts envelopes straight to the
Sentry ingest API:

- [components/shared/Sentry/Sentry.brs](../components/shared/Sentry/Sentry.brs)
  builds events with release, environment, device, OS, and user context on the
  render thread and hands each one to a
  [SentryTask](../components/shared/SentryTask/SentryTask.brs), which POSTs it
  from a Task thread; screens never wait on the network
- [components/shared/Sentry/PlaybackTelemetry.brs](../components/shared/Sentry/PlaybackTelemetry.brs)
  turns a terminal `Video` failure into a `playback_failure` event that mirrors
  the putio-web telemetry contract (`schema_version` 1): tags for grouping such
  as `playback_failure_mode`, `roku_error_code`, `source_kind`, `stream_format`,
  `video_codec`, and `roku_model`, plus extra with Roku `errorInfo`, the
  redacted stream URL, and the file `media_info`
- `VideoPlayer` reports before it stops the Video node because `control = "stop"`
  clears `errorInfo`; `Video` reports failed file requests separately
- Reporting is a no-op unless the package was built with `PUTIO_ROKU_SENTRY_DSN`;
  the checked-in `source/BuildConfig.brs` keeps it empty so open-source clones
  and local builds send nothing. The release workflow sets it from the
  `PUTIO_ROKU_SENTRY_DSN` repository variable. A DSN carries only the public key
  and is safe to ship, but packaging rejects values that do not look like
  `https://<publicKey>@<host>/<projectId>` so a typo cannot silently drop every
  report

