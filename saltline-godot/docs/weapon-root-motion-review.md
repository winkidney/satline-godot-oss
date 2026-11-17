# 原武器根运动内核审查

审查结论：当前 D 与两枪 recoil 的独立移植可以作为生产接管的计算内核。逐段核对未发现已知输入范围内的公式或状态更新顺序缺陷；参考独立性和本轮指出的验证漏洞已经收口。此结论不表示原 O、完整射击 RNG 流、换弹驱动、生命周期和手臂 IK 已接入。

本轮只读审查 [weapon_root_motion.gd](../scripts/weapon_root_motion.gd)、[参考生成器](../tools/weapon_root_motion_reference.cjs)、[验证器](../tools/verify_weapon_root_motion.gd) 与现有报告，没有修改代码或重新运行验证程序。确认生产 scripts 尚无该内核的调用，当前未覆盖既有采样 root。

## 最终磁盘证据

[weapon-root-motion-verification.json](../evidence/weapon-root-motion-verification.json) 当前为：

| 项目 | 结果 |
| --- | --- |
| 轨迹 | rifle / pistol 各 600 步，共 1200 步 |
| 标量比较 | 186,072 次，包含完整状态和新增 camera/shake 回调输出 |
| 最大标量误差 | `1.13242748511766e-14`，门槛 `1e-8` |
| 最大矩阵误差 | `3.7375165661685e-7`，门槛 `2e-6` |
| 原 recoil 调用 | 两枪各 24 次，共 48 次 |
| RNG 累计 | rifle 161、pistol 125；逐步核对真实 closure 计数与内核计数 |
| wall 查询 | 两枪各 191 次；逐步核对真实 closure 计数和 eye/forward/far |
| failures | 空数组 |

标量数包括状态中的固定参数，不能把它表述为 186,072 个不同动态场景。16 项矩阵对照已经覆盖最终位置和旋转；未单独比较 quaternion 的符号不构成姿态缺测，q 与 -q 本来等价。最终变换由 Godot float32 Vector/Basis/Quaternion 构造，因此与 CPU JS double 的误差需和标量弹簧误差分开看。

