# 变更记录

[中文](changes.md) | [English](../changes.md)

按发布版本列出用户能感受到的变化。GitHub 的 Release 页面列出了对应的 PR。

## 0.5.3

### 新增

- `vfox link --detect clang` 会查找本机已有的 LLVM 安装并将其链接进来，vfox 直接使用它们，而不必再下载一份。需要 vfox 1.1.0 或更高版本。见 [link.md](link.md)。
- 插件的测试：用 `vfox plugin test` 运行的离线 Lua 钩子测试、用真实 `/bin/sh` 执行安装命令的引号测试，以及分别在 Ubuntu 26.04 容器和 Windows runner 上运行的端到端测试。见 [development.md](development.md) 与 [e2e.md](e2e.md)。
- CI 中的检查：Lua 格式与类型、Go 格式、vet 与单元测试、工作流检查和许可证头。Dependabot 会跟进 Action、Go 模块与 Docker 镜像的更新。
- `.devcontainer/` 提供开发容器，内含 CI 所固定版本的检查工具与 Docker 命令行，端到端套件可以在其中运行。见 [development.md](development.md#开发容器)。
- 中英文文档：README、[使用系统 clang](link.md)、[故障排查](troubleshooting.md)、[开发](development.md)、[端到端测试](e2e.md) 与本变更记录。

### 修复

- `vfox search clang -- --no-cache` 会删除 vfox 为版本列表保存的缓存文件 `.available.cache`，然后打印列表。此前的版本删除的是一个 vfox 从不创建的文件，并且在打印任何内容之前就退出了（[#3](https://github.com/version-fox/vfox-clang/issues/3)）。vfox 会把每个结果存在以参数为键的条目下，并在调用结束后整体回写缓存，所以普通的搜索可能会一直显示之前的列表，直到缓存过期；见 [故障排查](troubleshooting.md#列表没有刷新)。
- README 改为写 `vfox search clang -- --no-cache`。`vfox search clang --no-cache` 在 vfox 1.1.0 与 1.0.13 上都会失败（[vfox#808](https://github.com/version-fox/vfox/issues/808)）。
- 安装失败后不再留下 `.installing` 标记和不完整的 `v-<版本>` 目录：钩子改为抛出错误，而不是调用 `os.exit`，因此 vfox 会自行清理（[#4](https://github.com/version-fox/vfox-clang/issues/4)）。
- pixi 命令会对程序与参数加引号（Unix 与 Windows 均是），因此主目录包含空格时也能安装（[#5](https://github.com/version-fox/vfox-clang/issues/5)）。
- HTTP 请求失败时会说明原因：状态码不是 200 时写出状态码，清单中没有版本列表时明确说明，网络错误则保留原始信息。不再出现关于 nil 值的 Lua 报错（[#6](https://github.com/version-fox/vfox-clang/issues/6)）。
- 识别 macOS。vfox 报告的平台名是 `darwin`，而插件检查的是 `macos`，因此 macOS 上的每次安装都会以 `Unsupported environment` 停止（[#7](https://github.com/version-fox/vfox-clang/issues/7)）。
- 版本列表工具改为在 Update version list 工作流中由源码构建，仓库不再提交 23 MB 的二进制文件。工具中的正则表达式与插件一样，只匹配第一个 `<code>` 块（[#8](https://github.com/version-fox/vfox-clang/issues/8)）。
- 源文件带上 Apache 2.0 许可证头。
