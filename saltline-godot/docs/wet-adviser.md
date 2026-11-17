# 原湿度噪声的 GPU 数值诊断

本次先审查原 `pk/mk/gk`，随后按主线追加授权新增独立 GPU 诊断工具。未修改生产 shader。结论基于 2026-11-15 的原源码、NumPy 2.4.4 逐操作 float32 复算和 RTX 4070 SUPER Vulkan 实测。CPU 计算只用于定位运算差异，最终验收仍使用原 Three GPU 参考。

## 当前判断

已定位两层运算重排。`slH` 内部的融合和重新结合会改变 hash；内联到 `slN3` 后，调用点 `(floor(x)+corner)*c` 又出现与 `float32(floor(x)*c)+float32(corner*c)` 一致的结果。完整内部屏障加 hash 入口屏障后，原 48 cases、768 通道全部通过，最大绝对误差 `.00048828125`，容差仍为 `.001`。

公式本身一致，首乘加只差 1 ulp 就能把单个 hash 从 `.828125` 改成 `.615234375`。高频 bead 又经过宽度仅 `.08` 的 smoothstep，最终出现 `.18` 级差异是合理的数值放大。RGBA16F 写入误差解释不了这种幅度。推荐共享 `slH` 的运行时 uint guard 实现，保留原 hash、频率、插值和阈值，无需引擎补丁。真实空间材质仍需另做验收。

## GPU 实验结果

独立 RD 和 canvas 的单 hash 探针覆盖原 48 profiles 中使用的 1016 个不同噪声格点。RD 同时保留只输出最终值和输出 18 个阶段的两个独立 pipeline。

| RD 版本 | 最终 hash 与逐步 float32 位型不同的格点 | 18 阶段的不同位型总数 |
|---|---:|---:|
| 普通公式 | 812 / 1016 | 572 / 18288 |
| 仅首乘法 guard | 617 / 1016 | 572 / 18288 |
| 完整内部 guard | 0 / 1016 | 0 / 18288 |
| GLSL precise | 0 / 1016 | 0 / 18288 |

普通版本输出各阶段后，最终 hash 只剩 146 个格点不同，原来的 812 个不同不能从这个插桩版本直接重现。这说明输出中间值会约束优化，必须保留独立 final-only 对照。[RD 证据](../evidence/wet-hash-precision-verification.json)

相同完整内部 guard 在 canvas 单 hash 探针也通过 1016 个格点，但放回 `slN3` 后，336 个实际噪声坐标的最大差异仍为 `.643949314951897`。仅在 hash 函数入口增加 `p=R3(p)`，最大噪声误差降到 `1.1920928955078125e-7`，剩余差异来自插值最后几位。[Canvas hash](../evidence/wet-canvas-hash-verification.json)、[Canvas noise](../evidence/wet-canvas-noise-verification.json)

将 CPU 角点乘法改成 `float32(base*c)+float32(corner*c)`，能复现 native 无入口屏障版本的全部 336 个噪声结果，最大差异也是 `1.1920928955078125e-7`。原括号顺序与该版本有 75 个噪声点相差超过 `1e-6`。这支持乘法分配和公共子表达式复用改变舍入的解释；尚未做 NVIDIA 机器码反汇编，不能声称已观察到具体机器指令。[分配重排拟合](../evidence/wet-hash-distribution-analysis.json)

完整湿度公式的六个独立 canvas 变体与未改像素值的原 Three fixture 对照如下：

| 版本 | `.001` 门槛下失败通道数 / 768 | 最大绝对误差 |
|---|---:|---:|
| 原普通 hash | 48 | .18780517578125 |
| 仅首乘法 guard | 40 | .2275390625 |
| 完整内部 guard，无入口 guard | 36 | .2275390625 |
| 完整内部 guard，加入口 guard | 0 | .00048828125 |
| 仅首乘法 guard，加入口 guard | 12 | .0478515625 |
| 去掉 affine 加法后及 fract 后两道 guard，保留入口及其余内部 guard | 0 | .00048828125 |

最后两行说明入口 guard 必需，但它不能单独替代内部屏障。保留完整版本作为首个生产候选；简化版本只证明这 48 cases 通过，后续应扩大坐标范围并测量成本再决定是否使用。[完整变体及 shader 原文](../evidence/wet-guard-variants-verification.json)

## 已核对的源码和参考边界

