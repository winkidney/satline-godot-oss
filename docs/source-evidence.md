# 旁白事实与来源索引

这是旁白与图形分镜的证据索引，路径指向本项目内保存的原版研究和 Godot 复刻。每个条目说明证据范围，不能把局部对照扩大为整个游戏一致。

| 编号 | 事实和对应材料 | 限制 |
| --- | --- | --- |
| E01 | [本地原版来源与拆解](../artifact-rendering-study/docs/source-and-evidence.md)；[原作 HTML](../artifact-rendering-study/source/saltline.original.html) | 用户提供文件的 SHA-256 为 `b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb`；远端 Artifact 与本地文件未核对。旧版 `legacy-v8` 已存档，未做相同深度研究。 |
| E02 | [原版运行与开关对照](../artifact-rendering-study/docs/runtime-findings.md)；[Godot 技术验收](../saltline-godot/docs/current-completion-audit.md) | 原作消融使用固定曝光和研究副本；单项开关不代表清空所有相关光照。 |
| E03 | [体积光实现](../saltline-godot/docs/volume.md)；[16 组 GPU 对照](../saltline-godot/evidence/volume-gpu-verification.json) | 对照是受控输入和指定后端，不等于所有游戏画面逐像素一致。 |
| E04 | [原作反射拆解](../artifact-rendering-study/docs/surfaces-fx-and-cloth.md)；[Godot 平面反射](../saltline-godot/docs/planar-reflection.md)；[兼容引擎说明](../saltline-godot/engine/README.md) | 高保真反射路径依赖定制引擎补丁；独立教学实验是近似。 |
| E05 | [原作材质与湿润](../artifact-rendering-study/docs/materials-and-textures.md)；[Godot 湿润记录](../saltline-godot/docs/wet-surface.md)；[干湿实验](../artifact-rendering-study/docs/godot-experiments.md) | 单项 wet 噪声对照不是全部材质、全部设备和全部画面的证明。 |
| E06 | [材质/贴图拆解](../artifact-rendering-study/docs/materials-and-textures.md)；[衣袖材料坐标](../artifact-rendering-study/docs/surfaces-fx-and-cloth.md)；[微细节实验](../artifact-rendering-study/docs/godot-experiments.md) | 原版 fabric 不是尼龙丝袜；部分复刻纹理由原作运行数据导出后加载。 |
| E07 | [光栅方向阶段记录](../saltline-godot/docs/implementation-status.md)；[引擎兼容说明](../saltline-godot/docs/engine-compatibility.md) | 武器局部 MAE 是历史受控样本；旧文档中的引擎版本以当前引擎 README 顶部说明为准。 |
| E08 | [武器实时手臂](../saltline-godot/docs/source-weapon-live-arms.md)；[手臂 IK](../saltline-godot/docs/source-weapon-arm-ik.md)；[敌人实现](../saltline-godot/docs/enemy-implementation.md) | 这些记录跨多个实施阶段；旧待办以最终验收和最新实现为准。 |
| E09 | [曝光与后处理](../saltline-godot/docs/post-composite.md)；[原版亮暗适应实测](../artifact-rendering-study/docs/runtime-findings.md)；[96 组后处理对照](../saltline-godot/evidence/post-gpu-verification.json) | 自动曝光数据属于固定场景；96 组使用受控输入，不代表所有动态画面。 |
| E10 | [当前固定机位对照](../saltline-godot/evidence/main-paired-high-r16-audit-comparison.json)；[历史室内对照](../saltline-godot/evidence/main-paired-high-interior-comparison.json)；[历史室内临时灯光匹配诊断](../saltline-godot/evidence/interior-highlight-origin-matched-pool.json) | 室内图为历史版本；匹配灯光后局部差异缩小，并不证明正常游戏中的灯光历史完全同步。当前差异需在脚本通过后重拍；不能从整图均值推断“还原度百分比”。 |
| E11 | [最终技术证据索引](../saltline-godot/evidence/final-technical-audit.json)；[r16 运行包验证](../saltline-godot/evidence/runtime-bundle-r16-verification.json) | 当前包内启动和触摸生命周期已验证；现有视频多为历史版本或固定步进，未证明本片实时录制。 |
| E12 | [原版音频合成器与音色表](../artifact-rendering-study/source/extracted/bundle-1.js#L65486)；[动态音乐调度](../artifact-rendering-study/source/extracted/bundle-1.js#L66212)；[WebAudio 服务](../artifact-rendering-study/source/extracted/bundle-1.js#L66779) | 原始生成器已导出 79 个生成项、136 个缓冲，其中两个是混响脉冲；Godot 事件、动态混音和听感对照仍在实施。 |
| E13 | [原版太阳光与 PCSS 移植](../saltline-godot/docs/source-sun.md)；[PCSS 受控对照](../saltline-godot/evidence/sun-pcss-verification.json) | 高画质表面阴影采用 8 次遮挡物搜索和 16 次过滤；不同于体积光沿视线的 24 步采样。受控 GPU 对照不代表所有设备与场景一致。 |

## 供审脚本的现有画面

- 当前版本室外固定机位：[原版](../saltline-godot/evidence/main-paired-high-source.png) / [Godot r16](../saltline-godot/evidence/main-paired-high-r16-audit-native.png)。条件及误差见 E10；关闭了 HUD 和武器，这是静帧参考，不代表实时帧率。
- 历史室内固定机位：[原版](../saltline-godot/evidence/main-paired-high-interior-source.png) / [旧版 Godot](../saltline-godot/evidence/main-paired-high-interior-native.png)。用于理解曾出现的局部差异；不能当作当前版本的结论。

以上图片来自旧版本，已并入本地项目，但公开授权尚未核实。本片另行录制实时对照；旧图用于说明历史问题时会标明版本和条件。

## 原版来源与模型归属

- 用户提供的[原 Artifact](https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp)作为原版链接；本地保存的 HTML 与远端内容尚未做字节一致性核验。
- [Saltline 镜像仓库的来源说明](https://github.com/realcodebear/saltline-fable-5.2/blob/main/README.md#where-it-comes-from)将该 Artifact 归于 Claude Fable 5.2，并指向 Felix Rieseberg 的[原始发布帖](https://x.com/felixrieseberg/status/2119925633564463609)。本次读取原帖返回 403，模型归属以用户提供的信息和镜像的说明为依据，不能将镜像当作原作者授权或本地文件一致性的证明。
- [Anthropic 的 Claude Fable 5.2 发布说明](https://www.anthropic.com/claude-fable-and-mythos-5-2)可核对模型名称；该页面本身不证明此游戏的制作过程。

## 外部来源

- [用户提供的原 Artifact 页面](https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp)：来源链接；尚未验证远端内容与本地 HTML 字节一致。
- [Godot 官方 Spatial shader 文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)：材料和着色器接口；实际项目应按固定 Godot 版本复核。
- [Godot 官方 CompositorEffect 文档](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)：渲染阶段扩展的能力与边界。
- [Boson Higgs TTS 3 模型说明](https://huggingface.co/bosonai/higgs-tts-3-4b)：参考逐字稿与模型能力。
- [Boson Higgs TTS 3 许可](https://huggingface.co/bosonai/higgs-tts-3-4b/blob/main/LICENSE)：真人声音同意、创作者署名和模型再分发条件；以实际模型版本及适用许可为准。
- [Boson VoiceOver 介绍](https://www.boson.ai/blog/higgs-voiceover)：十秒级参考音频的上游示例，仅作本片参考片段实验起点，不等于当前 AW 效果保证。

原 Artifact 地址、完整第三方图像与字体来源、许可证及授权状态，沿用研究项目的 [SOURCES.md](../artifact-rendering-study/SOURCES.md) 和 [参考图说明](../artifact-rendering-study/references/README.md)，公开前逐项复核。
