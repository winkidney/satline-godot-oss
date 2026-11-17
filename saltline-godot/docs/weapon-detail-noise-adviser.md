# 武器细节噪声：GL/Vulkan dot 融合顺序诊断

本轮已经把大幅噪声差异定位到 `dot` 内部的浮点融合顺序，并用独立 GPU 探针验证了最小修复。保留原 sin/hash/噪声插值公式，只在 native 明确执行原 NVIDIA GL 的乘加顺序；没有换随机场、放宽容差或修改原参考。顾问只新增诊断文件和本文，生产 extractor 与 shader 的修正由主线完成。

原 helper/body 与 [bundle L70384](../../artifact-rendering-study/source/extracted/bundle-1.js#L70384)、[主体 L70396](../../artifact-rendering-study/source/extracted/bundle-1.js#L70396) 逐字一致；mat3 列顺序、dn3 八角插值顺序和合成测试输入没有发现错误。验证及 SHA 记录在 [weapon-hash-analysis.json](../evidence/weapon-hash-analysis.json)。

## 决定性样本

原 case2 的 grain 直接执行 `dh3(floor(dP*2900))`，绕过 dQ 矩阵、dn3 插值、材质分支和雨滴。它的 FP32 格点为 `(4,-11,-470)`。原参考 dGr 为 `.2158203125`，旧 native 为 `-.2421875`，即 hash 分别为 `.7158203125` 与 `.2578125`。

独立探针直接上传该整数格点，逐个 shader 输出 dot、sin、乘法和 fract 的完整 32 位模式。每个 float 编码成四个 0..255 字节，跨两个 RGBA16F 像素保存，alpha 固定为 1；这些整数能被 half 精确保存，避免直接用 RGBA16F 输出角度时丢掉决定性的 ULP。

| 运算 | 原 NVIDIA GL | 原样移植的 Vulkan |
|---|---|---|
| dot | `0xc7148d4c`，−38029.296875 | `0xc7148d4d`，−38029.30078125 |
| sin(dot) | `0x3e9f1cdd`，约 .3107670844 | `0x3ea09ae5`，约 .3136817515 |
| sin(dot)×43758.5453 | `0x46547add`，13598.7158203125 | `0x46567908`，13726.2578125 |
| fract | `0x3f374000`，.7158203125 | `0x3e840000`，.2578125 |

三个独立乘积本身逐位相同，第一处分歧在 dot 的累加。`weaponRound(dot(...))` 仍保留这一差异，因为它只固定 dot 输出处的边界，没有规定 dot 内部的乘加。将 GL dot 改成逐次单独舍入，GL 也会得到旧 Vulkan 的 hash，因此“全面禁止 FMA”会改变原随机场。

把相同 angle 作为 uniform 上传后，两端 sin 在全部 15 个控制样本中逐位相同，包含 case2 的两个候选角度。不能据此证明任意角度/驱动的 sin 都相同，但已经排除 sin 实现作为本例的第一处分歧。CPU 精确 sin 不等同该 GPU 内建的近似 sin，不能用 CPU libm 替换它；本轮也未这样做。

## 最小修复与实测

枚举嵌套 FMA 顺序后，原 GL 的受测结果对应：先舍入 x 乘积，再融入 y，最后融入 z。

```glsl
// dh3 的 dot
fma(p.z, 74.7,
    fma(p.y, 311.7, weaponRound(p.x * 127.1)))

// dh2 的两个 dot
fma(p.y, 311.7, weaponRound(p.x * 127.1))
fma(p.y, 183.3, weaponRound(p.x * 269.5))
```

这里继续保留已有的 hash 输入、dot 输出、sin 输出和最终乘法运行时零 guard。只替换 dot 的执行顺序，其余常量、sin、fract、dn3、dDrops、材质方程不变。Godot 本身已有 fma 内建，无需引擎补丁。不能把该修复推广成所有旧噪声都应统一融合；此前 wet hash 需要限制融合，这是两个不同源表达式的实际编译结果。

第一轮包含 15 个格点/角度控制、20 种表达式，共 300 个 GL/Vulkan float32 比较，原样路径有 44 项位差，均落在 dot 及其下游。增加显式 FMA 后，15 个格点的 dot、sin(dot)、hash 共 **45 项逐位匹配原 GL**；统一 uniform angle 的 15 个 sin 控制也全部逐位相同。[GL 原始读回](../evidence/weapon-hash-gl-diagnostic.json)、[Vulkan 原始读回](../evidence/weapon-hash-native-diagnostic.json)

独立 [FMA 材质诊断](../evidence/weapon-detail-fma-diagnostic.json) 使用原 96 cases、1536 channels，全部通过原 `.001 / relative .0015` 门槛，最大绝对差约 `5.96e-8`。主线随后修改 extractor 并重新生成生产 shader，[生产验证](../evidence/weapon-detail-verification.json) 也得到同样的通过结果。初始失败和只加 guard 的失败仍分别保留在 [initial numeric failure](../evidence/weapon-detail-initial-numeric-failure.json) 与 [dot order failure](../evidence/weapon-detail-dot-order-failure.json)。

以上对齐对象是本项目原 NVIDIA GL 参考和当前 RTX 4070 SUPER Vulkan。不能仅凭这些样本宣称所有驱动的 sin 或 FMA 路径都逐位等同；更换 canonical backend 后仍应保留该 GPU 对照。

## 诊断文件与复跑

- [weapon_hash_diagnostic.json](../tools/weapon_hash_diagnostic.json)：格点、统一 angle 和操作表达式；额外 FMA 项标为 native_only。
- [weapon_hash_diagnostic.html](../tools/weapon_hash_diagnostic.html) 与 [collector](../tools/weapon_hash_diagnostic_collect.cjs)：用原 bundle 的 Three 在现有 NVIDIA GL 会话采集字节编码结果。
- [verify_weapon_hash_diagnostic.gd](../tools/verify_weapon_hash_diagnostic.gd)：同输入 Vulkan 字节编码探针。
- [weapon_detail_fma_probe.gdshaderinc](../shaders/weapon_detail_fma_probe.gdshaderinc) 与 [verify_weapon_detail_fma_diagnostic.gd](../tools/verify_weapon_detail_fma_diagnostic.gd)：独立 FMA 候选，不引用已修正生产 helper 来替代其诊断输入。
- [analyze_weapon_hash_diagnostic.py](../tools/analyze_weapon_hash_diagnostic.py)：仅使用 Python 标准库，合并原始数据、检查抽取内容、输出位匹配与 SHA；不重写原材质参考。

```sh
rtk proxy env DISPLAY=:0 python3 artifact-rendering-study/tools/collect_browser.py saltline-godot/tools/weapon_hash_diagnostic_collect.cjs --session salt-pmrem-gpu --name weapon-hash-adviser-metadata
rtk proxy env DISPLAY=:0 saltline-godot/tools/run_native.sh --disable-low-processor-usage-mode --script tools/verify_weapon_hash_diagnostic.gd
rtk proxy env DISPLAY=:0 saltline-godot/tools/run_native.sh --disable-low-processor-usage-mode --script tools/verify_weapon_detail_fma_diagnostic.gd
rtk proxy python3 saltline-godot/tools/analyze_weapon_hash_diagnostic.py
```

GPU/browser 命令需使用有 DISPLAY 和真实 GPU 权限的执行环境。原始浏览器导出同时保留在 `artifact-rendering-study/evidence/runtime/weapon-hash-gl-diagnostic.json`；分析脚本将其复制到本项目 evidence，并记录两端 backend。

## 真实武器集成复审

当前六个 D_KIND 材质对应十三个普通 Mesh，使用 position/normal/color/aSurf，没有 skin/morph、normalMap、roughnessMap、AO、alphaTest 或 SL_FX。对这个实际集合，未发现坐标、normal 属性或执行顺序的实质错误。

[source_scene.gd](../scripts/source_scene.gd#L123) 将 aSurf 保存到 CUSTOM0，并将原 FP32 normal 保存到 CUSTOM2。vertex 在 D_KIND 启用时恢复 NORMAL，再保存 object normal 和 `normalize(mat3(MODEL_MATRIX)*NORMAL)`。这与原 [vertex patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L70507) 一致：世界法线在 vertex 归一化，fragment 读取插值后的 y，不再归一化；不能换成最终 bump normal、MODEL_NORMAL_MATRIX 或 fragment 归一化世界法线。由于这十三个对象没有蒙皮，恢复 CUSTOM2 不会覆盖已经蒙皮的法线。

surface 在顶点色/instance color 已乘入之后、光照之前处理 base/roughness/metalness；bump 使用原 view-space position，先归一化输入 normal，并位于 normal map 之后。扰动前 normal 已提前保存，仍负责 geometryRoughness。当前实际材质没有 normal map；如果以后扩展 D_KIND 与 normalMap/SL_FX 组合，要重新核对 roughness 抗锯齿与 surface 的先后，不能把当前六材质的验收视为所有组合都等价。[原 surface/bump 注入](../../artifact-rendering-study/source/extracted/bundle-1.js#L70520)

cavity 的四项权重分别为 indirectDiffuse×occ、indirectSpecular×occ²、directDiffuse×mix(1,occ,.35)、directSpecular×mix(1,occ,.6)，并且不修改 emission；这与原 [cavity patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L70485) 一致。审查时发现两个 generic shader 把间接镜面写成 `(specular*occ)*occ`；原式是 `specular*(occ*occ)`。主线已加括号，复读生产文件确认修正。这不是本轮巨大噪声差异的来源。

`update_weapon_wetness` 初值 1、室内目标 .3、室外目标 1、速度 .25/.6、dt 上限 .05，同时更新六个 gun 材质和 arms，且在暂停时继续运行，符合原 [湿度更新](../../artifact-rendering-study/source/extracted/bundle-1.js#L86048)。室内选择仍用首个 box 的严格 x/z 边界与 y<max，没有额外 y 下界。

已读取主线的 [runtime 验证](../evidence/weapon-detail-runtime-verification.json)：十三个 mesh 的 aSurf 共 674256 channels 与原数据逐字节相同，十三个原 FP32 normal 也逐字节相同；四个 playing/paused、inside/outside 湿度状态误差为零，修复后实际 weapon detail on/off 改变 15501 个 HDR 抽样点。[空间 bump 验证](../evidence/weapon-bump-spatial-verification.json) 的 32 cases、98304 channels 无失败；它覆盖平面梯度和内部像素，不覆盖原网格的透视插值或完整过程高度场。本轮顾问没有重复运行这些实验。

噪声 kernel 的全部通过不代替顶点属性、导数、真实 BRDF 或整场景视觉等同证明，各项证据继续保持独立范围。目前六材质、十三个实际 mesh 的接线未发现剩余阻断缺陷。
