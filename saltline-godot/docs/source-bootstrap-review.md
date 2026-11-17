# 共享 bootstrap 与爆炸物随机流审查

当前实现未发现阻断本轮接入的问题。Main 创建一份 bootstrap，将同一个 root 对象交给 Mission，将对应子流对象交给 Weapon 和 Explosives。构造后状态、原 `su` 输出和爆炸物 chain 消费均有独立参考。Session retry 没有重建这些对象或重新播种。结论限定为固定 `seed=4207`、high/noaudio、normal title 路径，以及本轮明确验证的消费者。

本次只读审查 [bootstrap](../scripts/source_bootstrap.gd)、[SourceRng](../scripts/source_rng.gd)、[Main](../scripts/main.gd)、[Explosives](../scripts/explosives.gd)、[Mission](../scripts/mission.gd)、[Weapon](../scripts/weapon.gd)、[Session](../scripts/session.gd) 和参考、验证工具，仅新增本文。原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 的 `su` 第 34783 行、`Gw` 第 56614 行、`yE` 第 69404 行、`I5` 第 78949 行、`W5` 第 82926 行和 `pT` 第 84792 行。

| 流 | seed | 构造后 state | 构造后 calls |
| --- | --- | --- | --- |
| root | 4207 | 3031300163 | 4 |
| level | 589939774 | 759034465 | 183 |
| rain | 1278876144 | 1866875301 | 40641 |
| explosives | 1883172587 | 3586856006 | 15 |
| weapon | 3554171070 | 3554171070 | 0 |

bootstrap 顺序执行四次 `root.fork()`，再将每个子流恢复到浏览器观测的构造后 state/calls。烘焙的模型与雨几何无需重新生成，其构造消费也没有再次执行。子流的后续调用不推进 root。`SourceRng` 使用 32 位掩码和拆分乘法复现 `Math.imul`，`calls` 只用于记录；输出仍由原 state 运算决定。`seed` setter 会重置 state/calls，因此运行期 reset 路径不得再给共享流设置 seed，当前路径没有此操作。

[参考生成器](../tools/source_bootstrap_reference.cjs) 从原 bundle 字面提取 `su`，使用前一轮冷浏览器 trace 重放各子流的构造消费，再生成每条流的前 64 个后续输出。最新版本已检查 ready/fatal/errors、high/noaudio、无 shot/show、root seed、boot/ready root state 一致、四个子流 seed/order，以及固定 calls `183/40641/15/0`。父子 state 也经过原递增公式复核。独立无写入重生成的 JSON 与当前资产逐字节相同。

[335 项检查](../evidence/source-bootstrap-verification.json) 分别核验五条流的 seed/state/calls，再各比较 64 个原始 uint32 输出，全部精确相等。以 `randf()*2^32` 还原整数避免了十进制 JSON 小数解析末位差异；没有放宽随机数误差。Native 从同一 JSON 恢复 state，因此初始 state 比较主要验证装载，后续输出参考和浏览器 trace 才是原算法与来源的独立证据。

Main 通过显式对象注入完成共享，Weapon 的 `random_stream` 优先于 seed 参数，并记录 `seed_mode=shared_stream`。RootMotion 的随机回调绑定该对象，没有复制当前 state。Mission 和 Explosives 的默认构造仍会建立独立 bootstrap，便于隔离测试；多个默认构造不能用作生产共享的替代。实际 Main 已显式传入对象。

Session reset 只清除 gameplay 内容，随后调用既有 Weapon.reset、Explosives.reset、Mission.reset_run，再按需生成 patrol。Weapon 保留 RNG 历史；Mission 保留原 root，新的 patrol 合法地继续消耗它。原 `pT` 的 start/retry 同样重置 run 并生成新 patrol，没有重新调用 `su`。因此 retry 后 root 值可能继续前进，正确要求是保持原对象及消费顺序，而不是要求 reset 前后数值完全不变。

原 `yE` 的子流 `s` 只用于额外桶的构造 yaw 和 explosion callback 的 chain delay。构造 yaw 发生于第 69537 行附近，已观测消费 15 次；第 69630 行附近的 chain 仅在物体 alive、距离不大于半径且不小于 `0.05` 时调用一次 `s()`。delay 为 `0.14+s()*0.3+distance*0.03`。即使已有 fuse 更短，仍先消费一次随机数再取 min。Native 从 post15 开始，保留 item 顺序、这些条件和 fuse 更新，未再消费烘焙 yaw。15 次是本次地图与 seed 的观测结果，不能推广到其他资产构造。

第 69684 行的原 reset 保留 `tick`、leak 信息和 RNG，只恢复 alive/hp/fuse、显示和碰撞。Native 同样没有清零 `tick` 或 rewind RNG。第 69693 行的原 update 泄漏分支调用 `fx.sparks`、`fx.smoke`、light flash，不调用 `s`；其 FX 随机性属于原 `Math.random` 类别。当前 Native 已改用公共 sparks/smoke 方法，从 FX 自有 RNG 消费，修正了旧泄漏分支污染爆炸物流的问题。

