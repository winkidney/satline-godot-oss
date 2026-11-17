# 本轮验证与边界

验证日期：2026-11-17。历史证据和本次实时录屏的采集条件见[录制条件](recording-evidence.md)，本记录只描述当前整合目录的检查。

## 游戏和资源

将 Godot 项目复制到独立临时目录，排除导入缓存、历史证据和构建目录。使用官方 Godot 4.7.2 编辑器执行 `godot --headless --editor --path <项目副本> --import --quit`，资源导入退出码为 0；随后用复制的固定定制引擎在独立 XWayland、Vulkan Forward+ 和 RTX 4070 SUPER 上启动游戏，达到 `--quit-after 360` 的退出条件后退出，场景加载记录为 729 个节点、292 个网格和 128 张纹理。[导入日志](../media/tests/portable-import.log)和 [GPU 启动日志](../media/tests/portable-gpu-run.log)保留在项目中。

自动退出时 Godot 报告 30 个 ObjectDB 实例泄漏警告；原因和正常游玩退出时是否重现未调查。此检查证明独立副本的资源导入及场景启动，不替代全流程游玩验收。

`node --test tools/tests/original_audio.test.cjs` 通过；独立副本使用 Dummy 音频运行 `res://tools/tests/verify_original_audio.gd`，核对 79 个定义、136 个缓冲、14 个循环及主要事件，默认音量为 80%。真实音频输出检查与迁移近似见[音频方案](audio-port-plan.md)；完整原版与复刻的人工听感比较未完成。

## 视频工程和成片

- 在隔离目录使用锁文件执行 `npm ci --ignore-scripts` 成功；Chromium 的另行准备仍需遵循 [Remotion 工程说明](../video/editor/README.md)。
- [当前成片](../video/final.mp4)经 `ffprobe` 检查为 H.264、1920×1080、60 fps、38,852 帧、647.533 秒，AAC 48 kHz 立体声；FFmpeg 使用 `-xerror` 完整解码音视频，退出码为 0。SHA-256：`11f8ac595564f05de42379306a976d86744ca458cc6b932cdf00face1bf3271f`。
- 逐类检查了原版、复刻与内建版本的十个调试场景；镜头按段落与原理 MG 对齐，透明 MG、字幕和章节栏避开主要画面。片头 45 秒，片尾的三连仅为简短动画。[成片抽帧](../video/review/film-v5-qc-contact.webp)覆盖片头、光照、湿润、动作、应用和片尾；湿润实验抽查了反射开关前后。
- [颜色检查](../video/review/film-v5-color-qc.json)：三类源片到镜头的主体区域 RGB8 平均误差约 1.38–1.44/255；8 个镜头抽样中，镜头到拼接画面的误差均为 0，再编码至成片的误差为 0.088–1.148/255。武器和 PBR 样本没有重现旧版的明显黑位抬升；这些检查不代表整片或跨引擎逐像素一致。
- [48 段旁白](../video/review/film-v5-audio-qc.json)与成片 AAC 混音逐段做了相关性检查：最大绝对偏移 5.38 毫秒、最低相关系数 0.98923；成片平均音量 −23.4 dB、采样峰值 −8.8 dB。该检查不能判断语音内容或听感。185 条字幕已去掉标点，小数点用“点”表示；字幕按文字长度估计时间，仍须人工逐句核对。
- 从成片帧解码二维码，得到预定的 GitHub 项目地址；页面仍待公开。配音由 AW 的 Higgs TTS 生成，本地识别标出 5 段应优先试听，具体见[配音研究](tts-naturalness.md)；声音自然度、技术词发音及完整成片仍需人工观看和试听。
- [初版成片](../video/archive/first-cut.mp4) SHA-256：`9336db13b57902305bc212a91ce01d18e02ae5c9554d42d447610fabda6ef52b`；[此前第二版](../video/archive/previous-cut-before-v5.mp4) SHA-256：`fe93a0a2808c99c1a186ae0496b0fed8131c5f1f28b0b5dc70f105decbe4de4c`。

项目和视频当前仅供本地或私有审阅。原作及其衍生资源的公开授权、自主代码协议、未来公开地址的实际访问性，均须在发布前确认；不能从本记录推断已获公开分发权。
