# 原作 post 与 Godot HDR 合成审查

日期：2026-11-15。审查运行环境为 Godot 4.7.2，官方构建提交 `ed1daf0bf`，Forward+ / NVIDIA Vulkan。本文记录架构建议和待验证条件，不代表下述各 pass 已经实现。审查期间只修改本文档。

建议将原 `tk` 作为唯一的场景色调与 grade pass。世界与武器先在线性 HDR 中合成，再应用原曝光、ACES/AgX、grade、受伤和淡出公式。已经经过 Godot Filmic 的画面丢失了原 HDR 输入关系，无法通过后叠颜色准确恢复。

优先方案是在 `game_mode` 中使用独立的 HDR world、weapon 和 scene viewport，根 viewport 保持 SDR，让现有 UI 继续使用原来的合成空间。根 viewport 全局开启 HDR 是备选方案。

## 来源与原顺序

原作来源为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。以下行号对应本次读取的提取文件。

| 内容 | 原作行号 | 审查结论 |
| --- | --- | --- |
| `sv` / `slExposure` | 35625–35628 | 手动曝光乘自适应因子；`tAdapt.r` 是适应亮度 |
| `j9` 降采样 | 35800–35824 | 13 个采样点；首级 partial Karis，后续普通加权 |
| `K9` 升采样 | 35825–35832 | 9 个采样点，与同级 high 图按 `uMix` 混合 |
| `tk` grade | 35891–35997 | HDR 采样、CA、ADS、bloom/光学项、曝光、曲线、grade、受伤、fade、sRGB 编码 |
| `nk` final | 35998–36029 | 在 sRGB 数值域进行 FXAA、锐化、颗粒、抖动 |
| 原默认参数 | 36083–36112 | `key=.12`，`agxMix=.25`，`lookPower=1.18`，`lookSat=1.22`，`ca=.0013`，`vignette=.3` |
| 中间 render targets | 36050–36142 | HDR 场景和 down/up 使用 HalfFloat；`ldr` 使用 UnsignedByte |
| `tk.tBlur` 绑定 | 36277 | 指向 `y.down[1]`，不是 Gaussian blur |
| down 尺寸 | 36339–36370 | 首级 `max(4, ceil(W/2))`，第二级再右移一位，至少 2 |
| down/up 每帧执行 | 36490–36515 | 原实现随 bloom 开关执行，输入来自原 scene/motion 输出 |
| 自适应更新 | 36529–36550 | 前两帧 rate 为 1，直接采用本帧测光结果 |
| grade 与 final 调用 | 36553–36583 | `tk → y.ldr`，随后 `nk → 窗口` |

`tk` 不是原作最后一道 pass。第一阶段完成 `tk` 后，仍应记录 `nk`、眼适应和缺失光学输入的状态。

## 线性 HDR 与最终 gamma

Godot 的 HDR 2D 使用线性 HDR framebuffer，挂接屏幕时才应用输出传递函数。`get_texture()` 返回的 HDR 图也保持线性编码。见 [Viewport.use_hdr_2d 官方说明](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-use-hdr-2d)。

对应运行版本的源码进一步确认了两个不同阶段：