- 原 `pk.slH/slN3` 位于 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js#L39377) 的 39377–39382 行。修复前四个 generic shader 中同名函数的运算顺序、常量和八角插值一致；只存在空白及 `1`/`1.0` 这类可精确表示的字面量差异。
- 原 `mk` 湿度准备在 39395–39443 行；bead 两个频率为 170 和 410。最终颜色在 39454–39458，`gk` roughness 在 39471–39482。当前参考只覆盖湿度准备，不覆盖最终颜色、roughness、真实几何导数或最终材质画面。
- [wet_reference.html](../tools/wet_reference.html) 的湿度主体来自原 `mk` 提取文件，`slH/slN3` 最初由生产文本复制。主线已改为直接读取原 `pk` 字面提取，48 cases 重采全部像素与旧 fixture 完全相同，并记录实际后端为 ANGLE Vulkan SwiftShader。原像素参考没有随 native 修复改变。[参考独立性证明](../evidence/wet-reference-independence.json)
- 原参考先 `normalize(vNormal)`，再由 `inverseTransformDirection` 再次 normalize。native 隔离探针直接传 `uNormal`。即使输入理论上单位长，也应让两边使用同一预处理并记录 float32 输入位型。该差异可能影响最后几位，不能解释 case 7 的大 bead 差异。
- 原低处积湿写成 `smoothstep(.5,0,y)`，native 写成 `1-smoothstep(0,.5,y)`。两者数学意图相同，但原反向端点属于 GLSL 未定义输入，不能凭代数就宣称跨驱动逐位相同。先保留原 GPU 结果作为参考；若要严格固定实现，可在单独探针中验证原实际行为。case 7、15、31、39 的 `y=.54`，低处项为零，排除它是这些失败的主要来源。[GLSL 4.60，第 8.3 节](https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.pdf)
- 当前 probe 的 `blend_disabled`、透明 HDR viewport 已由主线修正。不要再次把大误差归因于 alpha 混合。参考目标是 HalfFloat，native 也读 RGBA16F；逐操作诊断应使用 float32 或 uint 位型，避免 half 写出隐藏首个差异。

初始报告的 48 cases、768 通道中，有 10 个 case 的最大绝对误差超过 `.001`，分别为 7、15、29、31、33、34、37、38、39、43。报告的 `failures` 只保留前 20 条，且 2×2 相同像素重复记录；不能把 20 当成完整失败通道数。初始最大误差是 case 39 的 `.18780517578125`。

## 已得到的数值证据

CPU 诊断把每次加、减、乘及赋值显式转成 `np.float32`，hash 乘积和求和保持源码左结合，噪声使用相同八个角、平滑权重与 mix。48 个 bead 与既有原 GPU half 输出比较，全部低于 `.001`，最大约 `.0000976`。下表为未量化成 half 的 CPU 输出。

| case | 原 GPU bead | 分离乘加的 CPU float32 | 仅 hash 首乘加改成 FMA |
|---:|---:|---:|---:|
| 7 | .19970703125 | .1996789 | .0157619 |
| 29 | .00587463379 | .0058755 | .0317117 |
| 33 | 0 | 0 | .0501635 |
| 39 | .08514404297 | .0851173 | .2750672 |

仅融合首乘加后，48 个 bead 有 7 个超过 `.001`。case 29、33 已接近 native 失败值 `.0317687988`、`.0501708984`；case 7、39 尚有余差，说明不能只靠这个复算便认定全部 GPU 操作顺序。模拟 FMA 用 float64 计算两个 float32 操作数的乘加后只舍入一次；这里有限、同量级的输入足以区分首乘加。

最小放大案例来自 case 7 的 `p*170` 噪声角点 `(22,92,1)`：

| 阶段 | 分离 float32 乘加 | FMA |
|---|---|---|
| affine x 的位型 | `0x40f6cf68` | `0x40f6cf67` |
| affine y 的位型 | `0x41eb2e1b` | `0x41eb2e1a` |
| affine z 的位型 | `0x3f3cc058` | `0x3f3cc058` |
| 最后乘积，fract 前 | `32239.828125` | `32239.615234375` |
| hash | `.828125` | `.615234375` |

可复制的 NumPy 核心复算如下；它只验证上述角点，不替代 GPU 验收：

```python
import numpy as np
F = np.float32
p = F([22, 92, 1])
c, offset = F(.3183099), F([.71, .113, .419])
for fused in (False, True):
    q = F(p.astype(np.float64) * np.float64(c) + offset.astype(np.float64)) if fused else F(F(p*c)+offset)
    affine_bits = q.view(np.uint32).copy()
    q = F(F(q-np.floor(q))*F(17))
    xy = F(q[0]*q[1]); xyz = F(xy*q[2])
    total = F(F(q[0]+q[1])+q[2])
    product = F(xyz*total)
    print(fused, [hex(int(v)) for v in affine_bits], product, F(product-np.floor(product)))
```

## 第一轮最小原始参考与 GPU 探针

