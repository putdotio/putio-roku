# Roku Variants And Lab

## One sideload slot

Every sideloaded ZIP replaces the same `dev` channel, whatever its title,
assets, or config. To keep a normal app beside Lab on one device, install the
normal app from a public or beta Roku lane, or use a second Roku. Do not
pretend different manifest ids can coexist through sideloading.

## Variants

`ROKU_VARIANT` picks `production` (release artifact), `development`, or `lab`
at packaging time. Only `lab` includes `components/lab/`. Titles, app id, and
the Sentry DSN are package-time overrides in
[scripts/package-roku.ts](../scripts/package-roku.ts), which renders the
manifest and `source/BuildConfig.brs` without editing checked-in files. The
checked-in [source/BuildConfig.brs](../source/BuildConfig.brs) stays
production-safe.

Never fork app code per variant.

## Design adapter

Roku consumes `@putdotio/design`; this repo owns only the Roku adapter.
[generate-roku-assets.ts](../scripts/generate-roku-assets.ts) writes
`images/generated/<variant>/`, and
[generate-roku-design.ts](../scripts/generate-roku-design.ts) writes
[source/DesignTokens.brs](../source/DesignTokens.brs).

- App colors go through `designTokenColor` or `DialogStyle`; raw color literals belong only in generated files, generators, tests, and docs
- Roku screen, focus, and autoscale-grid metrics stay in [UiMetrics.brs](../components/shared/UiMetrics/UiMetrics.brs), not in design tokens
- Roku-native token files are generated here, never inside `putio-design`
- To test unreleased design work, point `PUTIO_DESIGN_ASSETS_DIR` or `PUTIO_DESIGN_TOKENS_PATH` at it; normal builds use the installed package

## Error reporting

Sentry has no BrightScript SDK, so the app posts envelopes straight to the
Sentry ingest API:

- [Sentry.brs](../components/shared/Sentry/Sentry.brs) builds events on the render thread and hands each to [SentryTask](../components/shared/SentryTask/SentryTask.brs), which POSTs from a Task thread; screens never wait on the network
- [PlaybackTelemetry.brs](../components/shared/Sentry/PlaybackTelemetry.brs) turns a terminal `Video` failure into a `playback_failure` event that mirrors the putio-web telemetry contract (`schema_version` 1)
- Events carry ids, codes, categories, codecs, container, resolution, device, and OS as tags and contexts only, with no `extra`. Never send filenames, media titles, URLs, query strings, tokens, account fields other than the user id, Roku error messages, or the API's `error_message`. [sentry-privacy.test.ts](../test/sentry/sentry-privacy.test.ts) pins this with synthetic forbidden values in the [`@rokucommunity/brs`](https://github.com/rokucommunity/brs) interpreter
- `VideoPlayer` reports before it stops the Video node, because `control = "stop"` clears `errorInfo`; `Video` reports failed file requests separately
- Reporting stops when `/account/info` `settings.diagnostics_enabled` is `false`; a missing key or an unloaded account counts as on. The app reads the account at launch, so a change on another client applies on the next launch
- Reporting is off unless the package was built with `PUTIO_ROKU_SENTRY_DSN`. The checked-in `BuildConfig.brs` keeps it empty, so clones and local builds send nothing; releases set it from the repository variable. Packaging rejects values not shaped like `https://<publicKey>@<host>/<projectId>`, so a typo cannot drop every report
