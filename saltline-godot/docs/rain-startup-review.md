# 雨与雷电启动状态审查

当前 timer 恢复、共享雨流接线和 game 冷启动时钟未发现生产阻断。构造不再额外抽样；第一次自然雷电使用第 40642、40643 次雨子流输出，第二次使用第 40644、40645 次。Session retry 保留已有 timer、雨量、目标雨量和 RNG。此前 [bootstrap 审查](source-bootstrap-review.md) 中尚未接入动态雨的边界，本轮已推进到实际 Main 的自然雷电时序验证。

审查读取 [Rain](../scripts/rain.gd)、[Main](../scripts/main.gd)、[bootstrap 参考](../tools/source_bootstrap_reference.cjs)、[rain 参考](../tools/rain_reference.cjs)、[CPU 验证器](../tools/verify_rain.gd) 和 [实机验证器](../tools/verify_rain_thunder_runtime.gd)，仅写本文。原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 的 `Vw`、`Gw`、`Vg`、`cL` 和 thunder 回调。

high 设置的 rain 为 `1`，原 `Vw` 每实例消耗四次随机数。雨本体 `9000+260` 个实例，加 splash `900` 个实例，共消费 `4×(9000+260+900)=40640` 次。第 56680 行 `E=22+t()*25` 恰好消费第 40641 次；下一行雨相位 `M=0`。由原 `su` 重算的最后构造样本为 `0.3691861836705357`，故初始 timer 为 `31.229654591763392` 秒。

bootstrap 参考在构造重放循环中保存最后 sample，再生成后续 sequence，二者没有混用。资产中的 rain initial_state 是 `time=0`、`level=.6`、`target=.6`、上述 timer；流本身仍为 seed `1278876144`、state `1866875301`、calls `40641`。Native Rain 构造直接装载状态，不调用 `randf()`。Main 传入同一个 `source_bootstrap.streams.rain`，没有复制其 state，实机也断言了对象身份和构造后 calls。

`random_stream` 与 `initial_state` 是一组输入。默认构造提供 canonical 两者；历史隔离用例则显式提供已预抽一次的 `SourceRng(1337)` 和相应初态。仅换随机流、仍使用 canonical timer，不构成另一 seed 的正确冷启动。当前 Main 和历史验证器都提供了匹配的状态。

原 `Gw.update` 每次先递减 timer；`E<=0` 时依次消费两次，第一次数值设置 `30+t()*30`，第二次设置 intensity `.3+.7*t()`。原式不补回跨过零点的余量，也不循环补发多次事件。Native 保留这个单次 if 行为，没有把它改成周期累计器。

参考侧直接提取原 `su` 和完整 `Gw.update`。canonical 包装层先抽 40640 次，再用第 40641 次建立初始 timer；Native canonical 用默认构造，未将参考的 initial 直接注入 Native。初始构造公式在参考包装层重建，已另由原 `Vw/Gw` 源码计数核对；该测试没有重新执行完整几何构造。legacy 输入从 seed `1337` 抽一次并从 `.05` 秒开始，属于历史合成状态回归，不能用于证明 normal startup。

| 证据 | 当前结果 | 验证范围 |
| --- | --- | --- |
| [legacy CPU](../evidence/rain-verification.json) | 1000 帧、98000 次报告比较、2000 次 RNG 检查、0 失败；1 次雷电，calls `1→3` | 显式历史状态下的原 update 闭包 |
| [canonical CPU](../evidence/rain-canonical-verification.json) | 3000 帧、294000 次报告比较、6000 次 RNG 检查、0 失败；4 次雷电，calls `40641→40649` | 默认启动、雨量渐变、FOV/分辨率、遮雨盒、skylight、可见性、timer 和事件 |
| [Main runtime](../evidence/rain-thunder-runtime.json) | 1450 帧、72.5 秒、10150 checks、0 失败；calls `40645` | 实际 ambient 更新、共享 RNG、全局/雨时钟、自然雷电到 sky 回调 |

CPU 标量阈值保持 `1e-10`，Vector 存储路径保持 `1e-5`，RNG state/count 每帧精确比较。canonical 最大标量误差 `2.8421709430404e-14`，legacy 为 `7.105427357601e-15`；两者最大 Vector 误差均为 `4.1961669872137e-7`。3000 帧测试使用 `1/60`、`.05`、`.1` 秒交替步长及合成环境输入，属于闭包数值验证，不代表真实渲染器的逐帧调度。

