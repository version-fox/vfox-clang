# vfox-clang

[中文](README_CN.md) | [English](README.md)

[Clang](https://clang.llvm.org/) 的 [vfox](https://vfox.lhan.me) 插件。clang 包来自
[conda-forge](https://conda-forge.org/)，由 [pixi](https://pixi.sh/) 安装，因此
`vfox search clang` 列出的是 conda-forge 发布的版本。并非每个平台都有全部版本，参见[平台](#平台)。

## 环境要求

- [vfox](https://github.com/version-fox/vfox) 0.5.1 或更高版本。若要使用本机已有的 clang
  （`vfox link --detect clang`），需要 vfox 1.1.0 或更高版本，参见 [docs/zh-CN/link.md](docs/zh-CN/link.md)。
- Linux（x86_64、arm64）、macOS（x86_64、arm64）或 Windows（x86_64、arm64）。
- 安装时需要能访问 GitHub 与 conda-forge。网络慢或被阻断时，参见 [镜像](#镜像)。

## 安装

安装 [vfox](https://github.com/version-fox/vfox) 之后，添加插件：

``` shell
vfox add clang
```

列出可用版本并选择：

``` shell
vfox search clang
```

vfox 会缓存版本列表 12 小时。要重新获取，请在 `--` 之后传入 `--no-cache`：

``` shell
vfox search clang -- --no-cache
```

必须写 `--`：vfox 会把以短横线开头的参数当作自己的选项解析，所以
`vfox search clang --no-cache` 会失败。`--no-cache` 能做什么、不能做什么，参见
[docs/zh-CN/troubleshooting.md](docs/zh-CN/troubleshooting.md#列表没有刷新)。

用 `latest` 标签安装最新版本，或安装列表中的某个版本：

``` shell
vfox install clang@latest
vfox install clang@22.1.3
vfox use clang@22.1.3
```

列表中最新的版本标记为 `latest`。

## 使用本机已有的 clang

如果机器上已经装了 LLVM，例如来自 Homebrew、LLVM 安装程序、apt 或 Visual Studio，
vfox 可以直接使用它，而不必再下载一份：

``` shell
vfox link --detect clang
```

插件会在各平台的常见位置查找，并列出找到的安装。查找的位置和规则参见
[docs/zh-CN/link.md](docs/zh-CN/link.md)。

## 环境变量

| 环境变量    | 默认值                | 说明                                             |
| :---------- | :-------------------- | :----------------------------------------------- |
| Conda_Forge | `conda-forge`         | 安装 clang 所用的 conda 频道                     |
| GITHUB_URL  | `https://github.com/` | GitHub 的基础地址，用于版本列表与 pixi 的下载    |

用法：

``` shell
export Conda_Forge=https://prefix.dev/conda-forge
export GITHUB_URL=https://mirror.example.com/https://github.com/
```

## 镜像

`GITHUB_URL` 会把插件的 GitHub 下载改到镜像：版本列表
（`<GITHUB_URL>/version-fox/vfox-clang/releases/manifest`），以及 pixi 的安装包和它旁边的
`.sha256` 文件（`<GITHUB_URL>/prefix-dev/pixi/releases/latest/download/…`）。插件会用该 SHA-256
核对安装包；镜像若对 `.sha256` 地址既不返回文件也不返回 404，安装会停止，参见
[故障排查](docs/zh-CN/troubleshooting.md#无法获取安装包的-sha-256)。`Conda_Forge` 是 pixi 安装
clang 所用的 conda 频道，可以是 conda-forge 的镜像，例如 `https://prefix.dev/conda-forge`。
请在需要它们的命令之前设置。

## 平台

| 平台    | 架构   | pixi 安装包                              |
| :------ | :----- | :--------------------------------------- |
| Linux   | x86_64 | `pixi-x86_64-unknown-linux-musl.tar.gz`  |
| Linux   | arm64  | `pixi-aarch64-unknown-linux-musl.tar.gz` |
| macOS   | x86_64 | `pixi-x86_64-apple-darwin.tar.gz`        |
| macOS   | arm64  | `pixi-aarch64-apple-darwin.tar.gz`       |
| Windows | x86_64 | `pixi-x86_64-pc-windows-msvc.zip`        |
| Windows | arm64  | `pixi-aarch64-pc-windows-msvc.zip`       |

安装路径可以包含空格，Windows 用户目录和 macOS 账户名常常如此。

Windows arm64 上，conda-forge 只为 `vfox search clang` 列出的部分版本发布 clang。`latest` 是其中之一，请安装 `latest`。安装其他版本会在 pixi 中以错误停止，参见[故障排查](docs/zh-CN/troubleshooting.md#failed-to-execute-command--pixi--global-install)。

## 文档

- [变更记录](docs/zh-CN/changes.md)
- [使用系统 clang](docs/zh-CN/link.md)
- [故障排查](docs/zh-CN/troubleshooting.md)
- [开发](docs/zh-CN/development.md) 与 [端到端测试](docs/zh-CN/e2e.md)

## 发布插件

维护者可以在默认分支上进入 **Actions → Plugin → Run workflow**，输入不带 `v` 前缀的稳定版本号，
发布插件。共享工作流会更新 `metadata.lua`、创建版本提交与标签，并在本仓库发布 ZIP 与 manifest。
无需本地标签，也无需额外的发布令牌。Pull Request 只运行检查；PR 标题不再触发发布。

若 `PLUGIN.version` 已与标签一致，仍支持直接推送版本标签。发布失败时，重新运行原来失败的任务即可继续。

该工作流跟随共享的 `@v1` 发布工具版本，更新工具不会发布本插件。打包约定与首次上线的要求，
参见 [共享工作流文档](https://github.com/version-fox/plugin-manifest-action)。

## 许可证

[Apache License 2.0](LICENSE)
