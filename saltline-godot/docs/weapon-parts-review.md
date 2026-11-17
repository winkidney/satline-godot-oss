# 武器机械节点实时接管审查

本轮只读审查 `weapon_parts_motion.gd`、`weapon_parts_view.gd` 及 Weapon / ReloadKernel / Animation / Main 接线；仅本文件由顾问写入。当前未发现阻止这六个机械角色接管的代码问题。结论限于 rifle bolt / round 与 pistol slide / barrel / stop / round，弹匣轨迹、手部目标和 IK 仍属采样过渡路径。

## 原文与状态边界

依据 [原 bundle](../../artifact-rendering-study/source/extracted/bundle-1.js)：rifle `reset/cancelReload/shot` 为 77000–77015，reload 机械前缀为 77041–77084，`endReload/parts/setLocked` 为 77174–77206；pistol slider 为 78595–78599，`reset/cancelReload/shot` 为 78660–78677，reload stop/slide 段为 78790–78806，`endReload/parts/setLocked` 为 78816–78869。

- Rifle 的 `de/$/se/me` 对应 `time/locked/override/finger`。`yS=0` 是原常量：空仓时 rifle 并不靠 `locked` 将 bolt 长期保持在后端。当前 `.062 * max(wave * .95, override)` 保留此行为，不应按 pistol 的锁后逻辑改写。
- Pistol 的 `le/xe/j/q` 对应 `time/locked/stop_weight/finger`。`reloading && locked` 时跳过射击周期的 slide/stop 更新，保留 reload 给出的机械 pose；释放事件解锁后，同一帧 parts 恢复射击周期路径。`set_locked(true)` 同时把 time 设为 9，符合原文。
- Rifle handle 的三段运动、两类 back/release/bolt 时间和 partial `.32` 保留；pistol `.036` 锁后距离、`.04` 行程、`.006` barrel 联动阈值、`.02` barrel pitch、`.0025` barrel z 与 `-.06` stop pitch 均与原常量一致。
- 原 rifle 77085–77168、pistol 78716–78789 的省略段操作 magazine / hand pose，没有漏掉当前六 roles 所需机械写入。后续 pistol 机械段已单独保留。原 `fe/O/ue` 等手部混合状态及左右臂 `shot` impulse 尚未整体接管，不能把本轮描述成全部 rig-private 或手臂动态已迁移。

## 生产顺序与所有权

[Weapon](../scripts/weapon.gd) 在 fired 回调完成后调用 `parts_motion.shot`。当前 Main 回调先处理 recoil、bloom、flash，故对应原 Q 在 79432 的 flash 变换之后调用 `re.shot`。`motion_controls.finish` 更新 finger 后，仅对 active rig 调用一次 `parts_motion.step`；Main 再推进 D 并提交 Animation。它与原 O 的 79763–79764 顺序一致，没有在渲染回调中重复推进机械时间。

[ReloadKernel](../scripts/weapon_reload_motion.gd) 的 fresh round、magin、boltback、bolt、slide 与持续 handle/slide pose 插入点正确：一次性 private 变化受原 event 成功条件约束，连续 pose 每次 reload 调用更新。最终取消路径按 `reload.weapon` 选择机械状态和 ammo，与原 `B.rig.cancelReload(B.seated)` 一致，不再依赖可能变化的 current。只有 seated 才解除 lock；round visibility 由该枪 ammo 决定。完成仅清理对应 helper 负责的状态，不额外重置射击时间。reset 重建两枪机械状态；View 每次读取新的 per-gun Dictionary，不持有 reset 前的旧字典。

[Animation](../scripts/weapon_animation.gd) 在旧 transform、visible 和骨写入之前跳过 owned 六节点，随后由 [View](../scripts/weapon_parts_view.gd) 恢复各自 source base transform，再写机械局部参数。它不会把机械位移叠到已包含机械运动的采样 pose。非 active rig 状态不积分；对隐藏 rig 重复写入当前状态不会推进其周期。

核对当前导出的六个 base transform：basis 均为单位阵；barrel 保留 y `-.01`，stop 保留 y `-.0165` / z `-.004`。因此这里的绝对 `position.z` / `rotation.x` 写法与原文一致，也没有当前素材的欧拉顺序差异。未来若更换 source snapshot 或节点结构，应重新执行角色与 base 检查；角色发现依赖原 children ordinal，不能据此推广为任意 rig 自动识别。

所有权为 Weapon → Parts、ReloadKernel → Parts、Animation → View → Scene/Parts；Parts 不反向引用 Weapon/View。现有 ReloadKernel 的事件 owner 仍为 WeakRef，没有新增强引用环。View 与源 Scene 同生命周期，当前 Main 只绑定一次；若以后替换 Scene，必须同时重建 View，不能继续使用旧节点映射与 rest 缓存。

