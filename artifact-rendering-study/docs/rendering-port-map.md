# SALTLINE 渲染链路到 Godot 的迁移表

记录日期：2026-11-14。依据用户提供的 [saltline.original.html](../source/saltline.original.html)，静态分析实际执行的第二个 script。格式化后的 [bundle-1.js](../source/extracted/bundle-1.js) 是行号依据；链接的 `#L数字` 表示该版本的源码定位。本文负责约 35301–37400 行的渲染模块，其他模块的材质、平面反射、几何与动画应结合研究项目其他分析阅读。

第一个 `legacy-v8` script 的 MIME 类型为 `application/octet-stream`，不能把其中保存的旧程序当作当前渲染。下文“确认”只指源码中存在算法和调用分支，不证明驱动编译成功、分支实际启用、运行画面或性能。后续实机证据见[运行报告](runtime-findings.md)，独立Godot验证见[实验报告](godot-experiments.md)。

## 1. 已确认的画面链路

```text
程序噪声 → 天空背景
          └→ 单独环境版本天空 → PMREM → 场景 IBL
方向太阳 + 动态点光池 + 阴影图 + 可选室内 cubemap
          ↓
世界相机 → HDR 半浮点颜色/深度，按质量配置 MSAA
          ↓
近景物件相机，独立 FOV/补光/环境，深度压到 0..0.05
          ↓
1/2 分辨率线性深度 → SSAO、体积散射 → 双边滤波
          ↓
深度引导上采样 → AO 合成 → 体积透射/散射合成
          ↓
可选相机运动模糊
          ↓
6 级下采样/5 级上采样 bloom → 横向 streak
          ↓
中心加权亮度 + 太阳遮挡 → 1×1 历史适应缓冲
          ↓
色差/瞄准外圈模糊 → bloom/dirt/streak/太阳 flare
          ↓
曝光 → ACES/AgX 混合 → 分离色调/S 曲线/抬黑/饱和度
          ↓
暗角/受伤/淡出 → 手动 linear-to-sRGB
          ↓
FXAA → 低边缘锐化 → 动态 grain → 抗色带 dither → 输出
```

