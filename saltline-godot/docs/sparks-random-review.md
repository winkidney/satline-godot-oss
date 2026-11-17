# Sparks、flash 与敌人枪口效果随机顺序审查

本轮 `_sparks`、Impact.flash 和默认敌人枪口效果的受控发射对照通过，未发现该范围内的生产阻断。完整 impact 分发、decal 插入时机和 explosion 联合序列仍未完成，不能由 helper 通过推导为全 FX 随机顺序一致。本次只读审查，未改生产代码。

原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 的 `go`、`u1`、`_`、`T`、`w` 和 `H`。对应实现为 [ImpactEffects](../scripts/impact_effects.gd)。原 `T` 第 58894–58913 行每次尝试按以下顺序消费：scatter 四次、speed 两次、life 一次、size 一次、red tint 一次、green tint 一次，共十次；成功 emit 再消费 seed。红绿各抽独立 tint，蓝色不抽 tint，随后 `_` 将三个颜色分量乘 `.6`。当前 Native 保留这个顺序，修正了旧 life/size 排序及共用 tint 的差异。

原 `w` 第 58914–58926 行先 emit，成功后才抽 rotation。Impact.flash 现采用同样的顺序，并以 Float32 保存 rotation。金属、敌人、通用 sparks 和 enemy muzzle 的相应 flash 调用已使用此 helper。第二道 flash 的随机 frame 在调用前求值，所以即使池满，该 frame draw 仍须消费；只有 emit 内 seed 和成功后的 rotation 才跳过。

[sparks 参考](../tools/sparks_random_reference.cjs) 字面提取原 `go/T/_/w/u1`，使用原 Float32Array 存储。wrapper 合成 `_sparks + 两道 flash`，没有模拟整个 impact 分发器。容量为 `0/1/2/7/12/15/80`，count 为 `2/9/18`，共 21 cases、63 行状态；各组连续调用两次，再 clear 后第三次调用，整组共享同一 tape。

独立统计为 609 次 sparks 尝试、246 次成功，126 次 flash 尝试、43 次成功。因此总消费严格等于 `609×10 + 246 + 63个预参数frame + 43×2 = 6485`。容量 0 每轮仍分别消费 `21/91/181` 次，证明外层随机参数没有被满池提前截断；容量 7、count 2 的第二轮命中首个 flash 成功、第二个失败。成功 flash 的 frame 0/2/3 均实际出现。

新增 [muzzle 参考](../tools/muzzle_random_reference.cjs) 直接执行原 `H` 及其 `go/M/_/w/u1` 依赖。它覆盖相同七档容量，scale `0/.55/1`，其中 `0` 按原 `q.scale || 1` 使用默认值 1。四层 flash、轴向粒子、三粒短 sparks 和末尾 puff 在同一 tape 中执行。参考 `ph` 只返回默认颜色，light 接收者是空 stub，输入方向只有 UP；自定义颜色、方向退化及真实 light 调用不属于这组联合消费证明。

两组 tape 都在执行原函数之前量化到 `k/2^53`，再导出 hex u53，Native 解码同一值。独立无写入重放两个生成器，结果与最终 fixture 逐字一致，全部 tape 解码与 JS 输入逐位相同。验证器检查有限性，随机调用数精确比较；字段阈值保持 `2e-6`。

| 最终证据 | 结果 | 范围 |
| --- | --- | --- |
| [sparks 联合发射](../evidence/sparks-random-verification.json) | 21 cases、12429 checks、6485 draws、0 失败；最大误差 `1.90734863636521e-6` | `T/_/w` 与 pool 的发射状态、成功/拒绝及消费顺序 |
| [muzzle 联合发射](../evidence/muzzle-random-verification.json) | 21 cases、13149 checks、1812 draws、0 失败；最大误差 `1.9073486328125e-6` | 默认色、UP、light stub 下的原 H 发射序列 |
| [既有 enemy muzzle 配置](../evidence/enemy-muzzle-verification.json) | 4 cases、464 比较、0 失败 | 确定性层、轴向和 light 配置；随机参数按范围核验 |
| [最终 GPU 接入回归](../evidence/sparks-random-runtime.json) | 470 帧、11 处共享身份、332 次 FX 消费、0 失败 | 实际 Main 接入及既有骨骼、机械、弹匣路径，对应 [日志](../evidence/sparks-random-runtime.log) |

粒子核心 92 帧/3376 字段和爆炸物流 180 步/8180 项回归也已通过。470 帧的 332 次消费没有原作整场轨迹可逐项比较，只能作为本次实际运行记录，不能视为源消费总量已对齐。

本轮仍需明确保留的范围：

- sparks 主用例仅 UP、flags=1、固定颜色、spread 和速度/寿命范围，已消费 tape 不包含 0 或极近 1。先前 scatter 的定向测试仍是单独证据。
- 这里只比较发射状态，未验证粒子运动、排序、回收后复用、受控 sparks 像素或完整 impact/FX 事件顺序。
- [ExplosionEffects.flash](../scripts/explosion_effects.gd) 仍有独立的旧实现，在 emit 之前抽 rotation。本轮没有修改它；该点留待原 explosion `Q` 的完整联合序列迁移，不能表述为所有 flash 均已修正。
- Main 当前仍在 impact 之前调用 `decals.impact`，而原 `A` 将 decal 放在各材质分支内部。共享 FX 流下，这会影响随后参数消费。下一步应按原 A 的完整分发、分支和 decal 时机联合验证，不能仅依据本轮 helper 通过调整结论；本次未扩大审查到 A/Q 实现。

固定来源及最终 fixture 校验值如下。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| sparks 提取函数 | `d4b9f63758d7b19bb9f13cd70cd823404630d1ecfcce5b4faea7815dffe3e479` |
| sparks-random-reference.json | `fea2caba242e45cd5956706d63bf5c8d3b768dc235a3fe44915d37073550dc4b` |
| muzzle 提取函数 | `290c8355d54cefb7bd33aa6b5f7ccc3fbad0848a7084b33efa1a9fb814c414e0` |
| muzzle-random-reference.json | `974ed87cf60191154b658575aa3fd1a017a3a4db04e940b67cde8f3aa69a8135` |
