# 正常手臂实时接线与 Fh 审查

本轮只读审查 [weapon_arm_pose.gd](../scripts/weapon_arm_pose.gd)、[weapon_arms.gd](../scripts/weapon_arms.gd)、Weapon / ReloadKernel / Animation 接线及原 Fh 参考；仅本文件由顾问写入。当前未发现正常 alive 手臂路径的阻断问题。生产已使用实时目标、vS、Fh 和骨骼写入，原 arm clip 采样及 rigid group delta 不再叠加；死亡 drop 和公开 attach 流程尚未接入，不能视为本阶段完成。

## 调用顺序与冲量

[原 bundle](../../artifact-rendering-study/source/extracted/bundle-1.js) 79785–79788 的普通路径先 D，再 `p.update(B,Y,Y.root)`。当前 Weapon.step_root 先取得 D 的新 root transform，再调用一次 arms.step；Animation 随后提交 root 和手臂。求解使用的是本帧新 root，区别于 pistol 弹匣自由下落使用的旧 root 输入；这两个时点不应合并。

arms.step 依次执行 armTargets、vS blend、Fh setFingers、setTrigger、solve、update，对应原 vS 76319、76354–76362。D 自身限制 dt 为 `.1`；armTargets/vS 仍接收原 dt，Fh.update 独立截断为 `.05`，没有把所有阶段统一改用同一个截断值。

- 原 rifle shot 的左右臂冲量为 `.55/.35`，pistol 为 `.8/.6`；当前 fired 回调完成、机械 shot 更新后调用 arms.shot。原 rig.shot 内的 timer / impulse / locked 顺序略分散到两个对象，但此处没有回调或共享字段读取，两类写入互不依赖，最终同帧状态一致。
- 两枪 magin 都只给左臂 `1.0`，受同一成功的一次性 reload event 条件约束；没有另接一条 phase_event 监听导致重复冲量。
- 取消 reload 使用 `.22` blend，holster 转 draw 前使用 `.13` blend，与原 79317、79354 附近的调用点一致。blend 从上一帧实际输出建立历史，并保留已确认的 quaternion alias 行为，见 [vS 审查](weapon-arm-blend-review.md)。
- 正常 reset 复位两枪 armTargets engagement，调用 vS.snap，但不重新创建 Fh。原正常 reset 同样不清空 Fh finger springs、jiggle 或 solver history；当前保留这些对象是原行为，不应为“重试更干净”额外归零。reload-hand 与机械 private 的 reset 仍由其原归属模块执行。

本轮运行时验证为连续 alive 输入；死亡后的 drop/update、公开 attach 和其 reparent/layer 管理仍是独立边界。现有 Main 的进入 tick 时 alive 判定会让当帧射击回调中发生死亡的帧继续完成一次 D/arms，下一 tick 才停止正常求解，沿用已有 root 接管时序。

## Fh 状态和手指公式

原 Fh 构造与正常方法位于 bundle 75404–75728。当前实现保留五指二阶弹簧、腕部惯性、左右镜像及 helper bone，而非仅插值主手指骨。

- pose/shown、spring/velocity 使用 PackedFloat32Array，对应原 Float32Array 的逐次赋值舍入；惯性和 IK 数学使用 double 数组/标量。不能把隔离 double 内核精度等同于最终 Godot Vector3/Quaternion 写入精度。
- trigger clamp 为 `[0,1]`，其四个偏置只作用于 index finger；弹簧对各段的贡献、finger limits 与 helper 的半角 slerp/鼓包位移保留。拇指第一段不计算同类鼓包角差，左右手镜像只按原位置 x / quaternion y,z 处理。
- impulse 同时写五个 finger velocity 和腕部惯性速度。update 的 900/34 指弹簧、260/18 惯性系数、休眠阈值、位移耦合及 `.06` 最大摆幅与原一致。dt 非正时直接返回；不能在零 dt 下清 displacement 或推进 spring。
- solve 更新本帧 shoulder、五个前臂/手部旋转、twist base 和位移历史，update 再叠加 wrist jiggle。setFingers → setTrigger 的重复 render 顺序也与原一致，避免用新的 trigger 提前改变上一阶段的结果。

当前没有观察到状态漏接。该结论不表示已实现 Fh 所有公开工具方法；findPole、fitGrip、socket 等编辑/查询接口不属于当前正常生产调用链。

## 骨骼索引、空间与唯一写入

核对当前 source：左右各 35 个 Bone，骨名各自唯一，全部存在于导出的 bone_names；70 条父骨边与原 Fh 构造关系一致，包括 helper 与对应 digit 作为同一父骨子节点的关系。Animation 通过 source record 的骨名确定模型索引，通过 ancestor `arm-left/right` 确定侧别，不依赖 Godot 自动改名后的 Node.name。

