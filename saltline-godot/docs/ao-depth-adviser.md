# 原作 AO 深度、格式与 MSAA 边界

日期：2026-11-15。审查对象为原 Three r180 bundle 和 Godot 4.7.2 `ed1daf0bf` 的现有双深度桥。本轮只新增本文档，不改运行代码。当前实施范围是独立 R32F half-depth 组件及原 q9 的奇偶尺寸 GPU 对照；默认游戏暂不启用原 AO，也不把太阳用的武器 0/1 mask 宣称为 MSAA4 完整深度等价物。

原作行号均来自 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。RD 生命周期依据当前 [solar_depth_bridge.gd](../scripts/solar_depth_bridge.gd) 的帧前 `prepare_size()`；不能在 compositor callback 内发布替换纹理。该限制来自本项目 resize 实测发现的 Canvas 材质 uniform set 刷新窗口。

## 真实目标格式与采样

| 数据 | 原构造 | 实际格式 | 采样 |
| --- | --- | --- | --- |
| depthHalf，主路径 | `p(us,h,{format:Jc})` | R32F | nearest / clamp edge / 无 mipmaps |
| depthHalf，fallback | `p(c,h)` | RGBA16F，仅 r 存 z | nearest / clamp edge / 无 mipmaps |
| aoA、aoB | `p(u,h)` | RGBA8 UNORM 数据，不是 sRGB | nearest / clamp edge / 无 mipmaps |
| volA、volB | `p(c,h)` | RGBA16F | nearest / clamp edge / 无 mipmaps |
| scene、motion | `p(c,f)` | RGBA16F | linear / clamp edge / 无 mipmaps |

