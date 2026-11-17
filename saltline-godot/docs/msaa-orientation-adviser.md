# MSAA 采样方向与镜像渲染相机审查

日期：2026-11-15。Godot 4.7.2 `ed1daf0bf`，Forward+ / NVIDIA Vulkan；原参考为 Three r180 / ANGLE SwiftShader Vulkan。本文只记录隔离实验和源码审查，不修改 main 或 shader，不表示镜像相机已经通过完整场景验收。

结论：**值得继续镜像相机的隔离实验。** 在这两个已测后端上，local-Y 反射再按行还原能修正 MSAA sample pattern 的垂直方向；它比从原方向中选一个位置不匹配的 sample 更接近原参考。但默认渲染链不能只加相机反射和两个 flip 就认为完成：双面材质的 FRONT_FACING/法线处理和 camera-facing billboard 有具体语义变化，必须先验证。

## 当前实际证据

| 文件 | 审查时内容 | SHA-256 |
| --- | --- | --- |
| [msaa-depth-reference.json](../assets/export/fixtures/msaa-depth-reference.json) | 原 MSAA4、165 case、D24，未使用 multisampled-render-to-texture 扩展 | `ca321e5ed5c82aa757b1863e2ed55f0bf6394518710c3c60fa58ceb0b9f75fc4` |
| [depth-samples-verification.json](../evidence/depth-samples-verification.json) | native 未镜像，4 sample 成功捕获，90 个部分覆盖像素 | `d97c1f394311db04db1e52672d33441a48549564fd5d8295710e49fef09cdf76` |
| [depth-samples-mirrored-verification.json](../evidence/depth-samples-mirrored-verification.json) | 镜像后 96 个部分覆盖像素；sample 0 对原深度仅剩 2/165 个差异 | `694a5b46ad0f5eace0528be9a2e28c4460011a1e244542adbf1ec564a14a8264` |

后续运行可能覆盖同名报告，上述 hash 固定本文所读快照。以绝对误差 `2e-6` 比较 mirrored sample 0，剩余 case 为 13（x，fraction=.3875）和 76（diag，fraction=.275）；两处 native coverage 也比原多一个 sample，因此不是单纯 R32F 深度误差。此时 sample 1/2/3 分别为 52/49/54 个深度不匹配。不能把报告内 `failures:[]` 当作“与原深度全等”：该字段当前只检查捕获样本数和受控深度值，跨后端差异来自逐 case 二次比较。

原 selected sample 的位置由扫边推断约为 bottom-origin `(.375,.125)`；native 实测四点为 `(.375,.875),(.875,.625),(.125,.375),(.625,.125)`。镜像图像后 `(x,y)→(x,1-y)`，native sample 0 对应 `(.375,.125)`，其余三个点也整体反射。这个几何关系解释了改善；原 selected index 的实际内部编号和边界 rasterization 行为仍以探针为准。

剩余两处应继续细扫原与 native 的 edge 坐标、覆盖和实际浮点顶点输入。候选原因包括子像素栅格化量化、边界填充规则或不同的最终 clip 坐标；目前没有证据唯一确定其中一个。不要靠更换深度容差、随 axis 选择 sample 或移动真实场景几何掩盖它们。

## Camera3D 是否会丢掉负 basis

