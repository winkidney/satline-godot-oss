# 本轮验证与边界

本页的历史画面及视频检查基于本机完整项目。GitHub 精简版本保留游戏运行资产与文本记录，未上传视频及非运行所需的研究图像。

验证日期：2026-11-17。历史证据和本次实时录屏的采集条件见[录制条件](recording-evidence.md)，本记录只描述当前整合目录的检查。

## 游戏和资源

将 Godot 项目复制到独立临时目录，排除导入缓存、历史证据和构建目录。使用官方 Godot 4.7.2 编辑器执行 `godot --headless --editor --path <项目副本> --import --quit`，资源导入退出码为 0；随后用复制的固定定制引擎在独立 XWayland、Vulkan Forward+ 和 RTX 4070 SUPER 上启动游戏，达到 `--quit-after 360` 的退出条件后退出，场景加载记录为 729 个节点、292 个网格和 128 张纹理。[导入日志](../media/tests/portable-import.log)和 [GPU 启动日志](../media/tests/portable-gpu-run.log)保留在项目中。

自动退出时 Godot 报告 30 个 ObjectDB 实例泄漏警告；原因和正常游玩退出时是否重现未调查。此检查证明独立副本的资源导入及场景启动，不替代全流程游玩验收。

`node --test tools/tests/original_audio.test.cjs` 通过；独立副本使用 Dummy 音频运行 `res://tools/tests/verify_original_audio.gd`，核对 79 个定义、136 个缓冲、14 个循环及主要事件，默认音量为 80%。真实音频输出检查与迁移近似见[音频方案](audio-port-plan.md)；完整原版与复刻的人工听感比较未完成。

码头墙面修复后，实际场景的[几何检查](../media/tests/quay-geometry-test.log)通过：目标 24 个顶点已分离，其余顶点未改变。正式游戏入口在隔离 GPU 会话中启动并按 `--quit-after 360` 自动退出；[启动日志](../media/tests/quay-game-smoke.log)记录 32 个 ObjectDB 实例泄漏，尚未确认正常游玩退出时是否发生。

## 视频工程和成片

- 在隔离目录使用锁文件执行 `npm ci --ignore-scripts` 成功；Chromium 的另行准备仍需遵循 [Remotion 工程说明](../video/editor/README.md)。
- [当前成片](../video/final.mp4)经 `ffprobe` 检查为 H.264、1920×1080、60 fps、37,192 帧、619.867 秒，AAC 48 kHz 立体声；FFmpeg 使用 `-xerror` 完整解码音视频，退出码为 0。SHA-256：`784cbf8870919e16a41ff6337a116c2188875988029a29ca0e9e18509038d627`。
- 影片包含原版、复刻与内建版本的十类调试场景；透明 MG、字幕和章节栏按时间线编排。片头为 38 秒，片尾的三连为简短动画。已抽查[码头镜头](../video/review/film-v6-quay-shot.webp)和一处内建材质对照；完整成片仍需人工观看。
- 修复后素材用于全部 5 处海面镜头。[版本 6 片头的逐帧检查](../video/review/film-v6-quay-qc.json)覆盖近、远处墙面的上下四个区域，共检查素材第 165–290 帧；四区域最大相邻亮度跳变为 0.30 / 255。检查方法和复现命令见[录制记录](recording-evidence.md#成片)。
- [颜色检查](../video/review/film-v6-color-qc.json)：三类源片到镜头的主体区域 RGB8 平均误差约 1.38–1.44 / 255；8 个镜头抽样中，镜头到拼接画面的误差均为 0，再编码至成片的误差为 0.088–1.140 / 255。该检查针对抽样区域的剪辑与编码链路。
- 成片 AAC 音频流与本版混音逐字节一致。[48 段旁白](../video/review/film-v6-audio-qc.json)的相关性检查得到最大绝对偏移 5.38 毫秒、最低相关系数 0.98737；共 15 段重新生成、33 段沿用。174 条字幕已去掉标点，小数点用“点”表示；字幕按文字长度估计时间，仍须人工逐句核对。
- 从成片帧解码二维码，得到预定的 GitHub 项目地址。配音由 AW 的 Higgs TTS 生成，本地识别标出 7 段应优先试听，具体时间见[配音研究](tts-naturalness.md)；声音自然度和技术词发音仍需人工试听。
- [版本 5 成片](../video/archive/previous-cut-before-v6.mp4) SHA-256：`74153bc591b6b1608875729fd7c53ab74b8b8eac2a4af3ee946852bd8747886d`；其旁白与字幕作为历史版本保留。
- [初版成片](../video/archive/first-cut.mp4) SHA-256：`9336db13b57902305bc212a91ce01d18e02ae5c9554d42d447610fabda6ef52b`；[此前第二版](../video/archive/previous-cut-before-v5.mp4) SHA-256：`fe93a0a2808c99c1a186ae0496b0fed8131c5f1f28b0b5dc70f105decbe4de4c`。

视频保留在本机供审阅。原作及其衍生资源的公开授权和自主代码协议仍待确认；来源与状态见[第三方来源](../THIRD_PARTY_NOTICES.md)。
