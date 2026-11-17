# 原平面反射：相机与材质阶段

当前完成原 Uw 相机数学及 RP 地面混合公式，**默认真实场景反射尚未接入**。后续独立XR视口的几何斜裁剪与HDR拷贝探针已通过，但原生级联阴影失败，mip链随后已实现并通过原GPU对照。默认地面不展示新平面反射，不能将本阶段称为完整平面反射完成。

## 原作行为

直接来源为 `artifact-rendering-study/source/extracted/bundle-1.js` 的 Uw（56155附近）、RP（56045附近）与 Vg（56750附近）。Uw 每帧按 y=0 镜像相机位置、forward 和 up，再以 lookAt 构造右手相机；采样矩阵为 oblique 修改之前的 B×P×V。随后将世界 y=-.01 的平面转换到 view space，写入原 oblique projection。两种矩阵必须分开。high 反射尺寸为实际 render resolution×.5，宽度取16倍数、高度取8倍数，最小64×32。相机 y<.03 或质量比例<=0关闭。输入 RGBA16F、无MSAA、线性 mip 过滤。原 pass 隐藏 apron、sea、rain、splash，skirt仍保留。

RP 使用地面世界位置投影采样，按地面法线斜率和相机距离扭曲 UV；粗糙度、积水和浸湿控制 LOD，三次纵向拉伸采样，HDR 上限48，再以 puddle/soak 权重替换环境镜面 radiance。不是直接加自发光。

## 已完成与验证

- `tools/planar_reference.cjs` 直接截取并执行原 Uw，使用原 bundle Three r180 类，模拟 renderWorld 只用于检查被排除节点在pass内隐藏及结束后恢复。8组覆盖滚转、不同FOV、非整齐分辨率、最小分辨率、质量关闭和高度边界。
- `scripts/planar_camera.gd` 对照上述实际原函数。镜像 world 最大分量误差1.2e-7，preclip sampling最大3.82e-6，oblique projection最大4.20e-5；绝对阈值1e-4未放宽。分辨率、LOD和启用门控全部通过。见 `evidence/planar-camera-verification.json`。
- 初次对照发现 `(1+Pzz)/Pwz` 在 float32 projection 上发生消减误差，掠射时放大至 .000343。改用源 perspective 恒等式 `1/far`，其余 plane scaling 用标量 float64，保留原公式语义后通过原定阈值。y=.03 边界与引擎 Vector3 存储精度保持一致。
- `tools/port_ground_reflection.py` 将原 RP 写入 ground.gdshader，Godot `RADIANCE=vec4(pr,pw)` 对应环境镜面混合。原材质最终有效roughness与Godot内部BRDF的差异仍待全场景校准。
- `tools/verify_planar_radiance.gd` 使用真实地面 shader、合成 HDR 绿色 mip 纹理和黑色天空。红色 unshaded control 证明几何可见。关闭RP输出黑，开启输出(.1451,1,.2118)，证明实际PBR反射贡献。viewport输出是LDR，绿色1发生clamp；这不是HDR链数值验收。见 `evidence/planar-radiance-verification.json`。

## 黑色反射探针的根因

Astra 对照引擎源码发现：Godot默认 specular occlusion 会在自定义RADIANCE混合后，按 ambient_light 亮度×8限幅压低间接镜面。黑色环境使其为0，即使注入高亮反射仍归零。最小shader区分实验确认关闭 `specular_occlusion_disabled` 对应的额外门控后贡献恢复。生产ground已设置该render_mode；F0/Fresnel/DFG仍由原生PBR计算，没有改成EMISSION。此选择避免原作RP不存在的亮度门控；完整场景能量仍待验证。

官方 RADIANCE 行为说明：[Godot spatial shader reference](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html)。引擎准确源码路径与接入顾问记录见 `planar-adviser.md`。

导出快照中的 uReflOn=1 和当时 render-target 不是实时生产者。source_scene 的地面初始化现在强制 uReflOn=0，等待真实反射图准备好后再开启，防止零默认矩阵采到旧图。

## 下一步

先验证 mono XRInterfaceExtension 对独立 reflection SubViewport 提供任意投影的路径，检查真实斜裁剪、CPU frustum、方向阴影与clustered点光，不将单纯投影成功称为完整光照兼容。随后接线性HDR拷贝和逐mip生成、原节点排除、真实动态反射与地面开关录像。Astra已明确 oblique 投影会触及引擎 get_z_near/get_z_far 的标准投影假设，这仍是待验证风险，不是已确认可直接上线的方案。

## XR 任意投影与 HDR 实机探针

`scripts/planar_xr_interface.gd` 是实验性 mono XRInterfaceExtension，只用于独立受控 viewport。设置原 reflected world 和 canonical GL projection，Godot负责后续 Vulkan/reverseZ。注册前拒绝替换已初始化的真实XR接口，退出恢复旧primary并uninitialize/remove。getter用mutex访问发布的pose/projection/size快照；这仅是受控探针，生产化仍需更严格的逐帧快照发布/重入/关闭流程。