`c=ro=1016` 是 HalfFloat，`u=wi=1009` 是 UnsignedByte，`us=1015` 是 Float，`Jc=1028` 是 RedFormat；`h=Dn=1003` 是 Nearest，`f=x0=1006` 是 Linear。名称可与 [Three r180 官方 constants.js](https://github.com/mrdoob/three.js/blob/r180/src/constants.js) 对照。

证据链：`p()` 默认 RGBA、无 depth/stencil 附件、无 mipmaps 在 36058–36073；目标选择在 36111–36125；GL 类型转换在 32040、32050–32057；R32F 内部格式在 30533–30536，RGBA16F/RGBA8 在 30572–30577，filter 映射在 30789–30796。Texture 默认 `colorSpace=ci=""` 在 587、2759–2766，`p()` 未覆盖。因此 AO 纹理是数值数据，没有 sRGB 传递函数。

`v` 只表示 `EXT_color_buffer_float` 扩展存在，异常则 false；它不是浮点线性采样能力检查，也不是创建 framebuffer 后的完整性试验。参考 fixture 应记录实际 `v` 与内部格式。以主路径为目标使用 R32F 是正确的；不能用 Godot 普通 HDR 2D 的 RGBA16F 代替它并称为同精度。

原 AO 顺序为 `X9 → aoA`、横向 `QM → aoB`、纵向 `QM → aoA`，见 36429–36435。**三个输出阶段分别经过 RGBA8 量化**，不是仅最后量化一次。可以用 `use_hdr_2d=false` 的专用数据 viewport 或 RD RGBA8_UNORM 实现；直接输出 AO 数值，sampler 不加 `source_color`，关闭混合并写 alpha=1，随后实际检查格式和读回值。若采用 HDR pass，必须另行保留每个原存储边界的 8-bit 量化，不能依靠最终显示转换补回。

## q9 的 half-depth 精确坐标

原 q9 在 35636–35639：

```glsl
ivec2 p = min(ivec2(gl_FragCoord.xy) * 2, textureSize(tDepth, 0) - 1);
float d = texelFetch(tDepth, p, 0).r;
float z = d < 0.05 ? 0.01 : (uNear*uFar)/(uFar-d*(uFar-uNear));
```

这是每个 2×2 区域选一个确定 texel，不是平均、min/max、双线性或区域中心采样。全尺寸先至少为 8；half 尺寸为 `max(4,ceil(W/2)) × max(4,ceil(H/2))`，见 36339–36362。

原 gl_FragCoord 与原输入纹理均按 bottom-origin 理解。当前桥导出的 RD 纹理、compute invocation 行坐标均按 native top-origin 存储。设目标 native half 像素为 `(x,y)`，`HH=ceil(H/2)`，正确转换是：

```text
source_bottom = min((2*x, 2*(HH-1-y)), (W-1,H-1))
source_top    = (source_bottom.x, H-1-source_bottom.y)
```

由此，x 总取 `2*x`；**偶数 H 的源 top 行为 `2*y+1`，奇数 H 为 `2*y`**。不能简单地对 native top-origin 图 `texelFetch(2*p)`。直接枚举已核对：

| 全高 H | half 高 | 目标从顶到底所取源 top 行 |
| --- | --- | --- |
| 8 | 4 | 1、3、5、7 |
| 9 | 5 | 0、2、4、6、8 |
| 10 | 5 | 1、3、5、7、9 |
| 11 | 6 | 0、2、4、6、8、10 |
| 720 | 360 | 1、3、…、719 |
| 721 | 361 | 0、2、…、720 |

因此测试应同时覆盖奇偶宽高，使用逐像素不同的非对称深度数据。纯色、中心物体或对称图不能验证这个索引规则。

## 当前 half-depth 组件的数据契约

当前方案可在 weapon compositor 的真实深度桥之后追加一个独立 compute effect：读本帧 world forward R32F 和本帧 weapon 0/1 mask，写独立 R32F half-depth。world viewport 必须先完成；同一 weapon compositor effect 数组中的顺序必须是 weapon bridge 在前、half-depth effect 在后。两个源的尺寸、帧代数和就绪状态均需匹配。

以同尺寸 world/weapon 输入为前提，核心逻辑如下：

```glsl
ivec2 dst = ivec2(gl_GlobalInvocationID.xy); // native top-origin
ivec2 full_size = textureSize(world_forward, 0);
ivec2 half_size = (full_size+ivec2(1))/2;    // 原有效全尺寸 >= 8
if (any(greaterThanEqual(dst,half_size))) return;
ivec2 source_bottom = min(ivec2(dst.x,half_size.y-1-dst.y)*2,
                         full_size-ivec2(1));
ivec2 source_top = ivec2(source_bottom.x,full_size.y-1-source_bottom.y);
float d = texelFetch(world_forward,source_top,0).r;
bool weapon = texelFetch(weapon_mask,source_top,0).r < 0.5;
float z = (weapon || d<0.05) ? 0.01
    : (near_plane*far_plane)/(far_plane-d*(far_plane-near_plane));
imageStore(depth_half,dst,vec4(z,0.0,0.0,1.0));
```

武器 mask 只能选择 `.01` 标记分支；**绝不能把 0/1 mask 代入世界距离线性化**。非武器像素使用真实 world forward depth，保留原近远裁剪面 `.08/900`。若输入尺寸不同，应先明确输出对应哪一个原 full-resolution grid；按 normalized UV 重采样武器是适配策略，不是原单张组合深度的逐 texel 等价。

还必须保留 `worldD<.05`。原作的阈值没有真正识别 mesh 类型，它也会把极靠近世界 near plane 的片元当作需要 bypass：`.08/900` 投影下，forward d=.05 对应 view distance 约 `.08421013235`。只按 weapon mask 分类会改变约 `.08..08421` 范围内世界表面的行为。等号按原代码：`d==.05` 不进入标记分支。

这是“真实世界距离 + 明确无距离标记”的专用 half-depth 数据，而不是通用世界深度。以后任何消费者必须理解 `.01` 的含义，不能把武器标记反投影成真实世界位置。

复用 SolarDepthBridge 的目标创建和清理机制可以，但初始化 clear 值不能无意识继承太阳纹理的 1：half-depth 的未就绪值应明确选择 far-plane 深度或单独禁用消费者。帧前准备输出尺寸并发布 Texture2DRD；回调只 dispatch。意外尺寸不符时显式报告未就绪，不把上一帧纹理静默标为本帧。最新 `prepare_size` 模式已经处理了换 RID 的 Canvas cache 风险。

## 原 AO、模糊和 composite 的 bypass 范围

| 原 pass | 必须保留的行为 | 行号 |
| --- | --- | --- |
| q9 | `d<.05 → z=.01` | 35636–35639 |
| X9 AO | 仅中心 `z0<.05 || z0>140` 时 AO=1 | 35645–35646 |
| X9 梯度和 spiral | 邻居/采样点 z2 没有独立武器排除；`.01` 继续参与公式 | 35649–35669 |
| QM blur | 无 weapon early return，按深度 bilateral 权重；AO 的 BLUR_TOL=.04 | 35734–35743、36209 |
| `$9` composite | full-resolution `d>=.05` 才运行 AO/vol；AO 还要求 `d<.99999` | 35752、35768 |
| Y9 vol | `z<.05` 输出 `(0,0,0,1)` | 35691–35692 |
| Z9 motion | 中心 `d<.05` 保留原色；tap 的 `d<.05` 令其权重为 0 | 35783、35795 |

不要给 X9 邻居、spiral 或 QM 添加原作没有的武器排除。它们的深度权重和屏幕空间几何关系会因此改变。`$9` 的四邻居 joint bilateral upsample 应继续显式实现，包括 `w=max(w,1e-5)`；不是依靠 AO 纹理 linear filter 代替。原 AO A/B 的 sampler 本来就是 nearest。

AO shader 中的 `vUv`、`vpos` 和 noise 也需要保留原坐标域：纹理存 native top-origin，`sourceSample()` 将原 bottom-origin UV 转换一次；`ign(gl_FragCoord.xy)` 的 y 应使用原 half-height 减 native 像素中心 y。不能只翻纹理 UV，却让噪声旋转仍基于 top-origin fragcoord。

未来启用时，原顺序为原 HDR scene → AO/vol composite → motion（若启用）→ bloom/down 与测光 → tk。`$9` 的 lit 权重使用旧 adaptation，tk 使用本帧 adaptation。原 AO 开启时需避免与现有 Godot SSAO 重复相乘；本轮尚不启用，不能从 half-depth 数值通过推断 AO 外观已经完成。

## 0/1 weapon mask 的等效边界

单样本或所有样本完整同类覆盖的像素，weapon mask 选择 bypass 有明确依据：原武器写入 `depthRange(0,.05)`，正常有效武器片元的深度低于 `.05`；若被极近世界表面挡住，那个世界表面自己也低于阈值。

**这不能推广到 MSAA 边缘。** 原作先逐 sample 进行 world/weapon depth test，再 resolve 一份组合深度。部分样本覆盖武器、其余为世界或天空时，resolved d 可能大于 `.05`；当前 mask 将任何 native weapon coverage 压为 0，已丢失原深度值和每个 sample 的覆盖关系。其后无论怎样计算 half-depth，都无法从两张 resolved world/mask 图恢复这些信息。恰在武器 far plane 的 depth=0 与 native clear=0 也无法单凭该 mask 区分。

所以本轮对照可证明 q9 坐标、sentinel 和非武器线性化正确；应将 MSAA 关闭或将输入限定为已定义的合成像素，报告不宣称默认 MSAA4 的 AO 边缘全等。

## 后续原 resolve 探针与 per-sample 组合接口

先测原 Three 的实际路径。记录 renderer/ANGLE backend、samples、depth 格式、`EXT_multisampled_render_to_texture` 路径是否启用。用已知常量深度的 world 面和 weapon 面逐亚像素扫过同一像素，改变覆盖方向和深度顺序，读回 resolve 后的 depth，同时记录颜色 coverage。样本覆盖变化能区分平均、min/max 和某个固定 sample；不能仅从 `blitFramebuffer(...NEAREST)` 推断取 sample 0。原逻辑与 GL 规则已见 [solar-depth-adviser.md](solar-depth-adviser.md) 的 MSAA 边界。

Godot 侧所需接口和资源：

1. 两台相机各自在自己的 POST_TRANSPARENT 回调内取得 `RenderSceneBuffersRD.get_depth_layer(0,true)`。第二个参数 true 取得 MSAA variant；`get_depth_layer(0)` 是 resolved 图。可通过 `get_msaa_3d()`、RD texture format 的 samples 确认样本数；枚举值不是样本数本身，显式映射。接口见 [RenderSceneBuffersRD](https://docs.godotengine.org/en/stable/classes/class_renderscenebuffersrd.html)。
2. 输入 compute 用 `sampler2DMS`，读取 `texelFetch(source_depth,p,sample_index).r`。不能对 MSAA texture 使用普通 sampler2D。Godot 自己的 [resolve.glsl](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/effects/resolve.glsl#L8-L10) 使用同样接口；其 [38–45 行](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/effects/resolve.glsl#L38-L45) 当前对样本取算术平均，不自动等于原参考行为。
3. 在 world callback 将每个 sample 复制到自持 R32F `TEXTURE_TYPE_2D_ARRAY`，array_layers 为样本数，samples 为 1，storage|sampling usage。用 image2DArray 写每层，保留 native reverse depth。这样不必把引擎持有的 MSAA RID 跨 viewport/跨帧长期保存。资源尺寸或样本数改变时仍在帧前准备；不释放引擎 depth RID。
4. 在 weapon callback 后续 effect 中，读取该帧 world sample array 和当前 weapon 的真实 MSAA depth，逐 sample 合并并按参考实测的规则 resolve，直接写自持 R32F `combined_forward`。如果调试需要，也可先把 weapon samples 复制到另一张 array；生产可直接消费当前 callback 的 weapon MSAA 输入以减少一次全图复制。检查两个 producer 属于同一帧。
5. q9 half-depth 和 `$9` composite 改为消费 `combined_forward`，不再靠 weapon 0/1 mask 重建距离。组合深度仍是原 post 数据；是否给其他距离消费者复用，需按各消费者原公式单独确认。

逐 sample 的候选公式为：

```text
dw[s] = 1 - native_world_reverse[s]
dv[s] = 0.05 * (1 - native_weapon_reverse[s])
combined[s] = weapon_sample_covered ? min(dw[s],dv[s]) : dw[s]
resolved_forward = SOURCE_RESOLVE_RULE(combined[0..N-1])
```

这里 min 对应原默认 LessEqual 深度测试的最终深度值；**不能先对 dw、dv 各自 resolve，再 min，也不能把 dv 先二值化**。两个相机 near/far 应保持 world `.08/900`、weapon `.01/10`，维度、sample count 和采样位置需对应。原 D24 的写入量化发生在原深度写入/测试边界；原与 native 的格式量化、sample 编号/位置和 clear/far-plane 歧义均要用探针确认，不能只凭相同 MSAA4 标签声称相同。

若直接读取 native MSAA attachment 在该回调/驱动上未保留预期内容，应以逐 sample 探针确认实际 attachment 生命周期，并在有效阶段复制到自持 array；不要绕回 CPU 回读或额外场景重渲染。当前接口方案尚未实现或验证，不能把其预期行为写成既有测试结论。

## 本轮建议验收

- 原 q9 + 原 R32F target 作为 GPU 参考；记录扩展分支。覆盖 8×8、9×8、8×9、9×9 以及实际分辨率，源每行每列不同，并检查四角和最后一行列。
- 测 `.05` 两侧、恰等于 `.05`、近裁剪面、far、纯武器 mask 和世界极近表面，分别验证 `.01` 标记与线性 z。原阈值不放宽。
- 在隔离测试中检查 R32F 实际格式；不能通过 RGBA16F viewport 中转再宣称 R32F 对照。GPU readback 仅用于测试。
- 用非周期深度序列检查 world→weapon→half-depth→消费者同帧关系，以及 resize 当帧零 ERROR。不要等待数帧后才采样 resize 结果。
- 当前结果限于 half-depth。AO8 量化、双边模糊、joint upsample、真实材质、MSAA resolve 和原 AO 最终视觉验证分别记录，默认游戏保持本轮约定不启用。
