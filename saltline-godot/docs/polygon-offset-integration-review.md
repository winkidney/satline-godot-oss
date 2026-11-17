# D24 与硬件 polygonOffset 接入审查

本轮只读审查生产代码、补丁和已有 GPU 报告，没有重新运行 GPU 测试，没有修改生产或引擎文件。结论限定为当前 NVIDIA RTX 4070 SUPER、Forward+、启动时固定 D24 设置和已审计的 48 个透明材质。该范围内未发现新的阻断缺陷，可以保留当前接入。

本轮确认的引擎二进制 SHA256 为 `1f621cd3a85ba413b3a385b2a19b828bc145bf2da9e86f9fc515908a1a639a2f`。重新计算了本地 11 个已改源文件、完整 patch 和二进制的 SHA，全部与 [source-manifest.json](../engine/source-manifest.json)、[build-result.json](../engine/build-result.json) 相符。原 archive 应用验证见 [source-bias-patch-verification.json](../evidence/source-bias-patch-verification.json)。这份审查没有把旧 oblique-only 二进制当成当前构建。

## 已核对的生产路径

[source_scene.gd](../scripts/source_scene.gd) 在创建材质前，从原导出节点的 `layers` 累积每个 material 的 mask，不读取经过 Sun/local fallback 修改的 native 高位 layer。当前数据重新统计为 48 个 MeshStandardMaterial、75 个 Mesh，47 个材质只用于 world、1 个只用于 weapon；全部 `castShadow=false`，没有跨两类相机复用。

映射为 46 个 world -2/-2、1 个 world -4/-4、1 个 weapon -3/-3。生成器正确注入对应的私有模式。world_3 是隔离探针模式，目前没有原生产材质使用它。遇到不支持的 factor/units 或 world+weapon 共用时会报错，不会擅自选择某一侧。

`_generic_shader()` 的缓存 key 包含完整修改后 shader 文本的 SHA，因此 bias 模式和 sampler declaration 都参与缓存区分。新建 shader 保留 `source_shader_path`，材质保留 `source_material_id` 与 `source_polygon_offset_mode`。Sun、IBL 和 local service 都从这份来源 metadata 识别派生 shader；没有因 resource_path 为空而漏迁移。现有同 shader 的材质仍可共享 shader，参数保持在各自 ShaderMaterial。

[引擎补丁](../engine/patches/0001-saltline-render-fidelity.patch) 将模式存入 ShaderData，在 `set_code()` 开头重置，并给实际 raster state 设置 slope/constant，未写片元 DEPTH。`set_code()` 的现有 pipeline cache 清理仍在。模式是每个 ShaderData 的静态状态，因此不必另把它复制进该 ShaderData 内部的 PipelineKey。

`uses_shared_shadow_material()` 已增加 offset=NONE 的前提，普通绘制和异步预编译共用这个判定，避免带 bias 的 depth/prepass 被替换成无 bias 默认 shader。50 组 opaque 探针也检查了 color 保持白色，因此当前 prepass/EQUAL 路径有实际证据。

格式选择统一改在 `RenderSceneBuffersRD::get_depth_format()`，实际附件、辅助附件和 Forward+ framebuffer/pipeline 预编译仍调用同一个 helper。R32F storage/resolve 的早返回完整保留，没有把 compute resolve 输出误改成 D24。D24_S8 保留 stencil 兼容路径。当前四类场景相机均实测 format=128，见 `d24-*.log`。

## 证据范围

| 证据 | 本次读到的结果 | 能支持的结论 |
| --- | --- | --- |
| [polygon-engine-verification.json](../evidence/polygon-engine-verification.json) | 50 profiles、0 failures；最大残差 1.375 q24；0/4xMSAA | Forward+ D24、reverse-Z 符号、四模式 constant、weapon×20、opaque prepass/color 与两种 native 斜率 |
| [polygon-transparency-verification.json](../evidence/polygon-transparency-verification.json) | 32 profiles、0 failures；48 material / 75 mesh | 透明 alpha=.5、四种后方间隙、depthWrite=false；全部导出材质映射 |
| 同上真实材质探针 | decal_logo_a 改变 5 个 HDR 像素；weapon_markings 改变 368 个；仅切 bias | 原几何、UV、纹理及生产 shader 上存在实际硬件偏移贡献 |
| [d24-source-sun.log](../evidence/d24-source-sun.log)、[source-sun-runtime.json](../evidence/source-sun-runtime.json) | 360 帧，各相机 128，功能断言 0 failures | 当前冻结场景源太阳与 PCSS 在 D24 下继续生效 |
| [d24-ao.log](../evidence/d24-ao.log)、[ao-runtime.json](../evidence/ao-runtime.json) | 240 帧，格式及功能断言通过 | 当前源 AO 在 D24 输入下继续生效 |
| [d24-volume.log](../evidence/d24-volume.log)、[volume-runtime.json](../evidence/volume-runtime.json) | 360 帧，格式及功能断言通过 | 当前有阴影体积光在 D24 下继续生效 |
| [d24-planar.log](../evidence/d24-planar.log)、[planar-runtime.json](../evidence/planar-runtime.json) | 240 帧，15,859 个采样变化；0 failures | 当前实际 oblique 反射、排除 mask 与回调顺序继续成立 |
| [sun-depth24-delta-verification.json](../evidence/sun-depth24-delta-verification.json) | 4096² 全图、148 个 eligible caster；402,512 像素变化；最大 1 q24；无超过 2 q24 | 当前静止姿态下 native D32→D24 的整个 shadow producer 差异受该界限约束 |
| [planar-lifecycle-verification.json](../evidence/planar-lifecycle-verification.json) | source_bias 引擎、8 cases、重入 0 failures；文件产生于项目启用 D24 之后 | 当前 resize、暂停恢复、XR/layer 还原和重建链回归通过 |

