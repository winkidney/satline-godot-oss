# 玩家运动事件桥审查

本次只读核对 Player.update、Main 信号接线、Weapon listeners、原事件片段和验证器。审查发现的跳跃帧碰撞 grounded 参数差异已经修正；最终事件位置、payload、发出时的 phase/shake、伤害顺序和待消费标志均符合本阶段原作合同。结论限于玩家事件桥，不代表完整玩家运动、地表判定、粒子效果或武器 D 消费已完成。

本审查只修改文档。原生运行与报告由主线完成，本次读取并检查最终文件，没有重复运行 GPU。

## 原作顺序与生产接线

源代码是 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)。玩家事件位于 L69071–69138，武器 listeners 位于 L79028–79038。

| 事件 | 发出位置与本轮核对 |
| --- | --- |
| jump | jump buffer/coyote/站立检查通过后，先设置起跳速度、清两个 buffer、置空中并取消蹲伏，再发事件；发生在半步重力与碰撞之前，pos 是碰撞前位置。 |
| land | 必须前帧非 ground 且 air_time>.12。force=max(0,-impact,fall_speed)，先加落地 dip 和超过 7.5 的 shake，再发 speed/surface/pos；超过 13 的 damage 在 emit 之后，stride phase=.35 也在 emit 之后。 |
| rescued | 先回到 safe_pos、清速度、设 ground、把 shake 置 .6、yaw 加 PI，再 damage(12)，最后发空 payload。`.6` 属于 shake，不能写到 stride_phase。 |
| step | ground 且 speed>.5 时推进 stride；仅当 floor(new phase)>floor(old phase) 发一次，粗 dt 跨越多个周期也不补发多个事件。静止 ground 则向 JS Math.round 对应目标衰减。 |

[player.gd](../scripts/player.gd) 保留上述顺序。特别是 land 的事件观察者读到的是落地前的 stride phase、已经增加的落地 shake、尚未施加的坠落伤害；之后 phase=.35 再进入本帧 stride 更新。rescue 的观察者则已经能读到 damage(12) 对 shake 的影响。验证器在 emit 时采集这些值，未只比较整帧结束状态。

静止步相位使用 `floor(phase+.5)` 复现 JS 负半整数向正方向取整；例如 -.5 的目标为数值 0，不能用 Godot 普通 round 的负半整数方向。该迁移不宣称 signed-zero 位模式相等。

[Main](../scripts/main.gd) 在创建 Weapon 后连接 `player.motion_event → weapon.on_player_motion_event`，Player.update 仍先于本帧 Weapon.update。listener 写同一份 motion_state：stepEv=1、jumpEv=1、landEv 为非负落地速度。rescued 没有对应的武器标志，与原 listeners 一致。这些是待消费标志，不是事件计数器；多次 step/jump 合并为 1，新的 land 覆盖上一速度。原 D 尚未接入，因此本次没有证明其消费、清除和落地随机冲量。

生产连接只在初始化建立，reset 没有再次 connect；Weapon 不反向持有 Player。测试观察者用 WeakRef 取得 Player/Weapon，没有为 trace 增加相互强引用。Weapon.reset 继续将 stepEv/jumpEv 清 0、landEv 清 -1。

## 审查中修正的接口与边界覆盖

原 L69086 的 moveCapsule 最后一个参数是上帧 ground `l`；即使本帧刚跳跃、A.onGround 已置 false，l 尚未改变。初版 native 虽为落地判断保存了 previous_ground，碰撞调用仍传跳跃后的 on_ground。该参数会改变 source_physics 的 STEP/.08 墙体和地面门槛，不能当作无效参数。

最终已改为传 previous_ground，并让 CollisionStub 记录每次收到的 grounded，逐 case 断言等于输入 row.ground。随后还补记传入碰撞器的 velocity.y 和 height，对照原半步重力后的 ce 与当前 o，增加允许从 crouch 起跳的 case；参考 wrapper 的初始 o 也按当前 stance 选择。此修正恢复并检查原调用合同；它不是完整碰撞求解器的重新验收。

初版名为 speed=7.5/13 的 landing case 在半步重力后实际 force 为 7.675/13.175，不能用来证明精确阈值。最终新增 dt=0、可被 FP32 精确表示的 force 7.375/7.5/7.625 与 12.875/13/13.125，覆盖 shake 与 damage 的严格大于边界。air_time=.12 与 .120000001 也分别保留不触发/触发条件。没有通过放宽容差掩盖分支差异。

