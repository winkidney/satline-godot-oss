# 实时 D 根接管审查

本次只读核对 Main、Weapon.step_root、RootMotion、WeaponAnimation、reset 路径，以及原 D 适配、变换和 GPU 探针。审查指出的死亡入口顺序与测试缺口已修正，当前范围未发现阻断。实时 D 已进入生产，枪根不再叠加原采样 sway/reload/holster；双臂采用一次采样根差值补偿。该双臂方案是明确的刚性过渡，不是原实时 IK。

本审查只新增本文。数值测试与 GPU 运行由主线完成，本次读取当前报告、代码及两张实际截图，没有重跑 GPU。

## 根的每帧归属

[Weapon](../scripts/weapon.gd) 构造时将 time 设为导出的 S.t，并让 RootMotion、reload、lifecycle、controls 共享同一 Dictionary。启动继续的是显式导出快照；不再混用 native time=0 与已推进的 S.t。reset 仍按原选择性规则保留 t、breath 等历史，不把时钟或随机流重建成开局值。这不代表原 HTML 的全局初始化消费、fork 和启动帧时序已经对齐。

[Main._advance_weapon](../scripts/main.gd) 的正常存活帧顺序为：

`Player.update / 玩家事件 → Weapon.update（含 Q）→ step_root 一次 → animation.update(live_root) → 后续效果更新`。

Q 在 D 和新根写入之前执行，因此 muzzle/eject 继续读取上一份根。D 读取本帧控制目标、reload/recoil 冲量与玩家事件，推进共享弹簧并清 stepEv/jumpEv/landEv；随后由 animation 的唯一 live 分支提交 active root。原 D 内部仍 cap dt 到 .1，外部时钟使用传入的原 dt，没有补跑第二次积分。

step_root 把 NativePlayer 的 on_ground、speed、Vector3 velocity、yaw、eye、forward、crouching、sprinting 和 tuning 映射到原 D 的字段。raycast 未命中从 source_physics 的空 Dictionary 转成 null，命中保留 dist。这项适配必要：空 Dictionary 不能直接冒充原 JS 的 null 命中结果。

## 采样保留与单次双臂差值

[weapon_animation.gd](../scripts/weapon_animation.gd) 在首次收到 live_root 后锁定 live_root_enabled。即使后续 update 没有 live 参数，也不恢复采样根或旧 holster 增量。旧纯采样分支只用于尚未进入 live 模式的隔离 clip 测试/预览。

采样循环仍计算 active gun 在当前 clip、当前 cursor、当前 ADS/sprint 混合下的 sampled_root，且在跳过 root 写入之前保存它。所有枪 root、key/target 和其他非 gun-child/arm 节点都不再接受采样写入；机械子节点与双臂局部姿态继续采样。

两组手臂每帧先恢复采样 transform，再只执行一次：

`delta = live_root × sampled_root.affine_inverse()`

`arm_group = delta × sampled_arm_group`。

不能将 delta 继续乘到上帧已经修正的组上，也不能给组和组内每个骨骼同时乘 delta。当前代码两点都没有犯。真实导出树中两组 arm 和两枪 root 都是同一 camera 的子节点，矩阵在同一局部空间；每个实际 Skeleton3D 位于其 arm group 下，因此组变换自然作用于 skin。

骨代理节点与 Skeleton3D slot 仍双写相同的采样局部 pose，避免只移动代理却没有驱动实际 skin。delta 只作用于组，不再次写进骨 pose。基于现有资源独立盘点得到 104 个采样节点、70 个 Bone、26 个 gun children、2 个 arm groups，当前分类与资源一致。

最终 active root 直接赋值 live_root，旧的 root.position.y/rotate_x holster 修正只在非 live 模式运行。inactive root 保留原 transform，只更新可见性；key/target 不被动画覆盖。没有发现其他普通生产动画路径再次写这两个枪根。

## 冻结、reset 与死亡

进入 live 模式后，update(weapon) 的无 live 参数调用使用现有 active root 计算 arms delta，不写 root、不增加 commit。Session.reset 调用的也是这条路径：重置 S 与采样子树后保留已有根，下一次正常 D 才提交新根。它不会短暂重新施加采样根或旧 holster。

暂停由上层 flow 阻止模拟 tick，不能用重复 step_root(dt=0) 代替暂停：原 D 即使 dt=0 也可能消费事件或随机分支。已死帧不再推进 D；冻结根只是当前 drop 尚未迁移时的明确边界，不是原死亡掉枪行为。

审查指出初版在 Weapon.update 返回后重新读取 alive，会漏掉 Q 中同步自伤/爆炸致死当帧的最后一次 D；原 O 只在入口判断 alive。最终 Main 已在入口保存 was_alive，并据此决定当前 D。GPU 探针在第 205 帧 fired 回调中置 alive=false，验证该帧仍 step/commit 一次，后续已死帧不再推进。这个定向回调证明入口顺序，不冒充完整爆炸/掉枪实现。

## 三层验证分别证明什么

### 原 D 到 NativePlayer 适配

