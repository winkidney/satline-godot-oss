# Godot PBR 能做到什么：官方能力与本项目路线

**供新增视频章节审阅。** 本文核对 Godot 4.7 官方文档、Three.js 官方文档及当前项目源码和已有证据；本次没有新建标准材质样例、运行游戏或做新的画质、性能测试。项目配置为 [Forward+](../../saltline-godot/project.godot)，随项目的定制引擎以 Godot **4.7.2** 为基线；当前构建信息以[引擎说明顶部](../../saltline-godot/engine/README.md)为准，[兼容性分析](../../saltline-godot/docs/engine-compatibility.md)保留了较早阶段的构建记录。文中“原生”指官方 4.7 文档所述能力，不等于本项目已有运行画面证明该能力。

## 一句话结论

官方 Godot 已有完整的金属度—粗糙度 PBR 基础工作流，配合灯光、天空、反射和间接光，可以制作带金属、石材、织物等材质的实时 3D 画面。标准材质也有清漆层、各向异性和次表面散射等功能。达到什么视觉质量还取决于资产、光照、调色、渲染器、硬件预算和制作水平；现有资料不足以给出一个跨项目的“画质上限”。[Godot 标准材质](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html)、[渲染器对照](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html)

本项目另有一个更严格的目标：尽量贴近 Three.js 原作的具体输出。它不是简单地把原贴图连到官方标准材质上，而是使用项目自己的 `ShaderMaterial`、光照计算、反射及渲染链，并为少数底层状态配合定制引擎。现有 Godot 截图因此证明的是**这条项目实现路线**的表现，不能单独当成官方标准材质开箱表现。[材质创建](../../saltline-godot/scripts/source_scene.gd#L272)、[材质 shader](../../saltline-godot/shaders/source_material.gdshader#L65)、[直接光实现](../../saltline-godot/docs/source-local-lights.md)、[引擎补丁边界](../../saltline-godot/docs/engine-compatibility.md)

## 1. Godot 原生材质的能力

| 功能 | 能做什么 | 范围与来源 |
| --- | --- | --- |
| 基础 PBR | `StandardMaterial3D` 提供底色、金属度、粗糙度、法线、遮蔽和自发光等属性；`ORMMaterial3D` 将遮蔽、粗糙度和金属度合并到一张 ORM 贴图中。高粗糙度让反射分布变宽，金属度影响漫反射与金属反射的比例。 | [StandardMaterial3D](https://docs.godotengine.org/en/4.7/classes/class_standardmaterial3d.html)、[ORMMaterial3D](https://docs.godotengine.org/en/4.7/classes/class_ormmaterial3d.html)、[标准材质参数](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#metallic)。法线图改变受光方向，不改变模型外轮廓。 |
| 表面细节 | 自带细节贴图、UV 与三平面映射、高度视差等选项；高度视差是视觉近似，并不产生真实碰撞几何。 | [标准材质文档](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#height)。额外的生成规则、材质层或特定布料模型可使用 [Spatial shader](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html) 扩展。 |
| 多层高光和方向性 | 内置 Clearcoat 给原表面叠加一层高光；Anisotropy 可让高光沿切线方向拉长，并使用 flowmap 控制方向。Rim 可以模拟布面微小纤维造成的边缘散射。 | [清漆层](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#clearcoat)、[各向异性](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#anisotropy)、[Rim](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#rim)。材质高光的各向异性与**纹理过滤**各向异性不是同一个设置；这些选项也不自动构成准确的丝袜纱线模型。 |
| 皮肤和薄片 | 支持次表面散射和背光近似，可用于皮肤、蜡或叶片的视觉制作。 | [次表面散射与背光](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#subsurface-scattering)。内置次表面散射只在 Forward+ 提供，不在 Mobile/Compatibility 提供。 |
| 透明与折射 | 标准材质支持透明和基于屏幕信息的折射，能用于玻璃等效果。 | [折射原理与限制](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#refraction)：折射物体不能折射屏幕外物体、自身或其他透明物体；透明对象还可能发生[排序问题](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_rendering_limitations.html#transparency-sorting)。这些是内置路径限制，不等于自定义渲染完全做不到其他效果。 |

PBR 描述的是一套材料如何响应光线的模型，不等于场景自动有正确的反射、间接照明或色调。Godot 4.7 Forward+ 是面向实时画面的前向渲染器；实时反射和 GI 有各自的近似与成本。另一条独立路径是 `LightmapGI` 在编辑器中用射线追踪烘焙静态光照，不能因此把运行时光栅渲染说成路径追踪，也不能反过来说 Godot 没有任何射线追踪用途。[Forward+ 架构](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html#forward)、[LightmapGI 烘焙与去噪](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_lightmap_gi.html#denoising)

## 2. 灯光、反射和渲染器会怎样限制成片

- **反射。** Forward+ 有屏幕空间反射 SSR，可以反射当前可见的不透明物体；屏幕外、被遮挡及透明物体有可见性限制，可与天空或 ReflectionProbe 等其他来源结合。[SSR](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html#screen-space-reflections-ssr)；[ReflectionProbe](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/reflection_probes.html)。本项目的湿地清晰倒影则主要使用第二台镜像相机加平面反射，不应称为 Godot 默认 SSR；[反射实现与后续接入](../../saltline-godot/docs/planar-reflection.md)。
- **间接光。** LightmapGI 适合静态烘焙，VoxelGI 和 SDFGI 提供不同实时近似，但会有漏光、空间分辨率、更新或成本上的取舍。[官方 GI 对比](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/introduction_to_global_illumination.html)。这些是灯光方案，不是 PBR 贴图的另一种名字。
- **平台与版本。** Godot 4.7 的 Forward+ 支持 SSR、VoxelGI、SDFGI 和内置次表面散射；Mobile/Compatibility 对上述功能不完全相同。Compatibility 自 4.6 起已有简化 SSAO，不能套用旧版本资料说它没有 SSAO。[Godot 4.7 渲染器表](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html#feature-comparison)、[简化 SSAO 说明](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html#screen-space-ambient-occlusion-ssao)。当前项目配置不等于已经在其他渲染器或设备完成验证。
- **实际效果。** 同一模型和材质参数，在不同光源、环境反射、曝光、色调映射和抗锯齿下可以出现明显不同的画面；比较前应尽量固定这些条件。比较结果不能脱离目标平台和运行成本谈“最好”。[环境与后处理](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)、[Godot GI 取舍](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/introduction_to_global_illumination.html#which-global-illumination-technique-should-i-use)

## 3. 原版与 Godot 复刻究竟怎么做

| 层次 | 原版 Three.js / WebGL | 当前 Godot 复刻 | 为什么不能直接画等号 |
| --- | --- | --- | --- |
| 基础材质 | 通用环境表面采用 `MeshStandardMaterial` 的金属度—粗糙度 PBR 工作流；很多纹理由原版 GPU 按配方生成并缓存。原作通过 `onBeforeCompile` 增加湿润、低频变化等局部规则。 | 原版运行后导出网格、纹理与材质参数，`source_scene.gd` 为通用表面建立 `ShaderMaterial`；专用水、地面、手臂等用各自 shader。 | [Three.js 官方材质说明](https://threejs.org/docs/pages/MeshStandardMaterial.html)、[原版实现](../../artifact-rendering-study/docs/materials-and-textures.md#4-在标准-pbr-中插入局部规则)、[实际材质工厂](../../saltline-godot/scripts/source_scene.gd#L272)、[导出核查](procedural-source-verification.md)。图形库中存在某特性不代表原游戏使用了它。 |
| 贴图 | 基础颜色、法线和 ORM 分别表达颜色、微表面方向与遮蔽/粗糙度/金属度。 | 通用 shader 对 `albedo_tex` 使用 `source_color`，并从 ORM 的 R/G/B 分别取 AO、粗糙度与金属度；按源参数处理湿润、细节和法线。 | [原版 ORM 输出](../../artifact-rendering-study/source/extracted/bundle-1.js#L37444)、[Godot 采样及输出](../../saltline-godot/shaders/source_material.gdshader#L15)、[Godot 颜色语义](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shading_language.html#using-source-color)。颜色贴图与数值贴图的颜色空间不同；同一张 PNG 仅复用文件名并不能保证采样等价。 |
| 直接受光 | 原 Standard 路径使用 Lambert 漫反射与 GGX 相关镜面模型，输入还包括灯光强度和阴影。 | 官方 Godot 默认漫反射模型是 Burley，也可选择 Lambert；本项目为对齐原作，给通用及特殊表面接入原公式的统一直接光和太阳 PCSS。 | [原太阳公式记录](../../saltline-godot/docs/source-sun.md#brdf-原公式)、[Godot 漫反射选项](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#diffuse-mode)、[项目当前统一直接光](../../saltline-godot/docs/source-local-lights.md#统一原直接光默认接入)、[实现](../../saltline-godot/shaders/source_direct_surface.gdshaderinc)。仅切换 Lambert 不等于其他光照、纹理采样与最终画面也自动一致。 |
| 环境受光 | 原场景使用经预过滤的环境贴图，表面粗糙度、视角和金属度参与间接光计算。 | 在 source IBL ready 时，项目的通用材质屏蔽相应原生早期环境项，计算原版 IBL 后经 `EMISSION` 输出通道累加；这是复刻管线选择，不应误说物体本身在发光。 | [shader 实际分支](../../saltline-godot/shaders/source_material.gdshader#L90)、[最新专用材质 IBL 接线与验证](../../saltline-godot/docs/source-ibl.md#专用地面海面与手臂默认接入)。项目文档中更早的“尚未接入”是阶段记录；此外仍须区分 ready/fallback 和完整视觉比较范围。 |
| 湿地反射与底层状态 | 原地面运行湿润材质并从镜像相机获得平面反射。 | 项目实现镜像相机、HDR 反射与 mip，并在定制引擎里分离实际斜裁剪投影和用于灯光等计算的参考投影；还有深度偏置、采样和光栅方向等兼容。 | [项目当前补丁及替代方案](../../saltline-godot/docs/engine-compatibility.md)。改引擎是为了维持本项目需要的接口和原行为，并不意味着普通 Godot 制作 PBR 湿地必须打这些补丁。 |

## 4. 现有证据可以支持什么

- 项目保留了[原版材质目录](../../saltline-godot/evidence/material-catalog-full-source.png)和 [Godot 复刻材质目录](../../saltline-godot/evidence/material-catalog-full.png)，以及[原版球阵](../../saltline-godot/evidence/render-catalog-source.png) / [Godot 球阵](../../saltline-godot/evidence/render-catalog.png)。这些适合审阅、选镜，正式展示仍须核对版本、机位、灯光、材质参数、曝光及录制状态；后者是本项目复刻 shader，不能标作官方默认材质。
- 已有统一直接光测试覆盖 72 组、576 个通道，在记录的容差下无失败；测试明确不涵盖 PCSS 或非零几何导数。它支持所测函数在那些输入下接近，不能证明画面全部一致。[测试结果与范围](../../saltline-godot/evidence/direct-lights-verification.json)、[项目说明](../../saltline-godot/docs/source-local-lights.md#统一原直接光默认接入)。
- 已有一组固定机位、固定时间和曝光的原版/Godot 主场景图，RGB8 平均绝对差约 `0.628`、P99 为 `7`；条件包括隐藏 HUD 与武器、零 dt 预热，记录明确只作描述，不是全游戏画质或 PBR 能力评分。[报告](../../saltline-godot/evidence/main-paired-high-r16-audit-comparison.json)、[技术审计](../../saltline-godot/docs/current-completion-audit.md)。
- **尚缺官方原生材质的同条件画面对照。** 若要回答“开箱能达到什么程度”，建议审阅通过后单独制作官方 Godot 4.7.2 的标准材质球或小道具实验：固定模型、PBR 贴图、灯光、环境与曝光，展示金属度/粗糙度、清漆层和各向异性。必要时与 Three.js 同场景对照；应把“官方标准材质样例”和“当前定制复刻”分别标清，记录运行版本与设置。该实验目前尚未制作，也没有性能结论。
- 原版和复刻的渲染工作台，以及 `wet=0/1` 的历史截图已整理成[效果对照页](pbr-comparisons.md)；其中同时列出计划追加的官方材质和反射对照。

## 5. 视频章节和效果对照

供审阅的旁白、镜头和 MG 以[完整分镜](storyboard-v3-draft.md)中的“Godot 的 PBR 能做到什么程度”章节为准。现有历史对照与待制作的官方材质、透明及反射实验见[效果对照页](pbr-comparisons.md)。

## 6. 仍需确认的范围

本轮没有运行项目、官方 Godot 材质球或 Three.js 对照，也没有测试不同渲染器、设备、透明叠层或性能。已有样本和历史截图不足以证明全部材质、整局游戏或跨平台像素一致；新章节以文档能力和当前源码为依据，实际观感仍以之后实录审阅为准。