[Animation](../scripts/weapon_animation.gd) 在 live 后跳过所有 arm_node 的旧 transform / visible / bone sampling，并停止旧 `liveRoot * sampledRoot.inverse()` group delta。随后两组 arm Group 设为 identity，再写实时局部骨骼 pose。正常原 Fh Group 位于 camera 下，solve 输入已在该父空间，因此再应用枪根或 group delta 会重复变换；当前没有这层叠加。

[SourceScene.set_source_transform](../scripts/source_scene.gd) 同时写骨代理 Node3D 与该 source bone 对应的 Skeleton3D pose，避免只有代理动、实际蒙皮不动。现有 source skin 绑定关系继续使用原 boneInverses。代码检查和本轮 runtime 检查证明写入对应关系；它们不单独重新证明 inverse bind、全部蒙皮顶点或与原画面逐像素一致。

对象关系为 Weapon → Arms → targeter/blend/models，ReloadKernel 持有 Arms 用于冲量；Arms 不持有 Weapon，step 参数临时使用。没有新增 Weapon↔Arms 强引用环。

## 参考独立性与验证范围

[Fh reference](../tools/weapon_arm_pose_reference.cjs) 保留原完整构造与方法、手指数据和公式。Group/Bone 为真实 bundled Three 类型；只替换 geometry/material/Skeleton/SkinnedMesh。原 calculateInverses 仅读骨骼 world matrix，显式 bind(identity) 写绑定矩阵而不修改 bone local p/q，因此这些 mock 不改变本次比较的局部骨骼结果。手指、trigger、impulse、solve、update 没有替换成 native 或重写的参考算法。

顾问拦截文件写入后独立重放，fixture 和 config 均逐字节一致。[Fh 报告](../evidence/weapon-arm-pose-verification.json) 为 840 步 / 240240 检查、0 failures，最大误差 `5.55111512312578e-16`，门槛 `1e-10`。每步比较 `20 pose + 20 shown + 1 trigger + 35 × 7 bone p/q = 286` 通道。实际覆盖 168 次零 dt、168 次 dt 截断、18 次 impulse、120 次负 trigger、96 次超上限 trigger；双方有限数检查有效。

该 fixture 没有直接导出私有 finger spring b/g、jiggle I、w/S/z 运动历史或 IK diagnostics；长序列骨骼输出对这些状态提供间接验证，不能称所有 private 状态已逐项相等。其肩手距离 `.370776–.478783` 也没有触及 reach/lean 极限或定向 pole 退化；这些边界来自另一个 [独立 IK 报告](../evidence/weapon-arm-ik-verification.json)：1280 步 / 48640 检查、0 failures、最大误差 `2.05391259555654e-15`，不是这 840 步的覆盖。

上游证据按各自范围保留：[armTargets](../evidence/weapon-arm-targets-verification.json) 720 步 / 48960 检查；[reload-hand 实际 Weapon.update 接线](../evidence/weapon-reload-hand-integration.json) 1284 步 / 35952 检查。它们与 vS/Fh 单独通过，并不自动组成原完整 O→手臂的端到端原作轨迹对照。

[实际运行报告](../evidence/weapon-arms-runtime.json) 已完成 470 帧：arms step 470 次，proxy bone 检查 32900 次、Skeleton3D bone 检查 32900 次，failures 为空，即每帧各检查全部 70 个骨骼。探针在同一迭代执行 game tick 和 Main render update，确认没有附加的 arm solve，且 group 保持 identity、实时结果未被采样覆盖。这是实际绘制路径与写入一致性的证据；expected 仍为本次 native model 的结果，不是该 470 帧逐帧原 Fh 的联合重放。

顾问查看 [pistol frame 110](../evidence/arms-runtime-110.png) 和 [rifle frame 350](../evidence/arms-runtime-350.png)，确认实际手臂蒙皮在两枪换弹场景渲染。没有配对原作截图，本轮不作视觉相同结论。

Fh fixture SHA-256：`cda3cf2e41b1a0536988d3c6712c893be8ec9696809d90a73678cec715966a02`；pose config SHA-256：`bc875ede99ddd38f3924879ebde7e946c47ce5c86433b7c32d985e36cfaf8462`；提取 Fh/helper SHA-256：`0aa7333a0191d4f17d5120cd6b4ed800c04821564bd242049eebb61f6c7bed83`；原 source SHA-256：`756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

## 尚未完成

正常实时手臂已经接管对应节点，不再把手臂采样过渡写作当前生产状态。死亡 startDrop/dropUpdate、公开 attach 的父节点与 layer/visible 流程、完整原游戏输入及 RNG 启动流、原整场景视觉对照仍未由本阶段完成。也不以正常 470 帧的通过替代这些分支的独立验收。
