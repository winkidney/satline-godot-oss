# 原最终compositor与原生HDR渲染链

## 原作依据与范围更正

原始入口 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp ，保存活动脚本 `../../artifact-rendering-study/source/extracted/bundle-1.js` SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。约35619/35625为ao/sv共享函数，35800为j9缩小核，35891–35997为tk最终合成，36106为后处理参数，36545起为运行时uniform同步。

核对活动版本后更正此前清单：原作没有镜头雨滴折射，render.post.wet是未被该后处理读取的字段；真实效果是ek生成的静态镜头污渍参与bloom/flare。该污渍已接入，太阳眩光仍须迁移，但不能凭wet字段或下雨场景添加原作不存在的折射效果。

## 当前链路

`post_pipeline.gd`在默认游戏和游戏预览构建：

1. 主相机保持原transform与mask1，独立world_port使用LINEAR/exposure1；独立weapon_port保持54度/mask2、.01/10、透明HDR，世界与武器都捕获真实MSAA各样本。
2. 武器capture后按原depthRange(0,.05)与depth test逐sample合并，按实测原参考选择sample0，输出full R32F；精确2x texelFetch到R32F half。没有把武器mask当距离。
3. scene_port线性HDR先画world，再按原预乘方式合成weapon。独立AO8原12tap和两遍7tap双边模糊，经原$9 joint-bilateral/亮处衰减输出ao_scene HDR；默认GodotSSAO关闭。
4. ao_scene进入原j9六级13tap降采样、K9五级tent上采样(.62)与J9两遍横向光晕；第二层down也是原ADS柔化输入。历史copy在这些pass前保存上帧adapt，AO/streak读上帧，原Q9测光/可见性后tk读本帧。
5. 原tk将调色后sRGB和亮度alpha写RGBA8 LDR，原nk FXAA/锐化/颗粒/dither输出不透明根显示；HUD仍在独立SDR层20。

viewport按producer→consumer创建。Godot不会根据sampler引用自动排序，源码依据见[Astra HDR审查](post-hdr-adviser.md)。TextureRect使用EXPAND_IGNORE_SIZE，避免输入纹理尺寸成为缩小pass最小尺寸。R32F替换纹理在帧前prepare_size发布，不能在compositor callback中换wrapper，详见[深度桥resize修复](solar-depth.md)。

`tools/port_composite_shaders.py`直接从保存的原GLSL模板生成各pass。`source_composite.gdshader`保留不透明诊断版本，默认游戏使用亮度alpha版本`source_composite_data.gdshader`与`source_finish.gdshader`。world/weapon内建tone map和glow关闭，避免双重处理；旧非游戏诊断入口保留Filmic阶段配置。

## 实际启用和仍缺的输入

当前运行uExposure=1、uAuto=1。原Q9的35点中心加权log测光与1.5秒指数适应已接入；streak读上一帧适应结果，tk读本帧结果。太阳投影及双深度可见性已接线，flare按原增益.16开启。uBloom=.065、uDirt=.1、uStreak=.03按原作接入。set_bloom_enabled只切增益，不是原质量开关，图仍执行且测光输入保持down5。污渍运行时使用原GPU烘焙资产。

默认游戏已用原AO替换Godot SSAO，原体积光/雾、运动模糊和雷暴在相关pass中的响应未接。原tk后nk的FXAA/锐化/颗粒/dither现已迁移并接入RGBA8中间目标，详见[最终显示层](final-finish.md)；但体积光等前置pass仍未完成，不能称整条原final链已完成。原全场景灯光能量、材质与曝光仍未统一校准。旧非游戏诊断入口仍用原先Filmic配置，便于保留阶段证据；默认游戏走新链。

## 验证

| 证据 | 结果及范围 |
|---|---|
| `post-pipeline-verification.json` | 实际world/weapon/scene/down链，12帧红绿交替、全屏武器(8,.1,2)/alpha.25，贯穿6级down、5级up和2遍streak，验证同帧、预乘透明、常场能量、阈值2.2及HDR>1；最大残差.007032，容差.025。不是非均匀空间核或污渍一致性证明 |
| `post-gpu-verification.json` | 原Three r180实际tk/ao/sv Float32输出与Godot HDR RGBA16F对照96组288通道，0失败，最大.000481；覆盖UV/曝光公式/色调/伤害/低血量/ADS/flare/bloom函数，使用受控常色HDR纹理。未验证空间CA图像采样 |
| `post-downsample-verification.json` | 原Three实际j9两级输出与native HDR对照，32×16非均匀HDR梯度和300辐射亮点，经16×8、8×4两层，160像素480通道，0失败；最大绝对.01555，容差max(.003,参考值×.003) |
| `post-runtime.json` | --post-preview真实damage75到HP25、reload、两次切枪、ADS、持续交互断点、heal与retry；snapshot新增实际post参数，手动曝光1/自动0 |

