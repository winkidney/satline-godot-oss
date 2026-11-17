# 剪辑工程

这是 1920×1080、60 fps 的 Remotion 工程。`src/timeline.js` 保存章节、MG 图示和节奏；`src/media.json` 保存镜头、旁白及字幕的时间线。原版与复刻是分别实时录制的画面，标注“非同步操作”。原始录像保留在 `../recordings/`，`public/footage/` 中的 60 fps 代理用于剪辑，补齐的编码帧不代表游戏实际帧率。

需要 Node.js、FFmpeg、Chromium 和可用的视频素材。在本目录运行：

```sh
npm ci
npm run studio
npm run render
```

新版成片使用 `npm run render-fast` 导出：先从初版素材生成无字幕画面与混音，再按旁白片段将每段间隔减半，重新输出章节栏和字幕。旁白片段不会被剪切，结尾三连动画保留；源时间到新时间的映射保存在 `src/revision.json`。Remotion 的 `SaltlineFilm` 使用同一映射，`FirstCut` 保留初版编排，初版视频与字幕在 `../archive/`。

快速导出需要 FFmpeg、Pillow、NumPy、支持 H.264 NVENC 的 NVIDIA 驱动、`libass`、Fontconfig 与 `Noto Sans CJK SC`。它与 Remotion 是两套渲染器，图形细节可能略有不同。重用中间章节时仅检查时长；修改初版时间线或画面后应删除 `.render/chapter-*.mp4` 再导出，避免复用旧画面。新版字幕同时输出为 `../subtitles.srt`，时间按各旁白段文字长度估计，仍须人工逐句核对。

声音样本、参考音频、参考逐字稿和克隆数据不在公开分发范围。若本地没有本片获授权的旁白片段，可执行 `npm run prepare-silent` 创建**静音占位**，以检查画面和字幕；它不会覆盖已有音频。克隆旁白在本地由 AW 生成，使用受保护的 `public/private-voice/`，不是构建公开项目所需的凭据或模型。

`../music/` 的氛围配乐独立生成；游戏声音的来源和目前的近似边界见[音频记录](../../docs/audio-port-plan.md)。视频、截图和原版资源的公开分发仍需先核实各自权利。
