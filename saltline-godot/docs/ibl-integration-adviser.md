# Generic Standard 环境光接入审查

本次只读审查，未修改生产代码。建议保留现有直接光路径，将完整原 Three 间接光结果加到 `EMISSION`，同时以 `IRRADIANCE=vec4(0,0,0,1)` 和 `RADIANCE=vec4(0,0,0,1)` 覆盖原生天空间接项。这个方案在当前无 lightmap/GI/ReflectionProbe/SSIL/SSR/clearcoat 的边界内成立；两个输出不是“关闭所有原生间接光”的全局开关。

## Godot 实际覆盖位置

审查基于 Godot `ed1daf0bf001b61586d9930840f2f1394092c079` Forward+。`RADIANCE` 在初始天空采样后混合进 `indirect_specular_light`，`IRRADIANCE` 混合进 `ambient_light`。RGB 为零、alpha 为一会清除这两个早期结果。[覆盖代码](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1735-L1762)

后续仍有能重新引入间接光的分支：

| 后续路径 | 对本方案的要求 |
|---|---|
| Lightmap、SH capture、SDFGI、VoxelGI、GI buffer | 当前不使用；新增这些功能时必须重新审查，不能只保留双零输出就认为已隔离。 |
| ReflectionProbe | 当前场景中不应有原生 probe 参与 generic 材质。 |
| SSIL、SSR | 保持关闭；透明 pass 虽不启用这两个屏幕效果，仍不能据此排除其他 GI。 |
| Clearcoat | 当前两份 generic shader 未使用；后续不能直接套同一结论。 |

源码位置：[GI](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1800-L2025)、[probe](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L2100-L2135)、[SSIL/SSR](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L2187-L2227)、[透明 pass 标志](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L753-L774)。