## 参考独立性、覆盖与精度

[player_motion_events_reference.cjs](../tools/player_motion_events_reference.cjs) 直接提取原 jump/land/rescue/stride 片段及原 weapon listeners，在原 Three Vector3 和原数学 helpers 上执行。碰撞结果、surface resolver、伤害记录等由显式输入/stub 提供；expected 不读取 native 实现。

源码 SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，拼接原片段 SHA256 为 `cb965ba30cbbcfbc90229a9225a922e406ecf45baae620d63bfb362e745bb017`。参考与当前原文身份一致。

[verify_player_motion_events.gd](../tools/verify_player_motion_events.gd) 调用实际 Player.update 和实际 Weapon listener，只替换碰撞查询结果。它核对事件数组的数量/顺序、完整 payload、事件时的 phase/shake/flags、damage、最终 phase、最终 pending flags、Weapon reset，以及玩家 surface metadata 的 reset 保留。String/bool 精确比较，数值拒绝 NaN/Inf。

[最终报告](../evidence/player-motion-events-verification.json) 为 47 case、832 项比较，最大绝对误差 `1.33514403799495e-6`，门槛 `2e-6`，零失败。coverage 为 jump 3、land 17、step 8、rescued 1、无事件 18；其中 6 个 coarse-stride case 确认跨多个周期仍只发一个 step。

当前受控行每行最多一个事件，尚未定向覆盖 land+step 同帧、已有 jump buffer 且无新按键、crouch stride。这不否定已覆盖路径，也不能用事件总数替代这些组合的验证。

最大误差有明确的 FP32 来源：gravity=21、dt=1/60 时，原 double 的下落速度 13 经半步重力得到 13.175；native Vector3 保存为 13.175000190734863。其差约 1.90734863e-7，再乘坠落伤害系数 7，恰为报告中的 `1.33514403799495e-6`。这解释的是已测样本的速度存储边界，不是跨位置/速度规模的统一误差保证。分支阈值另用上述 dt=0 精确样本校验。

审查初期指出 expected.impact 虽已生成却未比较，主线最终已将其接入上述 collision 输入断言。现在能检查这些样本的起跳/半步重力后速度与胶囊高度，不再仅凭 jump 事件存在推断冲量正确。CollisionStub 仍覆盖碰撞返回结果，因此完整重力积分、碰撞解算与跳跃轨迹尚未由这些逐段对照证明。

最终验证另有真实导出世界的功能路径：使用实际 source_physics，经实际 Player 信号送到 Weapon，观察到 1 次 jump、1 次 land、5 次 step；pending flags 均已收到，落地速度为 6.64426374435425。该部分证明真实碰撞路径能驱动事件桥，没有原完整世界轨迹对照，也没有调用 D 消费标志，报告 scope 已明确分开。

## 地表与尚未迁移的行为

原 `H()`（L68983–69005）先检查低处 puddle→water，再优先使用非 concrete 的碰撞 surface，最后查询 level.groundSurfaceAt 并回退。当前 `event_surface()` 默认返回最近的 collision.surface，可注入 surface_resolver；fixture 中注入 water 只证明接口和 payload 传递，不能证明原 puddle/level 地表图已迁移。

原 L 在初始化为 concrete，reset（L68879–68916）没有重置它。native 同样保留 ground_surface，测试明确把它设为 metal 后 reset 并检查仍为 metal。不要为“清理状态”将其无条件恢复 concrete。

step/land 的水花、尘土、脚步声音、原 H 的完整优先级与几何查询都不属于本次实现。落地伤害与 shake 的当前顺序通过受控样本核验，但不等于整份 damage/death/player-camera 行为重新验证。全世界碰撞精度、玩家运动轨迹及相机浮点差异仍需各自证据。

本阶段可以表述为“玩家原时机事件及武器待消费标志已接通，并完成受控原片段对照与真实世界功能检查”。实时武器 D、原地表 resolver 和 step/land FX 仍保留为后续工作。主线另完成的 GPU flow 属于运行回归，不扩大本文的原片段与事件桥对照范围。
