<div align="center">
  <p>
    <img src="https://static.put.io/images/putio-boncuk.png" width="72" alt="put.io boncuk">
  </p>

  <h1>putio-roku</h1>

  <p>
    Roku app for browsing, searching, and streaming your put.io library on TV
  </p>

  <p>
    <a href="https://github.com/putdotio/putio-roku/actions/workflows/ci.yml?query=branch%3Amain" style="text-decoration:none;"><img src="https://img.shields.io/github/actions/workflow/status/putdotio/putio-roku/ci.yml?branch=main&style=flat&label=ci&colorA=000000&colorB=000000" alt="CI"></a>
    <a href="https://github.com/putdotio/putio-roku/blob/main/LICENSE" style="text-decoration:none;"><img src="https://img.shields.io/github/license/putdotio/putio-roku?style=flat&colorA=000000&colorB=000000" alt="license"></a>
  </p>
</div>

## Install

Roku no longer supports private channels, so put.io on Roku is installed by sideloading.

For most users, the right path is the [published Roku ZIP](https://roku.put.io/v2.zip) and the step-by-step [Sideloading guide](./docs/SIDELOADING.md)

If you are working on the app itself, you can also sideload a ZIP generated from this repository. Start with [Contributing](./CONTRIBUTING.md)

## Use

After installation, sign in with your put.io account to:

- browse your library
- search files
- review playback history
- adjust app settings
- stream supported media on Roku

## Docs

- [Sideloading guide](./docs/SIDELOADING.md) for device setup and ZIP installation
- [Live Test](./live-test/README.md) for hardware-backed debugging and agent readiness checks
- [Release workflow](./docs/RELEASE.md) for [GitHub Releases](https://github.com/putdotio/putio-roku/releases) and [roku.put.io](https://roku.put.io/v2.zip) publishing
- [Security](./SECURITY.md) for private vulnerability reporting

## Development

The app is BrightScript/SceneGraph, with `brighterscript`, `bslint`, and
`roku-deploy` installed through pnpm for local and CI validation.

```bash
pnpm install --frozen-lockfile
make verify
```

## Contributing

Contributions are welcome. Use [Contributing](./CONTRIBUTING.md) for the contributor workflow and local sideload setup.

## License

This project is available under the [MIT License](./LICENSE)
