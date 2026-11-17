# 警告与普通消息

原版依据：原 HTML `.h-warn` / `@keyframes warn` 第 78–81 行、`.h-msg` 第 119–121 行。原 bundle sT.warn/message 第 83775 行附近与 re() 第 84020 行提示计时逻辑。

## 实现

`announcements_hud.gd` 替代固定位置、固定字号的 Label。来袭警告置于屏幕 top=21%，Big Shoulders Display 700，字号 clamp(20px,3.6vw,38px)，大写、上下 1px 边线。复现 3.4 秒 linear 关键帧动画的闪烁和字距变化：0/8/14/20/82/100% 对应透明度 0/1/.35/1/1/0，字距最初由 .5em 收至 .24em。

普通消息置于 bottom=23%，使用 IBM Plex Mono 400/11px、行高 1.4、字距 .08em、大写和半透明底板，.3 秒 ease 淡入淡出。

分开 HUD 倒计时与 CSS 动画时钟：原 re() 在 HUD 隐藏后提前返回，警告和消息倒计时停止；CSS 动画仍继续。保留原版 duration<=0 不自动结束的行为。clear 会去掉警告状态，并清空消息内容，开始消息淡出。

## 证据

`warning_css_reference.cjs` 在由原始完整 stylesheet 构建的对照页内，暂停浏览器原 warn Animation 并采样 opacity、letterSpacing。14 点数据位于 `assets/export/fixtures/warning-css-reference.json`，原始 CLI 输出 `evidence/warning-css-browser-observed.txt`。

`announcement_timer_reference.cjs` 直接提取并执行原 warn/message 方法与计时块，生成 81 步 fixture，包含 HUD 隐藏、恢复、零/负/正时长及清空消息。`verify_announcements.gd` 共 352 项比较通过；CSS 数值最大差异 4.706e-5，门槛 1e-4，源于 computedStyle 小数输出舍入。报告 `evidence/announcements-verification.json`。

`verify_announcements_runtime.gd` 在实际 Main 运行 360 帧，触发警告和消息、暂停与恢复、断言提示确实活动并最终结束。`evidence/announcements-090.png` 已目视确认警告和消息同时可见。报告与干净日志为 `evidence/announcements-runtime.json/.log`。

780 帧完整预览流程完成于 playing，暂停冻结、三次重置、重试与重启通过，日志无错误；`evidence/announcements-flow.json/.log`。此运行发生在最后的“空消息淡出时保留仅含 padding 的小底板”微调之前；最终计时/CSS 对照已在微调后重跑，空底板的 GPU 像素尚未单独验证。

## 局限与失败记录

仍未证明字体栅格、边线抗锯齿、窄屏换行及所有 CSS 反向过渡细节的像素一致性。移动设备安全区未纳入本次桌面布局。

首次实机测试驱动误保留 Main.flow_preview=true，导致内置流程预览同时驱动菜单与淡出；虽原测试报通过，截图实际为黑场，不能作为集成证明。已保存 initial-invalid 记录，修正驱动并增加活动提示、playing 状态与非黑场淡出值断言后重跑通过。
