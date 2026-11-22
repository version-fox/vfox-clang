# 使用系统 clang

[中文](link.md) | [English](../link.md)

`vfox link --detect clang` 让插件查找本机上已经存在的 LLVM 安装并将其链接进来，vfox 便能把它们当作版本使用，而无需再下载一份。需要 vfox 1.1.0 或更高版本。

``` shell
vfox link --detect clang        # 列出找到的安装，链接前会询问
vfox link --detect clang --yes  # 找到的全部链接
```

每个被链接的安装都会在 `vfox list clang` 中显示其路径：

``` text
-> 19.1.7 (linked → /usr/lib/llvm-19)
```

之后像使用其他版本一样使用它：

``` shell
vfox use clang@19.1.7
```

## 查找的位置

插件只会查看下列位置。一个安装指的是包含 `bin/clang` 的目录（Windows 上是 `bin\clang.exe`），并且它的 `clang --version` 会输出 `clang version X.Y.Z`。

| 平台    | 位置                                                                                    | 备注                         |
| :------ | :-------------------------------------------------------------------------------------- | :--------------------------- |
| Linux   | `/usr/lib/llvm-<N>`、`/usr/lib64/llvm<N>`                                               | 系统 LLVM                    |
| Linux   | `/opt/llvm*`、`/usr/local`                                                              | 安装在 /opt、/usr/local 下   |
| Linux   | `/home/linuxbrew/.linuxbrew/opt/llvm*`、`~/.linuxbrew/opt/llvm*`                        | 由 Homebrew 安装             |
| macOS   | `/opt/homebrew/opt/llvm*`、`/usr/local/opt/llvm*`                                       | 由 Homebrew 安装             |
| macOS   | `/opt/llvm*`、`/usr/local`                                                              | 安装在 /opt、/usr/local 下   |
| Windows | `%ProgramFiles%\LLVM`、`%ProgramFiles(x86)%\LLVM`                                       | 由 LLVM 安装程序安装         |
| Windows | `%ProgramFiles%\Microsoft Visual Studio\<年份>\<版本>\VC\Tools\Llvm\{x64,ARM64,}`        | 随 Visual Studio 提供        |
| Windows | `%USERPROFILE%\scoop\apps\llvm\current`                                                 | 由 Scoop 安装                |
| Windows | `C:\msys64\clang64`、`C:\msys64\ucrt64`                                                 | 由 MSYS2 安装                |
| 全部    | `$CONDA_PREFIX`（已设置时）                                                             | 由 CONDA_PREFIX 指定         |

目录名的匹配规则如下。在系统库目录 `/usr/lib` 和 `/usr/lib64` 中，只匹配 `llvm-<N>` 与 `llvm<N>`。在 `/opt` 以及 Homebrew 的 `opt` 目录中，任何以 `llvm` 开头的名字都会匹配，因此 `llvm@18` 也能被找到。

## 规则

- **从不使用 Apple 自带的 clang。** Command Line Tools 中的 `/usr/bin/clang` 只是一个会提示安装 Command Line Tools 的占位程序，它不是 LLVM。若要在 macOS 上使用 LLVM 自己的 clang，请安装 Homebrew 的 `llvm`。
- **从不报告 `.vfox` 下的安装**，因为那些是 vfox 自己安装的。
- **每个版本只列一次。** 如果同一版本出现在多个位置，插件只列出按上表顺序最先找到的那一处。
- **版本名与 `vfox search clang` 的命名一致**，即 `19.1.7`，不带任何来源后缀。一个版本名只能使用一次：如果某个版本已由 vfox 安装或已被链接，`vfox link --detect` 会跳过它并说明原因。
- 列表按版本从新到旧排序。

## 手动链接安装

任何包含 `bin/clang` 的目录都可以用 vfox 链接为某个版本名：

``` shell
vfox link clang@18.1.8 /opt/custom-llvm
```

该目录的 `bin` 中必须有插件会放入 `PATH` 的可执行文件。若要把已有的链接指向另一个目录，加上 `--force`。

## 删除链接

`vfox uninstall clang@19.1.7` 会删除链接，并保留目录本身：

``` text
Unlinked clang@19.1.7 successfully! /usr/lib/llvm-19 was left untouched.
```
