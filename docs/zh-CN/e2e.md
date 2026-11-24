# 端到端测试

[中文](e2e.md) | [English](../e2e.md)

端到端测试套件使用真实的 vfox 1.1.0 运行插件，方式与用户完全一致：`vfox add`、`vfox search`、`vfox install`、`vfox link --detect`。套件位于 `tests/e2e`，是一个只使用标准库的 Go 模块。离线的 Lua 测试由 `vfox plugin test` 运行，不使用网络，也不启动进程，见 [development.md](development.md)。

## 套件检查什么

三个套件运行的是同一组五个场景，定义在 `tests/e2e/common/scenarios.go` 中：

1. **搜索**会从真实的 manifest 列出版本，`vfox search clang -- --no-cache` 也会列出版本（issue #3）。
2. **HTTP 失败**会说明原因：404 会写出状态码，清单中没有列表会明确说明，镜像不可达会如实报告（issue #6）。测试中的假 GitHub 会给出各种错误的应答。
3. **安装失败**后不会留下 `.installing` 标记和不完整的 `v-<版本>` 目录。这包括 pixi 始终失败的情况，以及清单中没有列出的版本（issue #4）。假 GitHub 提供一个 pixi 总是失败的版本。
4. **主目录包含空格时的安装**：真实的 clang 从 conda-forge 安装到一个包含空格的主目录中，安装后的 `clang --version` 必须输出该版本号（issue #5）。pixi 的安装包会与 pixi 发布的 SHA-256 核对，因此安装会打印 `Verifying checksum`，且不会出现缺少校验和的警告（issue #14）。
5. **系统 clang 被发现并链接**：在各平台检测会查找的位置放一个假的 `clang`，`vfox link --detect clang --yes` 将其链接进来，`vfox list clang` 显示它，再次运行则不会发现新内容。两个平台都使用 `CONDA_PREFIX`，因此 runner 自己的 LLVM 安装不会干扰结果。在 `windows-latest` 上，套件设置的 `ProgramFiles` 没有传到插件里，搜索到的是 runner 自带的 Visual Studio 与 LLVM；Windows 上的各个查找目录由插件的离线测试检查。

假 GitHub 运行在宿主机上，监听 `127.0.0.1`。插件通过 `GITHUB_URL` 访问它。

## Linux：Ubuntu 26.04 容器

`tests/e2e/linux` 用其中的 `Dockerfile` 构建镜像（Ubuntu 26.04，只装了 CA 证书），然后为每个场景启动一个容器，场景结束时删除。vfox、插件 zip 和假程序通过 `docker cp` 放入容器，所有命令通过 `docker exec` 执行。容器与宿主机共享网络，因此能访问宿主机上的假 GitHub。容器内的 HOME 是 `/root/home with space`，`PIXI_CACHE_DIR` 也指向其中。

需要 Docker 与 Go 1.27.4。在仓库根目录执行：

``` shell
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

只运行某一个场景，按子测试名称过滤：

``` shell
go test -v -timeout 55m -run 'TestE2E/install_with' ./linux
```

rootless Docker 同样可用：套件不依赖容器内对绑定挂载目录的写入权限。

## Windows：runner 本机

`tests/e2e/windows` 直接在 Windows 主机上运行，不使用容器。Windows 容器需要 Windows 版的 Docker 引擎和大得多的镜像，而这里的检查并不需要它。每个场景在自己的临时目录中运行，其中的 HOME 名为 `home with space`。套件会移除可能改变 vfox 行为的宿主机变量（`GITHUB_URL`、`Conda_Forge`、`CONDA_PREFIX`、`VFOX_HOME`、`HOME`、`USERPROFILE`、`CI`），只设置场景需要的变量。每个沙箱还会把 `PIXI_CACHE_DIR` 指向其内部的目录，在 Windows 上把 `LOCALAPPDATA` 与 `APPDATA` 指向其 HOME 内的目录。pixi 会先读取 `PIXI_CACHE_DIR`，然后才向 Windows 询问缓存目录。`windows-latest` runner 上这一询问失败，报错为 `could not determine default cache directory`，因此沙箱不依赖它的答复。

CI 在两台 runner 上运行该套件：`windows-latest`（x86_64）与 `windows-11-arm`（arm64）。每台 runner 下载与其架构相符的 vfox 与 pixi，因此 arm64 的运行会检查 conda-forge 的 `win-arm64` 包中的 clang 能否在 arm64 Windows 上运行。

在仓库根目录的 PowerShell 中执行：

``` powershell
cd tests\e2e
go test -v -timeout 55m -run TestE2E .\windows
```

在其他主机上套件会被跳过。

## 设置项

| 设置       | 含义                                                                                               |
| :--------- | :------------------------------------------------------------------------------------------------- |
| `VFOX_BIN` | 使用你已有的 vfox 二进制，而不是下载固定版本（固定版本为 1.1.0；下载的压缩包会校验 SHA-256，此处的二进制不校验）。                     |
| `TMPDIR`   | `t.TempDir()` 放置场景文件的位置。请指向一块能容纳 clang 安装的磁盘。                              |
| `-short`   | `go test -short ./...` 会跳过两个端到端套件，只运行辅助函数的单元测试。                            |

固定版本的 vfox 压缩包会缓存在用户缓存目录的 `vfox-clang-e2e/vfox-1.1.0` 下。

网络命令（搜索与安装）最多重试五次，每次等待更久，因为从 GitHub 或 conda-forge 下载可能被中途切断。仍然失败的场景会显示最后一次尝试的输出。

## 未覆盖的范围

- macOS：离线 Lua 测试模拟了 `darwin`，glua 测试在 Linux 上运行真实的 shell。没有任何套件在 macOS 上运行 vfox。
- Linux arm64：Linux 套件只在 x86_64 容器中运行。
- 其他 vfox 版本：套件固定使用 1.1.0，`vfox link` 与 `--` 的行为都是以该版本验证的。
