# 开发

[中文](development.md) | [English](../development.md)

本页面向修改插件的人，说明仓库的结构、CI 运行的每项检查及其本地运行方式，以及测试所依赖的规则。

## 目录结构

| 路径                      | 内容                                                                                    |
| :------------------------ | :-------------------------------------------------------------------------------------- |
| `metadata.lua`            | 插件元数据。发布工作流会更新版本号。                                                     |
| `Injection.lua`           | vfox 注入的对象（`RUNTIME`），仅供编辑器提示。请勿修改。                                 |
| `hooks/`                  | vfox 钩子：`available`、`pre_install`、`post_install`、`env_keys`、`detect`。             |
| `lib/`                    | 钩子使用的模块：`util`、`versions`、`pixi`、`detect_clang`。                             |
| `tests/*_test.lua`        | 离线钩子测试，由 `vfox plugin test .` 运行。                                             |
| `tests/shell_quoting.lua` | 在 glua 下用真实的 `/bin/sh` 运行 `pixi.install`。                                       |
| `tests/e2e/`              | Go 编写的端到端套件（见 [e2e.md](e2e.md)）。                                             |
| `.github/`                | 工作流、版本列表工具（`UpdateVersionList.cr`）、Dependabot 配置。                         |
| `docs/`                   | 本文档，英文版在 `docs/` 下，中文版在 `docs/zh-CN/` 下。                                  |

## 检查项

CI 在每个 Pull Request 上运行以下检查，每一项都可以在本地运行。

| 检查           | 命令                                                                                       | 工具                          |
| :------------- | :----------------------------------------------------------------------------------------- | :---------------------------- |
| Lua 格式       | `stylua --check .`                                                                         | stylua 2.5.2                  |
| Lua 类型       | `lua-language-server --check . --checklevel=Warning`                                       | lua-language-server 3.19.1    |
| Go 格式        | 在 `tests/e2e` 中执行 `gofmt -l .`，输出必须为空                                           | gofmt，Go 1.27.1              |
| Go vet         | 在 `tests/e2e` 中执行 `go vet ./...` 与 `GOOS=windows go vet ./...`                        | Go                            |
| Go 单元测试    | 在 `tests/e2e` 中执行 `go test -short ./...`                                               | Go                            |
| 工作流检查     | `actionlint`                                                                               | actionlint 1.7.12             |
| 许可证头       | `license-eye header check -c .licenserc.yaml`                                              | SkyWalking Eyes 0.9.0         |
| 离线插件测试   | `vfox plugin test .`                                                                       | vfox 1.1.0                    |
| shell 引号测试 | `go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/shell_quoting.lua`                | Go                            |
| 端到端         | `go test -run TestE2E ./linux` 与 `./windows`，见 [e2e.md](e2e.md)                         | Docker、Go                    |

Go 相关命令在 `tests/e2e` 中执行，其余命令在仓库根目录执行。

请使用上表中的版本：新版 stylua 的格式化结果可能不同，新版 vfox 的行为也可能不同于插件所依据的版本。

## 编写 Lua

- 每个已有文件顶部的 Apache 2.0 许可证头都要保留，新文件请从 `lib/util.lua` 复制。缺少许可证头时许可证检查会失败。
- 使用 stylua 格式化；`stylua.toml` 设定每行 120 列、四个空格缩进。
- 模块返回一个表，钩子调用这些模块。共用的辅助函数放在 `lib/util.lua`。
- 不要调用 `os.exit`。退出进程会跳过 vfox 的清理，于是失败的安装会留下标记和不完整的目录（issue #4）。应当抛出错误，并写明出了什么问题。
- 传给 shell 的每个路径和参数都要用 `util.quote` 加引号：Unix 上是单引号，Windows 上是 cmd.exe 所需的双引号。Windows 命令行请用 `pixi.silenced` 构造，它会按 cmd.exe 的要求把整行包上引号。
- 读取命令输出时用 `read("*a")` 整体读取，再自行切分行。Windows 上 vfox 的 `io.popen` 句柄只有 `read` 和 `close`，`lines` 只存在于 Unix。在 Linux 上调用 `lines` 的测试会通过，同样的代码却会在 Windows runner 上失败。

## 编写离线测试

`vfox plugin test .` 会在各自独立的 VM 中运行每个 `tests/**/*_test.lua`。每个文件都要调用一次 `require("vfox.test").load(...)`。选项可以设置操作系统、架构、环境变量，以及一个回答请求的 `http` 处理器。在测试 VM 中：

- `os.execute` 与 `io.popen` 被禁用。需要它们的测试应当用桩函数替换。
- `os.exit` 会抛出错误，因此调用了 `os.exit` 的钩子会让测试失败。
- `io.open` 可用。读取文件的测试应当对它打桩，使测试不依赖运行测试的机器。

**闭包不能看到主代码块之后被重新赋值的局部变量。** 在测试 VM 中，捕获了 `answer` 的函数会保留该局部变量创建时的值，即使测试之后又给它赋了新值。因此，桩函数读取的状态应当放在表中，修改表的字段而不是重新赋值局部变量：

``` lua
local state = { answer = nil }
test.load({ http = function() return state.answer end })
state.answer = { status_code = 404, body = "" }   -- 处理器能看到这个值
```

若要测试另一个平台，请设置 `RUNTIME.osType` 和 `RUNTIME.archType`，钩子在运行时读取它们。

## 更新版本列表

Update version list 工作流每次运行时都会用 Crystal 1.22.3 从 `.github/UpdateVersionList.cr` 构建工具，因此仓库中不保存二进制文件。本地构建方法：

``` shell
crystal build --release --no-debug .github/UpdateVersionList.cr -o /tmp/UpdateVersionList
/tmp/UpdateVersionList -o /tmp/manifest.md
```

只有当 conda-forge 上的 clang 比列表中的新时，工具才会写出 `manifest.md`。它的输出就是 `manifest` 发布页的正文，插件从那里读取版本列表。

## 发布

参见 [README](../../README_CN.md#发布插件) 中的“发布插件”一节。