`tools/verify_planar_xr.gd` 实际渲染原斜投影：未裁剪red112/green103/blue70像素，裁剪后red0、green103、blue70；恢复后与起始一致。非XR主viewport三次原始bytes一致。18次投影回调，几何和隔离检查零失败。

`scripts/reflection_hdr_bridge.gd` 在该XR viewport POST_TRANSPARENT取得resolved color，GPU复制到独立RGBA16F。沿用已验证的帧前texture发布与回调内只写生命周期；测试green4读回仍为4.0、ready=true，证明当前接口能保持线性HDR。后续版本已加入mip链，见下节；生产运行不读回CPU。证据 `evidence/planar-xr-verification.json`。反射视口尚未接原全场景、最终地面或主游戏。

## 光照验证中发现的级联问题（未修复）

`tools/verify_planar_xr_lighting.gd` 对相同镜像pose，分别使用普通GL投影和原斜裁剪投影，绘制深度0..40的实际PBR方块、墙和悬空遮挡物。所有几何在裁剪面之上，原反射隐藏的地板不加入fixture，以免从地面下观察时被它挡住。

点光、聚光、无阴影太阳的两种投影图逐像素完全相同，分别有8712/8036/8329个亮像素。初版没有实际阴影接收贡献，不能用于级联验收；加入墙与悬空遮挡物、确认普通投影有434个阴影暗化像素后，斜投影产生434个不一致像素，最大差.7960784。测试保持失败退出，没有关闭阴影或放宽阈值让它通过。证据 `evidence/planar-xr-lighting-verification.json` 和同名log。

同一输入的 `Projection.get_z_near/far`：普通=.079999998/900.265991，斜投影=10.147048/-2.701201。负far与顾问指出的引擎标准透视假设吻合；具体代码路径和修复选择继续由Astra核查，尚不能将全部差异归到某一行源码，更不能宣称整条Forward+已支持原斜投影。

后续必须保留原有太阳遮挡语义，修复投影/cascade数据或使用经验证的原固定太阳阴影输入参与surface lighting；不能把关闭阴影当成复刻完成。可以独立继续GPU mip链开发。默认反射仍关闭。

## RGBA16F 反射 mip 链

`reflection_hdr_bridge.gd` 现分配完整RGBA16F mip资源，base level由实际reflection POST_TRANSPARENT复制；每一级GPU compute只读上一级、写本级，逐dispatch交给RenderingDevice处理依赖。所有层共享同一底层texture的不同mip view，输出Texture2DRD在帧前发布，回调内不换RID。释放父texture时同时销毁子view；额外mip shader与原copy shader显式释放。只有fixture上传测试开启CAN_UPDATE，生产不用CPU上传或读回。

`tools/reflection_mip_reference.html` 调用原Three RGBA16F WebGLRenderTarget的实际generateMipmaps，并用textureLod在每级中心采样读回。4种原对齐尺寸80×48、64×40、96×56、640×360，包括high实际尺寸及中间奇数层45→22、11→5、5→2。经参考验证，原后端的每级行为等价于目标中心映射的双线性采样，再RGBA16F存储。不是所有层都用简单2×2块平均。

原生compute使用明确4texelFetch插值与half RNE存储，避免后端半精度写入差异。`tools/verify_reflection_mips.gd` 检查1291416通道，预设绝对阈值.002未放宽，零失败；所有生成层（level>=1）最大差为0，base上传/取样转换最大差5.44e-5。原图为非对称高对比HDR图案，此结论不等于任意硬件所有图案位一致。证据 `evidence/reflection-mip-verification.json`。

实际XR反射捕获回归也通过：green4保持4.0，256×128目标生成8个额外mip，末级green=.01257324非零；几何斜裁剪和非XR主视口byte比较仍通过。证据 `evidence/planar-xr-verification.json`、`planar-xr-mips.log`。

