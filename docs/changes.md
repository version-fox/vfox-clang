# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages list the pull requests.

## Unreleased

### Fixed

- pixi's archive is checked against the SHA-256 that pixi publishes next to it, before vfox unpacks it.
  Before, the install printed `Checksum is not provided` and skipped the check
  ([#14](https://github.com/version-fox/vfox-clang/issues/14)). A release that publishes no SHA-256 still
  installs, with that warning. If the SHA-256 cannot be read, the install stops; see
  [troubleshooting.md](troubleshooting.md#failed-to-get-the-sha-256-of-the-archive).

## 0.5.3 (2026-11-22)

### Added

- `vfox link --detect clang` finds the LLVM installations already on the machine and links them, so
  vfox uses them instead of downloading another copy. It needs vfox 1.1.0 or later. See [link.md](link.md).
- Tests for the plugin: offline hook tests run by `vfox plugin test`, a shell test that runs the
  install command through the real `/bin/sh`, and end-to-end suites on Ubuntu 26.04 containers and on
  the Windows runner. See [development.md](development.md) and [e2e.md](e2e.md).
- Checks in CI: Lua formatting and types, Go formatting, vet and unit tests, workflow lint, and
  license headers. Dependabot keeps the actions, the Go module and the Docker image up to date.
- A development container in `.devcontainer/`, with the tools the checks use at the versions CI pins and
  the Docker CLI, so the end-to-end suite can run from inside it. See [development.md](development.md#development-container).
- Documentation in English and Chinese: the README, [using a system clang](link.md),
  [troubleshooting](troubleshooting.md), [development](development.md), [end-to-end tests](e2e.md),
  and this changelog.

### Fixed

- `vfox search clang -- --no-cache` removes vfox's cache file for the list, which is
  `.available.cache`, and prints the list. Earlier releases removed a file that vfox never creates, and
  they exited before printing anything ([#3](https://github.com/version-fox/vfox-clang/issues/3)).
  vfox keeps each result under the arguments and writes the cache back after the call, so a
  plain search may keep the previous list until the cache expires; see
  [troubleshooting.md](troubleshooting.md#the-list-does-not-refresh).
- The README shows `vfox search clang -- --no-cache`. `vfox search clang --no-cache` fails with
  vfox 1.1.0 and 1.0.13 ([vfox#808](https://github.com/version-fox/vfox/issues/808)).
- A failed install no longer leaves a `.installing` marker and a partial `v-<version>` directory:
  the hooks raise an error instead of calling `os.exit`, so vfox cleans up
  ([#4](https://github.com/version-fox/vfox-clang/issues/4)).
- The pixi command quotes its program and arguments, on Unix and Windows, so an install works in a
  HOME that contains a space ([#5](https://github.com/version-fox/vfox-clang/issues/5)).
- A failed HTTP request reports its cause: a status other than 200 names the status, a manifest
  without a version list says so, and a network error keeps its message. None of them raises a Lua
  error about a nil value any more ([#6](https://github.com/version-fox/vfox-clang/issues/6)).
- macOS is recognised. vfox reports `darwin`, and the plugin checked for `macos`, so every macOS
  install stopped with `Unsupported environment` ([#7](https://github.com/version-fox/vfox-clang/issues/7)).
- The version list tool is built from its source in the Update version list workflow, and the
  23 MB binary is no longer committed. The tool's regular expression stops at the first `<code>`
  block, as the plugin's does ([#8](https://github.com/version-fox/vfox-clang/issues/8)).
- Source files carry the Apache 2.0 license header.
