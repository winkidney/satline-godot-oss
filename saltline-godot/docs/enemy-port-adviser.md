# Saltline 原生敌人迁移顾问审查

审查日期：2026-11-15。范围为当前默认游戏的 Gull / Hound、共享管理器、战斗接口和死亡效果；不含音效，不使用 `legacy-v8`。本文只记录源码研究、现有工程边界和实施建议，没有修改实现，也没有把建议中的验收标为已通过。

建议先完成共享管理器和 Hound 的一条完整原生链路：感知 → 选位与导航 → 世界足点 → 动态骨骼 → 令牌与攻击 → 受击与死亡残骸。随后加入 Gull 和混合敌群。原作不是动画片段驱动的角色；Hound 的落脚、身体弹簧、枪台与头部姿态持续依赖实时位置、速度、地形和攻击状态。采样姿态适合作为比较基准，不能替代这些运行时计算。

原作依据：[bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)，SHA-256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。下文行号均指这个格式化文件。

## 1. 已有基础与当前缺口

| 项目 | 已核实的能力 | 本次迁移还需要什么 |
| --- | --- | --- |
| 导航 | [17,608 格、24 条路径、动态重建验证](../evidence/navigation-verification.json) 无差异，最大路点误差 0；[实现](../scripts/navigation.gd#L26)已接入 main | Hound 自己的寻路重规划、朝向速度约束、前探射线、轴向滑动、挤开和足点仍须实现；路径相等不证明移动相等 |
| 随机数 | [SourceRng](../scripts/source_rng.gd#L18) 与原作 `su` 的四种 seed、父流/fork/父流继续共 [1,152 个 32 位结果](../evidence/rng-verification.json) 精确相同 | 尚不能推出启动 fork 顺序、AI 分支消费顺序、`Math.random` 巡逻点和效果流已相同 |
| 地形与射线 | [raycast / line_of_sight / ground_height](../scripts/source_physics.gd#L71) 已有原生入口 | 按原作分别使用它们；不要用玩家 `move_capsule` 或 FX 向下射线替换 Hound 的移动/地面语义 |
| 敌人资产 | 导出含 10 Gull、8 Hound 池；Hound 每只 20 骨，Gull 每只 13 骨；隐藏节点与蒙皮均存在 | 依据池对象与 `rig.group.$node` 建控制器，初始化为原作未激活状态；当前 `modules.enemies.list` 的 5 个对象是运行快照，不能再实例化一次 |
| 蒙皮 | [source_scene](../scripts/source_scene.gd#L167) 建立 Skeleton3D、Skin 和 inverse bind；现有采样验证可证明已导姿态的绑定 | 动态姿态须同步源 Bone 代理与 Skeleton3D；动态足部、附件、枪口、弱点尚需独立验证 |
| 主循环 | [main](../scripts/main.gd#L227) 更新玩家、武器、可爆物及 FX | 审查时没有原生敌人状态机更新；需要在 weapon 后、explosives 前接入敌人管理器 |
| 伤害 | 玩家 health、可爆物和世界命中效果已有实现 | [player](../scripts/player.gd#L15) 尚无完整 `alive / damage / eye / forward` 合约；[武器命中](../scripts/main.gd#L261) 尚无敌人最近命中裁决；爆炸尚未贯通敌人 AoE |
| Gull 透明附属网格 | main / extraMesh 共享同一骨架，导入保留两者 | 原作 cone 使用 `uColor / uGain`；[当前通用 ShaderMaterial 兜底](../scripts/source_scene.gd#L141)不能代表光锥效果已完成 |

以上工程行号是审查快照，主代理仍在修改工程。实现状态应以各阶段实际证据更新。

## 2. Hound 函数地图与最小接口

| 原作入口 | 职责与直接依赖 | 建议原生边界 |
| --- | --- | --- |
| [`VS`，80522](../../artifact-rendering-study/source/extracted/bundle-1.js#L80522)；[`z5`，80381](../../artifact-rendering-study/source/extracted/bundle-1.js#L80381) | 程序几何、骨层级、蒙皮、材质槽 | 复用已导资产，不在 AI 中重建模型 |
| [`jS`，81960](../../artifact-rendering-study/source/extracted/bundle-1.js#L81960) | 创建池对象、脚数组、弹簧、骨引用、独立 lens 材质 | `HoundActor` 保存状态；`EnemyRig` 负责节点/骨映射 |
| [`damage / _activate / _deactivate`，82074–82170](../../artifact-rendering-study/source/extracted/bundle-1.js#L82074) | 受击冲量、初始化、归池、释放令牌 | 保留公共接口及明确的激活字段清单 |
| [`_raycast`，82171](../../artifact-rendering-study/source/extracted/bundle-1.js#L82171) | 头弱点球与身体两段近似胶囊 | 共享命中记录，只有更近命中才能替换 |
| [`E / M / _ / T`，82193–82245](../../artifact-rendering-study/source/extracted/bundle-1.js#L82193) | 理想世界足点、设目标、重规划、跟随路径 | `ideal_foot / set_goal / replan / follow_goal` |
| [`w`，82246](../../artifact-rendering-study/source/extracted/bundle-1.js#L82246) | 从掩体、导航随机点和环形候选选火力位置 | 必须读共享敌人 list、玩家、coverPoints、LOS、敌人 RNG |
| [`S`，82306](../../artifact-rendering-study/source/extracted/bundle-1.js#L82306) | 存活一帧：感知、双层状态、运动、足点、瞄准、骨姿态、灯和伤烟 | 保留源语句顺序，再逐段提取具名函数 |
| [`R`，82582](../../artifact-rendering-study/source/extracted/bundle-1.js#L82582) | hitscan、散布、曳光、枪口光、后坐 | `Combat.enemy_shot` 与世界空间 FX 入口 |
| [`z`，82626](../../artifact-rendering-study/source/extracted/bundle-1.js#L82626)；[`I`，82687](../../artifact-rendering-study/source/extracted/bundle-1.js#L82687) | 对角足组落脚；身体弹簧、头/枪台/天线、逐腿 IK | 原生程序姿态；不调用循环 walk clip |
| [`L / U`，82754–82862](../../artifact-rendering-study/source/extracted/bundle-1.js#L82754) | 死亡开始、坍塌/滑足/烟火、残骸下沉与回收 | 同一个 actor 保持 `active && !alive`，由管理器决定回收 |
| [`US / ll / KS / ZS`](../../artifact-rendering-study/source/extracted/bundle-1.js#L80445) | 腿 IK、半隐式弹簧、射线球、原作近似胶囊 | 可先独立逐值验证的小计算函数；`ll` 在 81957，`KS / ZS` 在 82864 / 82883 |

Hound 需要的环境合约应很小且清楚：`player(pos, eye, vel, alive, crouching, damage)`；`physics(raycast, line_of_sight, ground_height, nav)`；`level.coverPoints`；`manager(time, rng, list, playerSpeed, think, request/releaseToken, provoke, addWreck, retire)`；`combat.enemyShot`；世界空间 `fx`；事件总线；共享灯池。接口应对应原作数据语义，避免让 actor 反向读取 main 的展示状态。

## 3. 必须保留的执行与随机顺序

### 一帧的先后关系

原作先 `game.update`，由其判断是否运行模拟，再依次 `player → weapon → enemies → explosives`；未暂停时再更新 FX、ground、level、backdrop、materials，最后 HUD / renderer。[主循环 85994–86076](../../artifact-rendering-study/source/extracted/bundle-1.js#L85994)

敌人管理器对 `dt <= 0` 直接返回，对大于 `.05` 的 dt 截到 `.05`；先推进 manager 时间与玩家水平速度的指数平滑，再**倒序更新活动 list**，最后更新 bolt 和共享 Gull 扫描灯。[83334–83344](../../artifact-rendering-study/source/extracted/bundle-1.js#L83334)

Hound 存活帧内部顺序为：

1. 用旧 yaw 写 `fwd`，用上一轮已提交的 `headPos` 写 sensor，执行 `think`。
2. 处理 mode 变化；清目标/路径，进入 engage 就选 fire position；离开射击状态释放 token。
3. 减 cooldown / lungeCooldown；运行 mode 与 combat 子状态。此时可能发射子弹，读取上次提交的 gun world matrix。
4. 更新 yawRate / yaw、speed、push；试探候选位置，避障/滑动；平滑 root 地面高度。
5. 更新世界足点和 crouch；更新枪台、枪管、头部瞄准；求解身体/腿骨并提交矩阵；从真正 head 矩阵更新 `headPos`。
6. 更新 beacon、lens、flare 衰减、低血量烟火。

依据：[82306](../../artifact-rendering-study/source/extracted/bundle-1.js#L82306)、[82469](../../artifact-rendering-study/source/extracted/bundle-1.js#L82469)、[82521](../../artifact-rendering-study/source/extracted/bundle-1.js#L82521)、[82751](../../artifact-rendering-study/source/extracted/bundle-1.js#L82751)。把射击移到骨姿态提交后，或先更新所有 actor 再统一感知/选位，都会改变原作时序。射击、死亡、rally 的同步事件也可能在同一帧改变其他 actor。

### 随机数不是一个全局 seed 就够了

- 原作 [`su` 34783](../../artifact-rendering-study/source/extracted/bundle-1.js#L34783) 的 `fork()` 消费父流恰好一次，再用所得 32 位整数创建子流。主流 seed 在 [85808](../../artifact-rendering-study/source/extracted/bundle-1.js#L85808)，默认 4207。
- 文件内显式主流 fork 位点依次为 level `uw` [48043](../../artifact-rendering-study/source/extracted/bundle-1.js#L48043)、rain `Gw` [56615](../../artifact-rendering-study/source/extracted/bundle-1.js#L56615)、explosives `yE` [69409](../../artifact-rendering-study/source/extracted/bundle-1.js#L69409)、weapon `I5` [78950](../../artifact-rendering-study/source/extracted/bundle-1.js#L78950)。默认完整启动的先后关系见 [85860–85938](../../artifact-rendering-study/source/extracted/bundle-1.js#L85860)。资产已烘焙时仍需恢复所需流边界；不能因省去某个生成器而静默省去它对父流的消费。完整启动消费台账还应包含 game 的直接 `n.rng()` 调用 [85333–85440](../../artifact-rendering-study/source/extracted/bundle-1.js#L85333)。
- 敌人管理器**独立**创建 `su(params.eseed || 9001)`，不是从主流 fork。[82927](../../artifact-rendering-study/source/extracted/bundle-1.js#L82927) Gull 和 Hound 都直接引用同一个 `ctx.rng`，[81386](../../artifact-rendering-study/source/extracted/bundle-1.js#L81386)、[81962](../../artifact-rendering-study/source/extracted/bundle-1.js#L81962)。不能给每只敌人独立 seed/fork。
- 池构造顺序为全部 Gull，再全部 Hound；活动 list 按 spawn 追加、按倒序 update。选位/感知/死亡各分支、重试、短路判断和列表遍历顺序决定消费次序。[83126–83139](../../artifact-rendering-study/source/extracted/bundle-1.js#L83126)
- Hound `_activate` 在未显式提供 yaw 时先消耗 yaw，再依次 `senseT → cool → waitT → phase`；传入 yaw 会少消费一次。`scan / lensC / smokeT` 等字段并未全部在激活时重置，应按原作逐项实现。[82097](../../artifact-rendering-study/source/extracted/bundle-1.js#L82097)
- `nav.randomPoint` 使用的是 `Math.random()`，不属于敌人流；24 次候选各消耗角度与半径两个值，提前成功即停止。[40199](../../artifact-rendering-study/source/extracted/bundle-1.js#L40199) 现有 Godot 导航 RNG 序列与它未建立同流证据。逐帧参考录制应单独注入或记录 nav 随机流，不能只锁定 `eseed`。
- 伤烟、死亡烟的位置/尺寸、火花概率也消费敌人流。[82561](../../artifact-rendering-study/source/extracted/bundle-1.js#L82561)、[82833](../../artifact-rendering-study/source/extracted/bundle-1.js#L82833) 即使这些是视觉参数，也不能从 actor 中删除其随机消费，或移到每帧次数不同的粒子更新器。省去音频不等于省去整个带音频条件的死亡分支。
- `clear()` 清活动对象/弹丸/token 数，却不重置时间、递增 id、RNG、`tokenT / lastType / wantT`。[83314](../../artifact-rendering-study/source/extracted/bundle-1.js#L83314) 普通重试与重新加载整个进程不是同一种随机重置。

现有 1,152 项 RNG 验证证明生成器正确；下一份证据应记录每次消费的 `stream / index / caller / uint32`，以及 spawn、update 与同步事件顺序。第一处分歧比最后位置误差更有诊断价值。

## 4. Hound 两层状态与移动规则

### 感知模式

共享 `think(actor, dt, threshold)` 对 Hound 使用 `.55`，Gull 使用 `.4`。每 `.11 + rng*.08` 秒重新计算 LOS；范围 45，水平视锥 200°，已 engage 或距离小于 3.5 时跳过朝向门槛。LOS 存在时持续累积 seeT / exposure，并复制玩家 pos 为 lastKnown；不可见时 seeT 每秒衰减 `.6`，exposure 按 tuning 衰减。[83021–83069](../../artifact-rendering-study/source/extracted/bundle-1.js#L83021)

| mode | Hound 行为与退出条件 |
| --- | --- |
| patrol | 按 patrolLine 或 `randomPoint(home, patrolRadius)` 设目标，速度 1.5；到达后等 `1.5+rng*3` 秒。持续可见超过 `.55` 秒进入 engage |
| investigate / search | 朝 lastKnown 移动；距离小于 8 用 stalkSpeed，否则 runSpeed；距离不大于 2.2 时停步扫描。可见超过 `.55*.45` 进入 engage；modeT 耗尽回 patrol，只把 home 的 x/z 改为当前值 |
| engage | 连续失去 LOS 超过 4 秒，或玩家死亡，进入 search，搜索时间 `8+rng*3` 并释放 token；Hound 自己在 mode 变化时处理目标和射击状态 |

受击 `provoke` 可把非 engage 对象置为 investigate，`seeT=1 / senseT=0`，再 rally 周围 20；发现玩家 rally 半径 18。`passive` 跳过感知/报警，不代表冻结 actor 运动。[83070–83093](../../artifact-rendering-study/source/extracted/bundle-1.js#L83070)

### engage 子状态

原作精确分支见 [82350–82467](../../artifact-rendering-study/source/extracted/bundle-1.js#L82350)。以下时间是基础逻辑，伤害、burst 数、冷却等应读当前 tuning。

| es | 行为 / 转移 |
| --- | --- |
| move | 以 runSpeed 跟随火力位置；到达即 aim。超过 1.4 秒且有 LOS、距离在 `[rangeMin-1, rangeMax+2]` 内时，按 `rng < dt*.7` 机会提前 aim；超过 7 秒强制 aim。玩家相对选位时移动距离平方超过 49 则重选 |
| aim / cool | 朝玩家转向；有 LOS、太近（`rangeMin-3`）且等待超过 `.8` 秒则重选；否则 cool≤0、玩家活着、相对枪台 yaw 误差<`.14`，并成功拿 token，才进入 tele。无 LOS 且 noSeeT>1.1 或 esT>3 时重选 |
| tele | 倒计时 telegraph，flare 以 5/s 升到 1，crouch 目标 `.05`；到零进入 burst，并把 shots 设为当前 burst。此分支没有另加一次 LOS 取消检查 |
| burst | 每次到期最多发一发，重新设 `esT=burstGap`，不是 while 追赶。结束释放 token，抽 cooldown，并抽决定 1/2 轮后换位的值；否则进入 cool |
| wind | move / aim / cool 中，距离<3、lungeCd≤0、玩家活着时抢占进入；释放已有 token，发 melee telegraph，蓄力 `.28` 秒，crouch `.16`，俯仰弹簧蓄力 |
| lunge | 持续 `.36` 秒，速度 9.5；水平距离<1.35 时造成 lungeDamage、发 melee 事件并结束；随后 recover `.55` 秒，lungeCd=3.5，速度乘 `.3` |
| recover | 到期重新选火力位置 |

近战不请求攻击 token；不能用统一攻击限额阻止扑击。原作近战接触判定也没有另加 LOS 查询；移植若要改这个规则，必须另记行为变更。

### 选位和导航跟随

`w()` 首先遍历全部 `level.coverPoints`（偏置 -2），然后 7 个玩家周围 nav 随机点（0），再 5 个沿当前相对方位散开的环形点（1）。候选必须 walkable、玩家水平距离在 8–18；评分为移动距离×`.9` + 偏置 + `rng*3`。其他 engage Hound 的目标方向过近（dot>.86）可加到 14 分，间距<3 加 16；无 LOS 再加 22。无可用候选退回当前点。其他 Hound 若处于 move 就读其 firePos，否则读其 pos。[82246–82305](../../artifact-rendering-study/source/extracted/bundle-1.js#L82246)

设目标相差平方距离<`.25` 时不重置规划，除非 force；每 `.6+rng*.15` 重规划。路径首点距离平方<`.36` 时跳过；路点水平距离<`.55` 时前进；最终目标水平距离<`.45` 时到达。朝向误差>1.1 rad 时 maxSpeed=0，否则速度上限为 `min(requestSpeed*(1-angle*.5), .4+distance*2.6)`。[82200–82245](../../artifact-rendering-study/source/extracted/bundle-1.js#L82200)

Hound 不使用玩家胶囊移动：

- yaw 目标差经 `O5` 环绕，目标角速度 `clamp(diff*6, ±turnRate)`，扑击乘 2；yawRate 用指数速率 10 平滑。`O5` 在 ±π 边界保留原作符号，不能随意换成边界约定不同的 wrap。
- 原作 speed 的 clamp 会在减速时立刻裁到 maxSpeed，不能凭“更平滑”改成 `move_toward`。保存 prevSpeed 的位置决定 body acceleration impulse。
- 相邻 Hound 按 **active** 排斥，因此死亡但未回收的残骸也参与。玩家在非扑击且距离<1.25 时参与；push 按 `exp(-5dt)` 衰减。
- 速度>.3 时，每 `.12` 秒从 rootY+.55 向前射线探测 `.75+speed*.12`。候选 nav 不可走、feeler 阻挡，或扑击开始一小段之后被阻挡时，按原作分支采用 push-only / x 轴滑动 / z 轴滑动 / 停留。受阻速度乘 `.6`；累计 stuckT>.5 时重规划或换位。
- rootY 向 `groundHeight(candidateX,candidateZ,oldY+.6)` 以速率 12 平滑；脚落点单独查 groundHeight。

依据：[82469–82533](../../artifact-rendering-study/source/extracted/bundle-1.js#L82469)。导航图仅证明路径语义，不能覆盖这套连续运动。

当前导航以 boxes 数量变化触发重建，[navigation.gd:40](../scripts/navigation.gd#L40)。原作 addBox/removeBox 明确置 dirty，[39930–39959](../../artifact-rendering-study/source/extracted/bundle-1.js#L39930)。同一帧等量移除/添加会让“数量未变”失效；这是需要额外覆盖的动态场景边界。原地改边界若是新增原生功能，也要显式失效，不能假设已有验证包含它。

## 5. 世界足点、骨根坐标与动态姿态

### 唯一的坐标约定

源矩阵在 [source_scene.gd:57](../scripts/source_scene.gd#L57) 按 Three 列主序直接转 Basis / origin，没有翻轴。敌人 forward 是 **+Z**，`(sin(yaw),0,cos(yaw))`；玩家默认 forward 是 -Z。不要把敌人通用 `look_at` 默认朝向直接套上去。

Hound group 保存世界位移和 yaw；其 `root` 骨保留模型局部根。Skeleton3D 位于同一 group 下。body 骨的 `(lateral, stand + springY - crouch + breathing, 0)` 是局部坐标，不能再加 actor 世界位置。inverse bind 是资产固定数据，不能每帧改成当前 pose 的逆矩阵。

源 Bone 目前是普通 Node3D，另有驱动皮肤的 Skeleton3D：[source_scene.gd:43–50](../scripts/source_scene.gd#L43)、[167–191](../scripts/source_scene.gd#L167)。应建立 `source bone ID → 代理节点 + Skeleton3D index`，每次 pose 提交写两者；现有 [weapon_animation.gd:12–16](../scripts/weapon_animation.gd#L12)、[44–48](../scripts/weapon_animation.gd#L44)已有对应方式。只写代理则皮肤不动；只写 Skeleton3D 则 body 下的非 Bone 编号标签不跟随。Gull main 和 extraMesh 共用骨列表，只驱动一次。

Three 骨使用默认 XYZ Euler；Gull group 明确为 YXZ [81400](../../artifact-rendering-study/source/extracted/bundle-1.js#L81400)。原生姿态宜明确构造 XYZ Basis；不要依赖 Godot Node3D 默认旋转顺序。head 同时绕 x/y、body 绕 x/z、antenna 绕 x/z 的组合姿态最容易暴露这个错误。

### 四足不是正弦循环

腿参数在 [`Ky`，80502–80521](../../artifact-rendering-study/source/extracted/bundle-1.js#L80502)：stand=.72，L1=.4，L2=.42，外展偏移 l0=.075，hipX=.165、hipY=-.01、hipZ=.4，footX=.275，footZ=`[.37,.37,-.42,-.42]`，footR=.046。顺序 `FL,FR,RL,RR`，side=`[+1,-1,+1,-1]`；不要因为惯常“左侧”理解而把符号交换。

每只脚 `p/from/to/slide` 都是**世界坐标**。理想足点 `E` 为：

```text
x = actor.x + side*footX*cos(yaw) + footZ*sin(yaw)
z = actor.z - side*footX*sin(yaw) + footZ*cos(yaw)
y = 0
```

`_activate` 就用这个 y=0 初始化四脚，之后立即 `I(.016)`；它没有先把四脚放到 root 地面高度。若高台首帧显得不自然，先保留并记录源行为，不能把主动修正混进忠实迁移。[82145–82150](../../artifact-rendering-study/source/extracted/bundle-1.js#L82145)

对角足组为 `[FL,RR]`、`[FR,RL]`。未摆腿时，用速度和 yawRate 预测理想落点，按当前脚的最大水平误差选组；上一组之外的组误差乘 1.25。移动阈值 `.09`；静止超过 `.25` 秒后允许 `.035` 的调整。摆腿时长 `clamp(.27-(speed+abs(yawRate)*.5)*.026,.14,.27)`；预测目标使用 1.5 倍时长并查地面；水平/垂直基线用 smoothstep 插值，再加 `sin(πphase)*lift`。支撑脚不随 group 平移。[82626–82686](../../artifact-rendering-study/source/extracted/bundle-1.js#L82626)

落地只为该组的第一只脚发一次 `enemy:step`，同时给身体 Y 弹簧负冲量。原地转身也会触发踏步；没有 swing 时也有站立调整。源代码在“开始 swing”的那帧不推进 swing，相同 dt 下这一个分支差别会累计到踏步时间。

### 身体弹簧、世界到局部反解

[`I(dt)` 82687–82753](../../artifact-rendering-study/source/extracted/bundle-1.js#L82687) 从四脚世界高度计算 body 的支撑高度、前后坡度、左右坡度，再叠加加速俯仰与转弯侧倾。半隐式弹簧必须按 `v += ((target-x)*k-v*d)*dt; x += v*dt`，不能换成 lerp：Y `(160,17)`，pitch/roll `(130,15)`，lateral `(110,13)`，antenna `(60,5)`。

每只脚按下列顺序反解，保留原作 `footR*.6` 补偿：

1. 从世界脚点减 actor 世界位移，y 加 footR*.6。
2. 逆 yaw 转到模型根坐标；再减 body lateral / body height。
3. 逆 body pitch，再逆 body roll。
4. 减该腿 hipX / hipY / hipZ。
5. 调用 `US`，使用 `L2effective=L2-footR*.6`；写 abd 的 Z、thigh 的 X、shin 的 X。

`US` 的外展角先减 `atan2(-sqrt(max(x²+y²-l0²,1e-6)),side*l0)`；腿长限制为 `[abs(L1-L2effective)+.03, (L1+L2effective)*.995]`；髋角为 `acos(cosineLaw)-atan2(z,c)`，膝角为 `-(π-acos(cosineLaw))`。[80445–80462](../../artifact-rendering-study/source/extracted/bundle-1.js#L80445) 通用 SkeletonIK 或简单两骨求解不能保证这些外展、补偿与夹角约定一致。

随后原作强制更新 group 世界矩阵，再从实际 head 骨取 `headPos`。弱点、下一帧 sensor、枪口与伤害都依赖这一提交。不能用 `root + 固定头部偏移` 代替受击/死亡中真实头部位置。

独立 lens 材质属于每个 actor，shell/metal/glow 可共享。beacon 与 Gull rotor/strobe 的开关用 scale `1 / 1e-4`，应保留局部缩放；不能写入一个共享材质或所有同型敌人会同时闪烁。[82074](../../artifact-rendering-study/source/extracted/bundle-1.js#L82074)、[82549–82567](../../artifact-rendering-study/source/extracted/bundle-1.js#L82549)

## 6. 共享管理器决定敌群节奏

管理器是 Hound 第一阶段的必需依赖，即使暂时只放一只 Hound，也应实现真正的接口和状态，而非始终返回 true 的 token stub。[`W5`，82926](../../artifact-rendering-study/source/extracted/bundle-1.js#L82926)

| 规则 | 原作行为 |
| --- | --- |
| token 容量 | 活着的敌人数>5 使用 maxTokensCrowd，否则 maxTokens；已持有 token 直接成功；满额或距离上次授予小于 tokenGap 则拒绝 |
| 跨类型公平 | 若上次授予同一类型，另一类型 `.5` 秒内申请过，且距上次授予<`tokenGap*2.2`，也拒绝；被拒绝才更新该类型 wantT |
| 释放 | 仅 hasToken 为 true 时减少并清标志；射完、离开 engage/射击、死亡、归池都要经过同一入口 |
| 活动与死亡 | list 包含 active 的活体与残骸；aliveCount/raycast 只看 alive，Hound 排斥却看 active |
| 残骸上限 | 死亡立刻加入队列；超过 maxWrecks=5，把最旧残骸 sink 设 `.001`；其仍在 list，直到下沉>3.2 秒 retire |
| 池耗尽 | Gull 10 / Hound 8；找第一个 inactive。Hound 满池时若有 wreck，立刻 retire 最旧并复用；Gull 满池返回 null |
| 噪声 | weapon:fire 报警最多每 `.3` 秒一次，半径45；explosion 事件半径30；可爆物另外有其显式报警，不能漏掉或误用成仅视觉事件 |
| 重置 | title 触发 clear；清对象/token/bolt/灯强度，但不重置所有 manager 历史 |

依据：[82998–83020](../../artifact-rendering-study/source/extracted/bundle-1.js#L82998)、[83109–83124](../../artifact-rendering-study/source/extracted/bundle-1.js#L83109)、[83264–83373](../../artifact-rendering-study/source/extracted/bundle-1.js#L83264)。同一帧 list 倒序意味着后 spawn 的敌人先请求 token，不能排序后再更新。

基础 tuning 的 token 是 2/3、gap1.25；默认当前快照为 Hard：3/4、gap.85，Hound hp170、burst5、shotDamage8、runSpeed5、lungeDamage22；Gull hp55、boltDamage10。Standard、Hard、Brutal 定义在 [84672–84754](../../artifact-rendering-study/source/extracted/bundle-1.js#L84672)。`Bi.hound` 与 `c0=tb` 指向同一 tuning 对象；不能让 actor 在构造时拷贝后永远不接收难度/holdout 更新。快照中的 tuning 不是所有难度的默认值。

## 7. 战斗、死亡与效果对接

### 命中必须由同一战斗层裁决

玩家枪击先求世界 hit，再以其距离为上限查敌人；只对最近敌人应用 weak×2.2、damage、impact、player:hitEnemy，不再伤到其后的可爆物或墙。[`combat.playerShot`，69259–69304](../../artifact-rendering-study/source/extracted/bundle-1.js#L69259) `Hound.damage` 自己不乘 2.2；它负责 hit 事件、方向投影得到的 lateral/roll/pitch/Y 冲量、provoke、死亡判定。[82074–82096](../../artifact-rendering-study/source/extracted/bundle-1.js#L82074)

Hound 弱点是 headPos 半径 `.155` 球；身体为沿 yaw 的两段 `ZS`，上下半径 `.27/.25`。`ZS` 是“射线与线段最近参数得到一个球心，再调用球相交”的近似，并非精确胶囊。manager broadphase 使用的是**垂直距离平方>1.7**，不是半径1.7再平方。[82171](../../artifact-rendering-study/source/extracted/bundle-1.js#L82171)、[82864–82895](../../artifact-rendering-study/source/extracted/bundle-1.js#L82864)、[83285](../../artifact-rendering-study/source/extracted/bundle-1.js#L83285)

Hound 的 `R` 从旧 gun world position 出发，指向玩家 posY+1；枪口沿未加散布方向外移 `.43`，然后独立向 xyz 加立方分布噪声并 normalize。散布为 `lerp(far,near,exposure)*(1+smoothedPlayerSpeed*.3)`。这不是围绕视觉枪管轴的圆锥分布。[82582–82625](../../artifact-rendering-study/source/extracted/bundle-1.js#L82582)

`enemyShot` 对玩家使用原作投影距离与水平半径 `.38` / 垂直偏差 `.95` 的判定，先由世界射线截断；它不同于 Gull bolt 的 crouch 胶囊，也不是 Godot 玩家 CharacterBody 的碰撞体。[69305–69337](../../artifact-rendering-study/source/extracted/bundle-1.js#L69305)

玩家应先具备原作统一 `damage`：忽略死亡/无敌/非正伤害、health 下限0、重置回血计时、hurt/shake、player:hit、首次 player:dead。[68911–68929](../../artifact-rendering-study/source/extracted/bundle-1.js#L68911) 原作 `eye` 包含眼高平滑、步行 bob 与落地 dip，camera.position 复制 eye；逻辑 forward 包含后坐但不含 camera shake/死亡倾斜。[69172–69230](../../artifact-rendering-study/source/extracted/bundle-1.js#L69172) 应显式维护这些接口，不能凭“逻辑眼睛应无抖动”的假设改位置。

爆炸须保留视觉与伤害分离：`combat.explode` 按敌人 root 距离衰减、检查到 enemyY+.5 的 LOS；玩家按 posY+1 距离与 LOS，伤害乘 `.5`；owner 字符串不作为敌我免伤开关。[69338–69362](../../artifact-rendering-study/source/extracted/bundle-1.js#L69338) 原生 [explosives.gd:69–84](../scripts/explosives.gd#L69) 和 [explosion_effects.gd:65](../scripts/explosion_effects.gd#L65) 要避免 visual exploded、连锁与 combat 各扣一次伤害。

### Hound 死亡仍然是一段原生模拟

死亡开始立即 `alive=false`、释放 token、关闭 beacon，抽倒地方向与逐脚 slide，保留部分前进速度，发 sparks/debris，发 **一次** enemy:killed，加入 wreck。计分/波次应从这一刻变化，不等烟散或回收。[82754–82784](../../artifact-rendering-study/source/extracted/bundle-1.js#L82754)

前 2.2 秒：身体 Y 受重力跌到 `0.215-stand`，碰撞反弹系数 `.22`，较大撞击发 crash step 与 dust；身体角度弹簧、脚的世界 slide、root 漂移、头与枪下垂继续动态求解。前 1.2 秒 lens 闪烁；其后保留很暗的尾值，不是整材质瞬间归零。烟到 6.5 秒，火花到4秒，橙色热烟到3.5秒。[82785–82860](../../artifact-rendering-study/source/extracted/bundle-1.js#L82785)

6.5 秒后变成持久 wreck，不自动退场。只有队列超限会下沉，或 Hound 池耗尽时直接复用。下沉分支只移动 groupY，不重新求腿姿态。原作没有 Hound 死亡 AoE，也没有用刚体 ragdoll；不要在迁移时额外加入。[83109](../../artifact-rendering-study/source/extracted/bundle-1.js#L83109)、[83274](../../artifact-rendering-study/source/extracted/bundle-1.js#L83274)

### 本阶段效果覆盖清单（不含音频）

| 效果 | 必须保留的触发/空间/持续性 | 原作 |
| --- | --- | --- |
| Hound 枪口 | 世界空间 flash scale.9；light 色16756832、22/7/.05；tracer 色16760944、speed260、width.035；身体后坐 | [82582](../../artifact-rendering-study/source/extracted/bundle-1.js#L82582) |
| Hound 警告 | telegraph 事件含 time/pos/melee，flare 影响独立 lens，crouch 与弹簧预备姿态 | [82354](../../artifact-rendering-study/source/extracted/bundle-1.js#L82354) |
| Hound 常态 | beacon 双闪，patrol 频率.8，其余2.2；lens patrol `[8,4,.7]`、engage `[14,1,.35]`，HDR 值不裁到1 | [81944](../../artifact-rendering-study/source/extracted/bundle-1.js#L81944)、[82549](../../artifact-rendering-study/source/extracted/bundle-1.js#L82549) |
| Hound 受伤 | 低于40%当前最大hp，每.2秒伤烟，20%火花；方向相关身体弹簧冲击 | [82074](../../artifact-rendering-study/source/extracted/bundle-1.js#L82074)、[82561](../../artifact-rendering-study/source/extracted/bundle-1.js#L82561) |
| Hound 脚步/死亡 | 单组落地事件、身体冲量、坍塌尘、四脚外滑、烟/火花/热烟、编号随 body、残骸与下沉 | [82626](../../artifact-rendering-study/source/extracted/bundle-1.js#L82626)、[82754](../../artifact-rendering-study/source/extracted/bundle-1.js#L82754) |
| 敌人命中 | surface=`enemy`、part/dir/killed；对应火花、碎片与烟，不能套成默认混凝土 | [69270](../../artifact-rendering-study/source/extracted/bundle-1.js#L69270)；当前 [impact_effects.gd:130](../scripts/impact_effects.gd#L130)缺该分支 |
| Gull 常态/攻击 | 四旋翼不同倍率旋转、透明旋翼盘、gimbal/灯球/枪、三色strobe、HDR lens、透明光锥、共享扫地灯、telegraph、世界flash | [81651–81908](../../artifact-rendering-study/source/extracted/bundle-1.js#L81651) |
| Gull 弹丸/死亡 | 发光运动 bolt、墙面impact；失去单旋翼、灯/频闪收缩、翻滚坠落烟、碰撞爆炸与AoE、回收 | [81577–81650](../../artifact-rendering-study/source/extracted/bundle-1.js#L81577)、[83169–83209](../../artifact-rendering-study/source/extracted/bundle-1.js#L83169) |

现有粒子与灯池可复用，但应增加明确的世界空间 `smoke / sparks / debris / muzzle_flash / tracer` 适配层，保留原作默认参数与 RNG 归属。当前 `weapon_effects.fire` 绑定玩家武器，不能让敌人借用其第一人称枪口；`impact_effects.dust` 需要显式 size/color，不能直接照抄原作省略参数的调用。[weapon_effects.gd:12–26](../scripts/weapon_effects.gd#L12)、[impact_effects.gd:30–81](../scripts/impact_effects.gd#L30)

## 8. Gull 接入时不能沿用的 Hound 假设

Gull `XS` 在 [81384](../../artifact-rendering-study/source/extracted/bundle-1.js#L81384)，activate 在 [81486](../../artifact-rendering-study/source/extracted/bundle-1.js#L81486)，存活更新 `v` 在 [81651](../../artifact-rendering-study/source/extracted/bundle-1.js#L81651)。它共享 manager 感知、token、RNG，却有独立飞行与攻击过程。

- engage 围绕玩家作水平轨道，半径/高度/方向有随机变化；丢 LOS 后追 lastKnown。investigate/search 作较小搜索轨道；patrol 围绕 home，另有 hoverFixed。运动是目标加速度、速度限幅、前/下/上分轮次探测及逐轴射线避障；不是 nav A*。
- group 使用 YXZ，同时含 yaw/pitch/roll；body 还叠加悬停；rotor0–3 以不同正负倍率旋转。受伤后飞行姿态增加不稳定扰动。gimbalYaw/ball 与机体姿态不同，sensor、muzzle 用原作解析偏移，不能统一成 Hound 的 bone-derived muzzle。
- atk 为 idle/tele/burst；从 idle 请求同一 token，telegraph 到期连发。每 update 至多发一发，结束释放。bolt 目标有玩家水平速度预判、随机 lead、exposure 与移动散布，受伤又放大散布。
- Gull `_raycast` 只有 body 命中：把相对 y 和射线 y 都乘 2.3 后，求半径 `.5` 的球相交，等效为竖直压扁的椭球；没有 Hound 那样的 weak 点。命中法线也沿用源公式，不依照视觉机体 roll/pitch 重定向这个命中体。[81549–81572](../../artifact-rendering-study/source/extracted/bundle-1.js#L81549)
- bolt 是 32 槽池，life1.3，speed 当前70；每帧先对移动段做世界 raycast，再在被墙截断的段上用 `jD` 检测玩家竖直胶囊（bottom+.35，top 为 crouch+1 / stand+1.5，radius.36）。命中玩家先于墙impact分支；不能只检测新位置而漏穿透。[83169](../../artifact-rendering-study/source/extracted/bundle-1.js#L83169)、[`jD` 83374](../../artifact-rendering-study/source/extracted/bundle-1.js#L83374)
- fireBolt 池满时没有新弹丸，actor 仍继续开火效果与状态；damage 在撞击时读取当前 tuning。bolt 来自哪个 actor 不影响活体碰撞过滤，不是给每只 Gull 一个独立 projectile pool。
- 死亡即发 killed，失去一个随机旋翼，获得旋转和冲量。扫掠射线命中、超过5秒或低于y=-3时，发视觉 explosion(size1.2)，再 `combat.explode(radius3,damage30,owner="enemy")`，最后 retire；没有持久 Gull wreck。[81577–81650](../../artifact-rendering-study/source/extracted/bundle-1.js#L81577)
- Gull 的光锥是蒙皮附属网格；manager 另从共享灯池只申请一个灯位，给相机60米内最近的活 Gull。每.1秒沿 gimbal 查14米射线，平滑目标位置与能量。不是每只 Gull 一盏 SpotLight。[82950–82981](../../artifact-rendering-study/source/extracted/bundle-1.js#L82950)、[83220–83260](../../artifact-rendering-study/source/extracted/bundle-1.js#L83220)

这个共享灯在首次 update 尝试 acquire 一次，失败也不自动重试；clear 只把其强度设0，不 release。原作行为会占用公共灯槽，移植需要把它纳入灯池容量与生命周期验收。若改成更积极的回收/重试，要单列为与原作不同的修正。

## 9. 分阶段实施与必要验收

每阶段都推进完整玩法所需能力。阶段完成只代表该阶段有证据，不能据此宣称完整敌人或完整游戏完成。

| 阶段 | 原生交付 | 必要证据 |
| --- | --- | --- |
| A：合约与管理器 | 统一 player damage/eye/forward；事件；共享状态/池/RNG/token；rig 双写；原作 tuning 变更 | manager 申请/释放/公平/clear/spawn/retire 事件轨迹；池无重复 group；逻辑 eye/forward 对照；两种 mesh 共享骨架 |
| B：Hound 运动与感知 | 完整字段/reset、think、patrol/investigate/search、firePos、replan、feeler/slide/push | 固定输入与独立随机流，逐帧 mode、goal/path/wp、pos/yaw/speed/push、LOS、RNG index；墙角、窄路、原地转身、敌群挤开、动态移除可爆物 |
| C：程序四足 | 世界 p/from/to/slide、对角组调度、body/antenna 弹簧、解析 IK、head/turret/gun | 每帧四足世界点、20骨局部与全局矩阵、蒙皮抽样点、标签世界矩阵；地面/台阶边缘、90°/180° yaw、同帧 pitch+roll、站立调整、受击 |
| D：Hound 完整攻击 | move/aim/cool/tele/burst/wind/lunge/recover，hitscan/weakpoint、伤害、全部视觉反馈 | token 与 shot event 精确时刻；墙遮挡、移动玩家、近战抢占、玩家死亡、tele/burst 中杀死敌人；原作同射线命中结果与伤害相同 |
| E：死亡残骸 | 动态坍塌、滑足、烟火、持久wreck、排斥、下沉、池复用 | 死亡只计一次；死后持续姿态轨迹；6.5秒不自动消失；第6残骸下沉；8槽占满后复用；重激活无旧token/姿态/材质泄漏 |
| F：Gull 与混合群 | 飞行、13骨、传感与光锥、扫描灯、bolt、坠毁AoE，双方共用manager | 独立Gull轨迹；墙前玩家/墙后玩家/蹲伏/高速bolt；池满；交错spawn与token公平；AoE连锁导致多个actor同帧死亡/retire |
| G：游戏闭环 | 原作巡逻、三目标波次、追击、难度、holdout、title/暂停/重试/胜负事件 | 完整可玩场景录像与事件日志；所有 mode、es/atk、death 分支和难度有覆盖；没有依赖录制轨迹才能活动的敌人 |

建议参考导出按 **同一 dt 序列、同一初始 actor 状态、同一物理场景、同一独立随机流** 驱动 JS 与 Godot，至少含 `1/60`、`1/30`、`.05` 与大 dt 截断。源代码的 burst/swing/sense 是一次分支处理，不能用固定帧率或 while catch-up 改写后再比末帧截图。

差分字段最低要求：manager 时间/token/history/RNG游标；actor active/alive/id/mode/es或atk/各计时器；root pos/yaw/vel或speed；LOS/lastKnown/exposure/goal/path/wp；四脚完整状态与六个弹簧；所有骨的局部矩阵、headPos/muzzle；hp；bolt槽；wreck队列；同步事件的类型、时刻、对象、位置与伤害。

离散状态、事件数量/顺序、RNG 整数和命中 part 应完全相同。浮点向量/矩阵可为 Godot 标准精度设明确容差，并同时报告最大误差与首处分歧；不能用宽松位置容差掩盖已经走了不同状态分支。测试高台首帧、yaw接近±π、最大腿伸展、root不在原点、同帧死亡归池与新生、群体>5的token容量切换。

动态骨骼的验收同时看局部矩阵和屏幕效果：world foot contacts 固定时皮肤脚端应稳定，body编号跟随，枪口与head弱点吻合，Gull主网格/透明附属网格一起变形。已有静态蒙皮采样误差、导航路径验证和 RNG 单函数验证都是有效基础，但各自不能代替这些运行证据。
