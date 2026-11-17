# FX 共享随机源审查

本轮审查限定为 FX 随机源、53 位 tape、对象注入，以及已经独立对照的原粒子 emit/clear 与 thunder callback。提出的两项基础适配问题均已修正，最终未发现生产阻断。共享随机源与原 `su` 子流分离的方案成立；完整 tracer、shell、decal、impact、explosion 等函数的消费顺序仍需后续联合原函数验证。

本次读取 [FxRandom](../scripts/fx_random.gd)、[Main](../scripts/main.gd)、[ImpactEffects](../scripts/impact_effects.gd)、[Particles](../scripts/particles.gd)、[Debris](../scripts/debris.gd)、[Shells](../scripts/shells.gd)、[Decals](../scripts/decals.gd)、[ExplosionEffects](../scripts/explosion_effects.gd)、[SkyWeather](../scripts/sky_weather.gd) 和独立参考工具，只写本文，未改生产代码。

审查提出的两项修正已落盘。

- [Tracers](../scripts/tracers.gd) 原先仍保留独立 PCG seed `4207`。原 bundle 第 58148 行的 tracer 首帧 travel 明确调用 `Math.random`，属于同一个 FX 随机类别。现在 Tracers 支持同样的可选随机源注入，Main 实际 tracer 和 Impact 内两个绘制 batch 均传入共享服务。该修正只补对象归属，不等于验证 tracer 全部数值与消费顺序。
- `randi_range` 原实现将 minimum 放进 floor。对 `u=1−2^-53`、范围 `[1,2]`，`1+2*u` 在 double 中舍入为 `3`，导致越界。现在按原 Three 第 994 行的顺序使用 `minimum+floor(span*u)`。新增独立 near-1 用例用 hex `1fffffffffffff` 恢复输入，确认 `[1,2]` 返回 `2`。该用例额外增加一项检查，未改动原 196 步共享序列及 183 次 draw。

默认 `randf()` 以两个全局 `randi()` 输出拼接 27 位和 26 位，得到整数 `k∈[0,2^53−1]`，再除以 `2^53`。这些整数及缩放在 double 中可以精确表示，最大值为 `1−2^-53`，不会返回 `1`。本地固定引擎 `VariantUtilityFunctions::randi()` 返回 `Math::rand()` 的 uint32 值并装入 int64，故右移前没有符号扩展问题。该实现不读写任何 `SaltlineSourceRng` 的 state，也没有将 FX 的随机数挂到 world、weapon、rain 或 explosives 子流。

这里的默认随机源来自 Godot 全局随机状态，仍会受其他全局随机调用影响；两次底层 draw 合成一个服务 draw，`FxRandom.calls` 统计的是服务调用次数。它提供 `[0,1)` 的 53 位取值能力，不承诺 V8 使用相同生成器、熵状态或输出序列。4096 个默认样本的有限性和范围检查，也不构成统计质量或浏览器熵等价证明。

tape 模式复制传入的数值数组，按 calls 顺序返回，不再访问默认随机源。输入检查要求有限且 `0≤value<1`；当前检查使用 assert，适用于本项目诊断构建，不能作为 release 中任意外部数据的完整验证接口。耗尽时标记 exhausted、报错并返回 NaN，不回绕、不补抽默认熵。当前成功路径验证断言 tape 未耗尽；非法输入和耗尽分支没有单独的成功/拒绝案例。

[参考生成器](../tools/fx_random_reference.cjs) 直接提取完整原 `u1` 类和 render thunder callback，只替换这些函数所看到的 `Math.random`。构造合成 tape 的 `su(9007)` 只是测试输入生成器，不表示原 FX 使用 `su`。源函数之后仍通过各自的 `Math.random` 调用依序读取同一个 tape。

Native 验证器从 `tape_u53` 十六进制整数恢复 double，不使用 JSON 十进制 `tape` 字段作为运行输入。这修复了 near-1 样本经 JSON 解析丢失低位的问题。独立核对所有 hex 输入均能逐位恢复；实际消费的 183 个值中有 179 个不在 32 位随机数网格上。near-1 进入第二次成功 emit，原 Float32 粒子 seed 舍入为 `100`，Native 同样如此，不能将这个合法的存储舍入误认为随机源返回了 `1`。

