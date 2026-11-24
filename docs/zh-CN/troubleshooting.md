# 故障排查

[中文](troubleshooting.md) | [English](../troubleshooting.md)

## 列表没有刷新

`vfox search clang -- --no-cache` 会重新获取版本列表并打印。vfox 会把每个结果保存在插件的缓存文件中，有效期由 `cache.availableHookDuration` 决定，默认 12 小时，缓存条目以参数组成的键来索引。vfox 在调用插件之前先读取缓存，并在调用结束后把整个缓存回写。因此：

- 新版本发布后第一次运行 `--no-cache`，会拿到新列表。
- 之后再次运行 `--no-cache`，可能打印之前保存的列表，直到该缓存条目过期。
- 普通的 `vfox search clang` 可能会一直显示之前的列表，即使刚运行过 `--no-cache` 也是如此，直到缓存过期。

若要让每次搜索都向 GitHub 请求，关闭 vfox 的缓存：

``` shell
vfox config cache.availableHookDuration 0
```

恢复默认值请运行 `vfox config --unset cache.availableHookDuration`。

`vfox search clang --no-cache` 会失败并提示 `flag provided but not defined: -no-cache`。请像 README 中那样，在标志前加上 `--`。

## Failed to get versions: status 404

插件从 `<GITHUB_URL>/version-fox/vfox-clang/releases/manifest` 读取版本列表。状态码不是 200，说明该地址没有提供列表：`GITHUB_URL` 写错或已过期，或者镜像不可用。请在浏览器中打开该地址，或用 `curl -I` 检查，然后修正 `GITHUB_URL`。

## Failed to get versions: the manifest has no version list

页面返回了 200，但其中没有插件要读取的 `<code>` 块。通常是强制门户或代理的页面代替了 GitHub 返回。请检查网络和镜像，然后重新搜索。

## Failed to get versions: the version list is not valid JSON

`<code>` 块存在，但其中的内容不是合法的 JSON，多半同样是中间的代理或页面在作怪。处理方法相同。

## Failed to get versions: the version list has no conda-forge entry

列表是合法的 JSON，但其中没有 `conda-forge` 条目。插件读取的 manifest 总有这一条，因此该地址提供的是别的内容。请检查 `GITHUB_URL`，然后重新搜索。

## Failed to request the version list

请求根本没有到达服务器：没有网络、DNS 错误、连接被拒绝，或代理丢弃了请求。请检查网络连接和 `GITHUB_URL` 的值。

## 无法获取安装包的 SHA-256

安装前，插件会读取 pixi 在安装包旁边发布的 SHA-256，地址是 `<GITHUB_URL>/prefix-dev/pixi/releases/latest/download/<安装包>.sha256`。返回 404 表示 pixi 没有为该安装包发布 SHA-256：安装会继续，并由 vfox 打印 `Checksum is not provided` 警告。其他响应都会让安装停止：

- `status N`（状态码既不是 200，也不是 404）：该地址没有提供这个文件。请检查 `GITHUB_URL` 和镜像，与版本列表的处理方式相同。
- `has no SHA-256 value`：该地址返回的是一个不是 SHA-256 文件的页面，通常是中间的代理或镜像给出了别的页面。请检查网络和镜像。

## 无法请求安装包的 SHA-256

请求根本没有到达服务器：没有网络、DNS 错误、连接被拒绝，或代理丢弃了请求。请检查网络连接和 `GITHUB_URL` 的值，与版本列表的处理方式相同。

## 压缩包校验和不符

症状：安装打印 `Verifying checksum <sha256>...`，接着打印 `Checksum error, file: <路径>`，并在解压之前停止。

下载到的安装包不是 pixi 发布 SHA-256 时对应的那个文件。通常是下载中途被截断或在途中被改动，或者镜像上放的是另一个文件。请重新安装。如果安装过程中 pixi 发布了新版本，安装包与它的 SHA-256 可能分属两个版本；再次安装时，两者都会取自新版本。

## Failed to execute command: ... pixi ... global install

pixi 无法从 conda 频道安装 clang。错误信息中会显示失败的命令，其上方输出的 pixi 日志说明了原因。常见原因是 conda-forge 被阻断或速度很慢、`Conda_Forge` 的值不是一个频道，或者 conda-forge 没有为该平台发布所选的版本。在 Windows arm64 上，`vfox search clang` 列出的大多数版本都没有发布，参见[平台](../../README_CN.md#平台)。遇到最后一种情况，请安装 `latest`；否则请重新运行安装：失败的安装不会留下任何残留，因此重试会从干净的状态开始。

## Unsupported version: X

该版本不在插件读取的列表中。运行 `vfox search clang` 查看可用版本；如果列表已过期，改用 `vfox search clang -- --no-cache`。

## Unsupported platform: X-Y

vfox 以 `<系统>-<架构>` 的形式报告平台，例如 `freebsd-amd64`，错误信息会写出该平台。插件支持 Linux x86_64 与 arm64、macOS x86_64 与 arm64，以及 Windows x86_64 与 arm64。在其他平台上，安装会在下载任何内容之前停止。信息之后的 `no installable runtime provided` 是 vfox 对这次停止的报告。

## unexpected EOF while downloading

下载过程中连接被切断，多见于网络不稳定或镜像。请重新运行同一条命令。

## `vfox link --detect clang` 没有找到任何安装

- 安装目录必须包含 `bin/clang`（Windows 上为 `bin\clang.exe`），并且位于 [link.md](link.md) 列出的位置之一。
- `clang --version` 必须输出 `clang version X.Y.Z`。Apple 自带的 clang 永远不会被使用。
- `.vfox` 下的安装永远不会被报告，因为它们是 vfox 安装的。

## 安装被中断

如果 vfox 在安装过程中被强制结束，它会在缓存目录中为该版本留下一个 `.installing` 标记和一个不完整的 `v-<版本>` 目录。下一次对同一版本执行 `vfox install` 时，会先删除不完整的目录，然后从头开始。vfox 报告为错误的安装失败则会自行清理。
