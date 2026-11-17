# 换弹状态核生产接入审查

本次只读核对 `weapon.gd`、换弹/生命周期核、实际 `Weapon.update` 验证器及原 bundle。当前接线没有发现阻止交付这一阶段的事件、弹药、完成清理或引用环缺陷。原换弹的状态计算已经进入生产 Weapon；武器根、零件和双臂仍由采样动画驱动，尚未完成实时 D/O 与 IK 接管。

本审查只新增本文，不修改运行代码或测试，也没有重跑 GPU。原纯状态核的公式和切片审查见 [weapon-reload-motion-review.md](weapon-reload-motion-review.md)。

## 已核对的调用链

[weapon.gd](../scripts/weapon.gd) 创建同一份 `motion_state`，交给生命周期核和换弹核。原来的独立 reload 事件扫描已删除，生产只有以下一条路径：

`Weapon.update → reload_motion.step → _reload_event → flags / magin 弹药 / phase_event → 返回 true → 原位置注入 S 冲量`。

这与原 bundle 的 `f/h`（L79061–79070）一致：事件只触发一次；magin 先扣 reserve、加 ammo、置 seated；emit 时仍能读到本事件冲量之前的速度；返回后才由两枪 reload 方法注入冲量。弹药按 context.weapon 归属，不依赖可能改变的 current。事件 flags 和连续权重共用同一 reload 上下文，没有另建第二套一次性标志。

`reload.fresh` 仍是首次 update 不加时间的标志；`reload.f.fresh` 是换新弹匣阶段的标志。`f/events` 指向同一 Dictionary，验证器通过写入/读取临时键检查了别名关系。审查中指出 T/duration 数值不是引用别名后，主线已删除 duration 副本；当前连续曲线和结束判定共用唯一的 reload.T。

更新阶段先执行 step，再判断完成。完成时清 `weapon.reload`、将 `motion_state.reload` 设为 null、清四个 targets，最后发 done；原 O 的 L79643–79663 也是先执行换弹，再清理和发完成事件。保留已注入的弹簧速度是正确的，不能在完成时把全部运动状态清零。

update 保留局部 `active_reload`，step 和完成判断均使用它，而非在事件回调后重新读取可能已被取消的外层 reload。这样回调中的切枪不会使当前方法访问空 Dictionary，当前方法仍沿原上下文执行。新增定向测试在 magout 回调中取消，确认无提前转弹、外层已取消，下一 tick 清 targets。

切枪取消时，`_start_switch` 立即清外层 reload 和 `motion_state.reload`。连续 targets 在随后一次 update 的无 reload 分支清理，符合原取消函数 `I` 与后续 O 的分工。取消发生在 magin 前不转弹，发生在 magin 后保留已完成的转弹；没有额外补发 magin。无 reload 的 S 表示统一为 null，未把空 Dictionary 留给运动核判断。

## 生命周期和所有权

生产 `_equip` 调用已验证的内部 equip 核，`reset` 调用选择性 reset 核；两个调用都修改原 Dictionary，未替换对象，因此 reload/lifecycle 持有的状态引用继续有效。reset 同时重置现有 Weapon 的枪槽、当前枪、切换/换弹状态并清诊断记录。t、breath 等历史仍按原状态核规则选择性保留。

这里仍需区分内部 `_` 与公开 `E.equip`，也不能把新核当作原生命周期的全部副作用。arms snap/blend、锁定零件、原掉枪恢复等不在本次迁移中；当前可见节点继续由 `weapon_animation.gd` 和既有 session/effects 路径维护。生命周期 `snap()` 仍没有生产调用，不能报告为已经接通。

引用关系现在为 `Weapon → reload_motion → WeakRef(Weapon)`，不再形成强引用环。事件调用先从 WeakRef 取得临时 owner；owner 已释放时返回 false，不退回本地处理以重复派发。S、reload 和 flags 字典中没有回指 Weapon 的引用。测试监听器也改为只捕获 WeakRef，避免测试自身把 Weapon 保活。当前 owner 和方法由构造器内部固定提供，未发现失效方法或跨线程生命周期问题。

初次运行虽然数值通过，退出时仍报告 42 个 ObjectDB 实例和 4 个资源未释放；该失败保留在 [初次 cleanup 记录](../evidence/weapon-reload-integration-initial-cleanup.txt)。最终验证新增 retained-kernel 用例：额外持有 kernel、释放 Weapon 后，断言 owner 的 WeakRef 已为空，再调用 kernel 检查委托事件不设置 flags、不记录事件、不施加本次 magout 冲量。[修复后完整日志](../evidence/weapon-reload-integration-clean.log) 已保存，包含最终 119,266 项比较报告且没有退出泄漏警告。该断言与日志共同支持已定位引用环的修复；它不等于所有生产生命周期均无泄漏，也不把孤立 kernel 的全部连续状态计算定义为 no-op。

