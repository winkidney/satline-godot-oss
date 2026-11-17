# 武器 canonical startup 审查

本轮未发现阻断生产默认构造的缺陷。当前 `Weapon` 从原 `I5` 的冷启动 S 开始，以 world seed `4207` 的第四次根 fork 初始化武器 RNG。旧导出快照不再充当构造初态。结论限定为已观测的 normal title、`noaudio=1`、`step=1` 路径，以及独立武器 RNG；完整 FX、AI 和其他系统的全局随机流尚未迁移。

审查读取了当前 [startup helper](../scripts/weapon_startup.gd)、[Weapon 构造函数](../scripts/weapon.gd)、[原函数参考生成器](../tools/weapon_startup_reference.cjs)、[插桩生成器](../tools/instrument_weapon_startup.py)、[浏览器采集器](../tools/collect_weapon_startup.cjs) 和已落盘报告。本次只写本文，未改生产代码或重新运行 GPU 场景。

原始来源为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。`I5` 第 78950 行前捕获父 RNG，第 79028 行前捕获 S 构造完成状态，第 80176 行 `return E` 前捕获执行 `T` 后的状态。原根 RNG 在第 85808 行由 `su(+(n.seed || 4207))` 创建。正常 bootstrap 的 level、ground/rain、explosives、weapon 构造顺序与观测一致。

| 根 fork 次序 | 所属系统 | 子 RNG seed |
| --- | --- | --- |
| 1 | level | 589939774 |
| 2 | ground/rain | 1278876144 |
| 3 | explosives | 1883172587 |
| 4 | weapon | 3554171070 |

武器 fork 前 parent.calls 为 `3`，fork 后为 `4`，根状态为 `3031300163`。`I5` 返回时武器 calls 为 `0`，其状态仍为 seed `3554171070`。trace 中 weapon id `113` 是所有 RNG 实例的登记编号，不能解释为第 113 次根 fork。其他子 RNG 自己消耗随机数，不会推进根 RNG。

插桩保留 `su` 的整数运算和原有 fork 调用，只增加计数、父编号及复制快照。`__trace()` 返回记录副本，不调用 RNG；构造状态使用 `structuredClone`，不会被后续运行改写。独立复核将原版与插桩版的四个子流各运行 1000 次，4000 个结果完全一致；连续读取 100 次 trace 不推进状态。内存重生成的 JS、HTML、manifest 与当前文件逐字节一致。原 HTML 与原 bundle 未被改写。

当前参考生成器已加入本轮建议的观测门槛：`ready === true`、`fatal === null`、空 errors、根 seed `4207`、武器 fork 前 calls `3`、返回时父 calls `4`、恰好四个 parent `0` 子流及其全部 seed/order、最终根 calls/state 与 boot 一致，以及武器 calls `0`。这使冷启动失败或 fork 次序漂移直接终止生成。

原 S literal 的 75 个顶层字段、162 个叶子值，与浏览器 construct 和 post-T 状态完全相同。采集时全局 `time.frame` 已为 `3`、`time.t` 为 `0.050000001`，但 title 阶段尚未推进武器，`current_state` 仍等于冷启动 S。全局帧计数不能用于推断武器已经运行三次 O/D。

旧 scene 快照与冷启动 S 的六处差异如下。它们说明旧快照含有运行后的状态，不能作为默认构造值。

| 字段 | 冷启动 | 旧快照 |
| --- | --- | --- |
| `t` | 0 | 0.050000001 |
| `cooldown` | 0 | -0.001 |
| `flashT` | 0 | -0.050000001 |
| `idleT` | 0 | 0.050000001 |
| `breath` | 0 | 0.07857895131232057 |
| `wallT` | 0 | 0.04666666600000001 |

构造函数深拷贝 rigs 和传入 S，避免两个 Weapon 实例互相修改初始输入。RootMotion、Lifecycle、Reload 和 Controls 则有意共享本实例的同一份 S。`time` 从该 S 同步，默认值为 `0`。现有 legacy scalar 默认值与这份 canonical 初态相容。`reset()` 保留已消耗的武器 RNG 状态，未重新播种。

