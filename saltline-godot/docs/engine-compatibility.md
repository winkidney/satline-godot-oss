# 引擎补丁、官方版替代方式与后续项目选型

核查日期：2026-11-16。本次只读审查源码、项目调用和已有验证记录，另写本报告；没有构建、启动 GPU 或重跑历史实测。

结论：这些改动服务于 Saltline 原版 WebGL 的渲染行为复刻。普通 Godot 游戏、丝袜物理与材质研究不必继承它们。官方 Godot 已提供多数底层能力，但当前内置 Forward+ 的相机、材质与视口接口不能直接表达本项目需要的全部状态。可以移除引擎补丁，但要修改项目渲染方案，或接受与原版不同的像素结果，不能只更换可执行文件。

## 实际版本与范围

- 当前二进制以官方 **Godot 4.7.2** 的 `ed1daf0bf001b61586d9930840f2f1394092c079` 为基线。本次实际读取文件并计算 SHA256，结果为 `bb476c9fd4cbf588904f38de2633b58cf962c3e30225dca8f009bf414bf1e70e`，大小 80,338,024 字节，与 [build-result.json](../engine/build-result.json) 一致。
- 当前合并补丁为 [0003-saltline-source-raster-origin.patch](../engine/patches/0003-saltline-source-raster-origin.patch)，实际包含 28 个文件。它包含此前所有功能，不是需要把三个历史补丁依次叠加。以 [source-manifest.json](../engine/source-manifest.json) 的 `patch_file`、完整 `patched_file_sha256` 和 build-result 为准；manifest 的 `files`、`scope`、`build_state` 仍有早期 11 文件阶段描述，README 的历史章节也保留多个旧 SHA；文件顶部已标明当前构建。
- 当前产物是 Linux x86_64 `template_debug`，不是编辑器；构建使用 `wayland=no`。这些是打包选择，不是额外游戏功能。系统 Godot 未被替换。依据：[构建记录](../engine/build-result.json)、[构建说明](../engine/README.md)。
- 官网当前最新稳定版仍是 **4.7.2，2026-08-18 发布**；最新公开预览是 **4.8 beta3，2026-11-09 发布，commit `c51ff06e8`**。本项目已经使用最新稳定版的源码基线，不是停留在很老的版本。[官方稳定版公告](https://godotengine.org/article/maintenance-release-godot-4-7-2/)、[官方预览版公告](https://godotengine.org/article/dev-snapshot-godot-4-8-beta-3/)、[发布列表](https://godotengine.org/blog/release/)、[预览列表](https://godotengine.org/blog/pre-release/)。

## 四类改动到底做什么

| 改动 | 项目用途和实际接线 | 必要性的准确边界 |
| --- | --- | --- |
| 单目斜近裁剪投影的参考投影 | 平面反射绘制仍使用 oblique 投影；灯光裁剪、cluster、阴影拟合、near/far、LOD 和排序改用有限的普通参考投影。仅识别名为 `SaltlinePlanarProjectionProbe` 的 mono XR 接口。 | 为本项目保留原斜裁剪且继续复用内置灯光路径服务，不是通用 XR 或任意投影解决方案。 |
| D24 深度附件与硬件 polygon offset | `rendering/saltline/source_depth_24=true` 优先选择 D24S8；四个私有 render mode 给原贴花/武器刻字添加 raster bias，reverse-Z 反号，独立武器视口常量项乘 20。D24 和 bias 是两个配合使用的能力，前者对齐量化，后者对齐偏移。 | 避免用任意 epsilon 代替原 GL 的 polygonOffset；普通游戏消除贴花闪烁并不要求复制原 D24 量化。 |
| 单纹理固定 4× 各向异性采样 | 私有 shader hint `filter_linear_mipmap_anisotropic_4` 在同一 Forward+ 视口中与普通 8× sampler 并存，LOD bias 固定 0。原 122 个纹理记录中 119 个为 8×，fx_decals 颜色为 4×，法线/ORM 为 1×。 | 对齐原纹理过滤状态。它与衣料高光的 BRDF 各向异性不是一回事。 |
| 每视口源光栅 Y 方向 | `viewport_set_source_raster_y_up` 同步改变投影、front face、cluster、previous projection，并加入 pipeline cache key；`SOURCE_RASTER_Y_UP` 供材质修正像素坐标和 dFdy。world/weapon/planar 开启，颜色与深度各在既有合成入口规范化一次，太阳视口保留原方向。 | 修正 GL/Vulkan 在极细三角形与 4×MSAA 下的覆盖差异。事后翻图片只能改行序，不能恢复已经丢失的样本覆盖。 |

实现依据：[当前补丁](../engine/patches/0003-saltline-source-raster-origin.patch)、[反射脚本](../scripts/planar_reflection.gd)、[材质生成](../scripts/source_scene.gd)、[主渲染链](../scripts/post_pipeline.gd)、[项目配置](../project.godot)。原问题与阶段记录见 [平面反射](planar-reflection.md)、[polygon offset](source-polygon-offset.md)、[实现状态](implementation-status.md)。

## 不改引擎能否替代

以下是工程方案判断，除明确写出已有探针的部分，**没有在当前项目完整实现或做画面、性能验收**。

| 功能 | 官方版可用的替代路径 | 视觉、性能与维护取舍 |
| --- | --- | --- |
| 平面反射斜裁剪 | 镜像 Camera3D + SubViewport 使用普通透视，参与反射的材质按世界裁剪平面 `discard`；效果要求较低时也可使用 ReflectionProbe 或 SSR。 | 前者可保留平面反射效果，但必须覆盖所有材质/粒子，裁剪深度与导数行为不完全等价，fragment discard 也可能增加片元成本。Probe/SSR 的可见范围与遮挡行为不同，不能当原平面反射的精确替代。普通镜像反射方案尚未在当前完整场景验收。 |
| D24 + polygon bias | 普通贴花可用原生 Decal，或把标记烘入底材纹理；也可给独立薄片少量几何偏移。若确实需要原硬件语义，可通过 RenderingDevice 建立自己的 D24 framebuffer 和 raster pipeline。 | Decal/烘焙可减少自定义深度处理，但改变原透明贴片、UV、材质或动态编辑行为。几何偏移会改变轮廓/穿插。片元写 `DEPTH` 或固定 epsilon 不能保证等价于斜率 bias 与 D24 量化。自建 RD pass 能控制深度与 bias，但要自己处理几何提交、材质、遮挡和合成，工作量通常大于小补丁。 |
| 固定 4× sampler | 最简单是全部使用官方全局/视口 4× 或 8×，接受少数纹理差异；要求逐纹理精确状态时，可在自建 RD pass 使用 `RDSamplerState.anisotropy_max=4`。 | 全局 4× 会降低原 119 个 8× 纹理的斜角清晰度；全局 8× 会改变原 4× 贴花的结果。分开视口再合成增加绘制/深度处理；手写多采样近似不等于驱动的硬件过滤，并会增加 shader 成本。 |
| 光栅 Y 方向 | 普通项目直接沿用 Godot 的原生方向。若只纠正输出方向，在合成时翻 UV 即可；若必须复制源 MSAA 覆盖，则可统一自定义 vertex projection、剔除约定与所有深度/后处理坐标，或自建 RD raster pass。 | 本项目已有逐 shader 投影翻转诊断恢复目标三角形覆盖的证据，但这不是可直接投产的完整替代。逐材质处理要维护阴影、透明、正反面、导数和跨视口状态；单改 camera basis 或最终纹理翻转不足以替代当前补丁。关闭/改变 MSAA 会改变画质，也偏离原版目标。 |

这些替代方式使用的底层 API 已在官方版存在：[Spatial shader 的 vertex/fragment 控制](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)、[原生 Decal 的能力和限制](https://docs.godotengine.org/en/stable/classes/class_decal.html)、[RDPipelineRasterizationState 的 depth bias 与 front face](https://docs.godotengine.org/en/stable/classes/class_rdpipelinerasterizationstate.html)、[RDSamplerState 的 anisotropy_max](https://docs.godotengine.org/en/stable/classes/class_rdsamplerstate.html)。因此不能说“Godot 完全没有这些能力”；缺口主要在把这些状态接入既有 Forward+ 场景渲染器的公开接口。

## 新版上游是否已经解决

核查对象为官方公开预览 **4.8 beta3 / `c51ff06e8`**。这里的结论来自实际源码，而不是“文档没有列出某个 API”。没有运行该预览版验证本项目。

1. **任意相机投影入口有进展，不能据此删除 oblique 补丁。** `camera_set_xr_projections` 已允许提交 Projection 数组，单目路径直接传入 `set_camera`。但 `_render_scene` 仍把 `main_projection` 交给 light culler，RD scene 的 near/far 也仍从同一 `main_projection` 提取，没有本项目的 actual/reference 分离。这说明新版入口更方便，但相关旧假设仍在。依据：[相机设置与 light culler 源码](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/renderer_scene_cull.cpp)、[scene near/far 源码](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp)。

2. **D24 受支持，但 Forward+ 未提供同等的项目 opt-in。** `get_depth_format` 仍在 `p_storage=true` 时优先 D32S8，D24S8 是 fallback；Mobile 对应路径优先 D24S8。存在 D24 枚举和设备支持，不等于当前 Forward+ 场景能选择它。内置 spatial pipeline 创建时的 raster state 仍只配置 cull/wireframe，未接入本项目这类材质 polygon bias；公开 RD pipeline 则已支持 bias。依据：[深度格式选择](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/renderer_rd/storage_rd/render_scene_buffers_rd.cpp)、[Forward+ pipeline 创建](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp)。

3. **逐纹理固定 4× spatial sampler 尚无等价接线。** ShaderLanguage 的 TextureFilter 仍只有普通 nearest/linear/mipmap/anisotropic 类别；`samplers_rd_allocate` 按传入 viewport anisotropy 创建整套 sampler，同一套的 anisotropic filters 共用该级别。不是不支持 4×，而是不能用当前普通 spatial hint 在一个 8× 视口内指定某个 sampler 固定 4×。依据：[filter 枚举](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/shader_language.h)、[sampler 分配](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/renderer_rd/storage_rd/material_storage.cpp)。

4. **每普通视口改变场景光栅方向尚无本项目的等价路径。** RD 场景仍设置 `scene_data.flip_y = !p_reflection_probe.is_valid()`；Forward+ pipeline 未从视口状态设置 front face。已有内部反射/坐标校正路径不能直接等同于本项目 world/weapon/planar 的公开开关。依据：[场景 flip_y](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp)、[Forward+ raster state](https://github.com/godotengine/godot/blob/c51ff06e8/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp)。

这些检查没有覆盖 beta3 之后未发布的所有 master 提交，也不是对未来 4.8 stable 的承诺。当前证据不支持“升级到已发布的新版本即可无修改删掉全部补丁”。

## 已有实测证明到哪里

- Oblique：历史水平/俯仰灯光与阴影探针通过；当前 origin 集成又验证水平裁剪、HDR、8 mip 和生命周期。仍未证明所有投影、原生 SSAO/SSR/TAA/fog 等路径兼容。见 [反射说明](planar-reflection.md) 和 [实现状态](implementation-status.md)。
- D24/bias：已有 50 组 Forward+ 偏移探针、32 组透明遮挡检查、48 材质/75 网格映射，以及太阳 D24 深度差异检查。武器独立深度范围的量化次序、跨驱动数值仍不是逐位一致。见 [深度偏移说明](source-polygon-offset.md)、[GPU 报告](../evidence/polygon-engine-verification.json)。
- Fixed4：已有固定 4× 在视口 4×→8× 时保持相同、与普通 4× 相同且与普通 8× 不同的 GPU 对照；透明路径也有历史验证。SDFGI 专项运行和全部原版贴花画面不由这些探针证明。见 [sampler 报告](../evidence/fixed4-sampler-verification.json) 和 [实现状态](implementation-status.md)。
- Raster origin：已有共享材质、正反面、奇数尺寸、165 深度 case、反射和重入检查；特定枪械画面 MAE 从约 0.563 降到 0.232，仍有明显个别像素残差。当前 SHA 的射击录像记录 87 项检查、13 次射击。固定帧率录制不能证明实时 60fps，已有截图也不是用户完整视觉验收。见 [origin 报告](../evidence/raster-origin-verification.json)、[当前录像与引擎记录](../evidence/raster-origin-shooting-video.json)、[完整阶段说明](implementation-status.md)。

本次还在隔离的空项目中分别运行本机官方 4.7.2 和项目定制版：ClassDB 显示官方版没有私有 `viewport_set_source_raster_y_up`、定制版有；官方与定制版均有常规 `camera_set_frustum`。两次探针退出 0、无日志错误，见 [二进制与 API 对照](../evidence/official-stock-api-comparison.json)。这只检查接口存在，不是官方版整项目运行或替代方案画面测试。历史通过记录未重新标记为本次运行通过。

## 为何当前项目不能直接换官方可执行文件

现在的 [post_pipeline.gd](../scripts/post_pipeline.gd) 直接调用私有 `viewport_set_source_raster_y_up`；多个生产 spatial shader 直接读取 `SOURCE_RASTER_Y_UP`；[source_scene.gd](../scripts/source_scene.gd) 会生成私有 fixed4 hint。只有部分 bias/反射逻辑有版本 guard，并没有完整官方版兼容分支。因此当前代码换用 stock 不只是反射或细节画质下降，还会遇到缺失 API 或 shader 编译问题。

README 早期“stock 仍可跑已有太阳/后处理”的文字对应早期阶段，不应当作当前默认场景的承诺。迁回官方版需一次独立项目改造：替换上述调用和 shader 语法，确定反射、贴花与过滤的目标，再验证深度/颜色方向和画面。当前审查没有执行这项改造。

## 丝袜物理与材质项目该借鉴什么

后续丝袜研究若目标是可信的物理、材质和光照表现，采用官方 Godot 稳定版作为基线即可；当前没有证据要求先继承这四类引擎修改。它们也没有新增布料求解器、丝袜拉伸模型或纤维散射模型。普通 spatial shader 已提供法线、粗糙度、透明度、自定义光照与各向异性等材质输入；需要依据实际模型设计组合，不能把“有 API”当成最终效果已通过。[官方 spatial shader 参考](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)。

值得迁移的是研究方法和项目层知识：固定相机与灯光分离检查材质；明确颜色空间、法线方向、mip/过滤与曝光；把物理行为、shader 数值、真实 GPU 画面和性能证据分开记录。透明排序、贴身几何穿插、细织纹理在运动中的混叠、受力形变以及目标硬件帧时间，需要该项目自己的实测。

这里的 `filter_linear_mipmap_anisotropic_4` 只是纹理采样过滤。丝袜纤维沿特定方向的高光是另一种“各向异性”，不要因为同名就沿用 fixed4 补丁。只有未来出现一个可复现的、公开接口无法满足的具体问题，才有理由单独评估引擎修改。

未执行新版 Godot 运行、跨 GPU 验证或替代方案实施；其视觉与性能成本仍是待验证事项。
