# 局部直接光实现复审

本轮只读核对共享 shader、灯数据、注册 service、五类材质和生成器，并复读原 bundle。顾问仅写本文；生产修正由主线完成。总体上，十点灯→太阳→key 的共同累积、原 point 衰减、地面/海面总高光限制和 native 隔离设计符合原作。审查发现的两处材质/相机语义问题已修正；另发现一处 native 压力测试的覆盖漏洞，也已通过修正后的 world/weapon 两 pass 探针补足。

相关源码来源与单位约定见 [原局部光顾问报告](local-light-adviser.md)。本文聚焦实际实现，不重复该报告的架构提案。

## 已发现并修正

### 手臂 bump 必须先归一化输入法线

审查开始时 `arms.gdshader` 用 `armBump(NORMAL,v_view_pos,armH)`。Godot Forward+ 进入用户 fragment 前将 `normal_interp` 直接赋给 `normal_highp`，此时插值后的 NORMAL 不保证单位长度。原 Three 先执行 `normalize(vNormal)`，再在 arm patch 中调用 bump。[Godot 输入](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1262)、[用户 fragment 插入点](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1351)、[Three normalize](../../artifact-rendering-study/source/extracted/bundle-1.js#L22990)、[arm patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L75327)

这不是末尾再 normalize 就能消除的误差。若输入法线为 `k*N`，armBump 中 `abs(det)*N` 随 k² 变化，而梯度项只随 k 变化，因而改变表面细节坡度。影响直接光和 IBL，不能靠多灯数值 kernel 验证发现。

**已确认修正**：[arms.gdshader](../shaders/arms.gdshader#L133) 与 [port_arm_shader.py](../tools/port_arm_shader.py#L18) 均改为 `armBump(normalize(NORMAL),...)`。扰动前的 `source_non_perturbed` 仍用于原 geometryRoughness，最终 bump normal 用于 NL/GGX/IBL，两个角色没有混用。这是既有材质输入问题，不应描述成 atlas 引入的错误。

### 灯过滤必须读取当前相机层

审查开始时 service 从 `node.layers` 推导实例 `source_local_camera_mask`。原 Three 在每次 render 时按 `camera.layers` 收集灯，而不是按被照物体的 layers 过滤灯。[原收集逻辑](../../artifact-rendering-study/source/extracted/bundle-1.js#L33694)

原导出几何为 277 个 layer1、24 个 layer2，没有 layer3，因此原对象分组暂时掩盖了差异。同一 layer3 对象若同时进入 world 与 weapon，相同实例 mask 会让 world 错误得到 key。已有 254 对象的局部光 on/off 图不能覆盖这一情况。

**已确认修正**：五类 fragment 现在向共享 helper 显式传 `sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS)`；service 已删掉按对象赋值的实例 slot12。helper 保留原低两位，并把 native world-only bit4 映射回原 world bit1，忽略 fallback/marker 高位。Godot 内建量直接映射当前 scene data 的 camera visible layers，不需要引擎补丁。[官方映射](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L789)、[当前 helper](../shaders/source_direct_surface.gdshaderinc#L7)

最终空间回归将 231 个 world Standard 几何临时改为 layers3，切换 key visible：world HDR 差为零，weapon 中 29309 个抽样点改变，已实际验证当前相机过滤。Canvas kernel 只接等价整数 mask，负责验证数学分支；空间 built-in 的绑定结论来自这一独立实机实验。camera mask4 单独渲染尚未专测，当前主 world mask5 已覆盖生产路径。

## 已核对正确的实现

[source_local_light_data.gd](../scripts/source_local_light_data.gd) 保存固定十一行：六个 pool 槽、四个原 level PointLight、key。mask 来自原语义，没有读取已被 fallback 改写的 native light_cull_mask；visible 使用层级可见性；源 intensity 独立保存在 metadata/pool state，native `/π` 不回流进 atlas。

CPU 上传原线性辐射，RGBA32F 最近点数据不走 sRGB、mipmap 或硬件 bilinear。四仓库灯保持原创建顺序，Gull persistent 仍占六池槽之一。数据状态没有加入原作不存在的局部阴影或 spotlight 选择逻辑。RGB 目前通过 native Color 的 linear↔sRGB 往返恢复，会有 float32 舍入；若后续严格 GPU 对照证明这成为误差来源，再保留独立 source_color_linear。当前没有证据要求为此改写生产路径。

[source_direct_surface.gdshaderinc](../shaders/source_direct_surface.gdshaderinc#L14) 建立一次 PhysicalMaterial 和一个 ReflectedLight：十个 point 依序累积，然后 source sun/PCSS，最后 key。每个 point 先用当前 VIEW_MATRIX 将 world light position 变到 view space，再减去实际 fragment VERTEX。传给 `RE_Direct_Physical` 的 geometryPosition 为零不影响结果，因为该原函数没有读取这一参数；距离和方向已在 point helper 中计算。[原 point 顺序](../../artifact-rendering-study/source/extracted/bundle-1.js#L22765)、[原 directional 顺序](../../artifact-rendering-study/source/extracted/bundle-1.js#L22816)

五个调用点使用最终扰动 normal、扰动前 normal、实际 view position 和当前 view matrix。地面湿 F0、generic metalness、sea/arms 非金属 F0 选择正确；源 Lambert/GGX 没有落回 native Burley。Sea 用位移后的 VERTEX 计算点光距离，位移前 vGWorld 继续仅服务原水面纹理和 glitter 方位。

[ground.gdshader](../shaders/ground.gdshader#L185) 在 helper 返回完整 specular 总和后 clamp40；[sea.gdshader](../shaders/sea.gdshader#L84) 也是一次总 clamp，随后乘 sea_glitter。没有把 clamp 放进单灯 BRDF，也没有限制 directDiffuse 或 IBL。sea glitter 虽名为 sun glitter，原实现确实作用于全部 directSpecular，当前保留了这个行为。[原 ground](../../artifact-rendering-study/source/extracted/bundle-1.js#L56142)、[原 sea](../../artifact-rendering-study/source/extracted/bundle-1.js#L56463)

[sun_shader_bridge.py](../tools/sun_shader_bridge.py) 的三个专用材质模板与现有 shader 同步使用共享 helper、当前相机 mask 和各自 clamp/glitter。原 IBL 仍单独累积，未通过修改 ALBEDO、AO 或 native 环境来补偿局部光。

## Native 隔离与生命周期

[source_local_light_service.gd](../scripts/source_local_light_service.gd) 使用 worldFallback `1<<18`、weaponFallback `1<<17`，与 source sun 的 `1<<19` 分离。点灯只照两个 fallback 位，key 只照 weaponFallback。源路径完整支持的 GeometryInstance 去掉这两个位，保留实际 render layers；未知材质或存在未支持 surface 的整个对象继续 native fallback。Basic/unshaded 被识别为不需要 source direct 的已知材质，未强行加光。

`enabled` 与 `radiance_enabled` 分离有效：前者切换 source/native 路由，后者关闭迁移对象上的局部贡献，同时保持 native 隔离，允许获得真实 local-off 图。共享材质只存纹理和 ready/enabled，逐对象 active 仍是实例状态，mixed material 对象不会因为共享材质被其他对象绑定而重复照明。

正常 Main 生命周期顺序正确：`_process` 先更新 key、执行一次 pool TTL，再上传 atlas 和更新 service，之后更新渲染 pass；dispose 先恢复 native 路由并解除材质纹理，再清空 data，灯数组尚有效。weakref 清理不会将已销毁的材质长期保活，ImageTexture 无手工 RD RID 退役问题。现有六槽和四静态灯生命周期固定，足以支撑这个实现。

这两个 RefCounted 组件的 `setup()` 目前应视为一次性调用：重复 setup 没有清空 lights/masks/original_masks，外部删除池灯或替换 data.texture 也没有通用重绑定协议。Main 每次创建新组件，当前未触发这些条件；不需要为了本轮先泛化动态灯编辑器。后续若引入复用组件/热重载/任意灯增删，应先补生命周期契约，不能假设现有固定布局自动支持。

source/native 混合 fallback 仍是过渡路径。如果只关闭 source sun 的 migration、保留 source locals，或者反过来让 locals native、sun source，地面/海面的两部分不再共享同一个 specular accumulator；这时不保证原总 clamp 等价。`radiance_enabled=false` 的诊断关灯与 `enabled=false` 的 fallback 是两种不同状态，报告应继续区分。

## 压力测试中发现的覆盖漏洞

审查时的 [verify_local_light_service.gd](../tools/verify_local_light_service.gd) 先把 native energy 全设为 1000，再调用 `draw_game()`；后者会多次执行 `game._process(0)`。Main 更新会把 key energy 重设为 source/π，pool.update(0) 也会重设 busy 且非 persistent 的池槽。因此原测试中四静态灯确实维持 1000，但不能只凭最终零差把 key 和活跃 flash 也算作经过 1000 压力测试。它不是已发现的生产隔离失败，而是原验证步骤不足。

最小修正顺序是：先执行本帧更新/atlas 上传/service 绑定，再在绘制前最后一步把 native energy 设为 1000，随后 force_draw；中间不能再次调用 Main._process。记录每个灯 draw 前的实际 energy，分别比较 world 和 weapon HDR 输出，再恢复。还应保证灯在场景中的位置、范围或 key 方向确实能对未隔离对照面产生贡献，以免零差来自灯根本照不到。

**已补足验证**：最终探针在 Main 更新之后设置 native 能量，绘制期间不再调用 Main._process。结果记录十一盏 native 灯均为 1000，world 和 weapon 的 HDR 最大差均为 0。这支持当前场景两条 pass 没有 native 重复局部照明，不再沿用旧测试对 key/flash 的推断。

扩展共享层实验的初版错误地把合成后的 scene_port 当作 world 输出，weapon 对 key 的正确响应被误计入 world，造成失败。该结果保留在 [composite probe failure](../evidence/local-light-service-composite-probe-failure.json)。最终改为分别读取 world_port 和 weapon viewport 后通过；这里修正的是测试观测点，没有调整着色公式或容差。

## 审查时已读取的验证与剩余范围

- [实际场景 service 验证](../evidence/local-light-service-verification.json)：254 对象迁移，local off/on 在 world 改变 42267 个抽样 HDR 点、weapon 改变 5881 点；十一灯绘制时实际 energy=1000，两个 pass 的 HDR 差均为零；重新进入 source 的 world 差为零。231 个共享 layers3 几何的 key 开关令 world 差为零、weapon 改变 29309 点。
- [数据验证](../evidence/local-light-data-verification.json)：RGBA32F 完整 GPU 字节往返一致，playing/paused 每次更新仅上传一次，flash 源强度分别 95/93，室内 key 为约 .495，四静态灯顺序/位置正确。该旧 JSON 的 scope 仍写 staged/no consumer，属于历史阶段描述，不代表当前生产未接入。
- [耦合直接光](../evidence/direct-lights-verification.json)：修正后重测 72 cases、576 channels、15 cases 触发总 clamp，全部通过既有容差。参考来自原 NVIDIA Three PointInfo/Physical BRDF；该数学测试不覆盖 PCSS、非零 geometry derivatives，真实空间 CAMERA_VISIBLE_LAYERS 由上述 service 实验独立覆盖。
- [生成回归](../evidence/local-direct-generation-verification.json)：ground/sea/arms 可重复生成，direct 块完整、ground planar 块保留。后续生产修正应继续重跑该检查，而不是只改生成结果。

本轮局部直接光的数学耦合、生产接入、两 pass 隔离及当前相机过滤已有独立证据。仍未由这些测试证明的是整场景逐像素等同原作、非零 geometry derivatives 与手臂曲面 bump 的单独原 GPU 数值对照，以及切换到混合 native fallback 时的总 clamp 等价；不要扩大当前通过结论。PCSS 与 IBL 沿用各自既有验证，本轮不重复宣称覆盖。原项目没有实际 SpotLight；完整 Spot helper 探针的锥边 visible 位差异仍应保留，不能用当前 point/key 成功覆盖或放宽掉那项记录。
