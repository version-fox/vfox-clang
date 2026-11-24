# vfox-clang

[中文](README_CN.md) | [English](README.md)

[Clang](https://clang.llvm.org/) plugin for [vfox](https://vfox.lhan.me). The clang
packages come from [conda-forge](https://conda-forge.org/), installed by
[pixi](https://pixi.sh/), so `vfox search clang` lists the versions conda-forge publishes for
your platform. Not every platform has every version; see [Platforms](#platforms).

## Requirements

- [vfox](https://github.com/version-fox/vfox) 0.5.1 or later. Linking clang that is already on the machine
  (`vfox link --detect clang`) needs vfox 1.1.0 or later; see [docs/link.md](docs/link.md).
- Linux (x86_64, arm64), macOS (x86_64, arm64) or Windows (x86_64, arm64).
- Network access to GitHub and conda-forge while installing. See [Mirrors](#mirrors)
  for networks where they are slow or blocked.

## Install

After installing [vfox](https://github.com/version-fox/vfox), add the plugin:

``` shell
vfox add clang
```

List the versions and pick one:

``` shell
vfox search clang
```

vfox keeps the list for 12 hours. To fetch it again, pass `--no-cache` after `--`:

``` shell
vfox search clang -- --no-cache
```

The `--` is needed: vfox reads a flag that starts with a dash as its own option, so
`vfox search clang --no-cache` fails. See [docs/troubleshooting.md](docs/troubleshooting.md#the-list-does-not-refresh)
for what `--no-cache` can and cannot do.

Install the latest version with the `latest` tag, or a version from the list:

``` shell
vfox install clang@latest
vfox install clang@22.1.3
vfox use clang@22.1.3
```

The newest version in the list is marked `latest`.

## Use a clang that is already installed

If LLVM is already on the machine, for example from Homebrew, the LLVM installer, apt or
Visual Studio, vfox can use it without downloading another copy:

``` shell
vfox link --detect clang
```

The plugin looks in the usual places for each platform and lists what it finds. See
[docs/link.md](docs/link.md) for the places and the rules.

## Environment variables

| Environment variables | Default value         | Description                                                |
| :-------------------- | :-------------------- | :--------------------------------------------------------- |
| Conda_Forge           | `conda-forge`         | conda channel that clang is installed from                 |
| GITHUB_URL            | `https://github.com/` | GitHub base URL, for the version list and for pixi         |

Usage:

``` shell
export Conda_Forge=https://prefix.dev/conda-forge
export GITHUB_URL=https://mirror.example.com/https://github.com/
```

## Mirrors

`GITHUB_URL` moves the GitHub downloads the plugin makes to a mirror: the version list
(`<GITHUB_URL>/version-fox/vfox-clang/releases/manifest`), and the pixi archive and the
`.sha256` file that pixi publishes next to it (`<GITHUB_URL>/prefix-dev/pixi/releases/latest/download/…`).
The plugin checks the archive against that SHA-256. A mirror that answers the `.sha256` address
with neither the file nor a 404 stops the install; see
[troubleshooting](docs/troubleshooting.md#failed-to-get-the-sha-256-of-the-archive).
`Conda_Forge` is the conda channel that pixi installs clang from, and may be a mirror of
conda-forge such as `https://prefix.dev/conda-forge`. Set them before the command that needs them.

## Platforms

| Platform     | Architecture | pixi archive                                    |
| :----------- | :----------- | :---------------------------------------------- |
| Linux        | x86_64       | `pixi-x86_64-unknown-linux-musl.tar.gz`         |
| Linux        | arm64        | `pixi-aarch64-unknown-linux-musl.tar.gz`        |
| macOS        | x86_64       | `pixi-x86_64-apple-darwin.tar.gz`               |
| macOS        | arm64        | `pixi-aarch64-apple-darwin.tar.gz`              |
| Windows      | x86_64       | `pixi-x86_64-pc-windows-msvc.zip`               |
| Windows      | arm64        | `pixi-aarch64-pc-windows-msvc.zip`              |

Install paths may contain spaces, as a Windows user profile or a macOS account name
often does.

`vfox search clang` lists the versions that conda-forge publishes for the platform you are on, so some
platforms list fewer. On Windows arm64 the list may hold only the newest version. A platform
without a pixi archive lists nothing; see [troubleshooting](docs/troubleshooting.md#unsupported-platform-x-y).

## Documentation

- [Changelog](docs/changes.md)
- [Using a system clang](docs/link.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Development](docs/development.md) and [end-to-end tests](docs/e2e.md)

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only; a PR title does not trigger publication.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract and first-rollout requirements.

## License

[Apache License 2.0](LICENSE)
