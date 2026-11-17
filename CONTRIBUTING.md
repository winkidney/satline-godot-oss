# 参与和验证

本地研究版本尚未公开发布。修改前先保留原版与 Godot 对应关系；涉及原作素材、声音或外部资料时记录来源、许可与变更。

- 启动游戏：在 Linux x86_64 上运行 `./run.sh`。
- 校验原版音频生成器：`node --test tools/tests/original_audio.test.cjs`。
- 用隔离静音驱动检查音频资源和设置：`./run.sh --headless --audio-driver Dummy --script res://tools/tests/verify_original_audio.gd`。
- 原始音频重建：`node tools/export_original_audio.cjs`。生成的音频及原始数据涉及原版素材，公开使用前须核权。

报告实际使用的引擎、设备、验证方式和未覆盖范围；固定帧率渲染或历史截图不能替代实时录制、听感和人工画面审阅。不要提交声音参考、克隆数据、凭据、本机配置或其他未获公开许可的内容。
