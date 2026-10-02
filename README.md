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

Roku no longer supports private channels, so put.io on Roku is installed by sideloading the [published Roku ZIP](https://roku.put.io/v2.zip). The [Sideloading guide](./docs/SIDELOADING.md) walks through it.

## Use

After installation, sign in with your put.io account to:

- browse your library
- search files
- review playback history
- adjust app settings
- stream supported media on Roku

Long file lists wrap around: press Up on the first item to reach the last,
or Down on the last item to return to the first.

## Docs

- [Sideloading guide](./docs/SIDELOADING.md) for device setup and ZIP installation
- [Live Test](./live-test/README.md) for hardware-backed debugging, Lab stories, and agent readiness checks
- [Roku variants and Lab](./docs/ROKU_VARIANTS.md) for the development/Lab split and design-token adapter
- [Roku visual reference](./.vref/README.md) for curated screenshots and the generated gallery
- [Release workflow](./docs/RELEASE.md) for [GitHub Releases](https://github.com/putdotio/putio-roku/releases) and [roku.put.io](https://roku.put.io/v2.zip) publishing
- [Security](https://github.com/putdotio/.github/blob/main/SECURITY.md) for private vulnerability reporting

## Contributing

Contributions are welcome. [Contributing](./CONTRIBUTING.md) covers setup, local sideloading, and validation.

## License

This project is available under the [MIT License](./LICENSE)
