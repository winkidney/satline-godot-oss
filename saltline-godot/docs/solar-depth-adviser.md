# 原作 Q9 太阳遮挡的 GPU 深度桥

日期：2026-11-15。目标运行版本为 Godot 4.7.2 `ed1daf0bf`，Forward+ / NVIDIA Vulkan。本文是实现建议；本轮只新增本文档，没有修改运行代码，也没有运行真实场景深度桥验收。父代理另行完成的 64 组 Q9 合成输入验证，不等于这里的实际深度桥验证。

建议让世界和武器相机各挂一个独立 `CompositorEffect`，在 `POST_TRANSPARENT` 取得实际 depth，compute 转存到各自持久 R32F 纹理，用 `Texture2DRD` 暴露给 Q9。没有额外场景绘制、每帧 CPU 回读或深度代理几何。世界保留正向非线性深度；武器输出仅供太阳遮挡使用的 0/1 数据。Q9 每个 tap 合并两者，不需要新增合成 viewport。

## 实施纠正：纹理必须在帧前发布

父代理实际GPU验证发现，下文原建议的“回调中_ensure_output并更换wrapper”会在resize当帧导致Canvas uniform set失效。延后释放旧base RID两帧仍不能解决，因为Texture2DRD.texture_replace自身释放旧shared view；材质dirty刷新在draw_viewports之前已经结束。实际实现改为主线程prepare_size→call_on_render_thread，在下一帧材质刷新前分配/发布纹理；Compositor回调只写已准备的目标。意外尺寸不匹配时不读旧数据，标记未就绪并deferred请求帧前准备。此项纠正优先于下文原实施骨架。证据和实际接口见[实现记录](solar-depth.md)。

## 原作实际读取哪一份深度

来源：[原 bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)，行号按当前提取文件。

| 来源 | 结论 |
| --- | --- |
| `Q9`，35844 起 | 12 个太阳圆盘 tap；纹理内部以 `step(0.99999, depth)` 判定可见；越界 tap 算可见，再乘 `uSunOn`，最后与上一帧可见度混合 |
| `q = me.depthTexture`，36410；绑定 Q9，36536 | Q9 使用最终 HDR 场景 target 的 depthTexture |
| 相机建立，36693–36697 | 世界 near/far 为 `.08/900`；武器为 `.01/10`，两相机各自的层过滤不同 |
| `Z()`，36942–36954、36975–36991 | 先画世界，再可选复制世界深度供软粒子，随后 `depthRange(0,.05)` 画武器，恢复 `[0,1]`，才执行 post |
| fallback `F()`，36916 | 此处的 `clearDepth()` 不属于上述 advanced HDR 路径，不能套用到 Q9 的语义 |

因此 Q9 不是读取“世界 opaque 副本”。它包含所有实际写 depth 的世界和武器片元。当前 prepared 资产 195 个材质中，61 个透明材质都关闭 depthWrite；两个 chainlink 材质为 alphaTest=.5 且写深度，孔洞通过 discard 保留天空。原材质工厂见 39737–39741。天空、瞄具玻璃、标记、枪口光与粒子不应凭颜色 alpha 被当作深度遮挡。当前 Godot 的 `dynamic_sky`、`source_material*_alpha`、`sight_glass` 已使用 `depth_draw_never`；opaque/alpha-test 路径使用真实深度写入。

原武器深度候选范围是 `[0,.05]`，一定低于 `.99999`。对这个二元测试，武器存在有效深度时写 0，与保存完整的原 depthRange 值等效：即使武器被极近的世界表面挡住，该世界表面本身也已经使太阳不可见。这个推论不提供场景距离、软粒子、AO、雾或世界位置恢复所需的深度；武器桥应命名为 solar occlusion 数据，禁止复用于这些用途。恰落在武器 far 平面、reverse depth 恰为 0 的片元与清屏值无法仅凭 depth 区分，应纳入边界说明。

## 挂接阶段与同帧顺序

两个 effect 分别挂到 `camera.compositor`、`view_camera.compositor`，不挂共享 `WorldEnvironment`，也不让两台相机共用同一个有输出状态的 effect 实例。已有 compositor 时，将 effect 加入各自 effect 数组，保留其他 effect 的明确次序。相机 compositor 的作用域见 [官方教程](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)。

设置：

```gdscript
effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
access_resolved_depth = true
access_resolved_color = false
```

