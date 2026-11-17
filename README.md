# Saltline：Godot 复刻与渲染研究

本项目将浏览器游戏 Saltline 的渲染研究、Godot 复刻、原版音频迁移和视频制作资料放在一起。项目当前为**本地研究版本**：原作及衍生素材的公开授权仍待核实，不能据此公开再分发或宣称整包已经开源。

## 运行游戏

首版面向 Linux x86_64，需要支持 Vulkan Forward+ 的显卡驱动及 X11 / XWayland。项目内包含固定版本的兼容引擎和已准备的导入数据：

```sh
./run.sh
```

若从不含导入缓存的源码包开始，先用官方 Godot 4.7.2 编辑器执行 `godot --headless --editor --path saltline-godot --import --quit`，再运行 `./run.sh`。正式游戏仍使用项目内的定制引擎；官方编辑器用于导入资源。

WASD 移动，鼠标转向，左键射击，右键瞄准，R 换弹，1 / 2 切换武器，E 按住与中继交互，Esc 暂停。设置中的 `MASTER VOLUME` 默认 80%，可保存调整。

定制引擎基于 Godot 4.7.2；补丁、固定源码和构建依据见[引擎说明](saltline-godot/engine/README.md)。在独立目录重新导入资源后，136 个声音缓冲及主要事件已通过自动检查；画面和玩法的历史技术验证以各自记录的设备与版本为准。

## 从哪里开始学习

- [观看完整视频](video/final.mp4)：约 10 分 48 秒，1080p / 60 fps，含原版、定制复刻与调校后的官方 Godot 对照、旁白和中文字幕。
- [成片画面：片头](video/stills/opening.png)、[光照对照](video/stills/lighting.png)和[项目来源](video/stills/sources.png)；[原始实录](video/recordings/)与[剪辑工程](video/editor/README.md)也保留在本地。
- [视频旁白与实际分镜](video/storyboard-v5.md)：13 章，包含逐镜头时间、画面来源和技术原理示意。
- [官方 Godot 调校与质检](docs/builtin-calibration.md)：十类场景的参数、逐项差异和复现方法；[对照图 1](video/review/comparisons/showcases-01.webp) · [对照图 2](video/review/comparisons/showcases-02.webp)。
- [原版与复刻的事实、来源和参考图](docs/source-evidence.md)：每个效果的原始实现、对应代码与证据。
- [三个应用场景与 AI 提示词](docs/scene-and-ai-prompts.md)：雨后地面、室内光束和角色布料。
- [原版音频迁移](docs/audio-port-plan.md)：原始生成器、事件、混音及验证边界。
- [录制条件与实测证据](docs/recording-evidence.md)：原版与 Godot 运行条件、帧率、同步及机位限制。
- [视频颜色处理与检查](docs/video-color-pipeline.md)：不同来源的色彩范围、转换和拼接验证。
- [配音自然度研究](docs/tts-naturalness.md)：AW 参考音频、逐字稿和试听流程。
- [完整制作与交付状态](docs/production-plan.md)。
- [本轮验证和待核对事项](docs/validation.md)。

`artifact-rendering-study/` 保存原版拆解、示例和历史证据；`saltline-godot/` 保存游戏、引擎补丁和复刻证据；`builtin-godot/` 保存官方引擎对照；`video/` 保存脚本、录制素材和成片。历史录屏、固定步进画面与实时录制分别标记。

## 授权和隐私

原版 HTML、由其生成的资源与声音、字体、引擎及其他第三方组件分别记录在[第三方来源](THIRD_PARTY_NOTICES.md)；每项独立核实授权。声音参考、逐字稿、克隆数据与授权记录只保存在私有工作区，不纳入项目分发。获授权的合成旁白只用于本片及其必要制作材料。

制作配音使用 Asset Workbench 和 Boson AI 的 Higgs Audio；成片及随附说明保留模型要求的署名。项目的自主代码许可待原作授权核实后决定。
