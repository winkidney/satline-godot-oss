# 原AO深度与滤波内核阶段

本阶段先完成隔离验证，随后已接入默认游戏并**替换过渡Godot SSAO**。原Q9/R32F深度抽样、X9 AO12与QM两遍双边模糊均已移植并有原Three实际GPU对照；全场景使用已验证的原逐sample合并/样本0算法；native与软件参考的MSAA边缘差异单独记录。

## 真实格式与坐标

原脚本36112–36128在EXT_color_buffer_float可用时将depthHalf分配为FloatType+RedFormat，即R32F，nearest；AO A/B是UnsignedByte RGBA8，nearest。AO、横模糊和纵模糊每次都量化到8位，不能以HDR浮点blur代替。[Astra依据与MSAA方案](ao-depth-adviser.md)包含逐项源码。

原q9用gl_FragCoord转整数后乘2，按源纹理左下坐标texelFetch，half尺寸为ceil(full/2)。native输出p的源top-origin行是H-1-2*(ceil(H/2)-1-p.y)：偶数高选2y+1，奇数高选2y，不能统一取2y。`scripts/half_depth_bridge.gd`使用独立R32F compute输出保留这条规则，继承solar bridge仅复用GPU目标生命周期，不复用其距离语义。

它对真实world forward-depth执行原near*far/(far-d*(far-near))，worldD<.05或完整weapon mask命中时输出原.01 sentinel；mask只决定bypass，从不当距离计算。初始化clear为far值且保留ready状态。near/far默认.08/900。该分类等价性只适用于单样本/完整覆盖，未宣称MSAA边缘成立。

## 实际GPU对照

`tools/ao_reference.html`直接用原Three r180运行原q9 Float32输出，再以原X9 AO_TAPS=12与QM BLUR_TOL=.04运行三次RGBA8/nearest输出。输入64×32、65×33、17×9、8×8，含斜坡、距离阶跃、天空、worldD<.05和武器sentinel区域。fixture为`assets/export/fixtures/ao-gpu-reference.json`。

`tools/verify_ao_gpu.gd`在真实Compositor callback中运行nativeR32F compute，由后续AO8/blur8视口直接取样，验证四组尺寸和重新分配。`evidence/ao-gpu-verification.json`全部通过。深度最大绝对差.00006104，AO/横blur/纵blur最大差1色阶；深度容差max(1e-5,原值×2e-5)，AO阈值1.01字节。原参考ANGLE SwiftShader、native RTX4070SUPER Vulkan。R32F避免了半精度在远处吞噬深度细节。

`source_ao.gdshader`保持原中心早退、邻居/spiral sentinel参与与法线选择；Godot不允许fragment直接return，因此包入普通返回vec4函数，公式不变。blur不额外排除weapon邻居，每一pass保持8位量化。`ao-kernel-native.png`与`ao-blur-native.png`保存65×33输入对应半分辨率结果。`ao-gpu.log`无SCRIPT/SHADER/GPU错误或泄漏。

共享GPU资源基类增添可覆盖compute源和初始化clear值后，既有太阳双深度桥11帧、透明/cutout/resize首帧回归仍通过，见`ao-solar-regression.log`。原AO现已接默认pipeline，实际仓库开关对照及720帧游戏回归见下文。

## 深度合并与剩余边界

原MSAA先逐sample合并world与depthRange(0,.05)武器，再resolve。旧solar resolved world/二值mask不足以保留该语义，现已由实际MSAA sample数组和组合R32F替代。默认使用原样本0算法与native正常栅格，参考后端样本位置/子像素精度差异记录在msaa-depth.md，不假装逐像素全等。原joint-bilateral composite已接；体积光仍需原shadow map/matrix等输入，没有以无阴影环境fog替代。

## 默认接线与实际画面

原逐sample组合深度现由R32F数组capture和combined_depth_bridge提供，不再以二值mask重建默认AO距离。half_depth_bridge.combined_source分支直接线性化这张组合深度并保留d<.05 sentinel；原有world/mask分支仅供既有隔离fixture。MSAA工程取舍与165例证据见[msaa-depth.md](msaa-depth.md)。

默认顺序是world/weapon sample captures→combined R32F→half R32F→原AO12/AO8横blur/AO8纵blur→原$9 joint-bilateral HDR scene→bloom/测光→tk→nk。$9保留slExposure相关亮处衰减、冷色AO和武器bypass；vol仍明确关闭。3D世界环境Godot SSAO只在非游戏旧诊断入口保留，默认游戏关闭，避免叠乘。

原$9 composite另以相同原DepthHalf/AO8输入做Float32参考对nativeRGBA16F隔离对照，四组全部通过，最大.001419，容差max(.002,参考×.003)。整条native AO链因为上游8位输出可差1色阶，传播后的合成最大差.004215，单独记录，没有当作隔离公式失败放宽容差。实际窗口resize还验证combined/half/AO/scene尺寸、FOV/aspect更新和同帧HDR，日志无ERROR。

`--ao-preview`冻结dt、场景时间和film grain，在同一仓库走道视角前120帧关闭原AO、后120帧启用。`ao-runtime.json`显示GodotSSAO=false，两路MSAA4、combined/half ready；关闭时HDR亮度比1，启用时抽样平均比.85946，5064个抽样像素下降超过2%。`ao-100.png`与`ao-220.png`是原生截图，`native-source-ao.mp4`为4秒720p/60fps无音轨的开关录像。相机受控移动，HUD玩家位置未随诊断相机传送，不代表人工游戏验收。

默认720帧post-preview装填、切枪、ADS、伤害/低血量与retry回归完成，`ao-game.log`及`ao-game-runtime.json`归档。与源原shader比较仍保留native栅格化差异，不声称整个场景逐像素全等。体积光、运动模糊及其他材质/照明校准仍未完成。

逻辑分辨率resize补充：原canvas_items固定画布时改变窗口仅缩放显示。隔离测试显式关闭固定画布后，实际目标从1280×720变为960×540、half从640×360变为480×270；确认输出格式/尺寸与同帧HDR，零ERROR。未以纯窗口缩放冒充渲染目标重建。