1450 帧实机逐次调用实际 Main `_process(.05)`，游戏逻辑固定在启动状态。雷电自然发生在第 `625`、`1431` 帧，intensity 分别为 `0.783887012978084`、`0.609752463223413`；未强制归零 timer。两次事件同帧到达 sky，累计 34 帧 `sky_weather.value>0`，最大标量误差 `7.105427357601e-15`。已保存 [625 帧](../evidence/rain-thunder-0625.png) 和 [1431 帧](../evidence/rain-thunder-1431.png) 图像，但该测试没有作原作图像逐像素比较。

原全局 `cL.time.t` 在第 85809 行初始化为 `0`，雨 `M` 和 ground `E` 也各从 `0` 开始。Main 的 game_mode 现从 `animation_time=0` 启动，修正了继承旧导出 `.050000001` 所造成的相位差；最新 runtime 新增初始 global `0` 及每帧 global/rain 同步检查，已经通过。

这个同步条件只适用于本次没有暂停的路径。原第 85996–86001 行在 paused 时仍推进全局 time；第 86062–86067 行暂停 ground，所以雨 time/timer 冻结；render 的天空时间和已有闪光衰减仍推进。当前 Main 同样让 animation_time 和 sky update 继续，在 paused 时跳过 rain。不能要求暂停之后 global 与 rain 永远相等。

原 `pT` retry/start 不重建 `Gw`，也不调用 `ground.setRain`。Native Session.reset 同样不重建 Rain、不改 target、不设置 RNG seed。后续从当前相位继续是源行为。这一项本轮由源码和调用路径审查确认。[780 帧流程](../evidence/game-flow-runtime.json) 已完成两次 retry、暂停冻结并回到 playing；上述 CPU 和 1450 帧雷电探针没有执行 pause/retry，流程报告也没有记录每次 retry 前后完整雨状态，不能将这些证据写成原作雨状态的 retry 数值对照。

非 game 隔离预览保留现有短快照 `.050000001` 秒，同时显式设置 rain.time，并从初始 timer 扣掉同样时长，不增加 RNG 消费。该恢复适用于当前已知未发生第一次 thunder、没有 pause/雨量改变的短快照；不能推广为任意时间存档恢复。若未来快照已经经历雷电，需要同时恢复对应的 timer、state/calls 和雨量历史，不能继续只减 snapshot age。

雷电方向仍属于另一随机类别。原 render thunder 回调第 36830、36834–36835 行消耗三次 `Math.random`；Native [SkyWeather](../scripts/sky_weather.gd) 使用三个独立于雨子流的全局 `randf()`。音频还存在其自己的 `Math.random` 消费。现在可确认雨事件的时间与 intensity、共享子流消费、事件到 sky 的传递；不能据此宣称天空方向、音频时序或整张闪电画面与原浏览器一致。

本轮审查提出的强度 finite 检查已修正。两个 GD 验证器现在都检查 actual/expected 有限，再执行 `1e-10` 比较；参考生成器也拒绝非有限 time/level/timer/intensity。legacy/canonical CPU 已重跑通过。1450 帧 GPU 没有因这一验证器修改再次运行，而是对原归档的两次实际与 expected 强度直接离线检查有限性及相同阈值，均通过；本次审查也独立复核了这两个归档事件。运行输入和生产实现没有因该检查变化。

独立无写入重放确认 bootstrap 与 runtime fixture 逐字一致，legacy/canonical 的全部数值与帧也一致。原有两个 fixture 曾缺新增的 `runtime:false` 元数据，当前磁盘已重生成补齐。最终主要文件校验值如下。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 原 Gw.update | `7238574fc745406116523c03559b42bb5bc90487ea5b78eec292b325a7b5f747` |
| source-bootstrap.json | `d93b727ba02c547ddf2fc88e6d9ef28057bef3d7393fe8927aa1f0d8b699aad8` |
| rain-reference.json | `b5db36c57aacb97ca3c5d4fab1c836984055486b9a366d19b8bc3d6a69b7a041` |
| rain-canonical-reference.json | `9c2fd5b975d02f859d51b68a9f5f49768d873024e14ff6835ed44e5160f02382` |
| rain-runtime-reference.json | `f0dc57c56b797b6ee7c38bf327619ad2ca4bd10971de43631e09ee3296961e26` |
