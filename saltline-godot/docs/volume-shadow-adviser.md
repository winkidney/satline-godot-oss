# 原作 Y9 体积光的太阳阴影来源

日期：2026-11-15。审查版本为 Godot 4.7.2 `ed1daf0bf`，Forward+ / Vulkan。本文只记录源码调查和实施建议，没有修改运行代码，也没有运行这里建议的新阴影 pass。父代理已经完成的 AO、逐样本场景深度和实际场景贡献测试，不证明本报告的阴影方案已经通过。

建议保留官方 Godot 二进制，新增专用的原作太阳阴影 pass，再接入完整 Y9。公开 GDScript API 无法取得引擎实际 DirectionalLight 阴影图和 cascade 数据。额外 pass 应重建原固定光空间深度、caster 集合与更新节奏。若以后允许维护引擎补丁，可以另做原生阴影资源导出，但原生级联阴影与原作单张固定阴影图仍有语义差别。

## 公开接口的确定边界

| 路径 | `ed1daf0bf` 中的实际能力 |
| --- | --- |
| `RenderData` | 仅绑定 scene buffers、scene data、environment、camera attributes 四个 getter。[绑定源码](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/storage/render_data.cpp#L33-L38) |
| `RenderDataRD.lights/shadow_atlas` | 内部 C++ 成员，没有脚本绑定。这里的 `shadow_atlas` 也不等于方向光 atlas。[成员定义](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/render_data_rd.h#L38-L66) |
| `RenderSceneData.get_uniform_buffer()` | 场景 UBO 包含相机、采样核、atlas 像素尺寸与方向光数量，不含 cascade 矩阵或 shadow texture RID。[UBO 结构](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/render_scene_data_rd.h#L107-L170) |
| `RenderSceneBuffersRD.get_texture(context,name)` | 只查当前 viewport buffers 的 `named_textures`，不能靠猜 context 名取得全局方向光 atlas。[实际查表](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/render_scene_buffers_rd.cpp#L356-L362) |
| `Light3D` / `RenderingServer` | 可设置灯光参数，没有公开运行时 light-instance cascade getter。资源 light RID、场景 instance RID 与内部 light-instance RID 不可混用。[公开绑定](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/rendering_server.cpp#L2310-L2330)、[内部 instance 建立](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L648-L656) |

完整资源存在于引擎内部 `LightStorage`。它提供 [cascade camera/transform/rect/split getters](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/light_storage.h#L690-L730)、[方向光 UBO](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/light_storage.h#L184-L215) 与 [directional_shadow_get_texture()](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/light_storage.h#L1083-L1085)。它们没有 ClassDB 绑定。

Forward+ 单独绑定方向光 UBO 和 atlas。方向光 UBO 是一个 set 的 binding 7，方向光 atlas 是另一个 set 的 binding 6；binding 5 才是其他灯光 atlas。[UBO 绑定](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L2902-L2907)、[atlas 绑定](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L3110-L3134)。场景 UBO RID 不能用来反查这些 descriptor。普通 GDExtension 只使用公开 ABI，也不能补出这个缺失接口。

## 原 Y9 需要的阴影语义

原代码位置均指 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。

| 来源位置 | 必须保留的行为 |
| --- | --- |
| `Y9`，35675–35732 | `tShadow` 是 `sun.shadow.map.texture`，RGBA packed forward depth；nearest 单 tap；`step(sc.z-.0006,d)`；任何 xyz 越界都返回可见 1 |
| `sunVis()`，35684–35690 | `sc=uShadowMatrix*vec4(world_position,1)`，没有除以 w，因为太阳是正交投影 |
| 36440–36458 | 当实际 shadow map 存在时才设 `uHasShadow=1`，绑定 `sun.shadow.matrix`；太阳辐射按原 `sun.intensity*volSunScale` 构造 |
| `ZM()`，35489–35541；调用 36701–36713 | 单个固定世界边界拟合的正交相机，不跟随玩家，也不是 cascade |
| `P9`，29563–29644 | 非 VSM 使用 RGBA depth packing、nearest、普通单样本 render target，清屏 packed depth 为白色 |
| `P9.b/g`，29682–29770 | 按当前主世界相机 layers、祖先可见性、castShadow、阴影 frustum 和材质可见性筛 caster；保留材质组、alphaTest、map/alphaMap、位移及 customDepthMaterial |
| `Z()`，36942–36954 | ultra 或 `params.shot` 每帧更新；其他质量按渲染帧偶数更新；首次没有 map 必须更新。`params.shot` 是截图/测试参数，不是武器开火 |

先画世界会完成这次 shadow update，并清除 renderer 的 `needsUpdate`。之后的 viewmodel render 使用另一层，但不再次请求 shadow update。因此此太阳图不包含第一人称武器。原世界和武器合成 depth 用于 AO/Q9 的规则不能挪到这里。

原非 VSM 默认 shadow side 与可见材质 side 相反：FrontSide 画背面，BackSide 画正面，DoubleSide 画双面；显式 `shadowSide` 优先。这与直接再画一遍 Godot 可见材质不同。太阳的 `shadow.bias=-.00012` 与 `normalBias=.02` 是材质接收阴影时的参数，Y9 没有使用它们。不要在新的阴影图和 Y9 中重复加入这些偏置。Y9 也不使用原材质的 PCSS/PCF 软阴影核。

当前 prepared 快照中，world 层有 148 个 castShadow mesh 节点，含 130 Mesh 和 18 SkinnedMesh，使用 91 个材质。149 条 castShadow 记录中另有太阳自身。特殊 caster 材质包括双面 tarp 和两种 alphaTest=.5 的双面 chainlink。这个快照只能辅助建立清单；动态生成、池化回收、隐藏祖先和骨骼动画仍须同步。

## 原太阳相机的可复算参数

`ZM()` 使用接收区域 `[-41,-.2,-33]..[37,32,31]` 和 caster 区域 `[-41,-3,-64]..[72,36,34]`。太阳 target 为接收盒中心，position 为 target 加 `normalize(sunDir)*200`。接收盒八角决定 left/right/top/bottom 和 far；caster 盒八角只扩展 near。xy 四侧各留 1，near/far 各留 4。

按 prepared 原太阳方向复算，结果如下。这是 CPU 数学复算，不是 GPU 验收。

```text
target   = (-2, 15.9, -1)
position = (181.26947229749683, 60.91706470189606, 65.22510407256709)
left/right = -44.349397293811236 / 44.34939729381122
bottom/top = -27.390530305380572 / 27.390530305380576
near/far   = 112.07668703468636 / 253.95743745812524
width/height = 88.69879458762246 / 54.781060610761145
width/height ratio = 1.6191507356503891
```

对应矩阵按行显示，使用列向量 `M*vec4(p,1)`。Three `Matrix4.elements` 与 Godot `Projection` 的列存储需要按列填写，不能把下列行数组直接视为列数组。下表忽略原 double 计算中约 1e-14 的 xy 中心残差。复算检查得到 eye→`(0,0,0,1)`，target→`(0,0,-200,1)`。

```text
V =
[ 0.339846296967185,  0,                  -0.940480991002844,  -0.260788397068481 ]
[-0.211688468114392,  0.974339056561232,  -0.0764944136963578, -15.9918623492487  ]
[ 0.916347361487484,  0.225085323509480,   0.331125520362835, -201.415036400463   ]
[ 0,                  0,                   0,                  1                 ]

P_GL =
[0.0225482207430031, 0,                  0,                  0                ]
[0,                  0.0365089682036408, 0,                  0                ]
[0,                  0,                 -0.0140963449518773, -2.57987164150453 ]
[0,                  0,                  0,                  1                ]

uShadowMatrix = B * P_GL * V =
[ 0.00383146466135414,  0,                   -0.0106030864948652,  0.497059842827843 ]
[-0.00386426377573288,  0.0177860568177797,   -0.00139636605869824, 0.208076802987138 ]
[-0.00645857425163507, -0.00158644018189726,  -0.00233382977870219, 0.629672095045656 ]
[ 0,                    0,                     0,                   1                 ]
```

high 的原阴影图为 4096×4096，受设备最大纹理尺寸限制。矩形世界区域投到方形纹理，x/y 的世界 texel 大小不同。单纯建立一个方形 viewport 加普通正交 Camera3D，不能复现这张图。Camera3D 公开的正交配置只有 size、near/far 和跟随 viewport 的 aspect，没有任意投影矩阵 setter。[Camera3D API](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)

## 可实施的官方引擎方案

推荐先做独立 caster `World3D`、固定 shadow Camera3D、专用深度材质和一个 depth bridge。这仍会额外绘制 caster 几何，但不需要重新执行主场景完整材质、原生灯光阴影和后处理。

1. 建立专用 `SubViewport`，原分辨率 4096²，关闭 MSAA、TAA、动态分辨率和屏幕效果。独立 World3D 不放灯光，环境关闭 fog、glow、SSAO 等。viewport 的 color 不参与最终图像，只使用其实际 depth。不能靠给共享世界设 `debug_draw=UNSHADED` 就宣称没有额外阴影工作，需实测该路径。
2. 为原 caster 建立轻量代理，复用 Mesh、纹理和可共享的实例数据，不复制游戏逻辑。同步 global transform、有效可见性、实例数量、骨骼/skin 与 morph 状态。当前实际骨骼绑定可作为移植基础，但跨独立 World3D 的代理绑定必须用变形顶点和阴影图测试，不能只验证静态姿态。
3. 每种阴影 side 和 alphaTest 建立明确的 depth shader 变体。opaque 写 depth；alpha-test 在 fragment 做与原 shadow material 一致的 discard。map/alphaMap 继续使用各自原采样和 UV 变换，nearest 只要求用于最终阴影图。不要因原可见材质透明就自行加入透明混合，也不要默认所有可见节点都投影。
4. Camera3D 使用原位置、look-at、near/far，正交边长设 `S=max(width,height)`。这个方形 frustum 包含原矩形，供引擎做保守裁剪。专用代理 shader 只修正投影 xy 缩放，保留引擎的 reverse-Z 和屏幕方向修正：

   ```glsl
   void vertex() {
       PROJECTION_MATRIX[0][0] *= shadow_square_size / shadow_width;
       PROJECTION_MATRIX[1][1] *= shadow_square_size / shadow_height;
   }
   ```

   原 ZM 的 xy 中心为 0，所以这里只需对角缩放。`PROJECTION_MATRIX` 是公开的 inout builtin，[官方定义](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins)。Forward+ 在用户 vertex 代码之后用这个矩阵计算 gl_Position，[源码](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L415-L488)。这条建议尚未实测；先用矩形四角与非对称图案验证。修改投影不会修正引擎的 culling，所以保守相机和动态 caster AABB 必须正确。
5. 在该专用相机 compositor 的 POST_TRANSPARENT 获取非 MSAA depth，GPU compute 转成持久 `R32F` forward depth，即 `1-native_z`。不经过 HDR2D 的 RGBA16F 中转。让 Y9 的深度读取从 packed dot 改为 `.r`，其余投影、越界与比较公式保持原样。R32F 与原 RGBA8 packing 的差异应独立记录，尤其测试 `.0006` 比较阈值附近。
6. 若要求保留原 packed sampler，可以再把 forward depth 用原 `packDepthToRGBA` 写入 RGBA8 UNORM。这个转换并不能恢复在 native depth attachment 中已经丢失的精度。若需要从原始 fragment depth 直接 packed RGBA8，应选下一节的自建 RD 绘制。不要用普通空间材质 ALBEDO 加 ALPHA 偷渡四通道数据，ALPHA 会改变渲染通道，颜色也可能经过色调和格式转换。
7. 在阴影图就绪后才允许 Y9 正式启用 `uHasShadow=1`。原 `uShadowMatrix=B*P_GL*V` 保持 world→原 bottom-origin UV/forward depth；导出的 native 顶部起始纹理在采样助手中翻 y 一次。采样使用 nearest/clamp、无 mipmap、无 source_color、无 comparison sampler。

单独把同一 World3D 再交给一个相机，只能快速证明光空间 depth 能流入 Y9。普通相机按 visibility/layers 画几何，不按 castShadow 筛选，也不会自动切换成原 shadowSide/alpha-test depth 材质；还可能让原生灯光再次准备阴影。没有这些修正时，它不是原太阳阴影实现。

## 自建 RD 绘制与引擎补丁的取舍

自建 RD draw pass 可以直接建立 4096² RGBA8 color 加 depth attachment，使用原光空间矩阵，fragment 写原 packed depth，nearest 交给 Y9。它能避开额外 3D viewport 的颜色、灯光和后处理成本，也能原样表达非等比正交投影。

代价是自行维护 vertex/index buffers、实例化、骨骼/morph、alpha clipping、材质组、face culling 和可见性。不能假定已有 Mesh RID 能直接绑定到自建 RD 的 vertex array；需要明确支持的资源导出接口或使用本项目已有原始几何数组创建自己的 GPU buffers。原 prepared 数据使此路线可做，但它比专用深度代理的初次实现范围更大。是否转用该路线，应由完成代理版本后的 GPU 时间与 VRAM 测量决定。

若选择引擎模块或源码补丁，可在 world viewport compositor 阶段暴露只读方向光 atlas RID、对应 light index、cascade matrices/splits/atlas rect 以及必要的 bias/坐标约定。随后立即计算 Y9 的阴影项，或复制到自己持有的纹理和 buffer。这能复用现有阴影绘制，不需要 CPU readback。

但 native 矩阵已经包含当前相机 view、atlas rect 和 depth correction，[构造源码](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L753-L773)。不能直接替换 Three 的 world→单图矩阵。还必须实现 cascade 选择、越界、split transition 和原生阴影覆盖范围。方向光资源为引擎共享数据，后续 weapon viewport 可能改写；在 world 回调内消费或复制是合理的生命周期设计，但这个跨 viewport 行为仍需非周期帧探针验证。维护自定义编辑器和所有导出平台模板也是该路线的实际成本。

## 帧顺序、更新与资源寿命

建议把专用太阳 pass 注册在已有 world/weapon 和 Y9 之前，或者至少确保它在 Y9 消费前执行。只在原更新帧请求一次渲染，其余帧保留上一张已完成的阴影图。Y9 自身每帧运行，跟随本帧玩家相机；不要把阴影图和体积光一起降为隔帧更新。

```text
应更新阴影的帧：原 caster 状态同步 → sun_shadow_port → GPU depth export
每帧：world/weapon → combined depth → half depth → Y9 → QM 横/纵 → joint composite
```

既有多 viewport 链路已经验证的排序方式可以复用，但 sampler 引用不自动建立所期待的渲染顺序。增加这个 viewport 后仍要验证首次帧、非周期移动 caster、隔帧持有、重入和 resize。原 shadow 分辨率独立于窗口，普通窗口 resize 不应无故重建阴影图。

持久 `Texture2DRD` 的分配和 RID 发布必须在帧前完成，回调只写已准备目标。不要重犯在 compositor 回调中替换 wrapper RID 导致后续 Canvas material uniform set 失效的问题。停用时先停止 Y9 消费，再在渲染线程释放自有资源；不释放引擎 depth RID，不保存跨帧 RenderData，也不在运行时 submit/sync/readback。

4096² 的 RGBA8 或 R32F 单图各为 64 MiB，32-bit depth 另约 64 MiB；RGBA16F color 单图为 128 MiB，尚不包括引擎额外 attachment。上述是按 texel 大小计算的容量，不是实际分配测量。记录新增 pass 的 GPU 时间、draw calls、三角形数和 VRAM，再判断是否需要 RD draw 或分层缓存。降低分辨率、改 caster 更新频率都应作为显式质量变体，不能用于声明原 high 已完成。

## Y9 接线和验收边界

Y9 原算法同时用阴影调制太阳散射和环境散射，后者系数为 `.40+.60*shadow`。无阴影 fog 会失去棚屋门洞、屋顶和堆叠物之间的光束。`uHasShadow=0` 只适用于初始化/故障诊断或原 map 缺失情形，不能作为默认完成方案。

另外，当前 native 主太阳能量为 3，prepared 原太阳 intensity 为 9。Y9 应由原渲染参数计算 `uSunRad=color*(9*.85)`，不能悄悄改为 native 灯光的 `3*.85`。保留原 high 的 24 步、双相位函数、棚屋密度与环境压暗、sky 路程、远处解析延续，以及 RGBA16F volA/B、原 QM 深度引导双向模糊和 joint composite。来源为 35675–35732、36085 附近默认参数、36440–36464。

建议先获得以下证据，再默认启用原 vol：

1. 独立 Three 原 shadow pass fixture 与 native 专用 pass。矩形四角、不同深度平面、front/back/double sided、alpha-test 孔洞分别验证，特别覆盖 view frustum 外但位于 sun frustum 内的 caster。
2. 固定世界采样点对比 `uShadowMatrix*p`、最近邻 texel 和 `sunVis`。扫过 `.0006` 阈值两侧，单独标记跨后端栅格和深度格式差异，不扩大比较 bias 掩盖误差。
3. 非周期移动的静态与骨骼 caster，验证原隔帧更新和当前 Y9 同帧消费。武器开火、换枪与 viewmodel 位移不得改变这张 world-only 太阳图。
4. 使用已验证的半深度和合成 shadow 输入做 Y9 GPU 数值对照，再对实际太阳图做端到端对照。数值 fixture 与真实几何图必须分别保留。
5. 冻结实机场景，对比 vol off、正确阴影、强制全可见三种状态。棚屋、门洞、遮挡边缘与远处地平线都应有可解释的贡献，且无 HDR/gamma/alpha 回归。

仍待验证的是专用代理投影、变形同步、真实阴影图数值、额外 pass 成本及完整 Y9 实机结果。公开 API 不足和原 shader/阴影生成规则已由本轮源码确认。