不要以 `ambient_light_disabled` 替代双零。这个 render mode 同时跳过 native DFG `energy_compensation` 计算，使补偿保持默认 1；native direct GGX 也使用它，因此会改变希望保留的直接光数值。[补偿计算](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L2246-L2260)、[直接光使用](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl#L291-L292)

完整 Three IBL 进入 `EMISSION` 后，不会再次经过 native albedo、metallic、roughness/DFG、材质 AO 或 specular occlusion。它仍会经过 emissive exposure normalization、fog、透明混合和后处理。没有 CameraAttributes 时 exposure normalization 默认为 1；应把当前 world/weapon viewport 的实际 CameraAttributes 与线性曝光设置一并记录。[曝光值](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/render_scene_data_rd.cpp#L240-L258)、[最终合成](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L3047-L3099)

IBL 必须加到现有 `emission_color` 和 `sourceSunRadiance` 之后或同一总和中，不能覆盖它们。透明材质输出保持未预乘的辐射，继续交给既有 alpha/weapon composite 链处理，不能提前再乘一次 alpha。

## 原 Three 环境选择

[environment-bindings.json](../assets/export/fixtures/environment-bindings.json) 记录了原 NVIDIA 后端、195 个材质 ordinal identity 零失败。全局环境强度为 2，所有相关环境旋转为零，没有 ambient、hemisphere 或 light probe。

138 个 MeshStandardMaterial 中，22 个显式绑定室内 envMap、强度均为 1；113 个 envMap=null、材质强度 1；另 3 个玻璃材质 envMap=null、材质强度 1.4。原 Three 在 `envMap===null` 时使用 `scene.environmentIntensity`，忽略该材质的 `envMapIntensity`。因此三个 1.4 不能再乘进结果。[原 renderer](../../artifact-rendering-study/source/extracted/bundle-1.js#L34084)

有效选择表如下：

| 材质/绘制对象 | PMREM | 有效强度 |
|---|---|---:|
| world，envMap=null | 天空 | 2 |
| viewmodel，envMap=null，主相机在室外 | 天空 | `2 * viewFill` |
| viewmodel，envMap=null，主相机在室内 | 室内 | `1 * viewFill` |
| 显式室内 envMap | 室内 | 材质强度，当前均为 1，不乘 viewFill |

world implicit 不会因主相机进入室内自动切换 room。原 render loop 只在第二次 viewmodel draw 临时替换 `scene.environment` 与 `environmentIntensity`，随后恢复。[原 viewmodel draw](../../artifact-rendering-study/source/extracted/bundle-1.js#L36955)

室内判定使用第一个 `interiorBoxes`，严格要求 `min.x < camera.x < max.x`、`min.z < camera.z < max.z` 和 `camera.y < max.y`，没有 `camera.y > min.y` 条件。标准 AABB `has_point` 与此不同。使用实际主相机位置，不使用 weapon proxy 或 planar mirror 相机的位置。

当前导出的 254 个 Standard 节点只使用 layers=1 或 layers=2，分别 233/21 个，没有同时属于两层的节点。故实例 slot 10 按 `node.layers & 2` 设置 viewmodel 标志，对当前资产成立。现有实例 slot 8/9 用于 skin triplanar，sun 标志占前面的自动槽，slot 10 不冲突。今后若节点同时参与 world/viewmodel 两个 pass，实例标志不再足以表达环境选择，需要按当前 pass 区分。

有三个 Standard 材质走专门分支：`saltline_arm`、`apron_wet`、`sea`。此次只接两份 generic Standard shader，实际覆盖 135 个材质；不能把 138 个 Standard 都计为已接入。arms 的 view-fill 特殊处理，以及 ground/sea 的反射总和限幅继续保留各自验收边界。

## viewFill 的原始更新

原始初值为 `1.1`，更新位于 [bundle-1.js 86035–86059](../../artifact-rendering-study/source/extracted/bundle-1.js#L86035)，每个渲染帧在相机/武器更新之后、render.frame 之前执行：

```text
E = max(0, cameraForward.x * sunDir.x + cameraForward.z * sunDir.z)
target = inside ? 1.1 : 1.1 + 0.6 * E * E
viewFill += (target - viewFill) * min(1, dt * 2.5)
```

不要把 XZ 向量重新归一化，俯仰会影响这两个水平分量。源代码有 truthy `wfill` 参数时跳过自动更新；draw 时还使用 `Q.viewFill || 1.1`，零值会回退到 1.1。冻结的三帧参考值 `1.160389343639477` 是更新结果，不是通用默认常量。

环境位置判定采用主相机；IBL 方向变换则应使用当前绘制 pass 的 `INV_VIEW_MATRIX`。反射相机应得到反射视角下的 normal/view 方向，不能把主相机矩阵硬塞进所有 pass。

## roughness、方向与 AO 顺序

先完成原 map/tint、湿度、顶点/实例颜色和 alpha-cut 对最终漫反射颜色的影响，再建立与原 Standard 相同的 `PhysicalMaterial`。generic 的原湿度块不把 F0 改成 .075；这项是 ground 特有补丁。generic 应使用 `mix(vec3(.04), finalColor, metalness)` 和 `specularF90=1`。

roughness 顺序为原 scalar×ORM.g，湿度/宏观/bead 调整，非 triplanar normal-map 长度修正，以及 `gk` 的 [.045,1] 限制。之后用尚未经过 normal-map 扰动的原几何 normal 计算：

```text
dxy = max(abs(dFdx(nonPerturbedNormal)), abs(dFdy(nonPerturbedNormal)))
geometryRoughness = max(dxy.x, dxy.y, dxy.z)
r = min(max(roughnessFactor, .0525) + geometryRoughness, 1)
```

这个最终 `r` 必须同时用于 radiance 方向偏转、cubeUV roughness 层选择、DFG/multiscattering 和 specular AO。不能直接拿 Godot `ROUGHNESS` 的 [.045,1] 值代替，也不能从已扰动 normal 再算一次几何粗糙度。[原 material 建立](../../artifact-rendering-study/source/extracted/bundle-1.js#L22349)

原 radiance 方向是 `normalize(mix(reflect(-V,N),N,r*r))`，随后转换到世界方向并应用 env rotation；irradiance 用最终扰动后的 N 对环境取 roughness=1 的样本，再乘 `PI*envIntensity`。当前 rotation 为零，但 normal/view 必须处在同一个当前视图空间。[原方向函数](../../artifact-rendering-study/source/extracted/bundle-1.js#L22277)

必须区分 `irradiance` 与 `iblIrradiance`。前者来自 ambient/hemi/lightProbe/lightMap，当前为零；后者来自 PMREM。原 Standard 将 PMREM 只传给 `RE_IndirectSpecular_Physical`，该函数内部已经加入能量补偿后的环境漫反射和间接镜面。再把同一 PMREM irradiance 传给 `RE_IndirectDiffuse_Physical` 会重复环境漫反射。[原积累顺序](../../artifact-rendering-study/source/extracted/bundle-1.js#L22835)

原 AO 在两个间接项计算完成后执行：indirectDiffuse 乘材质 AO，indirectSpecular 乘 `computeSpecularOcclusion(dotNV,ao,r)`。不能依赖 Godot `AO` 自动处理新增 EMISSION，也不能把源 AO 乘到直接光或原 emissive 上。

材质 `has_ao_map` 必须独立于 `has_orm`。当前 138 个 Standard 中有 78 个 ao/roughness/metalness 图同时存在且同源，59 个都没有；唯一例外 `fx_decals` 有 roughness/metalnessMap，却没有 aoMap。它的 IBL AO 应为 1，而非 ORM.r。当前 fixture 中原 AO intensity 为 1 的验证，不代表任何无 aoMap 的材质也应启用 AO。

原屏幕空间 AO post 与材质 ORM AO 是两层原有效果，应保留各自顺序。Godot SSAO 在 game world/weapon 环境中继续关闭，防止额外施加一层不同算法。

## 最小接入验收

现有 cubeUV 224 组和 indirect BRDF 96 组通过，只证明独立核心。接入后建议做以下配对验证，参考仍用原 NVIDIA 后端：

1. 环境清零探针：关闭所有直接光、原 emissive 和 custom IBL，保留明显发亮的 native sky/ambient。双零输出后，非金属/金属、不同 roughness、opaque/alpha=1 两份 shader 都应为黑；关闭覆盖时应恢复可见间接光，证明探针能观察到该路径。
2. 直接光保留探针：custom IBL 关闭，双零仍开启；切换 native sky/ambient 不应改变 sourceSun/native local direct。不要用 `ambient_light_disabled` 生成对照，因为它自身会改变 direct energy compensation。
3. 原 IBL-only 材质：关闭直接光，实际 PMREM+final normal+geometry roughness+AO 联合对照。覆盖 AO=0/.5/1、没有 aoMap 的 fx_decals、normal map、金属端点和斜视角，检查没有重复 PI 或重复 diffuse。
4. 选择与时序：验证表中四种环境选择、三个 null-env 的 1.4 玻璃值被忽略、室内严格边界和相机低于 min.y 情况；逐帧核对 viewFill 初值、朝向/俯仰、进入室内和可变 dt。
5. 实际 viewport：确认 world、weapon 和反射 pass 的方向、HDR>1、透明 premultiply 和现有 EMISSION 分量。记录无 lightmap/GI/probes、SSIL/SSR/clearcoat、CameraAttributes 及 Godot SSAO 状态，界定双零方案成立的条件。

完成这些后可声明 generic Standard IBL 接入通过；专门的 arms、ground、sea，以及原生 local-light BRDF 与原 Three 的差异仍需各自验收，不能由此次 IBL 核心测试代替。
