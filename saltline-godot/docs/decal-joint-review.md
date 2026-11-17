# Decal Jg、impact 联合消费与精确法线审查

本轮 Jg 生成、A→decal 联合随机消费及 decal 局部 FP32 normal 路径通过已列验证，未发现该范围内的生产阻断。原生 ARRAY_NORMAL 的 oct16 误差仍如实记录；生产 shader 改用 CUSTOM2，不依靠放宽法线容差。本次只读审查，只新增此文档。

依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 第 58584–58748 行的 Jg、Yw atlas UV 函数及第 59200 行的 A。对应实现为 [decals.gd](../scripts/decals.gd)、[Main._impact_visuals](../scripts/main.gd)、source_scene 的 fx_decals 材质绑定和两份 Standard shader。

Jg 的几个易错语义已修正。unknown kind 只回退 UV 选择，默认尺寸仍为 `.25`，不能先改成 concrete 后取 `.34`。显式负 size 在原 `s || ...` 中有效，Native 现以 size!=0 保留负值。normal、切线、旋转、中心和顶点使用 double 标量计算，直到最终 Vector3/Float32 写入才量化；零 normal 保持零并生成退化四边形，tiny normal 仍归一化，不增加 epsilon 回退。

环形池仍为 160 槽，第 160 次发射即开始按新 next 起的 14 槽淡出。base_alpha 先量化为 Float32，再乘 `(i+1)/15` 并写回 Float32，与原 baseA/col 写入顺序相同。UV 保留原 Yw 的两像素边距和方向，实际 ArrayMesh indices 单独核验为 Godot 对应绕序 `0,2,1 / 0,3,2`。

[decal 参考核心](../tools/decal_reference_core.cjs) 字面提取原 Jg.add/clear、Yw UV、Oa 和 ZP。[独立序列](../tools/decal_random_reference.cjs) 连续发射 175 次，再 clear 并重发两次，共 178 操作、177 次 emit、531 次随机消费。每次 emit 固定按 tile、size variation、rotation 消费三次。覆盖七类 kind、负/default size、零/tiny/非轴向 normal、首次满池及覆盖淡出。逐步检查消费次数，在选定快照比较完整有效数组；clear 后重发也已加入。

[A 联合参考](../tools/impact_decal_reference.cjs) 现以真实原 Jg.add 取代旧不耗随机的 decal stub，并与原 A/helpers、粒子池和碎片 jg.add 共用同一 u53 tape。Native 验证实际调用 Main._impact_visuals，比较随后的 particles、debris、light 请求和 decal 几何/UV/color。它补足 [前轮 impact 审查](impact-random-review.md) 中缺失的实际 decal 消费，不能用旧总次数加固定常数代替此次联合重放，因为后续随机分支也会随 tape 位置改变。

原 A 会先把零/tiny normal 回退 UP，再将处理后的 normal 传给 Jg。Main 现将相同 fallback 后的 normal 放入传给 decals 的命中副本，保留 water surface 路由并避免退化弹孔。这与直接调用 Jg 时保留零法线并不矛盾，两条入口的原语义不同。当前联合用例的 normal 为 UP/零/tiny，未因此宣称任意斜向 A 输入的全部误差已测。

Godot 固定提交 `ed1daf0bf001b61586d9930840f2f1394092c079` 的 `servers/rendering/rendering_server.cpp:613–629` 显示，即使未设置 COMPRESS_ATTRIBUTES，ARRAY_NORMAL 仍执行 octahedron encode 和 uint16 截断；第 1511 行附近读回时再 decode。此次非零法线的 codec 期望误差为 0，但原生数组相对原 source normal 最大偏差为 `4.20212745666504e-5`，不能将二者混为同一指标。

生产修正限定 fx_decals。Decals._rebuild 在 CUSTOM2 保存原 FP32 normal，CUSTOM3 继续承载颜色。source_scene 仅为该材质启用 source_exact_normal，两份 Standard vertex 在计算 local_n、world_n 与太阳 shadow offset 之前恢复 `NORMAL=CUSTOM2.xyz`。其他材质默认关闭，既有 weapon normal 分支保留。没有修改引擎 normal codec、材质贴图或 polygon bias。

