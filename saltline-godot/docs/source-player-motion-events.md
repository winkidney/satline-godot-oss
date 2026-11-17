# 玩家运动事件与武器桥

生产Player.update现在在原分支位置发motion_event，Main连接Weapon.on_player_motion_event，将step/jump/land分别写为共享S.stepEv=1、jumpEv=1、landEv=max(0,speed)。rescued不写武器标志。D后续已接管生产根并消费这些标志，见source-weapon-live-root.md。本文件的独立事件测试只证明所列接口范围。

## 原顺序和可见修正

来源bundle-1.js的player N，jump L69074–69082、land L69097–69109、rescue L69117–69126、stride L69129–69142，weapon listeners L79030–79039。

jump在赋初速度、清jump buffer/coyote、取消crouch之后，半重力和碰撞之前发。碰撞接收保存的previous_ground。原作jump把A.onGround改false但私有l仍是上一帧ground；之前native传了jump后的on_ground，会改变STEP/.08横向和floor门槛。本轮恢复原参数，并单独检查实际传入值。

landing仅在前帧未ground且air_time严格>.12时发，speed取max(0,-碰撞前竖速,累计fall_speed)。先施加landDip和>7.5的shake，再发land，再按>13产生伤害，最后stride_phase=.35。原落地shake和步相重置此前缺失，现已补齐。source reset不清私有surface L，native也保留ground_surface。

stride跨过整数时只发一次step，即使单帧跨过多个周期；休止时用JS Math.round等价的floor(phase+.5)。rescue恢复safe position/零速度/ground，设置shake=.6、转身、伤害，再发rescued。原M是shake，不能误写成stride_phase=.6。

## 表面与视觉效果边界

payload含pos，step含surface/sprint，land含surface/speed。当前默认surface来自碰撞结果，并支持明确String合同的可注入surface_resolver。原H中的puddle、level.groundSurfaceAt metal区域和异常fallback尚未整体迁移，所以生产表面类型不宣称完全一致。原step/land对应水花、灰尘等视觉消费者也未接线，后续继续；不包含音效。

## 验证

reference生成器直接提取原jump/land/rescue/stride和weapon listener字面段，使用原bundled Three、原j0。碰撞结果和surface resolver由用例指定。native测试实际执行Player.update、signal及生产Weapon listener，比较payload、emit时phase/shake/flags、伤害，以及传入碰撞的上帧ground、竖速和height。

最终47组、832次比较，最大误差1.335144e-6，门槛2e-6，未放宽。最大差来自原double竖速13.175到Vector3 float32 13.175000190734863，再乘伤害系数7。另以dt0和二进制可精确表示的force7.375/7.5/7.625/12.875/13/13.125验证shake与damage严格阈值，避免把有重力偏移的输入速度误当成真实impact阈值。

coverage明确断言jump3/land17/step8/rescued1/no-event18，以及6组大dt跨步仍只发一次；包含coyote jump、crouch阻挡和允许跳跃、air_time=.12严格边界、负半休止phase、resolver指定water和reset保留L。原完整player movement/collision/camera轨迹不在此组证据范围。

另用实际导出的SourcePhysics连续功能测试，得到jump1/land1/step5、landing speed6.64426374435425，均到达Weapon pending flags。这是原世界碰撞数据上的功能证据，不是与原HTML整段轨迹对照，也未调用生产D来消费标志。

原player五项和weapon十项回归通过。最终RTX4070SUPER Forward+780帧流程退出0，pause冻结、两retry、最终playing，日志无ERROR/泄漏；保存为player-motion-events-flow.json/.log。CPU clean日志亦保存。GPU流程不是jump/step像素证明或性能证据。

Astra只读审查见player-motion-events-review.md。原recoil和Q内部流后续已接入，见source-weapon-shot-integration.md。后续继续全局随机fork、S启动初态/推进、D根唯一写入、双臂同步/IK与parts/drop，以及原表面查询和脚步落地视觉效果。

复现：

```sh
rtk proxy node saltline-godot/tools/player_motion_events_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-player-motion-events.log --script tools/verify_player_motion_events.gd
```
