# vfox-clang

[Clang](https://clang.llvm.org/) plugin for [vfox](https://vfox.lhan.me).

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

``` shell
vfox add clang
```

Next, search and select the version to install. By default, vfox keeps cache for available versions, use the `--no-cache` flag to delete the cache file.

``` shell
vfox search clang
vfox search clang --no-cache && vfox search clang
```

Install the latest stable version with `latest` tag.

``` shell
vfox install clang@latest
```

Some environment variables are served as following:

| Environment variables | Default value         | Description         |
| :-------------------- | :-------------------- | :------------------ |
| Conda_Forge           | `conda-forge`         | conda-forge channel |
| GITHUB_URL            | `https://github.com/` | GitHub mirror URL   |

Usage:

``` shell
export Conda_Forge=https://prefix.dev/conda-forge
export GITHUB_URL=https://mirror.ghproxy.com/https://github.com/
```

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only; PR titles no longer trigger publication.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract and first-rollout requirements.
