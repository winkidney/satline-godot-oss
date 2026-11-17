# 实际世界与武器GPU深度桥

实现`scripts/solar_depth_bridge.gd`，依据保存的原Q9及[Astra原码审查](solar-depth-adviser.md)。默认游戏世界和武器相机各有独立CompositorEffect，POST_TRANSPARENT读取resolved depth，在全局RenderingDevice compute中复制到持久R32F Texture2DRD。世界值为1-native reverseZ；武器为实体0/空背景1，仅供太阳阈值遮挡，不是可用于AO/雾/软粒子的距离数据。

原Q9新增tWeaponSolarDepth与uUseWeaponDepth开关。默认游戏开启双输入，每个太阳tap读取两张nearest深度的min，再执行原step(.99999)。离线原shader对照保持开关默认false。运行时没有CPU GPU回读，也没有重复绘制场景或碰撞射线代理。当前太阳投影和动态可见性已接线，原flare=.16开启，细节见[太阳眩光记录](solar-flare.md)。

## 真实GPU验证

`tools/verify_solar_depth_bridge.gd`创建实际世界和武器视口，11帧非周期遮挡序列中逐帧读取后续2D pass与原Q9.g。左上世界/右下武器能区分方向；空背景1，实心世界小于阈值，武器实体0。透明玻璃depth_draw_disabled不遮挡，discard裁剪的一半孔洞通光、一半实体遮光。全部通过，`evidence/solar-depth-bridge-verification.json`保留逐帧读数。

两路从64×64独立resize为96×80与80×96，resize首帧改变遮挡，保持Texture2DRD对象及RenderingServer texture RID不变，后续消费者当帧读到新数据；原始世界数据FORMAT_RF，EXR保留`evidence/solar-world-depth.exr`。GPU日志无SCRIPT ERROR、SHADER ERROR、ERROR:。测试使用正交相机与MSAAoff，不是原作MSAA4边缘或全部原资产材质一致性证明。

## resize实际修复

最初在Compositor回调中换Texture2DRD RID，数值断言通过但日志报“Uniforms were never supplied for set(1)”。分阶段标记明确发生在resize。Astra源码审查确认TextureStorage.texture_replace会释放旧shared view使Canvas材质uniform失效；其dirty重建窗口已在viewport draw之前结束。因此延迟旧base释放不能解决。

实际prepare_size先排队到渲染线程，提前分配R32F并发布给持久wrapper，接着由引擎在帧前刷新材质。回调只dispatch，不再发布新纹理。尺寸不匹配则is_ready=false，deferred排队准备；调用方不得把未就绪旧图当本帧数据。默认pipeline setup和_resize显式准备两路尺寸，dispose先解绑相机effect与消费者，再排队释放自建GPU资源；引擎depth从不释放。此改动修正了原adviser初版resize建议。

R32F usage包含storage/sampling/copy-to/copy-from；copy-to用于准备阶段清屏为1，copy-from仅为独立验收回读提供能力，游戏不读回。无跨帧缓存RenderData/RenderSceneBuffersRD。GPU pipeline/shader/sampler/texture集中在渲染线程创建/释放。

## 尚未完成

原Three D24阈值量化与Godot R32F/实际depth精度边界；原MSAA4逐sample世界+武器合并后resolve与native两路resolve后合并的边缘差异；长时间反复resize/重建的VRAM趋势；真实chainlink/武器轮廓逐像素对照。不能以本桥组件通过替代完整太阳眩光视觉验收。

默认post-preview游戏流程720帧跑完并正常释放，11个snapshot均确认世界/武器桥ready=true、两路1280×720；`evidence/solar-depth-game-runtime.json`记录状态，三个solar-depth-*.log归档实机/隔离链路日志，无ERROR或泄漏。原64组空间对照、180帧HalfFloat历史及12帧HDR链路均回归通过。
