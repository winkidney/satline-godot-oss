# PMREM HDR 补采与历史快照来源核对

本报告只审查原源码、导出工具和已有数据，不改运行代码，也没有另开或操作共享浏览器。主线完成 NVIDIA headed 补采后，两张 HDR 纹理在旧快照可比较的 clamp/UNORM8 范围内均最大只差 1 byte，差值 >1 的通道为零。应优先采用这组原 GPU 数据。完整环境 IBL 集成尚未由本报告验证。

## 当前结论

继续调整 `step=1/3` 或比较最终 `time=.050000001/.05` 不能解释主要差异。源码把任何 truthy `step` 都变成启动后运行三帧；两张 PMREM 都在这三帧之前生成。旧导出也没有给 PMREM 加 tone mapping 或 sRGB 编码。

主线完成了同一冻结实例的三路径对照：旧 `texture2D → RGBA8` 与新 `texelFetch → RGBA8` 最大只差 1 byte，`texelFetch → RGBA8` 与 clamp/量化 `texelFetch → RGBA32F` 完全相同。软件后端生成的数据与历史快照仍差 17/253 byte，因此主要差异在 PMREM 内容生成阶段。

随后在与历史记录一致的 NVIDIA OpenGL ES 后端重采，两个最大 byte 差都降到 1。这把本轮问题定位为跨后端生成差异，不能继续将旧快照与 SwiftShader 的偏差当成新 HDR 导出错误。

## 应采用的原 GPU 数据

权威来源是 [pmrem-gpu/manifest.json](../assets/export/environment/pmrem-gpu/manifest.json)，backend 为 `ANGLE (NVIDIA Corporation, NVIDIA GeForce RTX 4070 SUPER/PCIe/SSE2, OpenGL ES 3.2)`，URL 参数为原 `q=high&shot=1&noaudio=1&step=1&dt=.016666667`。

| 原 GPU 捕获 | 天空 768×1024 | 室内 384×512 |
|---|---:|---:|
| RGB 最大值 | 6 | 382.25 |
| RGB >1 的通道数 | 19326 | 2003 |
| clamp/量化后与历史 byte 最大差 | 1 | 1 |
| 差值 >1 的通道数 | 0 | 0 |

本顾问重新读取两个文件计算，确认上述 byte 比较结果，且全部 float32 值均可精确往返 FP16。两个 HDR 文件 SHA-256 分别为 `fd13d68f22081e25f073394f91a835acbc5bd8a58dd073f3f390bba828a12e9f` 和 `3a15e203389b7c62d213d9f909a48d1bea8dfd17346828ccdffb0401332ee530`。实际 `saltline.original.html` 文件 SHA-256 为 `b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb`，与新 manifest 相同。

采用这组直接捕获的 HDR 值作为后续环境 IBL 输入，保留旧 RGBA8 和 SwiftShader 捕获作为历史及跨后端证据。byte 比较只证明可比较范围的一致性；大于 1 的历史真实值无法从旧 byte 反推，新 HDR 高光来源是本次原 GPU 运行时直接读取。

## 两张纹理的生命周期

原始来源均为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。

| 纹理 | 历史 ID / 尺寸 | 创建与更新 |
|---|---|---|
| 天空 PMREM | `30c27fd2-4d7a-42ce-8e91-2cd36adb3c40`，768×1024 | `YM` 在 35476–35485 克隆天空 uniforms，设 `uEnv=1`，调用 `PMREMGenerator.fromScene`；renderer 初始化 36783–36786 调用一次。天空此时 `uTime=0`。 |
| 室内 PMREM | `e44868bb-2bd3-41d6-978b-02a02fedbdf3`，384×512 | `J()` 在 37191–37248 建立 128 HalfFloat CubeRenderTarget、CubeCamera near=.15/far=300，采集主场景后 `fromCubemap`。`onLevelReady` 的 37064–37067 调用，boot 的 85942 在 shot/game.start 和 RAF 前触发。 |

室内捕获位置由第一个 `interiorBoxes` 决定，x/z 取包围盒中心，y=`min.y+min(2.4,height*.4)`。CubeCamera 限定 `Ia` 世界层，捕获时暂时关闭 tone mapping、将天空 `uEnv` 设为 1，并令 shadow map 更新；最后恢复天空和 renderer 状态。捕获结果赋给 `userData.interior===true` 的材质 envMap。

`captureInteriorProbe` 在 bundle 中被暴露为方法，但没有逐帧重捕获调用。37139 附近更新的是屏幕天空状态，不能据此认定旧 PMREM 已随三帧时间更新。

`step` 的关键代码是 85975 的 `n.step && (window.__step = 3)`，随后 85990–85991 每次 RAF 消耗一次。`step=1` 和 `step=3` 都是非空字符串，行为相同。shot 的游戏启动在 85960，晚于室内 probe 捕获。

