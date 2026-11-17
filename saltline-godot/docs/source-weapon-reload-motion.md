# 换弹运动与选择性状态生命周期

新增 `scripts/weapon_reload_motion.gd` 和 `scripts/weapon_motion_lifecycle.gd`，与已验证的 `weapon_root_motion.gd` 共享同一份S的接口。换弹核现已由生产Weapon.update调用，内部equip/reset的状态修改亦已接线；D后续已接管，见source-weapon-live-root.md；snap及完整O/IK尚未接管，不代表可玩版本已经完成实时换弹根运动。生产接入证据见 `source-weapon-reload-integration.md`。

## 换弹运动

来源为原bundle-1.js的rifle reload L77041–77172、pistol reload L78698–78815。模块保留对bump/kZ/kP/kR速度的冲量、antYT/antRT窗口、reloadW/rackW连续权重，以及一次性事件flags。rifle regrip+.025的tug是单独flags，未误当成已存在的magin事件。

window在终点精确归零，不能换成永久保持1的普通smoothstep。根reload权重和rack权重依枪/empty状态分别计算；rifle退出窗口用reload.T，pistol使用magin/slide派生时刻。原事件检查使用reload.t，连续曲线使用方法time参数，两者在接口上保留独立含义。

事件记录包含原phase/empty/weapon，战术rifle boltback还含partial=true。当前arm_impulses只记录原magin左手冲量调用次数，不实际改手臂。弹药转移仍属于weapon逻辑，本模块不重复写slot。弹匣位置、套筒/枪栓、锁定状态及手部目标的实时求解尚未迁移。

参考生成器直接提取原reload写S的prefix/suffix、原f/h事件函数、ft/It时间表、B1/H1和Ot/dn数学函数。中间geometry/arms-target段明确跳过；它没有写入S，但仍需后续单独迁移。原f/h在reference中执行ammo/seated副作用，当前验证只比较运动S、flags、事件payload和arm调用数，不拿reference的ammo结果证明native弹药逻辑。

12组测试覆盖两枪×空仓/战术×240Hz/时间边界/大步长重复及回退时间。所有根曲线派生边界和事件阈值取±1e-9。当前2625步、453273次比较，最大误差2.21351e-15，门槛1e-12；NaN/Inf拒绝。见 `evidence/weapon-reload-motion-verification.json`。

## equip/reset/snap

原equip的下划线函数在L79194，reset T在L79236，snap在L79128。`weapon_motion_lifecycle.gd` 只迁移这些函数对S的改动，节点visible、arms snap/blend、掉枪恢复、slots等副作用仍须由完整驱动接入。

两枪共享S。equip只重设指定弹簧参数/状态，保留sway、air和inertia的连续历史；reset并不整份覆盖S，仍保留t、breath、landSide、recPhase、lastVy、wallT等未写字段。snap先合入gOff到gait，再清gOff；分别对ADS/sprint/reload/rack/stance写当前target。模块没有以统一清零替代这三条路径。

参考直接提取原三函数并执行，用mock隔离节点/arms/drop/slot副作用。96次操作在同一份S上交替equip/snap/reset，操作前显式污染所有spring x/v以及关键历史，包含debug ADS/sprint、switching、reload存在、crouch和严格false/null ground分支。15552次比较，误差0，门槛1e-12。coverage显式断言equip24/reset24/snap48，stance1/0为16/32、ADS1/0为23/25、sprint1/0为6/42，避免操作索引与输入周期相关而漏分支。见 `evidence/weapon-motion-lifecycle-verification.json`。首次提取未限定T函数作用域的失败记录在weapon-motion-lifecycle-initial-failure.json，已修正为从weapon equip之后查找reset。

## 生产接入约束

换弹一次性事件必须有唯一owner。不能先由旧weapon._reload_event把共享flags设好，再调用新核而漏掉冲量；也不能使用两份独立flags分别发事件和转移弹药。此接入现已实现：由原顺序中的motion event委托唯一weapon事件处理，在magin原位置完成转弹药和emit，再返回bool驱动对应冲量。换弹运动必须在done清空reload之前执行。reload.fresh的首次计时标志与reload.f.fresh的换新弹匣标志含义不同。

后续继续补O的wants/urgent、dry-fire/inspect和玩家事件桥，绑定原随机消费顺序，再进行根唯一写入和双臂同步。当前数值证据不覆盖完整生产换弹、生命周期副作用、手臂IK或死亡掉枪。

复现：

```sh
rtk proxy node saltline-godot/tools/weapon_reload_motion_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-reload-motion.log --script tools/verify_weapon_reload_motion.gd
rtk proxy node saltline-godot/tools/weapon_motion_lifecycle_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-motion-lifecycle.log --script tools/verify_weapon_motion_lifecycle.gd
```

Astra只读审查见 `weapon-reload-motion-review.md`。
