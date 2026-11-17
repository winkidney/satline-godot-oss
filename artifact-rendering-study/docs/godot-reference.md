# Godot 渲染能力与丝袜项目接入参考

调研日期：2026-11-14。官方资料使用当天可访问的 `en/stable` 文档；这是可变地址，后续开发仍需按目标 Godot 版本核对 API。本机命令 `godot --version` 返回 `4.7.2.stable.official.ed1daf0bf`，该版本也用于后续独立实验，见[实验报告](godot-experiments.md)。

**证据边界：现已取得用户提供的 [HTML 原件](../source/saltline.original.html)，并静态检查其实际执行的第二个 script。** 格式化源码为 [bundle-1.js](../source/extracted/bundle-1.js)。第一个 `id=legacy-v8`、`type=application/octet-stream` 的 script 是惰性遗留文本，不作为当前渲染实现。已确认的天空、光照、阴影和后处理见 [SALTLINE 渲染迁移表](rendering-port-map.md)，其中每项都有源码行号。下文本页继续作为 Godot 官方能力与 `stocking-lab` 静态接入参考，不表示示例采用了所有这些技术。原作运行、参考图和独立实验已完成，见[实机报告](runtime-findings.md)；本页的丝袜接入分析仍仅依据目标项目静态代码。

## 1. 材质与光照应分开迁移

同一材质在不同光源方向、环境反射、曝光下会呈现不同高光。迁移时应分别记录光源、材质、相机和后处理参数，不应把参考画面中的亮带直接烘焙进基础色。

| 问题 | Godot 对应手段 | 适用判断 |
| --- | --- | --- |
| 普通金属、皮肤、地面材质 | `StandardMaterial3D` 或 `ORMMaterial3D`，设置 albedo、metallic、roughness、normal、AO | 先用内置材质建立可比较的基准 |
| 局部变化、程序纹理、应变驱动外观 | `ShaderMaterial` 的 spatial `vertex()`、`fragment()` | `fragment()` 写材质属性，让引擎执行默认光照 |
| 特定布料高光、卡通明暗或纱线 BRDF | 自定义 `light()` | 逐像素、逐灯计算，必须保留阴影和光源衰减 |
| 受观察方向影响的边缘散射 | 内置 rim 或自定义受光 sheen | 不把整条边缘无条件写成 emission |
| 微小凹凸 | normal/detail normal | 法线不改变轮廓与碰撞，真实洞口、翻卷和突出的纱线需要几何 |

内置材质具有粗糙度、法线、rim 与各向异性等能力，normal 只改变受光方向，不添加几何。[StandardMaterial3D 官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)

自定义 `light()` 用 `DIFFUSE_LIGHT += ...` 和 `SPECULAR_LIGHT += ...` 累积每盏灯。`ATTENUATION` 包含距离和阴影；省略它会造成背阴区域仍发亮。`LIGHT_COLOR` 已包含灯光颜色、能量和引擎的 π 约定，移植别的 GLSL 公式时需重新核对归一化。启用顶点光照会跳过 `light()`。[Spatial shader 官方参考](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins)

各向异性高光沿切线空间定向；网格必须有有效切线。`anisotropy_flowmap` 的 RG 表示方向扰动，alpha 可调强度。这与贴图的 anisotropic filtering 是两个不同功能。[BaseMaterial3D 官方属性](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-anisotropy-enabled)

丝袜候选做法：保持非金属纱线，按编织方向设置切线与高光轴。细节法线负责近处纹理，anisotropic BRDF 负责较远处成片的方向高光。不要通过提高 metallic 来模拟“有光泽”。这是针对目标项目的工程建议，并非原示例分析结论。

## 2. 贴图、颜色空间与采样

| 数据 | 保存与采样建议 | 需要防止的问题 |
| --- | --- | --- |
| 基础色、彩色遮罩、手绘颜色 | shader 的颜色输入使用 `source_color` | sRGB 颜色当线性数据读取会改变亮度和饱和度 |
| normal、roughness、metallic、AO、coverage、应变数据 | 当线性数据读取，不加 `source_color` | 数据经过 gamma 转换后，覆盖率和方向会失真 |
| normal | 使用 Godot 要求的 OpenGL 风格 X+、Y+、Z+；DirectX 资产核对 `Normal Map Invert Y` | 凹凸方向翻转 |
| 细密针织、蕾丝、网眼 | mipmap、线性过滤；斜视面考虑 anisotropic filtering | 远处条纹、摩尔纹、游动亮点 |
| HDR 环境 | 线性 `.hdr`/`.exr` | 把普通图片亮度当作 HDR 能量 |
| 数据贴图 | 按实际精度选浮点格式、最近邻或明确插值 | 压缩和过滤改变索引、密度或边界 |

