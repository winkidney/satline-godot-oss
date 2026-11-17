# Smolder 固定槽位与延迟发射审查

本轮 smolder 的固定 24 槽分配、顺序更新和延迟发射对照通过，未发现该范围内的生产阻断。原 Q 初始生成回归也通过。证据限定 smolder，不覆盖其他 emitter kinds 与它共用原 W 池时的占位、释放和随机交错。本次只读审查，只新增此文档。

原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 第 59971–60094 行的 W/G/oe，以及第 60304 行附近 `le` 的 dt 处理。生产实现见 [explosion_effects.gd](../scripts/explosion_effects.gd)。

构造时固定分配 24 个槽，`_start_smolder` 从索引 0 开始找首个 inactive 槽，复用时重新写入 position、ttl、scale、shade，并将 time/accumulator 清零。满槽时拒绝创建。`update` 直接按槽序遍历，不删除或压紧已过期槽，因此复用较小索引后仍在原槽位顺序消费随机数。`clear` 只取消 active，保留槽位；重新 start 覆盖本路径使用的历史状态。

`emitters` getter 按槽序返回活跃项的新数组，里面仍是原槽字典。它适合计数和只读遍历，不能再用 `emitters.clear()` 停止生产发射器。当前仓内生产消费者只读取其数量；[verify_explosions.gd](../tools/verify_explosions.gd) 已改为调用 `effects.clear()`，没有修改旧 expected fixture。

更新先增加 time，仅在 `time>ttl` 时停止。未过期时使用更新后的 time 累加 `dt*9*(1-time/ttl)`，仅在 accumulator `>1` 时发射。每次发射先减 1，再依原顺序消费 tone、位置偏移、velocity、life、末尺寸与 M 的 seed/rotation/frame。粒子池满时，外层参数仍消费，M 内成功后字段的随机数不消费。fade-in 按原 Float32Array 写入精度保存为 `.12`，turbulence 为 1。

Native 在入口把非正 dt 设为 0，对应原 `le` 在调用 oe 之前的 `j>0 || (j=0)`。参考也在 wrapper 中施加这段上游约束。它不是原 oe 自带的分支，因此不能据此声称完整 le 或所有 FX 子系统的负 dt 处理已经迁移。

[参考生成器](../tools/smolder_reference.cjs) 字面提取完整 G/oe/M/u1，运行时只激活 smolder。W 初始对象和 stop 为测试构造，当前 smolder 不持有 light，stop 的 active=false 与这条路径等效。输入 tape 先量化为 `k/2^53`，再用 hex u53 给 [Native 验证器](../tools/verify_smolder.gd)。参考未读取 Native 实现，也没有用 Native 结果构造 expected。

每档容量执行 78 步，共 53 次 start、21 次 update、3 次 clear 和 1 次 clear_particles。实际命中如下。

- 初始连续创建 25 次，第 25 次返回拒绝，已有 24 槽保持原状态。
- time 恰为 `.2/.3/.5` 的 TTL 时仍 active，随后越界才停；过期产生空洞后重新使用索引 0。
- INF 槽在 dt=`1/9` 后 accumulator 恰为 1，接着 dt=0 不发射，再加 `1e-8` 才发射。负 dt 不改变时间、accumulator 或消费次数。
- 容量 2 的 lit pool 命中饱和；容量 256 的最大粒子数为 235，是未饱和对照。clear_particles 保留 emitter 状态，完整 clear 后再 start 则重新初始化复用槽。

每档均尝试生成 335 粒。容量 2 成功 8 次、拒绝 327 次，消费 `8×12+327×8=2712` 次；容量 256 全部成功，消费 `335×12=4020` 次。两档合计 6732 次，与逐步随机计数一致。

| 证据 | 结果 | 可支持的范围 |
| --- | --- | --- |
| [Smolder 对照](../evidence/smolder-verification.json) | 2 容量 × 78 步，54176 checks、6732 draws；失败 0；最大误差 `9.5367431640625e-7` | 槽分配/活跃状态、time/ttl/scale/shade/accumulator、粒子初始字段与消费次数 |
| [Q 初始生成回归](../evidence/explosion-random-verification.json) | 48 cases、122484 checks、68808 draws；失败 0；最大误差 `1.90734863636521e-6` | Q 改用固定槽入口后，初始生成与新增 raw-size signal 检查 |
| [固定槽实机预览](../evidence/smolder-runtime.json) | 330 帧；93 additive、70 lit、24 debris、2 light、1 scorch；最终粒子池、debris、smolder 均为 0 | 实际渲染接入和释放回归；[日志](../evidence/smolder-runtime.log) |
| [流程回归](../evidence/smolder-flow.json) | 780 帧，retry/reset 后 emitters=0 | 游戏状态与清理接入；[日志](../evidence/smolder-flow.log) |

Smolder 的 time/ttl/scale/shade/accumulator 阈值为 `1e-10`，位置和粒子字段为 `3e-6`，计数与分配结果精确比较；验证器拒绝非有限误差，并单独检查 INF。独立禁写重放得到与 fixture 逐字一致的输出，独立重算 54176 checks 与报告一致。

已核对本轮实机与流程归档，两份日志均无 ERROR/泄漏报告。780 帧包含暂停冻结、两次 retry 和最终 playing；这些是接入回归，不是原作整场随机轨迹或像素对照。

本轮 Q 额外加入 432 项事件检查，比较原始未 clamp size、position，以及发送事件时的随机消费、debris 与两粒子池数量。这补足 [上一轮 Q 审查](explosion-random-review.md) 中当时未验证的 payload 和生成后发送位置；连锁爆炸消费者及整场事件交错仍未联合验证。

仍需保留的范围如下。

- 原 W 是多个 emitter kinds 共用的 24 槽。Native 当前只实现 smolder 所需字段，没有 fire light、steam、embers、drip 等行为，也没有公共 handle 的 stop/setPos 和原共享失败对象 J 的完整接口。
- 测试直接调用 start/update 并查看状态，没有推进粒子运动、碰撞、排序和自然粒子回收。清池后的复用是显式操作，不能替代完整帧调度证明。
- getter 的数量受测，槽序由直接 filter 实现和逐槽状态/粒子对照支持；调用者若修改 getter 返回的槽字典，仍会修改生产状态。当前调用不这样使用。
- 生产 Main 将 explosion update 放在 impact 粒子更新之前，保留本路径先生成后推进的关系。其他共享 Math.random 消费者的完整先后顺序、真实 shade/地面查询及受控像素仍是独立范围。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 字面提取函数 | `0b939540b9e594e5bff26529b724a46e0d832a99ec435414dfadf1f8082d2aa3` |
| smolder-reference.json | `79f98caa474b25e7201a3a3fa3bb9c5bcec5f08fcf270553894af657a79ed2f9` |