不会自动丢掉纯反射。Camera3D 的 [get_camera_transform 路径](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/3d/camera_3d.cpp#L247-L258) 和 RenderingServer 的 [camera_set_transform](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L110-L114) 都调用 orthonormalized。其 [Basis::orthonormalize](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/basis.cpp#L52-L68) 是逐列 Gram–Schmidt，没有用叉积重建第三轴，也没有强制 det=+1，因此 `diag(1,-1,1)` 被保留。

应按 camera **local Y** 右乘反射：

```gdscript
var t = normal_camera.get_camera_transform()
t.basis = t.basis * Basis.from_scale(Vector3(1,-1,1))
render_camera.global_transform = t
```

不能左乘世界 Y 反射：那会改变玩家旋转后的朝向关系。不要经 Euler/Quaternion、`look_at()` 或“从 forward/up 重建正交右手 basis”走一遍，因为这些路径可能重建成 det=+1。probe 先禁用 physics interpolation；未来应在正常 rig 得到该帧最终 pose 后同步 proxy，避免 proxy 自己再插值或落后一帧。

CPU frustum 使用反射后的相机 transform，见 [renderer_scene_cull.cpp:3059](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_scene_cull.cpp#L3059)；平面通过 inverse-transpose 变换，见 [transform_3d.h](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/transform_3d.h#L178-L181)。这条路径没有把反射删除。仍应通过非对称、接近上下视锥边界的真实 mesh 检查 culling，不能仅用屏幕中央大 quad。

## 面剔除已支持，双面法线仍需单独处理

Forward+ 明确计算 `reverse_cull = camera_basis.determinant()<0`，并与物体自身 mirror 结合选择 cull variant；depth prepass、opaque、transparent 都收到该标志。[render_forward_clustered.cpp:1653](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L1653)、[363–368](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L363-L368)、[1922](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L1922)、[1995](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L1995)、[2174](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L2174)

因此不要再把全部材质的 cull_front/cull_back 交换一次。已有 probe 采用 unshaded、CULL_DISABLED，仅证明覆盖和深度，不能证明带光照材质正确。

有一条确定需要验证的源码路径：

- cull variant 只切换 raster cull mode，没有同时重定义 front-face；见 [scene_shader_forward_clustered.cpp:388–390](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L388-L390)、[463–470](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L463-L470)。
- `cull_disabled` 和 `cull_front` 开启 `DO_SIDE_CHECK`；见 [785–786](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L785-L786)。
- shader 在 `!gl_FrontFacing` 时先对插值 normal 取反；见 [scene_forward_clustered.glsl:1168–1174](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1168-L1174)。

相机反射会改变 raster winding，从而改变 gl_FrontFacing。由这三处实现可推断：对开启 side check 的材质，“可以被正确剔除/绘制”不等于“收到的 NORMAL 与原视图只差坐标反射”。当前多个 `source_material*.gdshader` 和 arms 依赖该输入，必须用双面法线可视化和单向光 probe 检查。

若实测确认额外的 normal 取反，应仅在受影响材质、镜像 view 的正确阶段补偿。不能全局给所有 NORMAL 乘 -1：默认 cull_back 路径、显式写入世界法线的 ground/sea、以及 shadow view 的情况不同。也不要直接把反射修正 uniform 无条件传播到所有阴影绘制 pass。优先在隔离 shader 中证明，再决定统一材质适配方式。

## VIEW、TBN、billboard 与现有 shader

纯反射矩阵 R 仍是正交矩阵；dot、长度、normalize 等在所有输入一致变换时保留关系。VIEW、LIGHT、NORMAL 和显式 T/B 一起变换本身不意味着 BRDF 必然出错。Godot 会对 normal/tangent/binormal 使用 model-view normal 路径，见 [scene shader:432–448](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L432-L448)。

不能仅看到 `cross()` 就统一补 determinant：`cross(Ra,Rb)=det(R)Rcross(a,b)`，而本策略还同时反射 raster Y，导致对应像素的 dFdy 变号。对当前 source_material 的导数 TBN，假定输入 normal 已正确，位置/UV 的 Y 导数与反射手性符号可以抵消。具体实现仍需 normal-map probe，但不能预先叠加任意 TBN 符号修复。arms 的 `armBump`、导数 normal 和微表面频率也要在实际 shader 上检查。

更直接的非等价点在 [lit_particle.gdshader](../shaders/lit_particle.gdshader) 与 [additive_particle.gdshader](../shaders/additive_particle.gdshader)：它们把 `INV_VIEW_MATRIX[1]` 当 camera up，并据此在世界空间生成朝相机的 quad。proxy 的 up 被取反后，生成的世界几何也随之反射；最终再 flip 图像，会使原本非对称的 billboard 贴图方向/旋转与原路径不同。这里应明确区分“用于采样方向的渲染 view”与“用于还原原 billboard 世界姿态的正常 rig right/up”。

现有朝相机分支还用 right/up 构造 `vT/vB`，因此只翻 UV 而不核对法线和粒子旋转不足以恢复原行为。轴向 streak、世界法线贴附粒子使用不同构造分支，不应一并取反。验证使用带箭头的非对称 atlas、非零旋转和非对称光照，不能用圆形白烟作为唯一判断。

其他需针对性验证的当前路径：

| 路径 | 审查判断与测试 |
| --- | --- |
| ground/sea 显式世界 normal→VIEW | 数学上可随 view 反射正确变换；用非对称光向核对，无条件 normal 补偿会破坏它 |
| sight_glass 的 view/right/up 点积 | 所有向量一致反射时点积保留；检查偏心观察、准星视差，不直接改轴 |
| dynamic_sky | 用同一世界射线的颜色验证；它自定义 POSITION，需确认只被镜像一次 |
| soft particles | SCREEN_UV 和当时的 depth 都应保持 native mirrored 域，直到 3D 绘制完成；不要把已还原深度塞回这个采样域 |
| AO/noise/SSAO/SSR | 基于屏幕坐标的旋转、dither 与 temporal history 未必反射对称；原 post 应在颜色和 depth 统一还原后运行 |
| TAA/FSR/motion vectors | 初始 probe 关闭；未来 vector 的 Y、jitter 和历史坐标必须有一致契约，不能只 flip RGB |

## 透明排序和阴影

纯 local-Y 反射不改变 camera origin 或 local Z。Forward+ perspective 排序深度使用相机到物体中心的距离；orthographic 使用相机 Z 对应的 near-plane 距离，见 [render_forward_clustered.cpp:839–868](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L839-L868)。因此同一批世界几何的这些排序键应保持不变；但 billboard 自己若改变世界顶点，最终透明交叠仍可能改变，必须独立检查。

不应反射世界、灯光或 shadow camera。渲染 proxy 只改变观察坐标；物体世界坐标、光照方向和 shadow-space 变换保持原值。相机视锥集合在行还原前后相同，因此 directional cascade 的覆盖区域在数学上不应改变，但这不是完整阴影实现已验证的证明。至少比较方向光 cascade 边界、薄片/双面 shadow caster、normal bias、移动相机时的阴影稳定性。尤其避免针对主 view 的法线补偿误作用于 light view。

## 若探针通过，生产 proxy 的边界

保留正常 main/source camera rig 和其武器、手臂、附着灯子树。不要直接反射该节点，否则子节点也继承反射，改变世界姿态；[Node3D global transform](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/3d/node_3d.cpp#L605-L609) 明确组合父子变换。当前 main 有多处把 `view_camera.global_transform=camera.global_transform`，不能只在一个更新分支插入反射。

创建独立且无 gameplay 子节点的 world/weapon render cameras，分别复制对应正常相机的最终 pose、FOV/投影、near/far、层、Environment 和 Compositor，再 local-Y 反射。若从 `get_camera_transform()` 复制已含 h/v offset 的 pose，proxy 的 h_offset/v_offset 应为 0，避免重复偏移。正常 camera 不再是 viewport 的 current camera，但仍供 player、HUD、solar projection、武器发射点和动画使用；检查依赖 `get_camera_3d()` 的代码，防止把镜像 proxy 误当作 gameplay camera。

输出契约建议为：

```text
正常 world/weapon rig：玩家、HUD、太阳投影、武器姿态
      ↓ 复制最终 pose 后 local-Y 反射
仅渲染的 world/weapon cameras
      ├─ 颜色纹理：在 scene 预乘合成入口各 flip_v 一次
      └─ 每 sample depth：捕获/组合时按行 flip_y 一次
              ↓
统一恢复为现有 native top-origin 的 scene/combined_depth
              ↓
q9 half-depth、AO、原 post：沿用既有坐标契约
```

颜色 flip 不改变 premultiplied alpha 数值；仍按既有 world + weapon 预乘合成。深度行翻转只改变像素行，sample index 0 继续表示 native index 0，其恢复后的物理位置已垂直反射；不要再把 index 0 换成 3。恢复后的 half-depth 继续使用已确认的偶数 `2y+1` / 奇数 `2y` 源行规则，不要因相机镜像再改一次。

## 进入默认链之前的最低证据

1. 细扫剩余 2 个 coverage 差异，记录它们的真实原因或保留明确边界；probe 的断言应包含跨后端 selected depth 比较。
2. 在 perspective、非对称相机旋转、奇偶尺寸和 resize 当帧复测 sample 位置及颜色/深度方向，保留非周期遮挡输入。
3. 开启 back/front/disabled 三种 cull 的单面与双面带光照 quad，检查 FRONT_FACING、输出 normal 和 normal map；再运行真实 source_material 与 arms。
4. 非对称 billboard atlas、旋转粒子、soft intersection、透明前后层、偏心瞄具和天空分别比较镜像前后还原图。
5. 世界与武器实际投影同步、阴影和 HUD/solar/unproject 坐标通过后，才讨论默认启用；其余仍保持隔离实验。

目前证据支持“镜像方向是更接近原采样位置的实现候选”，不支持“所有 Godot 材质和屏幕效果在反射后自动等价”。nearest sample 的近似也不能因此被包装成原作完全复刻；两条路径都应报告自己的实际误差与范围。