先从原 bundle 字面提取 helper 和湿度主体。以下 JavaScript 不从生产 shader 读取任何噪声代码；`source` 是现有 HTML 已 fetch 的原 bundle 字符串：

```javascript
const pkMatch = source.match(/\bpk\s*=\s*`([\s\S]*?)`,\s*mk\s*=/);
const mkMatch = source.match(/\bmk\s*=\s*`([\s\S]*?)`,\s*gk\s*=/);
if (!pkMatch || !mkMatch) throw new Error("Original pk/mk boundary changed");
const pk = pkMatch[1], mk = mkMatch[1];
const start = pk.indexOf("float slH(");
if (start < 0) throw new Error("Original noise helper missing");
const originalNoise = pk.slice(start); // slH and slN3, unchanged
const fxStart = mk.indexOf("#ifdef SL_FX\n");
const fxEnd = mk.indexOf("\n#if SL_TINT == 1\n  diffuseColor", fxStart);
if (fxStart < 0 || fxEnd < 0) throw new Error("Original wet block changed");
const originalWet = mk.slice(fxStart, fxEnd);
if (originalWet.split("fwidth(vSlPos)").length !== 2) throw new Error("Unexpected derivative replacement count");
const controlledWet = originalWet.replace("fwidth(vSlPos)", "uFootprint");
// Shader header defines SL_FX and the selected SL_TRIPLANAR / SL_TINT.
// Only the explicit test footprint differs from originalWet.
```

字面参考与旧 48 cases 的一致性现已由主线确认。新增 float32 诊断目标时继续记录 renderer/vendor、Three revision、GLSL 精度、扩展、uniform float32 位型及源码 SHA；不要根据另一个 fixture 推定本次后端。

GPU 最小输入先用 `(22,92,1)`。原 WebGL 以 `FloatType`/RGBA32F 目标读 `Float32Array`，native RD compute 写 SSBO uint 位型。诊断 readback 仅在工具中进行。两个后端都输出以下阶段，找第一个不同的位型：

1. `p`、`p*.3183099`、加 offset 后的 affine、fract、乘 17 后的三个分量。
2. `x*y`、`(x*y)*z`、`x+y`、`(x+y)+z`、最终乘积及 fract。
3. 48 个 case 的 `p*170`、`p*410+5` 的 floor/fract，八角 hash，以及两个 `slN3`、原始 `slB`、smoothstep 后 bead。
4. case 15/31 的三路 streak 噪声、相乘值与两个 smoothstep，再读最终 wet。

阶段输出会让中间结果变得可观察，可能改变原 shader 的优化。每个版本必须同时输出未经插桩的最终 hash/noise/wet，并保留原始最终颜色探针做回归。优先三个独立 shader/pipeline，避免 `precise` 或公共子表达式影响同 shader 中的对照版本。

## 首选局部运行时屏障

普通 `floatBitsToUint` 再 `uintBitsToFloat` 是可消除的恒等式。增加非编译常量的 uint uniform 后，整数运算建立真实数据依赖。运行时将 guard 设为零，数值仍是原 float32；必须保留该 uniform 为普通材质参数，不能改成 const、宏或 specialization constant。

```glsl
uniform uint source_round_guard = 0u;

float slRound32(float x) {
    return uintBitsToFloat(floatBitsToUint(x) + source_round_guard);
}
vec3 slRound32v(vec3 x) {
    return uintBitsToFloat(floatBitsToUint(x) + uvec3(source_round_guard));
}
float slH(vec3 p) {
    p = slRound32v(p); // 必需：固定调用点的格点坐标，阻止分配重排。
    vec3 q = slRound32v(slRound32v(p * .3183099) + vec3(.71,.113,.419));
    q = slRound32v(fract(q));
    q = slRound32v(q * 17.0);
    float xy = slRound32(q.x * q.y);
    float xyz = slRound32(xy * q.z);
    float sx = slRound32(q.x + q.y);
    float total = slRound32(sx + q.z);
    return fract(slRound32(xyz * total));
}
```

上面的完整版本已在独立完整湿度 shader 中通过。它与最初失败的完整内部版本只有入口 `p=slRound32v(p)` 这一处关键差别。无需改整个 slN3 或使用整数软件浮点替代原噪声。bead 每点会调用两个八角噪声，非 triplanar 还调用 streak 噪声，屏障有真实成本，应在正确性固定后测量。

预期编译链是 `OpFMul → OpBitcast → OpIAdd → OpBitcast → OpFAdd`。RD 工具将生成的 GLSL 和 SPIR-V 存在 `/tmp/saltline-wet-*`，可继续反汇编核对。现有证据已验证 RTX 4070 SUPER 的行为，但不是跨驱动保证。guard=0 的材质参数要覆盖所有 generic material 和 probe，避免意外非零改变浮点位型。

