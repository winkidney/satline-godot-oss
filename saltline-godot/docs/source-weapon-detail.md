# 武器程序化材质

原作 `_E` 的六个材质现接入生产通用 Standard shader，覆盖十三个真实网格。来源为 [原 bundle 的 Bz/Hz/Oz/Vz/Wz 与 _E](../../artifact-rendering-study/source/extracted/bundle-1.js#L70345)，HTML 来源和校验沿用研究项目原档案。`extract_weapon_detail.py` 从实际导出 patch 提取 helper 与 surface，核对六材质共享同一正文，再生成 Godot include；没有按截图重新猜参数。

| 原材质 | D_KIND | 主要细节 |
| --- | --- | --- |
| pac9_anodised | 0 | 阳极表面、手掌油痕、磨亮边缘、划伤露底 |
| pac9_phosphate | 1 | 磷化层吸油、晶粒、局部裸钢及加工纹 |
| pac9_polymer / pac9_polymer_tan | 2 | 模具细纹、1.15mm斜网格凸点、分型线、擦白 |
| pac4_nitride | 3 | 氮化表面加工纹、油痕、磨穿灰钢 |
| pac9_matte | 4 | 橡胶/哑光内衬细纹、粉化、磨亮 |

共用部分包含凹槽积尘、油污变色、雨滴半球高度、侧面流痕，以及随 `length(fwidth(vObjP))` 淡出的微细节。参数、分支顺序、roughness/metalness 调制均来自原式。

## 真实属性与渲染顺序

原 `aSurf` 四通道分别为 edge/cavity/bare/zone，已通过 CUSTOM0 进入 fragment。十三网格共168564顶点、674256个 aSurf 通道，GPU完整读回逐字节一致。原 normal 另存 CUSTOM2 的 FP32 xyz，避免 Godot native normal 通道的八面体编码量化影响细节。十三网格该缓冲也完整读回一致。

当 `source_weapon_kind>=0`，vertex 恢复原 NORMAL，保存原 object normal、object position 和 `normalize(mat3(MODEL_MATRIX)*normal)`；后者保持原 patch 的直接 modelMatrix 变换，不能替换成 inverse-transpose 后再在 fragment 归一化。三个 varying 按原方式插值。当前十三网格均无 skin、normalMap、SL_FX 或透明混合，尚不把此接线声称为所有未来组合都已验证。

surface 在原 vertex/instance color 之后、光照之前修改 albedo/roughness/metalness。最终高度为 `dHt+dDropH*.17`，使用原 bE 的屏幕导数 bump，并在调用前 normalize 输入 normal。之后用最终 normal 计算直接光和 IBL。

原凹槽项 `occ=1-.8*cavity` 在 AO 后分别调制四路光照：indirect diffuse乘occ，indirect specular乘 `occ*occ`，direct diffuse乘 `mix(1,occ,.35)`，direct specular乘 `mix(1,occ,.6)`。保留 `S*(occ*occ)` 的原乘法结合顺序。emissive 不受此项影响，默认非武器 occ=1。

## 武器湿度不是天气雨量

[原循环](../../artifact-rendering-study/source/extracted/bundle-1.js#L86034)维护独立状态c，初值1。首个 interior box 内严格xz且y<max时，target=.3、速率.25；室外target=1、速率.6；每渲染帧应用原dt上限.05，暂停仍更新。没有y下界。该值同时写六材质 uRain 与手臂 uArmWet，不能直接使用 rain_system.level。

实际Main四阶段验证得到 `.99125 → .982609375 → .979196328125 → .97982043828125`，包含暂停和低于地面仍在室内的情况；CPU状态和七个材质uniform误差0。复用既有IBL室内判断，未另造不一致边界。

## NVIDIA 原噪声的乘加顺序

最初 literal GLSL 移植未通过。`fract(sin(dot(p,c))*43758.5453)` 对dot的一ULP差异极敏感；只在dot外加float32守卫不能约束其内部运算。case2格点 `[4,-11,-470]` 的原GL dot为 `c7148d4c`，Vulkan为 `c7148d4d`，最终hash分别约.71582与.25781。统一输入angle后，两端sin逐位相同，因此这例不能归因为sin本身。[完整顾问诊断](weapon-detail-noise-adviser.md)

原NVIDIA GL顺序可显式表示为：

```glsl
fma(p.z,74.7,fma(p.y,311.7,round_to_float32(p.x*127.1)))
```

dh2 的两个二维dot也按x乘法先round、再y的fma处理。运行时uint零的bitcast守卫保护函数入口和关键运算边界，防止编译器跨调用分配乘法。此处保留原随机场，未改种子、分布、纹理或容差。结论以当前原NVIDIA OpenGL与native NVIDIA Vulkan为准，不外推其他驱动必然逐位一致。

## 验证与可查看产物

- [材质核心](../evidence/weapon-detail-verification.json)：96组、1536通道全部通过，最大绝对误差约5.96e-8。五个kind，位置/原表面属性/雨量/像素宽度组合，输出albedo、rough、metal、height、cavity及噪声/雨滴诊断。参考来自独立原Three GLSL；pixel width显式输入，不是完整原网格透视插值证明。
- [空间 bump](../evidence/weapon-bump-spatial-verification.json)：32组、98304通道最大误差0。覆盖正反面、镜像平面和高度梯度，使用实际Godot空间导数；不替代完整程序化高度场的逐像素对照。
- [实机接线](../evidence/weapon-detail-runtime-verification.json)：六材质、十三网格属性和湿度审核通过，开启细节改变15501个武器HDR抽样点。最后的cavity括号修正另由当前完整捕获和太阳回归覆盖。
- [生成幂等](../evidence/weapon-detail-generation-verification.json)：重新提取生成结果不变。
- 首次mat3语法编译失败、最初数值失败与dot顺序失败均保留，不将失败记录覆盖成成功。最初把roughness打包alpha时还暴露了native视口固定alpha=1的问题，后续标量移入RGB，没有扩大门槛。

![当前武器材质](../evidence/weapon-detail-on.png)

[当前版本10秒实机视频](../evidence/native-weapon-material-detail.mp4)包含瞄准、射击、换弹和切枪，1280×720/H264/60fps，无音轨。600个模拟帧加结束捕获帧共601个编码帧，时长10.016667秒。固定录制帧率不代表实时交互性能；[捕获参数与校验](../evidence/weapon-detail-capture.json)。已查看2秒瞄准与8秒手枪画面。

完整原作逐像素校准、真实网格透视插值对照、跨驱动噪声范围、其他非PAC的程序化patch和最终游戏验收仍在总目标内。

## 武器刻字的alpha凹刻

[原Uz材质](../../artifact-rendering-study/source/extracted/bundle-1.js#L70039)还有独立patch：在normal map阶段之后执行 `dBump(normal,-diffuseColor.a*.00005)`。当前加载器按实际patch正文启用 `source_markings_bump`，不按显示名猜测。生产通用shader在最终alpha与原法线已准备好之后，以原贴图alpha作为50微米的负高度，复用已独立验证的bE bump。实际此材质opacity=1、无vertex alpha/normalMap，透明度输入与原式一致。

[三套实际刻字网格验证](../evidence/markings-runtime-verification.json)使用原geometry/UV/纹理及生产alpha shader，在独立正交侧视中分别改变884、2193、5105个HDR像素，最大RGB差约.01465/.04590/.20886。原IBL保留，视角隔离只是为观察刻字；不是完整原作透视合成的数值比较。`markings-bump-on/off.png`是该孤立测试的线性RGB转RGB8图，不作为最终场景曝光预览。最终实机验证退出0，日志无错误或泄漏。

该材质原polygonOffset=-3/-3及世界贴花偏移现已按硬件raster bias接入，D24配置默认启用，未用fragment epsilon替代，见 [实现与验证](source-polygon-offset.md)。

最终回归：太阳/PCSS360帧、平面反射240帧均通过，当前600模拟帧实机录制正常退出；最终核心、属性/湿度、bump、太阳、反射与捕获日志无SCRIPT/SHADER/引擎错误或泄漏。见evidence内weapon-detail-source-sun.log、weapon-detail-planar.log与weapon-detail-capture.log。
