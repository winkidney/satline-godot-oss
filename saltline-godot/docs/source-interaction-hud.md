# 继电器交互提示

原版依据：原 HTML `.h-prompt`、`.h-key`、`.h-plabel` 第 103–112 行；原 bundle 第 83549 行 SVG 构造、sT.setPrompt 第 83743 行及任务 ge() 第 85490–85519 行。

## 修正

新增 `scripts/interaction_hud.gd`。提示改为订阅实际 Mission.prompt_changed，替代每个 HUD 帧重新查询最近继电器；隐藏时保留内容和状态以完成 .15 秒 ease 淡出。HUD reset 显式取消提示，dispose 断开信号。

恢复 48px SVG 布局、12px 间隔、label 的 2px 左边线及 7px/6px 上下内边距。整个提示按原文实际宽度居中，修正原先遗漏的边线宽度和文字起点。E 使用 Big Shoulders Display 700/19px、48px 行高；正文使用 Barlow Condensed 600/16px、.14em 字距。

保留原版 progress 每 1/200 取整，以及 stroke-dasharray=119.38、stroke-dashoffset 两位小数。进度环按该弧长绘制，而非直接将比例乘整圆。支持 E、X、USE 的原显示规格；生产交互当前仍走键盘输入，未因此宣称已实现完整手柄或触屏输入。

## 验证

`interaction_reference.cjs` 直接提取原 setPrompt 方法，以受控 DOM/输入适配器执行 29 步，覆盖 keyboard/pad/touch 标签、量化边界、空提示、隐藏时内容保留。`verify_interaction.gd` 203 项通过。fixture 与报告分别为 `assets/export/fixtures/interaction-reference.json`、`evidence/interaction-verification.json`。

`verify_interaction_runtime.gd` 使用实际 Main、实际 Godot E 键事件，在继电器 A 附近运行 360 帧：第 30 帧显示；第 100 帧进度 .38、offset 74.02；第 180 帧 .935、offset 7.76；第 330 帧实际 cut=1，active=false、alpha=0。`evidence/interaction-runtime.json/.log`，无脚本错误和绘制告警；`evidence/interaction-100.png` 已目视检查。

既有 ammo/health 800 例 9600 项，以及 Mission 482543 项原版比较均通过。本次不改变这些状态算法。

## 失败与局限

首次驱动使用 _game_tick 的 interact override，但该开关仅在 flow_preview 下读取，实际正常模式没有收到 E，进度始终 0，测试明确失败并留存 initial-failure.json。改用 Input.parse_input_event 的 physical_keycode E 后通过。实际切断后又暴露 ObjectiveHud 已填充方框的 draw_rect width 参数告警，已改为分别绘制填充与描边，最终日志干净。

未证明 CSS glyph raster、环形描边、阴影和 opacity 反向过渡的严格像素一致性；未验证手柄/触屏硬件输入、从出生点步行到目标的全程可达性。当前绘制弧长限制在一圈内，原版 API 若收到任务路径之外的异常 progress 并不在本轮验证范围。

最终 780 帧游戏流程回归通过：暂停冻结，死亡、重试与重启，三次重置后结束于 playing，日志无错误与告警。归档 `evidence/interaction-flow.json/.log`。实际切断后的 `evidence/interaction-330.png` 已目视确认面板打开、1/3 计数、接敌警告和后续无线电信息。