原 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`；D 提取段 SHA 为 `dd28a8747963c75e7086a1f37855f9bdd495f8928054e12cdc08dc82ea25a023`；两段 recoil 合并 SHA 为 `4437779e70f04044ec9a483eaede0a2581a60734fec477418a1849de78cbdd94`。本轮独立重算三项均与 fixture 相符。审查时 [fixture](../assets/export/fixtures/weapon-root-motion-reference.json) SHA 为 `f059114def0fd5750eb7f96d5a955eaaa424c529b99b2eef2efaaeb496bd7302`。

## 参考独立性

生成器直接读取原 bundle，提取字面 D、pn/en/Xn/AE/sa/ry、Hn/u0/Is/j0、_1/Ot、原常量，以及两枪的 recoil 方法；矩阵计算使用同一 bundle 的 Three。它没有读 native 脚本来生成 expected。少量闭包接线，例如固定随机流、raycast mock、me/ge/ce/P 和外部状态注入，是显式测试代码；其公式已与原 D 前的闭包逐项核对。

审查初版发现 wrapper 与 native 同时把 j0 重排为 lerp 形式。这已修正为提取原 `target+(value-target)*exp(-rate*dt)`，native damp 同步保留原表达顺序，未放宽门槛。fixture 的 patch 和 native merge 均已 deep clone，定向 spring patch 不会被随后的积分反向改写成“输入即结果”。

两枪从导出 debug.S 各自初始化，并显式设置本枪的 recoil/sway/air/inertia 系数。这是两个独立内核轨迹，不是原 equip/switch 的测试。固定五值随机流用于验证算法和消费次序，不是原模块 RNG fork 的真实序列。

## 公式与 JS/GDScript 语义

D 的 ADS 双弹簧、overshoot、sprint urgent 频率、reload/rack、wall cadence、旧 exert 的使用、breath/gait wrap、步相修正、惯性先更新低通再取残差、sway 先冲量后积分、落地换边与随机项、双 stance spring、六项 recoil 与 anticipation 均保持原顺序。

最终仍是 YXZ 的 base/detail 两个 quaternion，`q_base*q_detail`，以及 `pivot-rotate(q_detail,pivot)` 先与 recoil translation/ADS-out 合并，再经 base 旋转。未把 Euler 直接相加，也未给采样 root 追加第二份 sway。该类只返回 Transform3D，尚不写真实节点。

dt cap 只用于 D 的 B，a.t 由调用者推进。`onGround !== false` 已按 JS 的严格 false 语义实现；null vel/tuning/look 回退、无 ray、缺失 eye/forward 的分支已补入。`floor(phase+.5)` 保留 Math.round 的负半数值结果；-0 在此后与 phase 相减不改变本算法结果。

recoil 方法也已逐项对照原入口 L77017–77039、L78679–78696：

- rifle 保留 burst 1/2 的 first 系数、burst>9 的 camera 衰减、recPhase，以及缺少 addRecoil 时仍会计算 yaw 并消费一次随机数的行为。
- pistol 缺少 addRecoil 时跳过两个 camera 参数的随机数；root 强度及后续 kY/kR/kX 随机消费仍按原顺序执行。
- camera_scale 只作用于原 camera recoil/shake 相关项，不整体乘到 root impulse。root 使用各自的 crouch、adsBack/adsRot/adsPos 和 first 系数。
- rifle kU 有独立随机倍率，pistol kU 没有。两者都把冲量加到 velocity，而非直接改 spring position。

camera/shake callback 的实际向量和值与原字面 recoil 对照，再比较 D 后全部状态。它证明 recoil 方法本身，尚未证明外部 Q 的 spread、shell、flash 和 camera 调用没有重复或错序。

## 本轮补齐的验证缺口

验证器已显式拒绝所有被比较标量和矩阵中的 NaN/Inf，避免 `NaN > tolerance` 为 false 导致假通过。RNG 不再只比较内核自报计数，同时核对 random closure 的真实 index；ray 同样有独立计数，并断言查询参数。

第 300 步现在是明确的负半定向用例：dt=0、ground/wasGround=true、speed=0、stepEv=1、landEv=-1、gait=-.5、gOff.x/v/gOffT=0。两枪 expected 都得到 `gOffT=+.5`，生成器会断言此值。原先仅设置 gait 的版本并未进入该目标分支，不能沿用它的覆盖说法。

第 311 步直接设置正/负超限 sway 状态并使用 dt=0。rifle 输出为 `±.17500000000000002`、pistol 为 `±.21250000000000002`，对应速度为 0；生成器也断言该分支真正触发。此前 ±30 look 只证明输入 clamp，此次才覆盖 state clamp。零冲量落地仍消费 RNG、null 输入、noIdle、dt=0/.2、wrap 和 ADS overshoot 也保留在轨迹中。

## 接入前仍需完成的工作

1. **O 驱动和 lifecycle。** wants、urgent、reloadW/rackW、antYT/antRT、inspect、step/jump/land、time 仍由合成输入提供。原 reset/equip/snap 是选择性重置；两枪必须共享一份 S，且每 tick 只积分当前 rig 一次。当前测试没有切枪、暂停、死亡或恢复流程。
2. **真实射击次序和 RNG。** 新 recoil 方法接入后，必须撤掉或改由它负责 Main 原有 camera recoil，避免双调用。保留原 Q 在 D 前读取 muzzle/shell 的顺序。完整 weapon RNG 还包括 spread、shell、flash、burst recPhase 等消费，不由当前固定流测试证明。
3. **raycast 适配。** 当前 core 的合同为“未命中返回 null，命中返回带 dist 的对象”。本项目 SourcePhysics.raycast 未命中返回空 Dictionary，直接绑定会在 hit.dist 处出错。生产 adapter 应先转换为空值，并把 eye/forward 转成真实查询所需的 Vector3。原 JS 捕获 raycast 异常的行为也不能假定由 GDScript Callable 自动复现。
4. **root 唯一写入与采样过渡。** 停止旧 animation 对两枪 root 的 transform 写入，删除旧 holster 增量。枪内机械件与 arms 分开采样，避免 ADS 抹掉 bolt/slide；两臂 sibling group 只应用一次 live/sample root 差值，仍需明确不是原实时 IK。
5. **真实状态与可见验收。** 当前 rig.pose 是导出视图的姿态，其他 view preset、实际 ray 几何、完整连发/换弹中断、帧输入桥和死亡掉枪尚未由这两条轨迹验证。生产接管后再做事件次数、每 tick root 写入次数、节点/蒙皮同步与实际交互检查。

本轮可将“原 D 与原两枪 recoil 计算核独立对照”标为通过。完整实时武器动态仍应按 [weapon-motion-adviser.md](weapon-motion-adviser.md) 的接管阶段推进，不能把这个报告扩大为 root/parts/arms 全部完成。
