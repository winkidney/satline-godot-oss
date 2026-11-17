# 实时武器目标、检视和空击驱动

`weapon_motion_controls.gd` 已进入生产Weapon.update，负责原O的spWant/urgent、待机检视三窗口、finger和空击bump。Weapon同时同步ADS want/adsLin/adsE、sprintT/hol和控制时钟。D后续已默认接管枪根并消费motion_inspect，见source-weapon-live-root.md；手臂仍是采样加组差值过渡。

## 原顺序

来源是bundle-1.js的O，L79625附近的spWant/urgent和L79730–79772的idle/inspect/finger，dry分支在L79680–79694附近。spWant/urgent在pressed reload之前计算，故本帧刚按reload时不会擅自重算这两个目标。ADS在reload完成清理之后求目标，再推进逻辑adsLin与quintic adsE。

待机中断条件包含fire、ADS输入、reload、switching、speed>.2、原look绝对增量和>.002以及sprintT>.1。活动检视被中断时先推到至少2.9，再加本帧dt、计算三窗口；严格>3.5才结束。只有rifle定义启用自动inspect，pistol不自动触发。idleT必须严格>24，未改成>=。

finger使用原j0的target+(value-target)*exp表达顺序。空击先emit原事件，再给bump.v减.08，自动武器保持dry_done一次触发，半自动仍按原edge/fire_queue节流。

Weapon.update在player.alive=false时先清previous_fire并返回，不推进逻辑时钟或控制状态。此改动只处理原早退条件；原掉枪、flash和死亡零件分支尚未迁移。Main的game tick只consume一次原归一化look，将同一份输入交给player与weapon，不从相机角差反推，也不把ADS lookScale再次乘给武器。

## 对照

独立提取原targets/idle/inspect/finger块，640步核对全部S和窗口；另直接执行原完整O字面函数，与生产Weapon.update比较4900步的选定逻辑字段、窗口与dry事件。后者使用empty ammo/reserve0，Q/RNG/reload/switch未进入；parts/flash/drop/D为mock，drop假定已active。使用完整原文不表示验证了整个O。本轮只证明所列控制行为，不证明真实死亡掉枪。

生产对照显式把native初始time设为导出S.t，与参考同初态；后续生产初始化也按这个导出快照继续，但仍不证明原标题到整场景的全部时间轴已一致。motion_state也尚未统一cooldown/spreadS/prevFire等所有旧逻辑字段，后续D已推进其运动部分，但整体仍是部分S。

最终211164次比较，最大误差1.42109e-14，门槛1e-12，failures空。比较器拒绝NaN/Inf并精确比较String。初版String曾错误走float转换，修正后全部重验；脚手架错误与边界记录见weapon-motion-controls-initial-notes.json。

coverage由生成器断言：每枪ADS wanted188步、sprint wanted130步、dry14次、dead10步；rifle inspect210步、窗口非零203步，pistol均0。独立用例在idleT=24/dt0不触发，下一步超过24才触发。参考/报告为weapon-motion-controls-reference.json和weapon-motion-controls-verification.json。

既有weapon10项、换弹生产119266项及input16项回归通过。RTX4070SUPER Forward+780帧实机流程退出0，pause冻结、两retry、最终playing，日志无ERROR/泄漏，保存为weapon-motion-controls-flow.json/.log。CPU clean日志同目录保存。实机流程不是原运动像素或性能证据。

Astra审查见weapon-motion-controls-review.md。玩家step/jump/land pending事件桥后续已接入，见source-player-motion-events.md。原recoil和Q内部流后续已接入，见source-weapon-shot-integration.md。仍需全局随机fork对齐、明确启动初态、共享S完整推进，再进行D根唯一写入和双臂同步/IK、parts及死亡掉枪。

复现：

```sh
rtk proxy node saltline-godot/tools/weapon_motion_controls_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-motion-controls.log --script tools/verify_weapon_motion_controls.gd
```
