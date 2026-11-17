# 本轮验证与边界

验证日期：2026-11-17。历史证据和本次实时录屏的采集条件见[录制条件](recording-evidence.md)，本记录只描述当前整合目录的检查。

## 游戏和资源

将 Godot 项目复制到独立临时目录，排除导入缓存、历史证据和构建目录。使用官方 Godot 4.7.2 编辑器执行 `godot --headless --editor --path <项目副本> --import --quit`，资源导入退出码为 0；随后用复制的固定定制引擎在独立 XWayland、Vulkan Forward+ 和 RTX 4070 SUPER 上启动游戏，达到 `--quit-after 360` 的退出条件后退出，场景加载记录为 729 个节点、292 个网格和 128 张纹理。[导入日志](../media/tests/portable-import.log)和 [GPU 启动日志](../media/tests/portable-gpu-run.log)保留在项目中。

自动退出时 Godot 报告 30 个 ObjectDB 实例泄漏警告；原因和正常游玩退出时是否重现未调查。此检查证明独立副本的资源导入及场景启动，不替代全流程游玩验收。

`node --test tools/tests/original_audio.test.cjs` 通过；独立副本使用 Dummy 音频运行 `res://tools/tests/verify_original_audio.gd`，核对 79 个定义、136 个缓冲、14 个循环及主要事件，默认音量为 80%。真实音频输出检查与迁移近似见[音频方案](audio-port-plan.md)；完整原版与复刻的人工听感比较未完成。

## 视频工程和成片

- 在隔离目录使用锁文件执行 `npm ci --ignore-scripts` 成功；Chromium 的另行准备仍需遵循 [Remotion 工程说明](../video/editor/README.md)。
- [新版成片](../video/final.mp4)经 `ffprobe` 检查为 1920×1080、60 fps、32,506 帧、约 541.77 秒，AAC 48 kHz 立体声；使用 FFmpeg 完整解码音视频并启用 `-xerror`，退出码为 0。新版 SHA-256：`fe93a0a2808c99c1a186ae0496b0fed8131c5f1f28b0b5dc70f105decbe4de4c`。
- 初版 640 秒，按旁白时间将片段间隔减半，移除了约 98.23 秒；剪切区间不与旁白重叠，片尾三连动画保留。35 段旁白在剪切后的 PCM 中间区间与初版混音逐样本一致；成片 AAC 在各段中间区间与剪切后 PCM 的最低相关系数为 0.99981。这些数字验证时间映射，不能代替人工试听。
- 143 条字幕均已去掉标点；小数点用“点”表示以保留读法。抽查片头、多个章节、字幕、历史画面对照和片尾；从新版成片帧解码二维码得到预定的 GitHub 项目地址，页面仍待公开。新版一处同画面对照的 RGB 平均差约 1.11/255，仅用于检查编码前后的画面异常。
- [初版成片](../video/archive/first-cut.mp4) SHA-256：`9336db13b57902305bc212a91ce01d18e02ae5c9554d42d447610fabda6ef52b`。
- 配音由 AW 的 Higgs TTS 生成；文本识别用于初筛，声音自然度、英语与技术词发音仍需人工试听。字幕按各旁白段文字长度估计时间，需要人工逐句核对。

项目和视频当前仅供本地或私有审阅。原作及其衍生资源的公开授权、自主代码协议、未来公开地址的实际访问性，均须在发布前确认；不能从本记录推断已获公开分发权。
