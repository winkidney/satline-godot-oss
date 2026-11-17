# Explosion Q 初始生成审查

本轮原 Q 初始生成的受控对照通过，未发现该范围内的生产阻断。随机顺序与高速 spark 精度修正均保留原公式。原 G/oe 的生命周期、24 槽复用、爆炸事件及整场 FX 调度仍未完成联合验证。本次只读审查，只新增此文档。

依据是 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 第 59761–59970 行的 `Q`、所用 `go/M/_/w/S/R/u1` 和 `jg.add`。实现为 [explosion_effects.gd](../scripts/explosion_effects.gd) 及 [impact_effects.gd](../scripts/impact_effects.gd)。

当前 Q 顺序与原函数一致。先 clamp size 到 `.4..4`，查询一次 floor 与 shade，发两次 light 请求和三道 flash，再依次生成受光火球、加法火球、烟、smolder 创建请求、高速 sparks、余烬、可选地面 ring/烟/scorch，最后生成 debris。第二道 flash 的随机 frame 在调用前消费；flash 成功 emit 后才消费 rotation。受光火球成功后按可选 frame、rotation、rotation speed 顺序消费，`i%4==0` 的固定 frame 7 不抽随机。加法火球 rotation 同样只在 emit 成功后消费。

高速 spark 按原调用参数顺序先抽 life，再抽 width。烟的 fade/turbulence 覆盖字段显式存为 Float32。地面 ring 委托已经对照过的 `fx.ripple`，保留成功 emit 后抽 rotation 的语义。`fragments` 新增可选 `floor_override`，Q 传入初次 `E(j)` 的结果，避免在提高碎片起点之后重新查地面；其他调用未传 override 时仍走原 API。

首次 [精度失败](../evidence/explosion-random-initial-precision.json) 的高速 velocity 最大误差为 `3.81469727273043e-6`，超过原定 `3e-6` 门槛。原 Three 在 double 方向乘速度后才写 Float32Array，旧 Native 先构造 Vector3，提前量化了方向。当前 `scatter_components` 返回 PackedFloat64Array，Q 高速 spark 以 double 分量完成乘法，再构造最终 Vector3。`scatter` 包装仍返回 Vector3，其四次随机消费和归一化公式没有改变。本轮未放宽阈值，也未替换随机场。

[参考生成器](../tools/explosion_random_reference.cjs) 从原 bundle 字面提取 Q、helpers、Float32Array pool 和 `jg.add`，没有从 Native 输出推导 expected。tape 在 JS 执行前量化为 `k/2^53`，再以 hex u53 导出，[Native 验证器](../tools/verify_explosion_random.gd) 解码同一值。所有比较检查误差有限性，随机次数和容器数量精确比较，数值字段使用 `3e-6`。

48 cases 覆盖 size `.1/.4/1/1.9/4/6`、容量 2/256、floor 0/−50、shade 1/.2。fixture 的 `grounded` 字段只是选择 floor 的标签，实际仍由原 `y-floor<1.4*q` 判断。输入 y=1，size `.1/.4` 都 clamp 到 `.4`，即使 floor=0 也不触发地面分支。实际地面分支和 scorch 各命中 16 次。最大 lit/add 粒子数为 88/139，最大 debris 为 37；容量 2 覆盖拒绝发射时的随机消费，256 组容纳全部初始粒子。

原 decal `add` 在第 58659–58682 行固定消费 tile、size variation、rotation 三次随机数，单 tile 的 scorch 也会抽 tile。参考接收器据此固定消费三次，Native 则执行真实 Decals.add，所以后续 debris 使用相同 tape 位置。但验证器只比较 decal 数量，没有比较保存的 point、normal、size、shade、alpha 或生成几何，不能称 scorch 参数和几何已完整对齐。

| 证据 | 结果 | 可支持的范围 |
| --- | --- | --- |
| [Q 初始生成对照](../evidence/explosion-random-verification.json) | 48 cases、122052 checks、68808 draws；失败 0；最大误差 `1.90734863636521e-6` | particles/debris 初始字段与 RGB、随机消费、light 请求、smolder 创建参数及 decal 数量 |
| [既有六尺寸数量回归](../evidence/explosion-verification.json) | 六尺寸，失败 0 | clamp 端点与初始粒子/碎片数量 |
| [splash/scatter 回归](../evidence/splash-random-verification.json) | 25419 checks、10115 draws，含 15 个定向 scatter cases；失败 0 | scatter 包装及现有 splash 发射路径 |
| [实机爆炸预览](../evidence/explosion-random-runtime.json) | 330 帧；93 additive、70 lit、24 debris、2 light、1 scorch；最终两粒子池、debris 与 smolder 均为 0 | 真实渲染接入和释放回归；[日志](../evidence/explosion-random-runtime.log) 无 ERROR/泄漏报告 |

实机的 70 lit 包含后续 smolder 发射。该运行说明现有更新路径能够推进并清理，不能替代原 oe 的数值和随机序列对照。主线已查看第 31/45 帧截图，本次审查没有重跑或扩大为原作像素对比。

后续仍须保留这些范围：

- G 是创建请求记录器，没有字面执行其 24 槽分配。每例只有一次爆炸，验证器核对 position/ttl/scale/shade，未比较 kind、acc/time/drop 初值、满槽拒绝或复用顺序。oe 的延迟随机消费不在 fixture 内。
- 原 Q 最后写 `Z.size=O` 并发 explosion 事件，使用未 clamp 的输入 size。Native 也传原始 size，但参考事件接收者是空 stub，本轮未证明 payload、事件时序或连锁爆炸。
- shade、floor 为受控值，未执行真实地面与遮挡查询，未测贴地判定的严格边界。固定位置不能覆盖任意世界坐标上的浮点误差。
- 本轮没有粒子运动、碰撞、池回收/复用、完整 scorch 几何、实际 light 分配、受控着色像素或完整共享 FX 事件顺序的源对照。默认 Math.random 适配仍不声称与 V8 熵序列一致。

独立禁写重放最终生成器与 fixture 逐字一致；独立按验证器字段重算得到 122052 checks，与报告相符。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 字面提取函数 | `6631ce8fdd69669354a5ef8d22515402c01d527d6d2330ea4591714470432ff5` |
| explosion-random-reference.json | `cb919e0e51ad4578a5c6ea5f9fdc6458d4c0fae219a0de7beca3507924d8362a` |