## 参考独立性与当前证据

[生成器](../tools/weapon_parts_reference.cjs) 从原 bundle 直接提取 methods、reset helpers、slider、reload 前缀及 pistol pose 段；不调用 native Parts 来生成 expected。包装层手写的 B1/H1、机械常量已逐项与源核对。顾问在内存中重放生成器，当前 fixture 与重放输出逐字节一致，source / parts SHA 匹配；未改写 fixture。

[隔离报告](../evidence/weapon-parts-verification.json) 最终为 272 operations / 3400 checks，0 failures，最大 state 误差 `3.10862446895044e-15`，最大 view 误差 `1.54972076144011e-9`；门槛仍分别为 `1e-12` / `2e-6`。3400 的构成为 rifle 六字段 816 次、pistol 九字段 1224 次及五个 view 数值 1360 次；另有 272 次两枪 round visibility 断言未计入 checks。顾问对最终 272-operation fixture 再次执行内存重放，逐字节一致。

最终 [fixture](../assets/export/fixtures/weapon-parts-reference.json) 文件 SHA-256 为 `46fe7a4907f72f3f3158f01d70fdce79de8c9e050ee923b507dcd45156c5b804`；source SHA-256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，原提取 parts 段 SHA-256 为 `10beec4d3616507cd4c55814adaea911ebf93dbc46406aad810c8f80fcf57c14`。文件 hash 包括最终时间表，区别于仅标识原文切片的 parts hash。

已覆盖 reset、空/非空 shot、lock 开关、cancel seated 两态、两种 reload、end，以及 pistol locked reload 跳过/执行两分支。真实 Animation 在 ADS / sprint / fire 采样压力下运行，角色对应原动画索引 81 / 84 / 92 / 94 / 98 / 101。

该 verifier 使用扁平 Node3D 层级和受控 Parts/ReloadKernel 调用，证明机械局部属性、角色映射及采样写入所有权；它不证明 Main 全事件顺序、真实父子世界变换或完整换弹动作。此前建议的 `1.865 / 1.9175 / 2.1375 / 1.59` 四个区间内点已补入，覆盖 rifle tactical 拉柄、两类 rifle 回位及 pistol reload pose。最终表已将 `1.59` 放在 `1.61` 前，实际命中顺序推进时的 locked-return 内点。该表不构成重复/倒退时间的完整覆盖矩阵；旧 reload 核的相关证据也不自动扩大为六机械 roles 的同类验证。

[实际 Main 运行报告](../evidence/weapon-parts-runtime.json) 已完成 470 帧，25 次持续空仓 hold 检查、2820 次六角色检查，failures 为空。最终探针逐角色断言实际 bolt/slide/barrel z、barrel pitch、stop pitch 及两颗 round 的 visible；2820 计的是 `470 × 6` 个角色，非属性标量总数。Pistol 帧 55–79 持续保持 slide `.036`、stop pitch `-.06`、round 隐藏，帧 200 已完成 reload 释放与回位；rifle 帧 280 保留原 `yS=0` 的空仓闭栓及 round 隐藏，帧 408 full pull 为 `.062`，帧 460 已回位。该证据覆盖实际 Main / Weapon / Parts / View 及真实节点路径，不再仅依赖扁平 CPU probe。[CPU clean log](../evidence/weapon-parts-clean.log) 与 [runtime log](../evidence/weapon-parts-runtime.log) 已落盘，未检出 ERROR 或泄漏记录；帧 70 / 408 图片由主线查看，顾问未将其称作原作图像对照。

[780 帧 flow 报告](../evidence/weapon-parts-flow.json) 及 [日志](../evidence/weapon-parts-flow.log) 已通过：pause 冻结、死亡后 retry、再次重启均完成，最终 state 为 playing，retries 为 2；日志未检出 ERROR 或泄漏。该流程仍保留其自动输入、完整原 HUD/settings 与视觉校准未完成的 scope。

最终磁盘的 [reload integration](../evidence/weapon-reload-integration-verification.json) 为 119266 比较、[Q / shot](../evidence/weapon-shot-verification.json) 为 1212 比较，均 0 failures；保留各自原 scope，不扩大为完整 O 或整场景验证。

## 尚未完成的边界

六角色的生产空仓持锁、reload 释放及对应实际节点检查已通过；本审查没有扩大或重跑 GPU 测试。当前弹匣轨迹、手臂采样、rigid shoulder delta、实时 IK、完整 O/drop 和原全局 RNG 启动流边界保持不变；六角色接管不等于完整原作武器动画或逐像素一致。
