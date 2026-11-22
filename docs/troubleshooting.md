# Troubleshooting

[中文](zh-CN/troubleshooting.md) | [English](troubleshooting.md)

## The list does not refresh

`vfox search clang -- --no-cache` fetches the version list again and prints it. vfox
keeps each result in the plugin's cache file for `cache.availableHookDuration`, 12 hours
by default, under a key made from the arguments. It reads that cache before it calls the
plugin, and it writes the whole cache back after the call. So:

- The first `--no-cache` run after a new release gets the new list.
- A later `--no-cache` run may print the list it saved, for as long as its cache entry lives.
- A plain `vfox search clang` may keep the list from before until the cache expires, even
  right after a `--no-cache` run.

To ask GitHub on every search, turn vfox's cache off:

``` shell
vfox config cache.availableHookDuration 0
```

Turn it back on with `vfox config --unset cache.availableHookDuration`.

`vfox search clang --no-cache` fails with `flag provided but not defined: -no-cache`.
Put `--` before the flag, as in the README.

## Failed to get versions: status 404

The plugin reads the version list from `<GITHUB_URL>/version-fox/vfox-clang/releases/manifest`.
A status other than 200 means that address does not serve the list: a wrong or outdated
`GITHUB_URL`, or a mirror that is down. Open the address in a browser, or with
`curl -I`, and fix `GITHUB_URL`.

## Failed to get versions: the manifest has no version list

The page answered with 200 but has no `<code>` block for the plugin to read. Usually a
captive portal or a proxy page answered instead of GitHub. Check the network and the mirror,
then search again.

## Failed to get versions: the version list is not valid JSON

The `<code>` block is there, but its content is not valid JSON. Usually an intermediary
answered with another page. Handle it the same way.

## Failed to get versions: the version list has no conda-forge entry

The list is valid JSON, but it has no `conda-forge` entry. The manifest always has one, so the
address serves something else. Check `GITHUB_URL`, then search again.

## Failed to request the version list

The request did not reach the server at all: no network, a DNS error, a refused connection,
or a proxy that drops it. Check the connection and the `GITHUB_URL` value.

## Failed to execute command: ... pixi ... global install

pixi could not install clang from the conda channel. The message shows the command that
failed; the output printed above it, from pixi, says why. Common causes are a blocked or
slow conda-forge and a `Conda_Forge` value that is not a channel. Run the install again: a
failed install leaves nothing behind, so the retry starts clean.

## Unsupported version: X

The version is not in the list that the plugin reads. Run `vfox search clang` for the
versions, or `vfox search clang -- --no-cache` if the list is old.

## Unsupported environment: windows-arm64

The plugin installs clang on Linux x86_64 and arm64, macOS x86_64 and arm64, and Windows
x86_64. On other platforms it stops before it downloads anything.

## unexpected EOF while downloading

The connection was cut in the middle of a download, most often on an unstable network or a
mirror. Run the same command again.

## `vfox link --detect clang` finds nothing

- The installation must hold `bin/clang`, or `bin\clang.exe` on Windows, in one of the places
  listed in [link.md](link.md).
- `clang --version` must print `clang version X.Y.Z`. Apple's clang is never used.
- An installation under `.vfox` is never reported, because vfox installed it.

## An install was interrupted

If vfox was killed in the middle of an install, it leaves an `.installing` marker and a
partial `v-<version>` directory in its cache directory for that version. The next
`vfox install` of the same version removes the partial directory and starts over. A
failed install that vfox reports as an error cleans up after itself.
