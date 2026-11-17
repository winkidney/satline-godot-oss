# Puff、splash 与 dust 随机顺序审查

最终实现未发现本轮生产阻断。[ImpactEffects](../scripts/impact_effects.gd) 已按原函数恢复 emit、随机参数和 Float32 写入的先后关系。结论限定为本轮受控输入的发射状态和随机消费；不代表完整 FX 场景、粒子运动或图像已经对齐。本次只写本文，未改生产代码。

原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 的 `u1`、`go`、`M`、`S`、`k`、`L`。三个参考生成器直接提取原函数，使用原 `u1` 的 Float32Array 存储。[puff 参考](../tools/puff_random_reference.cjs) 验证 `M/u1`；[splash 参考](../tools/splash_random_reference.cjs) 验证 `go/M/S/k/u1`；[dust 参考](../tools/dust_random_reference.cjs) 验证 `go/M/L/u1`。dust 提取片段附带的 `S` 没有被调用。

原 `M` 第 58855–58874 行先调用 `l.emit`。失败直接返回；成功后才抽 rotation、rotation_speed 和可选 frame。Native puff 现先 emit，再条件写入；标量经 `lit_pool.f32` 量化，颜色由 Vector3 存储。后续 splash 覆盖 rotation 等字段时仍先消费 M 的原随机值，没有因为值会被覆盖而删掉 draw。

原 `S` 第 58927–58940 行同样先 emit、成功后才抽 rotation。新增 ripple helper 保留这个顺序；第二道 ripple 成功后才写 `fade_in=.35`。原 `k` 第 59090–59198 行在调用 M/emit 之前计算的尺寸、位置、速度和寿命随机参数，即使池已满仍须消费，当前实现没有将整轮循环提前跳过。满池只跳过 emit 内部 seed 和成功后的随机赋值。

原 `L` 第 59002–59049 行先处理并归一化 normal、查询 shade，再逐粒消费 `go → speed → tint → life → end size → M`。Native dust 已将 tint 抽样移到 life/end 之前，并恢复 normal 处理。尾部两粒保留 X/Z velocity、life、end size 的顺序。当前 dust 数值用例仍只有 UP normal，不能据此宣称所有 normal 输入分支均已验证。

scatter 的旧 `max(length,1e-6)` 会改变非零但很小的随机向量，与原 `Math.hypot(...) || 1` 不同。现已改为 double 标量计算，仅长度恰为零时回退到 1，最终写入 Vector3。新增 15 组定向输入覆盖零、近零随机向量及 UP、零、`[1,2,-3]` 三种 axis，保留原最终长度小于 `1e-4` 时返回 axis 的行为。该结果不等于全输入域或跨数学库逐位一致。

本轮输入也已统一。早期分数 tape 直接供 JS 执行、之后才编码 u53，会使部分 Native 输入与 JS 不同。最终先将 raw tape 量化为 `round(raw*2^53)/2^53`，再让原 literal 和 hex 导出共同使用；Native 从 hex 解码。独立无写入重放三个生成器，产物均与最终 fixture 逐字一致，所有 tape 解码值与 JS 实际输入逐位相同。定向输入误含 `1` 的失败已保留，最终改为合法的 `1−2^-53`；没有修改原公式或放宽容差。puff 的 finite 检查也已补齐，splash/dust 比较继续拒绝非有限误差。

| 最终证据 | 结果 | 范围 |
| --- | --- | --- |
| [puff](../evidence/puff-random-verification.json) | 20 步、184 checks、32 draws；最大误差 `2.77555756156289e-17` | 容量 3；9 次成功、11 次拒绝；5 次随机 frame、4 次固定 frame；clear 后继续消费同一流 |
| [splash](../evidence/splash-random-verification.json) | 21 cases、25419 checks、10115 draws，加 15 组 directed scatter；最大误差 `4.76837158203125e-7` | 3 个 size × 7 个容量，每组连续调用两次，再 clear 后第三次调用 |
| [dust](../evidence/dust-random-verification.json) | 21 cases、12519 checks、5586 draws；最大误差 `9.5367431640625e-7` | 相同 size/容量结构，UP normal、无遮挡 |

puff 阈值保持 `1e-7`，splash/dust 发射字段保持 `2e-6`，directed scatter 保持 `1e-7`；调用数精确比较。splash 报告的 10115 draws 是跨 cases 的主序列，15 组定向测试各使用独立的四值 tape，其 60 次 draw 不包含在该数字中。容量现为 `0/1/2/7/12/15/80`，size 为 `.4/1/2`。`size=1, capacity=15` 已命中只剩一个槽位，第一道 ripple 成功、第二道失败。容量 0 和重复满池仍验证外层参数消费，clear 不回倒 RNG。

剩余边界如下。

- splash/dust 的参考将 shade 查询替换为 `g()=>1`，Native 使用空 physics，未验证遮蔽值 `.2`、真实 raycast 或 dust 的非单位/极小 normal。
- puff 独立测试比较 calls、返回是否成功和选定 16 个属性，没有比较位置、速度、life 和尺寸；splash/dust 的组合用例另比较这些发射字段。
- 每次比较发生在发射后，没有执行粒子 update、回收后复用、排序或受控像素对照，也没有验证完整 impact/explosion/shell 等联合消费顺序。

[最终实机回归](../evidence/splash-dust-runtime.json) 为 470 帧、11 处共享身份、295 次 FX 消费，`failures=[]`，对应 [日志](../evidence/splash-dust-runtime.log)。它验证最终代码的接入及既有骨骼、机械零件、弹匣路径，不是受控溅水像素或原作联合消费对照。先前 470 帧的 305 calls 记录属于较早版本，不能替代最终报告。默认熵不同也会影响效果分支，不能仅按两次 calls 差值推断顺序变化。

[780 帧流程](../evidence/splash-dust-flow.json) 及其 [日志](../evidence/splash-dust-flow.log) 在最后一次 scatter 修改之前完成，暂停冻结、两次 retry、最终 playing 正常；本文不将该流程列为最终 scatter 修改后的验证。[三档 splash 数量/寿命回归](../evidence/splash-verification.json) 也已通过，范围仍限其既有断言。

最终 fixture SHA-256：

| Fixture | SHA-256 |
| --- | --- |
| puff-random-reference.json | `d74cd330ca396d3ee8314f9ff8f9eaf7f0327535f33a6d5a8c5b5fa56f7ebfb5` |
| splash-random-reference.json | `59fe15a06e1ffb1efd4fc0108dd1d042fd2c22c98d7d2bc76d2ac3802b1ba493` |
| dust-random-reference.json | `2f05eeeee248e8eff059acf64884497aab44d70690a9936b6ec1434ede79afa5` |

三个报告均记录原 bundle SHA `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，以及各自提取函数的 methods SHA，可按固定源复核。