[verify_weapon_root_adapter.gd](../tools/verify_weapon_root_adapter.gd) 调用生产 Weapon.step_root，对照 [原参考生成器](../tools/weapon_root_motion_reference.cjs) 的 `--native-player` 输出。生成器先把输入 vel 量化到 Native Vector3 可表示值，再执行原 JS D；它不是把 native 输出量化后回填 expected。

独立内存重放确认 1,200 步输入与 expected 一致。实际覆盖包括 48 次 recoil、420 次射线未命中、204 次 dt=0、198 次 dt>.1、60 次 no_idle；NativePlayer 合同不可能表示的 null velocity/tuning 或缺失 ray 已在该模式规范化，不能沿用旧通用 kernel 用例的缺项覆盖声明。

[适配报告](../evidence/weapon-root-adapter-verification.json) 1,200 步零失败，最大 state 误差 `1.13242748511766e-14`，最大矩阵通道误差 `2.33474381272636e-7`；门槛分别为 1e-8、2e-6。完整原 D 核的独立对照仍见 [weapon-root-motion-review.md](weapon-root-motion-review.md)。

最终适配探针除了确认同一 S/RNG、调用次数及空命中桥接，也已增加 origin/direction/far 参数断言。规范化的 NativePlayer fixture 固定 forward，并未测试所有世界方向组合；本次可以证明这些实际输入被准确转发，不能扩大为完整世界射线轨迹对照。

### 采样子树保留与变换不累积

[verify_weapon_live_animation.gd](../tools/verify_weapon_live_animation.gd) 使用导出层级、70 个真实 Skeleton3D slots 和真实动画代码，对比非 live 采样基线与 live 接管结果。[报告](../evidence/weapon-live-animation-verification.json) 最终为 22 case、66 次重复 live update、45,500 项变换检查，最大误差 `3.53882967374375e-7`，门槛 2e-6，零失败。

它检查 active/inactive root、key/target、一次 arm delta、子节点、骨代理/Skeleton 双写、holster 不重复以及冻结/reset writer guard。初次创建匿名节点引发的空 Node.name 错误保留在 [initial log](../evidence/weapon-live-animation-initial.log)，最终已清理。

这个 baseline 与被测分支共用同一个采样实现，因此证明的是“接管后保留当前采样子树与关系”，不是独立原 Three IK 或插值等价。审查发现初版前六个 mode 实际均进入 fire clip；最终每枪新增三个 time=.8 的 mode，真正覆盖 hip 基础与 ADS/sprint 混合，另保留 fire 和两种 reload。不能把内部基线回归误称为原 IK 参考。

### 实际 Main / GPU 路径

当前实际运行探针仍位于 [verify_weapon_shot_runtime.gd](../tools/verify_weapon_shot_runtime.gd)，权威结果写入 [weapon-shot-runtime.json](../evidence/weapon-shot-runtime.json)。最终 220 帧中记录 195 个 live tick 检查、70,200 次 bone/proxy 检查，9 发 rifle、4 发 pistol，共 13 发，零失败。每个 live tick 遍历的是全场景 360 个已绑定 bone/proxy target，其中包含 70 个武器 slots；70,200 不能写成全部来自 70 个武器骨。

正常 live tick 的 step/commit 各加 1，暂停不加；D 后玩家事件标志已消费，实际骨代理与 Skeleton pose 一致。Q 的回调内部仍每发 rifle 18/pistol 17 draws、单次 flash/light、旧 root 未变；D 的落地随机消费是帧级共享流行为，不能误算成每发射击的额外消费。

审查发现初版 render 后只复查 D 次数；最终已同时复查 live_root_steps、root_commits 和实际 root transform，因此该运行中的 render 阶段既没有重复 D，也没有额外 root commit/覆盖。正常、暂停和死亡入口路径分别检查，未用计数替代 transform 比较。

本次已查看 [rifle 截图](../evidence/live-root-040.png) 与 [pistol 截图](../evidence/live-root-160.png)，实际捕获 frame 为 41/161，文件名保留请求帧 40/160。它们证明当前路径确实产出两枪画面，不构成原 HTML 逐像素对照或完整手臂视觉验收。

## 仍保留的迁移边界

双臂整组跟随 live/sample 差值会移动肩部，是当前保持握枪关系的刚性过渡。原 arms target、shoulder/pole 约束、IK、手指动作、完整 parts/shot/cancelReload/drop 仍未迁移，不能用 70 个 slot 的一致性检查宣称它们已完成。

完整 O 的部分旧标量与 Effects 状态仍分别持有，原启动 RNG fork 和全局初始化消费仍未对齐；生产使用显式导出状态及 legacy seed。D 现在实时推进所需状态，不等于任意时刻整份 S 或全局随机轨迹与原作一致。

本阶段的交付边界是“原 D 已作为生产枪根驱动，采样根与旧 holster 已退出写入，双臂/机械子树以明确过渡方案继续工作”。后续应继续真实 IK、parts/drop 和完整 O/初始化对齐，避免为暂时刚性肩部另叠经验 sway 或 recoil。