- [renderer_scene_render_rd.cpp，654–677](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp#L654-L677) 在 HDR 2D 下关闭 3D 到 sRGB 的转换，但仍读取 Environment 的 tonemapper 和 exposure。
- [tonemap.glsl，223–226](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/effects/tonemap.glsl#L223-L226) 的 LINEAR 分支直接返回输入；[779–815](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/effects/tonemap.glsl#L779-L815) 显示曝光先于该分支。
- [blit.glsl，142–175](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/blit.glsl#L142-L175) 在最终输出时，根据目标窗口颜色空间处理 linear/sRGB 转换和可选抖动。

因此，优先方案中的 `world_port`、武器 `view_port`、纯 2D 合成 `scene_port` 和 down 纹理目标启用 `use_hdr_2d=true`。根 viewport 保持 `use_hdr_2d=false`。世界 Environment 与武器相机的独立 Environment 都设为 LINEAR、exposure 1，并关闭 Godot glow、自动曝光和额外色彩调整。武器 Environment 是 `duplicate()` 得到的资源，不能依赖之后修改世界 Environment 自动同步它。

保留 Godot SSAO 是阶段性的外观选择；它不等价于原 AO pass，验收记录中应继续保留这一差异。

优先方案直接将原编码结果写入 SDR root：

```text
world_port：线性 HDR 世界，camera mask 1
weapon view_port：透明线性 HDR 武器，camera mask 2
  → scene_port：world 底图 + weapon 预乘合成
  → down0 → down1
  → root CanvasLayer 1 的 tk，采 scene_port 与 down1
  → 原 toSRGB，alpha = 1，blend_disabled
  → SDR root 显示 → HUD CanvasLayer 20
```

此时 `tk` 的颜色已经是 sRGB 数值，不再执行 `sRGB_to_linear`。输入的 `tScene/tBlur` 是自定义 sampler，按数据直接读取线性 HDR，不经过 root 的 screen texture。`scene_port` 设为 `disable_3d=true`，先画不透明 world TextureRect，再用预乘材质画 weapon TextureRect。

备选的 root HDR 方案使用以下适配：

```text
线性 HDR world + weapon
  → 原 tk，含原 toSRGB
  → sRGB_to_linear
  → HDR Canvas，alpha = 1
  → Godot 最终窗口输出转换
```

在 SDR 窗口，备选链使原 `toSRGB` 的编码结果只显示一次。仅迁移 `tk` 时，也可直接返回其 `toSRGB` 之前已 clamp 的 display-linear 值；保留原函数再解码更方便逐项核对来源。两种 viewport 架构都必须避免再次套用 Godot Filmic/ACES。

HDR 2D 不意味着改用 Rec.2020 工作色域。输入继续按 linear sRGB/Rec.709 理解；原 AgX 内部已经包含 sRGB 与 Rec.2020 矩阵，不应在外部重复转换。这里复刻的是原 SDR 输出。若实际窗口启用了 HDR 输出，应单独固定窗口模式和参考白再做截图对比。

屏幕 HDR 纹理和 HDR ViewportTexture 均按线性数据读取，不加 `source_color`。普通 sRGB 图像纹理仍按颜色输入处理。官方说明区分了 HDR Canvas 中需要解码的颜色纹理，见 [shading_language.rst](https://github.com/godotengine/godot-docs/blob/master/tutorials/shaders/shader_reference/shading_language.rst)。

## 武器预乘 alpha 与 grade 输出 alpha

目前 [viewmodel_composite.gdshader](../shaders/viewmodel_composite.gdshader) 使用 `blend_premul_alpha` 并直接输出采样值。迁移后应保持“线性预乘 RGB + coverage alpha”契约，合成公式为：

```text
scene.rgb = weapon.rgb_premultiplied + world.rgb × (1 − weapon.a)
```

不要再次乘 alpha，也不要在合成前对预乘 RGB 单独做 gamma 或色调曲线。非线性操作会破坏边缘覆盖关系，最终 grade 应在世界与武器合成之后执行。

这项契约仍需用 HDR 实际像素验证，不能仅凭旧 LDR 外观推断。检查透明清屏像素为零预乘 RGB，检查 MSAA 边缘和枪口加法效果。可用半透明线性红色 `rgb=(2,0,0), alpha=.5` 覆盖蓝色背景 `(0,0,1)`；预乘源应读到 `(1,0,0,.5)`，合成应为 `(1,0,.5)`。

`tk` 原输出的 alpha 是编码后 RGB 的亮度代理，供 `nk` FXAA 使用，并不表示透明度。直接写 root Canvas 时必须 `blend_disabled`、`COLOR.a=1`。若把原 alpha 当透明度混合，会让暗部漏出未处理的场景。

未来独立 `tk → nk` 中间纹理应保存原亮度 alpha，并关闭中间写入的混合；最终显示的 alpha 才固定为 1。

## 层顺序和屏幕复制

优先方案用 root CanvasLayer 1 显示 `tk` 输出，HUD CanvasLayer 20 继续随后绘制。GameUI 不再创建 Layer 3 的 `flow_post`，而是引用同一 `tk` 材质更新 `uFade/uSaturation/uDamage/uLowHealth/uAds/uFlash`。避免把 fade 或 saturation 应用两次。原 Layer 1 的武器显示也应转入 `scene_port`，防止重复绘制武器。现有 CanvasLayer 2 调试文字将位于 post 之后，应检查 game_mode 下的显示状态。

CanvasItem 首次读屏会生成 backbuffer，后续读屏节点不一定重抓之前 pass 的输出。多个 post pass 应使用明确的 BackBufferCopy 或独立输入纹理，避免默认认为第二个 pass 会读到第一个 pass。见 [Godot screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html#behind-the-scenes)。

这里还存在一个实现约束：子 SubViewport 的 `hint_screen_texture` 只读自己的画布。若子 viewport 采根 viewport 的输出，而根又把该子 viewport 当 `tBlur` 输入，便产生循环依赖。不能据此假定获得同一帧的完整场景；可能出现上一帧数据或错误的渲染顺序。此项是架构风险推断，尚未针对新实现实测。

独立 scene 方案建立明确的单向纹理依赖：

```text
world_port + weapon_port → scene HDR viewport：预乘合成
  ├─→ down0 → down1 → 后续 bloom 层
  ├─→ adapt ping-pong
  └─→ tk grade → nk final → root display → HUD
```

不要在同一帧让任一节点反向采样它的最终消费者。当前阶段在 SDR root 执行 `tk`；之后可将 `tk` 移到独立 LDR viewport，再由 root 执行 `nk`。

无环纹理关系还不足以保证同帧顺序。该版本 [renderer_viewport.cpp，90–124](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_viewport.cpp#L90-L124) 的排序依据是 viewport 父子关系和同级原注册顺序，没有遍历 shader sampler 建图。同级 viewport 应按生产者先于消费者的顺序创建并入树：world/weapon 两者顺序不限，随后 scene、down0、down1，最后 root 消费。另一种办法是将生产者设为消费者的子 viewport，利用子先父后的规则。不要仅依赖视觉上看似合理的 Node 名称顺序。

阶段一可使用 `UPDATE_ALWAYS`，避免可见性更新模式影响判断。用每帧交替颜色或编码帧号的输入检查 scene、down0、down1 和最终输出同帧一致，排除稳定截图难以发现的一帧延迟。

## Camera3D reparent 审查

只移动现有 camera 实例及其完整子树，继续复用 `source_scene.camera` 和 `source_nodes` 对象引用。先取得原 root 的 `World3D`，将 world 与 weapon viewport 都指向它，保持 `own_world_3d=false`，再执行 `camera.reparent(world_port, true)`。共享 World3D 允许 weapon 相机看到位于 world_port 子树中的武器实体，不需要再复制一套模型。

官方 [Camera3D 说明](https://docs.godotengine.org/en/stable/classes/class_camera3d.html#description) 指明相机会注册到最近的 viewport；[Node.reparent](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-reparent) 支持保留 Node3D 全局变换。迁移后仍应显式 `camera.make_current()`，并确认 world_port 的当前相机就是原 camera；武器相机在 weapon viewport 单独设为 current。

静态读取当前 `scene.json` 和代码得到以下结果：

- 原 camera 的父 Scene 矩阵为单位矩阵，当前 source_scene 和 main 也未设置额外变换。
- camera 子树有 105 个 source 节点，包含双臂和两个武器根节点；两个 skin mesh 的 Skeleton 都在该子树内，没有跨边界共享绑定。
- 所有武器动画轨道都在 camera 子树内，轨道不包含 camera 本身。迁移整棵子树能保留武器局部动画和骨架相对路径。
- `player.gd:116–128` 与 `169–173` 直接写 `camera.position/rotation`，把玩家世界状态当作相机局部变换。新父节点 SubViewport 不引入 Node3D 变换，符合现状假设；以后不要再给 camera 包裹非单位变换的 Node3D 而不调整这些写入。
- `game_flow.gd:109` 的标题相机仍使用同一个实例；射线、特效和 HUD 持有对象引用，未发现依赖旧 camera NodePath 的实现。
- 本次脚本搜索未发现 `get_camera_3d()`、AudioListener3D 或 AudioStreamPlayer3D 的调用。未来加入空间音频时，要明确监听 viewport；迁移后 root 不再拥有主 3D 相机。

迁移瞬间记录并比对 camera 的 `global_transform`，随后检查首个玩家更新、标题转场、瞄准、死亡和重试。`keep_global_transform=true` 只保证迁移瞬间，不替之后的局部坐标写入作保证。

world/weapon/scene 尺寸保持一致，root resize 时一起更新，随后重算 down 尺寸和 `uTexel/uAspect`。HUD 目前用 root 屏幕尺寸配合 camera 的 transform/FOV 计算投影；若 world_port 改用另一长宽比，必须增加坐标映射。迁移还应显式复制需要保留的 MSAA、3D scaling、TAA/AA 配置，不能假定新的 SubViewport 自动继承 root。

camera 下的武器 key light 会一起迁移，继续保持 `light_cull_mask=2`。世界与武器相机分别使用 mask 1 和 2。根 viewport 可停止 3D 绘制来避免重复开销，但保留承载 scene 节点的共享 World3D，不应为此删除或替换原世界。

仅在 game_mode 启用新路径时，预览模式可继续走原布局。销毁新 viewport 前要考虑 camera 与武器子树的生命周期；整个 main 统一销毁没有问题，单独重建 post 链则不能误删仍被 gameplay 持有的 camera。

## 缺失输入与阶段一参数

| 项目 | 阶段一处理 | 原因 |
| --- | --- | --- |
| `tBloom` | 绑定有效黑纹理，同时 `uBloom=0` | 原公式为 `mix(col,bloom,uBloom)`；只传黑而保留 `.065` 会使全图暗 6.5% |
| dirt | `uDirt=0`，绑定有效占位纹理 | 避免把缺失资源当作完整 lens dirt |
| streak | `uStreak=0`，绑定有效黑纹理 | 保留原函数及参数接口 |
| flare | `uFlare=0`，`tAdapt.g=0` | 原 flare 可计算，但缺少遮挡可见性输入 |
| exposure | `uAuto=0`、`uExposure=1` | 避免将静态占位解释为已实现眼适应 |
| `tAdapt` | 有效数据纹理 `(.12,0,0,1)` | `.12` 是原 `uKey`，不是已证实的原初始适应亮度 |
| ADS blur | 原两级 down 优先；mipmap 仅作标明的近似 | 原滤波核、分辨率和火花抑制均与 mipmap 不同 |

原 `uAuto=1` 时，自适应因子为 `clamp(pow(.12/max(adapt,1e-4),.85),.6,2)`。原前两帧直接用实测平均亮度；后续使用 `1-exp(-dt/1.5)`。阶段一固定曝光应在记录中写为“eye adaptation disabled”。

## ADS 两级 down 的精确实现要求

原 `tBlur=y.down[1]`。两次 pass 输入都是线性 HDR，采用线性采样、clamp-to-edge、关闭 mipmap，保留 HDR 存储。尺寸与采样步长必须按各自输入计算。

| pass | 输出尺寸 | `uTexel` | `uFirst` |
| --- | --- | --- | --- |
| down0 | `max(4,ceil(W/2)) × max(4,ceil(H/2))` | `(1/W,1/H)` | 1 |
| down1 | `max(2,down0.width >> 1) × max(2,down0.height >> 1)` | `(1/down0.width,1/down0.height)` | 0 |

每次 pass 读取 13 个点。以输入像素为单位，`a,b,c` 位于 `(-2,2),(0,2),(2,2)`，`d,e,f` 位于 `(-2,0),(0,0),(2,0)`，`g,h,i` 位于 `(-2,-2),(0,-2),(2,-2)`，`j,k,l,m` 位于 `(-1,1),(1,1),(-1,-1),(1,-1)`。每次采样先逐通道 clamp 到 `[0,400]`。

down0 先形成五个四点平均：`g0=(a+b+d+e)/4`、`g1=(b+c+e+f)/4`、`g2=(d+e+g+h)/4`、`g3=(e+f+h+i)/4`、`g4=(j+k+l+m)/4`。对每组应用 `kw(c)=1/(1+.08*luma(c))`；前四组权重各为 `.125*kw`，第五组为 `.5*kw`，最后加权求和并除以权重总和。这是原 partial Karis 处理。

down1 使用以下普通核：

```text
e × .125
+ (a+c+g+i) × .03125
+ (b+d+f+h) × .0625
+ (j+k+l+m) × .125
```

`tk` 再在线性 HDR 中按 `uAds*.75*smoothstep(.22,.85,r2)` 混入 down1。Gaussian、默认 mipmap 或直接增加屏幕采样 LOD 都不能声称是同一核。若暂用屏幕 LOD，需要带 mipmap 的 sampler filter，否则提高 LOD 不会产生预期模糊，见 [screen texture 说明](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html#screen-texture)。

## UV、`nk` 与中间编码

原 OpenGL `vUv` 和 `gl_FragCoord` 与 Godot 屏幕坐标的纵向约定不同。径向 CA、暗角与受伤边缘较对称，可能掩盖错误；flare 固定角度、太阳位置与 `nk` 像素噪声不会自动保持一致。

建议保留统一的原作 UV 定义，并在读取 Godot screen/viewport 纹理的适配函数中处理 y 方向。未来移植 `nk` 时也应明确像素中心坐标。用不对称上下色块、偏离中心的太阳位置验证，避免仅凭对称画面判断。

`nk` 的输入是原 RGBA8 `y.ldr`，其 RGB 是已编码的 sRGB 数值，alpha 是亮度代理。原 linear texture filtering 因此直接插值编码值。不能把已经存成 display-linear 的 HDR Canvas 纹理先进行线性插值、再 `toSRGB`，然后声称与原 `nk` 输入采样相同；转换与插值不交换。

完整迁移应保留一个专门的编码数据中间纹理，复刻 RGBA8 量化、sRGB 数值插值和亮度 alpha。可考虑独立的 LDR 2D grade SubViewport：关闭混合，shader 显式写入原 `tk` 输出；`nk` 用无 `source_color` 的自定义 sampler 读取其编码数据，而不是自动解码的颜色采样路径。该方案应置于前述无环 viewport 依赖图中，并单独做 GPU 验证。

之后 `nk` 保持原 sRGB 数值域运算，直接输出到优先方案的 SDR root，最终 alpha 为 1。只有采用备选 HDR root 时，最终写入前才执行 `sRGB_to_linear`。同时检查 Godot 自带 screen-space AA、FSR sharpen 与 debanding，防止重复应用；MSAA 属于几何抗锯齿，应按原渲染配置另行决定。

## 建议的最小验收

1. 先验证输入契约。用固定线性颜色 `.01、.18、.5、1、4、16`，在 grade 前读回 HDR 值，确认世界和武器均未提前 tone map、gamma 编码或截断。
2. 验证预乘合成。检查透明清屏、半透明标准色块、武器 MSAA 边缘、枪口和瞄具叠加，grade 前比对线性像素。
3. 用同一组受控纹理和 uniforms 执行原 Three `tk` 与 Godot `tk`。覆盖 `uDamage/uLowHealth/uAds/uFade` 的 0、中间值、1，以及亮暗和饱和高光；比较相同编码域，单独记录 HDR16F 读回误差。
4. 验证渲染顺序和相机迁移。用逐帧颜色验证多 viewport 同帧更新；记录 reparent 前后 transform，检查移动、ADS、标题、死亡、重试和窗口缩放。
5. 验证最终窗口图像。确认 HUD 在 grade 之后、fade 全黑、受伤边缘位置正确，并确认只有一次显示编码。优先方案 root 的截图仍是 SDR；离屏 HDR viewport 的 `get_image()` 则是线性数据，导出普通 PNG 前必须明确处理编码，不能混用两者的 RGB 数值。
6. 后续分别验收 down0/down1、眼适应、bloom/flare 和 `nk`。缺失或近似项继续留在交付边界中；原 `tk` 的一致性不能替代完整画面验收。


## 实施验证补充

最终采用独立HDR世界/武器/scene、SDR root显示方案。`post-pipeline-verification.json`用12帧交替红/绿背景及武器辐射(.2,.1,2)/alpha.25，证实scene与down1同帧且HDR蓝色2不被夹断。首次探针发现TextureRect默认EXPAND_KEEP_SIZE使缩小矩形保持输入纹理最小尺寸，只采到局部；改为EXPAND_IGNORE_SIZE后通过，最大残差0.001053。
