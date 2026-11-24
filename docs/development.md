# Development

[中文](zh-CN/development.md) | [English](development.md)

This page is for people who change the plugin. It covers the layout of the repository, the
checks that CI runs and how to run each one, and the rules the tests depend on.

## Layout

| Path                   | What it is                                                                 |
| :--------------------- | :------------------------------------------------------------------------- |
| `metadata.lua`         | Plugin metadata. The release workflow updates the version.                 |
| `Injection.lua`        | The objects vfox injects (`RUNTIME`), for editor hints only. Do not change it. |
| `hooks/`               | The vfox hooks: `available`, `pre_install`, `post_install`, `env_keys`, `detect`. |
| `lib/`                 | Modules the hooks use: `util`, `versions`, `pixi`, `detect_clang`.         |
| `tests/*_test.lua`     | Offline hook tests, run by `vfox plugin test .`.                           |
| `tests/shell_quoting.lua` | Runs `pixi.install` through the real `/bin/sh`, under glua.             |
| `tests/e2e/`           | The end-to-end suites in Go (see [e2e.md](e2e.md)).                         |
| `.github/`             | Workflows, the version list tool (`UpdateVersionList.cr`), Dependabot.     |
| `.devcontainer/`       | The development container, see [its section](#development-container).       |
| `.licenserc.yaml`      | Settings of the license header check.                                      |
| `docs/`                | This documentation, in English and in `docs/zh-CN/`.                       |

## The checks

CI runs these checks on every pull request. Each one can be run locally.

| Check                    | Command                                                                              | Tool                                  |
| :----------------------- | :----------------------------------------------------------------------------------- | :------------------------------------ |
| Lua format               | `stylua --check .`                                                                   | stylua 2.5.2                          |
| Lua types                | `lua-language-server --check . --checklevel=Warning`                                 | lua-language-server 3.19.1            |
| Go format                | `gofmt -l .` in `tests/e2e` must print nothing                                       | gofmt, Go 1.27.4                      |
| Go vet                   | `go vet ./...` and `GOOS=windows go vet ./...` in `tests/e2e`                        | Go                                    |
| Go unit tests            | `go test -short ./...` in `tests/e2e`                                                | Go                                    |
| Workflows                | `actionlint`                                                                         | actionlint 1.7.12                     |
| License headers          | `license-eye header check -c .licenserc.yaml`                                        | SkyWalking Eyes 0.9.0                 |
| Offline plugin tests     | `vfox plugin test .`                                                                 | vfox 1.1.0                            |
| Shell quoting            | `go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/shell_quoting.lua`          | Go                                    |
| End-to-end               | `go test -run TestE2E ./linux` and `./windows`, see [e2e.md](e2e.md)                  | Docker, Go                            |

Run the Go commands in `tests/e2e`, and the others in the repository root.

Use the versions above: a newer stylua may format differently, and a newer vfox may behave
differently from the release the plugin is checked with.

## Writing Lua

- Keep the Apache 2.0 header from the top of any existing file (copy it from `lib/util.lua`).
  The license check fails on a file without it.
- Format with stylua; `stylua.toml` sets 120 columns and four spaces.
- Modules return a table; hooks call them. Shared helpers live in `lib/util.lua`.
- Do not call `os.exit`. A hook that exits the process skips vfox's cleanup, so a failed install
  leaves a marker and a partial directory behind (issue #4). Raise an error for a failure, with a
  message that says what went wrong. An error raised in a hook reaches the user with a Lua stack
  traceback, so a request the plugin cannot serve, such as an unsupported platform or a version the
  platform does not list, prints its reason and returns no result instead (see
  `hooks/pre_install.lua`). vfox then stops the install with its own message.
- Quote every path and argument that goes to the shell with `util.quote`, which is single quotes on
  Unix and double quotes for cmd.exe on Windows. Build Windows command lines with
  `pixi.silenced`, which wraps the whole line as cmd.exe requires.
- Read a command's output with `read("*a")` and split it into lines yourself. On Windows the handle
  that `io.popen` returns has only `read` and `close`; `lines` exists on Unix alone. A test on Linux
  that calls `lines` passes, and the same code fails on the Windows runner.

## Writing offline tests

`vfox plugin test .` runs each `tests/**/*_test.lua` in a VM of its own. Each file calls
`require("vfox.test").load(...)` once. The options set the OS, the architecture, the environment and
an `http` handler that answers requests. In the test VM:

- `os.execute` and `io.popen` are disabled. A test that needs them replaces them with a stub.
- `os.exit` raises an error, so a hook that exits fails its test.
- `io.open` works, so a test that reads files should stub it to keep the test independent of the
  machine.

**A closure must not see a local that the main chunk reassigns later.** In the test VM, a function
that captures `answer` keeps the value the local had when it was created, even after the test
assigns a new one. Keep the state a stub reads in a table, and change its fields rather than the
local:

``` lua
local state = { answer = nil }
test.load({ http = function() return state.answer end })
state.answer = { status_code = 404, body = "" }   -- seen by the handler
```

Set `RUNTIME.osType` and `RUNTIME.archType` to test another platform. The hooks read them when they
run.

## Changing the version list

The Check Updates Periodically workflow (`.github/workflows/update-version-list.yml`) builds
`.github/UpdateVersionList.cr` with Crystal 1.22.3 on every run, so the repository keeps no
binary. To build it locally:

``` shell
crystal build --release --no-debug .github/UpdateVersionList.cr -o /tmp/UpdateVersionList
/tmp/UpdateVersionList -o /tmp/manifest.md
```

The tool writes `manifest.md` only when the manifest changes: when conda-forge has a newer clang than
the list, or when the versions published for a platform change. The manifest holds the conda-forge
list, and under each conda subdir (`linux-64`, `win-arm64` and so on) the versions of that list that
conda-forge publishes for it. Its output is the body of the `manifest` release, which the plugin reads.
The tool reads each version's platforms from the prefix.dev API. It writes nothing when prefix.dev
answers with an error, when a version of the list has no platforms there, or when no version of the
list is published for one of the subdirs.

## Development container

`.devcontainer/` opens a Linux environment with the versions of the checks above, the vfox release
the offline tests run with, and the Docker CLI. It mounts the host's Docker socket, so the end-to-end
suite starts its containers on the host's daemon, next to the container you work in. The container
shares the host's network, as the suite needs it to reach the fake GitHub on `127.0.0.1`.

Open it with any Dev Containers tool, such as **Dev Containers: Reopen in Container** in VS Code, or
the CLI:

``` shell
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

On a rootless Docker host, point the mount at its socket first:
`export DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock"`. The Windows suite is not run in the container;
it needs a Windows host (see [e2e.md](e2e.md)).

## Releasing

See the Releasing section of the [README](../README.md#releasing-this-plugin).
