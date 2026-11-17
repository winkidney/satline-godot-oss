# vS 手臂目标混合内核审查

本轮只读核对 [weapon_arm_blend.gd](../scripts/weapon_arm_blend.gd)、[参考生成器](../tools/weapon_arm_blend_reference.cjs) 与原 bundled Three。仅本文件由顾问写入。当前未发现正常目标混合内核的阻断问题；它尚未生产接线，验证边界为送入 Fh 的参数，不是 Fh IK、骨骼姿态或画面。

## Quaternion alias 必须保留

[原 bundle](../../artifact-rendering-study/source/extracted/bundle-1.js) 76350 调用 `c.slerpQuaternions(k.from.q, c, I)`。同一 bundle 1729–1730 的实现是 `this.copy(e).slerp(t, i)`；destination 与第二个输入同为 `c`，所以 `copy(e)` 先把原目标覆盖。它不执行预期的 from → target 方向插值。

顾问以原 bundled Three 重放，仅包装 `slerpQuaternions` 计数：最终 540 步序列中 52 个混合帧、左右手共 104 次调用全部满足 destination === second。输出相对 from 的最大分量差约 `3.33e-16`。这是原运行语义的直接证据，不是根据 native 结果重写 expected。

当前 native 在 `weight < 1` 时选择 `item.from.q`，保留原行为。这里的 from.q 已在当帧按 `root.q * from_local_q` 重建，会随 root 转动，不能理解为整个混合期间固定世界方向；到 `weight >= 1`，直接使用当帧目标方向。正常 slerp 初版的 [失败报告](../evidence/weapon-arm-blend-initial-mismatch.json) 最大误差 `.133460336367384` 已保留，最终没有放宽 `2e-6` 门槛。

此结论针对原 unit-quaternion 输入合同与实际正常路径。Three 的自 slerp 仍可能产生浮点末位变化，native 也使用 FP32 quaternion；验证比较旋转的等价符号，不能称 quaternion 分量逐位一致，也不是任意非单位输入的完整 Three slerp 仿真。

## 坐标、历史与调用语义

原 vS 76292–76364 与当前实现对应如下：

- `blend` 在首次有效 update 前无效；之后复制上一帧实际输出的 p/q/pose/pole/shoulder 到 from。新的 blend 可以从上一次混合的中间结果开始，不重新读取原目标作为起点。
- pending-local 的转换发生于 **blend 后第一次 update**：将历史 p/q 转到该次 update 的 root local，而非在调用 blend 的瞬间采集 root。每个未完成的混合帧再按当前 root 重建 from.p/from.q。当前实现保留这个时点。
- 普通模式下，手目标 p/q 由枪根局部变到 root 所在父空间；pole 和 shoulder 已在 solver 预期空间，不再乘枪根旋转。不能将所有字段统一套一个 Transform3D。
- attached 模式下，目标 p/q 直接传递；pole 仅乘 attachment inverse，shoulder 先减 attachment position 再乘 inverse。这对应原 76339–76347，native 没有把目标再乘 attachment 造成双重变换。
- 历史 from-local 的捕获和重建在 attached 模式下也照原文执行。不能因“attached 应该局部化”而另改历史路径；参考中的 attached blend 已覆盖该行为。
- `snap` 设置 progress=1、duration=0 并清 pending-local，不清 last/from 或 initialized。`attach` 只终止当前 progress，保留 duration / pending-local，和原 `attach` 只赋 `y=1` 相符；二者不能未经验证合并成一个 reset 方法。
- p、pole、shoulder 使用插值；20 个 finger 值经 Float32 存储，符合原 `tn` 写入 Float32Array。trigger 直接使用本帧值，不随混合权重插值；lean 固定 `.2`。history.last 保存混合后的输入，并在调用 Fh 前更新，符合原顺序。

native 的历史与输出使用独立副本，避免调用方修改当前输出反向改变 last/from；没有引入 solver 或 Scene 的所有权回环。`output` Dictionary 本身会复用，未来消费者若保存跨帧快照，需要自行复制；本内核目标是即时提供 solver 输入。

## 参考独立性与覆盖

生成器直接提取原完整 vS 与 `tn`，运行原 bundled Three 数学类。A5、肩/极点常量和 cS 包装已与原 76232–76246、73078、75343、75929–75930 核对。每帧 armTargets 提供合成输入，覆盖全部 20 个 pose 通道，因此初始 relaxed pose 占位不影响本轮输出。

Fh mock 在 setFingers、setTrigger 和 solve 入口复制参数；它不计算或替代 native 混合结果。原 Fh 75478–75479 复制 finger 数组，75496–75503 将位置/旋转/pole 复制到内部 scratch；vS 也在调用 Fh 前保存 last。因此 mock 未删除会反馈修改本轮混合输入的动作。真实 Fh 的 solve、update、骨骼修改和动力学没有执行，该参考不能证明它接收参数后会得到相同骨骼结果，也不验证 trigger 夹紧或手指 limits。native 的 attach 接口接受预构造 quaternion，而原接口接受 YXZ Euler；fixture 使用原 Three 把对应角度转换为 quaternion，未把 Euler 转换伪装成此 native 内核已提供的功能。

顾问无写入独立重放后，fixture 逐字节一致。[最终报告](../evidence/weapon-arm-blend-verification.json) 为 540 步 / 37800 比较，0 failures，最大误差 `1.52318401114293e-7`，门槛 `2e-6`。每手比较 p3、q4、pole3、shoulder3、pose20、trigger1、lean1，共 35 通道；`540 × 2 × 35 = 37800`。verifier 检查双方有限，并允许 quaternion 的 q/-q 等价表示。

序列覆盖首帧 blend 被忽略、进行中重复 blend、duration=0、dt=0、持续移动 root、正常与 attached 模式以及 attach/detach 调用。审查提出的进行中中断覆盖已补齐：89→90 与 439→440 为 blend 后 snap，239→240 为 blend 后 attach，349→350 为 blend 后 detach。最终 540 步 / 37800 比较仍通过，最大误差和门槛不变。每行仍为一个可选控制操作再 update，不将它扩大为任意同帧多操作序列的穷尽证明。

最终 fixture SHA-256 为 `1b5a48e770d4e286f5e9560c1007f115d2f4788a0983640730746f8e34951be9`，source SHA-256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，提取 vS stage SHA-256 为 `59a932b2961067045edcd0f59231361e3910a3c443ff87589c607f981e6a608d`。

## 后续生产边界

当前 attach 只实现数值空间变换，未实现原 group reparent、layer 和 visible 管理。生产桥仍需落实原正常 update 的有效 rig/armTargets 与 dropping 早退、每帧调用时点，以及 attach 对应的父节点空间；不能直接把返回的 solver 输入当骨骼 pose 写入。Fh IK 与手部动力学属于独立审查范围；startDrop/dropUpdate、真实 armTargets / solver / 骨骼接线和最终画面对照不由本轮证据覆盖。本轮不修改这些后续实现，也不宣称手臂已实时接管。
