# Impact A 随机顺序审查

当前实现通过本轮受控原 A 对照，未发现该验证范围内的生产阻断。共享闪光节流、wood 条件发射、退化输入及碎片颜色的初版证据缺口已补齐。完整 decal 联合消费、puddle 分类和实际遮挡查询仍未完成。本次只读审查，只新增此文档。

原始依据是 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 第 59200–59586 行的 `A`，以及其 `go/M/T/_/w/L/R/k/u1` 依赖和 `jg.add`。生产对应 [impact_effects.gd](../scripts/impact_effects.gd)、[debris.gd](../scripts/debris.gd) 与 [main.gd](../scripts/main.gd)。

金属与 enemy 原本共用闭包 `x=-1`，两分支都以 `m-x>.09` 判断闪光。Native 使用同一个 `impact_flash_time`，在发光前更新时间，位置、色值、energy、radius、duration 与原调用相符。金属位置沿 normal 偏移 `.12`，enemy 不偏移。`clear()` 保留 clock 与节流历史，也符合原 `xe()` 只清池和 emitter、不重置 `m/x` 的行为。

wood 先执行 dust 并取得 shade，再创建 fragments，最后仅在 `shade>.5` 时消费概率随机数、以 `<.3` 决定 flash。Native 已保留短路顺序。normal 的长度平方 `<1e-6` 回退 UP，incoming 只有长度平方 `>1e-6` 才归一化，否则取负 normal。当前 CPU 矩阵覆盖零向量与 `.0001` 小向量；没有据此声明所有斜向输入的 FP32 误差均已验证。

[原参考生成器](../tools/impact_random_reference.cjs) 字面提取完整 `A`、所用 helpers、原 Float32Array pool 和 `jg.add`。它不从 Native 实现生成 expected。合成 tape 在执行原函数前量化到 `k/2^53`，fixture 导出 hex u53，[Native 验证器](../tools/verify_impact_random.gd) 解码相同输入并检查误差有限性。随机消费次数精确比较，数值字段阈值为 `3e-6`。

最终为 8 类 surface、near/far、容量 2/80、shade 1/.2 的 64 cases，每组连续 6 次调用。时钟为 `[0,.05,.09,.090001,.18,.180002]`。metal 组在奇数 step 改调 enemy，同一个实例的灯请求累计为 `[1,1,1,2,2,3]`，已同时命中跨材质共享节流及严格 `.09` 边界。step 2/3 使用零及微小 incoming，step 4/5 使用零及微小 normal。shade 是受控注入，不能视为实际光照遮挡查询通过。

碎片参考现导出原 `jg.add` 写入的 RGB。Native 的 `slot.color` 保存同一 tint，并用该值写 MultiMesh custom data，CPU 对照已包含此 RGB。早期在 headless 下直接读取 custom data 得到黑色的失败保留于 [原始报告](../evidence/impact-random-headless-color-readback.json)，没有把这份失败改写为通过。新增实机测试分别写入四种颜色并读取 MultiMesh API，12 通道误差为 0；这是 custom-data 写入与读回证明，尚非 shader 着色像素证明。

| 证据 | 结果 | 可支持的范围 |
| --- | --- | --- |
| [原 A 联合发射](../evidence/impact-random-verification.json) | 64 cases、353470 checks、56727 draws；失败 0；最大误差 `1.90734863636521e-6` | 实际 Native particles/debris 发射状态、RGB、消费次数及 light 请求 |
| [碎片颜色实机读回](../evidence/debris-color-runtime.json) | 4 色、12 通道；失败 0；最大误差 0 | CPU tint 到 MultiMesh custom data；[日志](../evidence/debris-color-runtime.log) 无 ERROR/泄漏报告 |
| [Main 接入回归](../evidence/impact-random-runtime.json) | 470 帧、11 处共享身份、315 次 FX 消费；失败 0 | 实际共享随机服务及既有骨骼、机械、弹匣路径；[日志](../evidence/impact-random-runtime.log) 无 ERROR/泄漏报告 |
| [流程回归](../evidence/impact-random-flow.json) | 780 帧、两次 retry、pause 冻结、最终 playing | UI/游戏状态流程；[日志](../evidence/impact-random-flow.log) 无 ERROR/泄漏报告 |

470 帧发生在新增 `slot.color` 存储之前，不能将其写成最终颜色存储版本的完整回归；该增量另有上述实机 12 通道证据。470/780 都没有原作同输入整场随机轨迹，不能用运行帧数或消费总量代替联合序列对照。

Main 正常玩家射击与敌方命中已改为 `impact → decal`，与原 A 各分支在粒子/碎片之后调用 `p.add` 的相对次序一致。玩家命中的 `surface="enemy"` 由 Combat 产生；当前适配没有单独复刻原 A 的第五参数 `de` 强制改分类接口。该契约适用于现有生产调用，fixture 的 `de` 固定为 null。旧诊断预览路径不属于本轮正常射击顺序证明。

本轮证据仍有以下边界：

- 参考 `p.add` 为不耗随机的 stub，未比较实际 decal 参数或其随机消费。它证明受控依赖下的 A 发射顺序，不能证明跨多次真实 impact/decal 的共享流已整体一致，也不能证明 Main 整个 Q 回调的所有副作用时序。
- 参考没有 ground/puddle 对象，shade 为 1/.2、floor 固定 −50。实际 puddle 提升为 water、遮挡与地面查询继续待迁移或联合验证。
- near/far 使用两个明确区间点，未测距离平方恰为 3025；没有覆盖缺失 normal、斜向反射、缺失 camera 或所有表外 surface 输入。
- debris 最大累计 42 块，未触及 256 容量回绕；这里只比较发射后的状态，不包含完整运动、碰撞、回收、排序及受控像素。
- light 记录器核验调用参数，不执行真实 light pool 分配或照明。Explosion 的 Q 联合序列仍是独立后续任务。

本次以禁写方式重放最终生成器，输出与已归档 fixture 逐字一致。固定来源如下。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 字面提取函数 | `ef64dc9256df30ab0ba47c7c88989e11863bad5c2ea51a2ea19e5a3516c822db` |
| impact-random-reference.json | `52ea34aa1419d70ef785315a0ae148d20a54d70d1078f819b685f8fd5f54e6c1` |