斜率证据没有使用 CPU tan 作为最终精确基准。当前 [verify_polygon_engine.gd](../tools/verify_polygon_engine.gd) 取无偏移 GPU 深度图相距 32 像素的梯度，容差仍为 2 q24。旧 nominal-slope 失败留在 [polygon-engine-nominal-slope-failure.json](../evidence/polygon-engine-nominal-slope-failure.json)。这验证 native 硬件 factor 对实际梯度的响应，不等于原 GL 与 native 使用同一 clip 几何后的斜率逐点等价。

## 需要收口的事项

1. **报告与文档状态滞后。** 审查时 engine README 和 source-manifest.build_state 仍写“生产未启用、30 组、48 材质未接”；实际 project.godot 已为 true，报告已有 50 组和生产绑定。polygon-engine JSON 的 scope 也是旧文案，脚本内 scope 已更新。应同步这些说明，保留失败和原始数值，不将旧文字继续当当前状态。
2. **D24 fallback 保护已在审查期间补入。** 原实现只检查项目设置及 version.status，可能在附件回退 D32 后继续使用 D24 参数。现已读到 `_prepare_source_polygon_support()`：先检查隔离构建与 RenderingDevice，再检查 D24 的 sampling+attachment，以及额外 copy-from 两种 usage；不支持时关闭模式注入、明确警告并记录 requested/supported/reason。该修正解决格式 usage 不支持时误开 bias 的路径。它不校准其他驱动的 r，也不替代实际 MSAA4 附件测试。当前四类相机的真实格式 128 仍是本机证据。
3. **该设置应固定在启动前。** helper 每次动态读取 ProjectSettings，而已经分配的 viewport buffer、已有 pipeline 和已生成材质不会因设置变动全部重建。生产脚本没有运行时改动这个设置，因此当前安全；诊断在改值后重新创建 shadow viewport。不要把它做成可热切换的 UI 选项，除非同时完成所有相关资源和材质重建。

尚需让 capability guard 明确要求 `RenderingServer.get_current_rendering_method()=="forward_plus"`。Mobile 也可能有 RenderingDevice 和 D24 支持，但模式只接入 Forward+ actions；全局 parser 接受这些模式，其他 renderer 会静默忽略。当前 project.godot 固定 Forward+，不受此项影响。

本轮审查时，game-flow 数学报告和 runtime 文件仍早于项目启用 D24，未将它们计作新的 D24 flow 回归。父代理正在运行新 flow 和 capability guard 回归，最终交付应采用随后完成的结果；这不影响上表已读到的专项证据。

## 原生灯光和阴影隔离

本轮没有修改 LightStorage 的 directional/omni shadow-atlas 格式选择。D24 helper 改动作用于普通 scene buffers，并不自动把原生 shadow atlas 改成 D24。四类已测相机里的 sun 是项目自建的普通 SubViewport，所以它确实随全局设置改变，已由全图差异和功能回归单独覆盖。

75 个 offset Mesh 不投影；自建 sun pass 又使用独立 `shadow_depth_front/back/double` 材质，未从 generic shader 复制 private bias 模式。因此当前不存在贴花 bias 被意外加到固定太阳 shadow 图的路径。

派生 shader 的来源 metadata 没有丢失，Sun/local 服务继续使用既有高位 fallback mask 隔离 native 直接光。D24 与 raster mode 本身没有修改这些 mask、原 receiveShadow 或原灯光强度。本次代码审查未发现新增 native sun/local 回漏机制；原有十一灯能量压测证据属于上一轮光照审查，并非本轮新跑的测试。

私有模式目前对全部 pipeline version 固定采用 reverse-Z 系数。若将来把这些模式用于 `depth_test_inverted`、原生 shadow caster、内建 ReflectionProbe、材质烘焙或不同格式附件，需要重新定义 pass 符号与 r；尤其 weapon 的 60 units 只对应独立 weapon viewport。禁止 shared-shadow 替换只是保留状态，并不能证明那些路径正确。当前生产48材质不使用这些扩展路径。

## 保留的保真边界

独立 weapon viewport 仍有 `Q24(s*z+offset)` 与 `s*Q24(z+offset/s)` 的量化顺序差异。units×20 修正连续偏移尺度，不能据此声称原 world+weapon 共用 D24 depthRange、深度相等边界和 MSAA resolve 已经逐位相同。

原 GL shadow 的消费者读取高精度 RGBA packed depth，当前 native 读取真实附件后转换成 R32F。16M 像素扫描证明的是 native D32/D24 两个 producer 在当前静态场景中的差异，没有将原 packed shadow 全图或动态 PCSS 阈值改判为已对齐。现有原/native MSAA sample-location 差异也继续保留。

真实贴花探针确认两种材质路径的可见贡献，48/75 是绑定覆盖，不等于每一个实际贴花在所有视角都与原图像一致。oblique 反射专项证明生产链仍能工作，也不是所有反射贴花斜率的原 GL 像素对照。这些边界不妨碍当前接入成立，但应继续写入最终阶段结论。

## 主线后续收口

已补RenderingServer.get_current_rendering_method()==forward_plus的能力条件，Mobile不会注入未接线的私有模式。最终透明/映射与unsupported guard重跑通过。默认project=true之后的780帧flow日志和报告已完成，pause冻结、两次retry均通过。README、manifest、scope描述和最新视频已同步；量化/驱动/原packed shadow等边界不变。
