# 原局部直接光接入审查

本次只读核对原 bundle、导出场景和当前 native 路径；仅新增本文，未修改生产代码或运行新的 GPU 探针。建议先补齐四盏仓库灯和独立衰减验证，再把十盏 PointLight 与一盏 view-key DirectionalLight 接入共享源光照数据。最终使用原 `RE_Direct_Physical`，与已有太阳共同累积直接光。临时 native 灯的存在只能证明灯源恢复，不能证明原辐射、BRDF 或多灯总和已经一致。

## 实际灯源与固定顺序

[原场景导出](../assets/export/scenes/main.json) 与创建代码一致。本次“11 盏局部灯”包括十个 point 槽和一个 key，不包含已迁移的太阳；没有实际 SpotLight，也没有局部灯阴影。

| 顺序 | 灯源 | 原线性颜色 | 强度与距离 | 原 layers 位掩码 |
|---|---|---|---|---:|
| 0–5 | 固定六槽 light pool | flash 数字颜色经 sRGB 解码；persistent Gull 为 `(1,.9,.75)` | 初始强度 0、range 12、decay 2；使用时动态更新 | 3 |
| 6–9 | 四盏仓库 PointLight | `(1,.55201140150344,.2541520943200296)` | intensity 34、range 13、decay 2 | 3 |
| 独立 directional | viewmodel-key | `(.78,.86,1)` | 默认 `.9`，室内乘 `.55` | 2 |

