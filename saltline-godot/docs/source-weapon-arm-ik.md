# 手臂与手腕 IK 核心

`weapon_arm_ik.gd` 对应原Fh内部L，使用double数组完成数学，仅在未来写骨骼时转换成Godot的float32。当前尚未生产接线。

实现上下臂长度.3/.27、最大伸展乘.999、最小距离差+.02、有限肩部前倾、pole退化回退、肘位置、上下臂旋转、手腕相对旋转、twist分配.42/.84，以及flex/deviation/twist/violation诊断和逐帧手腕位移。左右手按原x及quaternion y/z镜像；原零距离退化行为也保留，没有额外归一化或改用通用IK替代。五个局部旋转依次对应原骨骼0 upper、1 fore、2 twist近端、3 twist远端、4 hand。

`tools/weapon_arm_ik_reference.cjs` 直接提取完整原L，使用原Three数学和五个Object3D骨骼接收器，不依赖native结果。两侧各640步，含超长/过短/重合目标、共线pole和默认pole、变化lean与手腕朝向。`tools/verify_weapon_arm_ik.gd` 共1280步48640项，最大误差2.054e-15，容限1e-10，失败0。结果 `evidence/weapon-arm-ik-verification.json`。

原源SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`；L方法SHA256 `409cd26a2a4552218bcc43c93be648542e537c7b634bbfb15a5f7c493f566771`。验证包含求解核心与历史位移，不包含手指、impulse/update弹簧、实际Skeleton3D写入、vS组合实机或画面对齐。
