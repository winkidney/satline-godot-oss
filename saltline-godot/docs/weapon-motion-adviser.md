# 原实时武器根运动迁移审查

建议把原 D 作为枪根节点姿态的唯一计算者，整体替换采样 root。枪内机械件与手臂可以暂时保留采样，但应分成独立写入路径。不能给现有采样根旋转再加一层 sway，也不能只跳过两个枪根而忽略相机直属的双臂。

本轮只读审查，没有修改生产代码。原依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 的 D，L79801–80128；文件 SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。驱动它的 O、Q、equip/reset、rig recoil/reload 也属于依赖。当前实现为 [weapon_animation.gd](../scripts/weapon_animation.gd)、[weapon.gd](../scripts/weapon.gd) 与 [Main._advance_weapon](../scripts/main.gd)。

## 现有采样能保留什么

[export_weapon_animation.cjs](../tools/export_weapon_animation.cjs) 遍历了整个相机子树。实际动画共 104 个节点，其中有两枪 root、两个 camera 直属 arm group、70 个 Bone、两个 SkinnedMesh，以及原 key light/target。枪根索引为 76、88，arm group 为 2、39。两臂各 35 个骨骼；检查的 clip 中 arm group 变换为 identity，姿态主要在 bone locals。

采集时使用 `noIdle=true`、look=0，普通 clip 的 speed/vel 为 0；sprint clip 设置 speed=6.4，但 vel 仍为 0。它包含原 root 姿态、射击后坐力、冲刺步态和离线求得的手臂姿势，却不是任意实际输入的运动参考。不能从这些 clip 推导完整实时 D。

当前 animation.update 对全部节点先采样，再按逻辑 `weapon.ads`、`sprint_blend` 插值，最后又对活动枪 root 追加 holster 的 y 位移和 rotate_x。D 接管后必须停止采样 root 的 transform 写入，并移除这两个 holster 增量。root visible 仍可由装备状态管理，flash 仍由 weapon_effects 在最后覆盖。

当前还存在可直接复现的机械件问题：ADS=1 会把 fire pose 全部混向静态 ADS clip。原 fixture frame0 中，rifle bolt 的 z=.039156476、pistol slide 的 z=.027777778 都被混成 0，pistol barrel 的动作也受影响。过渡时应让 gun children 按 fire/reload/action clip 采样，不对这些机械件做 ADS/sprint 插值；arms 的姿态混合单独处理。

旧 child clip 仍有 60 Hz 采样、第一帧为 update 后状态、射击连发重触发、空仓锁定、取消换弹等边界。保留它们是明确的过渡，不代表原 `parts()` 与 `armTargets()` 已实时迁移。

## D 的状态和计算顺序

`scene.json.modules.weapon.rigs` 已含两枪完整 motion、当前 pose 和 views；`debug.S` 包含 spring/history。当前快照 `a.t=.050000001`、breath 和 wallT 已推进，不是构造器的全零初始状态。参考轨迹必须声明从导出快照、原 reset 还是原 snap 开始，不能混用。

| 原 D 部分 | 必须保留的语义 |
| --- | --- |
| ADS / sprint / reload | `adsV` 与 `adsS` 是不同弹簧；`spV` 与逻辑 sprintT 不同；rwS/rkS 跟随 reloadW/rackW |
| 姿态 | HIP 与 ADS 位置差插值；SPRINT、SPRINT_ARC、RELOAD、RACK 已是对应偏移项；holster 使用 Hh 和三个含 abs 的非线性函数 |
| wall | 每次先减 wallT，超时设为 .08，按 eye/forward 向 rig.wall.far 查询；以 hit.dist 算目标再过 wall spring |
| idle | 先读取旧 exert，再更新 exert；breath、低频 sa、正弦和噪声各有不同幅度与 ADS 缩放 |
| gait | stride spring、spd 低通、步相/gOff、step/land 事件重同步、ground 与 crouch 幅度均有持久状态 |
| inertia | 用原 player.yaw 将水平世界速度转到局部；先更新 lpR/lpF，再算高通残差和四个弹簧 |
| sway | look 增量先注入速度，再积分；对 x 做硬限位并清 v，最后经过 tanh 软限幅 |
| air / crouch | jump/land 边沿、lastVy、landSide、一次随机采样、双 stance spring 差分和 fall target |
| recoil / anticipation | 六个 k 弹簧、bump、antY/antR 在末段积分，再参与完整姿态与 pivot 补偿 |

不能用现有 `weapon.ads` 代替 `a.adsV.x`。逻辑 adsE 控制射击等逻辑，视觉 adsV 是欠阻尼弹簧，可超出 [0,1]。原 D 只把某些权重用 clamp 后 cubic smoothstep 算成 q0；基姿态、arc 和 ADS-out 项仍使用原值。holster draw 的 overshoot 也不能统一 clamp 掉。

最终组合顺序是：

```text
q_base   = Quaternion(Euler(Kt, be, Le, YXZ))
q_detail = Quaternion(Euler(ve, we, Ae, YXZ))
pivot_delta = pivot - rotate(q_detail, pivot)
local_offset = pivot_delta + (kX.x, kU.x, kZ.x - ads_out)
root.position = (ws + Fe, cl + He, I0 + De) + rotate(q_base, local_offset)
root.quaternion = q_base * q_detail
```

