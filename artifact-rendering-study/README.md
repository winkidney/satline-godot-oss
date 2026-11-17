# Saltline 渲染技术学习项目

已完成原作源码分析、真实GPU运行、同机位效果对照、贴图与缓冲导出，以及三个独立Godot实验。研究关注原作本身的亮点，不以是否适合丝袜筛选内容；`stocking-lab` 未改动。

原作和Godot均在RTX 4070 SUPER上运行。原作高级渲染与软阴影实际启用；Godot采用4.7.2 / Vulkan Forward+。结果是学习与实现参考，不是完整视觉复刻或性能预算验收。

![原作实机](evidence/runtime/captures/pristine-original.png)

## 从这里读

| 内容 | 入口 |
| --- | --- |
| 实际画面、消融对照、曝光响应、贴图与GPU计时 | [实机发现](docs/runtime-findings.md) |
| 三个可运行Godot实验、截图、限制和顾问修复 | [Godot实验](docs/godot-experiments.md)、[运行说明](godot/README.md) |
| PCSS、体积积分、AO、Karis、曝光、法线方差、裁切公式与伪代码 | [实现细节](docs/deep-implementation.md) |
| 完整灯光/阴影/天空/后处理到Godot的映射 | [渲染迁移表](docs/rendering-port-map.md) |
| MRT烘图、通道、材质配方、过滤、缓存与贴花 | [材质与贴图](docs/materials-and-textures.md) |
| 湿地/海面/雨水/烟火/衣袖/武器 | [表面与特效](docs/surfaces-fx-and-cloth.md) |
| Godot官方能力及现有丝袜接口 | [Godot参考](docs/godot-reference.md)、[丝袜迁移建议](docs/stocking-transfer.md) |
| 原件、版本、提取过程及资源边界 | [源码与证据](docs/source-and-evidence.md) |
| 来源与参考图 | [来源索引](SOURCES.md)、[图片说明](references/README.md) |
| 后续完整原生复刻、实机视频及定制引擎边界 | [Saltline Godot 项目](../saltline-godot/README.md)、[已实现迁移路径](docs/rendering-port-map.md#7-后续原生复刻的实现路径) |

## 值得保留的知识

- **画面由多个阶段共同构成。** 方向天空、预滤环境、直射太阳、软阴影、雾的透射/散射和湿地反射共同建立空间。关闭平面反射后地面甚至可能更亮，关键在反射内容，不能只看亮度。
- **程序材质先生成，后采样。** 同一结构场生成颜色/语义alpha、ORM和高度，再推导normal；真实尺寸与分辨率分开规定。high档fabric实际只有256²，不能把质量档的1024理解为所有贴图尺寸。
- **微细节必须考虑像素足迹。** 原作同时使用mipmap、导数退出、线网覆盖与normal方差粗糙度补偿。增加MSAA不能替代这些处理。
- **镜头效果有顺序和耦合。** 原作使用曝光、ACES/AgX混合、grade及sRGB之后的FXAA/锐化/噪声。bloom开关还会关掉污渍和光条，不能把它当纯bloom消融。
- **外观算法有明确边界。** 天空云不等于体积云，平面反射不等于SSR，衣袖织纹不等于针织物理，镜头光条不等于纱线各向异性。

## 可运行实验

在本项目根目录执行：

```bash
rtk proxy python3 godot/tools/run.py run
rtk proxy python3 godot/tools/run.py capture
rtk proxy python3 godot/tools/verify_captures.py
```

三个实验分别覆盖微细节过滤、湿润/平面反射、曝光/glow/grade/横向光条。中文界面支持固定机位与参数开关。反射采用LDR SubViewport、逐材质裁切和加法合成，尚不是原作HDR radiance替换或相机斜裁切的精确移植。

![Godot湿地实验](godot/captures/wet-planar.png)

## 数据与复现

- [原始HTML](source/saltline.original.html)原样保存，SHA-256为 `b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb`。
- [可读源码](source/extracted/bundle-1.js)与[77段GLSL文本/模板索引](source/shaders/index.json)用于查阅。模板及补丁片段不保证可独立编译。
- [研究副本](research/index.html)和[诊断补丁](research/diagnostic.patch)保留实际采集改动；默认视觉算法沿用原作。
- [原作运行证据](evidence/runtime/)含36张截图、12帧无损WebP、29张贴图/缓冲查看图及额外高度打包图、4份原始数值缓冲，以及逐图参数。PNG中的HDR和高度图是预览，数值解释见实机报告。
- [Godot采集](godot/captures/)含42个状态、两份无损动态WebP、回归记录及早期错误ISO诊断图。
- 原作采集步骤见[研究工具说明](research/README.md)，最终文件校验见[sha256.json](evidence/sha256.json)。

原始静态阶段记录保留在`evidence/static-verification.json`；当前验收以[runtime-verification.json](evidence/runtime-verification.json)为准。Astra Ultra参与顾问审阅，发现的问题已修复并回归；这不代表用户已作最终视觉选择。

本项目未提交、推送或发布，也未接入丝袜项目。
