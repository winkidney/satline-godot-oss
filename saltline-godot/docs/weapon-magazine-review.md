# 武器弹匣实时轨迹审查

本轮只读审查 [MagazineMotion](../scripts/weapon_magazine_motion.gd)、Weapon / ReloadKernel / Main / PartsView 接线及原函数参考。仅本文件由顾问写入。当前未发现弹匣生产轨迹或接线的阻断问题；范围为两枪弹匣局部 transform 与该节点所有权，不包含手部目标、手指姿态或 IK。

## 原轨迹与移植边界

依据 [原 bundle](../../artifact-rendering-study/source/extracted/bundle-1.js) 的 rifle 构造段 76860–76944、reload 77085–77168，以及 pistol 构造段 78521–78599、reload 78716–78789：

- Rifle 的初始 pinch、下抽、转移、换握、上提、对准和插入路径对应原 `M/T/S/U/L` 构造。`.8` 时从 pinch 逆矩阵改用 carry 逆矩阵，是原函数的换握行为；当前代码保留该切换，没有额外平滑或把采样轨迹再次叠加。
- Rifle 插入后的 `ze` 决定弹匣 y 位移；原 `Ge/_e` 的 windup、rebound、tug 分量操作手部目标，不应一起加到弹匣。当前移植在 magin 后使弹匣留在 rest，与原 `c.position.copy(u).add(oe)` 一致。
- Pistol 原 `.1366` 之前沿斜轴运动，此后叠加 `4.9 * fall²` 的重力项和 `-2.6 * fall` 自转。重力方向明确由原 **旧枪根局部 quaternion 的 inverse** 旋转 `(0,-1,0)`，不是 camera 或枪根 world rotation。当前 `root_rotations.pistol.inverse()` 保留原坐标定义。
- Pistol replacement 使用 `offsetQuaternion * rake`；落下自转使用 `rake * spinQuaternion`。当前乘法顺序正确。swap 到 rise 的时间段采用 `max(time,.52)`，保留原替换弹匣立即到 rise 起点的行为。
- 原弹匣局部 basis 为单位 scale。当前基于 `Transform3D` 的位置插值和 quaternion slerp 会经历 Godot FP32 舍入，不能声称与 JS double 逐位一致；现有矩阵门槛 `2e-6` 覆盖的是该局部 transform 数值误差。

当前 source 的 rifle/pistol magazine 分别对应动画节点索引 82 / 99，均为 Group。原 rest 分别为 `(0,-.02,-.0665)` / identity，及 `(0,-.013,.0387)` / x rotation `-.314`；已与导出 matrix 核对，和 reset 常量一致。角色解析仍依赖此 source 的 children ordinal，不是任意 rig 的通用识别。

## 生产时序、取消与写入归属

[Main](../scripts/main.gd) 在 `weapon.update` 前采集两枪已有 root 的 local quaternion。随后 ReloadKernel 更新弹匣，再推进本帧 D 和 Animation；没有误用本帧 D 之后的新旋转。切枪可以在 Weapon.update 内更换 active rig，因此预先采集两枪也保证新 active rig 的旧局部旋转可用。该输入合同由 Main 提供；单独使用 MagazineMotion 的调用方需要显式提供对应 root rotation。

[ReloadKernel](../scripts/weapon_reload_motion.gd) 在原 reload middle 所处位置更新 magazine：rifle 在 ant targets 后、连续 reloadW/rackW 前；pistol 在 ant targets 后、slide pose 与连续权重前。magin 等事件仍在轨迹更新之前。取消/完成通过 reload context 的 weapon 选择需要复位的弹匣，reset 则复位两枪；未清空 root rotation 缓存不会影响 rest，下一次生产 update 前 Main 会重新采集。

[PartsView](../scripts/weapon_parts_view.gd) 将两个 magazine 加入 owned 集合，[Animation](../scripts/weapon_animation.gd) 因而跳过旧 transform 和 visible 写入。View 先恢复 source rest，再将 MagazineMotion 的完整局部 transform 作为唯一结果写入，并保持 magazine visible；原 ge/de helper 同样恢复可见。既有 round 子节点仍由 Parts 控制 visible，随 magazine 父节点一起移动。没有把 magazine 位移应用两次，也没有新增反向 owner 引用形成环。

