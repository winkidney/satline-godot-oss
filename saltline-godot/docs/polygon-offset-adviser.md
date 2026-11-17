# 原 polygonOffset 的硬件迁移建议

后续生产接入已完成，当前状态见[source-polygon-offset.md](source-polygon-offset.md)。本文保留只读调研阶段的建议与实测。

本轮只新增诊断工具、GPU 参考和本文，没有修改生产 shader 或引擎。引擎审查基于 `ed1daf0bf001b61586d9930840f2f1394092c079`，本地目录 `engine/.build/godot-ed1daf0bf`，现有私有 oblique projection 补丁保持不动。

建议先验证 **D24_S8 附件加私有材质 raster bias**。这条路径比新增 Vulkan depth-bias 扩展接线小，而且本机原 NVIDIA GL 与 Vulkan D24 的 63 组常量偏移差值已经逐位一致。仍需完成 reverse-Z、武器范围、MSAA 与真实贴花可见性验证，不能把当前单采样诊断当成生产接入完成。

## 当前实际材质

`assets/prepared/scene.json` 中 48 个材质开启 polygonOffset，覆盖 75 个 Mesh。

| 材质 | 数量 | 原 factor / units | Mesh 范围 |
| --- | ---: | --- | --- |
| `label` | 27 | -2 / -2 | 世界 |
| `decal_*` | 18 | -2 / -2 | 世界 |
| `label_atlas` | 1 | -2 / -2 | 世界 |
| `weapon_markings` | 1 | -3 / -3 | 武器，3 个 Mesh |
| `fx_decals` | 1 | -4 / -4 | 世界 |

全部为透明 MeshStandardMaterial，`depthTest=true`、`depthWrite=false`、`alphaTest=0`。只有 weapon_markings 为 DoubleSide，其余 FrontSide。75 个 Mesh 全部 `castShadow=false`，其中 69 个 receiveShadow=true。72 个世界 Mesh、3 个武器 Mesh，没有一个 offset 材质跨两类相机复用。

原创建入口在 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) L38115–38124、39078–39082、48419–48426、58623–58634、70041–70050。Three 在 L30198 传递材质参数，L30221–30226 直接启用 `POLYGON_OFFSET_FILL` 并调用 `gl.polygonOffset(factor, units)`。

## 原深度格式与范围

原 main HDR target 在 bundle L36792–36803 创建 `UnsignedIntType`、`DepthFormat` 的 DepthTexture，不带 stencil。Three 的格式选择 L30592–30609 和分配 L30949–30964 将它设为 `DEPTH_COMPONENT24`。MSAA renderbuffer 在 L31531–31556、31789–31791 沿用相同深度格式；high quality 请求 4 samples，最终受设备上限约束。是否采用 multisampled-render-to-texture 扩展由 L31978–31984 决定，否则使用独立 renderbuffer 和 resolve。当前新增探针测的是 samples=0，不补写 MSAA 等价结论。

planar target 在 L56160–56169 没有 DepthTexture，samples=0，但 `depthBuffer=true`、`stencilBuffer=false`；默认格式选择也得到 D24。world 与 weapon 共用 main target，L36945–36978 先画世界，再调用 `depthRange(0,.05)` 画武器，期间不清深度，最后恢复 `[0,1]`。

