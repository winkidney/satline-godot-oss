# 剪辑工程

GitHub 精简版本保留剪辑脚本、时间线和制作配方；录屏、成片、音乐音频和图像素材保留在本机，不包含私有旁白。没有这些素材时不能直接导出完整影片。

这是 1920×1080、60 fps 的视频制作工程。当前成片使用 `src/film-plan.json`、`scripts/render_film.py` 和 `../recordings/showcases/` 的十类调试场景；原版、定制复刻、官方内建分别采集，画面标注来源和非同步操作。官方内建视频逐帧固定步进输出，其编码帧率不是实时性能。具体录制条件见[实录记录](../../docs/recording-evidence.md)。

海面镜头使用 `../recordings/godot/sea-quay-fixed.mp4`，由修复后场景以固定步进重新录制；修复前的历史海面录像继续保留，不再用于成片。

当前导出需要 FFmpeg（含 libass 和 H.264 NVENC）、Pillow、NumPy、Fontconfig 和 `Noto Sans CJK SC`，以及本片授权生成的私有旁白。`python3 scripts/render_film.py --prepare-only` 生成实际时间线、分镜、字幕与图形，去掉参数输出完整成片；旧成片及字幕会先保存在 `../archive/`，不会覆盖已有不同内容的同名备份。旁白及参考音频不随项目公开，没有授权旁白时不能重建带配音成片。

原理 MG 与镜头按旁白片段对齐；原理图只绘制节点、连线和图标，不放整块底板。单画面和并排画面保留完整比例，图形、字幕与底部章节栏各有独立安全区域。

本片私有旁白仍在本机时，可从项目根目录运行 `python3 video/tools/check_film_audio.py`，逐段比较源 WAV 和 AAC 混音的时间偏移与相关性；需额外安装 SciPy。该检查不判断发音或声音自然度。

不同来源的色彩范围先转换到统一 SDR 格式再拼接；方法及假设见[视频颜色处理](../../docs/video-color-pipeline.md)。渲染后从项目根目录运行 `python3 video/tools/check_film_color.py` 可复核抽样像素与颜色漂移。

下列 Remotion 文件保留此前的剪辑版本。`src/timeline.js` 和 `src/media.json` 分别保存旧版章节与素材时间线；`public/footage/` 中的 60 fps 代理补齐的编码帧不代表游戏实际帧率。

需要 Node.js、FFmpeg、Chromium 和可用的视频素材。在本目录运行：

```sh
npm ci
npm run studio
npm run render
```

此前的第二版成片使用 `npm run render-fast` 导出：先从初版素材生成无字幕画面与混音，再按旁白片段将每段间隔减半，重新输出章节栏和字幕。旁白片段不会被剪切，结尾三连动画保留；源时间到新时间的映射保存在 `src/revision.json`。Remotion 的 `SaltlineFilm` 使用同一映射，`FirstCut` 保留初版编排，历史视频与字幕在 `../archive/`。

旧版快速导出需要 FFmpeg、Pillow、NumPy、支持 H.264 NVENC 的 NVIDIA 驱动、`libass`、Fontconfig 与 `Noto Sans CJK SC`。它与 Remotion 是两套渲染器，图形细节可能略有不同。重用中间章节时仅检查时长；修改初版时间线或画面后应删除 `.render/chapter-*.mp4` 再导出，避免复用旧画面。当前字幕保存在 `../subtitles.srt`，时间按各旁白段文字长度估计，仍须人工逐句核对。

声音样本、参考音频、参考逐字稿和克隆数据不在公开分发范围。若本地没有本片获授权的旁白片段，可执行 `npm run prepare-silent` 创建**静音占位**，以检查画面和字幕；它不会覆盖已有音频。克隆旁白在本地由 AW 生成，使用受保护的 `public/private-voice/`，不是构建公开项目所需的凭据或模型。

`../music/` 的氛围配乐独立生成；游戏声音的来源和目前的近似边界见[音频记录](../../docs/audio-port-plan.md)。视频、截图和原版资源的公开分发仍需先核实各自权利。
