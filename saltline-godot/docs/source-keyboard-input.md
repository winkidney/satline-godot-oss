# 键盘动作与备用操作

## 原版依据

原 bundle 第 68169–68207 行 fE/hE/pE，第 68306–68323 行 v/y，以及第 68767–68771 行键盘转向。原 keydown 使用 KeyboardEvent.code；repeat 不重新激活动作，keyup 不检查文本目标。

## 修正

新增 `source_keyboard_input.gd`，保存键盘动作集合，替代主场景对物理按键的逐帧 OR 查询。31 个原物理绑定映射为 Godot keycode，保留多个别名共享动作的行为：同时按下 ArrowRight 和 L 只算 turnR 一次，松开任意一个会清除 turnR，即使另一个仍物理按住。Native 不自行改为引用计数。

恢复 Arrow/IJKL 转向，水平 2.1rad/s、垂直 2.1×.6rad/s；加入既有 mouse look 累积，随后统一经过 Player.look_normalized 的 ADS 缩放。键盘转向不套鼠标 sensitivity/invertY。

Enter 和小键盘 Enter 可射击；小键盘 1/2 可切武器。主场景动作使用 physical_keycode，缺失时才 fallback keycode，避免非QWERTY布局或 NumLock 改变逻辑键名。F12 原生截图快捷键继续保留，不把它伪造为原 fE 行为。

按键释放在 _input 阶段也清理，避免 GUI 吃掉 keyup 后留下动作；失焦清空键盘集合与 mouse look，对应原 blur/y。离开 intro/playing 的状态切换清空键盘动作，对应原 setGameplay(false)。文本/菜单焦点的完整浏览器行为仍不是本轮等价声明。

## 验证

`keyboard_reference.cjs` 直接执行原 fE、键盘部分 v/y 和键盘转向代码。`verify_keyboard.gd` 覆盖 31 绑定、101 操作、435 检查，全通过，最大误差 3.469e-18。包括 repeat、别名释放、clear 与 mouse+keyboard look 合成。fixture/report 分别为 `assets/export/fixtures/keyboard-reference.json` 和 `evidence/keyboard-verification.json`。

`verify_keyboard_runtime.gd` 300 帧实际 Main / Godot 输入分发：ArrowRight+L 及释放、ArrowDown+K、鼠标敏感度3和invertY=true时的键盘固定速率、Enter 产生7次步枪射击、小键盘2在逻辑Down下选择手枪、小键盘Enter射击、NumPad1换回步枪；物理W在逻辑Z下能移动；受控 focus-out 通知清空held/look。报告 `evidence/keyboard-runtime.json/.log`，无错误/告警。它不是实际硬件/操作系统焦点/所有键盘布局验收。

原 mouse gain/ADS/sign/wrap/spike/wheel 16 项检查继续通过。

## 范围和失败记录

首次运行把输入事件注入帧直接当成生效帧，导致第34帧预期偏差 .035rad；Godot实际在下一帧分发事件，第38帧的完整按住/释放区间结果正确。保留 initial-phase-failure.json，最终使用完整区间断言，不提前手动调用 Main handler 绕过输入分发。

仍需手柄、触屏、GUI焦点/菜单导航和真实OS输入验收；不能把物理键位字段的合成事件当成全部硬件键盘布局测试。原 fE 的 F/V melee 绑定已保留，但在已核对的原游戏内未见该动作的玩家近战消费，未新增原版不存在的近战玩法。

最终输入适配器接入后，正常 Main 的 1100 帧任务链再次通过：三处物理 E 切断、船只完成、结算与重新部署，14 项断言、日志无错误/告警。归档 `evidence/keyboard-full-mission.json/.log`。位置跳转与无敌条件保持，未将其扩大为人工通关证据。