`startup_info.mode` 只描述 S 来源，新增 `seed_mode` 独立描述 `canonical_fork` 或 `explicit_seed`。仅传 seed 时仍可使用 canonical S，当前 233 项检查已覆盖此组合。`weapon_seed()` 用临时独立 root 重算四次 fork；它没有推进 Native 其他系统持有的 global root。这是默认武器子流的正确种子推导，不能据此声称整个 Native bootstrap 已共享原全局 RNG。

`initial_state` 是 motion S 的隔离测试输入。它只同步 S 和 `time`，没有恢复 slot/ammo、legacy scalar、手臂弹簧或零件 private state，不能用作完整 Weapon 存档恢复接口。保留历史 fixture 的显式 S/seed 注入是合理的：原参考和 Native 得到相同初态，旧数值内核仍能回归。它也不替代 canonical 路径验证；目前射击参考已增加两枪默认构造用例，未只依靠旧快照通过测试。

| 当前证据 | 结果 | 能证明的范围 |
| --- | --- | --- |
| [startup CPU](../evidence/weapon-startup-verification.json) | 233 项，0 失败 | 默认构造 S、time、seed、前 64 个随机数、reset 保留 RNG、显式输入及独立 seed provenance |
| [startup runtime](../evidence/weapon-startup-runtime.json) | 470 帧，3 项 startup 断言，0 失败 | 实际 Main 默认 mode/seed/time，以及既有手臂、机械零件和弹匣运行路径 |
| [射击回归](../evidence/weapon-shot-verification.json) | 4 cases、96 shots、2424 比较，最大误差 `1.16974115282886e-7` | historical 与 canonical 两套输入的原 Q、武器参数及 recoil/flash 方法；canonical cases 实际使用默认构造 |
| [controls 回归](../evidence/weapon-motion-controls-verification.json) | 211164 比较，最大误差 `1.4210854715202e-14`，0 失败 | 显式历史 S 输入下已定义的控制字段 |
| [public 回归](../evidence/weapon-public-verification.json) | 22786 项，误差 0 | 显式历史输入下已定义的 public 方法范围 |

startup runtime 报告产生于 `seed_mode` 元数据增加之前，报告未包含或断言该字段；新增字段由最新 CPU 检查覆盖。470 帧报告也不等于逐帧完整 O/S 与原作比较。参考侧 S 来自原 literal 与独立冷浏览器观测，而不是 Native 反向导出；Native 构造直接加载同一 canonical JSON，因此单独的 S 构造比较主要验证正确装载和无意外改写，其来源可信度依赖前述两条原作证据。

当前来源及 fixture 校验值如下。

| 文件或内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 原 HTML | `b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb` |
| 原 S literal | `e5ad183127f49eed090ca3c2025ba5988f19bed07ad82ef8147ef9c399765cd4` |
| 插桩 JS | `7b00f3bf1dbb5e6dd3a3a0f3ef9c464a1da774d64ecd816b39ed71a2c0e15e93` |
| [浏览器观测 JSON](../assets/export/fixtures/weapon-startup-observed.json) | `edd6c9e29581ac63b7a9547666db002d2284d42f5ea580fabc08969f2aa39408` |
| [canonical JSON](../assets/export/weapon-startup.json) | `72833ce93d8ed51bde498414998c072430d9fb68ed89ca05671e391d0158d9a5` |

插桩生成物与 manifest 位于 `artifact-rendering-study/output/playwright/`。浏览器返回的 observed JSON 没有内嵌它实际加载的 JS 响应哈希，当前 provenance 是生成物、manifest、源差异和观测内容的关联审计。若后续更新源版本，建议为每个替换片段加入唯一命中断言，并将实际响应哈希绑定到新观测；这不影响当前已复核的固定源版本结论。

后续仍需迁移完整全局 root 的生命周期、各系统 fork 和消费次序，并验证真实 gameplay 首 tick 的系统调度。当前默认 seed `4207` 的 normal/noaudio 冷启动证据，也不能自动外推到任意 world seed、其他启动参数或完整首帧图像一致性。
