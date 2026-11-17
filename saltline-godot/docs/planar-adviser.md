# 原作平面反射迁移建议

日期：2026-11-15。目标为 Godot 4.7.2 `ed1daf0bf`、Forward+。顾问只做源码审查并写本文，没有修改运行代码；运行结果来自父代理实现的隔离探针。文末的“XR 实测后的太阳光迁移”更新早期建议与未验证状态。

建议先做一个只服务反射 viewport 的单视图 `XRInterfaceExtension` 隔离实验。它是官方引擎中可传入完整投影矩阵的公开入口，可以让 CPU frustum 与实际绘制使用原 oblique projection，不必修改所有世界材质。主画面和武器保持 `use_xr=false`。不过 Godot 的 cluster 和原生级联阴影仍有标准投影假设，实验必须覆盖这些光照路径，不能仅凭几何裁剪正确就默认接线。

## 原作到底画了什么

源码为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。`Uw()` 位于 56157–56258，`RP` 位于 56052–56079，调用与隐藏列表位于 56754–56763，`renderWorld()` 位于 37044–37065，pre-pass 调用顺序位于 37143–37164。

- 反射平面是 `y=0`；clip plane 是 `y=-.01`，不是把反射平面整体挪到 -.01。原相机 y<.03、质量 planar<=0 或用户关闭反射时，设 `uReflOn=0` 并停止反射更新。
- 对原位置、向前目标和 up 分别反射 y，然后用 lookAt 建立右手正交相机。不要把现有相机 basis 简单乘一个 determinant=-1 的反射矩阵。原 lookAt 结果 determinant=+1，图像方向由其投影矩阵配合地面采样决定。
- 复制主相机完整 projection；先计算 `uReflMatrix=B*P_original*V_reflected`，再修改反射相机的 projection 为 oblique。`uReflScale=(P_original[0]*.5,P_original[5]*.5)`。
- 反射 target 为线性 sRGB 空间的 RGBA16F、单样本、有 depth、自动 mipmap；min 为 LinearMipmapLinear，mag 为 Linear。high 的 planar 比例是 .5。
- 尺寸按实际主渲染分辨率计算：`E=max(64,round(width*b/16)*16)`，`M=max(32,round(height*b/8)*8)`。复制的 projection 不随这个取整后的 E/M 重新计算。例如 1920×1080 得到 960×544，但继续使用主相机的 16:9 projection。
- 精确隐藏列表是 apron、sea mesh、rain、splash。sea skirt 没在列表内，不能把整个 ground 根节点隐藏。反射只画世界层，不画第一人称武器。
- `renderWorld()` 暂时禁用 shadowMap.needsUpdate，设 NoToneMapping、exposure=1，直接画场景。不运行主画面的 AO、Y9、bloom、tk/nk 或 HUD。
- 反射 pre-pass 早于本帧主画面及本帧主阴影更新，因此原反射会使用此前已有的太阳阴影图。Godot 新 viewport 自动重算 native cascade 并不等同于此时序。

初次审查时 `ground.gdshader` 已有 AP 的湿度、法线、roughness 和 RP uniforms，随后父代理已补 RP radiance 路径并通过下面的受控贡献实验。`post_pipeline.gd` 已将主 world/weapon 放入独立 HDR viewport；`source_scene.gd` 使用真实 Skeleton3D、MultiMesh 和共享材质。优先复用同一个 World3D，可以保留这些现有动画、实例、粒子和材质路径。

## 反射 pose 与原斜投影

主相机世界 transform 为 C，位置为 p，forward 为 `-C.basis.z`，up 为 `C.basis.y`。按原代码先取目标 `p+forward`，对 p、目标、up 的 y 取反，再 lookAt。保留主相机 near/far，当前是 `.08/900`。不要用固定 Vector3.UP 替代反射后的 up，否则俯仰和 roll 不再匹配原作。

clip plane 的世界四维系数是 `(0,1,0,.01)`。变到反射 view 空间可用 `transpose(C_reflected)*plane_world`，等价于原 Three `Plane.applyMatrix4(V_reflected)`。先保存未裁剪 P 和 uReflMatrix，再执行原数组公式。以下 P 是 column-major 的原 OpenGL 矩阵，p 数组索引与 Three 一致：

```text
q.x = (sign(c.x) + p[8]) / p[0]
q.y = (sign(c.y) + p[9]) / p[5]
q.z = -1
q.w = (1 + p[10]) / p[14]
c *= 2 / dot(c,q)
p[2] = c.x
p[6] = c.y
p[10] = c.z + 1
p[14] = c.w
```

上传 XR 入口的应是这份 canonical OpenGL oblique 矩阵。不能在 CPU 预先应用 Vulkan 的 y/depth correction 或 reverse-Z；后面 Godot 会做一次转换。矩阵转置、camera up、clip plane 正负和底部起始采样必须各自验证，不能靠最终画面是否像镜子判断。

## 优先实验：单视图 XR 投影入口

