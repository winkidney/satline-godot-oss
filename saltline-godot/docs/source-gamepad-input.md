# 手柄输入迁移与验证

## 原版依据

原始 `artifact-rendering-study/source/extracted/bundle-1.js` SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。输入实现为 `gE` 内的 `P/D/v/X/re`，按键映射 `le/xe`；瞄准减速来自 GameFlow 的 `B`，菜单行为来自 GameUI 的导航和调整方法。`tools/gamepad_reference.cjs` 从原始文件抽取方法，生成独立参考数据。

## 实现

`source_gamepad_input.gd` 保留每轴 0.14 死区、右摇杆三次曲线、满幅 0.45 秒加速、纵向 0.62 系数及灵敏度和反转设置。L3 冲刺锁定在前向量低于 0.55 时解除。X 按下瞬间锁定 Reload 或 Interact，持有期间不因提示出现或消失而改变。按钮数值严格大于 0.35 才触发。

各设备持有动作分别记录，合并到角色动作时避免一个设备释放另一个设备仍持有的动作。键盘按下重复、手柄按住时的首次按下、菜单方向重复及断开后的状态保留遵循原实现。垂直菜单首次重复等待 380ms，此后 170ms，横向只在方向变化时触发。

瞄准辅助每 0.05 秒查询相机前方 60 米敌人与遮挡，目标倍率为 0.55 或 1，按原指数平滑更新。当前帧输入使用上一帧倍率。Main 接入移动、视角、武器、继电器、暂停和菜单；HUD 的交互和切枪提示随设备切换。

`gamepad_device.gd` 将 Godot 已连接设备映射为浏览器标准 20 按钮和四轴快照，优先已知映射设备。原射击、受击、爆炸震动参数转为 Godot 的 weak/strong 顺序和秒单位。没有音效。

## 证据

- `evidence/gamepad-verification.json`：136 操作、5848 检查通过，最大数值误差 1.11e-16。覆盖死区、加速、冲刺、X 上下文、按键边沿、混合设备、菜单重复、断开重连和瞄准减速。
- `evidence/gamepad-runtime.json`：620 帧实际 Main，注入标准手柄快照，部署、移动/视角、LT/RT 瞄准射击、Y 切枪、X 完成一处继电器、暂停/设置/返回/恢复及断开全部通过。记录了九次射击震动请求。
- `evidence/gamepad-270.png`、`gamepad-400.png`、`gamepad-530.png` 为该次 GPU 运行截图。
- `evidence/gamepad-full-mission-regression.log`：接入后 1100 帧完整任务回归，14 断言通过，包括真实 E 持有、三处切断、撤离、结果卡片和重新部署。受控传送和无敌，不代表从出生点步行通关。
- 键盘数值回归 435 检查通过；`evidence/gamepad-keyboard-regression.log` 的 300 帧实际键盘事件回归通过，覆盖 Arrow/IJKL、Enter、物理 NumPad、W 与失焦清理。

最初参考脚本漏提取常量 Cz，补齐后运行；首次历史数组检查把 JSON 浮点数组与整数数组整体严格比较，改成逐项数值比较。未通过扩大容差绕过差异。

## 尚未验收

实机测试通过覆盖读取函数注入标准快照，未验证实体控制器、SDL 映射、热插拔设备选择或震动电机。震动请求记录只能证明事件和参数接线。完整控制器设置界面和原版菜单布局尚未还原；无整帧像素一致性结论。此阶段通过不代表整个游戏复刻完成。

## 操作说明补齐

核对原始标题模板 84183–84207 与 CSS 后确认，原版标题同时展示键鼠、Controller、Touch，不根据当前设备替换。原 `.m-legend` 在宽度至少 1180、高度至少 600 时显示。Godot 补齐三组标题提示与该可见性条件，修正 C 蹲伏及 Esc 暂停提示；布局仍为当前原生近似，不声称 CSS 像素一致。

控制面板按原 `sL/oL/rL` 补齐键鼠 12、手柄 10、触屏 8 行说明，滚动区域保留长表内容。近战仅列出原版绑定，没有因此新增未发现的近战玩法。触屏说明不代表触控实现已完成。原版 Settings/Controls 标签页与面板样式仍待迁移。

`tools/capture_controls.gd` 实际 GPU 运行并截图；`evidence/controls-capture.log` 正常退出，滚动内容高度 784。检查了 `controls-title.png` 与 `controls-controller.png`，标题可见且手柄行未横向截断；另保留 `controls-keyboard.png`、`controls-touch.png`。最终脚本断言 960×540 隐藏提示、恢复 1280×720 显示提示。

响应条件首次误用拉伸后逻辑画布尺寸，960×540 断言失败；改为实际 Window.size 后通过。目前按此桌面 DPR=1 环境验证，HiDPI CSS 尺寸对应关系尚未验收。失败测试直接退出导致清理期间大量 world 已离树日志，测试驱动已改为先显式清理；最终运行无此错误。