## 参考与实测范围

[weapon_reload_motion_reference.cjs](../tools/weapon_reload_motion_reference.cjs) 继续直接提取原 reload 首尾和原 `f/h`。新增 trace 在原 emit 时读取 ammo/reserve 和 bump/kZ/kP/kR 的 v，expected 不是从 native handler 反推。`production_final` 从独立初态重放生产可到达的时间点，再执行 T 时刻的原方法和结束清理；没有复用已经越过 T 的诊断轨迹终态。

[verify_weapon_reload_integration.gd](../tools/verify_weapon_reload_integration.gd) 实际构造 `SaltlineWeapon` 并调用 `update()`，验证：

- 两枪 empty/tactical 的事件顺序、完整内部 payload、弹药/seated、四路速度及四个连续 targets。
- emit 当刻的弹药和速度，因此能检测转弹与冲量前后顺序错误。
- flags 别名、重复/回退时间、完成只发生一次、完成后四个 targets 为零。
- rifle 在 magin 前后切枪取消时的弹药守恒，以及 reset 后上下文和诊断清理。
- 首帧 dt=.5 仍保持 reload.t=0，下一帧 dt=.2 后 t=.2，且尚未设置弹匣阶段 f.fresh；回调取消和 retained-kernel 的定向生命周期用例。

[最终集成报告](../evidence/weapon-reload-integration-verification.json) 为 12 case、2,456 个有效步骤、119,266 项比较，最大绝对误差 `2.21350715534641e-15`，门槛 `1e-12`，零失败。主要轨迹显式写入 reload.t，再以 dt=0 调用真实 update；它验证调用链和指定时刻的状态。新增 first-frame 用例覆盖了 fresh 的真实 dt 规则，仍不能把整份主要轨迹称为 OS 输入或 D 弹簧推进的证明。

本轮另读到 [既有 Weapon 回归报告](../evidence/weapon-verification.json) 10 项通过，对应 `/tmp/saltline-reload-integration.log`。该测试用真实 1/60 步长覆盖射速、magin 前后转弹、切枪、手枪单发、无限 reserve 和换弹前段取消，可补充常规正 dt 路径的证据；它仍不是完整 O 的字面轨迹对照。

两个测试边界需保留：集成测试在 reload_now 后才连接监听器，因此 start 信号未由该 trace 验证；done 只计次数，清理状态在 update 返回后检查。当前代码顺序已经静态核对正确，但不能宣称该 trace 独立证明了 start/done 发出瞬间的全部状态。

## 后续接入仍需处理的边界

1. **生产信号尚未传完整原 payload。** `_reload_event` 当前忽略 extra，`phase_event` 仍只传 event/weapon/phase。empty 和战术 rifle 的 partial=true 保存在 `reload_motion.events` 诊断记录，未送到外部监听器。当前 scripts 中没有生产 phase_event 消费者，因此不阻断这次状态接入；后续原音效/事件桥必须明确传递它们，不能拿内部 payload 比较冒充外部事件合同已完成。
2. **motion_state 目前只接入部分驱动。** 旧 Weapon 的 time、cooldown、ADS 等字段仍独立更新；新 S 的 D 弹簧尚未每帧推进，换弹冲量暂不会产生实时根变换。不能把积累中的这份部分状态未经同步就热切为完整 D/O 状态。下一阶段应确定唯一 S、时钟/随机流与每帧更新顺序，并停掉旧的重复字段驱动。
3. **取消和 reset 的机械/手臂副作用仍用过渡路径。** 原 cancelReload(seated)、endReload、arms 请求的完整实现待后续 parts/IK 迁移；当前 arm_impulses 仍是计数。数值验收没有覆盖这些可见变换。
4. **采样根仍是当前唯一实际根输出。** Main 继续在 Weapon.update 后调用 weapon_animation.update，没有把新冲量再次叠到采样根上，本轮不存在由该接线引入的双重 sway/reload。后续 D 接管时再一次性切掉采样根与旧 holster 增量，保留子节点/双臂过渡补偿。

本阶段可交付为“原换弹事件、转弹顺序及状态核已接入实际 Weapon.update”。实时根运动、完整 O、原事件消费者和 parts/IK 仍是后续工作，GPU flow 也应以对应本轮的新报告单独记录，不能沿用旧截图或旧报告扩大结论。