场景 RNG 也不是首要嫌疑。boot 85808 使用 `su(+(seed||4207))`；level `uw` 在 48043 从 `n.rng.fork()` 派生。缺省 seed 与显式 4207 等价。天空噪声在 35320–35342 使用独立固定种子。源码确有其他 `Math.random` 调用，但没有证据证明它们改变这两张静态捕获。

显式 `q=high` 优先于 shot 的默认 test quality，见 85810。两次捕获均为 high，因此也不能用 shot 默认 quality 解释当前差异。

## 旧导出实际做了什么

[export_source.cjs](../tools/export_source.cjs) 的 70–83 行将每张二维纹理画到同尺寸默认 UnsignedByte render target，再读取 RGBA8。Shader 使用 `texture2D(tex,v)`，`toneMapped:false`。只有 `tex.colorSpace===T.SRGBColorSpace` 才执行自写 sRGB 编码。

两张历史 PMREM 元数据均为：

- `type=1016`，即 HalfFloat；`colorSpace='srgb-linear'`，导出 `encode=0`。
- `wrapS=wrapT=1001`，ClampToEdge；`minFilter=magFilter=1006`，LinearFilter。
- `flipY=false`，repeat=(1,1)，offset=(0,0)，rotation=0。
- raw 文件按 framebuffer 的 bottom-to-top 行序写出。

因此旧流程是线性 HDR 纹理采样后写入 RGBA8，超过 1 的值丢失。它不是经过最终色调映射的环境图，也没有使用 PMREM 的 roughness 选择逻辑。PMREM 的粗糙度层打包在 cubeUV atlas 中，旧 sampler 的 LinearFilter 不会自动选择这些 atlas 区域；这里也不能用“自动 mip 降采样”直接解释差异。

旧 `texture2D` 仍包含插值与 varying UV，而新 [export_pmrem_hdr.cjs](../tools/export_pmrem_hdr.cjs) 以 `texelFetch(...,ivec2(gl_FragCoord.xy),0)` 读取。两条路径理论上在 texel 中心接近，但应实测，不能先把其差异归为场景变化。

## 先前软件后端数据的实际对照

读取最初 high/seed4207/三帧 HDR 资产和随后历史 URL `q=high&shot=1&noaudio=1&step=1&dt=.016666667` 补采文件，得到：

| 对照 | 天空 768×1024 | 室内 384×512 |
|---|---:|---:|
| HDR RGB 最大值 | 6 | 355.5 |
| 最初 HDR 中 RGB >1 的通道数 | 19363 | 2130 |
| 历史 URL HDR 与最初 HDR 不同的通道数 | 0 | 3519 |
| 两次 HDR 最大绝对差 | 0 | .05712890625 |
| 历史 URL HDR clamp+round 至 byte 后，与旧 raw 的最大差 | 17 | 253 |
| 上述 byte 对照中差值 >1 的通道数 | 7249 | 67583 |

这些数字来自本次只读 NumPy 检查；最初 manifest 的室内差值通道数为 67535，历史 URL 补采后变为 67583。两次统计对应不同 HDR 文件，不能混称同一快照。

两张新 RGBA32F 文件均全部有限，且每个值都能准确往返 FP16，符合读取 HalfFloat 纹理后扩大到 float32 的预期。室内 alpha 也存在大于 1 的原值，最高约 1.6377；导出时应保留，不应为了图像预览而强制 alpha=1 或反预乘。IBL 采样是否使用 alpha 是另一层语义。

室内最坏点以 bottom-to-top 行序计为 `(x=72,y=60)`：旧 raw 为 `[255,173,100]`，新 HDR 为 `[.00678253,.02404785,.03497314]`，周围 3×3 RGB 也全暗。这样的大差不能仅靠该 texel 附近的小幅 UV/线性插值偏移解释。它仍可能来自较早生成 PMREM 时的场景或后端差异，必须先做同 live texture 导出对照才能定性。

来源文件：[原 manifest](../assets/export/environment/pmrem/manifest.json)、[历史 URL 补采 manifest](../../artifact-rendering-study/evidence/runtime/saltline-pmrem-hdr-manifest.json)、[原导出场景](../assets/export/scenes/main.json)。

## 后端证据及其边界

[pristine-original.json](../../artifact-rendering-study/evidence/runtime/pristine-original.json) 的 `captures[0].metadata` 包含历史原始 URL，以及：

```text
ANGLE (NVIDIA Corporation, NVIDIA GeForce RTX 4070 SUPER/PCIe/SSE2, OpenGL ES 3.2)
```

`detail-validation.json`、`original-ablation.json` 和 `showcases.json` 的同期记录也使用这一后端。旧 `assets/export/scenes/main.json` 本身没有 GPU 标识，所以目前只能证明对应的历史视觉捕获使用 NVIDIA，不能凭此断言每次纹理导出都使用相同进程和后端。

新 NVIDIA manifest 已补记 renderer/vendor、GL version、Three revision、原 HTML SHA、URL 参数、frame 和 time。后续继续保留这些字段，必要时再补 shading language version 和实际 quality。天空 FBM、材质 hash、阴影边缘、HDR 高光和 PMREM 多轮过滤都可能继承后端差异；本次已确认整体 PMREM 的后端差异，但尚未逐项拆分是哪段着色贡献了多少。