这个回调在渲染线程执行，`RenderData` 仅在回调内有效，不能保存到下一帧。[CompositorEffect API](https://docs.godotengine.org/en/stable/classes/class_compositoreffect.html)

版本源码显示透明绘制位于 [render_forward_clustered.cpp:2163–2177](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L2163-L2177)，随后 [2181–2203](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L2181-L2203) resolve depth 并调用 POST_TRANSPARENT。该点尚未运行 TAA/FSR2 和最终 tonemap。

```text
world_port 3D → world effect：本帧实际 depth → world R32F
weapon_port 3D → weapon effect：本帧实际 depth → weapon R32F
history_copy → scene/down/up/streak → adapt(Q9：读取两张本帧 R32F) → tk
```

继续让两个 3D viewport 先于 Q9 所在 2D viewport 注册/渲染。sampler 引用本身不会改变 viewport 排序；[renderer_viewport.cpp:90–115](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_viewport.cpp#L90-L115) 按 viewport 层级及同级原顺序排列。相机在 world_port 内使用 effect 不会额外注册一个 viewport。

## RD 实施步骤

使用 `RenderingServer.get_rendering_device()` 的全局 RD，不能用 local RD：后者不是当前渲染场景及 Canvas 采样所用的设备。创建、dispatch、换 RID 和释放集中在渲染线程；主线程只配置资源和接收 deferred 元数据通知。不要在回调内修改 SceneTree、访问 live Camera3D 属性或更新 UI。

每个 effect 持有以下长期资源：`Texture2DRD output`、RD shader、compute pipeline、nearest/clamp sampler、输出 texture RID、输出尺寸和释放状态。`output` 是始终不替换的资源对象，材质只绑定它一次。其底层 RD texture 在 resize 时替换。

1. 初始化时将下述 compute 源编译为 SPIR-V，检查 `compile_error_compute`，创建 shader 和 pipeline。可以先用内嵌 `RDShaderSource.source_compute` 实施；稳定后迁移到导入的 `.glsl`，避免运行时重复编译。
2. 创建 `RDSamplerState`：min/mag/mip 全为 nearest，U/V clamp-to-edge，关闭 comparison。输入用 sampler2D 读取数值，不用 shadow sampler。
3. 回调中取 `render_data.get_render_scene_buffers() as RenderSceneBuffersRD`；确认非空、`get_view_count()==1` 和有效尺寸。使用 `get_internal_size()`，不是窗口尺寸；使用 `get_depth_layer(0)`，不是其他 viewport 的 depth，也不是普通 2D `hint_depth_texture`。这两个方法的含义见 [RenderSceneBuffersRD API](https://docs.godotengine.org/en/stable/classes/class_renderscenebuffersrd.html)。
4. 分配输出格式 `DATA_FORMAT_R32_SFLOAT`，`TEXTURE_TYPE_2D`，width/height 为内部尺寸，depth/layers/mipmaps 各 1，`TEXTURE_SAMPLES_1`，usage 为 `TEXTURE_USAGE_STORAGE_BIT | TEXTURE_USAGE_SAMPLING_BIT`。测试需要 RD 回读时另加 `TEXTURE_USAGE_CAN_COPY_FROM_BIT`；生产不需要回读。不要标记 discardable。创建前检查格式/usage 支持。
5. 每次回调重新取得当前源 depth RID；resize、MSAA 或渲染设置改变时，尺寸相同也可能换 RID。创建/查询匹配这些 RID 的 uniform set，推荐 `UniformSetCacheRD.get_cache()`；它会随依赖资源释放而清理。[UniformSetCacheRD API](https://docs.godotengine.org/en/stable/classes/class_uniformsetcacherd.html)
6. dispatch `(width+7)/8 × (height+7)/8`，保证边界判断，结束 compute list。不要在全局 RD 上调用 `submit()`、`sync()` 或 GPU readback。Godot 在 uniform 绑定时管理纹理访问及图像 barrier；后续 Canvas 必须引用同一输出 RID 的 wrapper，不能引用过期的另一个 texture。[RenderingDevice API](https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html#class-renderingdevice-method-compute-list-bind-uniform-set)

以下是核心 shader；它保持 Godot depth 的像素行方向，纵向翻转只由 Q9 现有 `sourceSample()` 执行一次：

```glsl
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0, binding=0) uniform sampler2D source_depth;
layout(r32f, set=0, binding=1) uniform restrict writeonly image2D out_depth;
layout(push_constant, std430) uniform Params {
    ivec2 size;
    int weapon_mode;
    int reserved;
} params;
void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(p, params.size))) return;
    float z = texelFetch(source_depth, p, 0).r;
    float out_value = params.weapon_mode != 0
        ? (z > 0.0 ? 0.0 : 1.0)
        : clamp(1.0-z, 0.0, 1.0);
    imageStore(out_depth, p, vec4(out_value, 0.0, 0.0, 1.0));
}
```

核心 GDScript 绑定步骤如下；`_ensure_output()` 负责上面的格式创建及尺寸变化处理，`shader/pipeline/sampler/output_rd` 已在渲染线程初始化。此片段是实施骨架，不是已经验证的完整组件：

```gdscript
func _render_callback(kind: int, render_data: RenderData) -> void:
    if kind != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or closing:
        return
    var buffers = render_data.get_render_scene_buffers() as RenderSceneBuffersRD
    if buffers == null or buffers.get_view_count() != 1:
        return
    var size = buffers.get_internal_size()
    if size.x < 1 or size.y < 1:
        return
    var source_rd = buffers.get_depth_layer(0)
    if not source_rd.is_valid():
        return
    _ensure_output(size)

    var source = RDUniform.new()
    source.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
    source.binding = 0
    source.add_id(sampler)
    source.add_id(source_rd)
    var dest = RDUniform.new()
    dest.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    dest.binding = 1
    dest.add_id(output_rd)
    var bindings = UniformSetCacheRD.get_cache(shader, 0, [source, dest])
    var params = PackedInt32Array([size.x, size.y, int(weapon_mode), 0]).to_byte_array()
    var commands = rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(commands, pipeline)
    rd.compute_list_bind_uniform_set(commands, bindings, 0)
    rd.compute_list_set_push_constant(commands, params, params.size())
    rd.compute_list_dispatch(commands, ceili(size.x/8.0), ceili(size.y/8.0), 1)
    rd.compute_list_end()
```

不要直接用 `texture_copy` 代替 shader：目标不是原 depth 格式的字节副本，而且需要 reverse-Z 转换。R32F 必须直接进入 Q9，不能经过 RGBA16F 的普通 HDR 2D 中转；half 在 1 附近的间距远大于 `.00001`，会改变原阈值。

## Q9 的接线、投影与采样

保留 `tDepth` 作为世界桥，加一个 `tWeaponSolarDepth`；两者均为 `filter_nearest, repeat_disable`，没有 `source_color`，不用 mipmap。Q9 原来的内部采样只需变成：

```glsl
float scene_depth = min(sourceSample(tDepth, uv).r,
                        sourceSample(tWeaponSolarDepth, uv).r);
vis += step(0.99999, scene_depth);
```

越界 tap、十二点位置、`uSunOn` 和历史适应均继续使用原公式。两张图不同尺寸时分别按相同 normalized UV 最近邻采样；不要先把武器遮挡降采样到 bloom 尺寸。

Godot reverse-Z 在 near=1、far=0；源码的 [Projection::set_depth_correction](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/projection.cpp#L733-L751) 给出反转与 OpenGL→Vulkan z 区间变换。在世界相机 near/far、投影和视图匹配时，`1-native_z` 就是原 Three 的正向非线性 depth，不需要线性化。这里不是 `1-linear_distance`，也不是简单判断 `native_z==0`：原 `.99999` 有意允许靠近 far 的深度通过。near/far 不一致时，应先从 native depth 恢复 view depth 再按原投影重新投影，不能只做 `1-z`。

原 `uSunUv` 是 Three 投影所得的左下原点 UV；36519–36529 使用 `cameraPos + sunDir*500` 投影，正面条件为 dot>.05，NDC 边界在 1..1.3 淡出。Godot `unproject_position()` 得到左上原点屏幕像素时，先除以 viewport size，再将 y 改为 `1-y`。不在 compute 中再翻转。用一个只占左上角的遮挡物实际验证这个约定，不能用中心太阳或对称遮挡验收纵向。

保持相机配置一致：world `.08/900`；weapon `.01/10`。父代理已在本轮将 native weapon far 从 5 改为 10。仅改深度数值转换无法修复裁剪范围、FOV、层过滤或 geometry/material 差异。

## 资源替换与销毁

`Texture2DRD.texture_rd_rid` 可以把 RD texture 暴露为材质采样纹理。[Texture2DRD API](https://docs.godotengine.org/en/stable/classes/class_texture2drd.html)；其 [setter 源码](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/resources/texture_rd.cpp#L73-L107) 会在渲染线程更新底层对象，并通过 `texture_replace` 保持已有 RenderingServer texture RID。它只释放 wrapper，不能代替调用方释放自建 RD texture。

- **启动：**预先建立持久 wrapper，并在主线程把 wrapper 绑定到 Q9。可以用一张初始化为 1 的 2×2 R32F 做占位。真正 copy 完成前保持 solar 未就绪，不把全黑未初始化纹理当作遮挡。就绪通知只传递元数据，不读 GPU。
- **resize：**在回调中按实际内部尺寸创建新 texture，令同一 wrapper 指向新 RID，再释放旧 RD RID。旧资源销毁由 RD 延后到 GPU 使用结束；不能先 free 再换 wrapper。新 texture 当帧由 compute 完整覆盖；不要从旧图拉伸继承遮挡。
- **线程：**渲染线程调用 wrapper setter 在该版本立即执行，见 [call_on_render_thread 实现](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/rendering_server_default.h#L1099-L1105)。避免主线程同时读取/修改 effect 可变字段；需要共享状态时用 Mutex 或只在 render-thread task 内操作。不要连接会在 `changed` 中操作 SceneTree 的回调。
- **关闭：**主线程先从两台相机解绑 effect，并让 Q9 改回明确的安全纹理/停止消费；随后排队渲染线程清理：清空 wrapper RID，释放输出 texture、sampler 和 shader，清空字段。释放 shader 会释放依赖的 pipeline，不重复 free。用显式 dispose 做主路径，PREDELETE 只做幂等兜底，避免异步 callable 使用已经销毁的对象。
- **引擎资源：**绝不释放 `buffers.get_depth_layer(0)`，不跨帧保存 `RenderData` 或 `RenderSceneBuffersRD`。源 depth 属于引擎，可随配置改变而重建。

## 仍需隔离验证的差异

**MSAA 不能直接宣称等价。** 原 high 配置为 4× MSAA。Godot 该版本的 [resolve.glsl:38–45](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/effects/resolve.glsl#L38-L45) 对 depth 取各样本算术平均；原 Three/WebGL depth resolve 的实际行为需要用同一条几何边缘实测确认。两个独立 viewport 的 resolved depth 再合并，也不普遍等于“逐 MSAA sample 合并世界和武器后再 resolve”。因此本方案精确保持真实深度来源及 Q9 判定，边缘 coverage 的跨后端等价仍待证。

原 target 的 UnsignedInt depth、Nearest 和 samples 配置见 36792–36803；默认 resolveDepthBuffer=true 在 3419。Three 把该深度类型分配为 DEPTH_COMPONENT24（30594–30610）；常规 resolve 路径在 31903–31925 使用含 DEPTH_BUFFER_BIT 的 `blitFramebuffer(...NEAREST)`，31978–31984 也允许 multisampled-render-to-texture 扩展路径。[OpenGL ES 3.0.6 §4.3.3，正文 p198](https://registry.khronos.org/OpenGL/specs/es/3.0/es_spec_3.0.pdf) 允许深度 resolve 在该像素样本最小值与最大值间选取实现定义的值，不能从 NEAREST 推断它必取 sample 0。原 D24 与 native depth 格式的量化差异也应在 `.99999` 临界值附近单测。

若边缘验证显示差异，再通过 `get_depth_layer(0, true)` 及 `sampler2DMS` 在桥内显式选择原参考所证实的 resolve 规则；此时保持单独非 MSAA 路径。不要凭猜测选择 min/max、sample 0 或平均。若要复现原合并后 resolve，必须保存两路 MSAA 样本并在单个 GPU pass 中按原 depthRange 逐 sample 合并，且两相机采样位置/样本编号仍须验证。不要为掩盖差异把 `.99999` 放宽。

建议验收按以下顺序，CPU readback 仅允许出现在独立测试工具：

1. 世界空背景得到 forward 1；实心遮挡得到 `<.99999`；chainlink 孔洞通光；天空/透明玻璃不写入；武器空背景为 1、实体为 0。
2. 左上角单侧遮挡，移动太阳到四象限，证明 UV 只翻一次；不同 world/weapon 尺寸、resize 后检查对应位置。
3. 非周期帧编号驱动世界/武器遮挡，逐帧读取 Q9.g，验证两路均为本帧，历史仍仅来自上一帧。不要只交替两种图案，否则两帧延迟可能漏检。
4. 固定相机与太阳，以真实薄三角形/栅栏边缘逐亚像素移动，比较原 Three 和 Godot 的 12 tap 原始可见数，再比较适应后的 g；分别记录 MSAA off/4×。
5. 连续 resize、重建/关闭场景和重新进入游戏，检查无失效 RID、无初始化闪光、无 VRAM 随重建增长。缺少/无效 depth 或跳过 viewport 渲染必须显式报状态，不能默默继续把旧深度当作本帧。

这份桥只完成“当前实际 GPU 深度进入太阳遮挡采样”的接口。太阳方向/投影、`uSunOn`、flare 参数、原与 native 材质裁剪和 MSAA 边缘一致性仍需各自证据；报告不把这些边界合并成已经完成的视觉等价声明。
