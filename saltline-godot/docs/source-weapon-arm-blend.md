# 手臂目标空间与切枪历史

`weapon_arm_blend.gd` 对应原 vS 的正常 update/blend/snap/attach 阶段，当前独立验证，尚未写生产骨骼。它接受原 armTargets 的输出和当前枪根，输出 Fh.solve 的输入。

未attach时，手腕位置/旋转乘枪根变换，肩/pole仍在相机空间。attach时手腕保持输入空间，肩减去挂接偏移后乘初始旋转的逆，pole只乘逆旋转。blend复制last历史；第一次update将历史手腕转换到该帧枪根局部空间，混合期间再随每帧枪根重建历史手腕。肩/pole和20通道姿态也混合，trig始终使用当前输入。

## 原作旋转别名行为

原76350调用 `c.slerpQuaternions(k.from.q,c,I)`。内置Three1729实现为 `this.copy(e).slerp(t,i)`。由于输出与第二输入同为c，copy后第二输入也变成from.q，因此I<1时朝向取随当前root重建的from.q，到I>=1才采用当前目标朝向。这里保留原行为。初版常规slerp与原对照最大误差.133460，失败保存在 `evidence/weapon-arm-blend-initial-mismatch.json`；修正别名语义后通过，未调宽容限。

## 验证

`tools/weapon_arm_blend_reference.cjs` 执行完整原vS，使用原Three数学，只将Fh替换为接收setFingers/setTrigger/solve输入的记录器。合成目标、变化枪根和dt覆盖首次blend、重复blend、snap、attach/detach、零时长blend及进行中混合的snap/attach中断。540步37800通道，最大误差1.52318e-7，容限2e-6，失败0。结果 `evidence/weapon-arm-blend-verification.json`。

这证明坐标转换与历史混合边界，不包含Fh求解、死亡drop、生产事件接线或完整画面对齐。