Godot 在相关渲染流程中在线性空间工作；颜色贴图应使用 `source_color`，数值贴图通常不使用。Sampler 可以独立指定 filter 与 repeat。[Shading language 官方参考](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#using-source-color)

Godot normal 的坐标约定、Y 轴转换和 mipmap 导入开关见[图像导入文档](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html#process-normal-map-invert-y)。mipmap 主要处理缩小时的采样，不能保证任意程序纹理自动抗锯齿。迁移程序纱线时，建议用 `dFdx`/`dFdy` 或 `fwidth` 估计屏幕足迹，低于像素尺寸后平滑过渡到平均覆盖率、平均法线和更粗的高光。

## 3. 光照、环境与反射

直接光控制明暗方向和局部高光；IBL 控制来自环境的漫反射与镜面反射。Godot 的 `WorldEnvironment` 配合 `Environment`、`Sky` 管理环境；即使背景是纯色，也可以用 sky 作为独立的环境反射来源。HDR 全景可由 `PanoramaSkyMaterial` 使用。[环境与后处理官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#background)

建议为丝袜观察准备中性灯光与展示灯光两套配置。中性配置用于区分密度和材质，展示配置用于检查长条高光、掠射轮廓和肤色透出；相机、曝光固定后再比较。

| 效果 | Godot 选项 | 迁移注意 |
| --- | --- | --- |
| 主光、补光、轮廓光 | `DirectionalLight3D`、`OmniLight3D`、`SpotLight3D` 等 | 记录颜色、强度、方向、距离、specular 与阴影开关 |
| 接触阴影、投影 | 灯光 shadow 与阴影过滤 | 阴影偏移过大会使贴体织物悬浮，过小会自阴影条纹 |
| 环境亮带 | `Sky` radiance 或 HDRI | 光滑材质缺环境高频亮区时，不会凭低 roughness 自动出现合适高光 |
| 局部环境反射 | `ReflectionProbe` | 静态棚景优先评估 `Once`，`Always` 增加场景重复渲染成本 |
| 当前视野内反射 | SSR | 只能利用屏幕已有信息，不能负责屏外或被遮挡对象 |
| 间接照明 | LightmapGI、VoxelGI、SDFGI、SSIL | 根据静态/动态场景选择，不应为单个材质问题同时开启全部效果 |

灯光本身的颜色、能量、specular、cull mask 与阴影分别影响受光行为。发光材质通常只让自身亮起，照亮周围还要对应 GI/间接光流程。[灯光与阴影官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)

ReflectionProbe 可提供屏外环境信息；SSR 可补屏内细节，两者可以混合。探针的 box projection 用于局部视差修正，不能把单点环境采样变成精确的自反射。[ReflectionProbe 官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html)

SSAO 是遮蔽近似，SSIL 是屏幕空间间接照明，二者都不等于完整全局光照。当前官方文档列明 SSR 仅支持 Forward+，透明背景的 viewport 不支持 SSR；SSIL 也仅支持 Forward+。[Environment 官方 API](https://docs.godotengine.org/en/stable/classes/class_environment.html#class-environment-property-ssr-enabled)

## 4. 透明织物与阴影是优先风险

| 方案 | 优点 | 适用限制 |
| --- | --- | --- |
| Alpha blend | 连续半透明，容易表达肤色透出 | 叠层排序、overdraw 与阴影/屏幕效果限制 |
| Alpha scissor | 洞口清楚，排序可靠，可投影 | 二值裁切不能直接表示均匀薄纱 |
| Alpha hash | 用抖动表达覆盖率，可投影 | 噪点受分辨率与时间稳定性影响 |
| Depth pre-pass | 不透明部分先写深度 | 不能保证所有半透明重叠都正确 |
| 独立阴影代理 | 显示与投影可以分别调节 | 必须保持洞口、变形与覆盖率同步 |

以上透明模式和投影规则以[StandardMaterial3D 透明说明](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#transparency)为准。丝袜的前后表面、双腿交叠、袜口翻卷和脚趾间隙都需要后续单独验收。

屏幕颜色副本在不透明之后、透明之前获取，因此普通透明层不在该副本中；屏幕 normal/roughness 纹理只在 Forward+ 可用。折射不能假定能读到另一层透明袜子。[Screen-reading shader 官方文档](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

据此推断：不要假定透明袜层能给 SSAO/SSR 提供完整的遮挡数据。贴体层也不应依赖强 SSAO 来伪造织物密度；它可能把腿与袜的细小间距变成污黑边缘。应分别检查不透明皮肤深度、袜体透明度、洞口和阴影代理。

## 5. 色调、后处理、相机与时间稳定性

Godot 的 Environment 将景深、自动曝光、glow、tonemap、颜色调整安排在不同阶段。曝光、色调映射和 LUT 会改变同一材质的最终观感，参数不能跨引擎照抄数值。[Environment 官方处理顺序](https://docs.godotengine.org/en/stable/classes/class_environment.html#description)

建议首轮使用固定曝光，并保存 `tonemap_mode`、`tonemap_exposure`、白点、glow 与 LUT 状态。glow 放大高亮区域的扩散，不应替代纱线高光模型。景深与运动模糊在材质验收时先关闭，完成后再作为镜头风格评估。

MSAA 擅长几何边缘，无法消除 shader 高光闪烁；TAA 能抑制更多 shader/透明采样问题，但会模糊并可能拖影。Godot TAA 仅支持 Forward+。细密织物需同时处理纹理缩小、法线方差和粗糙度，而不能只增加 MSAA。后续可比较原生分辨率的 MSAA 与 TAA 动态结果，再决定成品设置。[3D 抗锯齿官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html)

相机需记录投影类型、FOV、距离、near/far 与输出尺寸。近景可见针脚，远景则应过渡到稳定的整体透光和方向高光；两者不是简单换一张更大的贴图。

## 6. `stocking-lab` 已有接口，静态核对

本节只说明代码存在，不代表本轮已运行、功能正确或视觉已通过。文件来自邻接项目，未复制为本研究项目的原始样本，也未修改。

| 本地文件 | 静态可确认的实现 | 后续接入位置 |
| --- | --- | --- |
| [project.godot](../../stocking-lab/project.godot) | Forward+；MSAA 数值 2；屏幕 AA 数值 1；60 Hz 物理 | 记录完整渲染配置，再按目标版本解释枚举 |
| [scripts/rebuild.gd](../../stocking-lab/scripts/rebuild.gd) | 自定义 studio sky、颜色环境光、sky 反射、Filmic、SSAO；主光与轮廓/补光；FOV 33 | 保留现有灯光预设，新增可比较的研究配置 |
| [scripts/character_rendering.gd](../../stocking-lab/scripts/character_rendering.gd) | `wuwa`/`builtin`/`pbr` 三种预设；按角色材质分组；独立描边网格 | 人物风格与袜材质分开对比，保持角色肤色一致 |
| [shaders/fabric_vertex.gdshaderinc](../../stocking-lab/shaders/fabric_vertex.gdshaderinc) | 读取粒子数据；重建顶点、法线、切线与副切线；传入 `fabric_metrics`、压缩方向、边界距离 | 将受力信息接到外观，避免屏幕坐标纹理在形变时滑动 |
| [shaders/fabric_optics.gdshaderinc](../../stocking-lab/shaders/fabric_optics.gdshaderinc) | 覆盖率随光学密度、贴体密度、面积比和视角变化 | 接入经过校准的参数，明确这些是工程近似 |
| [shaders/nylon_body.gdshaderinc](../../stocking-lab/shaders/nylon_body.gdshaderinc) | knit normal/coverage/glint；导数驱动细节淡出；应变/压缩褶皱；自定义各向异性高光与 sheen | 可逐项关闭比较，先判断需要迁移的是哪一层效果 |
| [shaders/hosiery_shadow.gdshader](../../stocking-lab/shaders/hosiery_shadow.gdshader) | 独立 alpha hash 阴影材质；共享织物变形、洞口、覆盖率函数 | 重点核对阴影代理与显示层是否同步 |
| [shaders/hosiery_depth.gdshader](../../stocking-lab/shaders/hosiery_depth.gdshader)、[hosiery_layer.gdshader](../../stocking-lab/shaders/hosiery_layer.gdshader) | 独立深度/显示层配置；并非一个透明面完成全部处理 | 双腿交叠、足尖、翻卷时分别检查深度关系 |
| [scripts/fabric_appearance.gd](../../stocking-lab/scripts/fabric_appearance.gd) | 密度浮点贴图；细节图转浮点并生成 mipmaps | 保持 coverage 均值与数据精度的现有设计 |
| [scripts/post_processing.gd](../../stocking-lab/scripts/post_processing.gd) | clean/soft/graded；glow、生成的 3D LUT、附件 emission 开关 | 按单因素对比，避免通过 LUT 掩盖材质偏差 |

这些接口已经覆盖大量丝袜专用能力。本次 SALTLINE 源码显示，可优先研究它的环境高光、曝光/色调、软阴影和多尺度采样方法。它的港口天空、体积尘雾和镜头污渍属于场景或镜头效果，不能直接当作丝袜纱线的光学模型。具体映射与优先级见 [SALTLINE 渲染迁移表](rendering-port-map.md)。

## 7. 物理如何影响外观，迁移候选

以下属于为后续项目提出的模型设计，没有归因于原 Artifact，也没有本轮视觉验证。

1. 使用稳定材料坐标追踪编织结构。位置随布面变形，UV 与纱线方向仍对应同一块材料。
2. 用形变梯度区分沿纱线方向的拉伸、横向拉伸和剪切；面积比 `J = A_current / A_rest` 可用于密度近似，但不能代替所有针织力学。
3. 在保留纱线质量的近似下，拉伸区域平均覆盖率下降，针脚变稀；局部压缩则出现褶皱与方向变化。用实拍或测量校准，避免任意把所有拉伸都变成同样的透明度。
4. 更新变形后的 normal/tangent，保持切线与法线正交。几何平滑可控制外轮廓，但不得把纱线高光方向固定在原始静止姿势。
5. 近景用覆盖/法线细节或少量纱线几何，远景用过滤后的平均 BRDF。真实开口影响轮廓、深度和投影，不能只给 albedo 画黑点。

布料反射需要考虑纱线方向与多尺度结构，原始研究可参考 [Irawan 与 Marschner，Specular Reflection from Woven Cloth，2012](https://www.cs.cornell.edu/~srm/publications/TOG12-cloth.html) 和 [Sadeghi 等，A practical microcylinder appearance model for cloth rendering，2013](https://graphics.ucsd.edu/~henrik/papers/practical_microcylinder_appearance_model_for_cloth_rendering.pdf)。它们研究的模型不能直接当作尼龙针织丝袜的测量参数。

Godot `SoftBody3D` 是可变形网格能力，可用于布料原型，但不会自动提供针织各向异性、贴体应变场或光学外观。[SoftBody3D 官方 API](https://docs.godotengine.org/en/stable/classes/class_softbody3d.html)。当前项目已采用自定义粒子数据传递方式，应先保留该接口，再判断是否有必要更换物理解算器。

## 8. 丝袜目标项目的后续验收候选

- 静态基线：固定姿势、相机、曝光，分别输出颜色、normal、coverage、roughness、切线方向诊断图。
- 灯光对比：移动主光，确认高光随光源和视角运动，区分直接光、环境反射与无条件发光。
- 动态对比：拉伸、回弹、弯腿、翻卷、破损，观察纹理是否游动、切线是否跳变。
- 透明叠层：交叉双腿、脚趾缝、洞口、袜口内外层，检查前后排序、深度和阴影同步。
- 距离与 AA：相同材质做近、中、远景和缓慢转镜，记录摩尔纹、闪烁、拖影和覆盖率变化。
- 性能：先分开记录物理解算、网格/纹理更新、透明 overdraw、阴影与后处理，再评估总帧时。

本节针对丝袜目标项目，仍仅保留后续步骤；已完成的原作与独立实验不等于丝袜接入验收。