验收顺序为角点位型、48 case 原门槛、4 generic 的真实网格材质。真实网格还需要覆盖大/负世界坐标、三平面 rest 坐标、导数过滤、正背面和室内系数。隔离探针通过不等于完整湿材质图像已验证。

## 后备 precise 路径

原版 Godot `ed1daf0bf001b61586d9930840f2f1394092c079` 的 gdshader 没有 `precise` 或 `no_contraction` 限定符，也没有相关 render mode。`highp` 不禁止 FMA。[限定符注册](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/shader_language.cpp#L333-L337)、[spatial render modes](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/shader_types.cpp#L238-L260)

无需先改引擎，可在 `RDShaderSource` 的 GLSL450 compute 中测试以下三个独立 pipeline。输入来自 SSBO，避免常量折叠，输出 `floatBitsToUint` 到 SSBO，避免 half 下溢：

| 运算 | a / b / c | 预期位型 |
|---|---|---|
| 普通 `a*b+c` | `0x3f800001` / `0x3f7ffffe` / -1 | 观察后端选择 |
| `precise float r=a*b+c` | 同上 | `0x00000000` |
| `fma(a,b,c)` | 同上 | `0xa8800000`，即 `-2^-46` |

实际 hash 的 `precise` 应声明在函数内部；只在调用者写 `precise float h=slH(p)` 不保证函数体受约束。若 guard 方案无法可靠通过，再考虑新增独立 `TK_PRECISE` 和局部声明标志，解析后仅对这些声明输出 GLSL `precise`。不应把它混入 `DataPrecision` 或改全局浮点优化。[节点结构](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/shader_language.h#L447-L465)、[局部声明解析](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/shader_language.cpp#L8038-L8136)、[GLSL 声明生成](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/shader_compiler.cpp#L837-L867)

Godot 使用 glslang 将生成的 GLSL 编成 SPIR-V；其 precise 路径可输出 `NoContraction`。只拆临时变量、加括号或给 C++ 编译器设置 `-ffp-contract=off`，都不能代替 GPU shader 约束。[编译入口](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/modules/glslang/register_types.cpp#L98-L134)、[NoContraction 转换](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/thirdparty/glslang/SPIRV/GlslangToSpv.cpp#L525-L531)、[GLSL precise 语义，第 4.9 节](https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.pdf#page=108)

## 本次读取的来源指纹

以下是最初读取的参考指纹。主线后来只向 `wet-reference.json` 加入原 helper 来源和后端元信息，像素不变；新的完整文件指纹以参考独立性证明为准。

| 文件或提取段 | SHA-256 |
|---|---|
| `artifact-rendering-study/source/extracted/bundle-1.js` | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 原 pk 自 `float slH(` 到模板末尾 | `b10914a86198232b3f80c9150204e040fede90f467b36800656e2b10683f4ccf` |
| `assets/export/fixtures/wet-reference.json` | `ab0ad3b07b49e690ce4ed9f4a5c7374ba3031130680fc8dd7383ce792aa2691d` |
| `assets/export/fixtures/source-wet-original.glsl` | `32d9c6a28c03593e168dcc39b73f23b0e2e83d781d8a13833406bb587680d710` |
| `shaders/source_wet_surface.gdshaderinc` | `6710218ee985dd4cbddc4c45f960c337c6dfbe71b877cad0ab716c80bb5fa316` |

## 诊断复跑

需要 NumPy；本次为 2.4.4。以下工具只写各自诊断证据，不覆盖原 Three fixture。GPU 工具需要真实 Vulkan 显示设备，不能用 dummy headless renderer。

```sh
rtk proxy python3 saltline-godot/tools/wet_hash_precision_reference.py
rtk proxy sh saltline-godot/tools/run_native.sh --script res://tools/verify_wet_hash_precision.gd --resolution 64x64 --log-file /tmp/saltline-wet-hash-gpu.log
rtk proxy sh saltline-godot/tools/run_native.sh --script res://tools/verify_wet_canvas_hash.gd --resolution 64x64 --log-file /tmp/saltline-wet-canvas-hash.log
rtk proxy sh saltline-godot/tools/run_native.sh --script res://tools/verify_wet_canvas_hash.gd --resolution 64x64 --log-file /tmp/saltline-wet-canvas-noise.log -- --noise
rtk proxy sh saltline-godot/tools/run_native.sh --script res://tools/verify_wet_guard_variants.gd --resolution 64x64 --log-file /tmp/saltline-wet-guard-variants.log
rtk proxy python3 saltline-godot/tools/wet_hash_distribution_analysis.py
```
