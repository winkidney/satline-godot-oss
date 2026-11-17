# 触屏输入

原版依据是 `artifact-rendering-study/source/extracted/bundle-1.js` 中 `gE` 的 J/G/te/oe 和 touchstart/touchmove/touchend/touchcancel，以及 he 的输入合并。源文件 SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

## 行为

`source_touch_input.gd` 保留双精度数组。左侧 45% 范围的首指成为摇杆，原点固定、半径 58、圆形限幅。已有左指时下一指可成为视角指。右侧拖动视角倍率为 0.0052，应用灵敏度和反转。摇杆长度严格大于 0.93 且前向分量大于 0.8 时冲刺。

FIRE 持有射击并可拖动瞄准，释放必须匹配开火指。AIM 为切换状态，释放不关闭；暂停/失焦清除。RLD/SWAP/JUMP/USE/II 对应原动作。Main 接入原生 ScreenTouch 和 ScreenDrag，独立保存手指拥有的按钮，合并键盘、手柄及触摸移动后再限幅。

`touch_overlay.gd` 按原 CSS 放置 86/60/54/68/42 尺寸按钮和 58/24 半径摇杆，USE 仅在交互提示激活时出现。弹药移至上方，主数字改为 44。当前坐标为逻辑画布单位，尚未完成全部响应式布局或安全区域映射。

触摸会被 Godot 转为模拟鼠标事件。首次运行虽通过操作断言，却出现 NO GRAB 与额外开火；800ms 原版鼠标抑制不能完全处理原生事件投递顺序。现在排除 Godot device=-1 模拟鼠标的游戏操作路径，同时按已接受的实际鼠标按下/释放维护动作集合，避免读取模拟鼠标全局状态。菜单保留 Godot GUI 的触摸/模拟鼠标处理，未将全局模拟功能关闭。真实鼠标在触屏事件后 800ms 的抑制仍保留。

## 验证

`tools/touch_reference.cjs` 直接执行完整原版 fE 常量段和 gE 函数，以最小 DOM、navigator 和事件派发器驱动原来的触摸事件回调。并非另写一份触摸参考公式。`tools/verify_touch.gd` 对 73 操作进行 438 检查，最大误差 2.57e-16，失败为空。方法哈希 `77afaf29728ae8ab9e998cbc79bff53d99b9be2b51faaa5dba688100c4cd4ffc`，见 `evidence/touch-verification.json`。

`tools/verify_touch_runtime.gd` 通过 Input.parse_input_event 注入真实 Godot 事件，在实际 Main 中运行 250 帧。同时移动/转向、自动冲刺、AIM 切换、FIRE 持有/拖动/释放、切枪、暂停/清理/隐藏/恢复通过，12 次射击。额外断言移动时零射击，以及释放后停止射击。最终日志 `evidence/touch-runtime.log` 无 NO GRAB 或脚本错误，报告 `touch-runtime.json`，截图 `touch-runtime.png`。这次运行以受控事件代替实体触摸屏。

## 未完成

接入后的键盘300帧事件链及手柄620帧部署/射击/继电器/菜单链均通过，日志保存在 `evidence/touch-keyboard-regression.log` 和 `touch-gamepad-regression.log`。独立非游戏预览路径仍读取物理鼠标状态；新鼠标动作集合仅用于游戏模式。

真实设备、USE 三目标完整任务尚未逐项实机验收。按钮文字追踪、摇杆淡入淡出、安全区域和 HiDPI/不同屏幕尺寸的 CSS 等价布局未验证。触摸核心及当前状态测试通过不代表完整触控或整个游戏复刻完成。

## 触屏 HUD 与 GUI 增量

按原 `.is-touch` CSS 移动生命值到 top128、电台到 top27%、击杀消息到 top150，并将罗盘宽度设为 min300、屏宽减152。弹药恢复原 44 字号、2×7 弹药格及6/5外边距，备用武器行去除 Q，空弹匣提示使用不带键位的 Reload。触屏交互提示使用 USE。字号基线由原生字体度量近似，尚无 CSS 字形逐像素匹配证明。

