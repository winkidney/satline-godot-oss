# 实时弹匣轨迹

枪械弹匣已从动画采样切换为原作逐帧轨迹。步枪包含拔出、换手、带入和回插；手枪包含沿弹匣轴脱落、重力下坠、旋转和插入。此阶段未替换手部目标与完整 IK。

原始依据是 `artifact-rendering-study/source/extracted/bundle-1.js` 的 wS/zS 闭包、完整 reload 方法及 Ru/tn 插值。源 SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。参考生成器保留原 Three 数学和原变换构造，holds 直接读取原导出 p/q。仅手部姿态占位数据被替换，其值不参与弹匣位置和旋转计算。

`weapon_magazine_motion.gd` 保存两个本地 Transform3D。Main 在 Weapon.update 前采集上一帧枪根的本地 quaternion；手枪重力转换使用这个旋转的逆，保持原作更新顺序。Reload 在原分支位置更新弹匣。PartsView 独占 rifle root child5 和 pistol root child6，采样器跳过这些节点。换枪取消、装填完成和 reset 恢复原位。

步枪使用原 pinch/carry 握持变换的逆完成换手。插值保留 Ru 的五次曲线和分母保护，以及插入曲线的 2.2 次幂和夹取。手枪弹匣轴 `[0,-.951,.309]` 按原值保留，不归一化。脱落阶段使用原 .1366 秒切换点和 4.9 重力系数。

## 验证

- `tools/weapon_magazine_reference.cjs` 生成四个空仓/战术换弹用例，覆盖 120 Hz 密集采样、边界左右和变化枪根旋转。
- `tools/verify_weapon_magazine.gd`：1,284 步、20,544 矩阵通道，最大误差 2.91e-7，容限 2e-6。另检查两枪空仓/战术换弹在入匣前后的8次取消端点，共128通道并检查有限数；其中4次取消时弹匣有偏移，另4次原已归位。
- `tools/verify_weapon_magazine_runtime.gd`：GPU 实际 Main 运行 470 帧，940 次弹匣节点与控制器一致性检查、2,820 次既有机械角色检查和 25 次空仓保持检查通过。
- `tools/verify_weapon_magazine_runtime_reference.cjs`：将实机两枪空仓换弹记录的旧本地旋转、时间和实际节点矩阵重放到原 reload 闭包，281 行、4,496 通道最大误差 2.75e-7，容限仍为 2e-6。

结果保存在 `evidence/weapon-magazine-*.json`，截图为 `evidence/magazine-runtime-070.png` 和 `408.png`。运行日志 `/tmp/saltline-magazine-runtime.log` 无错误或泄漏报告。此验证只证明弹匣本地轨迹和接线，未证明完整手部 IK、整幅图像或全游戏时序对齐。

## 下一阶段接口调查

原作 vS 在 76247 附近创建左右手目标和历史状态；update 调用枪械 armTargets 后，将局部手腕变换乘枪根变换，肩和 pole 按相机空间处理，再调用 Fh.solve 与 update。切枪 blend 会先把历史手腕转换到新枪根局部空间，再逐帧还原到当前枪根空间，不能只插值最终骨骼。Fh 位于75404，solve 位于75626，负责原手臂骨链和手腕约束。步枪 armTargets 位于77185，包含16/s触发手指过渡及冲刺肩/pole变化；手枪位于78835。迁移应依次隔离枪械目标、vS历史/混合、Fh求解与骨骼写入，再移除现有采样手臂。以上是源码位置和依赖关系调查，尚未声称实现或验证这些阶段。
