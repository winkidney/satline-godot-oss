# 换弹运动与生命周期核审查

本次按当前磁盘文件核对原 bundle、native 实现、参考生成器及验证报告。未发现两枪换弹对共享 S 的冲量、连续权重或一次性 flags 有算法遗漏；生命周期的内部 equip、reset、snap 也逐字段符合原作。结论限于这些独立状态核，生产尚未调用，不能据此宣称实时换弹、零件运动、手臂 IK 或完整生命周期已接管。

审查只新增本文，不修改运行代码或测试。以下数值来自主线已经运行并落盘的报告，本次没有重复运行 native。

## 当前证据

| 范围 | 样本 | 比较数 | 最大绝对误差 | 结果 |
| --- | --- | --- | --- | --- |
| 两枪换弹 S、flags、完整事件 payload、arm 调用计数 | 12 case，2,625 步 | 453,273 | 2.21350715534641e-15 | 0 失败，门槛 1e-12 |
| 内部 equip/reset/snap 的共享 S | 96 次操作 | 15,552 | 0 | 0 失败，门槛 1e-12 |

权威报告为 [weapon-reload-motion-verification.json](../evidence/weapon-reload-motion-verification.json) 和 [weapon-motion-lifecycle-verification.json](../evidence/weapon-motion-lifecycle-verification.json)。实现范围与复现命令见 [source-weapon-reload-motion.md](source-weapon-reload-motion.md)。

源码为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)，SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。换弹首尾片段 SHA256 为 `29929b9aebe2fafd0865084ea09a4e162a754d3ac1f4cb2f058953059d5757b3`；生命周期片段为 `8fc340daf17cfc13acc5cd9c41f38bce8c2eb3f96e8a533de6e8dbe35483529f`。这些是原文切片的身份，不是完整生产集成的证明。

## 换弹切片与公式

[weapon_reload_motion_reference.cjs](../tools/weapon_reload_motion_reference.cjs) 从原 bundle 直接提取 rifle/pistol reload 的首尾、`f/h` 事件函数、`ft/It` 时间表、`B1/H1` 和 `Ot/dn` 等 helpers；没有读取 native 实现来生成 expected。原 Three 库也从同一 bundle 加载。初始 S 与枪配置来自已导出的 scene 快照，两端共用这份输入属于明确的测试前提。

逐段核对如下：

- Rifle L77041–77084 包含所有换弹事件冲量和 anticipation，L77169–77172 写 `reloadW/rackW`。省略的 L77085–77168 修改手臂目标 O、姿态和弹匣 transform；其局部 helpers 只修改向量、数组或零件，没有隐藏的 S 写入。
- Pistol L78698–78715 包含事件冲量和 anticipation，L78807–78814 写连续权重。省略的 L78716–78806 修改手臂目标 G、弹匣、slide/barrel 及局部零件变量；`$` helper L78595–78599 不写 S。
- `B1/H1` 在区间终点立即返回 0。native `window()` 保留 `time < start || time >= finish`，没有错误地让 anticipation 在终点继续保持 1。
- Rifle 的退出权重依赖本次 `reload.T`，empty/tactical 的 back/release/bolt 时间与冲量分别选择。Pistol 的退出权重依赖 magin/slide 派生时刻，tactical 的 rackW 恒为 0。两路公式和表达顺序均相符。
- Rifle 的 `regrip + .025` tug 独立写 `f.tug` 并施加一次 bump，不误用 magin flag。`f.fresh` 仅标记换新弹匣。重复时间或时间回退不清这些 flags；连续曲线仍按当前 time 重新计算。
- `clear_targets()` 只清 `reloadW/rackW/antYT/antRT`。它不清已经注入弹簧的速度，符合原 O 的完成/无换弹分支。

审查中发现的两处参考覆盖问题已经修正：战术 rifle `boltback` 的原 `F={partial:true}` 恢复，native 与 expected 都比较完整 `phase/empty/weapon/partial`；原先遗漏的根曲线派生时间边界已增加 ±1e-9。当前 2,625 步报告包含这些修正，不能再引用早期 2,553 步、仅 phase 的结果作为最终证据。

[verify_weapon_reload_motion.gd](../tools/verify_weapon_reload_motion.gd) 比较字典大小/键、数组长度和顺序，对数值拒绝 NaN/Inf。每一步同时核对全部 S、flags、事件 payload 与 arm 请求数，case 间深复制初始 S。240 Hz、关键边界、大步长、重复和回退时间覆盖了本阶段最易漏掉的一次冲量与窗口行为。

仍然排除的行为有明确原因：参考中的原 `h()` 实际执行 ammo/reserve/seated，但没有把这些结果列入 native 比较；native 本核也不转移弹药。arm 只比较原 magin 左手冲量的调用次数，没有证明其幅度、目标或 IK。零件锁定、弹匣/枪栓/套筒位置，以及被省略的手部目标仍须独立迁移。

## 生命周期的选择性重置