原GPU参考页面 `tools/post_reference.html` 直接使用保存的Three r180引擎和原GLSL模板；采集 `tools/post_gpu_reference.cjs`，本机文件服务端口8797。fixture为 `assets/export/fixtures/post-gpu-reference.json`。原浏览器参考运行于ANGLE SwiftShader，native为RTX4070SUPER Vulkan；比较的是隔离shader数值而非相同驱动比特输出。

`evidence/native-post-composite.mp4`为12秒/1280×720/60fps，无音轨。`status-120.png`显示真实伤害红边、低血量去饱和，`status-340.png`为ADS过渡，`status-354.png`为完整ADS周边柔化，`status-700.png`为恢复/重试。初始8弹和空仓边界为受控赋值，装填/切枪/伤害/回复/断点/重试均走实际系统；传送到中继点与自动输入不代表手动通关。

复现native GPU对照：`rtk proxy env DISPLAY=:0 godot --path saltline-godot --audio-driver Dummy --display-driver x11 --script tools/verify_post_gpu.gd`，链路/缩小核分别换 `verify_post_pipeline.gd`、`verify_post_downsample.gd`。


暂停时钟回归还确认：world材质与雨使用level式世界时钟，暂停时保持，恢复只推进一个dt；天空和post的全局时间继续。`game-flow-runtime.json`新增215/245/251帧world_clock_samples验证，避免把全局时间直接恢复给海面/地面产生跳时。

## 泛光接入后的实机记录

`evidence/native-bloom-composite.mp4`为接入6级down/5级up、原streak和静态dirt后的12秒1280×720/60fps实机录像，无音轨。`bloom-080.png`为港区主视角，`bloom-120.png`为伤害，`bloom-354.png`为完整ADS，`bloom-700.png`为重试后。运行日志未出现脚本或shader错误。此录像使用既有post-preview流程，没有专门触发爆炸，因此不能据此认定爆炸附近眩光已完成验证。

## 非均匀空间核与静态污渍验证

`tools/bloom_reference.html`直接运行原Three r180和原j9/K9/J9，64×32非均匀HDR渐变加300辐射亮点，输出六级down、五级up和两遍streak。`tools/verify_bloom_gpu.gd`逐4308个RGB通道对照Godot HDR RGBA16F，全部通过，最大绝对误差.014617，预先设定容差max(.004,参考值×.006)。参考为ANGLE SwiftShader、native为RTX4070SUPER Vulkan，未要求跨驱动逐比特一致。

原ek污渍的直接程序化移植在1504个采样点中有局部差异，最大23/255，主要出现在少数圆形污迹边缘；详见`evidence/dirt-procedural-diagnostic.json`。不能把这次结果说成程序化shader完全一致。原作本身仅在初始化时生成固定512×288纹理，因此移植采用原GPU结果作为静态资产，避免跨驱动hash12浮点差异改变圆心。研究shader仍保留。

实际资产`assets/export/textures/source-dirt.rgba8`来自保存的原GLSL与原噪声，589824字节；原始读回底行优先，native加载翻转行，不应用sRGB转换。原始来源、GPU后端与SHA256见`evidence/dirt-source-provenance.json`。加载后1504采样点对照原RGBA8，最大字节误差.000008，是读取归一化值的浮点残差。此项为资产加载验证，不冒充另一次GPU滤波验证。`evidence/dirt-native.png`供检查纹理。

原空间参考fixture为`assets/export/fixtures/bloom-gpu-reference.json`，复现命令将GPU验证脚本换成`tools/verify_bloom_gpu.gd`。自动曝光已接入，35点非均匀空间测光64组对照已通过；太阳遮挡和flare已接线，MSAA边缘一致性仍待验证；原AO已接线，体积雾、运动模糊仍未完成，nk最终显示层已接入。

## 原Q9自动曝光与GPU历史

新增`source_adapt.gdshader`，由原`35844-Q9.glsl.template`与ao直接生成。读取down5，按原7×5中心权重几何平均，限制测光到[.002,40]，适应速率前两帧1、fast时.6、平时1-exp(-dt/1.5)。默认游戏每个_process调用tick一次，包括暂停期间；任务重试和resize不重置适应历史。原fast来源是截图/展示模式e.shot||e.show，普通游戏默认false。本地tick保留fast参数供诊断。