原 `u1.clear` 在 bundle 第 57904–57907 行，不调用随机数；满池在第 57909 行提前返回；成功 emit 在第 57934 行消耗一次，为 Float32 seed 赋值。Native 满池分支也在 seed 抽样前返回，成功后才合并 options。即使调用者覆盖 seed，成功 emit 仍必须先消费这一次，当前实现保留了原顺序。

| 196 步参考的实际操作 | 次数 | 服务 draw |
| --- | --- | --- |
| 成功 emit | 71 | 71 |
| 满池拒绝 | 41 | 0 |
| thunder callback | 28 | 84 |
| 浮点 range | 14 | 14 |
| 整数 range | 14 | 14 |
| clear | 28 | 0 |
| 合计 | 196 | 183 |

其中 8 次成功 seed override 仍消费一次，3 次满池 seed override 不消费；所有 clear 都发生在有粒子的池上。A/B 两池与 sky 交错共享 tape，每步比较 calls 和状态，能够发现本组操作的消费错位。这里的“满池不消费”仅指 pool.emit 内部；更上层 FX 调用在进入 emit 前计算参数时，仍可能已经消费随机数，本轮未验证所有这些调用者。

[25837 项结果](../evidence/fx-random-verification.json) 包含逐操作状态比较、4096 次默认熵范围检查、最终 draw 检查和新增非零整数下界检查，0 失败。标量阈值 `1e-10`、sky direction 阈值 `1e-7`，最大误差 `3.33988862122325e-8`。原 sky callback 的三次 Math.random 现在经同一个服务消费；方向计算先以 double 完成三角函数、长度和归一化，最后一次构造 Vector3 才降为 Native 分量精度。原 source su 流不参与这个方向生成。

当前 Main 已检查十一处共享引用：Impact、自身 additive/lit pools、debris、shells、decals、explosion、sky、实际 tracer，以及 Impact 两个绘制 batch。两个 batch 复用 Tracers 类，常规粒子绘制本身不因此增加随机消费。Impact.setup 将同一 rng 继续传给两个 pool、debris 和 batch；Explosion 的默认随机源继承 effects.rng，避免单独构造时又创建一个独立效果流。各默认属性创建服务本身不消费随机数，Main 再替换为共享对象不会隐式推进全局熵。

clear、Session retry 和 pool 清理均未重建 Main 的 `fx_random` 或重置其 calls；随机历史继续。单独创建多个服务时，默认熵仍来自 Godot 全局状态，但这些服务有独立计数或 tape，因此联合诊断必须像 Main 一样显式传递同一个实例。把各子系统分别灌入同一组 tape 的副本，不等价于原共享 Math.random。

[最终 470 帧 runtime](../evidence/fx-random-runtime.json) 记录十一项对象身份检查、301 次服务消费、0 失败。它证明实际 Main 使用了这些共享对象，并且真实路径发生消费；301 没有对应原整场事件轨迹的断言，不能视为已对齐原全局消费总量。默认熵会改变后续效果分支，也不能用两次独立实机运行的 calls 差值推算某类效果应消费多少次。基础 emit/clear/tape 测试未覆盖粒子 update、回收后复用和排序。

已有粒子 3376 字段、debris 8320 字段、decal/splash/explosion、爆炸物流 8180 项及 sky 500 帧回归仍通过。这些保留各自原有范围，例如 debris 只对齐初始随机参数，splash/explosion 检查初始发射数量；不构成全部 FX 函数使用同一 tape 时的联合证明。后续应按实际调用顺序逐函数移植参考，比较逐步 calls、拒绝/覆盖分支和输出，再接入包含 tracer、shell、impact、decal、explosion 的联合序列。

初版 range helper 未使用 `self.randf()`，曾错误调用全局随机函数，已经修正为显式 self 调用。[初始失败](../evidence/fx-random-initial-failure.json) 保留，不应以最终通过结果覆盖诊断过程。十六进制 tape 修复没有修改原公式或放宽容差。

独立无写入执行当前参考生成器，产物与已存 fixture 逐字一致。固定来源校验值如下。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 原 u1 + thunder callback | `24e56cb52f1ae33fa505c1dd899a6dac3a8a1d800b5a886efd03cd7635f7ba41` |
| fx-random-reference.json | `b5641f77b823cf90ce20b1ea9486d716bc6b7af96a8bc336683eb00a423bcbfe` |