调度入口为 [q()，L36394](../source/extracted/bundle-1.js#L36394)，世界/近景合成入口为 [Z()，L36942](../source/extracted/bundle-1.js#L36942)。后处理失败时进入简单 forward fallback，[F()，L36908](../source/extracted/bundle-1.js#L36908)，该分支使用 Three 的 ACES tone mapping，因此与主链路不能视作同一画面结果。

## 2. 源码证据与 Godot 对应

“原生近似”指 Godot 提供同类效果，但算法、参数或处理顺序不同；“自定义”指需要为该具体做法写 shader/渲染调度。

| 源码中确认的技术 | 原理与定位 | Godot 对应 | 迁移等级与限制 |
| --- | --- | --- | --- |
| 程序天空、落日、云层 | 256² 固定种子噪声；FBM、domain warp、ridged 细节、方向性地平线色；太阳方向附近叠加窄高光；[L35304](../source/extracted/bundle-1.js#L35304)、[L35347](../source/extracted/bundle-1.js#L35347) | `Sky` + 自定义 sky shader，太阳用 `DirectionalLight3D` | 自定义天空。代码是方向纹理云层，不能称作体积云 raymarch |
| 云层伪自阴影与闪电 | 沿太阳水平向对比密度差，形成明暗起伏；`uFlash` 按方向增加云亮度；同上 | 在 sky shader 复现密度采样、时间和闪电参数 | 自定义美术模型，不是大气多重散射求解 |
| 独立天空环境捕获 | `uEnv=1`，去掉高亮太阳圆盘并将颜色上限压到 6，之后 PMREM；[L35476](../source/extracted/bundle-1.js#L35476) | sky radiance，或预制 HDR/EXR + `PanoramaSkyMaterial` | 原生近似。需区分显示太阳与 IBL 太阳，避免重复能量及高光火花 |
| 方向光与动态局部光池 | 单一有阴影太阳，另建 6 盏可复用点光，临时 flash 随寿命衰减；[L36712](../source/extracted/bundle-1.js#L36712)、[L36737](../source/extracted/bundle-1.js#L36737) | `DirectionalLight3D`、`OmniLight3D` 与对象池 | 原生可表达。物理单位/能量不能按数值一一照抄 |
| 面向场地边界的阴影相机 | 将给定场地包围盒变换到灯光空间，拟合正交 shadow frustum；[L35489](../source/extracted/bundle-1.js#L35489) | 方向阴影范围、级联与距离设置 | 原生近似。先保证贴体近景分辨率，不必照搬整个港口尺寸 |
| 阴影更新节流 | 关闭 renderer 的自动更新；ultra、shot 或偶数帧才请求主 shadow map 更新；[L36661](../source/extracted/bundle-1.js#L36661)、[L36948](../source/extracted/bundle-1.js#L36948) | 阴影质量预设、可控更新频率，必要时独立代理或自定义调度 | 需要策略适配。快速布料形变不能直接照搬隔帧更新，否则可见阴影滞后 |
| PCSS 类接触硬化软阴影 | 8 次 blocker search，10/16 次 Vogel disk 过滤；半影随遮挡物距离变大；接收面梯度 bias；[L35540](../source/extracted/bundle-1.js#L35540)、[L36731](../source/extracted/bundle-1.js#L36731) | 灯光 soft shadow、angular distance、bias/normal bias、质量设置 | 原生近似。精确复现其 shadow chunk 替换需自定义引擎阴影路径，普通材质 shader 无同等全局钩子 |
| 半分辨率 SSAO | 从深度邻域重建 normal；螺旋/旋转采样；距离衰减；[L35632](../source/extracted/bundle-1.js#L35632)、[L35641](../source/extracted/bundle-1.js#L35641) | `Environment.ssao_*` | 原生近似。其算法与 Godot SSAO 不同，也不代表有完整 GI |
| 深度双边滤波与上采样 | AO/体积各自两遍 7-tap；合成时 4 邻点按深度差加权；[L35731](../source/extracted/bundle-1.js#L35731)、[L35745](../source/extracted/bundle-1.js#L35745) | 原生效果内部滤波，或自定义 CompositorEffect | 原生近似/自定义。复现原缓冲结构要保留边缘深度指导 |
| 按亮度保护受光面的 AO 合成 | 明亮像素减少 AO，遮蔽色略偏冷；[L35766](../source/extracted/bundle-1.js#L35766) | `ssao_light_affect`、AO strength 可近似；精确规则写 compositor | 自定义规则。不能只把同一系数乘到所有材质最终颜色 |
| 体积光与远处空气透视 | 阴影图沿视线采样；两瓣 Henyey–Greenstein 相函数；指数透射；室内 box 增尘；远处解析续接；[L35674](../source/extracted/bundle-1.js#L35674) | Forward+ `volumetric_fog`、`FogVolume`、fog shader；远雾结合普通 fog | 原生近似。原型为半屏 raymarch，Godot 为不同实现，不能直接对应步数与密度 |
| 相机运动模糊 | 用当前深度重建世界位置，再投影到上一帧相机，沿速度 9 次采样；[L35778](../source/extracted/bundle-1.js#L35778)、[L36479](../source/extracted/bundle-1.js#L36479) | 自定义 compositor；可用 motion vector 或复现矩阵法 | 自定义。这里没有物体逐顶点速度，不能称作完整布料运动模糊 |
| 多尺度 bloom | 6 级 downsample、5 级 upsample；首级部分 Karis weighting 抑制极亮像素；[L35800](../source/extracted/bundle-1.js#L35800)、[L35820](../source/extracted/bundle-1.js#L35820)、[L36490](../source/extracted/bundle-1.js#L36490) | `Environment.glow_*` | 原生近似。源码用 `mix(scene,bloom,uBloom)`，并非简单相加，也没有先阈值截取后才建立 bloom 金字塔 |
| 镜头污渍 | 70 个程序斑点 + FBM smudge + 纵向条纹，生成 512×288 贴图；与 bloom 相乘；[L35871](../source/extracted/bundle-1.js#L35871)、[L36140](../source/extracted/bundle-1.js#L36140) | `Environment.glow_map` 可表达同类效果，污渍图可离线生成 | 原生近似。污渍在镜头/屏幕空间，不是丝袜表面 roughness |
| Anamorphic 横向光条 | 两遍 15-tap 水平 Gaussian 样采样；首遍按曝光调整亮度阈值；蓝色 tint；[L35830](../source/extracted/bundle-1.js#L35830)、[L36510](../source/extracted/bundle-1.js#L36510) | 自定义 compositor 中增加横向模糊目标 | 自定义。各向异性镜头光条与材质 anisotropy 是不同现象 |
| 太阳 lens flare 与光晕 | glare、衍射尖峰、轴上彩色 ghost、对侧 ring；12 点深度探测 + 历史平滑决定可见度；[L35844](../source/extracted/bundle-1.js#L35844)、[L35930](../source/extracted/bundle-1.js#L35930) | 太阳投影 + 遮挡判断 + 自定义屏幕 shader | 自定义。普通 glow 不能代替 ghost 位置与遮挡逻辑 |
| 自动曝光与眼睛适应 | 7×5 中心加权对数亮度；1×1 ping-pong 历史；key/亮暗限幅；[L35626](../source/extracted/bundle-1.js#L35626)、[L35844](../source/extracted/bundle-1.js#L35844)、[L36530](../source/extracted/bundle-1.js#L36530) | `CameraAttributesPractical` 的 auto exposure | 原生近似。精确测光权重、指数和时间常数需要自定义 |
| ACES 与 AgX 混合 | 自写 ACES Hill fit 与 AgX 对比/色域处理，按 `agxMix` 混合；[L35900](../source/extracted/bundle-1.js#L35900)、[L35962](../source/extracted/bundle-1.js#L35962) | 原生 ACES 或 AgX；准确混合则自定义 tone mapping/独立输出链路 | 原生近似/自定义。单选 tone mapper 或一张普通 LUT 不自动等价于该混合 |
| 调色与游戏反馈 | teal shadows/warm highlights、S 曲线、抬黑、饱和度、暗角、伤害红边、淡出；[L35965](../source/extracted/bundle-1.js#L35965) | Environment adjustments/LUT；游戏反馈用屏幕 shader 或 CanvasLayer | LUT 可承接固定调色。动态、空间相关效果需自定义 |
| 色差与瞄准外圈模糊 | radial RGB offset；从降采样 scene 读取柔化图，仅作用视野外围；[L35945](../source/extracted/bundle-1.js#L35945) | 自定义屏幕 shader/compositor | 自定义。它不是物理景深；`focusDist` 在本模块没有参与 DOF 求解 |
| MSAA + FXAA | HDR target 按质量设 samples，最终 gamma 编码后用 alpha 中亮度做 FXAA；[L36802](../source/extracted/bundle-1.js#L36802)、[L35998](../source/extracted/bundle-1.js#L35998) | Viewport MSAA、屏幕 AA 的 FXAA | 原生近似。原示例无 TAA 证明，不能把曝光历史缓冲误认为 TAA |
| 锐化、film grain、dither | 低对比处 unsharp mask，亮度权重动态噪点，约 1/255 的静态噪声抗色带；[L36013](../source/extracted/bundle-1.js#L36013) | 自定义末端 shader/compositor，或输出到 SubViewportTexture 再处理 | 自定义。原式在 sRGB 编码后处理，HDR 阶段移植同数值会不同 |
| 独立近景物件渲染 | 第二相机独立 FOV；专用方向补光；视深压到 0..0.05，让 AO/vol/motion 特判跳过；[L36698](../source/extracted/bundle-1.js#L36698)、[L36917](../source/extracted/bundle-1.js#L36917)、[L36954](../source/extracted/bundle-1.js#L36954) | SubViewport 双相机/显示层合成，或专用近景渲染方案 | 自定义合成。适合第一人称持物，丝袜角色近景通常应保留真实世界深度 |
| 室内局部环境探针 | 内部 box 选采样位置，128² cubemap 捕获后 PMREM，分配给标记为 interior 的材质；[L37190](../source/extracted/bundle-1.js#L37190) | `ReflectionProbe` 的范围、interior、更新模式 | 原生近似。不是局部实时路径追踪，也不是 SSR |
| 动态分辨率与自动降档 | 按帧间隔均值调 0.6..1 scale；质量级有像素数量上限；[L36848](../source/extracted/bundle-1.js#L36848)、[L37099](../source/extracted/bundle-1.js#L37099) | viewport 3D scaling，按策略改质量 | 原生缩放 + 自定义控制。源码的 CPU frame interval 不能作为 GPU pass 时间 |
| 编译检查与回退 | 初始化测试，soft shadow 失败退 stock PCF；post 失败改简单 forward；[L37249](../source/extracted/bundle-1.js#L37249) | shader 预编译/加载检查、低质量预设和可用性检查 | 架构可借鉴；源码有检查不代表本次已通过 |

## 3. 源码中的关键调节量

参数表定义见 [L36083](../source/extracted/bundle-1.js#L36083)。这些是代码中的初值，不是实测参数，也不保证游戏运行时未被调节。

| 分组 | 初值 |
| --- | --- |
| 体积 | `volSigma=0.0034`，`volMaxDist=170`，`volSunScale=0.85`，`volAmbient=0.2`，`volFarHaze=0.42`，室内 `volInteriorDust=6` |
| AO | radius `0.9`，intensity `1.6`，composite strength `0.95`；质量分支 8/12/16 taps |
| bloom/镜头 | bloom `0.065`，金字塔混合 `0.62`，dirt `0.1`，streak `0.03`，streak threshold `2.2`，flare `0.16` |
| 曝光 | key `0.12`，乘数限幅 `0.6..2`，适应 τ `1.5 s`，测光比例指数 `0.85` |
| 色调与末端 | `agxMix=0.25`，AgX look power `1.18` / sat `1.22`，CA `0.0013`，vignette `0.3`，grain `0.02`，sharpen `0.3` |

体积步数取质量配置并至少 6 步；shader 创建时初始宏为 16，不能把这一处写成所有质量档固定 16 步。曝光默认开启，但 URL/运行配置与回退会影响实际流程。前景相机的深度区间特判常量为 `0.05`，这是本项目人为约定，不适用于 Godot reverse-Z 深度。

## 4. 迁移时最容易混淆的边界

### 反射不等于 SSR

在本模块的 post graph 中没有 SSR pass，也没有依据屏幕颜色做反射 raymarch。这里可确认的反射来源是天空 PMREM 和室内 cubemap。后续地面/水面模块还出现独立 `reflectionTarget`/`reflectionCamera`，因此本文不把整个项目概括为“只有 IBL”。应结合那部分代码区分平面反射、IBL 和真正 SSR。

天空背景每帧更新 `uTime/uFlash`，但天空 PMREM 在创建时捕获，本模块未见每帧重新捕获天空 IBL。室内 cubemap 在场地就绪时生成，并提供显式重捕获接口。这是显示天空与环境照明更新频率分离的优化，不应误认为移动云层实时参与所有环境反射。

### 云层与体积雾是两套算法

天空云层按观察方向采样二维 FBM，密度差制造起伏受光。体积雾按世界视线、深度和太阳阴影图积分，有透射 `T` 与散射 `acc`。前者不能让近处几何投影进云中；后者确实在代码中使用场景 shadow map 遮住光束。

### 镜头 anisotropic streak 不等于纱线 anisotropic BRDF

横向 streak 在完整场景图上卷积，方向跟镜头走；纱线高光受局部切线、光线和视线控制。丝袜材料应从物理表面方向建立高光，再按所选镜头风格决定是否添加光条。

### DOF、SSIL、TAA 不能仅凭字段名认定存在

`focusDist` 只是 post 状态字段，本模块未见景深圆模糊求解；瞄准效果是基于屏幕半径混合低分辨率图。曝光 `adapt` 历史只存亮度与太阳可见度，不是 TAA。`uThunder`、`uFlicker` 的声明也不足以证明使用它们产生后期效果。实际雷电表现可确认在天空 `uFlash` 和体积环境亮度调节中。

## 5. Godot 管线选择与透明丝袜限制

建议先采用 `Forward+`，保留 `stocking-lab` 现有材料与阴影代理，利用原生 sky radiance、灯光、SSAO、glow、tone mapping 建立近似。只有在原生效果与目标差距明确后，才编写自定义多 pass。

Godot 的 `CompositorEffect` 能插入 3D 渲染阶段，但仅 Mobile/Forward+ 支持；回调在渲染线程运行。[官方 compositor 教程](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)。`POST_TRANSPARENT` 在透明之后、内置后处理之前执行，可用于让自定义镜头效果覆盖透明袜层；如开启 MSAA，需要正确获取 resolved color/depth。其 normal/roughness 与 motion vector 的生成阶段和格式也需按 API 处理。[CompositorEffect 官方参考](https://docs.godotengine.org/en/stable/classes/class_compositoreffect.html)

该阶段仍然不是“最终 sRGB 之后”。准确复制 SALTLINE 的 tone map → display-linear grade → sRGB → FXAA/grain 顺序，需要设计输出链路并关闭重复转换。把整段 `tk` 直接放进 Godot spatial shader，会遇到额外 tone mapping、颜色空间转换和透明阶段问题。固定 LUT 可承接一部分调色，不能代替曝光、空间暗角或亮度阈值 bloom。

普通 `hint_screen_texture` 在透明之前复制，无法完整取得其他透明层；深度也不能表达每层半透明覆盖。[官方屏幕读取说明](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)。因此：

- 镜头色调/glow 可作用到合成后的袜子，但袜层是否进入 SSAO/SSR 计算是另一件事。
- 半透明丝袜与皮肤的关系优先依赖正确几何、材质与覆盖率；不要用 AO 弥补所有透光问题。
- 体积雾的深度终止也要检查透明层，不能期待普通深度缓冲自动记录所有织物表面。
- 透明表面阴影继续使用现有代理或经过选择的 hash/scissor 方案；不把阴影 proxy 的存在当成已通过视觉验收。

Godot 体积雾原生支持光照、阴影、各向异性散射和 FogVolume，仅 Forward+ 可用；时间重投影可能为快速变化光源产生拖尾。[官方体积雾教程](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)。它可以作为港口尘雾近似，但不是丝袜薄纱透光的替代。

Godot 的自动曝光由 CameraAttributes 控制，Forward+ 支持；使用 `auto_exposure_scale/speed` 可建立近似，不是照搬 source 的 key 与 τ 数值。[CameraAttributes 官方 API](https://docs.godotengine.org/en/stable/classes/class_cameraattributes.html)。局部探针使用 ReflectionProbe；高光 shape 还取决于环境内容和 roughness，不能仅靠增加光源强度。[ReflectionProbe 官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html)

## 6. 对丝袜项目的迁移优先级

| 顺序 | 可收集/设计的内容 | 原因 |
| --- | --- | --- |
| 先做静态设计 | 分开记录主光、IBL、曝光、tone map 与材质参数，保留 clean 输出 | 有助于判断“丝感”来自材质还是镜头调色 |
| 第一轮候选 | 环境亮带、接触硬化阴影、稳定的亮度范围与高光压缩 | 与腿部曲面、细纱高光和贴体观感直接相关 |
| 第二轮候选 | 过滤后的多尺度细节、温和 bloom、固定调色 LUT | 需在材质已经成立后评估，防止把纹理抹掉 |
| 风格可选 | flare、streak、lens dirt、grain、vignette | 属于镜头审美，不是丝袜材料固有属性 |
| 场景可选 | 体积尘雾、港口天空、动态分辨率 | 适合有对应环境的演示，不是必需材质功能 |
| 不直接迁移 | 武器前景深度压缩、伤害红边、ADS 模糊 | 原用途与全身角色丝袜观察不同 |

源码提取和迁移分析已补充原作GPU运行与三个独立Godot实验。未接入或改动 `stocking-lab`，详见[实机报告](runtime-findings.md)。

## 7. 后续原生复刻的实现路径

2026-11-16：同工作区的 [saltline-godot](../../saltline-godot/README.md) 已进一步实现原生游戏与原作十类展示。这里的三个实验仍保留为学习用的简化版本，不能用其 LDR 反射限制描述后续完整实现。完整复刻尚在验收，不声称整幅画面逐像素一致。

| 技术 | 可阅读的实际代码与验证 | 迁移时的约束 |
| --- | --- | --- |
| HDR 平面反射、斜近裁切与反射 mip | [planar_reflection.gd](../../saltline-godot/scripts/planar_reflection.gd)、[引擎说明](../../saltline-godot/engine/README.md) | 原生 Spatial shader 的逐材质裁切可做近似；当前精确斜投影及相关灯光裁剪依赖隔离引擎补丁。没有替换系统 Godot。 |
| 世界与第一人称武器的独立深度 | [combined_depth_bridge.gd](../../saltline-godot/scripts/combined_depth_bridge.gd)、[165 案例读回](../../saltline-godot/evidence/depth-samples-engine-origin-verification.json) | 分别提取 4× MSAA 样本，反转 reverse-Z 后按原武器深度压缩规则合成。此用途不能直接套到透明丝袜分层深度。 |
| 完整多阶段后处理 | [post_pipeline.gd](../../saltline-godot/scripts/post_pipeline.gd) | 世界、武器、AO、体积光、曝光历史、bloom、光条、色调与最终屏幕处理显式串联，避免 Godot 再次执行同类转换。不是打开原生 glow 就得到同样输出。 |
| 原作材质纹理采样 | [实际 GPU 采样对照](../../saltline-godot/evidence/material-sampler-gpu-source-rows-verification.json) | 检查 wrap、flip、颜色空间与源 mip 行序。48 个受控采样最大差 0 只证明这些采样，不证明全材质在任意视角完全相同。 |
| 环境照明与室内适配 | [source_ibl_service.gd](../../saltline-godot/scripts/source_ibl_service.gd) | 保留独立环境预滤数据及材质绑定；动态天空显示和环境照明更新仍是不同路径。 |
| 贴花深度偏移和后端坐标差异 | [偏移记录](../../saltline-godot/docs/source-polygon-offset.md)、[光栅方向探针](../../saltline-godot/evidence/raster-origin-verification.json) | 当前 D24、源偏移模式和按视口光栅方向依赖固定 Forward+ 引擎。不要将补丁接口当成官方 Godot 通用 API。 |

当前可下载到本地直接运行的开发包为 [r16](../../saltline-godot/output/linux-runtime-20261116-r16/)，约 3.07 GB，保留未裁剪资产和导入缓存。实机效果见 [射击视频](../../saltline-godot/evidence/native-raster-origin-shooting.mp4) 与 [平面反射视频](../../saltline-godot/evidence/native-planar-reflection.mp4)；视频各自对应采集时版本，不能当成 r16 全功能回归。近期包内启动和资源一致性证据见 [r16 验证](../../saltline-godot/evidence/runtime-bundle-r16-verification.json)。

对丝袜研究仍建议先用原生材质、光照与过滤策略建立效果，再按实测差距选择这些定制路径。这里没有把武器深度压缩、跨后端精确偏移或整套港口后处理自动加入 `stocking-lab`。
