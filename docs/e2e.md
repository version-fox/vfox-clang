# End-to-end tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

The end-to-end suites run the plugin with real vfox 1.1.0, in the way a user runs it:
`vfox add`, `vfox search`, `vfox install`, `vfox link --detect`. They are in `tests/e2e`,
a Go module that uses only the standard library. The offline Lua tests, which `vfox plugin test`
runs without network access or processes, are described in [development.md](development.md).

## What the suites check

The three CI jobs run the same five scenarios, from `tests/e2e/common/scenarios.go`:

1. **Search** lists the versions from the real manifest, and `vfox search clang -- --no-cache`
   lists them too (issue #3).
2. **HTTP failures** name their cause: a 404 names the status, a manifest without a list says
   so, and an unreachable mirror is reported as such (issue #6). A fake GitHub serves the
   wrong answers.
3. **A failed install** leaves no `.installing` marker and no partial `v-<version>` directory,
   both for a pixi that fails and for a version the manifest does not list (issue #4). The
   fake GitHub serves a version whose pixi always fails.
4. **Install with a space in HOME**: the real clang is installed from conda-forge into a home
   directory that contains a space, and the installed `clang --version` must name the version
   (issue #5). The pixi archive is checked against the SHA-256 that pixi publishes, so the install
   prints `Verifying checksum` and no warning about a missing checksum (issue #14).
5. **A system clang is detected and linked**: a fake `clang` in a folder that `CONDA_PREFIX`
   names, `vfox link --detect clang --yes` links it, `vfox list clang` shows it, and a second run
   finds nothing new. Every job sets `CONDA_PREFIX`, so the runner's own LLVM installs stay out of
   the way. On `windows-latest`, `ProgramFiles` did not reach the plugin when the suite set it, and
   the search found the runner's Visual Studio and LLVM instead; the Windows folders of the plugin
   are checked by its offline tests.

The fake GitHub runs on the host and listens on `127.0.0.1`. The plugin reaches it through
`GITHUB_URL`.

## Linux: Ubuntu 26.04 containers

`tests/e2e/linux` builds an image from its `Dockerfile` (Ubuntu 26.04 with the CA bundle, nothing
else), then starts one container per scenario and removes it at the end of the scenario.
vfox, the plugin zip and the fake programs go into the container with `docker cp`, and every
command runs with `docker exec`. The container shares the host's network, so it reaches the fake
GitHub on the host. Its HOME is `/root/home with space`, and `PIXI_CACHE_DIR` points into it.

You need Docker and Go 1.27.4. From the repository root:

``` shell
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

One scenario only, by its subtest name:

``` shell
go test -v -timeout 55m -run 'TestE2E/install_with' ./linux
```

Rootless Docker works: the suite uses no bind mounts that the container has to write to.

## Windows: the runner itself

`tests/e2e/windows` runs on the Windows host, with no container: Windows containers would need a
Windows Docker engine and a much larger image for the same check. Each scenario gets a temporary
directory of its own, with a HOME named `home with space` inside it. The suite removes host
variables that would change vfox's behavior (`GITHUB_URL`, `Conda_Forge`, `CONDA_PREFIX`,
`VFOX_HOME`, `HOME`, `USERPROFILE`, `CI`) and sets only the ones a scenario needs. Every sandbox also sets `PIXI_CACHE_DIR` to a folder inside it, and on Windows `LOCALAPPDATA` and `APPDATA` to folders inside its HOME. pixi reads `PIXI_CACHE_DIR` before it asks Windows for the cache folder. On the `windows-latest` runner that question failed with `could not determine default cache directory`, so the sandbox does not depend on the answer.

CI runs the suite on two runners: `windows-latest` (x86_64) and `windows-11-arm` (arm64). Each one
downloads the vfox and pixi builds of its own architecture, so the arm64 run checks that clang from
conda-forge's `win-arm64` packages runs on arm64 Windows.

From the repository root, in PowerShell:

``` powershell
cd tests\e2e
go test -v -timeout 55m -run TestE2E .\windows
```

The suite is skipped on any other host.

## Settings

| Setting   | Meaning                                                                                                             |
| :-------- | :------------------------------------------------------------------------------------------------------------------ |
| `VFOX_BIN` | A vfox binary to use instead of downloading the pinned release (the pinned version is 1.1.0; a downloaded archive is checked against its SHA-256, this binary is not).          |
| `TMPDIR`   | Where `t.TempDir()` puts the scenarios' files. Set it to a disk with room for a clang install.                      |
| `-short`   | `go test -short ./...` skips both suites and runs the unit tests of the helpers.                                    |

The pinned vfox archive is cached in the user cache directory (`vfox-clang-e2e/vfox-1.1.0`).

Network commands (search and install) are retried up to five times, waiting longer each time,
because a download from GitHub or conda-forge can be cut short. A scenario that still fails shows
the output of its last attempt.

## What is not covered

- macOS: the offline Lua tests simulate `darwin`, and the glua test runs the real shell on Linux.
  No suite runs vfox on macOS.
- Linux arm64: the Linux suite runs on x86_64 containers only.
- Other vfox releases: the suites pin 1.1.0, the release the `vfox link` and `--` behavior is
  checked with.