这不是两个 Euler 向量直接相加，也不能颠倒 quaternion 乘法。pivot、recoil 平移与 ADS-out 在同一个内部偏移中先组合，再经过 q_base。输出是 camera-local 的绝对变换，两个引擎都按原右手坐标与 -Z 朝前处理，无需再加一次相机旋转。

## spring 与 CPU 噪声参考

`pn/en/Xn` 在 bundle L72782–72804，`AE/sa` 在 L72805–72819。建议直接提取原字面函数生成 CPU JS 轨迹，保留 source hash、参数、初始 x/v、每步 dt/target/impulse 和结果，避免用 native 实现反向生成 expected。

GDScript 的标量 float 可保存 double；spring/history 先用标量或普通 Array/Dictionary，避免提前放入默认 float32 的 Vector2/Vector3/PackedFloat32Array。最后提交 Transform3D/Quaternion 时再承认引擎 real_t 精度边界，分别验证标量状态与最终矩阵，不能把矩阵量化误差归为 spring 核误差。

`en` 的 z>=.999 分支按原临界阻尼公式执行，即使 z 大于 1 也不能擅自改成一般过阻尼解。原 P 仅在误差 <1e-5 且 |v|<1e-4 时 snap，并且只对原代码明确调用 P 的几个弹簧使用。不要对所有状态加统一“稳定归零”。

`sa` 是 CPU double 的梯度噪声，使用 floor、quintic 权重和 AE 的 `Math.sin`。它不是 GPU shader 的 fract/sin hash，不能套用之前 shader FMA guard。覆盖负坐标、整数边界和多个 seed；若不同 libm 有末位差异，先定位 AE 中间值并记录，不替换随机场。CPU 核与最后很小的视觉幅度应分别报告。

原调用是 `D(min(B,.1), ...)`，而 O 的 `a.t += B` 使用原 B。不要把 cap 同时加到所有时钟，也不要自行将大 dt 拆子步。恒定目标下 analytic spring 可有半群性质，但事件、snap、wall 轮询和目标变化使整个 D 不能视为帧率无关。

## 完整 root 需要的外部驱动

D 只消费 spring 状态，不负责产生所有冲量。生产切掉 fire/reload root clip 前，需要补齐下面的输入，否则会丢失现有后坐力和换弹倾斜。

- 原 rifle recoil 在 L77017–77039，pistol recoil 在 L78679–78696，注入 kZ/P/Y/R/X/U 的速度；同时产生 camera recoil/shake。迁移时必须替换或接管 Main 现有 camera recoil 分支，不能两份都调用 player.add_recoil。
- 原 rifle reload 在 L77043 起，pistol reload 在 L78698 起，产生 bump/k* 的一次性脉冲，以及 reloadW、rackW、antYT、antRT 连续曲线。当前 weapon.gd 的 phase_event 只覆盖部分时间点，不能代替这些曲线。rifle 的 regrip 后 tug 也是独立一次性事件。
- 原 dry fire 给 bump.v 减 .08，inspect 使用 idleT/inspect 三条窗口，sprint/ADS 有各自 want/urgent，均需按 O 的先后顺序输入。
- 现有 `weapon.ads`、`sprint_blend` 可以继续服务已验证状态逻辑，但 motion 应读取原 want/urgent 等明确字段，而非反推视觉目标。

原 weapon 的单个 RNG fork 同时服务 spread、shell、camera recoil、root recoil、flash、land 等。当前 native combat_rng 是独立 Godot RNG，且部分消费顺序不同。初期可给隔离 D 参考注入固定随机流，只证明 D 算法；生产接入时必须记录随机流暂未完全对齐，不能另建随意 seed 的 motion RNG 后宣称与原轨迹全同。特别是 landing 分支，即使冲量幅度最终为零，原表达式仍可能消费 r()，不可按结果省略。

## 输入与生命周期桥

当前鼠标事件直接调用 player.look，未保留 D 所需的 `input.look.dx/dy`。应累计原单位的输入增量，每个 simulation tick 读取一次，更新完该 tick 后清空。不要用 camera 的角度差代替，否则 camera recoil、shake、bob 和 clamp 会再次驱动武器 sway。原鼠标基础比例 hE=.0021，当前 player.look 使用 .002；灵敏度、invertY 和 ADS lookScale 也须明确各在输入哪一层应用，不能把 ADS lookScale 乘进原 D 的原始 look 增量。

原 player 在跳跃时发 jump；落地事件携带 `max(0, -collision前竖速, 累积fallSpeed)`，并有空中时长条件；step 在 stride_phase 跨整数时发。D 的标志只在对应位置消费一次。当前 player 已有这些状态和着地冲量计算点，可增加桥接而不重新推断相机运动。仍保留 D 自己的 wasGround/lastVy 兜底逻辑。

