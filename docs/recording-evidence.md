# 实录条件与验证

本页记录本机完整项目的拍摄和验证。GitHub 精简版本不包含视频、录屏及非运行所需的研究图像；指向这些材料的链接仅在本机完整项目可用。

本片的原版、定制复刻和官方内建版本分别采集，再按场景与动作剪辑对齐；**不是同步操作，也不是逐帧基准测试**。正式游戏实录使用机位跳转和无敌辅助，没有固定游戏步长；调试场景与逐帧输出的条件见下文。

| 内容 | 实际条件 | 实测 |
| --- | --- | --- |
| 原版浏览器 | 本地 HTML，`q=high&dynres=0&autostart=1`；1920×1080 游戏画布；WebAudio 同步录入 | 五段分别约 58.0、58.3、58.4、58.4、58.4 个游戏渲染帧/秒；各段游戏错误列表为空 |
| Godot 复刻 | Linux、定制 Godot 4.7.2、Vulkan Forward+；RTX 4070 SUPER；隔离的 1920×1080、60 Hz Wayland/XWayland 会话 | 290.02 秒；游戏进程记录平均 59.89 个渲染帧/秒，逐帧间隔 P95 18.76 ms、P99 20.47 ms；54 个拍摄操作已执行 |
| 独立教学实验 | 原生 Godot 4.7.2；同一显卡和隔离显示会话 | 与正式复刻分开标注；具体帧数和操作见 `video/recordings/lab/recording.json` |

原版直接录制 WebGL 画布与其 WebAudio 输出，因此不包含原版 HTML HUD；Godot 录的是完整游戏窗口，包含 HUD。两边使用各自的正常实时主循环，选择的观察角度及游戏状态仍有差异。Godot 在独立会话内运行，原用户桌面和其他应用的音频未纳入录制。

Godot 原始录屏为可变时间戳，视频 1920×1080、H.264，音频 48 kHz 立体声 AAC；编辑代理及成片使用 60 fps 时间线。视频封装或代理的 60 fps 不应被当作游戏实际渲染帧数。录制期间的每秒帧数与帧间隔保存在 `video/recordings/godot/recording.json`，画面和编码日志分别在同目录。

## 十类调试场景

| 内容 | 采集条件与实测 |
| --- | --- |
| 原版 `showcases/original/` | 浏览器以 1920×1080 分别实时录制十类场景；按各自帧计数和时长计算，约 59.8–60.1 个画面帧/秒。`original-frozen/enemies` 额外冻结机器人姿态，718 帧／12.003 秒，便于与内建静态姿态比较。 |
| 定制复刻 `showcases/replica/` | 十类场景分别录制，实际回调约 18.3–20.1 次/秒；其中材质、道具、渲染、湿地、武器和双手使用固定的 1/60 秒模拟步进。编码为 60 fps 不代表引擎实时达到 60 fps。 |
| 官方内建 `showcases/builtin-calibrated/` | 十类场景使用原生 Godot 4.7.2 Movie Maker 在 GPU 逐帧输出，固定 1/60 秒模拟步进，每段保留 480 帧／8 秒；每次生成实际耗时约 35–44 秒，不是实时帧率。官方材质与环境已调校，天空、部分动画与程序化材质为近似。 |
| 标准材质教学 `showcases/lab/` | 原生 Godot 的静态 PBR、漫反射和透明层演示；实际回调帧数未单独测量。 |

各段 JSON 保存实际采集条件；[逐场景对照图](../video/review/comparisons/showcases-01.webp)和[第二组对照图](../video/review/comparisons/showcases-02.webp)使用重新调校后的内建素材。单张截图不能证明动态一致，尤其是雨、烟、爆炸和反射。

## 码头修复后重录

复刻的[海面与码头素材](../video/recordings/godot/sea-quay-fixed.mp4)于 2026-11-17 在隔离 Xvfb、RTX 4070 SUPER 和项目内定制引擎上重录，1920×1080、480 帧、60 fps、8 秒、无音轨。使用 `--sea-preview` 和 Movie Maker 固定步进，实际生成约 51 秒，不能作为实时帧率证据。原始 [Movie Maker 录像](../video/recordings/godot/sea-quay-fixed.raw.avi)和修复前 `saltline-godot/evidence/native-sea.mp4` 均保留在本地；它们不上传到精简仓库。