[爆炸物参考](../tools/explosive_stream_reference.cjs) 直接提取原 explosion callback 和 update。它先用原 `su` 消耗 15 次，然后对 21 个导出物体执行 180 步。当前实际覆盖为 reset 20 次、chain 120 次、leak 40 次；chain 的 size `1`、`2` 各 60 次。代码数组中的 `0.7` 被同一循环的 reset/leak 分支截走，当前没有形成该 size 的 chain 用例。参考 reset 的标量恢复是测试包装层，不是另一个完整字面 reset 提取。

[Native 验证](../evidence/explosive-stream-verification.json) 共 8180 项，最大 fuse/tick 误差 `1.16450782350341e-9`，阈值保持 `2e-6`。每一步 RNG state/count 精确一致，calls 从 `15` 到 `195`。40 个 leak 用例实际调用 Native FX，分别断言爆炸物 state 不动、FX state 前进，并比较 sparks/smoke/light 请求顺序。该证据覆盖 chain 回调和 `update(0)` 泄漏路径，没有触发完整 detonation；参考中的爆炸函数会直接抛错，防止意外扩大范围。源位置先量化到 Native Vector3 存储精度，故不能将此结果表述为原双精度世界坐标的逐位等价。

FX 粒子数值仍未与原 `Math.random` 输出对齐。Native impact/explosion 等效果使用各自的 RNG，原作还存在其他共享 `Math.random` 消费。当前证明的是它们不再改写爆炸物的确定性子流，不能据此声明这些 FX 流彼此关系、粒子轨迹或整场随机事件顺序已经复刻。

[Mission canonical 参考](../tools/mission_reference.cjs) 在执行完整原 `pT` 前使用原 `su(4207)` 消耗四次。`fork()` 对父流恰好消耗一次，因此与 post4 root 等价。Native canonical 测试使用默认构造，历史 `1337` fixture 显式注入原初始流，双方输入保持一致。canonical 共 260 帧 Mission 加 1100 帧 Holdout、480866 项比较，最大误差 `1.89188867949497e-6`；历史回归 482543 项，最大误差 `1.88089907027233e-6`，均通过现有 `0.001` 阈值。这里比较的是受控 enemy spawn、LOS/nav、HUD/input 下的选定状态和事件，没有逐帧断言 Mission RNG 的完整 state/count；报告中的 failure retries 指失败 spawn 重试，不能代替真实死亡 retry 证明。

| 实机证据 | 当前结果 | 边界 |
| --- | --- | --- |
| [共享 bootstrap runtime](../evidence/source-bootstrap-runtime.json) | 470 帧，4 项共享/隔离检查，0 失败；结束 root.calls `115`、explosives.calls `15`、weapon.calls `37` | 实际 Main 的三条对象身份和独立 AI seed，加既有手臂/机械/弹匣运行路径；结束计数不是原作全场逐帧对照 |
| [runtime 日志](../evidence/source-bootstrap-runtime.log) | 未发现 ERROR、脚本错误或对象泄漏记录 | 本轮已保存的 470 帧运行 |
| [game flow](../evidence/game-flow-runtime.json) | 780 帧、2 次 retry、`pause_frozen=true`、最终 `playing` | 实际 UI/Session 重置功能；不含每次 reset 前后 RNG 身份及消费数的独立记录 |

AI 原 `W5` 明确创建独立 `su(eseed || 9001)`，没有从 world root fork。本轮保留 Native AI seed `9001`，没有把它并入 root；实际 AI 消费及行为的完整对应仍按原模块证据范围判断。

rain 仍有一个必须保留的后续边界。`Gw` 在生成几何后，用最后一次构造 draw 设置 `E=22+t()*25`，之后每次 thunder 再消耗两次，分别设置下一间隔与 intensity。当前 `rain.gd` 仍使用独立 `SourceRng(1337)`，Main 尚未注入 `streams.rain`。所以本轮 rain 仅恢复并验证 post-build state，动态 thunder 尚未接入共享流。后续接入不能将 post40641 流直接传给现构造再生成初始 timer，否则会多消耗一次；需要恢复最后一次构造 draw 对应的 timer 或保存原 timer，并从 post40641 继续。

固定源和主要 fixture 的 SHA-256 如下。浏览器响应本身未嵌入 JS 响应哈希的既有边界见 [startup 审查](weapon-startup-review.md)，本轮新增 observation hash 绑定当前观测文件，未补做新浏览器采集。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 冷浏览器观测 | `edd6c9e29581ac63b7a9547666db002d2284d42f5ea580fabc08969f2aa39408` |
| source-bootstrap.json | `fd49d57b3b789fd5470fc775042efba676136ae7930b371b256f615958c0f004` |
| explosive-stream-reference.json | `6c607ea8f59e116de75393143bf86ef2538f1ad658ccd2f9d56ba55b0e626bb1` |
| mission-canonical-reference.json | `22f28e3d7c407046d8b2641bb8ec7051bacc2643911dc90203a278ae7c914134` |