原 O 在 dead 或 debug.pause 时不推进 a.t，也不调用 D；debug.freeze 只跳过 D，其他 O 状态和 arms.update 仍可执行。当前 main 只把 dead/disabled 的 fire/reload/swap 清掉，weapon.update 仍会增加 time。因此新 motion 不能无条件把 weapon.time 当作已经等价的原时钟。先显式区分 alive root、暂停、freeze、死亡掉枪，死亡掉枪属于另一个 root 写入者，不能让 D 与掉落物理同时改同一节点。

reset、equip、snap 必须分别实现。原 T 保留 a.t、breath、landSide、recPhase、lastVy、wallT 等未写字段；equip 重新设各 rig 的 w/z 并清指定弹簧，但不会把 sway/air/inertia 全部清零。snap 又有自己的 spring target、gait/gOff 和 stance 规则。不要用一次整份字典重置替代三种操作。session reset 还需清除挂起的输入增量，避免暂停或菜单期间积累的 mouse delta 在恢复首帧突发。

原 S 是两枪共用的一份状态，不是每枪保留独立 sway/air/inertia 历史。每 tick 只对当前 rig 调用一次 D；切枪时更新同一份状态的参数与指定字段。不能遍历两枪各 step 一次，否则事件消费、随机流和时钟都会重复。

## 过渡层的最小接口与顺序

可用一个持有原状态的 motion 对象，加一个只负责过渡采样的 animation 对象。建议接口含义如下，不要求立即照此命名：

```text
motion.on_fire / on_reload_phase / on_player_event
motion.step(dt, weapon_logic, player_state, tick_input) -> camera_local_root
animation.sample_transition(weapon_logic) -> sampled_root + child/arm_local_poses
animation.apply_children_and_arms(sample, live_root)
```

每个模拟 tick 保留 `player.update → weapon.update及同步事件 → D → child/arms → effects`。原 Q 在本帧 D 前读取 muzzle/shell 的旧 root；当前 fired 同步回调也发生在 animation 更新前，这点与原作一致。不要为了“同帧更新”整体延后射击事件。应在同一个射击驱动里注入 root recoil spring，然后由本帧 D 积分。

采样器不再写两枪 root、key light 或 target。只保留明确的枪子节点、两臂组和骨骼。骨骼需继续双写导出节点代理与 Godot Skeleton3D，不能只让调试节点动而网格不动。

两臂是枪 root 的兄弟。临时保持手部与枪根关系，可以计算：

```text
delta = live_gun_root * sampled_gun_root.affine_inverse()
arm_group = delta * sampled_arm_group
```

sampled_gun_root 必须来自与该臂采样相同的 clip、时间和混合权重。每 tick 从原采样值重新计算，两个 arm group 各乘一次；不要累乘前帧 delta，也不要给每个 bone 再乘。当前 Skeleton3D 与手臂 Mesh 都在对应 group 下，可由 group 一起移动。

这是刚体补偿，会把肩部也一起移动；原 arms.update 则在 camera-local 肩位置与跟随枪根的手目标之间重新解算肩、肘、腕。该过渡可减少手枪脱离，不能证明原 IK、肘部 pole、关节约束或连发反馈已完成。既有骨骼 clip 的插值误差也不会被这一步消除。

## 分阶段验收

1. **纯数学核。** 原 JS 与 native 对照 pn/en/Xn、P、AE/sa，覆盖两枪 w/z、零 dt、.1 cap 边界、变化 target、正负 impulse、负噪声坐标。保存每步 x/v，不先看图。
2. **隔离完整 D。** 用原字面 D、rig motion/pose、显式 initial S、固定 player/input/raycast/RNG 序列生成轨迹。覆盖 idle、正反 look、急停、横移、walk/sprint/crouch、jump/land、wall、ADS overshoot、inspect、recoil/reload 外部驱动。逐步比较 spring/history、root position、quaternion 和变换矩阵。四元数用 abs(dot) 或矩阵比较处理 q 与 -q 等价。
3. **状态边界。** 两枪切换、holster 中改目标、draw 中再切、reload 取消、连发与空枪、reset/snap/pause/dead 各自验证。记录每步 RNG 消费和事件次数，不能只比较最后一帧。
4. **生产唯一写入。** 断言每 tick 活动 root 只有 D 一次 transform 提交，旧采样/holster 不再覆盖；输入只消费一次，_process 不重复积分；shot callback 仍在 D 前读取 muzzle。
5. **采样过渡。** ADS 连射时 bolt/slide 继续运动，flash 最终由 effects 控制；arm delta 不累积，切枪、换弹和暂停恢复不跳到旧 root；骨代理与实际蒙皮同时更新。量化手部相对枪的变化，并明确肩部刚体跟随是过渡限制。
6. **真实交互。** 用可复现的输入序列检查不同 dt、不同 ADS 和冲刺阶段的根轨迹及可见结果，再单独推进原 parts/armTargets/IK。已有 weapon 状态机或材质 GPU 验证不能替代这组运动证据。

阶段 1、2 可以先完整推进，不需要先重做实时 IK。默认生产 root 切换应等到它依赖的 recoil/reload/event 驱动与过渡层同时就绪；之后仍把子节点采样、手臂 IK、原 RNG 和死亡掉枪分别标成未完成范围。