原始 AVI SHA-256：`cb125c93fa1c625f9ad9e725540fff063be66250f324fe0f7079b84042271538`。剪辑用 MP4 SHA-256：`3d9f12cfd37e520680543bd7acf69fecaa453533dff67a9a126c3a9858845552`。画面边缘重合的原因、调整范围和逐帧检测结果见[码头边缘闪烁修复](../saltline-godot/docs/sea.md#码头边缘闪烁修复)。

在项目根目录复录需要已导入的 Godot 资源、Xvfb、rsync、可用的 Vulkan GPU、带 NVENC 的 FFmpeg 和 NumPy。以下命令把所有中间输出留在新临时目录，不覆盖既有录像；最终剪辑素材要另行放到 `video/recordings/godot/sea-quay-fixed.mp4`：

```sh
SATLINE_QUAY_SCRATCH=$(mktemp -d)
mkdir -p "$SATLINE_QUAY_SCRATCH/project/evidence"
rsync -a --exclude /assets --exclude /engine --exclude /evidence --exclude /docs saltline-godot/ "$SATLINE_QUAY_SCRATCH/project/"
ln -s "$PWD/saltline-godot/assets" "$SATLINE_QUAY_SCRATCH/project/assets"
SATLINE_QUAY_PROJECT="$SATLINE_QUAY_SCRATCH/project/project.godot" python3 -c 'import os; from pathlib import Path; p=Path(os.environ["SATLINE_QUAY_PROJECT"]); s=p.read_text(); assert s.count("viewport_width=1280")==1 and s.count("viewport_height=720")==1; p.write_text(s.replace("viewport_width=1280","viewport_width=1920").replace("viewport_height=720","viewport_height=1080"))'
xvfb-run -a -s '-screen 0 1920x1080x24' env XDG_CONFIG_HOME="$SATLINE_QUAY_SCRATCH/config" XDG_DATA_HOME="$SATLINE_QUAY_SCRATCH/data" XDG_CACHE_HOME="$SATLINE_QUAY_SCRATCH/cache" saltline-godot/engine/godot --audio-driver Dummy --display-driver x11 --rendering-driver vulkan --disable-vsync --fixed-fps 60 --write-movie "$SATLINE_QUAY_SCRATCH/quay.avi" --path "$SATLINE_QUAY_SCRATCH/project" -- --sea-preview
python3 video/tools/check_quay_flicker.py "$SATLINE_QUAY_SCRATCH/quay.avi"
ffmpeg -n -i "$SATLINE_QUAY_SCRATCH/quay.avi" -vf 'scale=in_range=pc:out_range=pc:in_color_matrix=bt601:out_color_matrix=bt601,format=yuv420p' -an -c:v h264_nvenc -preset p5 -cq 18 -b:v 0 -g 120 -bf 0 -pix_fmt yuv420p -color_range pc -colorspace bt470bg -color_primaries bt709 -color_trc iec61966-2-1 -r 60 -movflags +faststart "$SATLINE_QUAY_SCRATCH/quay.mp4"
python3 video/tools/check_quay_flicker.py "$SATLINE_QUAY_SCRATCH/quay.mp4"
```

## 音画同步抽查

对原始录屏，按画面枪口附近亮度变化和 10 ms 音频能量窗口估计枪声瞬态：开头约 5.91 秒声音、5.933 秒画面；末尾约 281.91 秒声音、281.939 秒画面。两次音频领先约 23–29 ms，差值约 6 ms。检测阈值、画面亮度和混响都会影响结果，这只是两处自动抽查，仍需人工试听及逐帧确认，不能视为整片同步保证。

## 来源标识

- 本地原版 HTML SHA-256：`b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb`。尚未与远端 Artifact 逐字节核验。
- 定制 Godot 可执行文件 SHA-256：`639baccce7c7c63638da889fba58b3797316b09be1df9da0bd49c839af1a5788`。
- Godot 原始实录 SHA-256：`263e2d56032a8110601b72ea510c30f0644789546db8fe72cd88fcc78581b960`。

剪辑代理、字幕、配乐和 MG 的制作方式见 [剪辑工程](../video/editor/README.md)。原始录像及其元数据应与成片一起保留；公开前还需核实原作素材及声音的使用许可。

## 成片

本地成片 `video/final.mp4`（[Bilibili 在线观看](https://www.bilibili.com/video/BV1ZYs66uE5J/#reply117632258871740)）为 619.867 秒、H.264 1920×1080、60 fps、37,192 帧，AAC 48 kHz 立体声；完整音视频解码通过。此前的[版本 5 成片](../video/archive/previous-cut-before-v6.mp4)为 647.533 秒，[第二版成片](../video/archive/previous-cut-before-v5.mp4)为 541.77 秒，初版成片为 640 秒。输出编码帧数不代表原版或复刻录制时始终达到 60 fps。当前成片的截图、音频与颜色验证见[验证记录](validation.md)；二维码指向 GitHub 项目首页，片尾的“项目待公开”是制作时的标记。

码头修复后，影片中 5 处海面镜头均换成新录素材，修复前成片保留在 `video/archive/previous-cut-before-v5-revision-03.mp4`。新素材使用固定步进，其他录屏保持各自原有的采集条件；版本 6 旁白的更新情况见[配音研究](tts-naturalness.md)。

版本 6 的片头码头镜头位于 00:09.50–00:14.25。[成片逐帧记录](../video/review/film-v6-quay-qc.json)检查其中相当于素材第 165–290 帧的画面：跟踪近远处墙面的上下四个区域，相邻帧平均亮度的最大跳变为 0.30 / 255。以下命令提取无损中间片并复核；提取起点比镜头早 12 帧，用于对齐原素材的帧号，检查范围均在码头镜头内：

```sh
SATLINE_FILM_QA=$(mktemp -d)
ffmpeg -i video/final.mp4 -vf 'trim=start_frame=558:end_frame=849,setpts=PTS-STARTPTS,scale=1280:720' -an -c:v ffv1 -level 3 "$SATLINE_FILM_QA/opening.mkv"
python3 video/tools/check_quay_flicker.py "$SATLINE_FILM_QA/opening.mkv" --end-frame 290
```
