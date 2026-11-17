# 仓内墙面亮斑：只读定位建议

后续配对实验已确认大亮斑缺失源于对照快照的 pooled point 输入不一致，见末节。下面保留最初只读定位过程。本顾问没有运行新的 GPU 实验、修改生产 shader。

## 已复核的信号

固定相机 `(-10,1.7,-20)` 看 +X，time `.05`，manual exposure `1`。已查看原/native beauty 和 normal 图，并用 Pillow/NumPy 重算 `[835,878) × [282,318)` ROI：beauty MAE `39.91085`、direct-specular `31.63975`、roughness `4.98170`、normal `6.18282`，单位为 8-bit 通道值。定位到的网格 `d9fa505f-e6e0-411b-a117-6e97dea78b4a` 使用 interior `corrugated_roof` 材质 `b7e177e2-f9a5-4dc3-b221-3bfd13343d32`。

亮斑内部单点 `(860,300)` 更有区分力：

| 输出 | 原 RGB | Native RGB |
| --- | --- | --- |
| beauty | 253,247,236 | 36,36,36 |
| direct specular | 249,242,231 | 18,23,27 |
| normal | 19,150,154 | 19,151,154 |
| roughness | 169,168,164 | 169,168,163 |

因此不能由 ROI 平均 normal 差异直接认定切线或 normalMap 为主因。该点法线/粗糙度输出近同而直接镜面项相差极大，优先检查直接光的实际运行时输入和可见度。这里仍是经过 post 的 PNG，不是原始 HDR 数值判等。

本次读取的 beauty SHA256：source `7c3e6069c2199b9963e2e9bd43859449e6c8203e980be26c9f5eaad55beb9957`；native `82d2595edd89cc3f5c84b840434ba21fdaab027ca65028eedc66717ab184c2f9`。

## 源码核对与诊断限制

- 该 geometry `04926581…` 只有 position/normal/uv，2052 顶点，没有 tangent。原 [USE_TANGENT 门槛](../../artifact-rendering-study/source/extracted/bundle-1.js:28756) 因而选择 [getTangentFrame 导数路径](../../artifact-rendering-study/source/extracted/bundle-1.js:22999)。Native [source_tangent_normal](../shaders/source_tangent_normal.gdshaderinc:2) 对应同一路径，不能把它改为依赖缺失 tangent。
- 材质是 FrontSide、非 triplanar、SL_FX、normalScale `(1,1)`、interior `.12`，无 polygonOffset。三个纹理都是同一 corrugated 集合，512²、Repeat、anisotropy 8、相同 repeat。导入器确实读取这些参数；尚未把运行时实际 uniform/纹理绑定再次读回。
- 原 [gk/vk](../../artifact-rendering-study/source/extracted/bundle-1.js:39468) 与 Native [fragment](../shaders/source_material.gdshader:75) 的 normal-length roughness 项、normalScale 和 wet/up 衰减顺序相符。
- roughness 诊断有一个明确小错位：[原输出](../tools/capture_main_paired.cjs:16) 是已 clamp 到 `.045..1` 的 `roughnessFactor`；[Native 输出](../tools/capture_main_paired.gd:19) 是裸 `rr`。应先对齐为 `clamp(rr,.045,1)`。两者都未显示 BRDF 最终的 `min(max(roughness,.0525)+geometryRoughness,1)`；原入口在 [22349](../../artifact-rendering-study/source/extracted/bundle-1.js:22349)，Native 在 [sourceDirectTerms](../shaders/source_direct_surface.gdshaderinc:17)。
- 当前诊断仍经过 AO/volume/bloom/tone 等后处理，且同名 corrugated_roof 材质均被修改。源还在 opaque 前 return；Native 通过 EMISSION 输出。它们适合找贡献来源，不能把通道差直接解释成几度法线误差或具体 HDR 能量。

## 最小判别顺序

1. **只拆这一个 ROI 的太阳与点光镜面项。** 维持当前相机和 shader 参数，不改变 normal/roughness；分别输出 sun-only、point-only 的 direct specular，优先从 world HDR 读 `(860,300)` 及周围少量像素，避免再经过 bloom 放大。Native 已有 point→sun→key 的明确累加位置，可在诊断副本中记录增量。原对应 Three lights 累加处记录同两项。先确定缺失亮斑属于哪一路，不做全场矩阵。
2. **若太阳项不同，先测 visibility=1 的同一像素。** 若无阴影两端接近，则比较该点原 packed shadow/native R32F 的投影坐标、bias 后接收深度、PCSS 可见度与实际 tap 深度。现有受控 PCSS 测试和 native D32/D24 全图比较没有证明原 packed shadow 与当前真实 caster 图全等，不宜直接改 bias 或加灯补偿。若无阴影仍不同，再读 `geometryRoughness`、最终 material.roughness、N·L/N·H 和 view position。
3. **若点光项不同，只导出当前活跃 point 的完整运行时记录。** 比较位置、线性 RGB×intensity、range、decay、visible、camera layers 和每灯贡献。不要仅核对导出的四个静态灯：原当前画面的 pool 状态也应入表。Native atlas 见 [source_local_light_data](../scripts/source_local_light_data.gd:13)，世界实际 mask 应排除 weapon key。四个静态灯的既有属性为 intensity 34/range 13/decay 2、layers 3；导入公式未发现遗漏，但这不代替本次活跃数据核对。

目前优先级：直接光可见度/运行时绑定 → 最终 geometry roughness 与位置 → normalMap 采样细节。尚无依据把这个大亮斑归为可接受的跨 GPU 浮点残差。

## 后续已确认结论

原参考的第一个 pooled point 已激活，intensity 约 `2.5715`、位置约 `(9.3081,4.0691,-11.3264)`，紧贴目标墙面；Native 的零 dt 暖机没有该瞬时灯。原参考禁用 pooled points 后，`(860,300)` direct-specular 变为 `(18,22,26)`，接近原 Native 的 `(18,23,27)`。

将原六个 pool 输入复制到 Native 临时 persistent 测试槽后，该点得到 `(249,242,230)`，原参考为 `(249,242,231)`；ROI MAE 从 `31.63975` 降为 `3.32903`。已读取 [matched-pool 报告](../evidence/interior-highlight-matched-pool.json)：raw HDR 对应点原为 `(4.62109375,4.5390625,4.10546875)`，Native 为 `(4.6015625,4.51953125,4.09375)`。

这解决了本次大亮斑的主要归因。生产 shader 没有变化，不能将它写成法线、BRDF 或 PCSS 修复，也不能把诊断状态同步扩大为普通游戏 FX 历史已对齐；剩余 ROI 像素差异继续保留。
