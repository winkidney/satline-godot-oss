# 弹壳状态与旋转复刻

原版依据：`artifact-rendering-study/source/extracted/bundle-1.js` 第 58421–58589 行的 Kg；四元数 setFromEuler 第 1470 行和矩阵 compose 第 4871 行。源码 SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

## 修正

- 初始 Euler 使用 XYZ。任意弹壳落地后，共享 Euler 切换并保留 ZXY；clear 不重置此历史，也不重置 next。
- 年龄、静止时间、位置、速度、四元数、角速度及地板高度按原版 Float32Array 的写入点舍入。四元数积分在 double 标量内完成，再写回 Float32。
- Three 的 compose 直接使用储存的四元数。Godot Basis(quaternion) 会按长度重新归一化，因此使用原公式构建矩阵，包含衰减缩放。
- add 不立即显示网格，update 才更新显隐；构造和 clear 隐藏网格。
- 保留原版只有向下地面射线的碰撞模型，不额外加入墙面碰撞。

## 验证

运行 `node tools/shell_reference.cjs` 和 `tools/run_native.sh --headless --script tools/verify_shells.gd`。

fixture 直接执行原版 Kg 的 add、update、clear、_floorAt，原版四元数转换及 compose。607 步，89 次共享随机调用，40,205 项状态和矩阵构造检查通过，最大差异 3.553e-15。覆盖初次落地、后续 ZXY 发射、环形覆盖、弹跳、淡出和清空后复用。报告为 `evidence/shell-verification.json`。

边界：固定平坦金属地面、容量 3。未证明实际世界射线、所有容量、GPU 像素或整帧随机序列一致。矩阵比较为生产构造函数输出，不是 headless dummy renderer 的 MultiMesh 读回。首次矩阵测试使用了 dummy renderer 读回和不完整的 JS 四元数适配器，产生错误；修正测试适配器后再执行，未放宽容差。首次状态测试还发现并修正了 add 显隐时机差异。

GPU 回归：最终修正后 RTX 4070 SUPER 实跑 480 帧、13 次射击、6 次枪口余烟，原有 87 项射击链检查全部通过，日志无脚本/渲染错误。记录 `evidence/shell-chain-runtime.json` 和 `.log`。此回归验证射击链集成，不替代弹壳轨迹的原版整场景对照。