[weapon_motion_lifecycle.gd](../scripts/weapon_motion_lifecycle.gd) 共享调用者传入的 S，不另建两份枪状态。原常量 `UD/DS` 位于 L78879–78900，原 `Xn` 只重置 x/v，native 的 RECOIL/DYNAMIC 列表和 `Math.reset()` 与之相符。

- 内部 `_`（L79194–79235）：六路 recoil 更新 w/z 并清 x/v；sway/air/inertia 只更新参数，保留 x/v 历史。ADS、reload/rack、anticipation 等按原列表清理。不要顺手把所有弹簧都 reset。
- `T`（L79236–79274）：清 reload 和指定控制状态，重置 DS、spV、stance、gOff、stride 后调用 rifle 的 `_`。`stride=1.55` 对应原 `NS.walk`。t、breath、landSide、recPhase、lastVy、wallT 等未写字段继续保留，这是原实现的选择，不是漏清。
- `snap`（L79128–79163）：先计算当前 ADS/sprint，重置动态弹簧，再把 ADS/sprint/reload/rack 弹簧直接放在当前 target。先 `gait += gOff.x` 再清 gOff，顺序正确。`onGround !== false` 保留严格布尔语义，null 不会被误判成空中。

[生命周期参考生成器](../tools/weapon_motion_lifecycle_reference.cjs) 直接执行原 `_ / T / snap` 及原 helpers/constants；mock 隔离的 drop、arms、rig.reset/snapArms 不写共享 S，因此没有切掉应由本核迁移的 S 副作用。96 次操作使用同一份 S，显式污染所有弹簧 x/v 和关键历史，能够验证连续历史的保留。部分普通标量仍沿用默认值，因此数值轨迹不能单独证明每一条清零语句；本审查另行逐字段核对原文。

审查发现初版 action 与 crouching 的周期相关，导致所有 snap 都落在站立分支；主线已解除该相关性并重新采集、验证。当前 coverage 明确为 equip 24、reset 24、snap 48；snap 的 stance 1/0 为 16/32，ADS 1/0 为 23/25，sprint 1/0 为 6/42。生成器对上述任一零覆盖直接报错，最终仍为 15,552 项比较、误差 0。报告和 fixture 均保存 coverage。

这里的 `equip()` 特指原内部 `_`，不是公开 `E.equip`（L79108–79115）。公开接口还要调用 `I()` 取消换弹、清 switching/pending、置 `a.hol=0` 并 snap arms。当前内部核刻意保留的 reload/hol 不能直接当作公开 equip 的完整行为。

## 下一阶段生产接线要求

当前脚本内没有对这两个新模块的生产调用。后续与原 D 共用同一个 S 对象；`weapon.gd` 中已有的 cooldown、burst、reload 等字段不能长期成为另一套可独立演化的状态。

1. **换弹事件只保留一个执行入口。** 现有 `weapon.gd::_reload_event` 同时拥有 flags、magin 转弹药及信号派发。若先运行旧事件扫描，再让新核读同一 flags，新核会漏冲量；若用两份 flags 各自派发，则会重复转弹药、音效或事件。建议新核的事件调用委托唯一处理器，按原 `f` 顺序设 flag → magin 转弹药/seated → emit → 返回 true，随后在原 callsite 注入 S 冲量。当前 `events` 数组是诊断记录，不是生产事件总线。
2. **先执行本帧 reload 核，再判完成。** 原 O 的 L79643–79663 即使一次 dt 跨越多个阈值和 T，也先执行所有应触发的事件/权重，再清 reload 和四个 targets、调用 endReload、发 done。调试 reloadT 存在时不自动完成。不能先删除 reload 再补动画。
3. **保留两种 fresh 与接口身份。** `reload.fresh` 控制起始帧是否推进时间，`reload.f.fresh` 控制新弹匣阶段，二者不可合并。现有 `duration/events` 到本核 `T/f` 要显式适配；事件使用 reload.t，曲线使用 time，原正常调用二者相等。
4. **统一 null 合同。** 原 S 的无 reload 是 null；现有 weapon.gd 用空 Dictionary。把空字典直接放入 S 会让 `a.reload == null` 等状态判断失真。进入状态核前统一转换，snap、D、O 和取消路径共用同一合同。
5. **生命周期同时协调外部副作用。** 公共 equip 的 cancel/hol、reset 的 slots/当前枪/掉枪恢复、snap 的 E.ads 和 arms，以及可见性都在本次核外。不能只调用内部状态核就宣称完整 equip/reset/snap 已完成。完成或取消换弹也不要重建整份 S 来代替选择性清理。
6. **保持根的唯一写入者。** 接入 D 后必须停掉含旧 sway/reload 的采样根和旧 holster 增量。子节点及双臂继续采样只是过渡，需要既定的一次根差值补偿；本次没有提供新的 parts、IK 或画面等价证据。

本阶段可以作为后续 O 驱动与生产桥的已验证基础。下一验收应针对真实 reload 事件/弹药单次性、完成/取消/换枪顺序和共享状态身份，不应把本次纯状态误差结果扩大为整枪动态已完成。