共享mip view使用官方公开API：[RenderingDevice.texture_create_shared_from_slice](https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html#class-renderingdevice-method-texture-create-shared-from-slice)。尚未验证动态真实场景producer顺序、resize/停用重入、性能和最终地面显示。

## 固定源太阳替代路径已通过受控场景

原Lambert/GGX与原jM PCSS独立GPU对照通过后，固定4096 source caster图已在受控墙/悬空物反射场景接入：752像素有真实阴影贡献，normalGL与oblique有/无阴影均逐像素一致。原生cascade失败仍保留，不改写成成功。当前是专用surface probe，默认原场景材质尚未替换；详见 [source-sun.md](source-sun.md)。

## 全场景接入中的水平视角限制与隔离引擎构建

新增 `scripts/planar_reflection.gd` 已建立真实场景反射viewport、原四对象排除、HDR mip消费和生命周期，但尚未默认开启。水平初始视角在stock引擎触发 `rendering_light_culler.cpp:create_frustum_points` 三平面求交失败；此前有俯仰的探针没有覆盖它。失败原始日志见 `evidence/planar-integration-stock-failure.log`，不标为通过。

默认路径现保持反射off，仅 `--game --planar-experiment` 尝试；且需engine status包含saltline_oblique。不会以普通投影替换原斜裁剪。与官方同提交的隔离引擎补丁正在构建，保留actual斜投影绘制，另给有限light bounds/cluster/阴影/sort提供reference；详见 [engine/README.md](../engine/README.md)。这仍需GPU验收，不能从源码设计推断已修复。

四个排除节点为apron、sea、rain、rainSplash，原world bit1移至main-only bit4；main camera mask5，reflection1，weapon2。quaySkirt仍保留原world层。local light pool mask从3扩为7以继续影响这些主画面表面；视图key mask2和专用nativeSun layer20不变。实际顺序和反射贡献尚未验证。

## 隔离构建与真实反射已通过首轮

7文件局部补丁已编译并在真实GPU运行；原绘制projection仍为oblique，Compositor返回的actual near提取仍可为inf（这是原矩阵，不将其改普通投影），灯光边界、cluster与scene scalar使用finite canonical reference。新构建水平marker/HDR/mip、点光/spot/native cascade、原固定PCSS与俯仰cascade复测均通过，详见 [engine/README.md](../engine/README.md)。不是关闭阴影来消除错误。

`--planar-preview` 在原完整场景冻结时间与相机，前120帧关闭平面反射、后120帧开启。两张最终图 `planar-100.png`、`planar-221.png`，反射HDR图 `planar-hdr-221.png`。640×360完整mip输入，uReflLod=.4150375，原RP三采样/湿度粗糙度混合实际改变15683个抽样HDR像素；零失败。4秒720p60无音轨录像 `native-planar-reflection.mp4`。

四个源对象layer排除正确（apron/sea/rain/rainSplash），quaySkirt仍在反射。main mask5/reflection1/weapon2。Light pool mask7保留主画面地面/水面受光。marker trace在太阳更新帧221实测 `[reflection,sun,world,weapon]`，符合源反射先读取旧太阳图的callback顺序；它不是非周期运动情况下逐texel shadow-age证明，该项仍待补。

`tools/run_native.sh` 使用隔离二进制，当前默认开启反射。stock版本默认不开此不兼容路径，显式实验入口也检查status，不再触发原水平错误。原caster/实际shadow flags、源太阳、AO/Y9/后期保持同一默认链。运行与退出日志无SCRIPT/SHADER/GPU ERROR或泄漏。

仍待动态运动与旧阴影逐texel辨别、真正逻辑resize/重建/高度停用恢复、XR状态重入、全场景局部灯/IBL/材质差异和GPU性能。没有据此标记整个复刻完成。

## 逻辑缩放、停用和重建验证

`tools/verify_planar_lifecycle.gd` 实例化原完整main场景，手动零dt驱动原处理链，真正关闭固定canvas缩放再改变root逻辑尺寸，未把物理窗口缩放冒充目标变化。1280×720对应640×360，961×541对应480×272，128×64对应最小64×32，再恢复640×360；每项都检查实际reflection纹理、world/weapon目标尺寸、ready与uReflOn。

相机降到y=.02时，反射viewport停用、gain=0且不再有reflection回调；回到1.4恢复。显式enabled=false/true同样通过。dispose后XR primary/interface数量和四个源对象world层恢复；同一原场景中重新setup后ready=1、gain=1、顺序仍为reflection→sun→world→weapon。八种状态与重建零失败，日志无错误/泄漏。证据 `evidence/planar-lifecycle-verification.json`。

顺序现在由显式viewport父子依赖保证：`order_before_sun()` 将反射viewport放在sun caster viewport之下，仍共享原场景World3D，camera重新make_current；渲染器按children-before-parent拓扑执行，不依赖资源创建RID先后。初始setup和重建都调用。这个变化不改变shadow矩阵、世界相机或caster几何。

## 非周期 GPU 阴影帧龄验证

`tools/verify_planar_shadow_history.gd` 使用真实SunShadowPass128和一个非周期移动的原caster proxy。反射与主场景中的实际3D fragment直接采样同一R32F阴影texture；反射仍走独立mono XR viewport和HDR capture/mip，使用与生产相同的child-of-sun依赖。为隔离数据顺序，诊断fullscreen shader显示深度数值，不把它称为最终PCSS画面对照。

八帧包含四次真实更新和四次隔帧持有。每次更新的新旧图分别有216/378/468/216个像素不同，区别足够辨认。逐128×128图检查：反射图等于更新前图、主图等于更新后图，所有像素零误差；奇数帧保持上张图，初次反射读取初始化白图。原预设.001容差未放宽，实际最大误差0。证据 `evidence/planar-shadow-history-verification.json`。

这补齐了此前仅有callback trace的限制，证明该共享R32F资源的实际GPU读写帧序。它使用受控单caster和128图，不能代替所有原角色/大场景动画、4096分辨率图逐像素和最终PCSS可见图的动态验收。性能、全场景照明与全项目其余功能仍待完成。