普通 Camera3D/RenderingServer 只有 perspective、orthogonal、frustum 参数 setter，没有任意 projection setter。但 `XRInterfaceExtension._get_projection_for_view()` 是公开 virtual，返回 16 元 `PackedFloat64Array`；对应方法通过 GDVIRTUAL_BIND 暴露，可由 GDScript 实现。[官方 API](https://docs.godotengine.org/en/stable/classes/class_xrinterfaceextension.html)、[绑定源码](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/xr/xr_interface_extension.cpp#L36-L61)

只有 `use_xr=true` 的 viewport 使用 primary XR interface；主画面和武器可继续普通相机路径。[viewport 分支](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_viewport.cpp#L309-L314)。反射 viewport 仍放普通 Camera3D，用于环境、cull mask、compositor 等配置。实际 view transform 和 projection 由 XR 回调进入 CameraData。[相机数据入口](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L2753-L2779)

最小接口职责如下。这是实施清单，不是已经运行的组件。

| virtual | 返回或行为 |
| --- | --- |
| `_get_name()` | 独立名称，例如 SaltlinePlanarProjection |
| `_get_capabilities()` | `XRInterface.XR_MONO` |
| `_initialize()` / `_is_initialized()` / `_uninitialize()` | 管理明确的 initialized 状态 |
| `_get_view_count()` | 显式返回 1 |
| `_get_render_target_size()` | 返回本帧原 E/M，XR 会用它覆盖 viewport size |
| `_get_transform_for_view(view,cam_transform)` | 返回快照中的完整反射世界 transform，避免重复乘原相机 transform |
| `_get_camera_transform()` | 与同一反射 pose 一致 |
| `_get_projection_for_view(view,aspect,z_near,z_far)` | 返回保存的原 GL oblique 矩阵，16 项按列排列；忽略由 E/M 推导的 aspect |
| `_pre_draw_viewport()` | 返回 true，或保留默认 true；低于高度阈值时由主控制器停用 viewport |
| `_post_draw_viewport()` | void，`pass` 或不覆盖；不调用 add_blit |

以下是与该版本 virtual 签名对应的最小骨架。`reflected_pose`、`projection_gl`、`target_size` 必须是同一个渲染帧的已发布快照。示例只展示接口，不包含线程同步、源矩阵构造、producer 就绪状态或资源释放逻辑；填入真实数据之前保持反射 viewport 停用。

```gdscript
extends XRInterfaceExtension

var initialized := false
var reflected_pose := Transform3D.IDENTITY
var projection_gl := PackedFloat64Array()
var target_size := Vector2(640, 360)

func _get_name() -> StringName:
    return &"SaltlinePlanarProjection"

func _get_capabilities() -> int:
    return XRInterface.XR_MONO

func _initialize() -> bool:
    initialized = true
    return true

func _is_initialized() -> bool:
    return initialized

func _uninitialize() -> void:
    initialized = false

func _get_view_count() -> int:
    return 1

func _get_render_target_size() -> Vector2:
    return target_size

func _get_camera_transform() -> Transform3D:
    return reflected_pose

func _get_transform_for_view(_view: int, _cam_transform: Transform3D) -> Transform3D:
    return reflected_pose

func _get_projection_for_view(_view: int, _aspect: float,
        _z_near: float, _z_far: float) -> PackedFloat64Array:
    assert(projection_gl.size() == 16)
    return projection_gl

func _get_color_texture() -> RID:
    return RID()

func _get_depth_texture() -> RID:
    return RID()

func _pre_draw_viewport(_render_target: RID) -> bool:
    return initialized

func _post_draw_viewport(_render_target: RID, _screen_rect: Rect2) -> void:
    pass
```

普通 Camera3D 仍设为反射 viewport 的 current camera，并挂载所需 compositor。注册接口、成功 initialize、设置 primary 后，才让这一个 viewport 使用 XR。矩阵按 `Projection.x/y/z/w` 四列各 xyzw 展平成 16 项。主线程提交新的 pending 快照，渲染开始时一次性切换为 active 快照，比在三个 getter 中各自读取可变相机状态可靠；这能避免一帧混入不同姿态、投影或尺寸。

矩阵读取没有自动转置，[源码](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/xr/xr_interface_extension.cpp#L223-L236)。depth correction 在之后的 UBO 上传阶段执行，[源码](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/render_scene_data_rd.cpp#L84-L104)。尺寸同步见 [viewport.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/main/viewport.cpp#L1206-L1216)。

color/depth override 默认返回空 RID，可以让引擎使用内部 texture，不需要模拟 HMD swapchain。[默认值](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/xr/xr_interface_extension.cpp#L256-L266)、[内部 target 回退](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/texture_storage.cpp#L4711-L4719)。`_post_draw_viewport` 不是返回数组的方法，不要 `return []`。不调用 add_blit 时只是不向窗口提交额外画面；此前完整 viewport 绘制和 compositor 已执行。[绘制顺序](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_viewport.cpp#L876-L929)、[空 blit 列表](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/xr/xr_interface_extension.cpp#L310-L320)

XRServer 只有一个 primary interface。建立前检查并保存现有状态，不能抢占真实 XR 会话；退出时恢复原 primary 并解除接口注册。不要修改全局 world origin 或 world scale。当前 project.godot 没有已有 XR 配置，但仍应按运行时状态处理。由主线程完成本帧 pose/projection/尺寸快照，渲染回调只读稳定快照，不在其中访问活动 SceneTree。

## 已确认的 oblique 风险

XR 能传入完整矩阵，不代表 Forward+ 的所有算法都支持斜近平面。`Projection.get_z_near/get_z_far` 明确假定 near/far 朝向 Z，即 `columns[0][2]` 和 `columns[1][2]` 为 0；原 oblique 正好违反这个前提。[源码中的假设](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/projection.cpp#L404-L415)

实际依赖包括 [cluster builder](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/cluster_builder_rd.cpp#L416-L429)、[native directional cascade split](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L2155-L2218) 和 [scene near/far 数据](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp#L1395-L1399)。cluster 还会调用 `adjust_perspective_znear(.0001)`；cascade 会重新建立分级投影。`get_endpoints` 使用平面求交，可以表示斜面，但不能消除这些上层假设。[endpoints 实现](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/projection.cpp#L436-L459)

因此首轮必须同时验证 omni/spot 跨 tile、太阳级联远近和反射软粒子的深度恢复。关闭 SSAO、SSR、TAA、原生 volumetric fog 等可减少无关路径，无法解决上述已经确认的调用关系。若出现随俯仰消失的灯光或 cascade 裁剪错误，应记录为这条公开入口的阻断问题，不能用全 unshaded 场景通过来宣称真实场景完成。

## 隐藏、同帧顺序和原始 HDR

共享场景使用稳定 layers 隔离原四个被隐藏的对象，不在 compositor 中反复修改 visible。一个可行分配是普通 world bit 1、weapon bit 2、主画面专用 ground/sea/rain/splash bit 4；主世界 camera mask=1|4，反射 mask=1，武器 mask=2。原四节点要从 bit 1 移走，不能只是再加 bit 4。保留 sea skirt 的原 world 层。审查灯光 mask、动态生成节点与当前按 world bit 查 caster 的代码，避免层调整引起旁路变化。

反射 viewport 共享当前 World3D，单样本，关闭后处理。用相机独立 Environment 保持 linear/exposure=1，保留需要的 native 灯光、环境贴图和材质路径。原始反射图不能接入主画面的 AO/Y9/tk，也不能重新混入 HUD 或武器。

建议顺序为 `reflection 3D → reflection HDR copy/mips → main world 3D → weapon →现有 post`。实际注册顺序须用非周期图案验证，不能只凭 sampler 依赖推断。第一帧未完成和停用时 `uReflOn=0`，不要把未初始化 mip 或上一尺寸的图当成本帧反射。

原 `renderWorld` 会抑制太阳 shadow 更新。Godot 对额外共享世界 camera 可能重新构建原生 cascade，这会增加开销，反射的 surface shadow 也可能与原先前固定图不同。这是现有 native surface lighting 与原 Three 的差异，专用 Y9 太阳深度 pass 并不会自动替换这些表面阴影。需要独立记录，不应靠关闭反射里的阴影消除问题。

## GPU mip 链

普通 ViewportTexture 加 `filter_linear_mipmap` 不会自动替它生成完整 mip 链。公开 Viewport 配置中的 mipmap bias 是采样偏置；公开 RenderingDevice 没有 `generate_mipmaps` 方法。[Viewport 定义](https://github.com/godotengine/godot/blob/ed1daf0bf/doc/classes/Viewport.xml)、[RD 方法定义](https://github.com/godotengine/godot/blob/ed1daf0bf/doc/classes/RenderingDevice.xml)

在反射 compositor 的 POST_TRANSPARENT 读取实际内部 color，GPU 复制到自己持有的 `R16G16B16A16_SFLOAT` 2D texture，分配 `1+floor(log2(max(E,M)))` 个 mip；使用 STORAGE 和 SAMPLING usage。通过 mip slice view 逐级 compute。第 k 级只读 k-1、写 k，不产生同一子资源读写反馈；用明确的 dispatch/list 顺序让 RD 管理 barrier。slice API 见 [texture_create_shared_from_slice](https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html#class-renderingdevice-method-texture-create-shared-from-slice)。

不能假定固定 2×2 平均必定等价于原 glGenerateMipmap。E/M 虽经 16/8 对齐，后续仍会出现奇数层，例如 640×360 的高度链是 360、180、90、45、22。先用原 Three 对 HDR 非对称图案逐 mip 读回，验证目标中心映射、边界、奇数尺寸和 RGBA16F 舍入，再确定 compute 核。既有 NVIDIA 与 SwiftShader 的半精度/双线性差异经验仍适用，但这里需要独立证据。

输出用持久 Texture2DRD 绑定地面。texture/RID 和各 mip view 在帧前准备与发布，回调内只写，避免之前 resize 时 Canvas/材质 uniform cache 失效的问题。全链无运行时 CPU readback，也不调用全局 RD submit/sync。缩放或停用后必须保持输出就绪状态与尺寸一致。

## RP 的正确接入点

原 RP 先算投影 UV、波纹倾斜、puddle/damp/soak LOD，再做三次不同偏移与 LOD 的采样，权重 .5/.25/.25，最后把 pr 截到 48，计算 pw，执行 `radiance=mix(radiance,pr,pw)`。Godot 的 spatial 输出 `RADIANCE=vec4(pr,pw)` 在环境镜面辐射阶段做同类混合，[官方定义](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins)、[Forward+ 实现](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1685-L1737)。它比写 EMISSION 或直接混 ALBEDO 更符合原语义。

将 RP 公式整体移入 ground fragment，保留原 `rc.xy/max(rc.w,1e-4)`、`uReflLod=log2(M/270)` 和 `.002..998` clamp。反射 sampler 用 `filter_linear_mipmap,repeat_disable`，无 source_color，无额外各向异性；当前占位的 repeat_enable 应随正式接线修正。原 bottom-origin UV 在采样时翻 y 一次，HDR color 不能经过 toSRGB 再当线性 radiance 使用。

RP 的 r 是 Three `material.roughness`，包含 `max(gRough,.0525)+geometryRoughness` 后 clamp 到 1，源码 22349–22354；不是任意换成另一个经验粗糙度。平坦 apron 的 geometryRoughness 通常为 0，但公式与测试仍应保留。`RADIANCE` 之后的 Godot BRDF 与 Three 环境 BRDF 并不保证数值相同；应分别验证 RP 的 pr/pw、native radiance 注入贡献和最终实机画面，不能用 RP 单元结果宣称完整原 PBR 等价。

### RADIANCE 的生效条件与黑环境探针

本轮父代理的最小 probe 将 `RADIANCE` 固定为 `(.1,8,.2,1)`，black sky、ambient color=black，无直接光。真实 ground 与最小 spatial shader 都输出全黑。源码给出一个确定的消零路径：默认 specular occlusion 在自定义 RADIANCE 混合之后，按环境亮度继续乘间接镜面反射。无 bent normal map 时，公式可写成：

```glsl
ambient_light *= ao;
float s = min(dot(ambient_light, vec3(.3,.59,.11)) * 8.0, 1.0);
float reflective_f = (1.0-roughness)*metallic;
s = max(min(reflective_f*s*10.0,1.0),s);
indirect_specular_light *= s;
```

因此 ambient=0 会将任意自定义 radiance 乘成 0。修改 energy 而保留黑色 ambient/sky 不会改变这个结果。[完整乘法与条件](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L2140-L2184)。区分实验是在最小 probe 中加入 `render_mode specular_occlusion_disabled`；该模式只跳过此消光估计，后续 F0/DFG BRDF 仍然执行，不会把材质改成自发光。模式有公开编译器映射，[源码](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L899)。

`CUSTOM_RADIANCE` 的 mix 位于 `USE_REFLECTION_CUBEMAP` 条件之外，不要求存在非黑 sky；其外层要求是非 depth pass、非 unshaded 且没有 `ambient_light_disabled`。RADIANCE 默认值是 vec4(0)，必须写有效 alpha。后续的 GI、reflection probe 和 SSR 仍可能替换或混合间接反射，F0/DFG 会继续调制；非金属且 SPECULAR=0 时 F0/f90 为 0，也会消除该反射。[最终 BRDF](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L2236-L2260)。不要用开关 sky 或增加环境光掩盖这个已定位的乘零机制。

原 Three RP 没有这项按环境亮度估计的原生 specular occlusion。父代理已在生产 ground 材质加入该 render mode，并用完整 AP/RP 公式复测通过。本轮只读检查的 [planar-radiance-verification.json](../evidence/planar-radiance-verification.json) 为 failures=[]，off=(0,0,0)，on 约为 (.145098,1,.211765)。这让源码乘零机制与实际区分实验对应，已定位本次全黑根因。

该 probe 的输出 viewport 未启用 HDR2D，green=1 已被最终输出截断，因此报告只证明反射贡献恢复，不证明后续 HDR copy/mip 链保真。父代理同时将导入快照中的 `uReflOn=1` 覆盖为 0，直到真实 producer 就绪才启用，防止零矩阵采样旧静态图。原 AO/post 语义继续保留。

## 备选方案与不可采用的捷径

若 XR 的 cluster/cascade 实验失败，最完整的后续是小范围引擎补丁，让反射相机持有独立投影矩阵，并让 cluster/cascade 使用经过审查的 culling/near/far 数据。仅新增 projection setter 仍未修复上述标准透视假设；不能把它视为一次接口绑定就完成。

官方二进制下的替代是为现有 spatial shaders 加统一的相机条件分支，只在反射 pass 覆盖 PROJECTION_MATRIX。使用保留的 camera layer marker 加 `!IN_SHADOW_PASS`，无需修改主视图参数。此版本已有公开 `IN_SHADOW_PASS`，[定义](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/shader_types.cpp#L81-L83)。正常的引擎骨骼/实例变换可以保留；应修改投影，而非自行接管所有 POSITION。

这条替代仍有三个明确缺口：CPU frustum 与引擎逆投影未同步；引擎灯光数据按普通 camera 生成；所有参与反射的特殊 shader 都要覆盖。当前 `dynamic_sky` 自写 POSITION 并固定 far depth，`lit_particle` 使用 INV_PROJECTION_MATRIX 恢复软粒子深度，必须分别处理。sky 的原 far-depth 行为要保留，不能把普通几何的 clip 逻辑机械套进去。把源 half-space 改为 fragment discard 可保留普通投影下的灯光路径，但与原 oblique 的 near/far clipping、depth 分布和边缘数值不同，只能作为明示变体。

不建议在 PRE_OPAQUE 用 RD 修改 scene UBO：CPU culling 和 depth prepass 已经发生，opaque 阶段还会重新准备环境 UBO；修改一个 buffer 不能同步全部 pass。POST_TRANSPARENT compositor 只能处理已有图像，不能恢复错误裁剪或被隐藏表面覆盖的反射内容。

## 最小验证顺序

1. 导出原 Uw 的 cameraWorld、P_original、P_oblique、uReflMatrix、E/M、uReflScale 和 uReflLod。至少覆盖俯仰、yaw、roll、高度 .029/.031 和非整齐窗口尺寸，先做 CPU 矩阵对照。
2. 只开 mono XR 反射 viewport，共享含不对称 RGB 标记的简单世界。验证 main/weapon 图逐像素不变；反射 det=+1、方向正确、y=-.01 两侧三角形裁剪正确；Compositor 能读取 HDR>1，关闭和重入无状态泄漏。
3. 在同一探针加入 skin、MultiMesh、alpha-test、天空与半透明粒子，再加入 omni/spot 跨屏幕 tile 和 directional cascade 远近。只有几何通过、光照未通过时保持实验状态。
4. 用原生成 mip 的非对称 HDR fixture 比较整数与小数 LOD，包括奇数 mip 尺寸和边缘。非周期帧颜色验证所有 mip 都来自当前帧，连续 resize 检查 RID/uniform 错误。
5. 独立对照 RP 的 ruv、lod、pr、pw，再在冻结实际场景中比较反射 off/on。检查 puddle 锐度、damp 纵向模糊、雨波纹、海面/skirt 排除和阴影。报告新增 GPU 时间与 draw calls。

以上是初次验证顺序；以下记录已经完成的 XR 实验及其暴露的问题。生产反射仍保持关闭，表面太阳照明与实际场景最终验收留待后续实现。

## XR 实测后的太阳光迁移

### 已定位：原生 cascade 误读斜投影 near/far

[planar-xr-lighting-verification.json](../evidence/planar-xr-lighting-verification.json) 在同一反射 pose、同一可见几何上比较普通 GL 投影与原 oblique 投影：omni、spot、无阴影 sun 都逐像素相同；加入明确壁面与悬空遮挡物后，普通投影有 434 个阴影暗像素，oblique 对照恰有 434 个差异像素，最大通道差约 .796078。报告还测得：

| 投影 | `get_z_near()` | `get_z_far()` |
| --- | ---: | ---: |
| 普通 GL | .0799999982 | 900.265991211 |
| 原 oblique | 10.147047997 | -2.701200724 |

这不是 HDR copy 或镜像 pose 故障。父代理另外完成 XR POST_TRANSPARENT HDR 拷贝：green=4 写入 R16G16B16A16F 后保持 4，非 XR 主图字节不变。相关实现为 [planar_xr_interface.gd](../scripts/planar_xr_interface.gd)、[verify_planar_xr.gd](../tools/verify_planar_xr.gd) 和 [verify_planar_xr_lighting.gd](../tools/verify_planar_xr_lighting.gd)。局部灯探针通过只覆盖当前 0–40 深度范围，不证明所有 cluster 分层与远距灯都已经正确。

本轮随后完成 [reflection-mip-verification.json](../evidence/reflection-mip-verification.json)：80×48、64×40、96×56、640×360 四个非正方尺寸，含奇数中间层，共 1,291,416 个 RGBA 通道，failures=[]；所有生成层（level≥1）对原 Three RGBA16F 自动 mip 的误差为 0，base level 最大误差约 .00005436，原容差 .002 未放宽。实现采用中心映射 bilinear 和逐层显式 half RNE。隔离测试通过 CPU 上传参考 base 只用于验证，生产链在 compositor copy 后由 GPU 生成。[planar-xr-verification.json](../evidence/planar-xr-verification.json) 也确认实际 XR 输出最大 green=4、生成 8 层、末层 green=.0125732421875 非零。此证据覆盖 HDR copy 与 mip producer，仍不替代表面阴影与最终 RP 场景验收。

源码链条明确：`Projection::get_z_near/get_z_far()` 用标准投影的两个标量分母提取距离，未处理 oblique 第三行中的横向项；方向阴影取这个 near/far，再用 aspect/FOV 构建标准透视 cascade。于是合法的斜裁剪投影被解读成负 far，cascade 范围与可见场景失配。[投影距离提取](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/projection.cpp#L404-L415)、[cascade 提取与分割](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L2155-L2219)。`get_endpoints()` 的平面求交不是本次根因；单改 camera.near/far 属性也无法阻止 renderer 从 XR 矩阵重新提取错误值。

推荐继续用原 oblique 绘制，改由现有 **SaltlineSunShadowPass 固定 4096 阴影图 + 原 jM PCSS + 原太阳直接光 BRDF** 提供表面太阳照明。它同时恢复源作固定阴影语义，避开原生 cascade 对该矩阵的假设，不需要再画一次 caster，也不需要引擎 fork。用无阴影太阳或普通投影替代不能作为原反射完成证据。

### 原太阳、对象与材质边界

权威源入口仍是 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)：太阳创建与 jM 安装为 36701–36721，方向光上传为 29290–29306，shadow 接收判断为 22811–22824。原 sun 是 linear color `(1,.72,.42)`、intensity `9`、layers mask `3`，世界相机 mask `1`，武器相机 mask `2`；两相机都会收集这盏灯。指向光源的世界方向为 `normalize(position-target)`，本 fixture 约 `(.9163473615,.2250853235,.3311255204)`。颜色已经是线性值，直接传 shader 数值时不要再做 sRGB 解码。

当前 [scene.json](../assets/prepared/scene.json) 有 301 个带 geometry 的对象：

| layers | castShadow | receiveShadow | 对象数 |
| ---: | --- | --- | ---: |
| 1 | true | true | 147 |
| 1 | true | false | 1 |
| 1 | false | true | 75 |
| 1 | false | false | 54 |
| 2 | false | true | 21 |
| 2 | false | false | 3 |

因此有 148 个世界 caster、222 个世界接收对象与 21 个武器接收对象。这是导出对象计数，不能当作当前可见 draw count；MultiMesh、材质分组、运行时对象和父节点 visibility 都会改变实际绘制。`castShadow`、`receiveShadow` 与是否受太阳照明必须分别保留。`receiveShadow=false` 只令太阳 visibility=1，仍然执行材质直接光；原世界中有 11 个纯 MeshStandardMaterial 对象属于这一类。18 个接收对象混有 Basic 与 Standard 材质，需要按 surface 的材质类型处理。

导出 195 个材质中有 138 个 MeshStandardMaterial、48 个 MeshBasicMaterial、9 个 ShaderMaterial，没有 MeshPhysicalMaterial 扩展。Basic/unshaded 不加太阳。sky、fx_lit 等自写光照 ShaderMaterial 保留自己的源公式，不能因对象在 world layer 就再叠一份 Standard 太阳。`receiveShadow` 是对象属性，建议用 instance uniform 或导入时明确分配的实例参数传递，不应误用共享 ShaderMaterial 的单一值覆盖不同对象。当前 loader 保存了 layers/castShadow，新的接收 flag 需要显式传入。

### 原 jM PCSS 的准确边界

表面算法在 bundle 35540–35610；它和 Y9 体积光的单次深度比较不同。可以复用同一张 forward-depth R32F 图，但不能复用 Y9 的 bias/tap 算法。固定 shadow camera、矩阵、caster proxy 与 shadowSide 语义见 [volume-shadow-adviser.md](volume-shadow-adviser.md) 和 [sun-shadow-camera.json](../assets/export/fixtures/sun-shadow-camera.json)。

1. 在 vertex 中用源变形完成后的世界位置与几何世界法线计算 `shadowMatrix * vec4(worldPosition + worldNormal*.02, 1)`，插值到 fragment。对应源 shadow vertex chunk 23456–23466。这个 normalBias 不使用 fragment bump/normal-map 扰动后的法线；也不要把 normalBias 改成光方向偏移。
2. jM 使用 `SL_FRUSTUM=(88.699,54.781)`、`SL_DEPTH=141.881`。这些常量是 JS `toFixed(3)` 的结果，不能直接改成 fixture 中的全精度数值。shadowBias=`-.00012`、radius=`1`、shadowIntensity=`1`；high/ultra 为 8 次 blocker search + 16 次 filter，low 为 8+10。源 radius=2 仅属于 jM 编译失败后 stock PCF 的 fallback（37266–37278），不是当前目标。
3. 先计算 `sc=coord.xyz/coord.w` 与 `dFdx/dFdy(sc)`，再做 frustum 分支。范围判断只检查 xy∈[0,1] 且 z≤1，源代码没有 z≥0 条件。通过梯度行列式得到 receiver-plane dz，clamp 到 `±(.003/max(texel))`；比较中心 `zr=sc.z+bias-(abs(dz.x)*texel.x+abs(dz.y)*texel.y)*.35`。
4. `phi=slIGN(gl_FragCoord.xy)*2π`；source fragcoord 为底部起点，native 转换应使用**当前 viewport 高度**。反射用其取整后的半分辨率高度，不得沿用主 viewport 高度。深度纹理 y 转换与噪声坐标 y 转换是两件事，应分别对照。
5. Vogel blocker search 半径为 `.55*radius/SL_FRUSTUM`，搜索比较含 `dot(offset,dz)`；无 blocker 直接返回 1。`distM=max(zr-avgBlocker,0)*SL_DEPTH`；`penM=clamp(distM*.022*radius,.012*radius,.60*radius)`；filter 半径为 `max(penM/SL_FRUSTUM,texel*1.25)`。filter 使用 phi+1.7，再按离图边缘 .02 的 smoothstep 混回全亮，最后按 shadowIntensity 混合。

R32F 的 `.r` 替代原 packed RGBA depth 解包，使用 nearest、clamp-to-edge、无 mip。原 packed-depth 的量化与 native R32F 的误差仍须留在报告中。现有 shadow bridge 已验证的是投影、caster 深度与时序；不能仅凭它通过就宣称 24-tap receiver PCSS 也已通过。接收平面梯度、光源方向、normalBias、屏幕噪声方向是新的独立验证项。

### 直接 BRDF：Lambert + GGX，不是 Burley

准确入口：`BRDF_Lambert/F_Schlick` 在 21855–21865；材质准备在 22349–22376；`V_GGX_SmithCorrelated/D_GGX/BRDF_GGX` 在 22486–22556；`RE_Direct_Physical` 在 22693–22705。对当前无 Physical 扩展的 Standard 基础分支：

```text
diffuse = baseColor * (1-metalness)
geometryRoughness = maxComponent(max(abs(dFdx(nonPerturbedNormal)),
                                    abs(dFdy(nonPerturbedNormal))))
rough = min(max(roughnessFactor,.0525) + geometryRoughness, 1)
F0 = mix(vec3(.04), baseColor, metalness) ; F90 = 1
a = rough*rough ; a2 = a*a
F = F0*(1-f) + f ; f = exp2((-5.55473*dotVH-6.98316)*dotVH)
V = .5 / max(dotNL*sqrt(a2+(1-a2)*dotNV²)
             +dotNV*sqrt(a2+(1-a2)*dotNL²), EPSILON)
D = a2 / (PI * (dotNH²*(a2-1)+1)²)
irradiance = sunLinearColor * 9 * visibility * max(dot(N,L),0)
sunDiffuse = irradiance * diffuse / PI
sunSpecular = irradiance * F * V * D
```

点积按原 saturate；EPSILON=`1e-6`（原 common 21796）。`nonPerturbedNormal` 是当前 view 空间、normal-map 之前的法线，逐分量导数 max 不是旋转不变量，不能用世界空间版本偷换。直接 BRDF 的 N 则使用最终扰动法线；V 来自当前主/武器/反射相机，反射必须用 reflected view。原自定义材质先处理纹理、wet、roughness 和法线，再进入这些公式。已有 native `.045` roughness 下限只是部分材质 patch 的输入限制，后面原 Standard 仍会执行 `.0525 + geometryRoughness`。

还有三类源修饰，不能遗漏：ground 在 56132 将 F0 混到 `.075`，56142 对全部 directSpecular 做 `min(...,40)`；sea 在 56463 先对全部 directSpecular clamp40，再乘 gSpark 与方位因子；六个 weapon detail 材质在 70486 对全部 directDiffuse 乘 `mix(1,dOcc,.35)`、directSpecular 乘 `mix(1,dOcc,.6)`。普通 slORM AO patch 主要调制 indirect 项，不应随意用 AO 将太阳直接项整体压暗。

Godot 非 physical light units 下会先将方向光 energy 乘 π；同色、同曝光、纯 Lambert 条件下原 sun9 对应 native energy=`9/π≈2.864788976`，当前 `3` 比该值高约 4.72%，而且默认 diffuse BRDF 也可能不同。此数值不能作为完整材质拟合结论。自算原 BRDF 时直接使用 linearColor×9，包含公式自身的 π，不继承 native3、不额外补 π。[Godot 能量转换](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L754-L765)、[Lambert 路径](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl#L239-L244)。

### 官方二进制中的接入方式与边界

建议在 fragment 中分别算出 sunDiffuse、sunSpecular，应用源材质修饰后，将这份**已完成 BRDF 与阴影计算的线性 radiance** 加到原有 EMISSION。此处 EMISSION 是累加出口，不是把反射图或 albedo 直接当自发光；材质仍是 shaded，其他局部灯、环境光、RP/IBL 继续沿现有路径。只在太阳替代项通过验证后，排除同一盏 native sun，保证它不重复照明。

选择 fragment 出口有具体接口原因：该版本 ATTENUATION、LIGHT_COLOR 只读，`light()` 分支替换整段默认直接 BRDF，没有仅覆盖 shadow visibility 的公开 hook。即便自行写 `light()`，renderer 还会对 diffuse 乘 ALBEDO×AO×(1−METALLIC)，对 direct specular 乘 AO；原 Three 的完整 diffuse 不能直接塞入 DIFFUSE_LIGHT，否则重复着色。EMISSION 则不再乘这些材质因子，仍经过环境曝光归一化与最终 fog，因此本链要求继续保持线性曝光配置。[自定义 light 分支](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl#L121-L176)、[只读 built-ins](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/shader_types.cpp#L204-L234)、[最终材质乘法](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L3047-L3056)、[EMISSION 曝光](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1680-L1683)。

原太阳目前由 `main._environment()` 手建的 DirectionalLight3D 代替，source_scene 对导出 Light 节点不生成实际 Godot Light。全体目标 Standard 材质迁移后，可将这一个节点的 `light_cull_mask=0`，并停止其 native shadow 工作；保留其语义参数或直接由统一 sourceSun 配置提供。weapon key、light_pool 的 omni、其他环境项保持原有注册。不要靠全局 shadows_disabled、环境 energy 或全对象 visibility 开关来排除太阳。

分阶段迁移时，可给尚未迁移的对象添加一个专用 layer bit，让 native sun 的 light_cull_mask **只含该 bit**，相机仍只按原 world/weapon bit 选择对象；已迁移对象不带这个 bit。不能在 native sun mask 中继续保留所有对象共有的 world bit。对混合材质 surface 的对象，需要一次迁移其所有受光 surface，或明确拆分测试对象；light_cull_mask 不是 per-surface 开关。instance uniform 决定 sourceSun 是否启用与是否接收阴影，不可将相机层级误用为阴影接收 flag。

这一步可忠实移植**太阳项**，但尚不能宣称完整 Three 光照相同。其余 Godot 局部灯/IBL 的 BRDF、能量与原作仍需后续校准；ground/sea 的 `clamp(sum(directSpecular),40)` 在“太阳自算 + 其他灯自动”的拆分中无法严格重建跨灯总和，不能把逐项 clamp 冒充原总和 clamp。太阳独占 probe 可以先通过，混合灯高光极端场景要单列未完成项；最终全部直接光迁移时统一累加后再执行这些材质后处理。若以后启用 GI，需要重新审查借 EMISSION 承载太阳项是否会被当成二次自发光注入 GI；当前方案不自动覆盖该用途。

### 同一阴影图的原帧时序

源反射 pre-pass 先于主 Z()；`renderWorld()` 强制 shadowMap.needsUpdate=false，主 Z() 随后按 ultra、shot、偶数帧或图尚不存在来更新（36940–36952）。所以反射使用此前已完成的太阳图，主 world/weapon 与 Y9 使用本帧可能更新后的图。

优先排成 `reflection读取旧sunDepth → SunShadowPass按原条件更新 → world → weapon → Y9`，即可复用一个 persistent target；这是不同 pass 的有序读写，没有同 pass feedback，不需每帧 CPU 回读或再画 caster。所有材质应在 render flush 前拿到稳定 Texture2DRD，callback 只写纹理。若现有 viewport 创建顺序无法调整，则在更新前 GPU copy 一份旧图供 reflection，不能改成 reflection 读“更早更新的本帧图”又声称原时序一致。首帧无历史图、强制更新、暂停后恢复、resize/重建都要单独定义并验证。当前 frame%2 的 native helper 还需和源 ultra/shot/first 条件统一。

### 迁移验收顺序

1. **BRDF 独立**：原 Three GPU 与 native HDR 浮点探针对照 baseColor、metalness、roughness、N/L/V，覆盖 grazing、roughness 下限、metal=0/1、F0=.04/.075、双面与 bump。输出 sunDiffuse/sunSpecular 分开比较；先禁环境与其他灯，visibility=1。检查 9 与 π 的尺度，不靠最后 tone mapping 隐藏差异。
2. **PCSS 独立**：固定同一 shadow depth fixture，输出 sc、receiver dz、zr、blocker 平均、penM、visibility，覆盖无 blocker、斜坡、自阴影、图边缘、多个 blocker 深度和不同屏幕分辨率。原 packed depth 与 native R32F 的差别单独归因。验证 vertex normalBias 及主/反射 FRAGCOORD 方向。
3. **反射阴影重现**：现有壁面+悬空物用固定原 SunShadowPass 替代 native sun，normalGL 与 oblique 可见区域应恢复一致的完整 shadow contribution；同时与 Three 原固定太阳 probe 比较。434 个 native cascade 暗像素只是已定位失败的证据，不要求原固定 PCSS 恰好也产生 434 个暗像素。
4. **对象规则与组合**：实际 ground、container、chainlink alpha-test、skin、weapon21接收对象、receiveShadow=false Standard、Basic、自照明 fx 分别检查太阳开关差值；验证未重复添加太阳、原 emission 保留、其他灯/IBL 不因排除 sun 消失。ground/sea 总 specular clamp 的混合灯差异明确报告。
5. **时序与最终图**：移动 caster 用非周期帧标识，同时读取反射/主图/Y9，核对源旧图/新图关系和更新条件；再在冻结实际场景比较完整反射 on/off、湿地与 mip LOD、透明 premul、HDR>1、resize 和 GPU 时间。生产 uReflOn 只在 producer 与表面阴影路径通过后开启。

### 引擎补丁备选的真实范围

如果未来需要完整原生灯光支持 oblique，可在 XR/CameraData 内新增独立“未裁剪参考 projection”：actual oblique 用于绘制、逆投影和几何 frustum，普通参考 P 用于标准 near/far、cascade、light cull、cluster 分层及 LOD/sorting。`_get_unclipped_projection_for_view(...)` 只是可设计的新虚函数名，当前 API 没有这个方法。第一步诊断补丁可仅把 directional cascade 的输入换为原 P，验证阴影空间和强度恢复；正式补丁还须同时审查 CPU cluster 与 GPU cluster_z 的共同 far，以及 RenderSceneDataRD 暴露的 near/far。

相关入口为 [light cull / geometry frustum / directional shadow](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L3301-L3387)、[scene 数据构建](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp#L1371-L1399)、[cluster.begin](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L1652)、[CPU cluster far](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/cluster_builder_rd.cpp#L415-L429)。该补丁涉及 XRInterface/Extension 绑定、CameraData、cull、scene data、Forward+ 与回归测试，不是单个 near/far clamp。并且修好原生 cascade 仍不等于原固定图 jM PCSS。对当前完整复刻目标，优先固定源太阳方案更直接。

## 水平反射实机失败与 reference projection 补丁

父代理随后已把原太阳接到 138 个 Standard 材质、254 个相关对象，并接入 [planar_reflection.gd](../scripts/planar_reflection.gd)，按 reflection→sun→world 注册 viewport。真实游戏初始 pitch=0 时发生 `Condition !res create_frustum_points`，位置为 `rendering_light_culler.cpp:682`。当前反射仅在 `--game --planar-experiment` 下启用；默认游戏继续保留原太阳迁移，不默认进入报错反射路径。这不是将普通投影当成完成，也不撤销前面的原固定太阳方案。

### 两个故障来自不同内部假设

水平视线令本例 oblique 的 `P[2][2]=1`，标准 `get_z_near()` 分母为零；这是 near/far 提取失败。**本次 light culler 的报错不是先提取 inf 再使用它**：`prepare_camera()` 直接从 actual projection 提取六个平面，然后 `create_frustum_points()` 按固定的八组三平面交点构造有限八角锥，其中一组交点不可解，触发第 682 行错误。其前面没有 `get_z_near()` 调用。两者是同一 oblique 矩阵违反不同标准投影假设的症状。[投影保存及平面提取](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/rendering_light_culler.cpp#L627-L633)、[八组交点及错误](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/rendering_light_culler.cpp#L661-L682)、[near/far 公式](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/core/math/projection.cpp#L404-L415)。

`_render_scene()` 当前无条件调用 `prepare_camera()`，且没有处理其返回值；移除 native sun 也不会跳过这次准备。仅压掉 ERROR 或将求交失败的角点填零，会使 light culler 保留不完整数据，不能当修复。[调用点](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_scene_cull.cpp#L3297-L3301)。之前俯仰非零的 probe 没覆盖这个退化位置，其通过范围应保持原样，不扩大成“XR 任意斜投影完整支持”。

### 最小隔离实验：只给 light culler 一份正常参考投影

这个实验可以只修改引擎 `renderer_scene_cull.h/.cpp` 两个文件，不新增公开 API，不改游戏的 actual projection。建议只对当前具名 Saltline mono XR 接口和显式实验开关启用。

1. 在 `_render_scene()` 最后追加 `const Projection *p_light_culling_projection = nullptr`。默认值只写 header。原最后参数是 `RenderingServerTypes::RenderInfo *r_render_info`，其余调用保留默认 null。[声明](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_scene_cull.h#L1160)。
2. 在 `render_camera()` 的函数级作用域声明参考矩阵和空指针，确保存活到同步 `_render_scene()` 返回。XR mono 分支完成 actual projection 后，从 `projections[0]` 复制，只恢复 canonical GL 第三行；n/f 取 `camera->znear/zfar`，先验证有限且 `0<n<f`。当前脚本每帧把原 view.near/far 同步到反射 Camera3D，符合该实验前提。[XR 构造入口](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_scene_cull.cpp#L2744-L2769)。
3. 最后 `_render_scene()` 调用传入这个指针；函数中仅将 `light_culler->prepare_camera()` 的第二实参改为 override 或原 main_projection。[调用处](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_scene_cull.cpp#L2783)。

矩阵恢复示意，代码只用于指导实验：

```cpp
Projection light_cull_projection; // render_camera 函数作用域
const Projection *light_cull_override = nullptr;
// 在具名 Saltline mono XR 实验分支中，n/f 来自 Camera 原参数。
light_cull_projection = projections[0];
light_cull_projection.columns[0][2] = 0;
light_cull_projection.columns[1][2] = 0;
light_cull_projection.columns[2][2] = -(f + n) / (f - n);
light_cull_projection.columns[3][2] = -2 * f * n / (f - n);
light_cull_override = &light_cull_projection;
```

不能从 actual oblique 的 get_z_near/far 反推 n/f，也不能用反射 Camera3D 默认 FOV 和已取整 viewport 的 aspect 重建 XY。当前原投影复制自主相机，反射尺寸会取整，二者 aspect 不必相等。复制矩阵只修第三行能保留原 XY、非对称项和 perspective W 行。这个恢复方法限定 canonical perspective 且只有原 Uw 的第三行被替换，不能泛化成所有 XR 自定义投影的自动修复。

此实验保持 actual `CameraData.main_projection/view_projection`、几何 `get_projection_planes()`、depth、shader projection/inverse projection 和 HDR copy 不变。override 也会成为 light culler 内部后续 caster culling 保存的 camera_projection；原生 cascade setup、RD cluster 与排序仍然使用 actual。验收只能声明“light culler 有限角点假设导致的报错已被隔离或排除”，不能宣称整个 Forward+ 已支持 oblique。

### 完整方案：同一帧两份投影与一致的深度分段

后续应把 reference 从局部指针提升为显式相机数据。推荐在 CameraData 中保存 `has_reference_projection`、`reference_projection` 与 reference n/f；未 opt-in 的普通相机和现有 XR 保持原路径。当前源接口可以继续受控恢复原 P；更通用且便于维护的方式是新增可选 XR virtual，让脚本同时发布 actual P、原始 reference P、n/f。这个 virtual 目前不存在，需要 XRInterface/Extension 绑定与文档变更。先只支持 mono，不能假定现有 stereo 合并 frustum 自动支持两份 oblique。

pose、actual/reference P、n/f、size 必须来自同一帧 snapshot。当前 [planar_xr_interface.gd](../scripts/planar_xr_interface.gd) 各 getter 分别加锁，扩展时应保证本帧读取的是同一份不可变快照，避免渲染线程跨 publish 混用旧 pose 与新投影。

| 使用位置 | 应使用的数据 | 必须保留的行为 |
| --- | --- | --- |
| 几何 frustum、draw、depth prepass、透明 pass | actual oblique | 原 y=-.01 裁剪及实际 depth 分布 |
| shader PROJECTION/INV_PROJECTION、Compositor getter | actual oblique，按现有路径做一次 depth correction | 深度恢复必须用实际完整逆矩阵 |
| light culler 的有限角点体积 | 有界且保守的 reference P | 不因 clip plane 退化而漏掉影响可见几何的灯 |
| native directional cascade 如仍启用 | reference P 与对应有限范围 | 此项仍不代替原固定太阳 PCSS |
| cluster 体积 raster、near/far 分类、排序深度分组 | reference P / reference n/f | 所有 range 有限且有一致含义 |
| GPU cluster_z 查询 | 和 cluster 建表完全相同的 far | vertex 与 fragment 两条路径都一致 |

当前必须同步的实际源码位置：

- `CameraData::set_camera/set_multiview_camera` 要初始化或重置新字段，避免上一帧 opt-in 状态泄漏；普通、shadow/probe 相机的默认行为保持原样。[CameraData](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_render.h#L305-L322)。
- `RendererSceneRenderRD::render_scene()` 保留 cam_projection 为 actual，将 reference 传到 RenderSceneDataRD，scene scalar z_near/z_far 与 LOD 改用明确 reference 数据。[场景数据](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp#L1371-L1404)。不要全局覆写 cam_projection 来“顺带修好”这些值。
- `current_cluster_builder->begin()` 改用 reference P；ClusterBuilderRD 内部的 get_z_near/get_z_far 与 `adjust_perspective_znear(.0001)` 都必须基于 reference。建议把相同的有限 n/f 显式传入，避免一处使用原 n/f、另一处从 float32 矩阵反解后出现不同范围。普通 P 的名义 far=900，反解已测为约 900.266，不能假设两者完全相等。[begin 调用](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L1652)、[begin 内容](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/cluster_builder_rd.cpp#L415-L429)。
- cluster 建表设置 `state.inv_z_far=1/z_far`；shader 用 `(-viewZ/far)*32` 查表。必须让 CPU 建表参数、cluster raster shader、scene UBO 的 far 完全同源；只改 begin 或只改 scene_data.z_far 都会出现深度分箱不一致。[建表 far](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/cluster_builder_rd.cpp#L451-L455)、[vertex cluster_z](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L553)、[fragment cluster_z](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1546)。现有算法用 view-space z 分箱，不需要把 actual oblique depth 冒充普通透视 depth。
- `_fill_render_list()` 仍直接从 cam_projection 读取 near/far，必须改用同一 reference range；否则水平 near=inf 会污染 z_max 和 depth_layer。另一个 LOD 读取也需统一审查。[排序范围](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L935-L937)、[LOD](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L1546)。

reference 是灯光/分组的保守计算范围，不是 actual depth 的另一种解码公式。原 oblique 改变 near 与 far 平面的几何关系，普通原 P 不一定在任意姿态下包住它全部有效区域。当前 Saltline 近处 clip plane、高度门限与场景边界需测明；如需扩大 reference n/f 来覆盖可见几何和灯体积，应同时扩大所有 cluster 分段数据，actual clipping 仍不变。几何深度恢复继续乘 actual inverse projection，不能因为 scalar n/f 有效就重新启用假定普通透视的两标量解码。

这一完整方案指当前 mono planar 所用的 Forward+ 路径。反射已关闭 SSAO/SSIL/SSR、TAA；原作也不在反射运行主 post。若日后开启 native DoF、volumetric fog、occlusion culling、stereo 或其他依赖 projection 的功能，需另审其投影假设，不能凭这次 patch 宣称所有 renderer 功能已支持 arbitrary projection。

### 隔离构建可行性与交付边界

官方完整 commit 为 `ed1daf0bf001b61586d9930840f2f1394092c079`，[源码树](https://github.com/godotengine/godot/tree/ed1daf0bf001b61586d9930840f2f1394092c079)。父代理本轮已取得本地完整源码 `saltline-godot/engine/.build/godot-ed1daf0bf/`，其中 version.py 为 4.7.2 stable。不要误用 workspace 内的 godot-cpp 绑定库代替引擎源码。

只读检查的主机条件为 GCC 15.3.1、24 逻辑线程、约 19 GiB 可用内存，workspace 约 84 GiB 余量；系统 SCons/clang 不存在，Python 当前有 zstandard，独立 venv 不一定继承。8 个并发、无 LTO、无 debug symbols 的 template_debug 构建可作为本机隔离 GPU probe；本轮顾问没有执行构建，是否编译/链接成功仍以父代理日志为准。

本版默认 `use_sowrap=true` 与内置第三方库，许多 xcursor/alsa/pulse 等 pkg-config 缺项不直接意味着构建受阻；Vulkan 默认 volk 路径也无需外部 Vulkan pkg-config。Wayland scanner 当前缺失，可用 `wayland=no` 做 X11/XWayland 的 Vulkan 测试。`g++ -print-file-name=libstdc++.a` 返回裸文件名，静态 libstdc++ 未找到，本机隔离构建可加 `use_static_cpp=no`，不必为此先改系统依赖。[本 commit Linux 构建选项与依赖条件](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/platform/linuxbsd/detect.py)、[官方构建说明](https://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_linuxbsd.html)。

示例构建参数为 `platform=linuxbsd target=template_debug arch=x86_64 -j8 lto=none debug_symbols=no use_static_cpp=no wayland=no`，通过局部 venv 的 scons 调用，保留 Vulkan、RD、XR 和 GDScript。所有 shell 命令仍按 workspace 规则加 `rtk proxy`。二进制直接用完整路径启动，不覆盖 `~/.local/bin/godot`，不安装为默认模板。保存上游 SHA、补丁、构建参数与二进制 SHA；本机 Fedora 动态链接产物不作为跨发行版或 Windows 的交付证明。

### 补丁验收不能只看 ERROR 消失

先对两文件实验补丁检查 pitch=0、±极小角、向上/向下、roll、相机高度 .03 门限、窗口 resize；用原实际 oblique 矩阵和上下平面标记证明裁剪未被换回普通投影，并验证非 XR 主图逐字节不变。记录 prepare_camera 成功与 finite reference 值，actual P 必须仍是原矩阵。

完整补丁再使用深度跨 32 个 cluster 分箱的彩色 omni/spot 探针。far=900 时边界间隔 28.125，在边界两侧、近相机、远处、屏幕 tile 边缘放灯与可见接收面；覆盖透明物、reflection probe/decal 如实际使用。之前只覆盖 0–40 的灯光探针不足以证明整段范围一致。验证 CPU/GPU 分箱同源、没有因 reference 体积漏光、排序没有 inf/NaN，并保留旧 probe 与默认主场景回归。最后才进入实际源太阳 PCSS、反射 HDR/mip/RP 组合验收。通过 light-culler-only 实验不自动开启默认反射。

### 本轮选定的完整局部补丁

父代理决定第一轮构建即带完整 reference 数据链，保留前述两文件方案作为可单独启用的诊断设计。此次不新增 XR 公开 API：只在 `view_count==1` 且接口名为 `SaltlinePlanarProjectionProbe` 时，按本项目既定协议恢复 canonical perspective 深度行。CameraData 与 RenderSceneDataRD 各有 `has_reference_projection=false` 和 reference 矩阵，getter 返回 `const Projection&`，有 flag 时取 reference，否则取 actual。该局部 opt-in 可以保持其他相机、普通 XR 与未参与的渲染路径不变；可复用的 arbitrary-projection API 仍是另一项工程。

具体审查结论如下：

- CameraData 的 `set_camera()` 和 `set_multiview_camera()` 都应重置 flag，随后才在受控 mono 分支启用。RenderSceneDataRD 的字段默认 false，主场景构造时从本帧 CameraData 复制 flag/reference。getter 不能返回临时矩阵的引用。
- sort 使用 `get_reference_projection().get_z_near/get_z_far()`，不要改成无条件使用 `scene_data.z_near/z_far`。`_render_shadow_append()` 原来显式 scalar near=0、far=p_zfar，而 material/UV2/SDFGI 路径有些 scalar 留默认 0；用 getter 的 actual fallback 才保留其既有排序语义。
- 已检查其他构造点：Forward+ `_render_shadow_append` 原始 2809 行、`_render_particle_collider_heightfield` 2914、`_render_material` 2962、`_render_uv2` 3024、`_render_sdfgi` 3104。它们不应自动继承主相机 reference，保持默认 flag=false；shadow 自身的 projection、p_zfar、LOD 等仍按原代码设置。[shadow 构造](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L2809-L2824)、[其他 pass](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L2914-L3120)。
- 局部灯 shadow-atlas coverage 也用 near 与 viewport_half_extents，需要两者一起换 reference。它不是前面的 directional cascade 调用，不能漏掉。[coverage](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L3511-L3518)。
- 第一轮可以让 scene scalar n/f 和 cluster.begin 都从同一 reference 矩阵解码，已经能保证完全一致，无需再加独立显式 far 参数。不能一边用显式 900、一边用 float32 矩阵反解的约 900.266。分箱探针应使用实际共同 far 计算边界。
- prev_cam_projection、prev_view_projection、UBO 实际 projection/inverse 与 Compositor getter 继续用 actual。reference 仅为有限范围计算服务，不能替换前后帧重投影矩阵。
- CPU occlusion 在 `_scene_cull()` 仍会从 `cull_data.camera_matrix` 取 near，并把同一实际矩阵传入遮挡查询；不要为了去掉 inf 将这个指针整体换 reference。当前反射 viewport 不启用 occlusion，因此该路径不参与结果；如将来启用，buffer_update 与 is_occluded 必须一起审查，不能只改 near 标量。[occlusion 数据路径](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L2909-L2927)。

构建可给 `Engine.get_version_info().status` 加 `saltline-oblique` 后缀作为可检测标记。游戏启动时只有匹配这个局部补丁协议的引擎才允许开启反射实验，stock 引擎保留默认关闭；标记证明使用了指定构建，不代替渲染验证。最终证据仍应保存完整上游 SHA、具体 patch 与 binary SHA，而不是只记录 status 字符串。
