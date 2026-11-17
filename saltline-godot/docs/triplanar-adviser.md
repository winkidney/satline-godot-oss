# 原 triplanar 蒙皮材质迁移建议

日期：2026-11-15。目标为 Godot 4.7.2 `ed1daf0bf001b61586d9930840f2f1394092c079` Forward+。本轮只读审查源 bundle、当前导入器、真实资产和引擎源码，只写本文，没有修改运行代码或运行新的 GPU probe。

结论是可以保留 Godot 预蒙皮位置，用原 rest 属性与一个很小的 CPU→GPU 骨矩阵 palette 重建原 triplanar 的 X/Y 轴。普通 MeshInstance3D 的 spatial vertex shader 仍能读到 `BONE_INDICES/BONE_WEIGHTS`，无须重做位置蒙皮或为这件事再改引擎。当前两个共享材质服务 18 个独立骨架，推荐一张共享 palette atlas 加 per-instance offset，避免材质纹理被最后一个角色覆盖。

## 原作要求保留的量

源为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。`hk/dk` 位于 39343–39367，triplanar 颜色/ORM 的 mk 位于 39387 起，法线 vk 位于 39488–39510。基础 Three skinMatrix 在 23553–23564，骨矩阵纹理读取在 23528–23542。

原 SL_TRIPLANAR 不是在当前变形表面上做世界空间投射：

- `vSlPos=position`、`vSlONrm=normal` 直接保留原始顶点属性。位置和法线都不使用 skin 后结果。fragment 中先 normalize 插值后的 rest normal，再以 `pow(abs(normal),6)` 得到三向混合权重。
- 三向 UV 是 `restPosition*uSlUv.z` 的 `.zy/.xz/.xy`，normalMap 的三个样本也使用同一组坐标与权重。SL_FX 的 macro、beads 等 vSlPos 使用者在该分支同样采用 rest 坐标；不能修颜色取样后继续让噪声使用 world_pos。
- 局部 X/Y 单位轴先经线性加权 `skinMatrix`，再经 instanceMatrix（若有）、modelViewMatrix，**每顶点归一化后插值**。fragment 再分别 normalize 两个插值轴，然后令 `C=cross(A,B)`，最后 normalize 三轴组合后的法线。
- C 没有单独 normalize，A/B 没有 Gram–Schmidt 正交化。骨骼混合、非均匀缩放下这些操作不等效，不能为“正交”而改写。也不能把用于法线的 inverse-transpose 矩阵用于这两个轴；原公式明确使用线性 `mat3(modelViewMatrix)`。
- 原 vk 的三向 normalScale 没有非 triplanar 分支的 wet attenuation；gk 的 normal-map 长度 roughness 修正也明确排除了 SL_TRIPLANAR。原双面分支在最后乘 faceDirection，应对应 Godot 当前 pass 的 FRONT_FACING，避免重复翻转已经由引擎翻过的普通 NORMAL。

当前 [source_material.gdshader](../shaders/source_material.gdshader) 和 [source_material_alpha.gdshader](../shaders/source_material_alpha.gdshader) 在 vertex 中把 local_pos/local_n 设为 VERTEX/NORMAL，并跳过 triplanar normalMap。这对 skinned mesh 分别取到了预蒙皮后的值和缺少扰动的值，不能等同原 dk/vk。修复应覆盖不透明与 alpha 两份 generic shader，并保持源材质的其他 patch 边界可见。

## 预蒙皮后骨骼输入仍然存在