GL 的 offset 在 window-depth 上计算。范围缩小会改变斜率项，但不会自动缩小 units 项；最后深度限制也不能误解为 weapon 的 `[0,.05]`。原规范见 [OpenGL ES 3.0 §2.13.1、§3.6.2](https://registry.khronos.org/OpenGL/specs/es/3.0/es_spec_3.0.pdf)。

## 本轮原 NVIDIA 实测

独立工具为 [polygon_offset_reference.html](../tools/polygon_offset_reference.html)，collector 为 [polygon_offset_reference.cjs](../tools/polygon_offset_reference.cjs)。它从原 bundle 提取 Three r180，创建原类型 D24 target，通过 nearest `texelFetch` 将深度写入 RGBA32F，再以 Float32Array 读回。baseline 与 biased draw 使用同一几何和相同 vertex 运算，只有硬件 offset 状态变化。为测量偏移，诊断材质显式开启 depthWrite；这不是生产材质设置。

原始证据在 [polygon-offset-reference.json](../assets/export/fixtures/polygon-offset-reference.json)，分析在 [polygon-offset-gl-analysis.json](../evidence/polygon-offset-gl-analysis.json)，可用 [analyze_polygon_offset.py](../tools/analyze_polygon_offset.py) 重算，不依赖 NumPy。

- 后端是 `ANGLE (NVIDIA Corporation, NVIDIA GeForce RTX 4070 SUPER/PCIe/SSE2, OpenGL ES 3.2)`。
- 实际 `DEPTH_BITS=24`、`FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE=24`、samples=0，FBO complete。
- 共 546 组、4368 个深度采样，包含 7 个深度、world/weapon 两个 range、平面及 x/y/对角斜率、units -4..4、factor -2/-3/-4。
- 有效常量尺度为 `r = 2 * 2^-24`。这里是硬件 Float32 读回能分辨的结果，不声称测出了无限精度的 UNORM 归一化常数。
- range=.05 的 units 项与 range=1 一致；斜率项按 .05 缩小。所有数据对 `factor*m + units*r` 的最大残差为 `2^-24`，保留了 .25/.5 附近量化和读回舍入细节，没有修改任何现有验收容差。
- offset enabled 且 factor=units=0 时，14 组平面结果均与 disabled 的原始 bits 相同。
- 与主线 [rd-polygon-offset-probe.json](../evidence/rd-polygon-offset-probe.json) 的 Vulkan D24_S8 配对，7 深度 × 9 units 的 **63 组偏移差值全部精确相同**。绝对深度只有 nominal=.1 的 9 组不同，GL 经过 `2*d-1` 再 viewport 变换，RD 直接写 d，baseline 相差一个 `2^-24`。比较差值排除了这项输入路径差异。

主线的 D32F_S8 诊断则随深度改变 units 对应的步长。它证明当前 Forward+ D32F 上仅把 factor/units 符号取反不足以复刻原 D24 常量项。当前没有 reverse-Z、MSAA4、斜近平面或生产透明贴花的完成证据。

复跑原参考：

```sh
rtk proxy env DISPLAY=:0 python3 artifact-rendering-study/tools/collect_browser.py saltline-godot/tools/polygon_offset_reference.cjs --session salt-pmrem-gpu --name polygon-offset-gl-metadata
rtk proxy cp artifact-rendering-study/evidence/runtime/polygon-offset-gl-reference.json saltline-godot/assets/export/fixtures/polygon-offset-reference.json
rtk proxy python3 saltline-godot/tools/analyze_polygon_offset.py
```

## Godot 能用的入口

公开的 **RDPipelineRasterizationState** 已有 `depth_bias_enabled`、`depth_bias_constant_factor`、`depth_bias_slope_factor`、`depth_bias_clamp`，不是 RDPipelineDepthStencilState。绑定见 [rendering_device_binds.h](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/rendering_device_binds.h#L559)，Vulkan 直接写 VkPipelineRasterizationStateCreateInfo 的四个字段，见 [rendering_device_driver_vulkan.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/vulkan/rendering_device_driver_vulkan.cpp#L5936)。

普通 Forward+ ShaderMaterial 没有公开的材质 hardware bias 参数。`SceneShaderForwardClustered::ShaderData::_create_pipeline()` 当前只给 raster state 填 cull/wireframe，见 [scene_shader_forward_clustered.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L427)。RD 有 depth-bias dynamic-state 枚举，不等于普通材质或 GDScript 已有可用的动态 bias draw command。

项目内最小接线可以是三种私有 render_mode，对应本项目实际三组值，并由 ShaderData 保存。模式进入 shader parser 的 render-mode 表、Forward+ compiler actions，再设置 raster state；模式为静态 shader 状态，重编译时现有 pipeline cache 会清空。无需写 fragment `DEPTH`，不改变 early-depth 行为或凭空增加一个 epsilon。

在 D24_S8 普通 bias 的当前本机实测下，世界采用 `slope=-sourceFactor`、`constant=-sourceUnits`。独立 weapon 采用 `slope=-sourceFactor`、`constant=-20*sourceUnits`。三组 native 值是世界 `(2,2)`、武器 `(3,60)`、世界 FX `(4,4)`，clamp=0。这些是待 reverse-Z 探针验证的映射，不是已验证生产参数。

如果将来同一材质被 world 与 weapon 相机复用，静态模式不能自动随 pass 更换尺度，必须分材质或把相机域纳入 pipeline key。不要以 shader uniform 假装能改变已经建立的固定 raster state。

还应修改 `uses_shared_shadow_material()`，bias 开启时禁止替换为默认 depth/shadow shader。入口见 [scene_shader_forward_clustered.h](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.h#L298)，替换在 [render_forward_clustered.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L4224)，异步预编译也调用同一 predicate。当前 48 材质只进透明队列、全部不投影，这个问题尚未影响它们，但缺少该保护会使后续 opaque biased 材质的 prepass 与 color EQUAL 不一致。depth、normal/roughness、color 的硬件 bias 必须保持相同语义。原生 shadow pass 可能使用其他深度格式或反向比较，若将来支持 caster，需按该 pass 另定符号和 r，不能把本次 D24 相机参数原样套入 shadow atlas。

## D24 与扩展方案的取舍

建议使用 `D24_UNORM_S8_UINT`，不要为了移除原作没有的 stencil 改成新 D24-only 路径。Godot 已经支持 D24_S8 作为 Forward+ fallback，保留 stencil 也少一项附件契约变化。

统一格式选择点为 [RenderSceneBuffersRD::get_depth_format](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/render_scene_buffers_rd.cpp#L810)。Forward+ 目前优先 D32_SFLOAT_S8_UINT，然后 D24_UNORM_S8_UINT。一个默认关闭、需要重启的私有项目设置可以改变这两个附件格式的优先顺序，实际 unsupported 时应明确报错或记录退回，不能仍宣称 D24 对齐。

必须保留函数开头的 R32_SFLOAT resolve 分支。Forward+ MSAA compute resolve 需要可写 R32F target，不可把它改成 D24。MSAA 源附件使用 sampling、depth/stencil attachment、copy-from；单采样源附件使用 sampling 和 depth/stencil attachment。需要实际验证 D24_S8 的 4 samples 与这些 usage 的组合。

格式选择同时用于 scene-buffer 创建和 Forward+ framebuffer/pipeline 预编译，见 [render_forward_clustered.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L4516)。只改实际 texture_create 而不改预编译格式会留下 framebuffer/pipeline 不匹配。若改成逐 viewport opt-in，当前 static helper 及预编译调用也要带上同一 policy，不能只在 configure 内做分支。

现有 `DepthSamplesBridge` 使用 sampler2DMS/texelFetch 的浮点深度，`SolarDepthBridge` 也是普通深度采样，没有假设 D32 原始 bits；D24 normalized sampling 在接口层可兼容。Godot compute resolve 同样读取浮点 sample。SSAO、AO half-depth、volume、SSR、compositor 的输入数值会变，需重验已有证据，不能由接口兼容推导像素不变。引擎原生 SSAO 在本项目已关闭，也不意味着自定义 AO 不受影响。

本机 NVIDIA 暴露 `VK_EXT_depth_bias_control`，实查 `depthBiasControl=true`、`leastRepresentableValueForceUnormRepresentation=true`、`depthBiasExact=true`，但 **floatRepresentation=false**，因此不可计划使用 FLOAT 表示。备选是 FORCE_UNORM 加 exact。规范在 D32F 下取 24 个有效位，其 r 为 `2^-24`，故要复刻本次 GL 结果，还需把 constant coefficient 再乘 2。world 为 `-2*units`，独立 weapon 为 `-40*units`。这一方案保留现有 D32F 场景精度，但需要增加扩展枚举、feature query/enable 和 pipeline pNext；只设一个现有 RD 字段不够。参见 [Vulkan depth bias 计算](https://docs.vulkan.org/spec/latest/chapters/primsrast.html#primsrast-depthbias) 与 [VkDepthBiasRepresentationInfoEXT](https://docs.vulkan.org/refpages/latest/refpages/source/VkDepthBiasRepresentationInfoEXT.html)。

因此 D24 是较小的全场景格式方案；FORCE_UNORM 是较窄的 bias 语义方案。前者影响所有深度消费者，后者增加 Vulkan 扩展维护。两者都不能跳过反转深度和真实贴花的验证。

## 武器独立 viewport 的量化边界

令 `s=.05`，原 forward weapon 的连续偏移为 `s*m*f + r*u`。独立 native weapon 仍在完整 0..1 深度范围，reverse-Z 后斜率系数仅反号，units 需除以 s，即乘 20。把 slope 也乘 20 会错。

但 D24 和上述比例并不让两种深度存储完全相同：

```text
原共用 target：Q24(s*z + offset)
独立 native remap：s * Q24(z + offset/s)
```

两者量化顺序不同，后者映回原 source 深度后有更细的网格。即使偏移的连续公式吻合，深度相等、贴花与宿主极近距离、MSAA resolve 阈值仍可能不同。原与 native 的 clip 运算和 reverse-Z 舍入也要单列。

若目标进一步要求原武器 D24 深度比较时序，需要考虑 native weapon 实际 viewport reverse depthRange `[.95,1]`，同步修改 clear/weapon mask/深度解码，并重验与世界 depth 合并。它比当前 units×20 的隔离修复大，不能在 combined_depth 保持不动时宣称已经实现。

## 太阳阴影的例外

引擎自己的 directional/omni shadow atlas 格式由 [LightStorage](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L2743) 单独选择，不由 scene-buffer get_depth_format 控制；内建 reflection-probe depth 也有自己的选择函数。

本项目 [sun_shadow_pass.gd](../scripts/sun_shadow_pass.gd) 则是普通 4096²、无 MSAA 的 3D SubViewport，所以全局 D24 设置会影响它。当前生产 producer 使用 [SolarDepthBridge](../scripts/solar_depth_bridge.gd) 读真实深度附件，再做 `1-z` 写 R32F；输出 R32F 无法恢复源附件已经丢掉的精度。

原 Three sun shadow 的 D24 附件只负责深度测试。PCSS/volume 读取的是独立 RGBA packed depth：bundle L24169 传递 `vHighPrecisionZW`，L24198 计算 `.5*z/w+.5`，L24203 `packDepthToRGBA`。所以“原 shadow 也有 D24”不能证明把当前 native producer 改为 D24 后仍等价。它既可能改变近乎共面的 caster 谁胜出，也会改变每个导出的深度值。

较稳妥的范围是 world、weapon、planar 显式 D24，sun 保持现状。若为减小补丁先采用全局设置，就重新验证 sun depth map、PCSS 和 volume，并把它作为独立格式迁移记录。将来若恢复独立高精度 shadow color producer，D24 仍会影响 caster 深度胜出，但不再限制所有输出颜色深度的精度。

## 下一轮最小验收

1. 公共 RD 探针扩展为 reverse-Z、正负斜率、x/y/对角、range 缩放和 D24 MSAA4。保留 raw Float32 bits，分别核对 baseline、offset delta 和颜色遮挡，避免混淆 clip 变换差异。
2. 接私有 ShaderMaterial raster mode 后，直接在普通 MeshInstance3D 验证；记录实际附件格式及 samples，覆盖主相机、oblique planar、独立 weapon。
3. 用原 `(factor,units)` 三组值和微小宿主距离扫描验证透明贴花。生产材质 depthWrite=false，因此“底层 depth bridge 输出未变”应当成立，却不能证明 offset 生效，必须检查颜色可见性和遮挡。
4. 原有 D24/D32 差异、MSAA 样本位置差异、武器量化顺序分别记录，不通过放宽统一容差掩盖。重跑 solar/combined depth、AO、PCSS/volume 和 planar 的相关 GPU gate。
5. 如果保留通用 opaque bias 支持，再验 prepass 与 color EQUAL、默认 shadow-material 优化、异步预编译和 shader 热重载。未覆盖时把本次支持明确限定为已审计的透明不写深度材质。