旧 `main.json.sourceHash` 是 [export_source.cjs](../tools/export_source.cjs) 中的硬编码常量，并非当场计算，不能单独证明历史 live 页面字节身份。本次已对保留的原 HTML 文件重新计算并核对 SHA，后续导出也应计算实际来源，不能仅复制旧字段。

## 最小同源验证

下列对照已由主线执行，见 [pmrem-readback-compare.json](../evidence/pmrem-readback-compare.json)：

| 同一 live texture 的比较 | 天空 | 室内 |
|---|---:|---:|
| 旧 filtered8 与 fetch8 最大 byte 差 | 1 | 1 |
| 旧 filtered8 与 fetch8 差值 >1 的通道数 | 0 | 0 |
| fetch8 与 clamp/量化 fetch32 最大 byte 差 | 0 | 0 |
| 历史 raw 与当前 filtered8 最大 byte 差 | 17 | 253 |

以下保留实验方法。这个软件后端对照先排除了导出插值和 RGBA8 量化；之后的 NVIDIA 重采又把历史 byte 差异压到 1，完成本轮来源核对。

在同一冻结页面保留同一个 texture 对象，不重新初始化、不调用 `captureInteriorProbe`。对每张纹理依次执行：

1. A：完全复用旧 full-screen varying UV shader，`texture2D` 采样到 RGBA8。
2. B：使用 `texelFetch` 采样到 RGBA8。
3. C：使用同一个 `texelFetch` 采样到 RGBA32F。
4. 再次执行 A 和 C，确认导出过程没有改变输入内容。

每次明确设置目标为纹理的完整 width/height、完整 viewport、关闭 scissor、`NoColorSpace`、`toneMapped=false`、`NoBlending`，保存并恢复 renderer 状态。先记录对象 UUID、尺寸、type、colorSpace、wrap/filter、version；不要只凭同名和尺寸映射。当前两个尺寸可唯一匹配历史 ID，但映射应断言候选数恰为 1，并保存实际绑定来源，例如 `scene.environment` 或哪些材质的 `envMap`。

比较顺序如下：

| 结果 | 下一步 |
|---|---|
| B 与 clamp/量化 C 相差至多正常 byte 舍入 | HDR 读取和 RGBA8 量化路径相容。仍保留真实 GPU B，CPU round 只作辅助。 |
| A 与 B 有大差 | 检查 varying UV 位型、纹理中心、采样过滤和实际 GL 状态；此时不能用 C 直接否定旧 PMREM 内容。 |
| A 与 B 基本一致，但 A 与旧 raw 仍有大差 | 主要差异已在 PMREM 内容生成阶段，继续核对后端、capture 调用和场景绑定。 |
| 同页面重复 A/C 内容不稳定 | 查异步纹理更新、捕获调用、共享 render target 或测试代码副作用，先停止同源声明。 |

如确认生成阶段不同，可再导出室内 probe 的未卷积 cube 六面，将差异分成场景 capture 与 PMREM convolution 两段。记录 capture position、near/far、layers、天空 `uEnv/uTime`、可见节点和材质状态。不要一开始就把差异归到 PMREM blur kernel。

## 数据与后续 IBL 的验收边界

旧 RGBA8 文件保留作历史证据，NVIDIA HDR 单独保存并注明实际捕获来源。新数据可标为“与历史 byte 快照一致的原 GPU HalfFloat PMREM 直接捕获”，不能称为从旧 RGBA8 反推出的 HDR。SwiftShader 版本另存，不覆盖原 GPU 输入。

之后集成需要另外验证原 cubeUV 面方向、roughness→atlas 层选择、采样过滤、室内 envMap 绑定和强度、标准材质的间接漫反射/镜面分配。HDR 文件读回正确不等于这些运行时行为已完成。

## 对材质 sampler 参考的影响

此前 [sampler-filter-precision-verification.json](../evidence/sampler-filter-precision-verification.json) 证明 native NVIDIA Vulkan 的硬件 linear 过滤与 SwiftShader 参考或精确 FP32 手动插值有差异，也证明四 texelFetch 更接近那两者。它没有证明 native 相对历史 NVIDIA 原作采样不一致。

因此不能仅以 native 对 SwiftShader 的失败为依据，将手动双线性宣布为原作采样修复。主线正在同一原 NVIDIA 后端重新采集 48 cases，之后应将实际 factory 的硬件版本与该参考配对比较；保留 SwiftShader fixture 作另一后端结果，不能覆盖或混合两者。若硬件路径已匹配原 NVIDIA，应保留该证据并重新评估手动路径的必要性。

即使 GPU 型号相同，Godot Vulkan 与 ANGLE OpenGL 的编译和状态仍可能不同，最终判断必须来自配对实测。这个来源要求也适用于其他程序化噪声和后处理参考；不能依据本次 PMREM 结果自动撤销或宣称此前各项修复正确，应分别核对其原后端参考。