Astra Ultra核对Godot ed1daf0bf源码指出SubViewport必须至少2×2；因此两个2×2 HDR数据视口四个像素写相同数值，语义对应原1×1。注册顺序为history copy、scene/down/up/streak、adapt current、根tk。copy在本帧adapt清屏前读取其上帧结果，两个不同attachment无同pass读写。运行时只更新uniform，不使用GPU读回。首次history显式零seed，前两帧测光强制覆盖，streak第一帧按该零值的原曝光限幅工作。

原WebGL HalfFloat与RTX Vulkan直接写RGBA16F的舍入行为存在差异。180帧明暗序列中，直接写入的末值26.421875，原Three为26.59375。Astra用FP32运算+每帧HalfFloat RNE精确复现原输出，用RTZ精确复现native旧偏差。原Q9移植在store前用FP32位操作显式round-to-nearest-even，随后写入已能精确表示的half值，避免反馈积累偏差；packHalf2x16在本设备未解决此差异，未采用。

`tools/exposure_reference.html`直接运行原Q9及1×1 HalfFloat pingpong，`assets/export/fixtures/exposure-gpu-reference.json`保存180帧真实原GPU输出。`tools/verify_exposure_history.gd`运行native2×2 copy/adapt，覆盖暗/亮输入、测光上下限、不同dt及fast。`evidence/exposure-history-verification.json`显示history误差0，原HalfFloat参考差<1e-7；与无half量化的连续FP32轨迹最大差.020494是单独记录的量化累积，不能与原HalfFloat对照混淆。测试还逐像素确认2×2输出相同。35点非均匀图像测光现已另补64组原GPU对照；dt=0、resize、暂停等专门判别用例仍需补充。

太阳深度输入为实际世界/武器R32F双桥，现已接线可见性.g与原flare；MSAA边缘与源画面逐像素一致性仍待验证。当前默认自动曝光也不代表全世界材质、光照能量与原作已经校准。

`evidence/native-auto-exposure.mp4`为启用自动曝光后12秒、1280×720/60fps无音轨实机。`exposure-080/120/354/700.png`记录主视角、伤害、完整ADS和重试；`exposure-runtime.json`的11次snapshot确认uAuto=1。沿用post-preview流程，不是专门室内外明暗切换验收。运行日志无脚本或shader错误。

## 非均匀测光与可见性公式隔离验证

原参考页面新增64组20×12非均匀彩色HDR分布，包含半幅亮区、中心亮区、角落亮区和条纹，验证35点测光位置/中心权重/log均值。另有128×64合成深度图，覆盖半遮挡、.99999阈值两侧、交错遮挡、太阳圆盘在屏幕外的采样、不同aspect与历史可见性混合。`tools/verify_exposure_spatial.gd`分别比较adapt.r/.g，128通道全部通过，最大测光差<3e-18、可见性差0，详见`evidence/exposure-spatial-verification.json`。

该测试发现两个实际移植问题并修正：tDepth应使用nearest，不能以linear模糊后再做.99999阈值；Godot不允许带不同filter hint的sampler共用同一个sourceSample辅助函数，因此深度独立采样。高对比亮区边界上，RTX硬件双线性权重与SwiftShader参考不同，造成少量测光偏差；原35点位置保持不变，tLum改用显式四texelFetch双线性插值后全部对齐。

这些是原Q9在受控输入下的公式验证。实际世界/武器depth bridge现已接入并有独立GPU验证；太阳相机投影与眩光现已接入，不应把合成深度验证当成实机场景遮挡验收。

深度桥准备审查还核对了原advanced路径：world near/far=.08/900，weapon=.01/10，世界与武器之间不清深度。native武器far此前为5，现修正为10；实际太阳遮挡还须同时考虑世界与武器深度。原high质量MSAA4的深度resolve边缘需要独立图像验证。

最终采样修正后重跑180帧时间序列仍全部通过，原HalfFloat对照保持<1e-7；默认游戏实机启动120帧无脚本或shader错误，日志归档`evidence/meter-runtime.log`。此启动检查覆盖武器far=10修正，不代表完整任务通关或室内外曝光验收。

双深度桥实际实现与resize生命周期修复见[solar-depth.md](solar-depth.md)。默认游戏已绑定真实两路R32F，solar投影/可见性和flare已接线，并完成原相机公式与实机开阔/仓库遮挡验证，见solar-flare.md。

当前根显示已从tk直接输出改为tk RGBA8亮度alpha中间目标→原nk最终显示，HUD仍在独立层20。`source_composite.gdshader`保留原不透明诊断版本，实际默认游戏使用`source_composite_data.gdshader`和`source_finish.gdshader`。

默认深度已升级为MSAA逐sample capture→按原depthRange合并/选择样本0→R32F，再进原AO和太阳可见性；旧resolved world+weapon mask仅保留独立诊断组件。参见msaa-depth.md及ao-kernels.md，native栅格与软件参考差异明确单列。