| 证据 | 结果 | 可支持的范围 |
| --- | --- | --- |
| [Jg 独立序列](../evidence/decal-random-verification.json) | 212138 checks、531 draws；失败 0；最大误差 `3.5527136788005e-15` | 实际 mesh position/UV/CUSTOM3/CUSTOM2、CPU normal、环形淡出、索引与 clear 后重发；字段阈值 `1e-6` |
| [A + Jg 联合序列](../evidence/impact-decal-verification.json) | 64 cases、399796 checks、57560 draws；失败 0；最大误差 `1.9073486328125e-6` | 实际 Main 路由与共享 tape；particle/debris 阈值 `3e-6`，decal 字段 `1e-6` |
| [法线 shader 使用诊断](../evidence/decal-normal-runtime.json) | 31 checks，失败 0；production enabled 材质恰为 1 | 两份 Standard 路径、三种非退化 normal 的 local/world/太阳偏移输入与 off control |
| [旧 decal 基本回归](../evidence/decal-verification.json) | 170 emits、160 槽、14 淡出槽，失败 0 | 基本容量和几何平面 |
| [Q 回归](../evidence/explosion-random-verification.json) | 122484 checks、68808 draws，失败 0 | 六尺寸 Q 初始生成及事件；原参考 scorch 接收者仍是固定三次消费模型 |
| [真实效果生命周期](../evidence/decal-joint-runtime.json) | 420 帧；14 shots/impacts/shells/tracers，28 debris 全部 settled；末 add/lit/debris 为 0 | 实际射击、弹痕接入与清理回归 |

GPU 法线诊断使用正交相机、16×16 HDR target，保留生产 Standard/alpha vertex 和 production polygon bias，替换 fragment 并开启 unshaded。exact 开启时 local/world 的放大误差为 0；太阳偏移放大误差最大 `.000396728515625`，除以 16384 后约 `2.42144e-8`。关闭 exact 时，三个方向分别出现 `.25/.65234375/.68798828125` 的放大误差，证明诊断会暴露 oct16 路径差异。太阳矩阵在该探针设为 identity，验证的是 normal 参与偏移计算，不是 PCSS 或最终阴影像素。

最终 [法线诊断日志](../evidence/decal-normal-runtime.log) 和 [420 帧日志](../evidence/decal-joint-runtime.log) 均已核对，无 ERROR/泄漏报告。两份 fixture 禁写重放均逐字一致，独立重算得到 standalone 212138 checks、联合序列 399796 checks，与报告相符。

早期 [编译失败](../evidence/decal-normal-diagnostic-initial-shader-failure.json)、[黑图诊断](../evidence/decal-normal-diagnostic-initial-black.json)、[Jg baseline 失败](../evidence/decal-random-initial-failure.json) 和 [normal codec 差异](../evidence/decal-random-normal-codec-difference.json) 均保留。黑图的确定原因为诊断启用 unshaded 却将误差写入 EMISSION、ALBEDO 置零；引擎 `scene_forward_clustered.glsl:3087` 的该分支只输出 albedo。最终改用 ALBEDO 输出误差，未通过关闭 bias 消除问题。

零 normal 的退化四边形没有对 ARRAY_NORMAL codec 作断言，因为 oct 编解码不能保留零向量。但 CPU normal 和 CUSTOM2 仍与 source 比较，未从测试中删除。报告中的 2232 是累计快照里的零 normal 顶点记录数，不是 2232 个独立生成样本。GPU 三方向探针不包含这些退化面。

剩余范围仍须保留：

- clear 验证逻辑 count/next、空有效集合与重发。代码会隐藏旧 mesh，但该测试没有单独断言清空瞬间的 visibility，也未证明旧 backing buffer 如原 Jg.clear 一样全部清零。
- A 联合参考仍用受控 shade 1/.2 和 floor −50，不含实际 puddle 查询、真实 shadow 查询、完整世界命中时序或粒子运动。Q 的完整真实 Jg 几何联合仍没有替换其三次随机消费接收器。
- 正交诊断只证明实际 vertex 路径使用精确 normal；替换 fragment 后不能证明原 normal map、光照、透明混合、排序、受伤 post 或整图一致。
- 420 帧截图由主线查看并确认墙面弹痕，属于接入观察，没有原作配对像素。此次没有重跑 780 帧流程，不能借用旧流程记录冒充当前版本。
- Jg 独立参考先把坐标/normal 限定为 Native Vector3 可表示值，再运行原字面函数；tape 为受控 u53 输入，不声明 V8 默认熵序列或任意世界坐标的逐位一致。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| Jg/UV 提取函数 | `1ef81e2082911bc12584c1c8238bf9e0f392f650036b03df9b8a4f7cccf908b5` |
| decal-random-reference.json | `ec01cbcfad7e5058ffd31d831c68810307a302f13d383f2609fabd80ecee4da2` |
| A/helpers/jg 提取函数 | `ef64dc9256df30ab0ba47c7c88989e11863bad5c2ea51a2ea19e5a3516c822db` |
| impact-decal-reference.json | `d6fc35a32eab2b949a16d76d3120f078b878053681c842510acaa0a19a04cd6e` |
