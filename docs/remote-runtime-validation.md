# 仓库精简版本验证

验证日期：2026-11-17。验证对象是从精简 Git 历史创建的独立工作副本；未使用本机完整项目中的录像、预烘焙对照贴图或 Godot 导入缓存。

## GitHub 干净克隆复验

- 从 GitHub 克隆 `main`，移除本次测试生成的导入缓存，应用首次启动脚本及资源标识改动后执行 `./run.sh`。脚本自动调用官方 Godot 4.7.2 导入资源，随后在隔离 Xvfb、Vulkan Forward+ 会话中启动兼容引擎；日志没有脚本、着色器或资源加载错误。
- 按 `python3 saltline-godot/engine/build_engine.py --jobs 8` 从固定源码及补丁完整重建引擎，生成文件的 SHA-256 与仓库内引擎完全一致。由于默认 Python 包站点下载超时，固定版本的构建依赖改从镜像下载，并与 PyPI 官方 SHA-256 核对后使用。
- 菜单加载后通过隔离会话点击 `DEPLOY`，已进入集装箱游戏场景；菜单和游戏截图只保存在本机。场景记录为 729 个节点、292 个网格和 128 张纹理。
- `node --test tools/tests/run_launcher.test.cjs tools/tests/original_audio.test.cjs` 通过；使用 Dummy 音频驱动运行 Godot 音频检查，核对 79 个声音定义、136 个缓冲和 14 个循环。
- 引擎自动退出时记录 32 个 ObjectDB 实例泄漏警告；真实音频输出与完整游戏流程未在本次复验中检查。

## 此前的精简版本验证

- 将精简版本与本机完整历史的 `saltline-godot/assets/` 和 `saltline-godot/engine/godot` 逐条比较，原有 3,750 个 Git 条目的路径、模式及对象哈希完全一致。
- 官方 Godot 4.7.2 从零导入游戏资源，退出码为 0。随后使用项目内的兼容引擎，在独立 Xvfb、Vulkan Forward+ 和 NVIDIA GeForce RTX 4070 SUPER 下启动并设置 `--quit-after 360`，退出码为 0。导入和启动日志保存在本机；游戏场景报告加载了 729 个节点、292 个网格和 128 张纹理。
- 验证使用 Dummy 音频驱动，没有核对实际声音输出；退出时记录了 Xvfb 输入法警告和 34 个 ObjectDB 实例泄漏警告。该检查证明资源导入和场景启动，不代表完整游玩、真实性能或声音听感验收。
- 导入时生成了游戏音频的 Godot `.import` 文件及部分脚本 `.uid` 文件，已作为可复现的资源元数据纳入精简仓库。兼容引擎 SHA-256：`639baccce7c7c63638da889fba58b3797316b09be1df9da0bd49c839af1a5788`。

资料范围和本地完整历史的提交对应关系见[仓库资料范围](remote-scope.md)。