四盏仓库灯依次位于 `(-8.5,5.75,-15.4)`、`(2.6,5.75,-15.4)`、`(-3.5,5.75,-23.6)`、`(8.6,5.75,-23.6)`，均无 shadow。父节点虽名为 `level-dynamic`，它们没有闪烁或 gameplay 门控；该 level 的 `update` 只转动风扇，`shedLights` 没有后续写入。[创建](../../artifact-rendering-study/source/extracted/bundle-1.js#L50761)、[level update](../../artifact-rendering-study/source/extracted/bundle-1.js#L50930)、[导出](../../artifact-rendering-study/source/extracted/bundle-1.js#L52212)

池中的 persistent Gull 灯仍占六槽之一，不能另算第七盏；同样不能把旧快照中的六个 PointLight 再实例化一遍，同时保留运行时六槽池。原槽数组不因 flash/release 重排：优先首个空槽，满时替换非 persistent 中 TTL 最小槽，全部 persistent 时不产生新灯。普通 flash 更新为 `peak*ttl/duration`，persistent 不走 TTL。[六槽创建及生命周期](../../artifact-rendering-study/source/extracted/bundle-1.js#L36725)

Three 收集灯只检查场景祖先 visible 和当前 camera.layers，不按被照物体的 layer、距离、光强或 point frustum 选择“最近灯”。灯排序权重仅为 `shadow*2 + map*1`，相同优先级维持场景顺序。当前 point 的顺序是六个 pool 槽，然后四个仓库灯；shader 先累积 point、再 spot、再 directional。当前 directional 中有 shadow 的太阳排在 key 前。因此完整源顺序是 **pool[0..5] → warehouse[0..3] → sun → view-key**。[排序](../../artifact-rendering-study/source/extracted/bundle-1.js#L29211)、[收集](../../artifact-rendering-study/source/extracted/bundle-1.js#L33694)、[point 累积](../../artifact-rendering-study/source/extracted/bundle-1.js#L22765)、[directional 累积](../../artifact-rendering-study/source/extracted/bundle-1.js#L22816)

原太阳和十盏点灯的 mask 都是 3，照 world 和 weapon；key 为 2，只参与 weapon pass。原 lights 的 layer 是相机收集语义，不是 Godot 的逐物体 light_cull_mask 语义。当前 world/weapon 物体明确分组时可以映射；以后若同一物体同时被两类相机渲染，必须按 pass 过滤 key，不能仅凭对象含有 weapon bit 就永远加 key。

## 强度、颜色与衰减

原 shader 接收 `linearColor * intensity`，没有额外 π。`PointLight.power = intensity * 4π` 是 API 上的另一种单位，不能把 power 当作 intensity 上传。[point uniforms](../../artifact-rendering-study/source/extracted/bundle-1.js#L29345)、[power 属性](../../artifact-rendering-study/source/extracted/bundle-1.js#L16544)

原距离衰减为：

```glsl
float distanceFalloff = 1.0 / max(pow(lightDistance, decayExponent), 0.01);
if (cutoffDistance > 0.0) {
    distanceFalloff *= pow2(saturate(1.0 - pow4(lightDistance / cutoffDistance)));
}
```

保持 `range<=0` 的无截止分支、指数和乘法顺序；本项目实际 decay 为 2，但 kernel 验证可覆盖其他指数。不要替换为只调 range/energy 的 native 衰减。[原公式与 point 入射向量](../../artifact-rendering-study/source/extracted/bundle-1.js#L22187)

Godot 默认非 physical units 会在上传 point/spot 的 `light_energy` 时乘 π，directional 也如此。当前项目未启用 physical light units；原始 atlas 应继续存源 intensity。若给临时 native fallback 做能量对应，需要在 fallback 输出端除 π，并保留 exposure normalization 为 1；该换算仍不能消除 BRDF 和衰减差异。[point 单位转换](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L1030-L1059)、[directional 转换](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L754-L771)

Godot Omni 的截止形状接近原式，但核心为 `pow(max(distance,.0001),-decay)`，原式为 `1/max(pow(distance,decay),.01)`；decay=2 时在距离小于 .1 的范围已有实质差异，且 native 函数返回 half。因此 `/π` 只是单位校正，不是“原灯复刻通过”。[Godot Omni 衰减](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl#L457-L463)

颜色需要区分两类输入：原数字 hex 通过 `setHex` 从 sRGB 转为 working linear；`new Color(r,g,b)` 和 `setRGB(r,g,b)` 默认直接输入 working linear。仓库导出 RGB、key 的 `.78/.86/1`、Gull 的 `1/.9/.75` 都可以直接进入线性 atlas；flash hex 只解码一次。native Light3D 接口的颜色会被引擎再次转线性，给它设置已知线性值时应先 `linear_to_srgb()`。不要把 native `light_color` 的界面值直接当作 atlas 线性值。[Three 颜色路径](../../artifact-rendering-study/source/extracted/bundle-1.js#L6082)、[Gull setRGB](../../artifact-rendering-study/source/extracted/bundle-1.js#L83231)

当前 [light_pool.gd](../scripts/light_pool.gd) 和 [gull_scan_light.gd](../scripts/gull_scan_light.gd) 直接读写 native `light_energy`。一旦引入 `/π` fallback 转换，应单独保存源 `intensity/colorLinear/range/decay/position`；Gull 的初始化、指数平滑和 pool TTL 都继续使用源状态，再派生 native 属性。否则能量换算会污染游戏状态，后续 atlas 又可能再次换算。

## View-key 与帧时序

key 和 target 均挂在主相机下，局部位置分别为 `(-.55,.75,.6)`、`(.1,-.1,-.4)`。传给原 BRDF 的入射方向为 lightPosition−targetPosition，因此局部方向是 `normalize(-.65,.85,1)`。atlas 可存主相机 basis 变换后的 world direction，再由当前 pass 的 VIEW_MATRIX 旋转。不能把 native 光发射的 −Z 直接当作 BRDF 朝向光源的方向。[key 创建](../../artifact-rendering-study/source/extracted/bundle-1.js#L36919)、[directional view 转换](../../artifact-rendering-study/source/extracted/bundle-1.js#L29434)

原 key 强度为 `(viewKey ?? .9) * (inside ? .55 : 1)`，默认室内为 `.495`。inside 要求 interiorEnv 存在、首个 interiorBox 有 min/max、主相机 x/z 严格位于范围内、y 小于 max.y；没有 y>min.y 条件。它独立于 IBL 的 viewFill，不随 viewFill 淡入，也不应对显式 room IBL 的选择产生副作用。[室内判定及更新](../../artifact-rendering-study/source/extracted/bundle-1.js#L36926-L36957)

原游戏更新 weapon/enemies/explosives/FX 后进入 `render.frame`，其中先执行 `pool.update(dt)`，再 planar prepass，最后 world/weapon 绘制。因此新 flash 在首次呈现时已经衰减一个 dt；暂停时 render.frame 仍执行，普通 TTL 仍会减少。[游戏更新](../../artifact-rendering-study/source/extracted/bundle-1.js#L86028)、[frame 内顺序](../../artifact-rendering-study/source/extracted/bundle-1.js#L37137)

共享 atlas 应在本帧所有生产者和唯一一次 pool.update 之后、渲染前上传。不要为了三个 viewport 各更新一次池，也不要在 `_physics_process` 和 `_process` 重复衰减。key 在原 world 绘制后更新，但 world/planar 不收集 key，因此为 weapon 提前准备本帧 key 值是等价的。当前 native 的 paused/physics 调度与原 render.frame 调度仍需单独验收，不能仅凭位置和静态强度相同忽略时序。

## 最小接入方案

1. 恢复四盏静态仓库灯的源记录与 native 过渡节点；按创建来源去重六槽池。记录总数十个 point、一个 key、另一个已迁移 sun，并验证颜色与源强度，不从画面反推参数。
2. 固定尺寸 RGBA32F atlas 保存十个 point 和 key 的源状态，例如每灯三至四个 texel：world position/range、linear RGB/intensity、decay/type/source mask/active；key 使用 direction 而非位置。使用 `texelFetch`、无 sRGB、无 mip、无过滤。十余灯每帧上传仅数百字节，无 GPU readback，也不需要依赖 Godot cluster 内部数据。固定 pool 槽顺序，禁用槽保留行并设强度 0，避免重排造成浮点求和变化。
3. 复用已验证的 `PhysicalMaterial/RE_Direct_Physical`。每个点灯使用实际 view-space 片元位置：`lightViewPos - VERTEX`，长度决定衰减，归一化向量决定 NL/GGX。模型蒙皮、海面顶点位移后的实际位置必须参与；rest/local 过程坐标和 sea 的位移前 vGWorld 只服务原材质，不可代替几何位置。
4. 材质建立一次原 material：最终颜色/metalness、`.0525 + geometryRoughness` 规则、最终 normal 与 view、地面湿 F0。直接漫反射继续原 Lambert，直接镜面继续原 GGX；不是 Godot 默认 Burley。generic/arms 使用自己的原参数，sea F0=.04，ground 湿 F0 混到 .075。材质 AO/gOcc、IBL、planar override 不乘进直接光。
5. 让 point→sun→key 写入同一个 `ReflectedLight` accumulator。仅在最终输出处组合直接项。已有 source sun 的单独 EMISSION 加法必须纳入这一条路径，不能既保留旧太阳，又在总和中再加一次。无 shadow 的局部灯 visibility=1；receiveShadow 仍只影响实际太阳的 PCSS。
6. 用独立高位 mask 隔离 native fallback：点灯仅照 worldFallback|weaponFallback，key 仅照 weaponFallback。已迁移对象去掉这些 fallback 位，保留原 world/weapon/planar 位和已有 sun 专用位。高位只用于 native 筛选，绝不能上传为 Three source layers。具体位应与现有层占用审计后确定。

迁移开关必须以 GeometryInstance3D 为单位：所有 lit surface 都支持并且 atlas 已就绪后才移除 native fallback 位；未知 shader 或部分 surface 未迁移时保持整个对象 fallback，同时关闭该对象的 source local 项。MeshBasic/unshaded 可作为已知不受灯影响的 surface，但不应新增 source direct。不能只关 native Light 节点，也不能只靠 `SPECULAR=0/ALBEDO=0` 压掉 native 灯，那会损坏其他材质与 fallback。

atlas ready 和用户诊断 enabled 分开：ready 且 enabled=false 应同时保持 native 关闭，以获得真正的 local-off；not-ready 才走 native fallback。纹理先填充并绑定，之后再启用 source/清除 fallback 位。延迟创建的 weapon/敌人复制体和每个 surface 材质都要进入同一注册路径。已支持对象上的 native point/key 能量改为极大值时，source 结果应保持不变，以证明没有残留双照明。

## Ground、sea 的唯一总高光限制

原地面在 `lights_fragment_end` 后做 `min(reflectedLight.directSpecular,40)`；这里包含全部 point 和 directional，且不限制 directDiffuse 或任何 IBL 项。[ground patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L56130)

原海面同样先对全部 directSpecular 总和 clamp40，再乘 `gSpark*mix(.3,1,az³)`。虽然注释称 sun glitter，实际操作的是包括局部灯的完整 directSpecular，因此局部镜面也乘该 glitter；这不能从名字推断成只处理太阳。sea 的 gOcc 仅作用于 IBL，不应混入该总和。[sea patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L56455)

最终表达式应为：

```text
ground direct = sumDirectDiffuse + min(sumDirectSpecular, 40)
sea direct    = sumDirectDiffuse + min(sumDirectSpecular, 40) * seaGlitter
```

当前 source sun 单独 clamp、native `light()` 每盏单独 clamp 的路径并不等价。若太阳仍 native fallback，则 source local 无法取得 native 累加后的 specular；该混合阶段应明确保留“总 clamp 未完成”边界，不通过增加局部 clamp 掩盖。普通 generic 和 arms 没有此 clamp，不能把 40 写进共享 BRDF helper。

## 最小验收与未完成边界

- **原衰减 GPU 对照**：采用独立提取的原函数和已记录 backend，覆盖 d=.001/.01/.099/.1/.101、range 内外、range=0、不同 decay、非均匀方向；将方向、attenuation、linear radiance 分开输出。d=0 的 normalize 行为未定义，不用它代表可移植正确性。
- **多灯 BRDF 对照**：十个 point+sun+key，保留原顺序，覆盖金属/粗糙/湿地面/arms。分别读 directDiffuse/directSpecular，再测试地面 30+30→40、sea 总 clamp 后 glitter，证明不是每灯 clamp 后求和。对比 source NVIDIA 参考，不把 SwiftShader 的不同浮点行为误认成原 NVIDIA 本身。
- **语义与时序**：四静态灯全开/逐灯开；world 与 weapon 均受十点灯和 sun 影响，key 只影响 weapon；室内外边界和 viewFill 改变分别测量；flash 第一帧、TTL 到期、槽复用、persistent Gull、暂停和恢复均有逐帧源强度记录。
- **完整路径**：world/weapon/planar 使用相同源 atlas，当前 pass 变换正确；source active 与 native fallback 的开关不能双亮或漏亮；关闭 local 不改变 source IBL、planar RP、sun PCSS 或原材质自发光。

本次完成的是架构与源码核对。四灯恢复、attenuation kernel、多灯 atlas、mask 隔离、原帧时序以及 ground/sea 总 clamp 的生产结果，均应由后续实机证据分别标记。没有实际 SpotLight，不需要为本轮虚构 spot 参数或补充局部阴影。