原 cancel 的 ge/de 同时恢复手部目标；本轮只接管其弹匣复位。手臂仍由原采样过渡，不能将弹匣取消通过扩大为完整 cancelReload 手部行为一致。

## 参考独立性与证据

[参考生成器](../tools/weapon_magazine_reference.cjs) 提取原完整 reload methods、构造 closures 与 helpers，使用导出的原 holds p/q。手指 pose 占位只流向手部数组，不参与目标弹匣矩阵；expected 不调用 native MagazineMotion。两枪 empty / tactical 共四组，覆盖 dense 120 Hz、边界、变化 root rotation 和 ge/de reset。顾问拦截文件写入后独立重算，fixture 逐字节一致；未改写参考资产。

[隔离报告](../evidence/weapon-magazine-verification.json) 为 1284 步 / 20544 矩阵通道，最大误差 `2.90990324798308e-7`，门槛 `2e-6`，0 failures。另有 128 个取消矩阵通道：两枪 × empty/tactical × 两个取消时刻，共八次实际 Weapon.update → switch 取消。expected 为原 ge/de reset 的 rest matrix，不是完整 literal cancel wrapper；locked、round 与 ammo 的完整语义不属于这 128 通道的新增证明。`.6` 的四例取消前有非零偏移；rifle `1.6` / pistol `1.2` 的另外四例已经处于 rest，验证的是保留 rest 和清 reload。

审查发现的取消循环有限数检查缺口已修复：最终 verifier 同时检查 actual / expected 有限，再检查误差。主线重跑仍为 128 个 lifecycle 通道、0 failures，容差未改；不再保留 NaN 可绕过该循环的旧问题。

[实际 Main 运行报告](../evidence/weapon-magazine-runtime.json) 为 470 帧、940 次两个 magazine 实际节点 transform 检查，并保留既有 2820 次六机械角色检查和 25 次空仓 hold 检查，failures 为空。运行时另行核对 Main 采集的 quaternion 与 update 前的 root，故 old-root 时序不只依赖代码推断。节点 transform 对照证明实际采样没有覆盖实时值；它不是原整场景图像对照。

[运行时原函数重放](../tools/verify_weapon_magazine_runtime_reference.cjs) 使用记录的 time、empty 和旧 local root quaternion 作为输入，以原 JS 计算 expected，再比较实际节点 matrix。native matrix 没有进入 expected 计算，属于有效的条件对照；其上游输入仍来自 native，本身不证明原完整游戏会生成同一时间和 root 轨迹。[报告](../evidence/weapon-magazine-runtime-reference.json) 为 281 行 / 4496 通道，最大误差 `2.748394861262077e-7`，门槛 `2e-6`，0 failures。顾问无写入重放后报告全字段一致，实际矩阵与原 JS expected 均无非有限值。281 行实际为 pistol 115 帧、rifle 164 帧及两次 reset；两条生产轨迹均为空仓换弹，tactical 由上述隔离参考覆盖。

证据标识：fixture 文件 SHA-256 `39b126950e2c816c51c94563658f44565b8951bd41a33712c41cd529d02d3e30`；原 source SHA-256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`；提取 reload 段 SHA-256 `e3cb26df295a6439bfff3b1e12d59e0b29b2045f33ed7eac71aefa2113fc0491`。

## 剩余范围

两枪弹匣已从 clip sampling 改为原函数实时轨迹。手部 targets、手指 pose、左右臂 impulse、实时 IK 与现有 rigid shoulder 过渡仍未完成；完整 O/drop、原全局 RNG 启动流及逐像素视觉校准也不由本轮证据覆盖。未来接 IK 应复用相同 reload 时间与持握变换，并保持弹匣独立节点所有权，不再用整段 sampled magazine pose 覆盖当前结果。
