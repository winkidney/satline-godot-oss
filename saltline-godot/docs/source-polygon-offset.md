# 原贴花硬件深度偏移

默认启动已在隔离source_bias引擎启用D24_S8与原polygonOffset。48个原材质、75个原网格全部映射，未给无offset材质添加偏移。原GL计量、规范及引擎取舍见[顾问调研](polygon-offset-adviser.md)，最终复审见[集成审查](polygon-offset-integration-review.md)。原源码固定在研究项目bundle，当前补丁与二进制SHA由engine/source-manifest.json、build-result.json保存。

## 生产接线

引擎保持R32 storage/resolve输出，只将实际depth attachment优先设为D24_UNORM_S8_UINT。四种私有Forward+ render_mode设置真实rasterization depth bias，未写fragment DEPTH。depth/prepass/color保持同一偏移，并禁止biased材质被shared shadow material替换。当前原48材质全透明、depthWrite=false且不投影，不能据此推广到原生shadow atlas的其他深度格式。

| 原材质 | 原factor/units | reverse-Z slope/constant |
| --- | --- | --- |
| 世界标签/贴花，46材质 | -2/-2 | 2/2 |
| 武器刻字，1材质3网格 | -3/-3 | 3/60 |
| 世界fx_decals，1材质 | -4/-4 | 4/4 |

额外world_3模式仅用于通用斜率测试。符号因reverse-Z反转；独立武器viewport把原depthRange .05扩至1，所以仅constant项乘20，slope不再乘20。本机原NVIDIA GL与普通Vulkan D24的有效r都为2×2^-24，不需要再把普通D24的units乘2。

加载器从原node.layers收集材质的world/weapon域，再将模式加入动态shader的render_mode与cache key。保留source_shader_path元数据供太阳、IBL与局部光服务识别。原48材质不跨两个相机共享；混合域或未知系数组合会拒绝映射，不假装uniform能改变已经建立的固定pipeline状态。

启动能力检查覆盖isolated engine、Forward+、RenderingDevice及D24 attachment/sampling/copy-from用途；不支持时明确记录近似fallback并停止注入D24偏移单位，避免实际D32却使用D24常量。该检查不是跨GPU的r校准，当前数值证据限定本机NVIDIA。实际四viewport的D24格式另由compositor读回确认，不能只凭setting=true推断。

`rendering/saltline/source_depth_24`只能在启动前或完整销毁重建renderer时决定。现存buffers与按新flag推导的pipeline不可混用。生产配置静态true，只有隔离诊断在完整释放旧pass后切换它。

## 硬件与实际材质验证

- [原GL计量](../assets/export/fixtures/polygon-offset-reference.json)：546组、4368个深度采样，D24、world/weapon range与多种斜面。与[RD计量](../evidence/rd-polygon-offset-probe.json)配对的63组常量offset delta完全一致。
- [Forward+验证](../evidence/polygon-engine-verification.json)：50组，三个平深度与两个斜面、0/4xMSAA、四模式。实际附件128=D24_S8，opaque prepass与color中心保持一致。首轮CPU理想tan斜率与实际光栅梯度最多差约7个q24，失败留档；改用未偏移GPU深度的32像素梯度后通过，原2q24门槛不变。它验证真实光栅slope系数，不声称两个API的不同顶点运算逐位相同。
- [透明/映射验证](../evidence/polygon-transparency-verification.json)：32组，半透明层在receiver后2/16/64/256个q24的遮挡、alpha混合和不写深度均正确。全部48材质/75网格覆盖，其他材质无bias；unsupported逻辑guard也执行。原decal_logo_a与weapon_markings的原geometry/UV/texture/生产shader在同几何receiver后仅切bias，分别5/368个HDR像素变化。该孤立实验不代替完整原透视合成。

## D24对既有深度链的影响

[太阳深度全图比较](../evidence/sun-depth24-delta-verification.json)使用同一静态原148 caster，逐项核对D32_S8与D24_S8实际附件。完整4096²、16777216像素中402512像素改变，最大差5.9604644775e-8，即一个q24；没有超过预先设定的2q24界。几何覆盖5542142像素，caster分类不变。它是producer量化影响界，不是原GL packed shadow全图对齐证明。

D24完整场景重新运行太阳/PCSS360帧、AO240帧、24步volume360帧和planar240帧，各原功能断言通过；四相机world/weapon/sun/reflection实际附件均128。各自上下文在evidence/d24-*-context.json，旧D32报告保存到evidence/d32-before-source-depth24。

默认生产配置还通过8项真实resize/高度/开关生命周期、XR与layer恢复及重入，最后顺序reflection→sun→world→weapon；780帧标题/暂停/死亡与两次重试通过。所有最终相关日志无SCRIPT/SHADER/引擎错误或泄漏。

## 仍保留的边界

独立武器深度仍有量化次序差异：原Q24(.05*z+bias)与合成.05*Q24(z+bias/.05)并不完全相同。连续bias尺度已正确，不能扩称weapon所有相等深度阈值逐位相同。原packed shadow从高精度fragment Z编码，与附件读回也不是同一契约；原动态PCSS临界边、跨驱动r、全原作像素对齐仍在总目标内。

[当前实机视频](../evidence/native-source-depth24.mp4)为1280×720、H264、60fps、无音轨，601编码帧/10.016667秒，展示当前D24、材质、原光照/后期和真实ADS/射击/装填/切枪。固定录制fps不代表交互性能。[捕获校验](../evidence/source-depth24-capture.json)，已查看2秒ADS与8秒手枪帧。
