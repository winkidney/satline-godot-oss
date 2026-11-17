# 生产射击随机流与后坐力接入

Main射击回调现调用已验证的原两枪recoil方法，替代旧手写相机反馈。Root motion对象与Weapon.motion_state、reload/lifecycle/controls共用一份S，原枪身kZ/P/Y/R/X/U冲量也进入该状态。D后续已默认生产积分/写根，见source-weapon-live-root.md；手臂仍为采样加组差值过渡。

## 顺序与随机流

Weapon使用原su算法的SaltlineSourceRng，当前保留本地legacy seed4207。所有武器内随机调用经motion_randf进入同一计数流，替代原独立Godot combat/flash RNG。默认case每发为散布2次、弹壳初速度3次、rifle recoil7次或pistol6次、闪光6次，共18/17次。rifle kU另有随机倍率，pistol没有；源camera callbacks均存在时才是此数量。

Main按combat→tracer→shell→light→fire alert→recoil→bloom→flash执行关键阶段，仍在本帧animation/D之前读取旧root的muzzle/eject。camera direction不再额外重复归一化，combat origin使用player.eye。原fire事件的敌人警觉处理放在recoil前。部分impact/爆炸/FX接线并未在本阶段证明与原所有全局事件顺序逐项一致。

apply_recoil负责原相机add_recoil/add_shake和根冲量。原手写反馈分支已移除，CPU回调数组验证单次值/数量。bloom由按shot_count的guard在recoil后、flash前更新；_shoot返回后保留同guard的fallback，供没有recoil receiver的weapon-only调用者使用，不重复累加。本轮Astra发现的旧bloom在fired回调后才更新的顺序差异已修正。

burst结束仅在t-lastShot>.24且burst>0时，从同一流取一次recPhase=r()*6.28，再清burst；下一次空闲update不再消费。reset/equip不重建随机流，符合原闭包的持续语义。SourceRng算法和单流内部消费已对照，但原全局初始化后的fork seed、其它模块fork/FX随机消费仍未对齐，不能把4207说成原启动种子。

## 原Q对照

参考直接执行原完整Q、原su和字面两枪recoil，Q SHA256为 `ec64c6c1e07939e96d26c1cd725342a29a656f6eb4efdefefed796d570af00ac`。输入为明确seed4207、identity camera/root、无impact，并mock combat/FX接收者。

native验证实际_shoot/fired调用生产sample_spread、sample_shell_velocity、apply_recoil和WeaponEffects.fire，48发覆盖两枪、burst1至24、ADS0/.4/1、crouch交替；追加两次quiet检查首次一次recPhase消费、第二次零消费。比较root velocity、camera/shake数组、spread/shell向量、bloom、flash参数和累计随机调用。1212次比较零失败，max1.16974e-7；scalar门槛1e-11，float32向量门槛2e-6。reference.order未进入数值比较，外部副作用顺序只能按Main源码审查，不可扩大为全Q逐语句验收。

## 实机与回归

GPU探针包裹实际Main._weapon_fired信号，220帧、9 rifle+3 pistol，逐发断言18/17随机调用、单次flash/light、Main返回前bloom增一次，以及旧root在回调中未改。camera_recoil/root_impulse是诊断值；根仍待D积分。最终无失败和ERROR/泄漏，见weapon-shot-runtime.json/.log。

初次探针误留flow_preview，手动tick之外又走内建流程tick，并在原预览部署点重置会话，因未覆盖pistol而失败。修正探针后通过，initial JSON与原因留档，未把探针失败当作生产射击缺陷。

weapon10项、controls211164项、生产reload119266项回归通过。780帧GPU流程pause冻结、两retry、最终playing，无ERROR/泄漏，记录为weapon-shot-flow.json/.log。流程和shot探针不是完整原HTML图像/impact或性能证据；最后bloom顺序修正由最终shot探针和CPU覆盖。

## 剩余工作

Root D后续已推进共享S并接管枪根，见source-weapon-live-root.md；枪内parts和双臂仍以采样过渡；shot()空仓锁定及六机械角色后续已实时迁移，见source-weapon-parts.md；hand impulse/armTargets和magazine轨迹仍待完成。部分旧Weapon字段与S尚未统一，flashT/heat等也未全部成为单一源状态，不能热切已经积累的部分S当作完整历史。后续阶段已从明确导出快照接入D唯一根写入和双臂差值过渡，见source-weapon-live-root.md；仍继续完整IK/parts/drop、世界FX和原全局随机fork对齐。

Astra审查见weapon-shot-integration-review.md。

复现：

```sh
rtk proxy node saltline-godot/tools/weapon_shot_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-weapon-shot.log --script tools/verify_weapon_shot.gd
rtk proxy env DISPLAY=:0 saltline-godot/tools/run_native.sh --log-file /tmp/saltline-shot-runtime.log --script tools/verify_weapon_shot_runtime.gd -- --game
```