`verify_touch_runtime.gd` 扩展为480帧，在既有操作链上验证 JUMP 实际离地、USE 提示、长按 USE 完成一处继电器，并检查300宽罗盘及电台触屏模式。`touch-runtime.json` 的 cut=1、failures为空；GPU截图 `touch-runtime.png` 与 `touch-interaction.png` 已查看，底部按钮与弹药不再重叠。受控伤血/击杀/电台内容用于显示全部HUD。备用武器与击杀行出现重叠，原CSS的 top150 与弹药内容范围同样交叉；需原浏览器配对画面确认，不视为已证明一致。

`verify_touch_menu.gd` 通过 Input.parse_input_event 注入触摸，保留 Godot GUI 的模拟鼠标转换，在240帧内实际点击标题 Settings、Close、Deploy 后进入 playing，且没有射击泄漏。见 `touch-menu.json`、`touch-menu.log`。未覆盖所有滑杆、标签页或实体触摸屏。

布局改动后，原版状态HUD的800场景/9600比较、电台队列720帧/5760比较仍通过；它们证明状态行为，不能证明布局像素一致。

## 换弹、取消与标签页增量

触屏运行脚本扩展到760帧。切回已消耗弹药的步枪后，通过RLD按钮启动换弹，检查换弹结束、弹匣装满及备弹精确扣除。报告 `reload_checks` 的 started/completed/reserve 均为 true。随后同时持有摇杆、视角及FIRE三指，分别派发 canceled=true 的释放事件，验证三个拥有者、FIRE持有状态和按钮手指标记全部清除。最终 cut=1、shots=14、failures为空，日志正常。此处取消事件是原生事件注入，未证明操作系统手势取消的设备投递方式。

设置面板新增原版同时可见的 Settings/Controls 页签，可从标题 Settings 进入操作表。240帧触摸菜单测试新增双向页签切换断言，通过后仍可关闭、部署并进入playing，且没有射击泄漏。原版面板样式、页签焦点语义、滚动位置保留和所有设置项尚未完整还原。

## 2026-11-16：触摸生命周期不捕获鼠标

Astra Ultra 复核发现真实 capture_mouse 回调没有排除触摸模式。原 bundle 68420 的 requestLock 在 touch 时直接返回；85291 的暂停提示在 touch 时为空，原 HTML 285 的空 m-line 保留 1px 最小高度。旧触摸驱动断开 capture_mouse，无法证明这个生命周期行为。

Main 的状态捕获回调及鼠标点击捕获路径现均排除 source_touch_input.enabled。GameUI 持有实际触摸输入引用，暂停卡使用空提示和 1px 高度；桌面提示及 16.5px 行高保留。没有改状态机、触摸动作或鼠标转向公式。

新增 verify_touch_capture.gd 保留唯一真实生产回调，九个状态快照覆盖首次原生触摸、Deploy、Pause、Resume、Retry、触摸模式下实体鼠标点击及桌面对照，退出 0、failures 为空。触摸模式全部 mouse_mode=0，桌面 Deploy/Resume/Retry 为 2、Pause 为 0。报告 touch-capture-verification.json，实际暂停截图 touch-capture-paused.png。截图采集已等首帧，早期未等待呈现的空图已被有效采集替换。

原 verify_touch_runtime.gd 已去掉断开生产回调的代码。最终单窗口 760 帧回归退出 0：cut=1、shots=14、RLD started/completed/reserve 均 true，三指取消通过。首轮与另一个 GPU 窗口并行，失焦后停在 paused 导致换弹未完成；该失败保留 touch-capture-regression-focus-failure.json，未改变生产失焦暂停行为。桌面/窄屏 16 个卡片场景与 3 个滚动案例另行回归退出 0。最终三次日志无 ERROR/WARNING。

此修正已纳入 r16。包内真实捕获回调九个状态和主入口加载两次实机均退出 0，日志无 ERROR/WARNING；5,566 文件、3,074,723,888 字节及 SHA 校验一致，见 runtime-bundle-r16-verification.json。未连接实体触摸屏，不证明设备级手势投递或 HiDPI。