此版本 spatial vertex builtin 的公开类型是 `BONE_INDICES: uvec4` 与 `BONE_WEIGHTS: vec4`，均只读。[定义](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/shader_types.cpp#L105-L106)。编译器按使用情况生成 BONES_USED / WEIGHTS_USED，Forward+ 输入 location 为 10/11。条件是“使用该 builtin 或 particle trails”，并不是只为 particle 提供。[编译器映射](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L824-L825)、[顶点声明](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L63-L68)。

绘制时 VERTEX/NORMAL 从 mesh instance 的预蒙皮 `mis->vertex_buffer` 读取，但 bones/weights 仍绑定原 surface 的 `s->skin_buffer`。compute 将后者声明为 readonly，只把变形后的 position、normal、tangent 写入输出；因此 vertex shader 看到的是“变形几何 + 原索引/权重”的组合。[绑定路径](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp#L1475-L1495)、[只读 skin 输入](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/skeleton.glsl#L24-L27)、[预蒙皮及输出](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/skeleton.glsl#L248-L310)。

普通 vertex 的 MODELVIEW_MATRIX 包含模型/实例与当前相机变换，不包含上述每顶点加权 skinMatrix。读取它不能自动恢复原轴；相反，给 VERTEX 再乘自己的 palette 会二次蒙皮。正确分工是 native 保留位置及普通几何法线，自有 palette 只生成原 dk 的轴。

## 当前资产使范围可以限定得很清楚

本轮直接读取 [scene.json](../assets/prepared/scene.json) 及 skinIndex/skinWeight 二进制，得到：

| 项目 | 当前实际值 |
| --- | --- |
| 带 SL_TRIPLANAR 的 skinned 对象 | 18 |
| 骨架组成 | 10×13 bones，8×20 bones，共 290 slots |
| 唯一 geometry / 唯一 bone 列表 | 2 / 18 |
| 唯一 triplanar 材质 | armor_white、gunmetal，共 2 个共享材质 |
| 源属性 | position、normal、uv、color、skinIndex、skinWeight |
| 按对象累计顶点数 | 817,536，含共享几何重复实例 |
| 权重与索引 | 权重仅 0/1；每顶点和为 1；最大索引 19 |
| mesh local matrix、源 bindMatrix | 18 个均为 identity |
| 源 bindMode | attached；bindMatrixInverse 是当前世界逆矩阵 |

这是当前资产检查，不是新 GPU 实测。Godot 四权重实存为 RGBA16_UINT 索引、RGBA16_UNORM 权重，offset 0/8，stride16。对本批 0/1 权重完全无损；未来一般 float32 混合权重则会量化。不要额外重归一化 builtin 权重。若将来需要原 float32 权重精确重建轴，可以额外保留源权重属性，但当前没有这个必要。[顶点格式](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp#L1390-L1400)。

必须断言本路径采用四权重。compute 支持八权重，但此版本 spatial builtin 的顶点格式仍按上述四分量 offset/stride 设置，不能假定八权重网格会正确给出“前四项”。超出当前资产范围时需要独立属性/纹理方案或单独修正引擎。[八权重 compute](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/skeleton.glsl#L267-L285)、[固定 skin stride](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp#L1436-L1452)。

## 推荐数据布局与 palette

对上述两份 geometry，把原 position.xyz 写入 CUSTOM1，原 normal.xyz 写入 CUSTOM2，格式明确为 RGB_FLOAT 或 RGBA_FLOAT。无需每帧重写它们。若选择 RGBA_FLOAT，w 固定为 0/1 并明确用途；不要把三个分量的数组声明成 RGBA_FLOAT。当前 importer 已用 CUSTOM3 保留 HDR vertex color，必须保留它；CUSTOM0 也不应和其他类型的 aSurf/aType/aRest 布局混用。只在确认这两份目标 geometry 不存在已有 CUSTOM1/2 用途后增加布局，缓存 key 或布局检查应避免复用不兼容 mesh。

palette 按 **Skin bind slot** 编址，不直接按 Skeleton3D bone index 编址。每个 slot i 先按 bind_name 优先、否则 bind_bone 找到骨骼 b，再写：

```text
palette[i] = skeleton.get_bone_global_pose(b) * skin.get_bind_pose(i)
```

这正是引擎上传矩阵的公式；`get_bone_global_pose` 的 global 是 Skeleton3D 坐标系内的全局骨姿态，不是场景世界变换。[slot 映射及上传](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/skeleton_3d.cpp#L367-L405)。当前 [source_scene.gd](../scripts/source_scene.gd) 按 i→i 创建 Skin，因此当前映射简单，但建议数据结构保留 slot→bone 显式映射。

源完整公式为 `bindMatrixInverse * sum(weight * boneWorld * boneInverse) * bindMatrix`。当前 mesh.local 与 bindMatrix 是 identity，Skeleton 与 mesh 同属角色 group 且 Skeleton 局部 identity，源 attached bindMatrixInverse 会抵消角色世界变换，所以 `globalPose * bindPose` 正好落在本批所需的 mesh-local skin 空间。不要直接上传导出时的旧 world bone matrix 或旧 bindMatrixInverse，角色移动后就会错误；也不要再乘角色世界变换，因为稍后 MODELVIEW_MATRIX 已包含它。未来非 identity mesh/Skeleton 关系、detached bindMode 或非 identity bindMatrix 必须重新验证这个等式，不能无条件套用。

共享 atlas 可以是 **4×290 的 RGBA32F ImageTexture**，每行一个 slot，四 texel 存 column-major 的完整 Transform3D：basis.x/w0、basis.y/w0、basis.z/w0、origin/w1。总量 18,560 bytes，约 18.1 KiB；按 60 Hz 每帧上传一次约 1.1 MB/s。CPU 写现有骨姿态并上传不涉及 GPU 回读。数据纹理不加 source_color、不生成 mip，使用 nearest/repeat_disable 与 texelFetch；它不是导出的 PNG，不需要沿用材质图片的 y 翻转。

两个共享材质绑定同一 atlas，各 GeometryInstance3D 用 `instance uniform int sl_palette_base` 与 `instance uniform bool sl_skin_axes` 指定范围/是否启用。实例 uniform 不支持 texture；若选每 mesh 独立小纹理，则必须独立其各 surface 的 ShaderMaterial，并继续把 wet/sun 等运行时参数同步到这些副本。共享 atlas 可以保持现有材质共享，避免这一额外生命周期。[官方 per-instance 限制](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#per-instance-uniforms)。

同一实例有多个材质时，参数的名称、类型、instance_index 必须一致。当前 source_sun_active/source_sun_receive_shadow 已是 instance uniform；新增参数要统一规划位置，不与它们冲突。Basic/emissive surface 不因同属骨架而新增太阳或 triplanar 计算。

## vertex/fragment 的重建顺序

每个 vertex 读取原四组索引/权重。对轴只需要 palette 前两列，以下是数学示意：

```text
skinX = sum_j(BONE_WEIGHTS[j] * palette[BONE_INDICES[j]].basis.x)
skinY = sum_j(BONE_WEIGHTS[j] * palette[BONE_INDICES[j]].basis.y)
vSlAx = normalize(mat3(MODELVIEW_MATRIX) * skinX)
vSlAy = normalize(mat3(MODELVIEW_MATRIX) * skinY)
vSlPos = CUSTOM1.xyz
vSlONrm = CUSTOM2.xyz
```

不要写 VERTEX、POSITION，也不要在这一步改 NORMAL。对非 skinned triplanar 对象用 X/Y 单位轴，rest 属性可直接取其未蒙皮 VERTEX/NORMAL；针对这 18 个对象的开关必须明确，否则默认零权重会生成不可归一化的零轴。当前 MeshInstance3D 不是 MultiMesh；将来复用到 MultiMesh 时 Godot 已将实例变换合入 MODELVIEW，不能再像原 Three 那样额外乘一次 instanceMatrix。

fragment 按原 vk 完整计算三个 texture normal 的重定向与混合，最后使用插值轴构建 view-space NORMAL。原顺序是 normalize(vSlONrm)→pow6 权重、三次 normalMap 采样与 normalScale、三种轴 swizzle、normalize(slNo)、分别 normalize(vSlAx/vSlAy)、cross、最终 normalize。保持每顶点与 fragment 两次归一化的位置；把所有归一化挪到最后会改变插值结果。

普通世界法线/非扰动 view normal 仍用于源 wet-facing、几何 roughness 和太阳 normalBias。rest normal 只用于原 triplanar 权重与 vk 重定向，不可误用成当前世界法线。原 vk 生成的最终 NORMAL 才进入直接 BRDF 和 IBL。当前 generic SL_FX 仍有简化公式；本次轴/rest 修复通过不代表其全部 wet/macro/bead 算法已与原 mk/gk 等同。

## 更新时序与生命周期

`skeleton_updated` 在 modifiers 完成后、引擎向 RenderingServer 上传 Skin palette 前发出，可在这个信号内读取最终骨姿态填充自有 palette。带 modifiers 的 Skeleton 随后可能恢复原始 pose，不能等到很晚再读取并假定仍是渲染姿态。[精确顺序](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/skeleton_3d.cpp#L330-L414)。当前由 source pose 脚本驱动，也可在统一 pose 更新结束后强制完成骨姿态，再一次生成 atlas；不要在每一次 set_source_transform 的中间状态上传。

共享 atlas 的信号回调可先更新 CPU staging 中的对应行，再在确定所有本帧骨架更新完成且 render flush 之前上传一次。若无法证明这个汇合点，先在每次 skeleton_updated 后更新同一个持久 ImageTexture，验证同步正确，再优化上传次数；290 行很小，不能以时序错误换取少一次更新。新增的骨架、重建或换 Skin 必须分配/初始化 palette，静止且没有 signal 的首帧也要有有效数据。

使用同一 ImageTexture 的 update 保持资源绑定稳定；不要每帧更换 Texture2DRD RID 或在 compositor callback 中替换材质纹理。相机变化只影响 MODELVIEW，主视图与反射都消费同一份当帧局部骨矩阵，不需要为每个相机重算 CPU palette。销毁时断开信号、清除实例参数/绑定，atlas 重建只在受控边界发生。时序仍必须用非周期 GPU 帧探针确认。

## 最小 GPU 验证

1. **证明输入混合状态。**建立实际 Skin/Skeleton3D 的小三角形网格，原始顶点附带已知 CUSTOM1/2。让一个骨骼产生明显平移与旋转，用 shader 输出 VERTEX、CUSTOM1/2、BONE_INDICES/WEIGHTS 到分开的 HDR 图。预期 VERTEX 变化，rest 属性与索引权重不变。保留无自有 palette 的同姿态几何图，验证启用重建后 position/depth 完全不变，排除二次蒙皮。
2. **验证 slot 映射和矩阵方向。**使用至少三个骨骼，故意让 Skin slot 顺序不同于骨骼顺序，加入父骨骼与非 identity bind pose；让角色 group 平移、旋转和缩放。先测当前资产同样的 one-hot 权重，再测混合权重。分别输出 skinX/skinY、vSlAx/vSlAy、最终 NORMAL，CPU 与原 Three GPU 都有明确参考。混合权重测试要分开记录 Godot UNORM16 存储量化，不能把它归因为矩阵错误。
3. **验证 vk，而非只看一张最终图。**用非对称三向 normal 纹理覆盖正/负轴面、斜面、背面，输出 rest UV、pow6 权重、slNo 和最终 view normal；覆盖 normalScale 非1、非均匀缩放、两个不同旋转骨骼。必须出现能区分“normal inverse-transpose”“轴正交化”和原线性轴算法的 case。
4. **验证共享与同帧。**两个实例共享同一几何和材质、使用不同 palette offset，在 12 个以上非周期 pose 下同时出图，验证没有最后写入者覆盖或一帧延迟。主视图与反射使用不同 view matrix，分别比较同帧 view axes。随后测试真实 18 个对象及其共享 atlas、原 2 份几何，不在这个阶段替换 native 位置蒙皮。

原 Three 参考应执行实际 dk/vk 与原骨矩阵上传公式，不能只把新的 native 算法翻译成 CPU 参考。优先保存中间数值、GPU 后端、target 格式和逐通道误差。Godot HDR viewport 的 RGBA16F 输出本身会量化方向值；验收容差应区分该量化与矩阵/时序错误，不以最后 tonemapped 画面看起来相似代替证明。源码已经支持本方案，完整 GPU 通过仍是下一步工作。
