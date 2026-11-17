# 设置面板数值与焦点

依据原始 bundle-1.js 的 hT、x/w/S/R 与菜单 keydown：灵敏度输出保留两位小数和 ×，FOV 输出取整加 °；画质说明随 auto/手动选择改变，并提示难度只应用到新到达机器。原版面板接收打开时焦点，Tab 在面板内循环，Escape 关闭并恢复先前控件焦点。

Godot `game_ui.gd` 现为 sens/FOV 滑杆增加实时读数，将原画质/难度说明放在设置页底部。auto 文案保留原版，但当前初始高档仍是原生默认策略，不代表已经完成原版设备选档。

面板打开时用弱引用记录原控件，关闭时恢复有效且可见的控件，否则回到当前菜单主按钮。关闭面板不再重建暂停/结算卡片。Settings/Controls 切换保持原入口引用，切换后的页签恢复焦点。面板 Tab/ShiftTab 按当前可见按钮和滑杆顺序循环，Escape 消费事件以避免同时触发游戏暂停。

## 验证

- `tools/verify_panel_focus.gd` 实际 Main 50帧，通过 Input.parse_input_event 发送 Tab、ShiftTab、Escape，验证初始面板焦点、首尾循环、关闭、恢复标题 Settings 按钮及不触发其他状态。
- 同一脚本调用实际 pad_adjust/select 路径，确认灵敏度 1.10×、FOV 83° 的实时标签与画质说明。这部分不是物理滑杆拖动验收。
- `evidence/panel-focus.json` failures为空；`panel-focus.log` 正常。`settings-values.png` 为1280×720 GPU截图。首次截图与FOV更改同帧，读到了前一渲染帧78°；最终延迟两帧截图，未修改生产设置逻辑。
- `touch-menu.log` 的240帧实际触摸设置/标签切换/关闭/部署链通过。
- `panel-gamepad-regression.log` 的620帧手柄暂停/设置/返回/恢复链通过，包含原先武器及继电器操作。

用户明确不需要音效，因此没有移植音量滑杆。原版CSS样式、面板滚动与多尺寸适配、所有鼠标拖动与跨进程持久化、全屏文案及完整控制说明脚注仍待完成。此处证据只覆盖数值、焦点及列出的状态链，不代表整个游戏完成或像素一致。

## 配置加载与跨进程增量

原加载路径直接复制任意JSON字段，随后转换浮点或调用武器视图，会接受原版忽略的错误类型。现增加 `source_settings.gd`，按原版 iL 只接受有限数字、指定字符串枚举和严格数值视图，灵敏度/FOV按原限幅；invertY使用JavaScript真值语义，包括空数组和空对象为true。音量按任务范围排除。损坏JSON返回默认值且不输出解析错误。

`settings_reference.cjs` 抽取原 tL/cT/uT/ab/fT 与 iL 实际执行，31输入、217检查通过，覆盖无文件等价null、损坏JSON、错误类型、限幅、枚举与反转值。证据 `settings-verification.json`，方法哈希 `ed0b45700dad54eaf02dc81a42f03ab22ebd6304b1ea0a864e76ed892552a8cd`。首次实现用Godot数组成员检查数值视图，因JSON浮点与整数数组类型区别导致9项失败；改为数值相等比较后全部通过，仍拒绝字符串和布尔视图。

`verify_settings_roundtrip.gd` 通过 Main 的 `_settings_path` 可覆盖入口使用独立证据文件，默认用户路径不变。write进程调用实际 `_select` 保存 low/1.85/true/87/brutal/holdout/3；read新进程逐项恢复，并验证渲染画质low、模式holdout、难度brutal、武器视图3及玩家base_fov87。write PID3875122，首次read PID3875267，最终read见报告；进程均正常退出。另一个invalid启动用独立错误类型文件验证原版回退与空数组invertY真值。`settings-roundtrip-write/read/invalid.json` 和对应日志记录此证据。

跨进程文件恢复已验收，尚未证明所有实体鼠标/触摸滑杆操作后持久化、写入失败时的提示或任意操作系统权限环境。测试没有写入 `user://saltline-settings.json`。

## 右侧抽屉与窗口尺寸

原 `.panel` CSS 是右侧全高、width:min(440px,100vw)，页头独立、内容 overflow-y:auto。现替换先前居中600宽固定面板，采用右侧抽屉和独立ScrollContainer内容，页头不滚动，设置行改为标签在上、选择在下。控件获得焦点时滚动到可见区域。Controls内容按原顺序 Keyboard/Touch/Controller 展示。文字、边框、间距等仍有原生近似，不声称逐像素一致。

通过逻辑画布与窗口比例抵消面板缩放，保持原生窗口中的440像素宽。字体使用仅面板范围的复制FontFile并固定oversampling=1，避免低分辨率窗口先把字形缩成低像素后再放大。没有修改全局字体资源。

首次尺寸测试只将逻辑边界乘以窗口比例，忽略竖屏默认16:9黑边，虽断言通过，实际320×568窗口仅捕获320×180。此轮证据无效，保留 `panel-sizes-invalid-initial.log`。已将项目 stretch/aspect 改为expand，并增加实际Image尺寸必须等于窗口尺寸的断言。最终 `panel-sizes.json/.log` 四种尺寸1280×720、960×540、640×360、320×568均通过，竖屏逻辑画布为1280×2272，实际图像320×568。

最终抽屉边界分别为[x840,w440,h720]、[x520,w440,h540]、[x200,w440,h360]、[x0,w320,h568]。短窗口聚焦Fullscreen后自动滚动106/286/78像素。截图 `settings-1280x720.png`、`settings-960x540.png`、`settings-640x360.png`、`settings-320x568.png`；后两张已查看。修正字体前竖屏文字明显模糊，修正后可读。

尺寸测试每次改变窗口后重新打开面板；打开期间实时改宽还未证明行布局与焦点保持。HiDPI、实体滚动手势、所有HUD与标题的窄屏/竖屏适配仍待完成。项目expand宽高比改动只证明了上述捕获尺寸，不代表全部渲染/HUD已经完成跨宽高比验收。

最终抽屉与expand配置下，240帧实际触摸Settings/双向标签/Close/Deploy链及1100帧三目标/撤离/结算/重新部署回归均通过。证据为 `touch-menu.log` 和 `panel-mission-regression.log`，完整任务仍使用受控位置与无敌。
