# 参考图与归属

本目录分为源码结构示意和外部技术参考。该目录保留静态示意与外部参考，不作为原作运行证据。实际原作截图、GPU贴图和缓冲现保存在[evidence/runtime](../evidence/runtime/)，见[实机报告](../docs/runtime-findings.md)。

| 文件 | 来源与用途 | 归属与边界 |
| --- | --- | --- |
| [render-pipeline.svg](render-pipeline.svg) | 本轮依据当前脚本整理的渲染结构图 | 自制技术示意，不是游戏截图，不代表运行成功 |
| [material-pipeline.svg](material-pipeline.svg) | 本轮依据 MRT、normal 与采样代码整理 | 自制数据通道示意，不是实际生成贴图 |
| [godot-alpha-blend-vs-scissor.png](godot-alpha-blend-vs-scissor.png) | [Godot 官方材质教程](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#transparency)，[直接图片](https://docs.godotengine.org/en/stable/_images/spatial_material12.png) | Godot 文档图片；用于区分连续透明与二值裁切，不能代表丝袜视觉质量 |
| [khronos-sheen-cushion.png](khronos-sheen-cushion.png) | [KHR_materials_sheen 规范](https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_sheen)，[直接图片](https://raw.githubusercontent.com/KhronosGroup/glTF/main/extensions/2.0/Khronos/KHR_materials_sheen/figures/cushion.png) | Khronos 官方示例；演示织物 sheen，不能证明 Saltline 启用了该扩展，也不是尼龙针织参数参考 |

外部图片于 2026-11-14 下载，未编辑；哈希见 [sha256.json](../evidence/sha256.json)。图片归上游权利人，授权以其项目说明为准，本项目未单独核定每张图的游戏资产再利用许可。Three.js 库的 MIT 许可单独保留在 [THREE-r180-LICENSE.txt](THREE-r180-LICENSE.txt)，不据此推断整个游戏源码或所有图片都采用相同许可。

后续获准实机后，建议补：总览、材质球/面板、衣袖织纹与雨珠、湿地反射、雾中光束，以及关闭镜头效果的同机位对照。每张图需要记录原件哈希、质量档、尺寸、相机、时间与曝光，避免把不同版本或不同曝光当作材质差异。
