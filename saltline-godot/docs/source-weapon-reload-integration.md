# 生产换弹事件与运动驱动接入

`SaltlineWeapon` 现持有一份motion_state，以及共享它的lifecycle和reload运动核。reload的旧独立事件循环已移除；生产update在完成判定前调用reload_motion.step。当前只接入换弹驱动和内部equip/reset的状态修改，D后续已默认接管枪根，见source-weapon-live-root.md；完整O与IK/parts/drop仍未完成。

## 单一事件处理

reload_motion以WeakRef引用weapon事件owner。每个原事件位置先委托 `Weapon._reload_event(context,name,at,extra)`，由它检查并写入唯一flags，在magin转移弹药/设seated，再emit现有phase_event，返回true后运动核才施加对应冲量。未复用两份flags分别转弹药，也未预先消费flags导致运动核漏冲量。

reload.f与reload.events共享同一Dictionary，后者保留既有诊断接口。reload.fresh仍是首次计时标志，f.fresh是换新弹匣标志，两者独立。使用原T作为唯一总时长，已移除旧duration副本。step保留本次active_reload局部context，phase回调取消时不会继续访问已经清空的weapon.reload。

done在step之后清除活动context和四个连续目标，再发done。switch取消清context，下一次update的无reload分支清目标，保留与原O的阶段顺序。state-only equip/reset已接入原入口；公开equip、arms/node/drop副作用及snap的生产调用仍待完整驱动处理。

原phase_event签名仍只有event/weapon/phase。empty/partial完整payload保存在运动核诊断events中，尚无完整原事件payload的生产派发桥，不能扩大为全部源事件已迁移。当前无生产phase_event消费者。

## 对照与清理证据

`verify_weapon_reload_integration.gd` 直接执行生产Weapon.update，使用原字面reload state段和原f/h生成的expected。12组、2456个有效采样步、119266次比较，最大误差2.21351e-15，门槛1e-12。测试显式设置reload.t并用dt0采样，验证S的受影响字段、flags、完整诊断payload、slot、seated，以及事件回调当时的ammo/reserve和四路spring速度。这证明先弹药、再emit、再冲量的顺序，未冒充完整O时钟或真实输入证明。

同时验证done只发一次、magin前后切枪取消不重复授弹、取消后目标清零、reset清诊断、phase回调取消的上下文安全。首个update(.5)仍t0、第二次(.2)才t.2，且未把f.fresh误设。保留kernel并释放owner后，weakref归零，kernel不再接受过期事件/冲量。

首次数值对照通过但退出泄漏42个ObjectDB实例/4项资源，记录保存在weapon-reload-integration-initial.json及initial-cleanup.txt。生产owner改WeakRef，测试signal closure同样用weakref，修复后重新验证。最终clean日志已入库为 `evidence/weapon-reload-integration-clean.log`，无ERROR/泄漏。此结论限于该验证程序退出，不代表全部生命周期已证明无泄漏。

现有10项weapon回归、6240次枪内机械件对照及2625步独立reload核回归均通过。最终RTX4070SUPER Forward+实机780帧流程退出0，pause_frozen=true、两次重试、最终playing，日志无ERROR/泄漏。保存为weapon-reload-production-flow.json/.log。流程本身不逐帧比较根运动，也不是性能证据。

## 当前边界

motion_state是过渡的部分状态，D后续已推进运动弹簧并写入根，见source-weapon-live-root.md。后续已接入控制时钟/wants/inspect/finger，见source-weapon-motion-controls.md；完整旧逻辑字段、启动初态和随机消费仍未统一。不能直接把此时累积的部分S热切成完整实时根运动历史。后续需从明确初态启动完整驱动，再验证唯一root写入、射击读取旧root的顺序、双臂同步和最终IK。当前生产画面仍沿现有采样根动画，不能把本阶段描述为已经改变了完整武器可见动态。

原source、state核和选择性生命周期来源见 `source-weapon-reload-motion.md`；Astra接入审查见 `weapon-reload-integration-review.md`。

复现：

```sh
rtk proxy node saltline-godot/tools/weapon_reload_motion_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-reload-integration-reference.log --script tools/verify_weapon_reload_integration.gd
rtk proxy env DISPLAY=:0 saltline-godot/tools/run_native.sh --log-file /tmp/saltline-reload-production-flow.log -- --flow-preview
```
