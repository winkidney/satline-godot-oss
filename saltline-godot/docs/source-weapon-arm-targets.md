# 枪械手部目标内核

`weapon_arm_targets.gd` 迁移原作两枪 armTargets/snapArms，尚未接入生产骨骼。保持独立是为了先验证目标输入，再替换现有采样手臂。

已实现右手握持位置/旋转、grip/trigger 二十通道姿态混合、16/s 扳机参与度衰减、finger乘权；步枪冲刺肩/pole，手枪冲刺后瞄准的连续肩/pole插值，以及手枪滑套止动拇指四通道修正。左右握持数据直接读原导出 holds。左手 p/q/pose/busy 接口供下一步原 reload 左手轨迹驱动；busy=false 时仅 pose 恢复 fore/support，p/q 仍保持输入，这与原方法一致。

原初始和 reset 的参与度为1，snap按冲刺>.3、装填中或hol>.12决定0/1。连续 update 使用原指数曲线，姿态权重使用五次 smoothstep，输出姿态为 Float32Array 对应的 PackedFloat32Array。肩/pole 不应随枪根一起旋转；后续 vS 会分别处理这些坐标空间。

## 原函数验证

`tools/weapon_arm_targets_reference.cjs` 从原 bundle 提取完整 armTargets/snapArms 和 tn，原 sc/ol 配置另导出为 `assets/export/weapon-arm-config.json`。原 holds 使用 Three.Vector3/Quaternion 和 Float32Array。参考程序使用显式合成的spV/adsV/reload/hol/finger/止动权重/左手输入，覆盖边界、变化dt、busy切换和snap。没有用原生输出生成期望。

`tools/verify_weapon_arm_targets.gd` 对照720步、48960通道，最大误差7.79e-8，容限2e-6，失败0。结果 `evidence/weapon-arm-targets-verification.json`。源SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，方法和配置SHA256 `e4cf74b9c294ac67f24066cdf57c249e4027736e2c9cca76c6456c97e3d56a02`。

这证明目标内核在给定输入下对应原函数，不包含 reload 左手轨迹、vS 历史/切枪混合、Fh 手臂/手腕求解、手指骨骼写入、production集成或画面对齐。下一步应补全左手轨迹，再逐层验证 vS/Fh，最后移除采样手臂。
