# 实现状态与完整范围

## 2026-11-16：r14 独立运行包及启动界面缺口

新建 `output/linux-runtime-20261116-r14`，5,563个原manifest文件、3,074,713,094 bytes；固定引擎已更新为Portal缓存接线版本，SHA `639baccce7c7c63638da889fba58b3797316b09be1df9da0bd49c839af1a5788`。纳入卡片响应式/滚动、标题按钮生命周期、减少动态策略及Linux实际系统查询；r13及以前不覆盖。

从 `/tmp`、隔离XDG三次实际NVIDIA GPU启动，生产模块/资产/引擎来自包内：16卡片情况、实时resize/滚动/标题settings/resume动作；56动画双态及实际主机Portal值0；正常Standard从出生点自动行走射击、三点切断、撤离及延迟结算，1457ticks、60shots/31hits/13kills、protected_live_frames0。三个最终进程均终端0、日志清洁，全部5,563原文件运行后再验大小与SHA无差异。见 `evidence/runtime-bundle-r14-verification.json`。驱动只读且在源码tools目录，普通运行不依赖这些驱动。

Astra Ultra 后续审计确认原HTML `#boot` 加载界面仍未复刻：HTML29–35/372在JS之前显示深色底、SALTLINE、阶段标签、橙色进度条；bundle85794的fa使用预设阶段权重而非实测百分比，Main为4/12/34/50/58/66/74/82/92/100。render.onLevelReady在Ready前预备环境和编译；85966–85970在Ready后0.6s ease淡出、700ms隐藏，淡出期间游戏已运行。Native当前project直入main.tscn，Main同步加载资产，默认静态引擎启动图不能替代此视觉。下一步须补轻量Boot层与真实加载里程碑让帧，保留现有同步Main/runner测试契约；不能用计时器伪造生成百分比或在内部Main完成时让展示场景过早Ready。此项明确未完成，r14仍是阶段性交付。

## 2026-11-16：Linux Portal 减少动画系统查询闭环

已补齐上一轮本机API返回-1的缺口。复用隔离Godot已有FreeDesktopPortalDesktop：构造时在订阅后读取一次标准 `org.freedesktop.appearance/reduced-motion`，SafeNumeric<int>缓存初始-1；现有监听线程直接解析SettingChanged的一层variant→uint32更新缓存，不新增线程或重新查询。合法uint仅1映射减少动画，其它归0；读取失败/类型不符保留-1，无效变化通知不覆盖已有值。X11和Wayland方法委托缓存，无Portal或DBus支持则-1。旧Read的双层variant读取器保留，未迁移ReadOne或改变原颜色读取。

34文件合并补丁已从固定原archive逐文件应用并核对全部SHA；原28文件渲染补丁保持，新增6平台文件。增量构建退出0，实际80338024-byte二进制SHA `639baccce7c7c63638da889fba58b3797316b09be1df9da0bd49c839af1a5788`。系统引擎未改，旧引擎和metadata另存，r13及以前包保持原样。构建输出有既有可选accesskit依赖与pip缓存提示，未安装额外依赖；不将构建日志称为无警告。

私有D-Bus会话三组实际X11检查全部终端0：初值0、1、缺键-1，通知1→0、未知uint17→0、错误类型与无关键不覆盖；18000次getter加通知始终只发生一次目标Read。初值0组还加载实际Main，启动读到减少状态，再经真实通知0/1和GameUI.update_frame自动切策略，无策略边界注入。测试mock只在私有总线拥有名称，未写主机偏好；初次私有总线曾尝试启动不存在的辅助服务产生daemon诊断，最终fixture阻止该无关启动，Godot日志清洁。

真实桌面Portal与新引擎API均返回当前值0，原56项效果/例外/生命周期验证再次通过；原生Main反射8生命周期和73帧重入回归通过，最终进程均0、Godot日志无ERROR/WARNING。见 `evidence/portal-motion-engine-provenance.json` 和 `engine/reduced-motion-patch-verification.json`。仅X11实测，Wayland源委托包含但当前构建仍wayland=no，不能声称Wayland验证通过。新引擎与卡片/动画源码尚未合入下一运行包，r13仍为历史阶段包。

## 2026-11-16：减少动态效果策略及当前 Linux 查询缺口

新增小型共享motion_preference，GameUI启动及每帧读取 `DisplayServer.accessibility_should_reduce_animation()`，仅返回1启用减少动态效果，0/-1保持正常。CSS timing在retarget时捕获有效时长`.00001s`，不在progress里缩短正在运行的过渡；原CSS Chrome动态切换实测500ms运行过渡保持500ms，新反向过渡才用`.01ms × reversal factor`。HUD根opacity明确豁免，panel_toggle的滑块motion和colors也豁免，因为原`.menu *`不匹配`::after`。未改全局dt或共用bezier。

手工绘制路径同步：波次告警保持alpha1和.24em，缺弹提示停止闪烁，地点步进揭幕和目标边框按缩短时长到终值；击杀提示在out开始时捕获fade_duration，系统偏好后来切换不改运行中的淡出。命中WAAPI反馈、伤害方向弧、JS打字和提示寿命保持原规则。原CSS还排除了触摸摇杆和启动进度条的伪元素/外部路径，本轮未给这些添加额外缩短行为。

原CSS Chrome双态、动态切换及实际Main平台接线/生产组件GPU共56检查通过，含真正缺弹文字绘制alpha、目标边框GPU颜色、开关伪元素/HUD根例外、提示寿命及未改变的打字/命中反馈。当前Linux平台实测返回-1，减少分支只在策略输入边界注入1验证，未宣称OS实际返回过1。正常模式相关8进程回归均终端0且日志清洁，覆盖颜色/opacity反向、按钮、开关、地点、导航、战斗反馈和无线电；见 `evidence/motion-preference-provenance.json`。

仍有明确的平台接线工作：当前主机的标准只读Portal `ReadOne(org.freedesktop.appearance,reduced-motion)` 实测返回uint32 0，而固定引擎API仍返回-1。该键的0/1语义与SettingChanged信号见[官方Settings接口](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Settings.html)。已确认引擎已有FreeDesktopPortalDesktop读取/监听设施，下一轮应复用并缓存结果，避免新增CLI依赖或每帧同步D-Bus。当前没有修改桌面偏好，也没有把gdbus加入运行依赖；本机自动跟随系统偏好尚未补齐。源码晚于r13，未打新包。

## 2026-11-16：响应式结果卡片与标题按钮生命周期

已修复 r13 的窄屏卡片裁切。暂停/死亡/结算卡片现按原 `min(430px,100vw-32px)` 限宽、`100vh-24px` 限高，使用现有 ScrollContainer 焦点跟随方式，另用共享 Range 的叠加滚动条保留原卡片内容宽度。窄屏和短屏分别应用原 padding、按钮高度/间距、统计行28/34高度、rating34/46字号；标题保留原clamp的浮点字号，例如360px debrief为30.96px，短屏暂停39.6px。文本按已有title的ceil栅格+比例绘制方法处理，不截断为整数。处理了heading底部与rating顶部margin折叠，以及Mission死亡页因后续hidden行而没有:last-child底边的原语义。

实机连续切换还暴露旧的共享引用错误：暂停页Settings/Controls覆盖`buttons`字典后，TitleLayout把暂停按钮当标题按钮移动，替换卡片后又访问已释放对象。TitleLayout现保留自己三个按钮的直接引用；返回title时恢复活动按钮字典映射。没有改按钮的动作或颜色处理。初次失败日志保留 `evidence/card-layout-initial-failure.log`；原CSS采集器初次漏data-mode也已纠正，不将错误夹具作为产品尺寸依据。

最终实际Main/GameUI GPU检查原DOM/CSS16情况：1280×720、360×720、640×360、640×240各覆盖暂停、Mission死亡、Holdout死亡、结算。外框最大误差0.025635px，字号和按钮宽高均通过；3个真实溢出场景所有按钮可通过焦点滚动到达。另覆盖同一卡片在三窗口实时缩放、回宽屏后滚动归零、返回标题后打开设置、实际Resume信号恢复playing。结果按钮6动作hover回归、标题128选择区字段回归均通过。三最终进程均终端0、日志无ERROR/WARNING，已查看360px结算与240px高的滚动暂停截图。见 `evidence/card-layout-provenance.json`、`card-layout-verification.json`。源码晚于r13，尚未打包；系统减少动画偏好仍明确未接入，本轮不是全项目完成验收。

## 2026-11-16：r13 独立包及下一轮明确缺口

新建 `output/linux-runtime-20261116-r13`，不覆盖 r12。5,560 个原 manifest 文件、3,074,684,433 bytes，固定引擎 SHA 仍为 `bb476c9fd4cbf588904f38de2633b58cf962c3e30225dca8f009bf414bf1e70e`。纳入背景展示两条原标签 mip、生产 stretch disabled、字幕 inline clone 和目标栏/罗盘/弹药/生命窄屏规则。与 r12 比较9个文件改变、4个新增、无删除。

从 `/tmp` 和隔离 XDG 四次实际 NVIDIA GPU 启动，生产资源全部从包内解析：8种响应式HUD与真正GameUI截图、10种字幕布局、包内文档规定的背景展示入口及两条标签GPU全mip SHA、正常Standard从出生点自动行走射击通关均通过。Mission 1457ticks、60shots/31hits/13kills、3中继切断/撤离/延迟结算，protected_live_frames=0，测试专用seed4207及焦点恢复1次，生产规则不改。四个最终进程均终端0、日志清洁；运行后全部5,560原文件大小/SHA再验无差异。见 `evidence/runtime-bundle-r13-verification.json`。初次背景命令误用了原HTML URL风格的 `--show` 参数，已定位终止该测试进程，再用README规定的 `--script scripts/level_showcase_runner.gd -- --game --showcase=backdrop` 验证通过；未将错误参数导致的停留归为生产故障。

Astra Ultra 后续只读审计又确认两个真实未完成项：暂停/死亡/结算卡片的 `custom_minimum_size.x=430` 与缺少滚动容器会在360px窗口裁切；原CSS有视口宽度约束、最大高度及overflow:auto，须优先修复。其次原HTML减少动画媒体查询尚未接系统偏好，Godot已有对应平台查询，不能简单停用全部HUD逻辑动画。pointer coarse本身不是原作媒体规则，首次touchstart启用触摸的当前语义无须据此重做。r13仍是阶段性交付，不宣称全项目完成。

## 2026-11-16：目标栏、罗盘读数、弹药与生命区窄屏规则

已落实上一轮明确的窄屏差异。ObjectiveHud 在 ≤760px 使用顶部78、17px/.05em、1.1行高和62vw最大宽，保留原22px最小标题高度；宽屏仍顶部16、20px与min(300px,42vw)。绘制时更新位置，不改变可在未挂树状态调用的文字动画接口。NavigationHud 仅在 >760px 绘制单独的 heading 读数，罗盘刻度和标记仍显示。

StatusHud 窄屏桌面弹药为56px，宽屏76px，字距均.01em；缩短弹药行后提示行按原CSS相对移动16px。触摸模式的更高特异性保留44px，窄屏弹药组整体比宽屏触摸下移14px，生命组下移22px，对应原top64→78、128→150；pip、备用武器和生命条同步移动。未重排宽屏固定布局。

新增原CSS真实Chrome参考和生产HUD绘制观察，360/760/761/1280四宽×桌面/触摸8情况全部通过：目标栏top、字号/字距、实际换行、relay行top、heading显隐、弹药字号及断点位移。实际Main mission/weapon与生产stretch配置参与检查；随后移除所有观察控件，运行实际Main/GameUI并捕获 `evidence/responsive-hud-main-360-touch.png`，已目视检查。最终GPU终端退出0、日志清洁。最初观察控件在post层下方导致截图无HUD，最终fixture移至UI上层并另取真正GameUI截图，未改生产合成顺序。

相关回归为目标栏重置12项、原文字动画260项、状态HUD9600字段及导航过渡120字段，全部退出0且日志清洁。证据见 `evidence/responsive-hud-provenance.json`、`responsive-hud-verification.json`。本轮证明这些明确的原CSS规则，不是所有文本/整图像素或HiDPI验收；源码更新晚于r12，尚未打包。

## 2026-11-16：字幕 inline clone 换行边界完成

上节记录的 360px 残差已修复。Astra Ultra 的真实 Chrome probe 以 0/8/16px padding 对比中间软换行片段与最终片段，确认每行仅左 padding 参与中途换行预算，span 最终词才同时预留右 padding；背景仍在每个片段绘制双侧 padding。原 328px 容器中第二行文字约 312.51px，背景约 328.51px，可以溢出父框并从父框起点对齐。这不是末尾字距、尾空格或可通过放宽字体误差门槛解决的问题。

RadioHud 的 `lines_for` 现在接收完整容器宽度，按是否最终词扣 8/16px；绘制仍加双侧 8px，溢出行按父框起点对齐。未更改字体度量或提高阈值。原 Chrome CSS 参考增加“相同短语恰为 span 结尾”的边界样本，防止把所有行统一放宽。实际原生 GPU 在 360/760/761/1280 四宽、桌面/触摸及最终片段边界共 10 情况逐条对比，字号、字距、行高和文本行完全对应；最终终端退出 0、日志清洁。已查看 360px 触摸布局实际截图，见 `evidence/radio-layout-provenance.json`、`radio-layout-verification.json`。旧失败 `radio-layout-wrap-residual.json` 保留，不再作为当前状态。

窗口生产配置仍为 stretch disabled，上一轮三窗口坐标/渲染目标及标题、面板检查的配置未再改动。剩余窄屏源码审计已明确：objective_hud 仍固定 20px / 300px或42vw / 顶部16px，而原 ≤760 应17px / 62vw / 顶部78px；navigation_hud 仍绘制原应隐藏的 heading；status_hud 桌面弹药仍76px而原窄屏56px，触摸 top78/health150 也尚需核对。触摸弹药44px由更高特异性的 `.is-touch .h-ammo-n` 保留，不能误改为56px。这些是下一步明确未完成项；本轮不宣称全部窄屏或 HiDPI 已完成。源码更新仍晚于 r12，未打新包。

## 2026-11-16：窗口坐标根修复及字幕窄屏排版审计

Astra Ultra 发现原 HTML ≤760px 的 `.comms-t` 字号应为 17px，Godot 先前固定 19px。RadioHud 现按视口宽度选择 17/19，并同步 `.02em` 字距、1.3 行高、换行测量和底板高度。新增 Chrome 原 CSS/原字体参考和实际绘制回调检查，覆盖 360/760/761/1280 宽、桌面/触摸两种布局。

实际 GPU 首轮进一步证明生产 `canvas_items` 把小窗口继续映射到至少 1280 逻辑宽，字幕断点无法触发；既有若干 resize 检查曾在 fixture 中主动关闭缩放，不能替代生产默认行为。根修为 `project.godot` 的 stretch mode 改为 disabled，保留初始 1280×720。顾问核对本地引擎 `window.cpp:1328–1330/1407–1410`、`viewport.cpp:1467–1480` 和 `input_event.cpp:992`，原固定逻辑画布也会反向缩放鼠标 relative；标题和面板已有 logical/window 补偿在新配置下自然为 1，不需要拆除。

实际 Main 生产配置、不在 fixture 改 content_scale，1280×720、640×360、360×720 三种窗口的逻辑视口和渲染尺寸与窗口一致；经 `root.push_input(event,false)` 的同一物理鼠标 10/-5px 都产生 .021/-.0105 look，摇杆 29/58px 拖动始终为 .5/1。进程退出 0、日志清洁。标题既有四窗口回归 128 个选择区字段最大 .018738px、面板四窗口边界/滚动检查均通过，两个终端退出 0、日志清洁。证据见 `evidence/window-coordinate-provenance.json`。

仍明确未通过：360px 的字幕第二行在原浏览器含末尾 `of`，当前原生把它换到第三行；桌面/触摸各有一个失败，保留 `radio-layout-wrap-residual.json`。各尺寸实际字号、字距、行高均已匹配，760/761/1280 换行通过；不能将 360 残差略去后宣称全部字幕通过。尚需核清内联 clone 底板与字体度量的换行边界，并继续审计其它 HUD 窄屏规则及 HiDPI。当前源码晚于 r12，未重新打包。

## 2026-11-16：背景展示标签贴图身份修复

背景展示原先通过材质名、UV 和顶点数复用 Main 的标签材质，不能证明标签图像相同。新增既有 Playwright 原作采集器的 `--labels-only` 只读分支，保存实际 CanvasTexture 像素、wrap/repeat/offset/colorSpace 和 WebGL GPU 全 mip 链。原作 all 展示两块标签为 720×128、636×128，而原生先前复用 Main 的 491×128、467×128 图像；文字相同但笔画拉伸和磨损图案不同。新采样 position 哈希与此前保存的两块独立展示几何完全相同，排除匹配了别的几何。未推断字体初始化历史的原因，也未修改 Main 原纹理。

`build_backdrop_showcase_bindings.py` 现以 position 哈希验证标签身份，检查采样变换及 mip 文件 SHA，将两条源 GPU mip 链去重保存在 `assets/export/showcase/backdrop-labels/`，在对应 extra 中写入标签纹理记录。runner 沿用原 ShaderMaterial 和所有其它参数，仅复制展示材质并替换 albedo_tex；通过现有 IBL/灯光通路处理，不重写标签 shader。

实际 NVIDIA GPU 对 all/crane/ship 三入口分别运行，2/1/1 块标签的 Godot GPU 全 mip 回读 SHA 与源链逐条一致，各有 9 个额外 mip。三次最终进程退出 0、日志无 ERROR/WARNING；34/16/12 网格和 20/9/7 caster 检查保持通过，已查看实际 all 截图。初次命令缺少 `--game` 导致 Main 未初始化 game_flow，已定位停止该测试进程，补齐检查参数后验证；不作为生产缺陷修复。见 `evidence/backdrop-label-texture-verification.json` 及 `backdrop-label-fixed-*.png`。此更新晚于 r12，尚未打包，不代表整图像素或所有纹理已验收。

## 2026-11-16：r12 独立运行包

新建 `output/linux-runtime-20261116-r12`，不覆盖 r11。5,556 个原 manifest 文件，3,073,741,933 bytes，固定引擎 SHA 保持 `bb476c9fd4cbf588904f38de2633b58cf962c3e30225dca8f009bf414bf1e70e`。与 r11 的逐文件清单比较仅 `scripts/main.gd` 改变，纳入落海获救提示。

从 `/tmp` 和隔离 XDG 两次实际 NVIDIA GPU 启动，外部只读检查驱动加载的全部生产模块与资产来自包内 `res://`。落海获救 playing/title/致死三情况通过；正常标准难度 Holdout 清完两波，1999 ticks、164 shots、16 kills、实际受伤后补给恢复、无无敌或直接伤害。两个进程均终端退出 0，无 ERROR/WARNING。运行后全部原 manifest 文件重新核对大小与 SHA，差异为空。见 `evidence/runtime-bundle-r12-verification.json`；README 最新入口已指向 r12。此次未重跑 Mission 全通关，上一包的通关属于历史独立证据；本包不据此宣称全效果或全部波次已验收。

## 2026-11-16：正常 Holdout 战斗与落海提示

新增 `tools/verify_holdout_survival.gd`，实际 Main 标准难度从原出生点自动导航、瞄准与正常射击，不用无敌、传送、直接伤害或直接推进波次。1999 个 1/30 秒模拟 tick 清完前两波 7+9 个敌人，164 发射击、36 次命中、16 击杀，移动 109.8367 米；三次实际受伤后由原波次补给恢复至 100 HP，protected_frames=0。最终受控焦点恢复 1 次，生产暂停规则不改。实际 NVIDIA 进程退出 0、日志无 ERROR/WARNING；末尾停止模拟后补 60 次渲染更新再截图，使 UI 过渡完成。见 `evidence/holdout-survival.json`、`holdout-survival-provenance.json` 和 `holdout-survival.png`。这是正常战斗链路证据，不是人工平衡、全波次或实时性能验收。

Astra Ultra 对照原作发现 `bundle-1.js:85478–85479` 的 `player:rescued` 提示遗漏。Main 现有 `_player_motion_effects` 桥接增加一行，仅 `rescued` 且 `mission.state==playing` 时发出既有 `mission.message`，显示原文 `Hauled out of the water` 2.5 秒，复用 GameUI announcement，不新增 UI 或信号。实际 player.update 和原碰撞触发三次救援：100 HP playing 扣至 88 并显示；title 扣至 88 无提示；8 HP playing 先死至 0 再发救援事件，保持无提示。三项通过，终端退出 0、日志清洁，见 `evidence/rescue-message-verification.json` 和 provenance。初次测试误置于陆地下方，被地面碰撞纠正，最终改为原海域 x32 后验证；未改生产碰撞规则。该源码修复晚于 r11，历史运行包不覆盖。

2026-11-16 共享灯池与重试联合验证：实际 Main 场景在 NVIDIA Forward+ 上连续执行 8 次 session reset，每次填满 5 个火焰持久灯槽，验证扫描灯槽位和灯对象身份保留、重试释放火焰持久灯、20 次饱和临时闪光不能覆盖扫描灯、临时灯到期以及最终 dispose 释放扫描灯。98 项检查通过，进程退出 0，无生产代码修改。原作 `bundle-1.js:83313–83319` 的 enemy clear 同样保留扫描灯句柄并将亮度置零。证据见 `evidence/session-light-lifecycle-verification.json`、`evidence/session-light-lifecycle-provenance.json`，检查入口为 `tools/verify_session_light_lifecycle.gd`。此检查不证明全部画面的视觉一致性，也未重新打包 r11。

此清单用于防止将原生资产预览误判为完整复刻。所有未验证项均保持未完成。上部表格保留早期审计基线；后续实现、证据与尚存限制以末尾增量和链接的专项记录为准，不能将表中旧缺口直接当成当前状态。每项验证仅覆盖其注明范围。

| 范围 | 当前证据或缺口 |
|---|---|
| 原作活动版本与资产来源 | 原始HTML和活动脚本已保存并校验；旧版legacy-v8不参与主实现 |
| 主场景层级与网格 | 导出729节点、276源几何、195材质、132纹理；运行时292网格组合 |
| 完整资产目录 | 主场景及隐藏敌人池已导出；36类注册道具和全部48种材质的未使用变体仍须补齐审核 |
| 原生蒙皮 | 20个Skeleton3D、30蒙皮网格；732参考顶点最大误差约1.25e-6米 |
| 原生动画 | 两武器共12组原作运行时采样已接入原生Skeleton3D及零件变换，支持hip/ads/sprint/fire/tactical reload/empty reload；动态IK、连续混合、精确切枪曲线、敌人动作和死亡仍未完整迁移 |
| 通用PBR | 有贴图、ORM、法线和HDR顶点颜色；MeshBasicMaterial已按原作使用unshaded，Gull光锥公式已迁移；三平面法线、武器aSurf和完整湿润规则仍待精确迁移 |
| 手臂与手套 | 原作armSurface/armMicro/armBump公式已迁移并通过GPU编译 |
| 湿地面 | 原作地面颜色、粗糙度和法线公式已迁移；动态时间已接入；平面反射替换未完成 |
| 天空与环境 | 可见天空已接原作解析云层/太阳/方向雾色/云内闪电，原静态HDR环境捕获继续用于IBL；96组原Three→Godot HDR GPU颜色对照通过。原全屏/体积光雷暴响应与完整室内环境适配仍未完成 |
| 光照与阴影 | 有Godot定向光、环境反射和阴影；尚未完成与原作的能量、软影及接触阴影数值校准 |
| 海面 | 原作4组波浪位移、4+7组解析斜率、detail纹理、岸/船体泡沫与污沫、风斑粗糙度、日光闪烁与远距haze已接入；72组真实GPU位移对照通过。Godot PBR/IBL适配仍需与原作完整光照校准 |
| 雨滴与溅水 | 原9260雨/檐滴与900雨冠实例、专用shader、室内盒/天窗裁剪、雨量平滑、像素宽度与地面雨量同步已接入；1000帧控制器、9组GPU裁剪与40640种子分量验证通过。雷暴体积光响应、镜头污渍/眩光与完整天气/画质设置仍未完成 |
| 粒子与战斗效果 | 已迁移原作程序化枪焰公式、aType顶点通道、随机闪焰/余热和短时灯光；原作60实例弹壳几何及重力、四元数旋转、弹跳、停留和缩小消退已接入。原作三层曳光和160槽PBR弹痕已接入。通用粒子内核已通过92帧源码对照，金属火花、受光烟雾、木材/混凝土粉尘、枪口余烟与深度软交界已接入。原作256实例碎片池已迁移并通过260帧矩阵对照。原作爆炸组合与共享6灯池已迁移，尺寸上下限和生成数量已对照。水面命中的水雾、水滴和双涟漪已迁移并通过数量/回收检查。玻璃、橡胶和泥土命中特效的原作发射配置已迁移；烟迹、敌人专用命中分支及其余持续发射器仍待完成 |
| 后处理 | 默认已接原AO并替换Godot SSAO，使用逐sample组合深度/R32F half、AO8双边模糊和joint composite；bloom/streak/dirt、自动曝光、太阳遮挡/flare、tk调色与nk FXAA/锐化/颗粒/dither已接。分层原GPU对照和实机证据见各专项文档；MSAA与随机hash的跨后端差异单列。原24步阴影体积光/雾已默认接入并通过GPU与实机对照；运动模糊及全场景照明校准仍未完成。 |
| 角色碰撞 | 直接迁移原作moveCapsule；400组源码对照全通过，最大误差约1.96e-5 |
| 角色控制 | 原作速度、加减速、重力、跳跃缓冲、土狼时间、蹲伏检查、镜头步态、落地位移、瞄准FOV已接入；尚未逐帧完整源码对照 |
| 角色伤害与恢复 | 已有坠落/落水、原作damage/heal、无敌、延迟回血、受伤脉冲、死亡碰撞和相机倾倒；600帧生命/死亡相机对照通过，实际死亡、失败菜单及整局重置已接入；600帧含reset共9015字段通过；原作伤害/低血量色调后处理已接入；整条渲染链仍未验收 |
| 武器战斗 | PAC-9与PAC-4状态机已接入弹药、射速、射线、散布、相机后坐力、切换和装填；10组规则检查通过。原作视觉后坐力弹簧、完整事件、敌人命中和其余战斗效果仍未完成 |
| 敌人 | Gull和Hound隐藏池及蒙皮已导入；导航与共享感知/攻击令牌已通过原作对照；Hound世界足点、身体弹簧及20骨动态IK已迁移，240帧57600字段对照通过并有GPU录像。Hound路径跟随与原作运动段已迁移，720帧真实导航/射线/残骸排斥对照通过；Hound选位/攻击决策、弱点射线和受击死亡生命周期已有原作对照；独立Actor预览已联动，但最近敌人命中与双方伤害已在独立战斗预览和交互测试入口接入；原生18对象池、Hound管理及Gull飞行/攻击请求/坠落已接入；Gull实际弹体、伤害、敌人枪焰和共享扫描光已接入并有源码/GPU证据，任务波次核心、三中继点撤离及默认游戏状态编排已接入，完整HUD与手动整局验收仍未完成 |
| 爆炸物 | 21个原作爆炸物已绑定；命中引信、致命命中短引信、实例槽隐藏、碰撞移除、连锁和重置已接入并通过状态/物理检查。玩家与敌人爆炸衰减/遮挡伤害已接入Combat并有规则对照；整局爆炸警戒事件和完整视听之外的死亡反馈仍待接入 |
| 玩法 | Mission/Holdout核心、Standard/Hard/Brutal、初始巡逻、增援/追击、三个中继点、撤离评级与波次补给计分已有原作对照；任务GPU自动流程通过。标题/intro、暂停、胜败菜单、最高分持久化代码及重开已接入，500帧11030比较通过；GPU三次reset通过。手动通关、持久化跨进程验收和完整UI仍未完成 |
| UI | 原生标题、设置、基础HUD、结果和暂停已接入原作字体与配色；原作任务无线电、一次性提示及打字机已有源码对照；罗盘、世界目标标记和扩散准星已接入并有源码/GPU对照；命中/弱点/击杀动画、四槽受伤方向及击杀列表已接入；原作生命分段/弹药数字与弹匣pips/低弹提示/备用武器和环形交互已接入；目标打字与动画、画质/武器位置设置和像素校准仍未完成 |
| 瞄具玻璃与准星 | 原作ME独立Shader已替换不透明占位：透明镀膜、视角准直红色点/环/刻线、菲涅耳反射、灰尘/擦痕与离轴发光已迁移；600帧反射回调对照和黑白背景GPU预乘混合通过。整场景室内环境适配输入和最终色调映射仍待完成 |
| 双视野渲染 | 已接入同World3D独立SubViewport，世界74度/武器54度，透明合成及相机附属武器补光；仍需与原作HDR后处理顺序和深度特效逐项校准 |
| 音效 | 按用户要求不迁移，不创建音频节点 |
| 打包 | 尚未完成；原始二进制仍从带.gdignore的export目录读取，正式导出前必须处理资源路径与过滤规则 |
| 全面验收 | 不具备完整游戏通过证据，目标保持进行中 |

## 代码依据

原作 `../artifact-rendering-study/source/extracted/bundle-1.js`：角色常量34648起，物理碰撞40080起，站立检查68958起，角色更新69008起，镜头69200附近。台阶高度hg=0.42，半径0.32，站高1.8，蹲高1.15。

进一步需求以原作活动脚本和 `../artifact-rendering-study/docs/full-port-adviser.md` 为准。不要删除尚未实现项来让检查通过，也不要将当前GPU录像称作完整游戏实机。


### Hound行为模块增量，阶段记录

新增 `scripts/hound_behavior.gd`，迁移选位、巡逻/搜索决策、预警连射、扑击恢复及头部/炮台瞄准。原作函数受控对照共24660字段通过，见 `evidence/hound-behavior-verification.json`。该模块尚未在普通游戏循环中组合为完整Actor；真实攻击命中、玩家伤害、死亡残骸、Gull与任务仍未完成。


### Hound Actor联动增量，阶段记录

新增 `hound_actor.gd`、`hound_life.gd` 与 `enemy_hit_shapes.gd`，以及 `--hound-actor-preview` GPU录像。生命周期912帧、81228个递归比较通过；480条射线命中/部位分类与原作一致，近轴单精度数值上限单独记录。Actor预览组合真实场景导航、掩体、感知/令牌、射击请求、程序步态、脚本受击和持久残骸。玩家实际受伤、敌人枪焰、武器最近敌人命中、普通管理器和全部敌人类型仍待完成。


### 原生战斗链路增量

`SaltlineCombat` 已连接玩家最近敌人命中、2.2倍弱点伤害、敌方投影点射击判定和敌人/玩家范围爆炸伤害。`SaltlinePlayer` 已加入实际受伤、无敌、延迟回血、死亡碰撞与相机倾倒。原作240组战斗规则与600帧生命/死亡相机对照通过，回归移动、武器与爆炸物通过。新增 `--hound-combat-preview` 武器真实击杀GPU演示与 `--hound-fight` 交互开发入口。

仍缺完整敌人管理器、Gull、任务/波次、死亡失败与重开UI、玩家受伤后处理、瞄具玻璃/准星和敌人枪焰；普通默认运行没有自动刷出完整原作敌人队列。爆炸统计和敌人范围伤害已接Combat，但整局爆炸/警戒事件链仍需后续验证。


### 池管理器增量

新增原生EnemyManager，8只Hound均通过池生成、活动列表、逆序更新、残骸上限、池满复用和下沉回收；武器噪声/爆炸警戒接入。原作26组管理操作、4047个递归比较通过，600帧八对象GPU验证通过。Gull飞行池、弹体、共享扫描光、任务波次和默认场景布置仍待完成，不能把Hound管理器当全敌人系统已完成。


### Gull角色增量

新增GullFlight、GullBehavior、GullLife、GullPose和GullActor，10个Gull加入原生池。飞行与完整存活更新各1200帧、受击坠落64帧、射线480条原作对照通过。近距离GPU预览覆盖飞行/云台/旋翼、攻击请求、受控射线受击、旋翼脱落、坠落爆炸与回收。Gull实际bolt模拟/伤害、共享扫描灯和敌人枪焰仍待接入；任务波次、初始布置和剩余渲染仍未完成。


### Gull弹体和扫描光增量

原作32槽实际弹体、玩家扫掠命中、墙面遮挡、寿命回收及原始网格矩阵已接入，320帧232830比较通过。共享Omni扫描光接入六灯池，360帧4680比较通过。敌人通用枪焰配置接入并通过源函数对照，Hound/Gull均调用。GPU录像验证Gull三发弹体命中、玩家HP70、三次枪焰、52次扫描采样、坠落爆炸和回收。任务/波次、完整UI/重开、资产目录审计和剩余材质/后处理仍待完成。


### 任务与中继点增量

新增原作常量提取、Mission核心、中继点脉冲/旋转/弹簧门控制。三档难度、出生点评分、初始巡逻、增援/追击、中继点交互、撤离评级、Holdout波次/补给/计分已迁移；原作完整pT受控对照444125比较通过，中继点3300字段通过。GPU自动流程通过三点断开及撤离，并有11名实际敌人运行。新增 --mission / --holdout 开发入口。原作完整UI、intro/title相机、暂停、最高分持久化、失败/重开编排、手动通关验收和剩余渲染/资产审计仍未完成。


### 标题、状态编排、重开与无线电增量

默认启动进入原生标题菜单。新增 GameFlow、Session 和 GameUI，接入原作标题相机轨迹、intro/playing/paused/dead/complete时序、暂停防抖、失败重试、撤离重部署及Holdout最高分保存代码。设置支持灵敏度、反转Y、FOV、模式、难度及全屏。三组原作字体八个字重来自原HTML所引用Google Fonts，带URL、SHA256和OFL来源。

500帧状态对照11030比较通过。780帧GPU脚本通过标题/设置/暂停/死亡/重试/暂停重开，暂停冻结、三次reset的HP100/步枪30+150/21爆炸物/595碰撞盒/5巡逻敌人及零残留特效已记录。见 `game-flow.md`。

无线电文案由原作Vu直接提取。首次发现、低血量、逐个断点、撤离和Holdout补给按原作触发，死亡/重开/撤离清空旧队列。扩展后的完整pT任务与Holdout对照为482543比较；原作HUD打字机函数720帧5760比较通过。仅字幕，无音效。完整UI、天气/海面/材质/后处理、武器动态IK、近战、其余输入方式和整局手动验收仍未完成。


### 罗盘、世界目标标记与准星增量

新增 `hud_projection.gd` 和 `navigation_hud.gd`，迁移原作罗盘方向、每度4px刻度带与半像素量化、目标方位夹取、水平距离、真实相机投影、背面/屏幕边缘夹取、近距离隐藏、中心弱化、ADS隐藏世界标记，以及按散布/FOV/冲刺计算的准星间距。

实际执行保存的Three r180和原作HUD代码块生成640组样本、2560个目标；22770比较0失败，屏幕坐标样本最大误差0px。GPU780帧验证转向/ADS/射击与中继点标记A/B/C→B/C→C→EX，见 `evidence/native-navigation-hud.mp4` 和 `docs/navigation-hud.md`。切断使用直接调用核心函数，仅证明HUD生命周期，不替代手动交互验收。


### 战斗HUD反馈增量

新增 `combat_feedback.gd`，接到Combat实际击杀/命中与Player.hit；保留敌人死亡先于hit_enemy的顺序，同帧弱点击杀才给最新feed追加Weak point。四个受伤方向槽优先空槽、再替换剩余寿命最少者，角度按逻辑yaw更新，透明度按0.05量化；列表上限4项、寿命4.2秒、最后0.6秒进入CSS对应淡出。暂停冻结HUD生命周期，命中动画与已开始的淡出继续。整局hud_reset与单独clearRadio已分离。

原作真实事件回调/更新循环600帧10396比较通过，战斗240组2160字段回归通过；GPU真实射线覆盖普通命中/弱点命中/弱点击杀/普通击杀，真实damage覆盖四方向及槽替换，重试清空。见 `docs/combat-feedback.md` 与 `evidence/native-combat-feedback.mp4`。浏览器动画逐像素与完整后处理仍未验收。


### 生命、弹药与环形交互HUD增量

新增status_hud.gd替换原先开发HP/弹药文字和横向进度条。按原作重建76px弹药数字、弹匣pips、备弹/副武器、低弹/装填/空仓提示，10段生命条及满血隐藏、危急色、淡入淡出，以及48px E键环和0.005量化进度。实际原HUD代码800组9600比较通过；720帧GPU验证真实装填、两次切枪、伤害/回复、按住交互断点与重试清理。见docs/status-hud.md与evidence/native-status-hud.mp4。目标面板、警告/消息动画和完整像素校准仍未完成。


### 瞄具镀膜玻璃与准星增量

已移除uBright/uTilt瞄具材质的不透明占位，迁移原作ME解析玻璃Shader。红色准星按观察方向相对枪管轴计算，不是额外HUD贴图；玻璃镀膜包含环境/太阳反射、角度变色、边缘暗化、灰尘、擦痕及离轴发射器光晕。原片段公式经接口改名与去除原作显示编码后逐式保留，Godot仍使用当前过渡后处理。600帧环境回调1200比较通过；GPU黑白底预乘混合最大线性误差0.00313。9秒实机视频与说明见 `evidence/native-sight-glass.mp4`、`docs/sight-glass.md`。


### 原作海面增量

新增sea.gdshader及从原导出patch生成shader的port_sea_shader.py。原海面13620顶点网格及两张原detail纹理直接复用，四组Gerstner式竖直/水平位移、四组大波/七组细波解析法线、码头/船体距离场泡沫与污沫、风斑粗糙度、涌浪与太阳方向碎高光、远距haze已接入。片段表面块与原顶点位移块保持原式，72组GPU位移读回通过，最大误差0.001652米（8bit读回容差0.004米）。

当前光照采用Godot自定义GGX/环境反射适配，原作每帧海面公式已经运行，但IBL遮蔽上限、逐光截断与原作汇总截断、最终色调映射和整场景光照仍未完全一致。修复后的8秒固定步进视频见 `../../video/recordings/godot/sea-quay-fixed.mp4`；旧 `evidence/native-sea.mp4` 是修复前历史素材。边界与证据见docs/sea.md。


### 雨线、檐滴与雨冠增量

原InstancedBufferGeometry现在转换为MultiMesh，aSeed通过INSTANCE_CUSTOM原样保留，包括负w的260檐滴分支。原雨线和雨冠Shader已接入，雨滴随相机循环、风向下落、尺寸按像素控制，室内盒剔除/天窗放行，低于地面或海面剔除。原湿地遮罩决定雨冠密度；雨量同步地面uRain。

原Gw.update控制器1000帧98521比较通过，真实GPU9组遮挡/裁剪通过，全部40640个种子分量读回零误差。完整游戏暂停与三次重开回归通过，暂停包含雨时钟。新增10秒evidence/native-rain.mp4，详见docs/rain.md。独立雨系统雷暴计时已迁移，但全局fork RNG、天空闪光与镜头污渍/眩光尚未完成，不将此阶段称作完整天气。


### 动态天空与片状闪电增量

恢复原sky立方体，以Godot reverse-Z远深度绘制，保留原解析天空、FBM云层、太阳光环/云隙、低地平线雾色和方向性云内闪电。环境反射沿用原初始化捕获的静态PMREM全景，没有把动态太阳盘重新烘入环境。雨系统thunder已接天空；500帧原回调/闪光表达式3000比较通过。

原Three r180实际片段Float32 GPU参考96组，与Godot HDR RGBA16F逐288通道对照通过，原容差max(.004,0.2%辐射)未放宽。Astra Ultra协助诊断了硬件噪声插值的FBM误差放大；四texelFetch显式双线性插值修复少量云边偏差，详见docs/sky.md及精度诊断。8秒实机录像evidence/native-dynamic-sky.mp4。原post雷暴/体积光、太阳眩光和全局环境适配仍待迁移。


### 原最终compositor与HDR链路增量

默认游戏使用独立HDR世界/武器视口、线性预乘合成、原j9六级13点缩小核、K9五级tent上采样、J9两遍横向光晕、ek静态污渍与原tk最终色调和grade，HUD留在SDR根视口。世界/武器原内建Filmic与glow关闭，避免双重tone mapping；手动曝光1，原Q9自动曝光已启用并通过180帧原HalfFloat时间序列对照，太阳flare现按原值.16启用，MSAA边缘仍待对齐；bloom=.065、dirt=.1、streak=.03按原值启用。96组原Three最终compositor GPU对照最大误差0.000481；160像素480通道down对照通过；12帧交替色/HDR透明探针贯穿全部down/up/streak验证同帧顺序和HDR保留，最大常场误差.007032，另有13级非均匀空间核4308通道参考对照通过；污渍程序化边缘存在跨驱动偏差，保留诊断并使用原RGBA8烘焙资产，来源与SHA256已记录。

源核对更正：活动版没有镜头雨滴折射，实际是静态镜头污渍参与bloom/flare；旧“镜头雨滴待实现”不是原作需求，已纠正，未发明替代效果。完整说明docs/post-composite.md，实机evidence/native-post-composite.mp4。

## 原AO隔离内核阶段

R32F half-depth compute精确奇偶行抽样、原AO12及三次RGBA8/nearest量化已通过四组原Three GPU对照；最大AO差1色阶，见docs/ao-kernels.md。后续已接默认原AO和joint-bilateral composite并关闭Godot SSAO，MSAA逐sample合并/样本0及native后端差异已实测，详见msaa-depth.md。体积光现已接入，见后续体积光记录。

## 原体积光太阳阴影输入阶段

独立固定sun caster pass及原非等比投影已实现，原64² packed shadow参考4096像素和256投影点通过；Skin/MultiMesh隔帧同步通过。原场景148caster/18skin/6实例组的4096²图已生成，两次释放GPU内存无增长，新增约630MiB。随后已默认接入 Y9；阴影独立输入证据见 docs/sun-shadow-pass.md，体积光证据见 docs/volume.md。

## 原24步体积光默认接入

原Y9散射、QM两次RGBA16F模糊和joint composite已接默认管线，16组原Three GPU参考24576通道零失败。冻结仓库实机验证开启体积光及真实阴影输入均影响HDR结果，新增6秒录像 evidence/native-source-volume.mp4。首帧ready门控及退出资源保护已实现，具体参数和验证边界见 docs/volume.md。完整天气/画质、联合GPU性能和全场景原版图像对照仍待完成。

## 原Z9运动模糊初步接入

原9tap相机历史重投影已接HDR场景合成后、bloom之前，保留武器绕过、.75像素阈值、.018UV限幅和原shutter。4组原生GPU语义检查及后处理回归通过；随后原Three GPU 49152通道对照零失败、单一原相机配置矩阵误差5.722e-6，8秒重复轨迹开关录像已生成。完整画质设置和跨相机配置验收仍待完成。详见 docs/motion-blur.md。

## 原平面反射相机与材质准备

原Uw实际函数8组参考已提取，镜像相机、preclip采样矩阵、斜裁剪、尺寸/启用条件通过未放宽的1e-4绝对门槛。原RP三采样/LOD/扭曲公式已移植，黑环境真实ground反射贡献探针通过，并定位Godot额外specular-occlusion门控。真实反射viewport/裁剪/HDR mip链尚未完成，默认uReflOn保持0；详见 docs/planar-reflection.md。

## 平面反射 XR 投影与 HDR 探针

原斜裁剪在独立mono XR视口通过：下方marker裁掉，上方不变，普通主图bytes不变；POST_TRANSPARENT RGBA16F复制保留green4。点光/聚光/无阴影太阳一致，但真实墙面级联阴影出现434像素差异、max.796，测试保持失败；斜投影get_z_far为负数。默认全场景反射仍off，不能视为已完成。mip链与阴影修复继续，见docs/planar-reflection.md及planar-adviser.md。

## 原反射 mip 链 GPU 对照

RGBA16F完整mip链已实现，含实际640×360的4种尺寸、1291416通道原Three自动mip参考对照零失败；生成层最大差0，base转换最大5.44e-5。实际XR捕获仍保留HDR4，8级额外mip尾部非零，裁剪/主图隔离回归通过。级联阴影问题仍未修复，全场景反射保持off；下一步接原固定太阳PCSS/直接光方案的逐项验证。

## 固定原太阳直接光/PCSS核心与反射恢复

原Three Standard Lambert/GGX 96组768通道对照通过；原jM 8+16 PCSS16组131072通道对照通过，max.000488。实际4096 caster图接入受控反射墙面，原太阳阴影使752像素暗化，normalGL与oblique图逐像素一致，修复路径有实机证据。默认所有材质太阳替换、flags/总光clamp/原帧顺序尚待完成；详见 docs/source-sun.md。

## 通用Standard原太阳默认接入

135个通用Standard材质、250个原对象已默认使用原Lambert/GGX+jM PCSS，逐实例保留239接收/11不接收标记。独立审核全部301原geometry的材质类型、阴影flag和native sun隔离零失败；动态几何采用实际material再分类。6秒实机原太阳/阴影开关录像 evidence/native-source-sun.mp4；480帧motion回归通过。ground/sea/arms与特殊总光修饰、原局部光/IBL和反射顺序尚待完成，详见docs/source-sun.md。

## 特殊Standard原太阳接入

ground/sea/arms已接原太阳，默认覆盖原138个Standard材质、254个原对象（243接收/11不接收）。保留ground湿F0、sea位移shadowCoord/方向glitter与太阳specular限幅、arms原表面/bump。独立flags审计与实机太阳/阴影贡献检查通过，480帧海面/仓库太阳回归通过；生成器重跑一致。多灯先求和再clamp、原局部光/IBL和完整材质准备仍待验证，详见docs/source-sun.md。

## 全场景反射接入与引擎参考投影构建中

真实反射viewport/原四对象排除/HDR mip消费脚本已接出实验入口；水平初始相机暴露stock light-culler有限八角锥求交错误，失败证据已保存。默认反射继续off，原太阳功能保留，默认路径运行无错误。与原二进制同commit的官方源码已校验下载，7文件局部reference projection补丁正在隔离编译；源码/补丁/依赖/构建命令可复现记录在engine/。尚未编译和GPU验收，不宣称修复完成。

## 隔离引擎兼容补丁与实际平面反射首轮通过

对应官方commit的7文件mono reference补丁已编译；水平/俯仰点光/聚光/原生cascade及固定PCSS两投影逐像素一致，stock旧失败保留。完整场景反射开关改变15683抽样HDR像素，原四对象排除与callback顺序reflection→sun→world→weapon通过，4秒视频 evidence/native-planar-reflection.mp4。隔离构建经tools/run_native.sh默认开启，系统Godot未替换。动态shadow-age、resize/重入与最终光照/性能仍待完成。

## 反射生命周期与GPU旧阴影顺序通过

原完整场景实际逻辑1280×720→961×541→128×64→恢复，反射目标640×360→480×272→64×32→恢复通过；高度停用/恢复、开关、XR注册与层恢复、重建ready与顺序全部通过。新增显式reflection child-of-sun依赖，不靠创建顺序。非周期单caster128阴影图GPU逐像素证明反射读旧图、主图读更新图，8帧四次更新均可区分且实际误差0。完整大场景动态PCSS、性能和其余复刻要求仍待完成。

## 三平面法线与蒙皮静止坐标接入

18 个角色的静止位置/法线通过 CUSTOM1/2 保留，4×290 RGBA32F 共享骨矩阵图集随 skeleton_updated 更新原三平面坐标轴；Standard 接原 vk 法线融合。48 组原 GLSL GPU 对照最大差 .000488，290 个原矩阵最大差 1.49e-7。实际 Gull/Hound 各150帧、15次图集采样均与当前骨骼矩阵一致（最大差0），后续14次均有动画变化。完整 Gull600帧预览与太阳360帧回归无引擎错误。原湿度/污渍/水珠/距离裁剪、非三平面切线基及完整纹理采样画面对照仍待完成，详见 docs/triplanar.md。

## 通用湿度原公式接入，GPU精度差异待解

原朝向湿度、雨痕、贴地溅湿、污渍、水珠粗糙度和湿润增饱和已接四个generic shader，实机100帧无编译/运行错误。48组原GLSL GPU对照保持.001门槛，部分高频水珠最大差.187805、部分wet差.004395，验收失败已保留。未宣称材质一致；Astra正在审查噪声浮点差异与参考有效性，详见docs/wet-surface.md。

## 原距离透明裁剪及湿度后处理公式通过

SL_ACUT已接实际两个chainlink材质，补原alpha染色分支与uSlUv.xy；96组1536通道原GPU对照零失败，max.000488。湿润增饱和/暗化和水珠粗糙度另48组768通道通过，max.000488。实际场景100帧正常。湿度噪声准备仍失败，诊断首乘法/全hash位型屏障未解决，生产noise未改；Astra继续逐位定位。详见docs/alpha-cut.md、wet-surface.md。

## 原染色与顶点色顺序修正

四个generic材质修正tint/湿润在顶点和实例色之前的执行顺序，恢复SL_ACUT覆盖alpha后再乘顶点alpha，并处理BackSide非扰动法线方向。48组原mk+color_fragment GPU对照768通道零失败、max.000488。完整太阳场景360帧回归通过。仍不能据此宣称完整湿材质画面一致，详见docs/material-color.md。

## 湿度噪声修复与非三平面切线基通过

运行期uint零屏障固定原slH输入及关键中间float32运算，阻止内联角点表达式重排；四个generic共用生产noise include。完整湿度48组768通道原GPU对照零失败、max.000488，原门槛不变。导数切线基补双面T/B、零det及WebGL导数Y方向，32组Canvas512/真实空间98304通道均通过。完整场景360帧无错误、太阳回归通过。完整模型纹理插值/大坐标/不同GPU与性能、其他复刻要求仍未完成。详见docs/wet-surface.md、tangent-normal.md。

## 通用纹理夹取与采样绑定修正

通用shader改为按原wrap/minFilter生成6种缓存变体，183材质284绑定（50夹取）独立审计零差异。动态shader保留来源标记供原太阳分类，完整360帧回归通过。24个Clamp实际GPU样本误差0；Repeat线性过滤仍10个样本超.002门槛、max.003906，失败保留，不宣称完整纹理采样一致。详见docs/material-samplers.md。

## 原GPU完整mip链接入，修复sRGB远景暗化

原Three checker证实旧CPU编码值平均导致lod采样.21582而原GPU为.50293。已提取132张原GPU生成mip，逐张base原样验证；prepare校验sha，runtime直接上传编码RGBA8链。实际128张（127普通完整链+天空原raw专用行序）206MB GPU读回全哈希一致，完整360帧太阳回归通过。硬件linear过滤差异仍独立存在，mip/trilinear/aniso最终采样及完整画面未验收。详见docs/texture-mips.md。

## PMREM原HDR数据补采，身份对照未完成

发现早期RGBA8导出损失两张HalfFloat PMREM的HDR；已从原HTML逐texel补采RGBA32F并保留两组boot参数/sha，峰值6/355.5。与历史clamped快照仍有差异，未接生产IBL、未宣称资产身份通过；Astra继续审查过滤读回与状态。详见docs/pmrem-hdr.md。

## PMREM NVIDIA同后端来源对照与采样行序定位

headed原版NVIDIA重采两张PMREM HDR，clamp后与旧RGBA8最大差1/over1=0，首选资产位于environment/pmrem-gpu，峰值6/382.25，IBL仍未集成。GPU配对采样显示生产翻行+V反转10样本失败；保留原行序且直接采样的独立48组全误差0，尚未生产接入。详见docs/pmrem-hdr.md、material-samplers.md。

## 通用纹理原始行序与NVIDIA mip生产接入

通用材质保留原GPU每层行序并取消V反转，真实factory48个原NVIDIA线性采样全部误差0；专用shader契约保留。NVIDIA后端原132 mip重导替换Swift生成链，旧差异数据压缩归档；离线逐层翻行避免Image.flip_y重生成mip。实际128GPU变体206MB完整hash全部一致，360帧场景/太阳/阴影回归通过，无错误。mip/aniso实际采样完整画面对照与IBL等全目标仍未完成。

## 原CubeUV与间接光BRDF核心通过

canonical NVIDIA HDR loader按原RGBA16F/行序上传，两完整GPU读回恢复RGBA32F SHA一致。原U8 CubeUV224组3584通道对照通过、max.000122；原DFG/多次散射/间接diffuse+spec/AO96组768通道通过。尚未替换实际场景IBL，须补材质envMap覆盖、环境强度/室内选择及专用材质混合。详见docs/source-ibl.md。

## 通用Standard原IBL默认接入

原195材质环境绑定实际导出并核对身份；generic135材质250对象（19weapon）已接原CubeUV/间接BRDF与正确室内/武器强度。双零IRRADIANCE/RADIANCE抑制native间接光，保留direct；修正fx_decals无aoMap例外。独立flags/边界审核与实际47065 HDR抽样点贡献通过；原生ambient/sky能量0到10时source输出差0，关闭source的对照max20.242。360帧太阳/PCSS回归与224组CubeUV通过。ground/sea/arms专用IBL和其他全目标仍未完成，详见docs/source-ibl.md。

## 专用地面/海面/手臂原IBL接入与生成管线修复

全138 Standard/254原对象（21weapon、22显式room）绑定审核通过。ground湿F0+BRDF前planar辐射混合，sea原gOcc未clamp双路环境缩放，arms最终normal与weapon环境已接。72组耦合GPU核心通过；逐special实际HDR贡献13651/22543/743抽样点。生成顺序缺RP曾被planar回归检出，已修复完整生成链，三shader重建幂等；最终太阳360帧、planar240帧（15859变化）及未ready fallback回归全过。完整原图、haze、原局部光/总direct clamp及其他目标继续保留。详见docs/source-ibl.md。

## 原点光衰减核心与缺失仓库点灯补回

原point函数192组768通道GPU对照通过；完整Spot诊断6处cone边界visible差异保留，当前源无Spot，不扩大门槛。4仓库PointLight不再只是Node3D，原位置/颜色/强度/range/decay/shadow实机审核通过，开关36714 HDR点变化；key室内.495与方向通过。static/key native桥除PI并独立保留source intensity；6pool源状态不改，原局部BRDF/atlas和总directSpec clamp仍待接。太阳360与planar240回归通过。详见docs/source-local-lights.md。

## 动态灯源单位与渲染帧时序

6槽pool与扫描灯统一保留source_intensity，native fallback由单一setter写入source/PI，TTL/peak不变。实际game每render一次更新，原dt上限.05且暂停继续衰减；四次physics更新不衰减，persistent42不变。实际时序GPU测试通过，首次提前退出material-null失败留档，修正flush后清理通过。Gull600帧回归通过。4×11 RGBA32F局部光atlas已添加到pool之后、reflection之前的上传点，实际Main下整张176通道GPU读回逐字节一致，playing/paused每帧一次、source units/原mask/隐藏/静态行/key均通过；仍待原BRDF消费，不能宣称局部光原公式已接入。

## 统一原局部直接光与总高光顺序

实际254对象默认迁移sourceDirectTerms：十点光按pool6/仓库4顺序，接原太阳PCSS，再接武器key；ground/sea全部directSpec仅clamp40一次，sea随后glitter，IBL独立。当前相机CAMERA_VISIBLE_LAYERS提供原mask，native fallback bit18/17隔离并可恢复。72组576通道独立原NVIDIA Three耦合参考通过，15组触及限幅。实际world42267/weapon5881抽样点贡献；11 native灯实际draw时全部1000，两pass差0；231共享layer3物体key开关world0/weapon29309点变化，回入差0。Astra发现并修复了按对象而非相机过滤，以及既有arms bump输入未先归一化的问题。原节点测试更新为切换source强度后通过，39814 HDR点变化。生成/再注入幂等，最终太阳360帧、planar240帧回归通过且日志无错误/泄漏。误改alpha参数引起的首次编译失败和误读合成world图的探针失败均保留。全目标尚未完成，尤其详细材质patch、动态完整视觉对齐、性能/导出和游戏控制流程。详见source-local-lights.md与local-direct-adviser.md。

## 六种PAC武器程序化材质接入

原_E六材质五D_KIND分支已机械提取并接入十三真实网格，含磨损/划痕/加工纹/油污/聚合物凸点/凹槽积尘/雨滴/流痕，按原表面→bump→四路cavity光照调制顺序。aSurf 674256通道和另存FP32原normal GPU字节全一致，恢复原vertex normal与modelMatrix世界normal插值。独立武器湿度原室内外非对称状态、dtcap.05、暂停更新同时写七材质，实机4case误差0。原sin-dot hash初版数值失败，经Astra完整位探针定位为dot内部FMA顺序；显式复现原NVIDIA乘加后，原96组1536通道通过maxAbs约5.96e-8，未改门槛或随机场。空间bump32组98304通道误差0。实际detail开关15501 HDR点变化，生成幂等、太阳360/反射240与当前600帧ADS/射击/换弹/切枪录制完成，最终日志无错误/泄漏。新视频native-weapon-material-detail.mp4共601编码帧/10.016667s、720p60无音轨，已查看2s/8s。完整像素对齐、其他程序化patch/驱动范围、控制/任务/性能/导出总目标仍继续。详见source-weapon-detail.md与weapon-detail-noise-adviser.md。

## 武器刻字凹刻与剩余材质审计

weapon_markings原-alpha×50微米高度bump接入生产alpha shader，按原patch正文识别。三真实geometry/UV/texture在独立正交IBL下开关分别884/2193/5105 HDR像素变化，退出0且无错误。原bE空间导数公式沿用此前32组98304通道零误差证据，不扩大为完整透视合成对照。

186个Standard/Basic材质按onBeforeCompile划为9族，见material-patch-family-audit.json：新增明确缺项为两mesh blink灯和一mesh orbit ambient gulls，其属性blink/aOrbit/aPar及动画尚未迁移。不是敌方Gull actor。48个材质75个原mesh的polygonOffset亦仍缺失。

已补原GL546组硬件偏移fixture，D24有效r=2*q24；主线public RD对D24S8/D32FS8独立14深度profile各测units -4..4，D24的7×9偏移delta与原GL63组逐bits还原一致，D32则随深度指数变化。RD探针首次清理API错误留档，修正后退出0无错误。未改生产引擎、未用片元epsilon。Astra建议D24S8+私有静态raster bias modes，世界反号、独立weapon units×20；sourceSun depth producer与weapon range量化、reverseZ/MSAA/真实透明贴花均仍是接入gate，详见polygon-offset-adviser.md。总目标继续保留全部资产/效果/控制/任务/导出和完整视觉对齐。

## 背景顶点patch接入与硬件深度偏移引擎基础

原Basic blink两mesh、orbit海鸟一mesh现已机械提取接入，CUSTOM0/1全GPU字节一致，保留HDR色与unlit。海鸟解析轨道/振翅AABB修正静态y=-60误裁剪。96组384通道原RGBA32F vsnativefloat32位编码通过max2.98e-8；实际灯78700/78698、鸟4489像素变化；Main playing/paused时钟和原render dtcap .05通过。780帧流程pause冻结/两次重试及240帧反射通过，日志无错误，生成幂等。材质族审计不再有这两个vertexpatch缺项，完整像素/玩法验收仍未完成。详见source-backdrop.md。

隔离引擎新增默认关闭的source_depth_24和四个静态硬件bias render_mode，保留mono oblique，11文件合并补丁从原archive应用SHA全一致，构建18s完成。binary SHA256=1f621cd3a85ba413b3a385b2a19b828bc145bf2da9e86f9fc515908a1a639a2f，80333928bytes。初始Forward+30组D24/reverseZ/0+4xMSAA/opaque prepasscolor一致性通过，constant sign与weapon×20正确。初始化compositor对象/格式context两次测试错误留档，修正后无错误退出0。当前project setting仍未启用，48生产材质尚未映射；slope/透明贴花/SourceSun D24数据影响/AO/volume与生命周期是下一步gate。没有以当前probe替代这些gate。见engine/README.md、polygon-engine-verification.json。

## 默认D24与48源贴花硬件偏移接入

source_scene按原node layers归并材质world/weapon域，将私有硬件bias mode纳入shader代码/cache key，source_shader_path服务元数据保留；48材质75mesh映射通过，无普通材质串bias。项目现静态启用source_depth_24，新增isolated engine/Forward+/D24 attachment+sampling+copy-from能力guard，不支持时禁用D24 bias并明确近似fallback。engineC++/binary未再改变，SHA与11文件patch匹配。

50组真实Forward+常量/斜率/0+4xMSAA/prepass-color通过。理想CPUtan斜率曾有7q残差，失败JSON保留；改用未偏移GPU32pixel梯度且未放宽2q门槛，最大残差1.375q。32透明gap/alpha/不写depth通过，真实源decal/markings geometry+texture+shader在receiver后仅切bias分别5/368 HDR像素变化。

全4096²原148caster D32vsD24扫描16M像素，402512变化，max1q24，超2q像素0，实际格式129/128。D24太阳360/AO240/volume360/planar240及四相机附件128通过，旧D32报告留档。默认开启后的8case lifecycle/XR/layer还原/重入和780flow pause+两retry通过，相关日志无错误/泄漏。当前601帧10.016667秒720p60无音轨视频native-source-depth24.mp4已录制，ADS/手枪帧已查看，非性能证据。

Astra最终审查无当前NVIDIA Forward+路径新阻断；明确静态flag只在启动/完整重建时设置，usage cap不是跨驱动r校准。独立weapon量化、原GL packed shadow和动态临界边、全原图视觉/其他控制功能/性能/导出继续保留。见source-polygon-offset.md。

## 武器机械件动作与解析运动基础

修复weapon_animation对枪内26个子节点混入静态ADS/sprint pose的问题。根节点和双臂仍沿既有采样混合；枪栓、套筒等机械件保留原动作clip。原导出fire逐帧对照两枪、ADS/sprint零/一/混合共6240次，local position/quaternion最大误差0；射击起点rifle bolt与ADS差0.039156478米，pistol slide差0.027777778米。该证据来自轻量实际动画执行，未宣称新渲染画面或完整根动态/IK。原10项状态机回归通过。见evidence/weapon-mechanics-verification.json。

新增原pn/en/Xn/AE/sa/ry CPU double移植和literal JS fixture生成器。24条轨迹4320步含dt0/.1、critical .999门槛、频率/阻尼override、impulse/reset；position max5.996e-15、velocity max1.351e-13。128个noise/soft-limit样本max1.9893e-8，初始1e-8噪声门槛失败保留weapon-motion-math-verification-initial.json；此项明确按跨JS/libm容差3e-8验证，不能称逐位一致。该数学层尚未接管生产root。

Astra Ultra审查见weapon-motion-adviser.md。完整D仍需recoil/reload驱动、原look增量与玩家事件、共享S时钟/reset/equip语义，以及双臂同步过渡和最终IK；未以局部修复宣称完整武器动态迁移。全游戏资产/效果/控制/任务/导出与完整视觉目标继续。

## 原鼠标增益、逐tick look与滚轮切枪

生产Main新增source_mouse_input累积/一次消费，恢复原.0021增益、400 raw位移过滤、ADS消费时缩放和signed yaw modulo。暂停/状态切换/reset清look，上下滚轮280ms实时时钟节流。16项定向检查通过；原浏览器deltaY与Godot notch单位不同，高精度滚动仍为明确差异。player五项回归通过，旧FOV检查未考虑既有Camera3D .01更新阈值的初次失败保留，现同时约束内部目标与相机差值，生产FOV逻辑不变。实际Forward+780帧流程回归退出0、pause冻结、死亡和两retry、最终playing，日志无ERROR/泄漏。见source-mouse-input.md。完整武器D/IK、其他输入与全部游戏目标继续。

## 原实时武器D和recoil核独立迁移

新增weapon_root_motion完整D与两枪recoil方法；literal原函数和原bundled Three生成两枪1200步参考，186072个标量比较max1.13243e-14、16通道矩阵max3.73752e-7，门槛1e-8/2e-6不变。48次原recoil同时核对camera/shake/root，随机与墙调用由模块和独立Callable双计数。定向负半Math.round、sway硬限位、零幅度落地耗RNG、缺失/null输入与dtcap均覆盖，NaN/Inf拒绝。Astra指出的j0共同重排已改成原字面helper提取和native原式。

当前仅独立模块，生产Main未接管root；原reload/wants/inspect/dry、equip/reset/snap、玩家事件、原随机流消费与双臂同步/IK/死亡掉枪仍需接齐。未以数值核证明整枪或整游戏完成。见source-weapon-root-motion.md、weapon-root-motion-review.md与weapon-root-motion-verification.json。

## 换弹运动和共享S生命周期核

新增weapon_reload_motion，保留原reload对S的全部冲量/anticipation/reloadW/rackW、once flags和完整phase/empty/weapon/partial payload。原state-bearing prefix/suffix和f/h事件函数独立生成12组2625步参考，453273比较max2.21351e-15，门槛1e-12；含两枪empty/tac、240Hz、阈值及全部根曲线派生边界±1e-9、coarse重复/回退。arms/parts中段明确待迁移，arm仅调用数，ammo仍归weapon逻辑。

weapon_motion_lifecycle移植原equip/reset/snap对S的选择性修改，96次dirty-state共享S操作15552比较误差0；t/breath等历史保留，未用整份reset替代。首次源T作用域提取错误和无fixture的依赖验证失败留档，修正后验证通过。生产节点/slot/arms/drop副作用未接入。Astra提醒事件owner只能一份，reload.fresh与reload.f.fresh必须区分，新核须在done清理前运行。

当前生产仍未切换实时root，完整O驱动、玩家事件、原RNG、双臂同步/IK和游戏总体目标继续。见source-weapon-reload-motion.md。

## 生产换弹单一事件入口

Weapon.update现调用已验reload核，旧事件循环移除；同一handler检查flags、magin转弹药/seated、emit后返回bool再加冲量。f/events共享字典，计时fresh与f.fresh分开，唯一T时长、active_reload局部context防回调取消后访问空字典。内部equip/reset状态入口已接线，生产D/root仍采样。

原f/h emit时slot及四路v快照对照实际Weapon.update：12组2456有效步119266比较max2.21351e-15，门槛1e-12。完成一次、magin两侧取消、fresh首帧、回调取消及WeakRef owner释放/过期事件拒绝通过。首次数值绿但42实例/4资源泄漏已留档；WeakRef拆环后clean日志入库。10项weapon/6240机械件/2625 reload核回归通过，最终GPU780流程pause冻结/两retry/playing，日志无ERROR/泄漏，flow报告独立保存。

完整payload仅诊断events，phase_event仍旧签名。motion_state尚未D推进，不能当完整实时历史热切；O/wants/inspect/dry/player事件/RNG、根唯一写入和双臂IK等继续。见source-weapon-reload-integration.md。

## 生产目标/检视/空击控制

新增motion_controls，接入原spWant/urgent(pressed reload前)、ADS want/logical值、sprintT/hol、inspect3窗口/finger、dry bump及alive早退时钟冻结。Main消费一次look供player和weapon。640步原字面块+4900步原完整O受控空仓运行对照生产选定控制字段，211164比较max1.42109e-14、门槛1e-12。String错误float比较已修正重验。coverage断言每枪ADS188/sprint130/dry14/dead10，rifle inspect210、pistol0，严格24秒边界已命中。

既有weapon10/生产换弹119266/input16回归通过；GPU780流程退出0，pause冻结/两retry/playing，clean日志保存。原O中的parts/flash/drop/D为mock且drop已active，测试初态clock显式对齐；不证明完整O/启动/死亡掉枪。部分S未统一所有旧字段、未D推进，根和双臂仍采样，inspect窗口尚无root消费者。后续recoil/Q/RNG、玩家事件、S初态统一与根唯一写入/IK/parts/drop继续。见source-weapon-motion-controls.md。

## 玩家运动事件与上帧碰撞状态

Player原位置发jump/land/step/rescued，Main交Weapon设置stepEv/jumpEv/landEv。恢复landing shake、phase=.35、rescue shake=.6与JS负半round，保留reset的surface L。Astra定位jump后错误ground参数：现move_capsule传pre-jump previous_ground，stub独立断言。

原字面event段/listeners对实际Player.update+signals+Weapon：47组832比较max1.335144e-6<=2e-6，阈值未改；max可解释为FP32竖速再乘damage7。额外dt0精确force阈值，coverage jump3/land17/step8/rescue1/noevent18/coarse单步6。真实export-world physics功能收到1jump/1land/5step。原player5/weapon10回归通过；最终GPU780流程pause冻结/两retry/playing，无ERROR/泄漏。

source H puddle/level metal resolver及step/land水花灰尘尚待接，默认collision surface只证明当前接口。D尚未消费pending标志，根/双臂仍采样，完整S/recoil/Q/RNG/IK/parts/drop等继续。见source-player-motion-events.md。

## 生产原recoil、统一武器随机流与Q参数

Weapon新增共享S的root_motion，Main移除旧手写相机反馈，接原recoil方法和六路根冲量。SourceRng su算法的legacy4207单流供spread2/shell3/recoil7或6/flash6，共18/17次。quiet burst仅首次取recPhase，reset/equip不重置流。Astra指出的bloom在flash后问题已修，单发guard保证recoil→bloom→flash且weapon-only fallback不重复。

原完整Q+su+两枪recoil独立参考，48发+quiet对native生产methods/Effects：1212比较max1.16974e-7，scalar1e-11/FP32vector2e-6，未放宽。GPU实际Main220帧9rifle3pistol，18/17、单flash/light、bloom一次、旧root未改均断言通过。初探针flow_preview导致双tick/会话重置的rifle-only失败留档，修正后clean。weapon10/controls211164/reload119266回归和780flow通过，日志无ERROR/泄漏。

seed4207并非已还原原global fork，reference.order未数值验证，world impact/FX全事件顺序、partial S、D根/IK/parts/drop等仍未完成。当前根仍采样，冲量未D积分，必须从明确初态接管。见source-weapon-shot-integration.md。

## 默认实时D枪根与双臂差值过渡

Main现入口保存alive→Weapon.update/Q→D一次→animation唯一根提交。Native Player适配空ray{}→null，构造clock从导出S.t继续明确快照。禁生产采样root/key/target和旧holster叠加，两臂每帧恢复sample后乘live*sampleRoot^-1一次，骨proxy/Skeleton继续双写。源O只入口判alive：已修Q内致死当帧仍D、下帧停止。

原D在JS输入前做Native vel量化，对生产adapter1200步maxS1.13243e-14/matrix2.33474e-7；22case66repeat45500过渡检查max3.53883e-7，未放宽门槛。初版测试空Node.name错误留档修正。GPU220帧195live tick的D/commit一次、paused/dead0、render不重复或覆盖、205致死最后一次、玩家事件消费通过；70200次全场景bone/proxy target检查含70武器slot。9rifle+4pistol仍18/17随机/单光单焰/bloom一次/旧root读取。初probe X11 NO GRAB鼠标捕获错误已留档，自动探针禁capture后clean。780完整flow/controls211164/reload119266/weapon10/mechanics6240回归通过。

新video native-live-root.mp4为600游戏帧/10秒/720p60无音轨；明确裁掉MovieMaker第601帧销毁后的灰尾帧，2.8s/8.5s图已检查，hash/probe元数据保存。非性能证明。IK/parts/armTargets/drop、全局fork/完整S与标题、表面FX和整游戏验收未完成。见source-weapon-live-root.md。

## 六机械角色与空仓持锁

新增PartsMotion/View，生产负责rifle bolt/round、pistol slide/barrel/stop/round六角色，动画采样在写入前跳过owned节点。原shot/active parts/cancel/end/reset与reload private变化按原点接线，cancel按reload.weapon。rifle yS0空仓闭栓、pistol .036持锁及空换释放、barrel pitch/z和stop旋转恢复。手部private/弹匣轨迹/IK仍采样或待迁移。

原私有methods/helpers/reload机械片段272ops，3400比较state3.10862e-15/view1.55e-9，不放宽1e-12/2e-6；四个斜坡内点已补，1.59排在1.61前。GPU470帧25hold/2820六role属性检查(位置、旋转、round可见性)通过，70/408图已查看。reload119266/Q1212/weapon10和780flow回归通过，日志无ERROR/泄漏。绑定角色完整原record存manifest。仍有magazine/arms/IK/drop、全局RNG与整游戏验收待完成。见source-weapon-parts.md。

## 实时弹匣轨迹接入

两枪弹匣由原 reload 曲线实时驱动，保留 pinch/carry 逆变换、手枪旧本地枪根旋转和原轴长度。采样器跳过 owned 弹匣节点，取消/结束/reset 恢复原位。独立原函数 1284 步20544通道 max2.91e-7，取消恢复128通道通过。GPU470帧940弹匣/2820既有机械角色检查通过，实际矩阵281行4496通道原JS重放 max2.75e-7，容限2e-6。手部目标、完整IK/drop、全局RNG和整游戏对齐仍未完成。见 source-weapon-magazine.md。

## 手部目标内核，尚未生产接入

新增 weapon_arm_targets.gd，对应两枪原 armTargets/snapArms。握持/扳机20通道、冲刺肩pole、手枪ADS与止动拇指已实现。完整原方法720步48960通道比较max7.79e-8，容限2e-6。原初始/reset参与度1。当前仅独立内核，生产仍采样手臂；reload左手目标、vS混合、Fh求解和骨骼写入待迁移。见source-weapon-arm-targets.md。

## 换弹左手目标接入控制器

weapon_reload_hand.gd 已迁移两枪reload手部p/q/20通道pose/busy，使用真实原di/fit与holds。Kernel按原中部接线并共享MagazineMotion；取消/完成/reset恢复目标。独立与生产Weapon.update两模式各1284步35952通道max2.01445e-7，容限2e-6。画面仍采样手臂，vS/Fh/指骨仍待接入，不能据此声称完整IK完成。见source-weapon-reload-hand.md。

## 手臂混合与IK核心，尚未写生产骨骼

vS正常目标空间/历史混合已迁移，540步37800通道max1.523e-7，含进行中snap/attach中断。保留原c.slerpQuaternions的destination/second别名语义；常规slerp初版失败证据保留。Fh.L双骨骼/手腕核心以double数组迁移，左右/退化/伸展极限1280步48640项max2.054e-15，容限1e-10。指骨与受击弹簧、生产事件/骨骼写入、死亡drop仍未完成。见source-weapon-arm-blend.md/source-weapon-arm-ik.md。

## 正常实时手臂写入生产骨骼

新增weapon_arm_pose/weapon_arms，原手指/helper/trigger、握持冲击和手腕惯性接入。完整Fh840步240240项max5.55e-16；生产D后一次arms.step，shot/magin/cancel/draw/reset按原正常路径接线。Animation跳过所有arm采样，组identity，70骨双写。GPU470帧32900代理+32900Skeleton检查通过，780完整流程pause冻结/最终playing，日志无ERROR/泄漏。新10秒720p60无音轨视频native-live-arms.mp4，已查看截图。死亡drop、公有生命周期、整链初始化/全局RNG及完整图像对齐仍未完成。见source-weapon-live-arms.md。

## 武器死亡掉落数值核心，尚未生产接线

新增weapon_drop_motion.gd，对应oe/le/xe/j的FOV起始变换、细分重力/碰墙/地面反弹/rest缓动、落水隐藏/splash和restore状态。保留跨轮Euler XYZ→YXZ历史与无声audio RNG消耗。原函数1140步36169项max2.22e-15，容限1e-10，物理查询参数/RNG计数均比较。手臂drop和实际reparent/layers/重试恢复待接入。见source-weapon-drop.md。

## 手臂死亡下落目标，待Main触发

vS startDrop/dropUpdate/restore已迁移，保持两侧6次RNG、.15秒放松、重力/角速度、肩pole历史和.9秒/高度隐藏。180步13500项原函数max2.694e-7，容限2e-6。Arms controller支持向Fh提交drop目标、Animation支持两组可见性；尚未由Main触发。已查明掉落mesh需世界层、阴影和weapon→world硬件bias variant切换，不能只改layer。见source-weapon-arm-drop.md。

## 死亡掉落与retry接入

weapon_drop_view将死亡武器重挂世界层，原physics回调/arm drop接线，flash隐藏、阴影和weapon→world硬件bias shader切换，retry恢复父节点/layers/shadow/shader/meta。400帧两枪death/retry，281逐帧门控失败0；含Q回调同tick致死D一次/次帧drop、太阳caster登记和完整恢复属性。780流程pause冻结/最终playing，日志无ERROR/泄漏。已看025/055图。分层证据不等于完整O联合回放/全图对齐，公有生命周期/全局RNG及全游戏验收待继续。见source-weapon-drop-live.md。

## 武器主要公开接口与位置设置

原equip/setVisible/setView/snap/addAmmo/setWetness已接到Native/Animation弱引用桥；隐藏禁火，立即equip保留原公开ads待下一帧更新的同步特点。128组22784原合同+2隐藏扳机检查max0；GPU150帧30检查含真实三档位置按钮、持久化、即时节点/shader副作用通过，已查看032/075图。UI修复长label重叠及重开面板旧choices残留。其余attach/原O联合初始化、全局RNG、quality/DRS与全游戏验收未完成。见source-weapon-public.md。

## 武器canonical冷启动与第四fork

本地原作只加观测su/I5快照确认默认seed4207的level/rain/explosives/weapon四fork，weapon3554171070且I5返回时0抽样。原75字段S字面量等于浏览器pre/postT，修正旧导出3帧六字段漂移。Native默认canonical，历史隔离fixture显式state/seed输入。233构造检查、96shots2424Q比较及470GPU/780flow通过。全局FX/AI随机流、完整O与图像仍未完成。见source-weapon-startup.md。

## 任务root与爆炸物共享随机流

新增source_bootstrap：Main mission/root、weapon/child、explosives/child共享原postbuild流，重试不重seed。5流335位检查、canonical任务1360帧480866比较通过。爆炸物leak原不消费s，现改公共fx.sparks/smoke，180步8180项/40leak、chain RNG state/count精确一致，fuse max1.16e-9。GPU470对象身份/70骨/机械弹匣及780flow通过。level/rain构造结果已烘焙，但rain雷电RNG接线仍待完成；FX Math.random与完整随机时序未完成。见source-bootstrap.md。

## 自然雷电timer与共享rain子流

恢复原rain构造第40641次draw的初始timer31.22965459，Main共享流后不多抽；正常global/rain从0开始，隔离snapshot显式年龄恢复。canonical3000帧294000比较/6000精确RNG、4事件通过，scalar max2.84e-14。实际Main ambient1450帧72.5s，625/1431自然雷电、40645calls，10150检查通过，sky非零34帧；已看0625图。780pause/death/retry回归通过。Math.random方向/其他FX与完整图像仍待对齐。见source-rain-startup.md。

## FX Math.random 共享服务

11 接收点共享独立于 su 的 FX 服务，含 tracer 与两 batch。196 操作/183 draws、25837 检查通过，修正全局 randf 误调用与非零整数下界 near1 越界。GPU470帧11对象身份/301抽样及780流程通过；完整 FX 函数消费顺序和浏览器熵等价仍未证明。见 source-fx-random.md 与 fx-random-review.md。

## 烟尘生成与原 M 抽样顺序对齐

puff 改为先 emit，成功后抽 rotation/rotv/frame，满池无额外消费，保留 Float32 赋值。原 M/u1 提取20步184检查、32draws通过，三档splash数量与GPU470帧回归通过。其余FX全函数顺序继续对齐。

## 溅水完整生成顺序

原go/M/S/k/u1受控tape覆盖9组尺寸/容量、27次splash、重复饱和/clear，共4527draws、14781字段/计数检查通过。水面波纹修正先emit后rotation，满池不多抽，覆盖字段按Float32写入。GPU470实机接入回归通过。仅生成状态/消费顺序证明，非全运动或像素证明。

## 尘土与散射边界

尘土shade顺序与原L对齐；scatter恢复double标量/零分母行为。最终7容量含0与单波纹槽：splash25419检查/10115draws，dust12519/5586，通过；15定向scatter零/近零/端点通过。fixture先量化再u53编码，puff有限性补检。完整其他FX事件联合序列尚待继续。

## 火花与闪光原函数顺序

_sparks按原T/_修正life/size及红绿独立shade，flash对应原w先emit成功后rotation。21组6485draws/12429检查通过；完整原H默认色UP的21组1812draws/13149检查通过。GPU470帧/11共享对象与既有粒子/爆炸物/敌人muzzle回归通过。原A、Q完整联合消费与Main decal顺序仍待修正。

## 命中A完整生成状态与遗漏效果

补金属/敌人共享>.09光源节流、木材shade条件概率flash、法线/入射fallback；Main正常命中改impact后decal。原A+helpers+jg.add 64组/6时间点含跨材质、阈值、zero/tiny、遮蔽系数与碎片RGB，353470检查/56727draws通过。GPU470射击与780流程通过，新增CPU颜色驱动写入经真GPU12通道读回误差0。积水/步行着陆事件、decal联合随机与Q仍未完成。

## 爆炸Q初始生成顺序

flash/火球frame与旋转按emit成功后取样，火花life-width顺序、Float32覆盖、地面ring和最初floor传递对齐。高速spark使用double散射中间值，原阈值未放宽。原Q/helpers/jg.add48组122052检查/68808draws通过。真GPU330帧爆炸结束清空，031/045图已查看。smolder原oe/24槽复用、decal联合与像素对齐待继续。

## 余烟固定槽与更新生命周期

恢复原G/oe固定24槽首空位复用与槽序更新，clear只停活跃槽，保留严格time>ttl/acc>1。78步×2容量54176检查/6732draws通过。原Q补rawsize signal与post-generation计数，最终122484检查通过。固定槽后GPU330爆炸末清空，780流程reset emitters0/暂停冻结通过。仅smolder，其他generic emitter kinds及联合粒子运动/像素仍待迁移与验证。

## 地面积水与步行着陆FX

原Dw1024遮罩字节完全一致，Bg/Vg查询12879点90154检查通过。Main/player/FX共用query，积水命中抑制弹痕；step/land原回调12750检查/1818draws通过。实机240帧实际wet step/wet land/dry hard land数量和两命中材质检查通过，780流程通过。首次路线过短失败已保留。仅高质量1024；metalRects与其他质量、完整移动/图像仍待继续。见source-ground-queries.md。

## 默认关卡metalRects与玩家H

Playwright原版观察副本取得55区域和12978 live原查询，实际响应hash绑定。f64无损边界25957检查、原H1140例通过。Main实际绑定110区域/接触优先检查及240帧wet/dry事件回归通过，mask90154回归通过。默认4207金属地面分类接齐；其他种子/质量及完整世界运动像素仍待验证。见source-ground-metal.md。

## 弹痕几何、A联合随机与FP32 normal

原Jg独立178步212138检查/531draws，原A+真实Jg/Main路由64组399796/57560通过。修unknown/负size语义、double顶点、F32淡出和A的normal fallback。局部CUSTOM2 raw normal只对fx_decals启用，Standard/alpha生产vertex31GPU诊断通过，off control显现oct16差异；真实射击420帧末清空。整游戏事件交错/最终像素与其他系统验收仍未完成。见source-decals-joint.md。

## 曳光烟迹与同步发射链

补F五团轨迹烟，Yg恢复F32状态；玩家/敌人impact同步FX后爆炸物，再tracer/shell，猎犬muzzle时机修正。le更新恢复lit→add→Yg→debris→shell及非正dt处理；热烟归Weapon原位置。F169800、smoke335、order115通过，最终480帧87实机检查及780流程通过。通用ph/I输入和完整帧/像素、弹壳旋转仍待继续。见source-tracer-chain.md。


## 弹壳 Float32 与 Euler 历史

已修正初始 XYZ、落地后保留 ZXY、状态 Float32 写回以及 Three compose 的非归一化四元数矩阵。原版方法 607 步、40,205 检查通过；范围和局限见 [source-shells.md](source-shells.md)。完整游戏复刻仍未完成。


## 原版画面对照与任务 HUD

原版浏览器确认棚屋彩色竖纹也存在，未据此修改材质。任务提示已恢复原版边线、字体层级、方框计数、46 字/秒显示和清空逻辑。原版 DOM 10 步对照及 12 项检查通过，480 帧实机回归通过。CSS 动画、排版像素和其余 HUD 仍待对齐，见 [source-objective-hud.md](source-objective-hud.md)。


## 罗盘与无线电字幕布局

修正罗盘窄屏宽度、字距/行高/字体、目标代号与距离分组居中。无线电改为原版居中上下布局、逐行底板和 .3 秒渐变。640 组投影与 720 帧无线电逻辑回归通过，780 帧实机流程通过。详细范围及未对齐项见 [source-navigation-radio-layout.md](source-navigation-radio-layout.md)。


## 开场地点字幕

替代固定两行 Label，恢复原版响应式位置、字体层级、边线、按内容收缩宽度和 28 级裁切揭示。原 CSS 实际浏览器 14 点采样对照通过，780 帧实机流程通过。字体像素、CSS 反向过渡缩短及移动端安全区仍待核对，见 [source-location-card.md](source-location-card.md)。


## 来袭警告与普通消息

恢复原版响应式警告、关键帧闪烁和字距动画，以及消息底板。分开隐藏 HUD 时暂停的倒计时与继续运行的 CSS 动画时钟。原版 CSS/方法 352 项对照通过；实际 360 帧提示生命周期与 780 帧游戏流程通过。范围和失败记录见 [source-announcements.md](source-announcements.md)。


## 继电器交互提示

接入实际任务提示信号，恢复淡出、SVG 两位小数进度规则和原版 label 布局。原 setPrompt 203 项对照通过，360 帧实际 E 键切断继电器与提示退出通过，绘制日志干净。范围见 [source-interaction-hud.md](source-interaction-hud.md)。


## 正常主场景整局状态链与结果卡片

1100 帧实际 Main/GameFlow/UI 整局链通过：提前撤离被阻止、实际 E 切断三处目标、撤离标记、船只完成、延迟结算及 Redeploy。受控位置/无敌，不是步行或人工战斗验收。结果卡片恢复独立评分、统计分隔和死亡配色。范围见 [full-mission-native-chain.md](full-mission-native-chain.md)。


## 实时画质设置

接入原版四档设置与 render.setQuality 对应的分辨率/MSAA/阴影/AO taps/体积光 steps/反射/motion。295 项预设和尺寸对照通过，460 帧实际切换与物理窗口缩放通过。原 DRS、设备自动选择、启动分档资产和全像素验收仍未完成，详见 [source-quality-settings.md](source-quality-settings.md)。


## 动态分辨率控制器

接入原 R(G) 的墙钟统计、降比例、最低比例自动降档和延迟恢复，保留手动偏好。7494采样、82340检查通过；720呈现帧受控实机集成及8.37秒真实时钟观测通过。真实重负载性能、设备初始选档与首帧像素连续性仍未验收，见 [source-dynamic-resolution.md](source-dynamic-resolution.md)。


## 键盘备用操作与动作集合

补齐 Arrow/IJKL 转向、Enter射击与NumPad切枪，以物理键位和原动作集合保留别名释放行为，失焦清理输入。31绑定/435原版比较及300帧实际事件通过。手柄、触屏及完整GUI/硬件输入验收未完成，见 [source-keyboard-input.md](source-keyboard-input.md)。

## 手柄输入与菜单接入

补齐原版摇杆曲线、加速、冲刺锁定、X 上下文锁定、瞄准减速、菜单导航及震动事件参数。5848 项原版比较与 620 帧实际 Main 标准快照注入通过；接入后键盘 435 项数值/300 帧事件及 1100 帧完整任务回归通过。实体控制器、SDL 映射、震动电机、标题操作说明与完整菜单视觉仍未验收，见 [source-gamepad-input.md](source-gamepad-input.md)。

标题操作说明现已补齐同时展示的键鼠/手柄/触屏内容，控制面板补齐原版 30 行按键表并可滚动。GPU 截图完成，960×540 隐藏与1280×720显示标题提示通过。完整标题/标签页视觉、HiDPI和触屏输入仍未完成，详见同一记录的操作说明补齐段。

## 触屏输入接入

接入原版58半径摇杆、0.0052视角倍率、自动冲刺、开火拖动、AIM切换及屏幕动作按钮。73组原事件/438项比较通过，250帧原生多点事件实机链通过，修正模拟鼠标重复开火。完整触屏HUD、实际设备、菜单点击和USE任务链仍待验收，见 [source-touch-input.md](source-touch-input.md)。

触屏增量已移植生命/电台/击杀消息/罗盘布局与USE提示，480帧事件链验证跳跃及一处继电器切断；240帧实际GUI触摸点击完成Settings/Close/Deploy。实际设备、全设置操作、多尺寸布局、击杀与备用武器重叠的原版配对及Reload仍待验收。

触屏事件链现为760帧，补充RLD开始/完成/备弹扣除及三指取消清理，全部通过。面板已添加Settings/Controls双向标签，240帧原生GUI触摸切换通过；完整样式、焦点和全设置项仍待校准。

## 设置面板数值和焦点

增加灵敏度/FOV实时读数及原画质/难度说明；打开面板记录焦点，Tab/ShiftTab循环，Escape关闭后恢复。50帧实际键盘事件验证通过，240帧触摸与620帧手柄回归通过。样式、全屏文案、多尺寸及跨进程设置持久化仍待验收，见 [source-settings-panel.md](source-settings-panel.md)。

配置加载现按原版iL校验类型/枚举/有限数字/真值，31输入217检查通过。独立配置write/read两个进程验证七项非音效设置恢复及实际应用，另验证错误类型文件启动回退。默认用户配置未改动；完整GUI写入及多系统权限行为仍待验收。

设置改为原版右侧440宽全高抽屉、固定页头与内容滚动。四种实际窗口/捕获尺寸通过，含320×568竖屏；修正默认宽高比黑边与面板字体低采样模糊。面板打开期间实时改宽、HiDPI及其他HUD/标题响应式仍待完成。

标题主栏已接入原宽度/高度断点、窄屏按钮与模式选择，补上Controls入口。静态原HTML/CSS/本地字体Chrome对照确认桌面图例挤压与低高度原版上部裁切，四尺寸原生按钮边界及实际截图尺寸通过；触摸部署链通过。B4/图例kbd/字体字距/黑栏及完整像素校准仍待完成，见 [source-title-layout.md](source-title-layout.md)。

标题黑栏已恢复，浏览器7个CSS时间点对照通过；实际标题边缘纯黑、设置时保留、部署时退出和最终隐藏通过。修正遮罩顺序造成深灰的像素问题。反向动画、安全区域和减少动态偏好仍待验收。

图例现由原DOM导出的215字形/20结构原生绘制，包含kbd框、分隔线及组名，四尺寸边界/隐藏条件通过。同背景浏览器/原生差异图已生成；抗锯齿和文字阴影仍未像素一致，详见标题布局记录。

B4标牌与单位/地点时间现为原生按原字体/字距/内边距绘制，flex换行高度在四尺寸下与浏览器差小于0.03px，桌面/竖屏截图检查完成。整页垂直位置及字形像素仍待校准。

正文与字标现保留小数字号、原行高和字距；修正字标重复负边距。四尺寸正文高度/标题字号原DOM比较通过，桌面Deploy纵坐标误差约0.63px，竖屏仍约4.25px。整页字形及按钮像素仍未一致。

标题按钮恢复主/普通/分段三类字距、颜色与焦点绘制。五状态GPU填色像素、四尺寸布局、真实触摸入口及模式/难度选中联动通过。分段边框合并、标签与CSS状态过渡仍待校准。

选择区标签列/字距/模式说明行高与1px边框重叠已校准；四尺寸128个矩形分量对照最大差0.01874px，主要按钮纵坐标差均小于0.05px。字形、焦点像素与CSS状态过渡尚未完整一致。

标题btn颜色接入原0.12秒ease、预乘alpha和逐属性时钟；168通道浏览器采样及14个GPU中间填色像素对照通过。修正主按钮hover边框颜色。反向缩短、中断组合及真实调度仍待验收。

## 蒸汽与余烬发射器

扩展原共享24槽发射器池，补steam/embers并保留smolder；28426项原版比较通过，旧余烟54176项回归通过。300帧实际生产特效链验证移动/到期/停止/清理，已留截图。fire/drip及原特效展示场景仍未完成，见 [source-ambient-emitters.md](source-ambient-emitters.md)。

持续fire已迁移，含主火焰、第二烟/余烬循环和原闪动持久点光；124020检查及30034随机消耗对照通过。240帧Main验证shader数据与光槽生命周期，冻结模拟的点光开关截图显示世界/枪械照明差异。drip与完整展示场景仍未完成。

drip已接入下落、原计时、固定地面涟漪与三颗溅射；31594检查/3947随机消耗对照通过。360帧实际FX链验证移动落点和TTL，采用固定随机带确保复现。完整展示场景、通用smoke选项及整局效果源时间线仍待完成。


### Generic smoke numeric options (2026-11-16)

`impact_effects.gd::smoke` now follows original `I` numeric option semantics: falsy size/life/alpha/count use defaults; positive fractional count follows `ge < me`; explicit null rise becomes zero. Particle position and velocity arithmetic stays double until the final Vector3 assignment instead of rounding each intermediate vector operation.

`tools/smoke_options_reference.cjs` extracts and executes original `I` directly, replacing M with an argument recorder (does not test downstream particle allocation). `tools/verify_smoke_options.gd` invokes production smoke with an overridden puff recorder. Eight cases, 209 field checks, maximum error 1.05437e-7, no failures: `evidence/smoke-options-verification.json`. Source NaN count serializes as null in JSON; both are falsy defaults, so this proves resulting default behavior rather than native NaN ingestion. Default/custom, zero, fractional and negative counts, explicit null and zero rise covered. Full CSS color parsing/cache, arbitrary JS object coercion, and downstream shared particle RNG sequence remain separate incomplete work.


### Generic smoke source color parsing (2026-11-16)

Production smoke now uses `scripts/fx_color.gd`, reproducing original ph/e5 cache semantics. Number hex, three/six digit hex strings, original RGB integer/percentage grammar, HSL, all 148 original named colors, linear arrays, native Color/Vector3 and source-style isColor dictionaries are supported. Null/default and linear inputs bypass the cache. Invalid styles/types retain the previous number/string color; CSS alpha is ignored as in source. Source sRGB transfer constants are used rather than engine color conversion approximations.

`tools/fx_color_reference.cjs` runs literal original ph with original bundled THREE.Color and exports its named-color table. Sequential 179 cases / 537 channel checks pass with maximum double error 1.11023e-16 (`evidence/fx-color-verification.json`). Original warnings for unsupported styles/ignored alpha appear during reference generation; native parser reproduces color results without emitting those warnings. Valid three-component linear arrays tested; malformed/short arrays and exotic JavaScript property coercion remain unverified. This check covers color parsing, not full rendered smoke or shared emitter RNG. Numeric smoke regression remains 209 checks, no failures.


### Generic smoke real particle pool golden (2026-11-16)

`tools/smoke_pool_reference.cjs` executes literal original I/ph/M/u1 with bundled THREE.Color/Vector3 and a deterministic shared tape. Native `tools/verify_smoke_pool.gd` overrides only shade raycasting (.2), calls production smoke and puff with the real SaltlineParticles pool, and compares all 31 generation fields. Two capacities (2/64), 20 calls each, saturation, clear/reallocation, zero defaults, fractional/negative counts, null rise, velocity, CSS color cache and linear colors: **7,640 checks, 616 RNG draws, maximum error 3.55272e-15, no failures** (`evidence/smoke-pool-verification.json`). Source is immutable SHA 756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8.

This proves generation plus RNG consumption even when pool allocation fails. Clear/reallocation is covered; age expiry and free-list reuse during simulation, combined whole-game random interleaving, source double-precision positions beyond native Vector3 input, and GPU pixels are not established by this fixture. No additional production change was needed after the preceding option/color fixes.


### Generic smoke lifecycle and renderer input golden (2026-11-16)

`tools/smoke_motion_reference.cjs` extends the literal source I/ph/M/u1 fixture with actual original u1.update. Capacity2/64 pools each run two190-step simulation sequences with zero dt and a .5s step, interleaved smoke at steps50/90/130, age expiry and source free-list reallocation, sorting by camera distance, wind, turbulence, drag, rise, and clear. Native comparison uses production SaltlineParticles.update, compares active particles in sorted order plus all16 quad attributes submitted to rendering. **192,611 checks, 996 shared RNG draws, maximum error4.76837158203125e-7, no failures** (`evidence/smoke-motion-verification.json`). Shader-input size/alpha/color/rotation match within the5e-6 tolerance. No production motion changes were necessary.

The source free-list index itself has no native equivalent and is not compared; observable particle ordering/state after expiry and re-emission is compared. Position is exactly representable Vector3(1,2,3), shade is fixed. GPU blend/lighting/depth, full-world RNG interleaving, arbitrary double input positions, and final browser/native screenshot parity remain unverified by this numeric fixture.


### Generic smoke GPU runtime (2026-11-16)

`tools/verify_smoke_runtime.gd` boots actual Main on RTX4070SUPER/Vulkan Forward+, freezes gameplay/AI, uses source-seeded FX tape, and emits12 production smoke puffs in three CSS color formats. Frame1/30/90:12 live particles and12 renderer quads; frame210:0/0; total215 frames and144 RNG calls, failures[]. Evidence `evidence/smoke-runtime.json`, screenshots `smoke-runtime-001.png`, `-030.png`, `-090.png`, `-210.png`. Frame030 visually inspected: translucent smoke visible in front of the green container without opaque quad borders. This confirms native runtime rendering, not original-browser pixel parity, isolated lighting correctness, or realtime performance (fixed simulation steps).

Initial frame030 visual impression suggested clipped objective text. Rechecked against frame090 and original update block: this is the expected46 characters/second typing animation, not demonstrated clipping. Frame090 shows the complete objective. The earlier diagnosis is withdrawn; full HUD responsive fidelity is still unverified.


### Objective typing diagnosis correction (2026-11-16)

Frame030 smoke screenshot has23 objective characters after.5s; frame090 visibly shows complete CUT THE THREE UPLINK RELAYS. Literal source update block at84016 advances floor(accumulated dt*46). `objective_typing_reference.cjs` executes that block, and `verify_objective_typing.gd` compares production HUD over130 steps including zero/large dt and objective replacement:260 checks, no failures (`evidence/objective-typing-verification.json`). No production objective change is justified by these screenshots. Earlier suspected clipping is withdrawn. This is a timing check, not full CSS layout parity.


### Shared smoke/tracer color parser (2026-11-16)

Source KP showcase inspection exposed that generic tracer F also uses global ph, shared with smoke. Native tracer previously accepted numeric/linear colors only and did not share CSS parse state. Production impact_effects now uses one `fx_color` parser for both APIs, supporting source CSS styles and floor-before-hex numeric parsing. Six integration assertions verify tracer-to-smoke and smoke-to-tracer invalid-style cache retention and default fallback without mutation (`evidence/fx-shared-color-verification.json`). Existing literal F/ph/M/u1/Yg trail regression:169,800 checks,366 draws,no failures after change (`evidence/tracer-trail-verification.json`). Full KP showcase scene/timeline and remaining ph consumers (dust/muzzle APIs) still need integration; this change does not claim showcase complete.


### Generic muzzle flash public options (2026-11-16)

Added production `impact_effects.muzzle_flash(position,direction=UP,options={})`, adapting original H scale/color API while preserving existing enemy_muzzle_flash callers. Color now uses shared ph cache with smoke/tracer; omitted direction is UP and explicit near-zero direction falls back FORWARD as original. Four flash layers and axial particle derive their color from the parsed input; spark/smoke/light colors remain the original fixed values. Source H light stays16756832 regardless of custom color.

`muzzle_color_reference.cjs` executes original H and bundled THREE.Color for7 scale/color sequences including hex, HSL and invalid retained cache; `verify_muzzle_color.gd`:812 comparisons,no failures,max1.00985e-6 under1e-5 threshold. Deterministic emission configuration is checked; random spark velocity/lifetime only constrained to source ranges by this fixture. Full randomized H baseline is separately retained. Complete KP showcase assembly/timeline remains pending.


### KP showcase timeline module (2026-11-16)

Added `scripts/fx_showcase_timeline.gd`, original KP/C scheduler with synchronous dispatch callbacks. Preserves impact8-index wheel (.09/.13 catch-up while), tracer .16/.45 timer, shell .22 timer, explosion2.4/3.5 timer, first explosion.6/3.4 delay, size1/2/3 sequence or fixed override, and per-frame fxhold muzzle pair. Dispatch stays synchronous so future production effect callbacks consume shared RNG before subsequent target samples. Full scene adapter is not yet connected.

`fx_showcase_reference.cjs` executes literal original C with bundled THREE.Vector3; effect/impact callbacks are recorders. Ten mode/hold configurations,600steps each, zero and.8 dt, fixed explosion size:100,564 comparisons, max4.63506e-7 (Vector3 float boundary), no failures (`evidence/fx-showcase-verification.json`). An initial run using JSON-decoded1/60 shifted exact impact timer boundaries; native fixture now reconstructs exact1.0/60 from integer frame identity, matching source arithmetic. This is scheduler verification only; callbacks do not consume real effect RNG, raycast or render. KP geometry/materials, physics, impact targeting, startup prewarm fxt and fxage freeze integration remain pending.


### KP impact targeting and effect adapter (2026-11-16)

Added `fx_showcase_impact.gd`, original I eight-target wheel with alternating shot origins, enemy path bypass, raycast misses, water/dirt overrides and synchronous tracer-before-impact order. Literal original I against recorded mock raycast:64 calls,2,278 comparisons,max4.90604e-7,no failures (`evidence/fx-showcase-impact-verification.json`). No actual scene collision or final pixels covered by that fixture.

`fx_showcase.gd` now adapts timeline and targeting to actual Main tracer/muzzle/shell/explosion/_impact_visuals and starts original steam/fire/drip for all/impact modes. This adapter is new and has not yet been runtime validated or exposed as a launch mode; the dedicated geometry/material/collision setup and camera still need implementation. Whole showcase is not complete.


### KP effect adapter GPU integration (2026-11-16)

`verify_fx_showcase_runtime.gd` now runs actual adapter on Main for360 fixed60Hz frames with frozen AI:47 impacts,60 tracers,28 shells,1 explosion,failures[] (`evidence/fx-showcase-runtime.json`). Original all-mode persistent steam/fire/drip start alongside timed effects. GPU RTX4070SUPER Vulkan Forward+ run completes without script errors. `fx-showcase-integration.png` is integration evidence on the existing map, not original showcase geometry or pixel parity. Source Main frame processing overwrites camera/HUD; probe corrected to reapply display camera/HUD after Main processing. Dedicated KP geometry/collision remains missing and gun viewmodel is still present; complete showcase launch path is pending.


### KP literal rounded meshes and collision (2026-11-16)

`tools/export_fx_showcase.cjs` executes literal original Ei using bundled THREE.BoxGeometry/Vector3 and exports KP's three exact configurations (concrete2.6x2.2x.3,r.02; paint_blue2.2x2x.08,r.01; wood_pallet1.2cube,r.015). Each96vertices/324indices, original position/normal/UV Float32 values, triangle winding swapped for Godot. Source/function hashes stored in `assets/export/fx-showcase-geometry.json`.

`fx_showcase_geometry.gd` builds native ArrayMeshes, binds existing source material by first matching name, and appends original KP three AABB collision bounds/surfaces. Runtime probe includes all3 meshes. Initial run failed because new boxes lacked native required playerOnly flag; fixed explicit false. Rerun360 GPUframes passes:47 impacts,60tracers,28shells,1explosion,no script errors. This is still additive to original map. Exact source material identity (wood has two exported instances), isolated original showcase scene/camera/viewmodel suppression, bounds rays and source screenshot pairing remain to verify; do not claim complete showcase parity.


### Isolated KP scene GPU view (2026-11-16)

Added `fx_showcase_geometry.isolate`: hides imported geometry/static lights, resets collision boxes, builds KP3objects and80x80 concrete plane (no cast shadow). Runtime probe selects world camera as current, suppresses weapon camera cull mask and HUD.360frames pass47impacts/60tracers/28shells/1explosion. Report explicitly confirms camera(.3,1.6,7.2) and current world viewport camera path. Updated `fx-showcase-integration.png` visually inspected: standalone3objects, steam/fire/drip, impacts/explosion, no original container geometry or gun.

Visual limitations remain: floor appears waterlike with strong wave/reflection features; panels are unexpectedly dark. Main-created sea/environment services and source ground/puddle material customization were not reset by hiding imported geometry. This scene is not yet accepted as original KP rendering. Next audit must isolate source showcase boot's stub ground/backdrop/weather behavior and material identity rather than compensate with arbitrary lighting. Prior additive screenshot camera fix alone did not establish correct view; current make_current plus isolation gives direct visual/current-camera evidence.


### KP missing vertex-color attribute fix (2026-11-16)

Source Ei geometry has only position/normal/uv, while cached base materials carry vertexColors=true from exported map use. THREE program selection gates USE_COLOR on geometry attributes; native generic shader's explicit vertex_color flag instead multiplied missing custom HDR color (zero). Added showcase-local duplicated material with vertex_color=false for Ei meshes and ground, preserving source imported map materials. GPU360frame rerun succeeds with unchanged47/60/28/1 counts, no failures. Screenshot re-inspected: concrete surface, blue paint and wood grain now visible instead of near-black slabs; plane reads concrete after the same correction. Initial waterlike appearance was partly this black material defect and must not be assumed to prove sea geometry remained visible. Environment/rain/service parity still needs source showcase comparison.


### Standalone FX showcase entry point (2026-11-16)

Added `scripts/fx_showcase_runner.gd` and `docs/fx-showcase.md`: all/impact/tracer/explosion modes, muzzle hold, fixed size,30Hz prewarm,60Hz explosion-age freeze, optional fixed step/frame limit/capture, Escape exit. Reuses Main initialization, isolates geometry/collision, disables gameplay HUD/viewmodel and removes original puddle query from impacts. GPU explosion mode age.5,size1.2 ran30frames with one explosion and frozen=true; screenshot `fx-showcase-explosion-frozen.png` inspected. All/prewarm1s also run. No claim of original environment/time/global RNG parity; boot still reads existing settings and initializes whole game services before isolation. Dedicated source-showcase boot remains future work.


### Original browser showcase evidence and freeze correction (2026-11-16)

`tools/capture_fx_showcase.cjs` runs original immutable HTML in Chrome/WebGL at show=fx/fxshow=explosion, invokes original __setShot(fxage=.5,fxsize=1.2), captures original scene listing and PNG. No page errors;18 meshes/lights, lit55/add55/debris20. Evidence `fx-showcase-source.json` and `fx-showcase-source-explosion.png`. Actual original screenshot confirms wet concrete normal wave appearance is present in source; it is not by itself proof of stray ocean geometry. Source scene has no rain mesh, stubs ground/backdrop.

Standalone native runner now hides rain/rainSplash after Main updates. Original KP freeze stops FX update only; renderer/light/environment time keeps advancing. Corrected native runner to call Main._process(step) even with frozen FX (previous zero froze light decay incorrectly). GPU30frame explosion/frozen rerun passes and updated screenshot inspected. Original/native screenshots use different entropy and renderer elapsed time; no quantitative parity claim. Direct original capture currently uses3 step frames after snapshot with real dt, native30 fixed frames, so lighting/time differences remain expected and need controlled alignment before comparisons.


### Source/native fixed FX tape explosion capture (2026-11-16)

Original Et captures Math.random at module creation. Browser collector now installs a pass-through wrapper before load, enables deterministic8192-value tape only around __setShot(fxage=.5,fxsize=1.2), then disables it for renderer internals. Native runner accepts --fx-tape and shares it across impact/add/lit/debris/explosion/decals/shells/tracers. Original and native snapshots both consume **1,403 draws**, retain **lit55/add53**, at source FX age.5. Source errors[]. Updated `fx-showcase-source.json`, source PNG and `fx-showcase-native-tape.png`. Native GPU log `/tmp/fx-tape-native.log` records1403/55/53. This now controls FX entropy but not renderer clock/light decay/sky/exposure/service history. Snapshot draw count and particle count agree; full particle state correspondence and image error still need direct paired comparison. No completed pixel parity claim.


### Showcase projection pin and marker verification (2026-11-16)

Runner now pins original renderer camera74deg,near.08,far900 each view update, avoiding imported title/game settings projection. Same-tape GPU rerun still1403draws/lit55/add53. Updated native tape screenshot inspected: board extents align visually with source (previous extent mismatch was observable before pin). `showcase_camera_reference.cjs` constructs bundled original THREE cameras for both KP views, projects36 world markers. Native `verify_showcase_camera.gd`:72 coordinate checks,no failures,max3.63325e-5pixels at1280x720. Numerical marker check proves camera math/config, not full postprocess image alignment. Remaining visible ground flash intensity/color differences require matched renderer dt/light elapsed age before shader changes.


### Matched renderer light decay evidence (2026-11-16)

Original collector now sets dt=0.016666666666666666 and captures original light intensity/color/ttl plus camera projection. Native runner writes durable `fx-showcase-native-state.json`, including source-unit intensity and linear radiance. Both3render frames after fixed FX.5s snapshot: core144,afterglow58.6666666667,TTL.03/.4; maximum intensity error5.68435e-14,maximum linear radiance error2.84205e-6 (native color conversion/Float32). `fx-showcase-light-comparison.json` stores differences for all6slots. RNG1403 andlit55/add53 stillmatch. Brightness difference cannot be attributed to source light decay values at this snapshot; investigate material/light-service binding, direct sun/IBL/post environment next. This report does not prove light transport or pixel parity.


### Exact showcase ground geometry (2026-11-16)

Exporter now executes bundled THREE.PlaneGeometry(80,80).rotateX(-PI/2) for original showcase ground and exports its Float32 position/normal/UV/index alongside Ei meshes. Native geometry loader reuses a shared ArrayMesh builder for all four objects instead of Godot PlaneMesh defaults. This removes an unverified UV/winding equivalence assumption. GPU same-tape frozen run passes1403draws/lit55/add53, intensity144/58.6667 unchanged. Updated native screenshot visually inspected; wet ground highlight remains too bright relative to source, so exact plane conversion does not resolve the entire lighting difference. Continue actual material property/light/post bindings audit rather than adjusting brightness arbitrarily.


### Actual showcase material scalar and exposure audit (2026-11-16)

Original browser capture now includes MeshStandardMaterial runtime color/roughness/metalness/vertexColors/sl wet+macro+uv+interior and render exposure/auto/environmentIntensity. Native runner records four showcase surface uniforms and sun/local active flags. `tools/compare_showcase_materials.py`:78checks,no failures,max scalarerror2.38419e-8. Source exposure1/auto=true, native same. Source environmentIntensity2. Native custom solar/local/IBL ready bindings alltrue. This excludes an unproven scalar mismatch explanation; it does not establish texture/BRDF/environment-image or exposure GPU history parity. Existing source/native highgloss difference remains open. Astra read-only adviser requested for shader/render-chain diagnosis; no speculative brightness adjustment applied.


### Corrected current image diagnosis and measured residuals (2026-11-16)

Astra independently inspected current on-disk images and found the previously obvious highlight excess no longer present. Root repeated pixel measurement and agrees. Source hash1039ea449c783a7c510086e943e040d248cdd4887c21677f5f88446f750294b7; nativea0dfd55d7fd93a487038b97b711e6502677ce581ba404ae49a89c85246af6f3d. Earlier strong brightness impression referred to source capture before exact dt was set; continuing that diagnosis after source screenshot replacement was stale and is withdrawn.

Reproducible `tools/compare_showcase_pixels.py` writes `evidence/fx-showcase-pixel-comparison.json`: encodedRGB fullMAE.00985664 (2.51344/255), highlightMAE.00436294 (1.11255/255), highlight meanluma delta+.00070491, ground meanluma delta+.00084396. EffectROI MAE.01831942,max.19215686; fullmax.22352941 mainly not highlightcore. Do not adjust light intensity to chase a nonexistent large brightness error. Residual grain/sky/history and particle/debris edge differences remain to investigate. One fixed snapshot is not whole-game render acceptance.


### Explicit render warmup experiment (2026-11-16)

Added optional --fx-render-warmup=N and setup_ready guard so actual Main rendered updates can run before snapshot without concurrently advancing normal showcase loop. Default remains0. Three warmup frames give final world_time.1 matching original6frames*.0166667, while FX1403draws/lit55/add53 and light144/58.6667 stay unchanged. However pixel fullMAE **worsens .00985664 -> .05738**, highlightMAE .00436294 -> .04632534. World-time equality alone does not align GPU exposure history. This is an experiment, not accepted render repair. Preserved previous images/state/report as fx-showcase-before-warmup-*; current native PNG/state/report correspond warmup3. Investigate GPU exposure history with manual-exposure A/B before changing BRDF/light. Source init/warm frame scheduling and native viewport history must be measured, not inferred from CPU time.


### Astra timing review and exposure diagnostic controls (2026-11-16)

Astra read-only review identifies: original shot/show post uses fast=true (after initial2 passes uRate=.6,uVisRate1), while Main always ticked false; FX clear preserves clock, original boot3frames add.05 before snapshot (native previous.5 vs source.55 FX clock); grain time differs; UPDATE_ALWAYS feedback may render again during capture. No clear duplicate solar/environment addition found.

Production Main now has showcase_render defaultfalse; standalone runner sets true and post_pipeline.tick uses that flag. Normal gameplay default retains slow adaptation. Runner freezes all SubViewport update modes after final process-frame wait before force_draw, preventing the explicit capture redraw from advancing feedback viewports. This does not yet count every actual earlier GPU pass. Added --fx-manual-exposure and browser SALTLINE_FX_MANUAL with separate manual filenames. Paired exposure.7/autooff passes GPU but fullMAE.01700494,groundMAE.07403632; fast-auto+3warmup fullMAE.01650873. Controls alone do not establish parity. Current native-state JSON corresponds latest fast-auto run; manual native image and source-manual JSON retain manual case. Artifacts fx-showcase-manual-comparison.json/fx-showcase-fast-auto-comparison.json state scope.

Next gate: compare actual particle state/quads with matching FXclock; separately instrument actual adaptation prev/lum/rates/output/pass counts and slExposure. Source exposure formula uses manual*mix(1,clamp(pow(.12/max(adapt.r,1e-4),.85),.6,2),auto); do not confuse Q9 average .002 floor with this denominator. Do not tune material brightness to compensate for unaligned clocks/history.


### Actual source/native GPU instance attribute comparison (2026-11-16)

Original collector exports live fx_lit/fx_add instanced geometry aPos/aAxis/aCol/aMisc, all16 Float32 attributes per particle. Native runner records production pool quads converted to original GPU Float32 boundary. With3 startup frames and fixed tape, source FXclock(before .05 + snapshot .5)=.55; nativeclock.55. Source/native55lit+53add,1403draws agree. `tools/compare_showcase_quads.py` checks **1,728 attributes** plus pool shapes/clock/RNG;maximum1.90735e-6 under3e-6,no failures (`evidence/fx-showcase-quads-comparison.json`). Source/native JSON hashes included. Lit positionmax5.36442e-7;addmax comes fromcolor1.90735e-6. This is direct live GPU-input evidence, stronger than count-only. It narrows this snapshot's residual to shader/texture/blend/depth/post stages rather than unmatched CPU motion; no whole-game or other-tape acceptance claim. Full quad arrays stay in JSON; console output now omits them.


### Actual adaptation GPU-output traces (2026-11-16)

Original collector wraps real renderer.render of fullscreen Mesh (not just scene children) and reads HalfFloat target after Q9. Original frames4/5/6 uRate.6,uVisRate1 outputs r=.281005859375/.297607421875/.294189453125. Native runner records post_draw adapt/history pixels. Initial process_frame scheduling collapsed CPU steps into fewer actual draws; frame_post_draw coroutine wait then stalled and that owned process was stopped. Replaced with explicit UPDATE_ONCE viewport drawing and initialized-scene process_frame flush; each CPU step requests one render. Actual native snapshot outputs .2822265625/.298828125/.29541015625 (each +.001220703125), with matching .6/1 rates and real history chain. Raw callbacks include an unchanged frame0 event, so event count alone is not claimed as exact Q9 pass count. Source first3 outputs not captured yet.

`fx-showcase-adapt-comparison.json` records raw/paired output and computed actual exposure multipliers. Remaining lum difference is metering-stage input/history, not yet isolated to a shader. Current native-state includes latest trace run (no matching new PNG in this run); previous PNGs are historical and must be paired with their recorded state/hash. FX clock.55,RNG1403,lit55/add53 maintained. Complete-render acceptance remains open.


### Paired capture after actual render-step correction (2026-11-16)

Fresh native screenshot/state taken together using3warmup+3snapshot renderer updates and frozen feedback capture. Source hash1039ea449c783a7c510086e943e040d248cdd4887c21677f5f88446f750294b7; native86ed93b3606368c198af17a71c0f215f93c413634eec64aed8320f3500ac0332. Recomputed pixel report fullMAE **.00253648 (0.64680/255)**;groundMAE.00122651;highlightMAE.00097578 (0.24882/255);skyMAE.00100667;effectROI.01522199. Same run live quad comparison1732checks/no failures,max1.90735e-6. Rates/history now explicitly recorded, FXclock.55 andworldtime.1. This is stronger paired evidence than historical unpaired screenshots. Local max.21960784 and effectROI residual remain; inspect particle/debris sampling/geometry/softdepth before accepting visual parity. One explosion size/age/tape/camera is not complete showcase or game acceptance.


### Explosion age matrix and independent capture provenance (2026-11-16)

Collector accepts SALTLINE_FX_AGE/SIZE/CASE, writing case-specific source screenshot/state. Runner accepts --fx-state, records snapshot_age/size and capture path/SHA256. Native0.1s and1.5s paired captures withsize1.2 andsame tape each use3warmup+3renderframes. `evidence/fx-showcase-age-matrix.json`: age.1 source/native1367draws,1794checks,maxquad1.90735e-6,fullpixelMAE.00298108 (0.76017/255);age1.5 source/native1451draws,722checks,maxquad7.15256e-7,fullpixelMAE.00272693 (0.69537/255). Bothno failures under1e-5 quad tolerance and capturehash verified. Source errors[]. These extend earlier.5s evidence across flash and smoke stages, one size/tape/camera only. Residual particle/debris/softdepth/MSAA differences remain; no complete-showcase or whole-game acceptance.


### Live FX uniforms and no-soft diagnostic (2026-11-16)

Collector records actual post-render uPx/uSoft/uRes/uNearFar/uAtlas and lit sun/ambient uniforms (`fx-showcase-source-uniforms.json`). Original uPx=.00209320569473,uSoft1,res1280x720,near/far.08/900,atlas4x2; lit sun/ambient equal exported native setup values. Source atlas min1008/mag1006 and native linear_mipmap sampler are consistent at configuration level (does not prove GPU mip/sample identity).

Added optional runner --fx-soft=0 and collector SALTLINE_FX_SOFT=0 diagnostic. Both realGPU captures retain1403draws/55lit/53add. No-soft fullMAE.00253445 vsdefault.00253648;effectROI.01520099 vsdefault.01522199. Near-unchanged discrepancy excludes soft intersection fade as the dominant cause in this snapshot. Default soft_particles remains true. Evidence fx-showcase-source-explosion-nosoft.png/native-nosoft.png and fx-showcase-nosoft-comparison.json. Continue atlas/mip/shader/blend/MSAA edge investigation; no general depth equivalence claim.


### Live particle atlas base-byte identity (2026-11-16)

Collector now hashes actual original fx_lit/fx_add DataTexture.image.data at runtime and records filtering/mipmap settings (`fx-showcase-source-atlas.json`). Compared those hashes to immutable exported RGBA and native loaded mip0 bytes after documented vertical row reversal: both exactlymatch. lit512x256RGBA SHA99e1ef1b43fadece7ef1a96b391671ba336cb1dc09e00370fa8c02d6b39ff442;addSHA ddc9cf422d06eae064bc2118bfee5a03e24f25c13fe2d6c3d31da8675b689042. Total1,048,576basebytes verified (`fx-atlas-base-verification.json`). This excludes base-level asset corruption, not generatedGPU mip/LOD/bilinear interpolation or live atlas sample equivalence. Default source/native samplers use linear_mipmap. Remaining local residual investigation continues at mip sampling, shader/blend and MSAA/FXAA boundaries.


### Full live GPU atlas mip readback discrepancy (2026-11-16)

Optional collector SALTLINE_FX_MIPS=1 performs exact integer-level texelFetch into RGBA8 readback targets for both actual runtime atlas textures, storing20levels in evidence/fx-atlas-runtime-mips. Compared1,398,104bytes against prepared native mip chain after undoing row flips:level0/1exact,levels2-8mostly1byte discrepancies,1x1 level9max8(lit)/5(add);total9412differentbytes (`fx-atlas-mips-verification.json`). No production texture replacement applied: existing asset mip manifest records ANGLE NVIDIA OpenGL ES3.2; current collector explicitly selects ANGLE Vulkan. Backend-specific glGenerateMipmap/rounding is a plausible but not yet proven cause. Collector now supports SALTLINE_FX_ANGLE and records actual GL backend in future state. Need same-backend recheck before labelling prepared assets wrong or replacing them. This readback proves integer mip content discrepancy only, not its rendered error contribution.


### Same-backend complete atlas mip identity (2026-11-16)

Recollected original actual runtime atlas mip levels with SALTLINE_FX_ANGLE=gl, actual renderer confirmed ANGLE(NVIDIA RTX4070SUPER,OpenGL ES3.2), matching original export manifest. All20levels,1,398,104bytes match prepared native mip bytes exactly after row correction:0differentbytes/maxerror0 (`fx-atlas-mips-gl-verification.json`). Prior Vulkan-requested readback retained separately; no asset change justified. This establishes complete mip content identity for intended source backend, not cross-backend implicitLOD/interpolation or final raster parity. Collector stores mips per case directory to avoid overwriting prior results. Same-backend source screenshot `fx-showcase-source-explosion-mips-gl.png` now available for native comparison; use measured backend, not requested flags alone, for future claims.


### Showcase solar caster registration fix (2026-11-16)

Code audit found native SunShadowPass discovers only source-id geometry under source_scene; newly created KP nodes were attached directly to Main and had no source record, so they never cast source solar shadows despite receiving them. Geometry builder now registers deterministic source IDs/records/materials for3Ei meshes, and runner/probe attach showcase group beneath source_scene. Floor stays castoff. Live GPU run confirms3dedicated caster bindings,1403draws/lit55/add53 unaffected, no errors. Independent screenshot/state `fx-showcase-native-casters.png/.json`; capturehash stored and count in fx-showcase-caster-verification.json. SourceGLES/nativeVulkan pixel fullMAE improves.00284880->.00267345;effectROI.01518684->.01436203. This fixes a concrete missing effect regardless of modest image metric gain; source showcase shadow-camera configuration and full residual fidelity still need audit.


### Actual showcase solar shadow configuration identity (2026-11-16)

Collector now records actual original sun.shadow camera matrices/frustum,mapSize,bias/normalBias; runner records selected config and live viewport size. SourceGLES showcase and native both4096x4096. Source near/far/left/right/top/bottom vs native sourceconfig maxerror3.97904e-13;cameraWorld max1.42109e-13,projection1.33227e-15,shadowMatrix4.996e-16. Source bias-.00012,normalBias.02.3native dedicated caster bindings confirmed. `fx-showcase-shadow-config-comparison.json` ties this to separate source-shadow/native-shadow runtime states. This establishes that source renderer's global ZM fit is shared by showcase and map, so replacing it with a smaller arbitrary showcase frustum would reduce fidelity. It does not prove D24 depth/raster/PCSS pixel identity for these meshes; keep those gates separate.


### Particle visibility A/B localizes opaque residual (2026-11-16)

Added optional runner --fx-hide-particles and collector SALTLINE_FX_HIDE_PARTICLES=1, hiding only lit/add render batches while retaining simulation, debris, lights, timings. Matched manual exposure.7 sourceGLES/nativeVulkan GPU pairs: particlesOFF fullMAE.00272627/effectROI.01368296/ground.00138049;particlesON fullMAE.00281333/effectROI.01528558/ground.00138803 (`fx-showcase-particle-visibility-comparison.json`). Bothstates1403draws/55lit/53add. Remaining local error persists when particles are absent; earlier attributing all effectROI difference to particle edges was too broad. ROI contains test boards/debris and needs opaque layer audit. No production particle effect removed; default visibility unchanged. Next compare generic board/debris normal/light contributions, using this A/B to avoid spending effort only on atlas interpolation.


### Preserve dynamic sky during showcase isolation (2026-11-16)

Isolation audit found all imported GeometryInstance3D were hidden, including original sky sphere. Native therefore rendered static environment panorama while SkyWeather updated a hidden dynamic material. Original show=fx retains render.sky. `fx_showcase_geometry.isolate` now explicitly preserves and shows node record name sky, while map/sea/rain stay isolated. ActualGPU same-tape run succeeds1403draws/55lit/53add/3casters. SourceGLES comparison fullMAE.00267345->.00248782,effectROI.01436203->.01434614,skyMAE.00109415 (`fx-showcase-live-sky-comparison.json`, independent live-sky screenshot/state). This is a concrete missing dynamic effect fix even though single.1s skyframe error gain is modest. Other opaque/debris/local residual remains; do not attribute all previous effectROI error to this sky fix.


### Point-light-off opaque diagnostic (2026-11-16)

Added optional --fx-no-point-lights and browser SALTLINE_FX_NO_POINT_LIGHTS=1. Both set actual transient source intensities/peaks zero after explosion, retaining simulation, sun/IBL, particle visibility control, manual exposure.7. GPU run validates native pool radiance0 and source errors[]. `fx-showcase-nopoints-comparison.json`:fullMAE.00242906,effectROI.01318306,concrete.00466191,metal.00216414,wood.00654123. Residual persists without points, so local light parameter mismatch is not an adequate sole explanation. Source/native images and state saved independently. Previous points-on pair predates dynamic-sky fix; report explicitly warns it is not a perfectly isolated two-case delta. Default pointlights remain enabled. Next audit can separate sun/IBL and sample normal/roughness under exact camera, while keeping actual effect requirements intact.


### Final albedo debug stage capture (2026-11-16)

Added optional runner --fx-surface=albedo|normal|roughness, generating a showcase-local Shader variant with final unlit surface output; imported shared shaders/material assets untouched. Source collector SALTLINE_FX_SURFACE hooks original onBeforeCompile after original patch and returns selected value at opaque output. GPU albedo pair with particles/points hidden,manual.7,same clocks succeeds. Board interior MAE concrete.00407765 (1.03980/255),metal.00196484 (.50103/255),wood.00498560 (1.27133/255);ground.00126302 (`fx-showcase-albedo-comparison.json`). Final post/edges/debris remain so this is not raw HDR texel proof, but shows surface/color-stage residual remains without lighting contribution. No normal or roughness capture executed yet; avoid attributing all board residual to direct/IBL. Default full materials unchanged. Independent albedo source/native PNG/state preserved.


### Normal and roughness surface-output matrix (2026-11-16)

Executed source/native finalnormal androughness diagnostic variants with manual.7,particles/points hidden,same tape/clock. NoGPU/script/page errors. `fx-showcase-surface-matrix.json` records boardinterior meanencodedRGBerror:normal concrete.38474/255,metal.42084/255,wood.72138/255;roughness concrete2.01466/255,metal.90792/255,wood1.53435/255;groundnormal.11210/255,roughness.55820/255. Albedo matrix retained. Formula audit source39472-39480 vs source_wet_surface.gdshaderinc finds matching macro/wet/bead/normal-length roughness arithmetic; no justified formula edit from these postprocessed images alone. These images are not raw normal angular/roughness scalar comparisons and includepost/edge/debris behavior. Next audit sampler anisotropy/mips and raw stage reads before changing wet-material model.


### Program material anisotropy alignment (2026-11-16)

Source lv caps procedural material render-target anisotropy at8; actual original concrete/paint_blue/wood_pallet map+normal+roughness textures all8,min1008,mag1006,matching repeats verified (`fx-showcase-source-samplers.json`). Isolated Godot engine default viewport anisotropic_filtering_level=2 means4x; project had no override. Set project rendering/textures/default_filters/anisotropic_filtering_level=3 (8x). Live GPU worldviewport enum3 confirms8x,1403draws/55lit/53add/3casters unaffected. `fx-showcase-anisotropy-comparison.json` fullMAE.00248606/effectROI.01438774 vs precedingdynamic-sky.00248782/.01434614:parameter alignment is valid but does not remove this snapshot's dominant residual. Global8 also applies to other anisotropic samplers; original canvas/other textures can use4or1, requiring per-texture sampler distinction in later fidelity work. No all-texture filtering parity claim. Performance impact not measured by fixed-step capture.


### Full main material sampler metadata and decal1x correction (2026-11-16)

New capture_texture_samplers.cjs loads actual original main game, validates195materials by ordinal/name/type/scalars/color and texture dimensions/sharedbindings (2691checks), then maps122texture samplers to stable export IDs.119textures anisotropy8;fx_decals color4;decal normal/ORM1. Source backendGLES NVIDIA recorded. Evidence copied as reproducible import fixture assets/export/fixtures/texture-sampler-bindings.json. prepare_assets.py now validatesdimensions and applies anisotropy metadata; preparedscene updated without regenerating texture bytes.

Generic shader builder now chooses linear_mipmap without anisotropy for explicit source<=1. This fixes decal normal/ORM samplers; decalcolor4 still uses viewport8 and needs independent sampler-level support. verify_sampler_metadata.gd checks generated real shader declarations:2checks/no failures. Initial probe loaded outside tree and produced unrelated transform errors; corrected deferred root attachment and reran. Headless D24-unavailable warning is expected and not a GPU rendering check. FullGPU decal appearance still needs validation after this sampler change. Default119 procedural textures retain8x,1x metadata is no longer discarded.


### Fixed4 decal sampler engine path review (2026-11-16)

Astra read-only review confirms per-uniform true4x can use private Forward+ hint with existing MaterialStorage default4x/bias0 samplers; no new samplerresource lifecycle or ShaderRD changes required. Minimal7enginefiles:ShaderLanguage h/cpp token/filter after DEFAULT=6;ShaderCompiler h/cpp capabilitygate+specialname;Forward+compiler opts in;regular+SDFGI renderpass sets add37/38;scene_forward_clustered_inc declares samplers. Do not append normal samplerbank+12/+13 because Forward+24..36 andSDFGI24..27 alreadyoccupied. Unsupportedbackends mustreject beforeGLES fixed-length mapping. Defaultsampler reuse assumes sourceLOD bias0 and linear mipfilter(projectcurrentfalse for nearestmip);9filevariant needed if inheriting viewportbias. No enginepatch made yet. Acceptance requires same-material4/8,clamp/repeat,viewportchanges,decal/shadow/reflection actualGPU, not justhintparse.


### Independent4x engine sampler implemented and integrated (2026-11-16)

Implemented Astra-reviewed7-file Forward+ extension, merged with previous engine work into16-file reproducible patch0002. New hint filter_linear_mipmap_anisotropic_4 preserves FILTER_DEFAULT=6,has compiler backend capabilityguard,binds existing4x/bias0samplers at37/38 inregular/SDFGI passsets. First build failed due an undefined MaterialStorage local; corrected singletonaccess. Isolated rebuild succeeded. BinarySHA9babcf87a5bae54b005c9000ca1c5dfe6827e74f831b333eece269e96421b64a;patchSHAcb86dd61338593418e7dcce1947e4ed01c9e84bb43069c1e9ebc71dce66e2fa1.

GPU verify_fixed4_sampler:fixed4clamp/repeat identicalbytewise asviewport4->8;both equalordinary4. Ordinary8repeat control differs145837bytes,max48,confirming distinct true samplerstate. Evidence fixed4-sampler-verification.json. Generic materialbuilder now selectsnewhint forsourceanisotropy4;actualdecalcolor4,normal/ORM1 metadata3checks pass.31decalnormal GPU regression and360framecombinedshowcase(47impacts/60tracers/28shells/1explosion)pass withoutshadererrors. Fresh pinned sourcefiles+combinedpatch dryrun/apply all16hashesmatch(engine/fixed4-patch-verification.json). GLES Compatibilityexplicitly rejectsprivatehint with capabilitymessage beforefilterarray indexing;itsimageprobe intentionallyexit1 because shaderunsupported(fixed4-unsupported-verification.json),not a Forward+ failure.

SDFGI bindings implementedbutnotruntimeexercised;per-levelmipbiasinheritance deliberatelyunsupported(sourcebias0),cross-APIpixelidentitynotclaimed. Existing oblique/depth/bias broadregressions still need rerun undernewengine as appropriate; no fullgamecompletionclaim.


### New-engine transparency/projection/depth regressions (2026-11-16)

Extended fixed4sampler GPU probe with transparent alpha.55 mode. Fixed4clamp/repeat invariant under viewport4->8 and equalordinary4 bytewise;ordinary8control differs128085bytes,max35 (fixed4-sampler-alpha-verification.json),failures[]. This verifies transparentForward+ samplerbinding,not fulloriginaldecalpixels.

Reran previous engine capabilities:verify_planar_xr initially stalled at frame_post_draw coroutine;stopped ownedprocess and changed verificationwarmups toprocess_frame+explicitforce_draw. ActualGPU cases red112->0->112 while aboveplane green103/blue70 retained,mainviewportbyteidentity,HDRgreen4.0,8mips/nonzero tail,failures[]. Actual4096² sunD32vsD24 test all16,777,216pixels,148eligiblecasters,402512changed,maxdepthdelta1/16777216,outside2q24=0,failures[] (sun-depth24-delta-verification.json). These preserve testedoldprojection/HDR/depthpatchcapabilities underfixed4engine;not sourcewholegamePBR/PCSS or SDFGI runtime proof.

## Holdout record persistence across processes

The original bundle's result function `b()` at lines 84951–84973 reads `localStorage` on every result. Native flow previously cached the record only at construction, allowing an already-open instance to overwrite a newer saved score. `game_flow.gd` now reloads the isolated JSON record before each result and preserves numeric record precision. Empty storage paths retain the existing in-memory fixture behavior.

`tools/verify_holdout_storage.gd` ran in two separate headless engine processes against `/tmp/saltline-holdout-process-check-179478.json`. The first saved rounded score 1235 from 1234.6. The second loaded 1235 and kept it after score 900. Replacing the file with external record 2400.5 while that second flow remained alive caused its next result to read 2400.5 and leave the file intact. Both phase reports have empty failure arrays: `evidence/holdout-storage-write.json` and `evidence/holdout-storage-read.json`. No normal user save was accessed.

The existing original-source game-flow fixture also passed all 500 frames and 11030 comparisons, maximum error 0.00000602745. This verifies record semantics and flow regression; it does not prove full from-spawn gameplay, concurrent write atomicity, or the full holdout wave/resupply loop.

Reproduce using the same isolated path for both commands, in order:

```sh
./tools/run_native.sh --headless --script tools/verify_holdout_storage.gd -- /tmp/saltline-holdout-check.json write
./tools/run_native.sh --headless --script tools/verify_holdout_storage.gd -- /tmp/saltline-holdout-check.json read
```

## Actual Main holdout wave/resupply integration

`tools/verify_holdout_runtime.gd` instantiated the complete Main scene and ran 538 fixed 0.05-second steps through two holdout waves. The authoritative run used the isolated Godot Forward+ engine on NVIDIA RTX 4070 SUPER, log `/tmp/saltline-holdout-runtime-gpu.log`, terminal exit 0. `evidence/holdout-runtime.json` records 12 checks with no failures. Wave counts were 7 and 9, with 16 real actor damage/death events and total score 3820. First-wave rifle reserve changed from 10 to 100, with the destroyed explosive prop remaining destroyed. Second-wave reserve was capped at 240 and the actual explosive prop reset to alive. Player heal, breather duration, and objective were checked.

The test uses controlled lethal actor damage and an invulnerable player, without moving the player. It verifies queue/actor/mission/Main connections, not human combat, navigation, screenshots, frame rate, or full visual correctness. An initial headless attempt passed logic but emitted the expected unsupported dummy-renderer fixed4 shader error; it was superseded by the clean GPU run. The test disables record persistence and does not write the normal user record.

The existing canonical source mission fixture was rerun independently: 480866 comparisons, maximum error 0.000001891889, zero failures, three waves, score 7180, and 12 intentional failed spawn attempts. See `evidence/mission-canonical-verification.json`. Source wave and resupply implementation is in the immutable bundle at lines 84867–84935.

GPU reproduction from the project directory:

```sh
DISPLAY=:0 ./tools/run_native.sh --script tools/verify_holdout_runtime.gd -- --game
```

## From-spawn mission walking and interaction

`tools/verify_walk_mission_runtime.gd` ran the complete Main scene on the isolated Forward+ engine and NVIDIA RTX 4070 SUPER. Starting at the original `[-32, 0, 6]`, it used the existing navigation route to drive player movement/look through the real capsule collision solver. Relay interaction used the actual keyboard input state for E. No player position assignments, resets after spawn, direct relay cuts, direct completions, or enemy removal were used. All three relays were cut and boat extraction reached `complete`, with no reported failures.

`evidence/walk-mission-runtime.json` records 1410 fixed steps at 1/30 second and cumulative movement 146.9219246 meters. Leg step counts were 406, 398, 391, and 215. The GPU process exited 0, with log `/tmp/saltline-walk-mission-runtime.log`. This closes the specific missing from-spawn movement/collision/interaction integration check. It does not prove human playability or combat balance: look/movement were automated and the player was invulnerable, with no shooting. The simulation yielded every 100 steps, so elapsed runtime is not a frame-rate measurement or rendered video acceptance. Normal user record writes were disabled.

Reproduce from the project directory:

```sh
DISPLAY=:0 ./tools/run_native.sh --script tools/verify_walk_mission_runtime.gd -- --game
```

## Independent Linux development runtime bundle

`tools/package_runtime.py` now creates a new, non-overwriting bundle containing the pinned engine binary, all assets, scripts, scenes, shaders, prepared imported resources, class/UID caches, engine provenance, Godot copyright, launcher and a SHA-256 manifest. No asset pruning has been attempted. `output/linux-runtime-20261116-r2` contains 3355 manifested files totaling 1,405,506,769 bytes. All hashes were reread and verified. `evidence/runtime-bundle-verification.json` records no manifest failures and no startup/exit errors. The bundle ran on actual Forward+ GPU for six frames with isolated XDG_DATA_HOME, loading 729 nodes, 195 materials and 128 textures. This is a relocatable source-based development bundle, not an exported PCK/release or proof of compatibility on another host. Launch with `./run.sh -- --game` inside the bundle.

The initial bundle exposed a normal-exit cleanup defect: local-light traversal queried World3D after the source subtree exited the scene tree, emitting thousands of errors. `source_local_light_service.gd` now skips detached nodes/subtrees; live-instance mask restoration and material cleanup remain enabled. The rebuilt bundle exited cleanly. The GPU local-light regression also passed: 254 migrated objects, nonzero world/weapon contributions, no duplicated native contribution at energy 1000, exact reentry, and correct shared-layer key-light selection. See `evidence/local-light-service-verification.json`. The first faulty bundle was removed; its diagnostic log remains `/tmp/saltline-bundle-smoke.log`.

## Four saved-preset cold boots

`tools/verify_quality_cold.gd` was run in four independent Forward+ GPU processes using isolated `/tmp/saltline-quality-cold-{preset}` XDG data directories. Saved low/medium/high/ultra settings applied at scene initialization, with world/weapon sizes 896x504, 1088x612, 1280x720, and 1280x720. Eight draw observations per process checked sizes, AO/motion gates, shadow resolutions and depth readiness. All processes exited 0; all per-preset failure arrays and log error arrays are empty. Depth, half-depth and sun depth were ready in the first recorded observation. Medium/high/ultra planar capture was ready; low correctly disabled planar reflection. Reports and snapshots use `evidence/quality-cold-{preset}.{json,png}`; matrix is `evidence/quality-cold-matrix.json`.

This strengthens the previous auto/high-only cold-boot check. It does not establish exact first GPU pass timing, source pixel parity, AO/volume transient pixel correctness, hardware automatic preset choice, or frame-rate behavior. Each recorded observation follows process_frame plus a forced draw and can include earlier engine draws. Inspected high screenshot shows the expected early title fade and visible UI; nonblank-image detection includes UI and does not prove the scene underneath the fade is visible. No runtime code changed in this stage, so the independent runtime bundle remains current.

### UI-free cold-boot scene pixels

The cold-boot verifier was extended to read the actual HDR world viewport at all eight observations, before title fade/UI composition. It checks finite sampled RGB mean, nontrivial luminance range, and lit sample count. Four independent GPU preset processes were rerun successfully, with no failures or log errors. This closes the specific weakness where UI alone could satisfy the final-image nonblank test. Each preset now includes UI-free snapshots at observations 0 and 7, named `quality-cold-{preset}-world-{0,7}.png`; original HDR statistics remain in the per-preset JSON and matrix. The PNGs convert/clamp to RGB8 for inspection and are not tone-mapped final output. The inspected medium observation-0 image contains containers, wet pavement reflections, rain and dynamic sky. These observations still do not establish exact first actual GPU draw timing or absence of transient AO/volume artifacts. Runtime code and the packaged bundle are unchanged.

## Real mesh HDR lighting decomposition

Astra recommended following the residual generic-material chain on actual showcase boards, rather than adjusting global exposure or repeating isolated BRDF formula tests. Its review found a diagnostic mismatch: original gk clamps roughnessFactor to [.045,1], while native debug previously displayed unclamped rr. The runner now displays the matching clamped value. This changes diagnostic output only. The old `fx-showcase-surface-matrix.json` roughness rows are historical, not evidence of a production roughness defect.

Added four diagnostic modes for final direct diffuse/specular and indirect diffuse/specular. Original injection remains after lighting and aomap processing, before opaque output; native takes final sourceDirectTerms/sourceIblTerms values after occlusion. The source collector now optionally reads actual main-camera HalfFloat world target before post, and supports a restricted-directory base URL. Native runner saves actual world-port HDR bytes and metadata. The captured source buffer is RGBA16F with bottom-left origin; native is RGBH with top-left origin. `compare_showcase_hdr.py` corrects layout and compares three interior board rectangles. Original HTML was served only from the source directory at localhost:8806, not the workspace root.

Five source/native pairs were captured: four components plus beauty. Shared FX tape, age .5, size1.2, 1403 FX random draws, manual exposure .7; particle batches and point lights disabled identically. Original backend was ANGLE NVIDIA OpenGL ES, native Vulkan Forward+. All capture processes exited0. `evidence/fx-showcase-hdr-components.json` contains binary SHA256 provenance and all ROI metrics. Four components reconstruct their own backend's beauty with mean absolute error 0.0000146–0.0000399 and maximum0.0002289, consistent with separately rounded half-float terms. No missing large lighting term appears in these non-emissive board ROIs. This is a measured reconstruction, not a proof for other materials.

Direct diffuse average energy error is +.1546% concrete, -.1814% painted metal, -.5163% wood. Concrete direct specular is -3.15%, indirect specular +1.226%. Larger local absolute residual remains in diffuse texture detail, with direct-diffuse ROI MAE .001752/.000420/.002583. Thus there is no evidence to change overall light intensity. Next trace material input sampling/derivatives before changing BRDF. Remaining errors are real and no full pixel parity is claimed. No production shading change was made during this diagnostic stage. The bundled gameplay remains unchanged; its research showcase runner predates these diagnostic additions.

## Production material noise: restore original NVIDIA affine fusion

Actual HDR input decomposition found the largest systematic board residual in procedural `mac2`, not texture mean or normal direction. Concrete macro RGB MAE was .0325198, including mac2-channel .0819151. The historical all-rounding `slH` implementation matched a SwiftShader reference, whose backend is explicitly recorded in the old wet fixture and independence report. It did not represent the currently observed original NVIDIA OpenGL ES compiler behavior. Those old fixtures were not overwritten.

Single-variable actual-mesh experiments isolated the initial `p*.3183099 + offset` operation. Removing only its intermediate multiply guard lowered macro RGB MAE to .000139868 concrete, .000251831 metal, .000229140 wood, improving all three. Removing tail guards did not help; plain source arithmetic worsened metal. Explicit `fma(p,vec3(.3183099),vec3(.71,.113,.419))` was then verified byte-identical to the successful affine-free candidate across the captured HDR image. Production `source_material_noise.gdshaderinc` now uses that explicit FMA, preserving hash entry, fract, multiply/product and sum rounding guards. Constants, spatial frequency, eight-corner interpolation and material coefficients remain the original ones. Astra reviewed this narrowed change. Evidence: `fx-showcase-hdr-inputs.json`, `fx-showcase-noise-variants.json`, and archived native macro variant states/binaries.

The unmodified default full-FX rendering was recaptured before and after, including particles, transient point lights and automatic exposure, using the same age .5/size1.2/tape state. Source/native screenshot MAE improved full image .00248585 to .00227538, concrete .00513573 to .00273389, metal .00256166 to .00252767, wood .00780874 to .00658140. Thus the production change improves the complete render rather than only debug output. `fx-showcase-noise-production-comparison.json` records PNG hashes and regions. Main-scene local-light regression passed for254 migrated objects, world/weapon contribution, native-duplicate suppression, shared-layer key selection and exact reentry (`local-light-service-verification.json`, log `/tmp/saltline-local-light-noise-regression.log`). No global exposure/light-strength tuning was applied.

A new independent original48-case NVIDIA GL wet fixture is `assets/export/fixtures/wet-reference-nvidia-gl.json`, collected via explicit in-memory HTTP route whitelist without serving a workspace directory. Original wet/noise source and reference-page hashes are attached. `verify_wet_nvidia.gd` uses a new probe that directly includes production noise and wet functions. An initial attempt mistakenly reused the historical probe's copied hash; that test was corrected, not accepted. The corrected production probe passes47/48 cases at the unchanged .001 threshold. Case39 still differs only in bead by .02758789, source .30249023/native .27490234, at position(.676,.54,-.28), zero footprint. This is an explicit remaining failure, likely requiring investigation of high-frequency bead input arithmetic; causation is not yet proven. `wet-surface-nvidia-verification.json` intentionally remains failing. No threshold relaxed.

The existing linux-runtime-20261116-r2 bundle predates this production shader fix. It is retained as an earlier stage package; rebuild using package_runtime.py before distributing the updated revision. Complete visual parity remains open.

## Remaining bead mismatch localized to first noise layer

Extended the independent NVIDIA GL collector with an explicitly derived `--bead-components` diagnostic. Original48-case wet fixture is unchanged; the separate fixture is `wet-bead-components-nvidia-gl.json`. Native verifier records all four actual/reference components per case, avoiding the capped failure list obscuring case39. At case39, noise170 is source .7578125/native .7529296875; noise410 is .475341796875 on both and wet is .505859375 on both. The derived original diagnostic retained the same final bead .302490234375 as the uninstrumented fixture, while native retained .27490234375. This localizes the observed failure to the first noise layer, not the second coordinate transform or wetness.

Two second-layer input variants, explicit split and explicit fused p410+5, left the original case39 error unchanged. Two subsequent hash variants retained affine FMA while releasing either hash tail or entry guards. Entry removal left case39 unchanged; tail release worsened its error to .02880859 and introduced cases7/31 above .001. None was adopted in production. `evidence/wet-bead-localization.json` indexes the variant reports and component values; existing .001 acceptance remains unchanged. The production affine-FMA improvement from the previous stage remains intact, with its known47/48 wet-fixture result.

Next narrow investigation is the first-layer cell (114,91,-48) and its eight integer hash corners, especially high-weight (115,92,-48) and (115,92,-47), while treating isolated corner probes as compiler-context diagnostics rather than final acceptance. Current evidence does not justify changing frequency, wetness, bead thresholds or exposure.

## Eight exact bead-noise corner hashes agree

Added a derived original NVIDIA GL eight-cell capture and production Godot hash probe for the first-layer cell around(114,91,-48). `assets/export/fixtures/wet-corners-nvidia-gl.json` retains source provenance and backend. `evidence/wet-corners-nvidia-verification.json` records all eight integer corner coordinates and hash outputs; every corner matches exactly at the RGBA16F readback precision. This does not prove exact float32 hash bits or equality when the functions inline inside slN3. The observed full noise170 difference therefore cannot be attributed to a missing/wrong isolated integer corner at this precision.

A further diagnostic removed only the hash input guard and replaced explicit affine FMA with the original free p*c+b expression, retaining the other tail guards. The48-case wet test worsened: cases15,31,39 failed .001; case39 bead error .03027344. See `wet-surface-nvidia-hash-source-affine.json`. No candidate was adopted. Production noise and its prior whole-image improvement remain unchanged.

Remaining hypotheses are compiler-context changes in the inlined corner computations and/or float32 interpolation, not yet proven. Do not claim a driver root cause or hard-code case39. A future inline-corner probe must also show its instrumented full noise value still matches the uninstrumented original. Full visual acceptance is still open; these context probes are localization evidence only.

## Original material/prop directory coverage and six additional materials

Read the literal original `_k` material catalog and `Tk` props catalog. An actual original `show=props` runtime inventory executed all36 prop builders at seed7 and container doors .6, collecting mesh counts and material names without script errors. `evidence/catalog-inventory.json` records48 base material names and36 prop definitions. Six base material names were absent from the current main export: asphalt, brick, anodized_black, carbon, armor_orange, water_dark. This is directory/variant coverage, not proof of missing objects in the original main game. Main scene instancing does not consistently retain prop names, so userData.prop absence is not used as a missing-asset claim.

Added `tools/export_material_catalog.cjs`, which runs the original HTML with `show=mats&only=` those six names. It exports the actual18 sample meshes, three original geometry buffers, nine material variants including triplanar, and18 original GPU texture chains. Direct framebuffer attachment/readPixels reads encoded RGBA8 mip contents without shader resampling. Each chain retains dimensions, levels, anisotropy, color-space metadata and SHA256; raw source rows and separately flipped rows are saved for existing importer contracts. All request routing is explicit and in-memory, without serving unrelated workspace paths. Original source/backend provenance is in `assets/catalog/materials/catalog.json`. Integrity report `evidence/material-catalog-assets.json` verifies hashes and level byte sizes.

`scripts/material_catalog.gd` loads those assets through the existing generic material importer and original mesh-array helper, reversing Three winding once and preserving normals/UVs/transforms. Standalone `material_catalog_runner.gd` reuses Main services, isolates the map and weather geometry, pins the original source camera, binds original lighting and registers new material shadow records. An initial run exposed missing sun depth-material records; those were added before accepting the corrected run. GPU execution on RTX4070SUPER completed12 frames with no script errors,18 source lighting bindings,18 shadow casters and all18 full GPU mip-chain hashes matching original bytes. See `evidence/material-catalog-runtime.json`, log `/tmp/saltline-material-catalog-mips.log`, and native screenshot `evidence/material-catalog.png`.

Run `./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game`; Escape exits. Optional `--catalog-frames=12` saves screenshot/report and exits. Source screenshot is `evidence/material-catalog-source.png`, collected separately by `export_material_catalog.cjs --capture-only`; renderer-history alignment and pixel acceptance remain open. No game-map placement was invented for these uninstantiated directory variants. Full48-material catalog, decal display, and36-prop directory migration remain required work. Existing packaged r2 predates the new catalog and production noise fix.

## Full48 material, decal and label directory

The exporter now supports `--all`, which invokes the actual original default `show=mats` layout rather than constructing an approximate grid. Exported assets live separately in `assets/catalog/materials-full/`, preserving the six-material subset. The original inventory's48 base names are all present, with85 material instances including triplanar/decal/label variants,115 textures and34 distinct geometry buffers. Source geometry/transforms, original per-node renderOrder, shadow casting/receiving and shadowSide are retained. Non-mip filtered textures export only their valid base; off-camera original textures are explicitly initialized before readback so the decal wall is not omitted.

Visual inspection caught an initial scene-level omission: the original common80x80 concrete plane is a direct scene child outside `_k`'s sample group. The exporter was corrected to include that actual source mesh. Final catalog has175 nodes,175 source-lighting bindings and146 shadow casters, matching exported cast flags. Native attach now preserves non-casting decal/ground flags and material draw priority. Actual Forward+ run completed12 frames, all115 full texture/mip GPU hashes matched, and no shader/script/log errors remained. Offline source hashes and chain sizes also passed for155,964,376 source mip bytes. The superseded pre-floor export's230 unreferenced texture files were removed after confirming current manifest references. See `evidence/material-catalog-full-runtime.json` and `material-catalog-full-assets.json`.

Native screenshot `material-catalog-full.png` was visually checked alongside original `material-catalog-full-source.png`, confirming the grid, decal wall, labels and concrete ground are present in the original layout. Source camera is retained, but renderer history and full original/native pixel acceptance remain separate; no blanket visual-equivalence claim. The script still bootstraps Main then isolates map/weather, so it is not the original minimal showcase boot.

Launch `./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full`, Escape to exit. This completes the implemented default material/decal directory asset coverage at current high source quality, while original query filtering/other quality generation and props directory remain open. No unrelated game-map placements were added. The stage package r2 remains historical and needs rebuilding for these assets.

## All36 default prop showcase definitions imported

The catalog exporter now supports `--props`, invoking the actual original `show=props`. It flattens each original mesh's complete matrixWorld while retaining the owning prop name, source geometry, material variants, draw priority, visible flag, source shadow flags and common floor. Default original Tk uses seed7 and container door openness .6; no new layout or random prop design was substituted. The independent prior builder inventory counts296 mesh nodes; the exported prop roots contain exactly296, plus one original common floor. `assets/catalog/props/catalog.json` contains36 prop names,297 meshes/geometries,137 materials and124 original GPU mip chains.

Added `catalog_mesh.gd` to retain optional normals/UVs and original floating vertex colors.111 geometries contain color, now stored in native CUSTOM3 RGBA_FLOAT to match the shared shader's v_hdr_color input. Per-geometry material variants disable vertex color only when the source geometry has no color attribute, matching Three's attribute-dependent define. Multi-material geometry groups and MultiMesh data have import branches, but this actual dataset has zero multi-material nodes and zero instanced nodes, so those new branches remain unexercised and are not claimed validated.

Actual Forward+ run completed12 frames with36/36 owning prop names,282 lit mesh bindings,177 shadow casters,124 complete GPU mip-byte hash checks and111 exact native surface CUSTOM3 byte comparisons against original source floats. No failures or shader/script log errors. `evidence/prop-catalog-runtime.json` and `prop-catalog-assets.json` retain evidence. Native and original screenshots `prop-catalog.png`/`prop-catalog-source.png` were inspected and contain corresponding containers, forklift, racks, stairs, mast, pipes and foreground cargo. Full pixel parity remains open; boot/history are still Main-based rather than the original minimal showcase.

Because the shared catalog importer changed, the existing full48 material/decal directory was rerun:175 nodes,115 GPU hashes,175 lighting bindings and146 shadow casters, zero failures. The props entry is `./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=props`. Export/filter query options, arbitrary seed/doors generation, other-quality procedural generation and asset-independent reusable props API remain further work. Normal game maps were not altered. The earlier runtime bundle does not contain these new directories.

## Original known-name catalog filtering and layout

Added `catalog_selection.gd` and CLI `--names=` / `--only=` on the standalone catalog runner. Props are translated from the captured source layout into the original Tk26-meter row/wrap rule, retaining intra-prop world matrices and source seed7/door .6 geometry. Caller order and duplicate props are preserved. Materials use original _k one-row selected spacing and camera; mixed decals relocate the complete source wall, while decals-only uses the original dedicated camera. The common floor remains in place. Selected data prunes unused geometry/material/texture references before import. Runtime prop sizes now live in `assets/catalog/prop-definitions.json`, with original source provenance, rather than depending on an evidence file.

`capture_catalog_selection.cjs` executes literal original Tk and bk/Mk/fg/_k functions with original THREE, real original materials/props, and a collecting scene. Its independent fixture covers10 cases,157 constructed mesh nodes: single/ordered/repeated props, container row wrap, single and paired materials, glass/chainlink, decals-only, mixed paint+decals, duplicate materials and empty filtered material list. Native verifier passed2572 numeric comparisons plus mesh count/material/vertex count checks, maximum transform/camera scalar error4.44089e-15. See `assets/export/fixtures/catalog-selection-reference.json` and `evidence/catalog-selection-verification.json`. This validates placement and camera targets, not shader/pixel equivalence.

Actual GPU props selection forklift/container20/barrel passed with36 nodes including floor,47 GPU mip hashes,14 exact vertex-color surface checks,32 lit bindings and18 shadow casters. Actual decals-only selection passed31 nodes,34 GPU mip hashes,31 lighting bindings and2 shadow casters. Screenshots `prop-catalog-selection.png` and `material-catalog-full-selection.png` were inspected; the former shows source camera occlusion of the small barrel rather than inventing a new presentation angle. No source image parity claim from these screenshots. Reports are `prop-catalog-selection-runtime.json` and `material-catalog-full-selection-runtime.json`.

Only known captured names are supported. Unknown prop fallback boxes, arbitrary builder options/seeds, other procedural texture quality generation and full original minimal showcase boot remain open. `--names`/`--only` select the appropriate asset directory automatically; examples are in README. Main gameplay is unchanged.

## Vulnerable Main combat, death and retry integration

`tools/verify_main_combat_runtime.gd` starts the actual Main mission at original player spawn, clears initial patrols for a controlled encounter and spawns normal original hounds. The player remains vulnerable throughout, with no position reset, direct enemy damage, direct player damage, health override, altered tuning or direct flow-death call. Automated aim/fire drives `_game_tick` through actual weapon update/ray hits, normal actor health/death signals and enemy AI damage. The player killed the first target and survived the exchange. Combat recorded32 shots,5 hits and1 kill; automatic reload was requested when rifle ammo became zero. A subsequent normal hound encounter, while the player stopped firing, dealt further real AI hits until health0. Actual game flow entered dead, showed its delayed menu, and the real retry button restored playing with health100, invulnerability false and retries1.

The actual Forward+ GPU process completed1170 fixed steps and12 checks with no failures.13 recorded enemy damage events each dealt8, from frame194 through870, reaching health0. `evidence/main-combat-runtime.json` records all events and scope; `main-combat-death.png` was visually inspected and shows the death card/retry action. Log is `/tmp/saltline-main-combat-runtime.log`. This complements previous invulnerable walking and direct-kill holdout probes by exercising the normal damage/weapon/UI path. It does not establish human play balance, aim usability under movement, all enemy/weapon combinations, or full mission completion without invulnerability.

## Complete Standard mission with normal combat and resources

`tools/verify_survival_mission_runtime.gd` combines the original-spawn walking test with normal Standard difficulty selected through actual UI settings before start, original patrols/queues/AI, automated line-of-sight targeting, normal weapon fire and requested reloads. It does not clear actors, override health/ammo, enable invulnerability, teleport, directly damage actors, directly cut relays or directly complete the mission. Movement/look and fire use the actual Main simulation; physical E state holds perform interactions. Source navigation guides the path and automated aiming provides accurate target selection, so this is not human gameplay/balance acceptance.

The actual Forward+ GPU run completed all three relays and boat extraction in47.9 simulated mission seconds,1462 fixed simulation steps and146.88994 meters of cumulative movement. Protected live frames were explicitly counted and were zero. The bot fired60 shots, hit31, killed13 enemies and triggered4 blasts via normal combat. Rifle final ammo30+reserve90 equals initial180 minus60 shots. Health remained100 with no damage events in this successful route; earlier controlled vulnerable combat separately proved enemy damage/death. No retries were needed. The real completion menu appeared after its normal delay and showed original rating Surgical,13 kills and rounded52% accuracy (raw31/60). `evidence/survival-mission-runtime.json` records all four route legs, resources and debrief. `survival-mission-complete.png` was visually inspected. Log `/tmp/saltline-survival-mission-final.log` completed without script errors.

This closes the missing combined Standard from-spawn movement/combat/interaction/extraction integration check, while manual input feel, Hard/Brutal full-play routes, all enemy/weapon combinations and whole-render parity remain separate. The fixed-step CPU simulation yields only intermittently for rendering, so47.9 seconds and screenshot do not measure wall-clock frame rate or represent a recorded realtime playthrough.

## Updated independent runtime bundle r3

`output/linux-runtime-20261116-r3` now includes the production affine-FMA noise correction, all new material/prop catalogs, known-name selection support and runtime prop definitions. It preserves the pinned isolated engine binary. The unpruned development bundle has3882 manifested files and2,077,489,213 bytes after adding launch examples to its README. Every manifest file was reread and SHA256/size verified, with zero failures. The package README and packager's generated README text were updated together, and the manifest README entry/total were refreshed.

All three GPU launches used working directory `/tmp` and isolated XDG_DATA_HOME, through the bundle's own `run.sh`: normal game title boot/exit after6 frames, decals-only12-frame probe, and forklift/container20/barrel12-frame probe. All terminal exit codes0 and no script/shader errors in logs. Decals verified34 full GPU mip chains and2 casters; props verified47 full GPU mip chains,14 color byte checks and18 casters. Package runtime outputs are in its evidence directory, outside the immutable manifest file set. `evidence/runtime-bundle-r3-verification.json` records integrity and logs. This is a Linux source-based development runtime, not a PCK release or cross-device qualification; default catalog generation options and complete visual parity remain open. The previous r2 directory is retained as historical delivery.

## Shared catalog wet control and exported wet scalar import

Original lv creates the shared uSlWet value, and _k at bundle39909 applies the explicit wet query. The native generic importer previously left the shader's default wetness1 even when an exported material contained another uSlWet scalar. `source_scene.gd::_material` now initializes wetness from the actual source sl.uSlWet.value. Default main assets are1, so their normal initial state is retained. `verify_material_wet_import.gd` directly exercised the production importer with0,.35,1,-.5,2; all stored scalar values matched. No forced clamp was introduced beyond the original shader formulas.

Standalone catalogs now accept finite `--wet=` values. `material_catalog.gd::set_wet` updates actual per-geometry material variants, including the shared concrete floor. This is the original input to tint/roughness/streak/bead calculations, not a postprocess darkening adjustment. Optional safe `--catalog-case=` labels keep independent captures. Dry/wet actual GPU captures for brick/concrete each passed7 lit mesh bindings,6 shadow casters and6 complete GPU texture hashes, with2 material instances updated. Screenshots `material-catalog-full-selection-dry.png` and `-wet.png` were inspected and visibly retain changed floor reflection/vertical wet streak response.

`capture_catalog_wet.cjs` separately booted the immutable original with the corresponding wet0 and wet1 queries. It checked the original shared value and every source material reference value, all equal to the requested scalar. Reference screenshots and metadata are `material-catalog-wet-reference-{dry,wet}.png` / `material-catalog-wet-reference.json`. Native and original display-RGB dry/wet response MAE are10.7747 and10.8072 byte units respectively; these are descriptive response magnitudes, not source/native pixel acceptance. PNG provenance is recorded in `material-catalog-wet-response.json`. Known bead high-frequency precision residual is not fixed by this work. Existing r3 bundle predates this CLI addition; source project README documents the current command.

## Original main-node draw order imported

Audit of all captured generic material states confirmed existing opaque depth-write/transparent no-depth-write and depth-test conventions match the current source dataset. The actual missing state was mesh renderOrder: original main export did not store it. `capture_render_orders.cjs` now loads the immutable original, verifies729 nodes with5854 parent/type/name/material-slot/geometry-attribute shape identity checks, then maps current original orders onto the existing exported IDs without assuming UUID stability. `assets/export/fixtures/node-render-order-bindings.json` records the source HTML hash. Every groupOrder in this main dataset is0, and no material is shared across conflicting node orders.

`source_scene.gd::load_source` now derives material priorities from those source node bindings before mesh creation. Ordinary source priorities within Godot's range are retained exactly, including weapon markings2, gun muzzle flashes10 and the Gull scan/lens materials5 that previously inherited0. Existing extreme compression remains sky-1000→-128, rainSplash890→99 and rain900→100, preserving the tested relative order. Existing runtime decals/FX batches already used-5/10/20. Nonzero groupOrder or shared material order conflicts explicitly report an unsupported condition rather than silently pretending support. New catalog records keep their own per-node/source renderOrder path.

Actual GPU `verify_render_orders.gd` checked365 Main material bindings, with zero failures. `evidence/render-order-verification.json` records every nonzero source/native mapping. This proves priority state, not complete overlap-pixel equivalence or alternate group sorting support. Source alpha/additive shader conventions were audited without changing blending formulas; premultiplied RGB with alpha0 is intentionally used by native muzzle/cone shaders for additive RGB output.

The weapon GPU regression initially failed a stale test assumption: total pooled light increment was expected to be1 per shot, although current real impact effects also produce light. The failed report is preserved as `weapon-shot-global-light-assumption-failure.json`. The verifier now uses a delegating spy only on weapon-effects' light call, forwarding every request to the real shared pool and retaining all impact behavior. It checks exactly one muzzle call and exact color/energy/radius/duration, while separately recording global increments. Corrected220-frame run passed13 shots,195 live-root checks and70200 bone/proxy checks; every muzzle count is1, global counts are1 or2. See updated `weapon-shot-runtime.json`. No production lighting effect was removed to satisfy the test.

The earlier r3 bundle predates this sorting import and the new wet CLI. Complete original rendering fidelity and high-frequency bead residual remain open.

## Native focus-loss auto pause

Astra's scope audit identified a normal-game behavioral gap: original bundle85265–85278 pauses intro/playing when captured input lock is lost or document becomes hidden. Native Main's application-focus-out handler only cleared held inputs, letting simulation continue. `_notification` now also clears pending jump/pause/weapon actions and invokes the existing GameFlow.pause for active intro/playing while the node remains in the tree. Title, already-paused and result states are unaffected; focus-in does not automatically resume. This uses the original intro-to-pause handling, including hiding the location card.

`verify_focus_pause_runtime.gd` runs actual Main and injects the native focus notifications. It first advances all four mission/enemy/weapon/weather clocks beyond .9 seconds, seeds held movement/fire and queued jump/reload, then loses focus.120 simulation steps leave all four clocks unchanged, held/queued inputs are clear, focus-in stays paused, and the actual Resume button advances the mission again. Title and intro cases also pass.12 checks have no failures in `evidence/focus-pause-runtime.json`; `focus-pause.png` records the actual pause screen. This tests notification handling, not an OS-driven window switch. The separate backdrop-clock issue is still open, so these checks do not claim every visual animation freezes.

The main vertex-color audit found zero captured meshes with vertexColors enabled but no color attribute, so no speculative main-geometry fix was made. CSS reversal behavior was researched against W3C but remains unimplemented; confirmed focus/background behavior gaps took priority. Current r3 package predates this focus fix.


## Backdrop motion and paused visual clock

Main now advances a dedicated backdrop clock only outside paused state, matching the original loop. Boat vertical bob and hull pitch/roll, crane spreader swing and radar rotation use the literal original formulas. Initial rest scale and uncontrolled rotation axes are preserved; game start/retry do not reset this clock. `backdrop-motion-verification.json` checks 51 original literal-function samples with 3264 matrix/clock checks, no failures and maximum absolute matrix error 7.6294e-7. The separate blink/bird GPU regression also passes. This supersedes the earlier open backdrop-clock note. Original showcase boat mode without vertical bob is still separate from normal Main behavior.

`native-backdrop-motion.mp4` is a verified 1280x720 H.264 video with 180 frames at 30fps, duration6 seconds and no audio. Actual Main GPU frame readbacks show boat, spreader and radar from three inspection cameras. It is fixed-step rendering, not realtime performance or source-camera pixel parity. The first engine movie attempt produced only two actual frames and is retained as a failed attempt; its CPU counter is not accepted as video evidence. `native-backdrop-preview.png` is frame30 of the successful capture.


## Cold-start low material catalog assets

`export_material_catalog.cjs --all --quality=low` now loads the immutable local original with q=low on NVIDIA ANGLE OpenGL, exports actual generated assets and original GPU mip chains into a separate materials-full-low directory, and records cold_start_quality. Default high output paths remain unchanged. Invalid quality values fail before browser startup. The low catalog has175 meshes,85 material instances,34 geometries and115 textures, with48,223,192 original mip bytes. Source HTML SHA256 is b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb. Asphalt/concrete are512, brick256 and fabric/water128, compared with high1024/512/256 respectively. These are regenerated original maps, not resized high assets.

The native catalog runner accepts --asset-quality=low independently of render quality. Missing unexported asset directories explicitly fail. Actual Forward+ full catalog run completed12 frames:115 complete GPU mip-chain hashes match original bytes,175 lighting bindings and146 shadow casters match, failures empty. See material-catalog-full-low-runtime.json and material-catalog-full-low.png. The selected brick/concrete run separately passed6 hashes,7 lighting bindings and6 casters. An initial launch omitted the documented --game flag and failed before catalog attachment; it was stopped and rerun correctly, with log /tmp/saltline-low-catalog.log retained. Successful logs are /tmp/saltline-low-catalog-game.log and /tmp/saltline-low-catalog-full.log.

This establishes low-quality catalog generation/import, not whole-game cold-low support. Main still uses the original high asset scene; low ground generation/query masks, rain initialization/RNG consumption and catalog-to-main material mapping remain to implement. Menu quality changes correctly do not rebake textures. Medium/ultra asset directories have not been exported. The r3 runtime bundle predates these changes.


## Source-quality rain construction

`rain_initialization.gd` implements original Gw counts, literal Vw random assignment order, Float32 storage,260 eave sentinel writes, initial thunder timer and final RNG state. Actual SaltlineRain now rebuilds its two native MultiMesh buffers from source.quality.rain and the canonical rain child seed, then restores the shared child stream to the exact post-construction state. Explicit snapshot time/timer overrides remain supported; default timer comes from current quality construction. Main still loads high source quality, so this is infrastructure for correct cold-low integration rather than an exposed low whole-game mode.

`rain_initialization_reference.cjs` executes the immutable bundle's literal Vw and su using geometry/attribute stubs. Five presets test/low/medium/high/ultra compare151720 Float32 components byte-for-byte and exact counts, RNG states and timers. All pass in rain-initialization-verification.json. Low has4500 drops+260 eaves,450 splashes,20841 draws and initial timer46.70368686481379. High has9000+260,900,40641 draws and31.229654591763392. This prevents the incorrect approach of truncating high rain buffers while retaining high splash offsets/timer.

Actual Forward+ seed readback passes40640 native custom-data components with zero error,9260 rain instances and900 splashes. Actual Main thunder runtime passes10150 checks over1450 fixed steps/72.5 simulated seconds, with normal thunder events at frames625 and1431, RNG calls40645, maximum scalar error7.11e-15 and no failures. Logs /tmp/saltline-rain-generated-seeds.log and /tmp/saltline-rain-generated-runtime.log. The seed verifier's wording was updated after this run to describe regeneration; numerical assertions were unchanged. The first headless run encountered sandbox user-log write errors but completed the checks; rerun with explicit /tmp log was clean.

Remaining cold-low work includes original ground textures and surface-mask queries, main material/texture binding and atomic startup selection. No menu rebake behavior was introduced.


## Main low cold-start assets integrated

`export_ground_quality.cjs --quality=low` executes the immutable local HTML on NVIDIA ANGLE OpenGL. It reads original apron patch uniforms, directly exports all mip levels for uMask512, uDetail256, uDetailN256 and uMarks1024, and retains unmodified DataTexture CPU arrays. Original Dw512 regeneration matches the exported CPU mask byte-for-byte. The script records original HTML SHA256, backend, texture state, CPU/GPU hashes and no page errors in assets/ground/low/ground.json. Font requests outside the local HTML are blocked consistently with the earlier catalog exporter; this does not establish original network-font identity for marks.

`cold_quality_assets.gd` applies low assets before source material and mesh construction. Original userData.set identifies the procedural texture recipe; map/normal/ORM references are replaced together and shared-reference conflicts assert. Existing material colors, UV scale, interior/wet parameters and node bindings remain intact; uSlUv resolution changes to the actual low texture size.78 material instances use72 procedural texture replacements;4 ground replacements also update apron, sea and splash uniforms, uMarkRes/uMaskRes and CPU query asset. Source quality becomes original low before rain construction. The Main CLI is --game --cold-quality=low. Default high is unchanged; auto menu rendering uses the cold source preset, while saved explicit menu presets retain precedence. Runtime menu switching does not rebake assets.

Actual Main Forward+ verification passes all76 replacement GPU mip-chain hashes,20840 rain custom-data components,4760 rain instances,450 splashes, initial low RNG state/count and thunder timer,512 query resolution and exact CPU mask binding. Eight GPU frames render successfully. See cold-quality-low-assets.json/png. The saved-low cold render/depth/disabled-planar startup test also passes all eight observations at896x504. The first verifier invocation omitted its required isolated XDG path and failed its precondition before game construction; corrected isolated rerun passed.

Independent literal Bg/Vg low-query comparison checks12879 positions and90154 values/booleans with maximum error1.11e-16 and zero failures. High query regression also passes unchanged. See ground-query-verification-low.json and ground-query-verification.json. Logs /tmp/saltline-cold-low-assets-gpu.log, /tmp/saltline-cold-low-main.log, /tmp/saltline-ground-queries-low.log. This supersedes earlier statements that Main low ground/material/rain selection was unimplemented. Whole original low pixel equivalence, original font delivery, device-auto boot selection and alternate startup quality/texture overrides remain unproven. Existing r3 package predates this work.


## Independent original low Main binding audit and UV correction

`verify_original_low_bindings.cjs` now boots the immutable original low Main separately from the material showcase exporter. Before mapping existing material IDs, it checks195 material ordinals with1809 name/type/scalar/color identities and matching procedural set identity. It then reads original full GPU mip chains for397 material-property/ground-uniform bindings covering76 unique replacements. Every original Main mip hash matches the chosen low catalog/ground asset. No original UUID stability is assumed. The complete result is original-low-material-bindings.json with zero page errors/failures.

The first independent audit exposed a real native bug: cold-quality replacement unconditionally replaced uSlUv.z with the new map width. Original Main explicitly overrides this parameter for brass8, armor_white2 and gunmetal4. The failed audit is preserved as original-low-material-bindings-uv-assumption-failure.json. cold_quality_assets.gd now changes this field only when its old value equals the original texture width, preserving explicit overrides. Independent original Main comparison confirms all recorded uSlUv vectors after this correction. This supersedes the earlier blanket statement that every uSlUv resolution changes to low texture width.

The native GPU verifier now also compares each original per-slot uSlUv vector against modified source metadata and the actual native tri_scale/source_uv_scale shader parameters. This verifies the source-to-shader binding, rather than deriving success from texture dimensions alone. Existing complete mip/rain/query checks remain in place. Logs /tmp/saltline-cold-low-uv-corrected.log. Whole-frame equivalence remains separate.


## Medium/ultra cold Main and original-font ground correction

The independent browser binding probe now accepts --quality=low/medium/high/ultra and --local-fonts. Medium and ultra each pass195 material identities/1809 checks,397 property/uniform bindings and76 complete original Main mip-chain hashes against existing prepared high assets when original bundled fonts are supplied. Original Main has no hero asphalt set, so ultra does not require the showcase-only2048 asphalt texture. cold_quality_assets.gd now supports medium/high/ultra by selecting the original corresponding preset while retaining identical prepared textures; an explicit asphalt guard prevents silently using this shortcut for a future ultra Main that adds asphalt.

The initial medium/ultra offline runs had only uMarks hash mismatch. Supplying all eight project font files through the original Google stylesheet request eliminates it exactly. This also revealed that the newly exported low ground marks had used a fallback font, despite the internal offline source/native hashes agreeing. export_ground_quality.cjs now serves the locally saved original font faces before original startup and low ground was regenerated. The local-font low Main audit passes all397 bindings/76 hashes. Prior fallback-font reports are retained as evidence; the canonical original-low-material-bindings.json now contains the corrected-font audit. All eight font SHA256 values are recorded in ground and local-font binding manifests. No shader formula or threshold was changed for this correction.

Actual Main medium and ultra GPU runs each pass76 full mip hashes and390 original UV bindings. Medium passes32720 native rain components with7460 rain/720 splash instances; ultra passes40640 with9260/900. Both initial RNG states/timers and auto-selected rendering presets match their original references, then render eight frames. See cold-quality-medium-assets.json/png and cold-quality-ultra-assets.json/png. These checks use isolated empty settings directories; saved explicit settings keep precedence as documented. Logs /tmp/saltline-cold-medium-assets-gpu.log and /tmp/saltline-cold-ultra-assets-gpu.log. Low full GPU regression is repeated after the font correction. This supersedes earlier low/high-only startup support and the low ground font caveat. Test preset, explicit texture-resolution override, device-auto selection, ultra showcase hero asphalt and full rendered pixel parity remain separate.


## Updated independent runtime bundle r4

output/linux-runtime-20261116-r4 includes the current source-quality rain generation, low original-font ground assets and material catalog, all four normal cold quality presets, explicit UV overrides, original mesh renderOrder import, backdrop node motion/paused clock, focus-loss pause and wet CLI. It preserves the pinned isolated engine binary.4141 manifested files total2,195,143,947 bytes. Every manifest size/SHA256 was reread after all runtime checks, with zero failures. Runtime-generated evidence is outside the manifest list. r2/r3 remain historical and were not overwritten.

All four GPU processes launched from /tmp with isolated XDG directories and the bundle's own run.sh/engine. High and low title boots each exit0 after eight frames. An external verifier script loads actual res:// Main from the package, checks low4760 rain/450 splash and512 CPU query resolution, four boat/spreader/hull/radar bindings, injected focus-loss pause, frozen rain/backdrop clocks and actual Resume button restart, then captures GPU output. Its project/executable paths point into r4 and all assertions pass. The external verification script is not a runtime dependency. A packaged low brick/concrete dry catalog run passes six full GPU mip hashes,seven lighting bindings,six casters and two wet uniform overrides. All four logs have no script/shader errors and terminal exit0.

See evidence/runtime-bundle-r4-verification.json and package evidence/bundle-integration.png. Source tools/package_runtime.py generates the same documented launch examples and refuses to overwrite existing bundles. This is a relocatable source-based Linux development runtime, not a PCK production release, cross-device support proof or completion of original visual fidelity.


## Full Main paired-camera visual baseline

New capture_main_paired.cjs boots the immutable local original with original local font faces and actual NVIDIA ANGLE OpenGL, high quality, shot/step mode and fixed dt1/60. A specified camera is applied through the original cam query. After the three boot steps, world time is.05. Weapon/HUD are hidden, render fade0 and manual exposure1 are set, then12 zero-dt original render calls warm passes without further simulation. The native capture_main_paired.gd loads actual Main, uses recorded source camera position/quaternion/FOV74/near.08/far900 and world/rain/backdrop time.05, disables automatic exposure and hides weapon/HUD, then renders12 zero-dt frames. Additional cases copy recorded view-fill state when supplied. This is a diagnostic complete scene, not a normal gameplay recording or all-conditions acceptance.

First camera (-20,1.7,0) toward(20,1.7,0) shows the container corridor, wet ground, crane, shadows, sky and rain. Source/native PNGs were visually inspected. Full RGB8 mean absolute error is.8610948351 byte units, median0,P95=4,P99=11,max123. Signed channel bias is[-.05785,-.02404,-.01872]. Right-container ROI MAE.16435; left-container1.35235; wet-ground1.22277; crane1.18168; sky.53042. These are descriptive observations, not newly invented passing thresholds or an explanation of the residual.

Second camera (27,1.7,27) toward(31.5,-.3,21) covers harbor, boat and sea. Full RGB8 MAE1.1796976273,median0,P95=5,P99=11,max115; channel biases[-.06964,-.05974,-.07364]. Both native processes exit0 without script errors. All PNG hashes, regional statistics, camera/backend/exposure/time metadata and original HTML hash are saved in evidence/main-paired-high[-harbor]-{source,native,comparison}.{png,json}. compare_main_paired.py reproduces measurements. Logs /tmp/saltline-main-paired-high.log and /tmp/saltline-main-paired-harbor.log.

This adds actual whole-scene evidence beyond component fixtures. It does not prove all cameras, dynamic histories, interior adaptation, gameplay viewmodel/UI or complete visual fidelity. Grain/rain/high-frequency material/raster edge differences remain to localize; the baseline is not used to waive the known bead precision residual. Production shaders were unchanged in this stage, and r4 still contains current production runtime.


## Interior paired scene and explicit startup quality precedence

A third full-scene camera at(-10,1.7,-20) toward(8,1.7,-20) covers the warehouse interior, local lights, shelves, roof openings, ground and sun volume. Both original/native PNGs were visually inspected. Same .05 world time, manual exposure1 and source projection, with recorded source view-fill copied for the diagnostic. RGB8 full MAE1.3583391204,median0,P95=5,P99=14,max219; channel biases[-.15462,-.17257,-.19394]. See main-paired-high-interior-{source,native,comparison} artifacts. This is a fixed-time view, not indoor adaptation history proof. Native exit0, log /tmp/saltline-main-paired-interior.log.

Reading original settings apply84317–84329 exposed a current native regression introduced with the new cold-quality CLI: original explicit params.q prevents saved quality from overriding the startup preset. Earlier notes saying saved settings always retain precedence were wrong for explicit q. render_quality.startup_name now chooses source quality whenever --cold-quality is supplied, otherwise source quality for saved auto or the saved explicit render quality. Stored setting values are retained, and subsequent live menu quality changes still apply. This changes startup precedence only; no textures are rebaked.

Three actual Main GPU cases pass with isolated settings: saved ultra + explicit low starts low with4760 rain; saved low + explicit ultra starts ultra with9260 rain; saved low + ordinary boot starts low rendering with high assets/9260 rain. All three then apply the real UI setting_changed quality signal to medium and verify source quality/rain instances do not change. See quality-precedence-{explicit-low,explicit-ultra,saved-low}.json and corresponding /tmp logs. Processes exit0, failures empty. Signal application checks do not claim physical pointer-click coverage. r4 predates this final precedence fix and remains an immutable historical package; packager README template and source README now document correct behavior.


## Interior wall highlight localization in progress

The paired interior beauty exposes an obvious local mismatch near pixel856,298 despite low whole-frame MAE. Original raycasts at856/298,850/300 and860/300 intersect the interior corrugated_roof wall first (original traversal ordinal190), not a missing fixture or light mesh. First point is(9.6181456932,4.2460184857,-11.1300001144). Capture tools now record these visible-ancestor-filtered intersections and support normal/roughness/direct-specular/indirect-specular diagnostics that replace only corrugated_roof material output. Native diagnostics operate on temporary Shader instances, preserve original shader-path metadata and leave production shader files unchanged.

The source highlight survives the direct-specular output and disappears into the roughness display. ROI835,282–878,318 beauty MAE39.9109 vs full-frame1.3583; direct-specular ROI MAE31.6398; roughness ROI MAE4.9817. Thus the discrepancy is concentrated in the wall's direct specular response, with a smaller material/filtered-output difference also present. This does not yet establish whether normal mapping, roughness evaluation, direct-light input or another shared post term causes it. Source/native screenshots and scalar summaries are retained in main-paired-high-interior-{direct-specular,roughness}-* and interior-highlight-localization.json. Native diagnostic processes exit0 without shader errors. A normal diagnostic is the next probe; no arbitrary roughness or lighting change has been applied.


## Interior highlight explained by unmatched transient point input

Astra's read-only review in interior-highlight-adviser.md found pixel860,300 source/native normal and roughness differed by only one display byte, while direct specular differed by over200. The suggested sun/point split was performed rather than modifying normal/roughness formulas. Original no-points direct-specular pixel is[18,22,26], nearly the initial native[18,23,27], versus original all-points[249,242,231]. Original point metadata exposes an active first pooled point at(9.3081003049,4.0691011962,-11.3263721708), intensity2.5715036409, linear color(1,.9,.75), radius9,decay2. It is very close to the intersected wall. Initial native paired capture manually advanced world/rain/backdrop clocks to.05 but left transient FX pool at startup; same camera/time alone had not matched this light input. The baked export also contains this active snapshot light.

An explicit --match-source-pool diagnostic copies the six recorded original pool inputs into temporary persistent native test slots, preserving four actual warehouse lights. With production shader unchanged, direct-specular pixel860,300 becomes native[249,242,230] vs original[249,242,231]. ROI display MAE drops31.63975→3.32903. Actual pre-post HDR at the pixel is original[4.62109375,4.5390625,4.10546875] vs native[4.6015625,4.51953125,4.09375]; ROI HDR RGB MAE.02735965. See interior-highlight-matched-pool.json and main-paired-high-interior-spec-matched-* artifacts. The native process exits0 and log /tmp/saltline-main-paired-matched.log is clean.

This explains the major missing highlight as a diagnostic input-history mismatch, not evidence that the production tangent/BRDF must change. Residual ROI/filter differences remain; ordinary-game FX history synchronization is not established by copying a snapshot. Previous complete-scene MAEs remain descriptive of their recorded captures, but should not be interpreted as all dynamic state matched. The source capture now records lights and supports no-point/no-sun isolation plus true HDR FBO readback. Native HDR viewport readback is RGBH (format14,three half-float channels), while original FBO is RGBA16F; the first generic four-channel reshape failed and was corrected without changing data. Native dump files now use rgb16f with explicit channel/type metadata.

Astra also identified a diagnostic output mismatch: native roughness display used unclamped rr whereas original roughnessFactor was clamped. Future native diagnostic captures now clamp(.045,1); original historical roughness images remain historical. No production shader, light strength, roughness threshold or renderer precision was changed.


## Ultra hero asphalt and font-correct complete catalogs

export_material_catalog.cjs now fulfills the original font stylesheet with all eight locally pinned font files and records their SHA256 hashes. Complete high/low catalogs and the36-prop catalog were re-exported with these fonts; previous directories were moved intact into evidence/*-fallback-fonts for provenance. Same material ordinal/name/type identities hold. Full high and low each change14 non-procedural texture chains; props changes55. No procedural set texture hash changes. See catalog-font-correction.json. This corrects label/decal typography rather than resizing or retuning procedural materials.

The full Ultra catalog is now exported into assets/catalog/materials-full-ultra. Asphalt map/normal/ORM each2048x2048 with12 original GPU mip levels; full catalog contains175 meshes,85 materials,34 geometries and115 textures with206,296,024 original mip bytes. The initial Ultra export also lacked fonts and was retained separately before the corrected export. Catalog CLI --asset-quality=ultra --only=asphalt is now usable with the existing runner.

Actual Forward+ full high,low,ultra catalog probes each pass115 GPU mip hashes,175 lighting bindings and146 casters. Hero asphalt selection separately passes6 hashes including common concrete floor,4 bindings and3 casters. Full props probe passes124 GPU mip hashes,282 lighting bindings,177 casters and111 vertex-color byte checks for297 nodes. Current low Main regression after re-export passes76 mip hashes,390 UV bindings,20840 rain components and512 ground-query resolution. All terminal exit0 and failures empty; logs /tmp/saltline-catalog-{high-fonts,low-fonts,ultra-full,ultra-fonts,props-fonts}.log and /tmp/saltline-cold-low-catalog-regression.log. Hero screenshot material-catalog-full-ultra-selection-hero.png was visually inspected.

This supersedes earlier missing ultra asphalt and fallback-font caveats for these catalogs. Medium catalog is not separately exported, although main medium is supported. Alternate procedural sizes/seeds/options and whole showcase pixel parity remain distinct. r4 predates these catalog updates and the startup precedence fix.


## Interrupted CSS reversal for buttons and title bars

css_transition_timing.gd now tracks the reversing-adjusted start value and shortening factor for the zero-delay transitions used by title controls. Retargeting starts at the actual current value; reversing to the logical previous endpoint uses the eased old progress and old shortening factor to shorten duration. A third-state interruption starts a normal-duration segment. css_color_transition.gd keeps independent timing per background/border/text color and its existing premultiplied sRGB interpolation/legacy alpha quantization. title_bars.gd uses the same model with original.7s cubic-bezier(.2,.7,.2,1). Standard uninterrupted transitions are preserved. Reference: https://www.w3.org/TR/css-transitions-1/#starting (reversing rules400–418 in the fetched edition). No negative-delay/general CSS engine claim is made.

transition_reversal_reference.cjs samples original authored CSS in Chrome, replacing hover/active selectors with equivalent probe classes only to deterministically change states. Paused CSS animations seek exact elapsed times before retargeting. Unchanged properties retain their existing animation offsets. The initial probe incorrectly reset unchanged border progress and omitted the primary hover selector mapping; its invalid verification is retained as transition-reversal-invalid-persistent-sampling.json. Corrected reference includes ordinary/primary buttons, repeated hover reversal, active interruption and five repeated title-bar reversals.

Actual native model comparison passes432 color-component checks (max.00258565 normalized channel difference, existing.004 computed-CSS rounding tolerance),15 bar-position samples (max1.156e-6) and all bar shortened-duration checks. The original168 uninterrupted button checks and7 bar checks also pass. The actual production button process/draw GPU path passes36 interrupted-transition fill pixels within1.1/255,maximum.00320392. It uses injected clock and CSS-equivalent target states rather than physical pointer timing. Separate actual native hover/selected static pixel regression also passes five samples. See transition-reversal-verification.json, button-reversal-gpu.json and title-button-pixel-verification.json; logs /tmp/saltline-transition-reversal-bars.log,/tmp/saltline-button-reversal-gpu.log,/tmp/saltline-title-button-reversal-regression.log.

This closes reversal/active interruption for title-button color and title-bar transform transitions, not every HUD opacity/control transition, OS input timing or whole UI typography parity. r4 predates this production change.


## HUD opacity interruption and reversal

css_opacity_transition.gd wraps the shared zero-delay reversal timing with scalar interpolation. interaction_hud,radio_hud,location_hud,announcements_hud message alpha and status_hud health opacity now retarget from current opacity and shorten true reversals. Original durations remain interaction.15,radio/message.3,location.5 and health.12 fade-in/.6 fade-out. Location text reveal, radio content/timers, message expiry/HUD gate and health snapshot rules are unchanged. Legacy elapsed fields remain informational; the shared timing drives alpha.

Chrome reference now includes the five original authored classes h-prompt/comms/loc-card/h-msg/h-health, with six interruptions and three samples each. Short transitions are paused immediately after style flush: an early oracle waited a frame and accidentally completed sub-frame reversals before sampling, yielding misleading zero-duration segments. The corrected capture handles real cancelled/no-animation cases, retains actual durations and writes the complete fixture only after success. The first native invocation ran against an incomplete fixture and was stopped; subsequent temporary health stubs were also completed with pistol and rig data to avoid an unrelated queued draw error. Final clean headless run passes90 actual-control alpha samples with maximum4.1921e-7 and no failures/errors. See hud-opacity-reversal-verification.json and /tmp/saltline-hud-opacity-reversal-corrected.log. Health uses stub mission/weapon values solely to drive the actual status HUD update.

Regression passes14 location reveal/lifecycle samples,352 announcement/timer checks and9600 status snapshot comparisons. Actual Main360-frame GPU relay interaction also passes: proximity shows alpha1, held E advances ring, real relay completion increments cut1 and prompt ends alpha0/inactive. Log /tmp/saltline-interaction-opacity-regression.log, evidence/interaction-runtime.json. This verifies real composition and normal prompt lifecycle; rapid reversal accuracy is covered by the separate Chrome-driven actual controls test, not inferred from this steady gameplay route.

This closes the identified opacity reversal gaps in these five HUD components. Overall HUD/menu veil transitions, other remaining UI effects and physical scheduling are not covered by these checks. r4 predates this change.


## Parent HUD opacity and logical visibility gate

Original .hud uses opacity.35s ease plus class on, rather than instant disappearance. GameUI now drives its parent HUD modulate alpha through the shared CSS opacity/reversal model. It initializes invisible/alpha0 and retains rendering until the outgoing alpha reaches zero. New hud_on keeps the logical intro/playing-and-no-panel target separate: objective updates and announcement countdown gating follow hud_on, preserving original hidden-HUD timer behavior during the visible fade tail. Independent radio/location roots keep their own transitions.

The Chrome fixture now includes original .hud alongside the five child opacity classes. Actual Main GameUI checks18 samples across six retargets, including fast reversals, with maximum alpha error1.943e-7 and no failures. It separately checks logical target, actual visible flag, announcement timer advancement only while logically shown and panel suppression. See hud-parent-reversal.json and /tmp/saltline-hud-parent-reversal.log. This uses controlled flow-state assignment, not native pause button input.

The previous full mission verifier expected instant visual hiding ten frames after completion, which contradicted the newly restored original.35s fade. It now checks logical closure at that moment and adds a separate zero-alpha/hidden assertion after the original fade duration. Full1100-frame GPU integration passes15 checks: three actual E holds from controlled positions, real extraction, HUD fade completion, delayed debrief and redeploy back to playing. See full-mission-runtime.json and /tmp/saltline-full-mission-hud-fade.log. Teleported poses/invulnerability are explicit; this does not supersede the separate normal-resource from-spawn mission evidence.

Menu veil backgrounds and their own.5s opacity transition remain a separate known visual gap. r4 predates parent HUD and other recent UI changes.


## Menu veil opacity, dual title gradient and death background

GameUI now keeps a shared.5s CSS opacity transition for menu veil backgrounds outside menu_root, so closing the menu can hide interactive/content controls immediately while the veil fades out. Screen changes select the CSS background immediately: title uses both horizontal and bottom vertical gradients, paused/complete/none use rgba(6,8,10,.62), dead uses alpha.35. First initialized menu value is applied without an artificial boot transition. Repeated show calls keep the active transition; closed/transparent veils stop drawing. The new canvas shader preserves incoming modulate alpha. The previously omitted bottom title gradient and incorrect dead background alpha are now present.

menu_veil_reference.cjs captures original CSS over white at four diagnostic opacities for title/paused/dead/none (16 PNGs), plus18 samples across interrupted open/close transitions and open-to-open background changes. Persistent CSS animation progress is retained when only the background mode changes. The initial implementation retained a TextureRect type annotation while replacing it with ColorRect; that failed run is preserved as menu-veil-initial-type-failure.json and corrected. An early oracle also reset unchanged opacity animation progress on dead→complete; corrected capture preserves it.

Actual Main UI test now passes all18 scalar samples with max4.342e-7.142/144 RGB pixel checks are within1.1/255; two title-gradient points at opacity.8 remain2 bytes different. Threshold was not increased and final pixel verifier remains failing for these two observations. Unquantized endpoint version had three such differences and is preserved as menu-veil-unquantized-gradient-failure.json. Current endpoint alpha quantization uses209/255,128/255,179/255. At right-bottom1216,680 source/native opacity1 both[101,102,103], but opacity.8 source[130,131,133] vs native[132,133,134]. This needs grouping/compositing/reference investigation rather than an arbitrary brightness offset. Astra has been asked for read-only diagnosis. See menu-veil-verification.json and /tmp/saltline-menu-veil-alpha-quantized.log.

This stage implements the missing visual layers and fade behavior but does not claim complete CSS pixel parity. r4 predates these changes.


Astra's menu-veil-adviser.md confirms the mathematical layer order and points away from per-layer opacity/modulate quantization. The recommended Chrome A/B was executed in one browser process by menu_veil_composite_reference.cjs: A original dual CSS gradient opacity.8 on white, B original opacity1 transparent RGBA capture used as an img with opacity.8 on white. Full RGB arrays match exactly (MAE0,max0). The original transparent pixels show premultiply/unpremultiply quantization:1216,680=[5,6,10,158],640,680=[4,7,9,189],640,64=[6,6,9,83], instead of an ideal constant RGB6,8,10. See menu-veil-composite-reference.json,menu-veil-composite-A/B.png and menu-veil-original-transparent.png. This supports investigating an intermediate image/composite representation; it does not itself prove a native SubViewport or any proposed rounding formula. No further endpoint tuning was done.

Actual Main focus/pause/resume regression after veil changes passes12 checks and all four simulation clocks stay frozen while paused. Log /tmp/saltline-menu-veil-focus-regression.log. Remaining two-byte gradient observations are still open and the pixel verifier is not reported as passing.


## Reference RGBA blend isolation and CSS result-menu buttons

The existing menu-veil GPU verifier now supports --veil-reference-texture as a diagnostic: original Chrome transparent RGBA capture is sampled directly by a temporary native canvas shader. It still has one2-byte observation at title opacity.35/64,680 (source175,175,176 vs native176,177,177). Two previous opacity.8 sites move within one byte. All18 scalar samples remain aligned. See menu-veil-reference-texture.json and /tmp/saltline-menu-veil-reference-texture.log. Thus importing a fixed screenshot is not by itself a complete cross-backend blend solution, and no fixed-resolution bitmap/SubViewport substitution was added to production. Existing analytic shader residual remains documented without threshold change.

A separate confirmed visible gap was result-menu button rendering: GameUI._button used the original CSS custom draw class only under title, leaving pause/dead/complete actions on native Theme styleboxes with different hover fills, typography and transition behavior. The factory now selects the same CSS button class under result card descendants as well. Settings panel widgets retain their separate path; this is scoped to actual .btn action controls. Redundant older approximate pause_veil color assignment was removed so the new exact veil mode owns the first frame too.

Actual Main UI probe verifies six action controls across paused/dead/complete: resume/settings/controls/restart/retry/redeploy all use the CSS script, accept injected native mouse hover, and return original ordinary translucent hover or warm primary hover colors. The shared draw implementation is already covered by standalone GPU color/transition tests. Captures result-buttons-{paused,dead,complete}.png show actual screens. A normal zero-dt Main initialization frame was added before this controlled static probe to avoid displaying an uninitialized radio label in screenshots; this was a test setup artifact. Final probe failures empty, log /tmp/saltline-result-buttons-final.log. Focus/pause/real Resume signal regression passes12 checks with all simulation clocks frozen while paused, log /tmp/saltline-result-buttons-resume-regression.log.

This improves actual menu controls without changing their signals/actions. It does not prove full panel widget CSS or whole menu layout/font parity. r4 predates these changes.


## Settings panel tabs, small buttons, segments and sliders

Panel header tabs now use panel_tab.gd: original Barlow600/15px,3.3px tracking, steel/selected-bone text, transparent background and3px signal underline, with22px sibling spacing and focus outline. Header body height/separator and small Close placement follow the authored CSS measurements. Close/fullscreen use the same custom CSS small-button draw path (12px/.22em) instead of native theme buttons. Fullscreen text reports Enter/Exit based on actual window mode while the panel is open; fullscreen action behavior remains the existing DisplayServer toggle.

Panel segmented controls now use panel-specific CSS mode:13px/.16em,transparent unselected fill,bone selected fill,40px height and one-pixel adjacent border overlap. Title segmentation keeps its existing12px/.16em mode. The initial Three-quarter control retained a larger previous-font minimum size; explicit size reset after segmented font configuration corrected the overlap. The failed probe is preserved as panel-css-initial-font-minimum-failure.json.

New panel_slider.gd retains native HSlider range/input/value signals but replaces theme visuals with the original2px track and10x22 signal-yellow rectangular thumb, without filled progress track. It draws keyboard focus outline while suppressing it for pointer input. Input height is28 and numeric output uses original13px mono. Invert toggle and detailed panel labels/control tables retain their older visuals and remain separate work. Audio controls remain intentionally excluded by the goal.

Actual Main panel probe passes29 checks over10 segmented choices/two sliders: script wiring,active tabs,small-button size mode,segment dimensions/overlap,selected and slider GPU fill colors, actual native mouse click changing sensitivity to2.3, and real controls-tab button signal. See panel-css-verification.json and panel-css-settings.png, log /tmp/saltline-panel-css-final.log. The screenshot uses controlled fade0 and zero-dt GPU warmup so static setup does not leave the initial world fade black. This does not claim original full-panel pixel equivalence.

Actual Tab/ShiftTab/Escape dialog focus/return, setting readouts and pad adjustment pass50 frames, log /tmp/saltline-panel-css-focus-final.log. Four-window panel bounds/focus-scroll regression1280x720,960x540,640x360,320x568 also passes (performed before the final slider-only visual adjustment), log /tmp/saltline-panel-css-sizes.log. All successful processes exit0 with no script errors. r4 predates these changes.


## Original-style invert-Y toggle and focus modality

Native CheckButton pill graphics were replaced by panel_toggle.gd, retaining Button toggle_mode/toggled signal semantics and the existing invertY settings path. It draws the original44x22 border box,16x14 thumb at inner4px inset,20px enabled travel,13px IBM Plex Mono On/Off label and12px gap. Thumb transform and background use the shared.12s CSS default-ease reversal models; border selection changes immediately as authored. A separate INVERT Y label restores the original row structure. The surrounding fixed-row layout is not claimed fully matched.

Toggle/slider/title CSS controls now expose a shared show_keyboard_focus hook. GameUI Tab and controller navigation focus the target then request its keyboard outline, preventing a prior pointer click from leaving the new toggle/slider outline suppressed when keyboard/controller navigation resumes. Pointer press still suppresses keyboard-only outlines.

Original Chrome ::after transform/background reference through four interrupted toggles yields60 production process checks, maximum shift error3.074e-6px and color channel error.00340007 within existing computed-CSS rounding tolerance. See panel-toggle-timing.json and /tmp/saltline-panel-toggle-timing.log. Actual Main GUI mouse click toggles/apply invertY true, actual Space toggles false, controller navigation selects the toggle with visible focus and pad_accept toggles true. The completed active thumb GPU sample is exactly signal RGB(1,.7019608,.2784314), with no failures. See panel-toggle-runtime.json/panel-toggle-on.png and /tmp/saltline-panel-toggle-runtime.log. Device hardware, border/font pixels and full-panel layout are separate.

This closes the explicit native-pill toggle visual gap; detailed control-table glyphs, panel label tracking/row spacing and complete font/layout parity remain open. r4 predates this change.


## Rich original controls tables and notes

export_control_content.cjs executes the immutable bundle's literal sL/oL/rL HTML constants and controls-pane template, then uses original CSS and all bundled fonts to extract semantic heading/table/note blocks and actual row metrics. assets/export/control-content.json contains30 control rows,33 kbd elements,three headings in original Keyboard/Touch/Controller order and the omitted keyboard mouse-capture/arrow/IJKL/Enter and controller menu-operation notes. Only the final sound-unlock sentence is intentionally omitted for the explicit no-audio goal. Source bundle SHA and this omission are recorded. Pane metrics are retained for subsequent full layout alignment.

control_content.gd replaces the previous plain HBox labels/oversized headings with responsive rich drawing: original12px label/13px binding Barlow500 tracking,11px Barlow600 headings and separators,10px mono key boxes, and11px mono note wrapping. Inline key boxes retain margins,padding/minimum width and baseline treatment. Note/table flows recalculate on content width changes; static content ignores mouse input and does not enter focus traversal. Rendering is rebuilt on resize rather than reshaping all glyphs every frame. This remains a native font/layout approximation, not a glyph-pixel parity claim.

Actual content checks at widths382,262,200 retain exactly30 rows,33 key boxes and3 headings, with content heights976,1011,1099 showing responsive wrapping. Actual Main GPU captures at top/middle/end were inspected, including the restored controller menu note and no sound guidance. Legacy screenshot names that falsely implied fixed table positions were changed to controls-middle/bottom. Final focused runtime verifies three focusable header controls, native Tab/ShiftTab wrap, delivered mouse wheel movement (313px), scroll-end capture and Escape returning focus to title Settings. See control-content-verification.json,controls-panel-runtime.json,controls-keyboard.png,controls-scroll-end.png; logs /tmp/saltline-control-content-final.log,/tmp/saltline-control-content-gpu.log,/tmp/saltline-rich-controls-runtime.log.

An initial direct --script invocation incorrectly attempted to launch a Control script as SceneTree; it exited before running the content. The proper verifier instantiates it in a SceneTree and passes. Successful runtime processes exit0 without script errors. Full browser/native typography, panel row spacing and all-size pixel parity remain separate; r4 predates this content.


## Consolidated independent runtime bundle r5

output/linux-runtime-20261116-r5 now includes all recent production work: original-font high/low/ultra catalogs and props, Ultra2048 hero asphalt, correct explicit startup-quality precedence, button/bar/HUD opacity reversals, menu dual-gradient/death veil modes, CSS pause/result actions, panel tabs/segments/sliders/invert toggle and original rich controls content. The pinned isolated engine is unchanged.4383 manifested files total2,609,368,156 bytes including updated launch/readme notes. Every file SHA256/size was verified again after all runtime probes; zero failures. Packager template and r5 README contain identical new-feature/Ultra launch notes. Source README identifies r5 as latest; r2/r3/r4 remain unchanged historical bundles.

Six GPU processes launch from /tmp through the package's own run.sh and engine, each with isolated user data. All terminal exits0 and logs contain no script/shader errors: default eight-frame boot; low Main focus-pause/clock freeze/actual Resume; saved ultra plus explicit low retaining low then live menu medium; rich controls30 rows,three header focus targets and wheel313px/close return; Ultra asphalt six original GPU mip-chain hashes,four lighting bindings/three casters; invert toggle actual pointer/Space/controller-method setting paths and exact signal thumb color. The controls runtime measures actual content width390,height958 in this desktop panel.

External verifier scripts supply test logic only, loading actual package res:// Main/assets/UI. They are not runtime dependencies and research/evidence tools remain excluded from the package. Generated package evidence is outside the immutable manifest file set. See evidence/runtime-bundle-r5-verification.json and /tmp/saltline-r5-{integration,precedence,controls,boot,ultra,toggle}.log.

The package remains an unpruned source-based Linux development runtime, not completion of visual fidelity. Known small gradient/noise residuals, panel/font/layout details, alternate source generation options and other pending goal requirements remain. This package makes the accumulated validated changes runnable for review without waiving them.

## 2026-11-16：Ultra 阴影频率与暂停 Start 分层返回

依据当前完成范围审计，修复原 `ov.Z()` 的 Ultra 逐帧阴影策略：RenderQuality 现将每帧策略传入 SunShadowPass，其他档位保留半频，首次及 resize 强制刷新不变。暂停时的 Start 在 GameFlow 原 pause_delay 到期后先消费为关闭 Settings/Controls，下一次释放再按才恢复；标题 Start 行为不变。

新增 `tools/verify_quality_pause_runtime.gd`，实际 Main + NVIDIA Forward+ 渲染，High/Ultra/High 更新序列分别为 1010/1111/1010，10 项检查通过，覆盖 debounce、按住不重触发、Settings/Controls 返回和释放后恢复。报告 `evidence/quality-pause-runtime.json`。验证不证明运动阴影像素一致或实体手柄事件交付。首次验证退出时遇到延迟 focus 在节点离树后的报错，测试清理前等待 deferred focus 后复查。r5 历史包未修改，本次源码修复尚未重打包。

复查发现该 focus 报错来自同帧开关面板后，旧控件的 deferred grab_focus 仍被调用；单纯延后测试退出不能解决。生产 GameUI 已统一通过 `_focus_if_live` 检查实例有效且仍在树中后再获取焦点，保留有效控件的原焦点行为。最终复查日志 `/tmp/saltline-quality-pause-final2.log`。

## 2026-11-16：BD 武器具名近景入口首批接线

新增 `scripts/weapon_showcase_runner.gd`，支持原 BD 的 8 个步枪及 7 个手枪世界空间近景。`assets/export/weapon-showcase-views.json` 直接从 immutable bundle 的 BD 局部 s 对象求值得到（Math.PI 保留原公式结果），相机、目标、FOV、枪根旋转与高度沿用原值。实时 vS/Fh 使用 HIP 逆旋转/位移肩部转换，双臂实际重父级到枪根并切为世界层；不生成替代静态模型，不改普通游戏管线。首次步枪 side 实机 12 帧退出 0，无报错，截图已人工查看，可见全枪侧面与双手握持；不据此声称全图像素一致。仍缺 BD 第一人称动作及 TD 独立 hands studio。

手枪 grip 同样实机 12 帧退出 0，无报错；截图人工确认握把、手指、手套布纹可见。两组报告与 PNG 位于 `evidence/weapon-studio-{rifle-side,pistol-grip}.*`。新增 `tools/export_weapon_showcase_views.cjs` 可重放 15 视角表导出，并写 immutable bundle SHA256 provenance。

## 2026-11-16：TD 手部工作台初次接线

新增 `scripts/hands_showcase_runner.gd`，复用原 source 双臂网格、skin 与 70 根实时 Fh bones；原 TD 的 back/palm/side/arm 相机、studio 高度 1.16、X 轴 PI/2 及 palm 本地 Z 轴 PI、直臂肩部 ±.125/0/.57 已接入。支持五种初始 di 手势、左右独立手势、原余弦 trigger 动画与手势混合、固定湿润度。`tools/export_hands_showcase_poses.cjs` 从 source bounded di 对象提取 Float32 手势并记录 SHA；初版导出脚本把五种误计为六种，保护检查拒绝，修正计数后成功，不影响已生成数值。

掌心 open 12 帧、手背 relaxed+anim 30 帧实际 Forward+ 启动均退出 0，无运行错误。截图 `evidence/hands-studio-palm.png` / `hands-studio-back.png` 人工查看；后者 report 无失败，trigger .00111069965 → .70807341827，全部骨骼值有限。这证明入口和部分可见状态可用，不证明与原版整图一致。后加 hblend/hwet 需另一次实际运行验证。TD fp 握持、任意 hgun/hgrip 与 BD 第一人称动作仍待接入；历史 r5 不含工作台代码。

后加参数已实机复查：side + open/fist 固定 .5 混合 + wet .8，12 帧退出 0，骨骼有限检查无失败，日志 `/tmp/saltline-hands-studio-blend.log`。报告 scope 继续明确 FP 等剩余项。

## 2026-11-16：TD 第一人称握持与最终拟合手势

Astra 源码顾问确认原 JE(Ey()) 会覆盖初始 fist 并新增握持姿态。导出器已改为执行 immutable bundle `var Us = K` 到 `var zy = {}` 的完整 CPU 字面段，并调用 JE；原 bundled Three 数学提供 Vector3/Quaternion/Matrix4，无 Godot 反向生成 expected。现导出最终 15 项 di、10 个 nn.frame 及 SHA256 provenance。此前初始 fist 不再作为当前数据；rest/relaxed/open/flat 保持。VM 引擎初始化首次因 AbortController 缺失退出，改用既有 source-engine eval 路径后成功。

新增 `hands_studio_socket.gd`，实现原 M5/Fh.socket 的精确左右反射，runner 接入 TD fp 默认枪位姿、YXZ Euler、肩位置、lean=.2 和右手 trigger。双臂挂 view camera，局部 identity/layer2，隐藏枪械以匹配 TD。未用普通武器 rigs 的 fitted holds 替代独立 TD frame。支持 --hview=fp --hheld=rifle|pistol。

`verify_hands_studio_socket.gd` 对原 literal M5 的四组默认左右手独立 fixture 通过，最大位置/旋转度量 3.6500243e-8（报告把位置米与 quaternion dot residual 取 max，不能解释成统一角度）。首次 headless 的默认 user log 路径受限，改 XDG_DATA_HOME=/tmp 后无日志错误退出0。步枪 fp+anim、手枪 fp+anim 各30帧实际 NVIDIA Forward+ 运行，report 无失败，骨骼有限，trigger .0011107→.7080734。截图 `hands-studio-fp.png` / `hands-studio-fp-pistol.png`，未证明原版整图像素一致。BD 第一人称动作及 TD 任意 hgun/hgrip 参数仍待接入，r5 包保持历史不变。

## 2026-11-16：BD 第一人称动作入口

武器 runner 扩展 hip/ads/sprint/fire/reload/empty/locked，复用实时 root、机械件、Fh 与原渲染链。默认相机 (0,1.68,4) 向 south [.28,-.01,1]，FOV74，ADS52；snap 使用现有原 D 状态接口。reload/empty 默认固定 .62 秒，可 --wt 指定：新增默认关闭的 Weapon.debug_reload_time，原 O 相应分支固定 t 且不因到达 T 自动结束。debug_flash 默认关闭，新增可选 motion_controls 参数使 finger 在单次原 damping 中趋近1，weapon effects 设 seed3.7、duration.05、time.03、def.flashScale；不发射弹药、不加入替代静态动画。

实际 Main：rifle ADS12帧 report ads1/FOV52；pistol empty12帧 report t=.62；均退出0、无错误，截图已生成。普通 Weapon 回归10checks/39shots通过；原 O controls211164比较/4900production steps通过，最大1.42e-14，证明默认关闭未改变所覆盖控制行为。并非完整普通游戏/所有 GPU 回归。switch、wlook/wview 与任意 TD hgun/hgrip 仍缺，不宣称工作台全部参数完成。

fire 最终自动断言实机复查无失败：闪光可见、shot_count仍0。新增 verify_weapon_debug_reload 检查 t=3.0 超过原 T 后仍保持固定换弹，撤销 debug 参数后正常结束，两项通过。报告 `evidence/weapon-debug-reload.json`；固定时刻超过时长的路径与原 debug 语义保持一致。

## 2026-11-16：BD 切枪、观察方向与位姿选择

runner 新增 switch（默认 .14，可 --wt 覆盖），先 .016 更新/snap，再调用真实 switch_to，以原 .005 步进推进，随后冻结 weapon 更新而保留环境渲染。新增原 south/east/north/west/nw 向量选择，以及现有 Weapon.set_view 的 1–3 位姿选择。近景 --wempty 锁定、--wt 固定换弹亦接入；近景现在执行完整 Weapon.update 的机械/换弹阶段，只保留 root 固定，以贴合原 freeze 分支。

实际 NVIDIA Forward+：rifle switch + east + wview2，12渲染帧后仍冻结 holster t=.135（与 fresh 首步不推进语义一致）、live root/arms29步，报告无失败、无错误，截图 `weapon-studio-rifle-switch.png` 已查看。pistol grip + wempty + wview3，12帧无失败/无错误，截图 `weapon-studio-pistol-grip-locked.png` 可见滑套后定。只是这些组合的生产入口证据，未做所有组合或原版整图逐像素验收。原 BD 的任意 cam/fov/exposure 与 TD hgun/hgrip 参数仍未在这些 runner 接入，不能据此宣称工作台全部参数完成。r5 历史包未改。

## 2026-11-16：TD 自定义 hgun/hgrip

手部 runner 新增 hgun 3–6 数值（YXZ 弧度、缺省角0）与 hgrip 三数值。原双手 foregrip 分支按 anchor x±.11、原正交 basis、原 Fh.socket 镜像及 lean=.15；默认枪分支保留 lean=.2。显式手势/混合优先于自动 foregrip，不把 grip 误映射为扳机手势。支持报告独立命名，避免 fp 各配置覆盖同一份证据。

实际 Main：fp hgrip=0,-.15,-.4 + anim30帧、fp pistol hgun=.12,-.1,-.45,.05,.15,-.05 + trig.7 12帧，均无失败、退出0、无错误；截图为 `hands-studio-custom-grip.png` / `hands-studio-custom-gun.png`。日志逐行提取 JSON 保存两个具名配置报告。`verify_hands_custom_inputs.cjs` 使用原 bundled Three 独立计算 TD anchor/basis，和实际 runner 输出对照；它校验输入坐标而非完整 IK 或原图像素。BD 任意相机/fov/exposure 入口、整体最终范围验收及新版包仍待完成。

## 2026-11-16：TD 更新时序与独立湿润度修正

逐句复核 TD 759xx update 后修正 runner：setup 调用一次 y 对应 `_apply_pose`，静态姿态此后只执行 Fh.update；仅 trig=anim 或未指定第三项的 blend 才每渲染帧重求姿态/IK。此前每帧 _grip 的做法已替换，避免额外改变 IK 历史/惯性。显式 blend 第三项即使为负也保持原 tn 外插，不能用负值作为“自动”标记。

TD 无 weapon，所以原 kh 默认 .7 且 hwet 直接赋值，不经过 Weapon.setWetness 的0–1截断或室内衰减。runner 每帧渲染前仅向实际 arm material 的 uArmWet 写入原值，不改变主游戏全局湿润度行为。

实际 Forward+：静态 fp pistol trig.7，12帧pose_updates=1；动态 fp grip trig=anim，12帧pose_updates=13；两者均无失败、无报错。另检查 palm/open,fist,-.2 + wet1.2 的静态外插与实际 uniform绑定，日志 `/tmp/saltline-hands-negative-blend.log`。报告与截图只证明对应工作台状态，未代替原版全图验证。旧生成截图保留作过程证据。

## 2026-11-16：r6 独立运行包

新增共用 studio_render_options，两个工作台支持 --cam 六数、--fov、--exposure，后者关闭自动曝光并同步 post/AO/streak uniforms。源码实际武器 side 指定 cam/FOV35/exposure1.2 后 report 正确。

`output/linux-runtime-20261116-r6/` 已生成，4393 manifested files / 2,609,403,368 bytes，固定引擎 hash 未变；r5及更早包不覆盖。打包 README 新增工作台启动命令与范围。三次从 cwd=/tmp、隔离 XDG 的 NVIDIA Forward+ 包内启动（工具逻辑除外，res://均来自包）：手部 palm/open/FOV30/exposure1；武器 pistol empty t=.62/exposure1；外部 quality_pause verifier 加载包内 Main，10检查通过、High/Ultra/High 1010/1111/1010。全部终止0、无运行错误。运行后的 manifest 大小与SHA重读结果和完整运行报告见 `evidence/runtime-bundle-r6-verification.json`。

本包仍为未裁剪 Linux 开发包，非完整视觉/玩法验收声明。尚需原版工作台动态状态/整图的更强对照，以及全目标范围最终审计；已知少量跨后端噪声与菜单渐变偏差保持原记录，不因打包消失。

## 2026-11-16：UM 自动设备画质启动

新增 `device_quality.gd`：原 UM 的显式档位、mobile UA、小屏多触点、软件渲染器/Mali/Adreno/PowerVR、Intel 非 Arc 判断均作为可独立调用 predicate 保留。native adapter 使用 OS.get_name、实际 RenderingServer.get_video_adapter_name 与 DisplayServer.screen_get_size（已核对 pinned 引擎 class docs）；桌面没有浏览器 maxTouchPoints，明确 touch_points_known=false 并置0，不将普通触屏能力当作多触点。Android/iOS 的原生OS名映射：Android 匹配原UA；iOS 映射仍需修正/验证。

SourceScene 冷启动默认使用检测档位，原 --cold-quality 继续显式覆盖；已保存设置对渲染的优先级沿用原 startup_name，实时菜单不重烘焙纹理。`device_quality_reference.cjs` 用 literal UM + browser stubs 生成34cases，native predicate全通过。实际本机描述为 NVIDIA GeForce RTX4070SUPER、3840x2160、Linux，选择high；Main quality/pause10checks通过。报告 `device-quality-native.json`。其他硬件类是fixture覆盖，不能声明已实机验证。r6保持历史版本，本次源码改变未打包。

显式 Low 覆盖保存 Ultra 的实际 Main 复查通过：low源资产76贴图替换/4760雨实例，渲染low；实时菜单medium生效且源资产不变。iOS adapter 现将 OS名iOS映射为iPhone以命中原mobile判断，补纯映射断言；未声称iOS设备已运行。

## 2026-11-16：工作台原始环境差异修正

重新检查原 showcase bootstrap 85858–85903，发现早期两个 runner 错误保留 Main 港区环境。已新增 weapon_studio_environment 共用隔离：隐藏 Main 世界几何/静态灯/雨，仅恢复 sky、枪械与双臂；使用已导出的原80×80 Plane concrete几何（无vertexcolor、不cast shadow），清空 interiorBoxes/physics boxes、释放光池并禁 Main planar。原 studio viewFill 受空 interiorBoxes gate 固定1.1，现每帧重设并按dt0上传；BD arm kh默认.7，TD再应用自己的hwet。早期港区背景截图是过程版本，不能作为原 BD/TD 环境一致性证据。

Astra 顾问另确认 BD closeup world-layer mesh 仍使用 weapon-depth polygon bias；现 _layers 切世界层时仅调用已有 drop_view._world_material 的 shader variant 转换，不调用会改变 castShadow 的drop遍历。这样原 polygonOffset(-3,-3) 使用 world 单位，保持源cast flags。普通游戏和drop流程未改。

已实机生成 `weapon-studio-isolated-side.png`，运行12帧无失败/无报错；后续共用 viewFill/wet/bias 修正仍需新的对照。r6为之前环境版本，不宣称已含本次修正。整体原图对照仍待完成。

最终隔离复查还发现 Rain.update 会重新打开可见性；现 studio 将level/target=0、禁雷暴计时，并在after_frame明确隐藏rain/splash。`weapon-studio-isolated-side-final.png` 最终实机12帧无失败/无报错并人工查看，无港区/海/雨，只保留原studio地面/天空。此前 isolated-palm 截图仍含雨丝，作为失败过程证据保留，不标为最终环境一致。

Astra 进一步确认 __setShot 的 exposure 只写 multiplier、不关闭auto；现 --exposure保持auto，另加 --manual-exposure供固定曝光研究使用（r6旧语义不同）。BD默认改hip；wads限制为fire/locked（ads本身始终瞄准），不扩展到sprint/reload。尚缺原统一 snap→update(.016)→snap 初始化及首次update内部debug装填的语义修正，已定位，不能声称工作台全面完成。

## 2026-11-16：BD 初始化与调试装填语义

Weapon 现把普通 reload context 建立抽到 `_begin_reload(empty,emit_start)`；正常 reload_now 保留原弹量/储备检查与start事件。调试 reload_time 在首次 update 内绕过普通检查创建 context，允许满匣且不发start；原 debug_reload_empty 参数单独传入，不再伪造6发弹药。runner 统一 snap→update(.016)→snap（closeup 跳root D，动作入口执行D），再处理 switch 的 .005 stepping。

实际 Main pistol reload t=.62，初始化后ammo15、1次初始化更新、12渲染帧 live steps13，events只有magout、无start；rifle side+wt=.62同样ammo30、1次初始化、live13、无start。均无失败、退出0、无错误。正常Weapon回归10checks/39shots通过；debug reload逻辑测试满弹保持/不发start/超T时间仍固定/撤销debug正常完成均通过。

复核原 hL(86178)，studio共用环境现在显式设置pos(0,0,4)、eye(0,1.68,4)、yaw/pitch0、vel0、forward-Z、onGround、非蹲跑、enabledfalse；此前直接复用Main出生点状态会污染 D 的碰撞/运动输入。该最后适配仍需实际动作入口复查。原整图与骨骼状态更强对照仍待完成；r6未包含这些修复。

原 hL 玩家状态适配后的默认 hip 实机12帧复查通过，无失败/无错误，截图 `weapon-studio-default-hip.png`。

## 2026-11-16：首次原 BD 侧视整图配对证据

新增 capture_weapon_studio_reference.cjs，以本地 immutable HTML、8种本地字体映射、Chrome ANGLE GL 抓原 show=weapon/wgun=rifle/wpose=side，高档shot/step固定三步（t=.05），手动曝光1、12次零dt预热，页面错误0。原图 `weapon-studio-rifle-side-source.png` 与 JSON 含实际camera/场景mesh/骨骼及局部高亮ray信息。源相机p=(1.12,1.3,.11)、FOV30，与native配置一致。

runner 新增 --studio-warmup=12，仅推进零dt渲染不改武器物理；native同3步+初始.016，livearms4步，报告无失败/无报错。图 `weapon-studio-rifle-side-paired-native.png` 与source比较：RGB8 MAE .5629474，p95=2，p99=8，max164。差分x4 `weapon-studio-rifle-side-diff-x4.png` 已查看，大多数场景背景接近，残差主要集中枪体高光、标记与边缘，少数强点不能用平均值掩盖。此为描述量，不设置通过阈值，不等同于所有工作台/主游戏完整视觉通过。骨骼数据当前只抓原端，native逐骨骼配对仍待处理。

## 2026-11-16：原 BD 双臂逐骨骼配对

原capture为70根bone增加arm-left/right祖先标识；native runner 导出实际 source_node local transform（即 set_source_transform 同步到 skin pose 的输入），不只比较模型内部 solver cache。双方同rifle side、初始化.016+三步、manual exposure1、12次零dt预热。70对齐、missing/extra均空；最大local位置差3.33044e-8米，归一化四元数同号等价最短L2差1.18365e-7。`compare_weapon_studio_bones.py` 可重放，位置1e-6米/四元数分量2e-6门槛，未改历史shader像素阈值。这只证明该状态骨骼locals，不证明任意姿态、蒙皮逐顶点或整图。

原截图重新抓取0页面错误；原与native图片比较保持前述描述性指标。ray(660,359)命中pac9_anodised面及后方brass，说明局部亮点位于枪体材质路径，不能直接归因手部IK或未经核对的新灯。原端JSON记录70骨骼与ray；本地HTML SHA已附provenance。native测试无失败/无报错。下一步应对材质/光照高亮做有针对性的诊断，不能以该单图gate宣称整个目标完成。

## 2026-11-16：pac9_anodised 法线/粗糙度局部诊断

新增只在 --studio-surface 显式开启的材质诊断（默认生产shader公式不变），原端通过onBeforeCompile opaque前输出，native使用保留source shader metadata的临时variant输出最终法线/粗糙度/可选镜面分量。原与native同side/3固定帧/曝光1/12零dt预热，所有进程退出0、无运行错误。diagnostic报告单独命名，避免覆盖beauty报告。

目标像素(660,359)：normal RGB source195,175,205 / native202,176,203；roughness source156,158,158 / native173,172,167。普通枪体点(800,320)两模式分别179169208/180177171均逐字节一致。40×40ROI [640,340,680,380] normal MAE1.36708、p95=6,max43；roughness MAE1.20979,p95=5,max29。均为经过后处理的诊断图，不能直接把RGB当原始normal或roughness数值；ROI含边缘。数据表明目标高亮附近两种材质输入均存在差异，不能只凭beauty平均值推断BRDF坏掉或手部IK偏移。原source高光ray前层为pac9_anodised；骨骼证据继续有效。

证据：weapon-studio-rifle-side-{source,native}-{normal,roughness}.png、weapon-studio-{normal,roughness}-roi.json。已向Astra请求下一步最小高频detail/derivative定位实验；未修改生产材质公式或放宽任何像素门槛。

## 2026-11-16：实际几何线性 HDR 材质分量定位

依Astra建议扩展显式diagnostic为grain/noise；原__G renderer hook在实际scene/camera的HalfFloat world target后readPixels保存RGBA16F，native保存world_port Image RGBH(format14)。明确原bottom-to-top与native top-to-bottom，读取脚本 `compare_weapon_studio_hdr.py` 可重放，保留原几何与MSAA，避免从色调映射PNG反推shader标量。补ray pixel center(+.5)，射线仅定位对象，不充当MSAA实际fragment输入。

目标(660,359)与4×4 [659,358,663,362]：grain三通道(dGr+.5,dNear,dDrop)一致，目标(.5,0,0)，near全0，drop边缘双方同.1766357；因此该处 finest grain 被fade关闭，不能把此次法线/粗糙度共差归因dGr。noise三通道(dLo,dMid,dRun)目标source(.5732422,.3249512,0)、native(.6191406,.3066406,0)，quad最大差(.0458984,.0183105,7.15e-7)。实际分歧已缩到低/中频noise，尚未证明是domain插值、格点或hash算术顺序。

全部source页面errors0、native报告failures空、进程退出0，无报错。原始HDR文件、PNG、JSON及比较报告均在evidence/weapon-studio-rifle-side-{source,native}-{grain,noise}.*；已向Astra请求最小格点/hash实验，未调整生产noise guard/FMA或验收阈值。另修wview解析直接传字符串到现有set_view，避免1.6被提前int截为1；该小修仍需参数实机复查。r6仍为历史包。

## 2026-11-16：高光异常归入 MSAA 覆盖分支

按顾问新判断先抓实际fragment domain而非换hash。domain(dQ*34)目标原[-1.4423828,-2.6757813,-1.2734375]、native[-1.3603516,-2.5839844,-1.4316406]；差(.08203,.09180,.15820)，反解object位置X约-.02308与-.01720，明显不是同一坐标的微小FMA差。原ray有前后两层同材质表面，MSAA下resolved domain不能简单归为同一fragment位置。

新增仅诊断 `--no-msaa`（source调用真实 render.setQuality({...quality,msaa:0})）与 `--studio-no-msaa`（native world/weapon port禁MSAA），其他相机/时间/material保持。单样本noise目标两端逐half一致[.61962890625,.3212890625,0]；4×4低中频最大差0，run最大7.15e-7。所有进程退出0、source页面错误0、native无失败/报错。证据 `weapon-studio-domain-hdr-comparison.json` 与 `weapon-studio-no-msaa-hdr-comparison.json`、对应原始HDR/PNG。

因此当前证据支持优先检查原GL与nativeVulkan MSAA覆盖/centroid/sample shading/重叠表面resolve，不支持先改dh3 FMA顺序。本次没有关闭生产MSAA、降低画质或修改hash来掩盖误差。已请Astra继续只读比对两端采样/插值路径。整体高光偏差仍未修复，不能把诊断匹配当最终画面通过。

本轮按新用户AGENTS要求补查：root AGENTS仅构建说明，Saltline scripts/tools目录无适用AGENTS或docs/agent-project-notes；git status仍返回非有效Git仓库，虽然root存在.git路径，未进行暂存、提交或改动Git状态。

## 2026-11-16：MSAA 采样前提与插值路径核对

Astra 与主代理读取 pinned引擎：scene_forward_clustered.glsl 的 vertex_interp/normal_interp 为普通in/out，无centroid/sample；RenderingDevice multisample默认enable_sample_shading=false/min0，Vulkan driver直接写入VkPipelineMultisampleStateCreateInfo；原Three自定义vObjP亦plain varying。不能据此宣称硬件采样位置完全一致，但目前没有证据要求新增centroid生产API。

原抓取初版在resolve后FBO查询得到samples0，是查询对象错误；改绑定renderer.properties.get(target).__webglMultisampledFramebuffer后，首次又因WebGL没有getMultisampleParameter方法抛错（__studioHdr未产生），该次失败未写成功报告。现仅使用可用接口：保存/恢复READ和DRAW framebuffer绑定，实际draw FBO samples=4；sample_positions_available=false、positions=[]，明确不可查询。最后重抓退出0、页面errors0。原始HDR仍由Three readRenderTargetPixels读取resolve目标，查询后恢复绑定，不改变render数据。

`weapon-studio-msaa-path-audit.json`记录前提。当前domain为MSAA resolve加权输出，不能反解成某一次fragment真实坐标；其差异远大于普通相邻梯度，优先检查目标像素贡献的是哪一片几何/三角形。下一实验应为恒定coverage mask，保持depth/cull/MSAA，必要时区分同一merged mesh的前后面；不是先改哈希、关生产MSAA或加centroid。现有高光偏差仍未修复，r6未更新。

## 2026-11-16：覆盖掩码、实际样本布局与一次解释纠正

新增coverage诊断把pac9_anodised按smooth dP.x>=-.03输出R、否则G，其他可patch表面B；目标source(.75,.25,0)，native(1,0,0)，前两ray命中同object/geometry UUID。最初称为“前后表面3:1贡献”过强：原射线追加两套P/Py共8个pixel内位置，全部最近命中R侧，face607/171/339/612/613候选顶点x均为-.0176..-.0165，没有跨-.03。

进一步使用顶点分类的flat varying标签，两端目标均(1,0,0)，4×4差0。因此smooth阈值结果不能当实际面覆盖比例，可能是细小/掠射三角形在MSAA下pixel中心外插改变了dP；仍需flat逐三角形ID，不能仅据现结果最终认定同一primitive。明确撤回早期“25%后表面覆盖”的解释，保留原数据作诊断过程。

另在原同WebGL renderer/context创建独立HalfFloat4sample1×1 target做9×9 quadrant几何边界扫描；Godot独立Forward+16×16 target的pixel(8,8)做同扫描，均保存线性RGBH/HalfFloat。source占用1/8网格yx bins为[[1,3],[3,7],[5,1],[7,5]]；native为[[0,5],[2,1],[4,7],[6,3]]，归一到像素左下后与垂直镜像关系一致（阈值边界填充规则导致bin左右端差异，不宣称精确浮点sample坐标）。两端覆盖总和1，网格最大差.25。此为实际布局差异证据，不能独自证明目标primitive贡献。

临时 --studio-mirror-y（camera basis Y反射、读回flipY）coverage试验未恢复source结果：native仍(1,0,0)，quad差.25，未采用到生产。证据coverage-mirror-comparison.json保留失败结果，不能推断该camera变换一定改变了实际采样相位。所有进程退出0、原页面无错误、native无运行错误。源码diagnostic helper对fragment结束位置改为brace配对，避免对有light函数shader插错输出。生产MSAA/hash/默认camera不变。

新证据位于weapon-studio-{coverage,flat-coverage,coverage-mirror,msaa-layout}-comparison.json及source/native-sample-layout.json。下一步请Astra核对flat逐三角形标识方案，整体高光误差仍未修复；r6尚未包含近期修复。

## 2026-11-16：flat逐三角形真实贡献对照

顾问确认原pac9_anodised目标50550顶点/16850三角形、原index=null，Godot仅逐tri反转winding不改face序号。诊断在原geometry clone加aProbeID=floor(vertexIndex/3)，native仅mesh副本空闲CUSTOM1写同ID，保留CUSTOM0/aSurf、CUSTOM2原FP32normal、CUSTOM3HDRcolor与原position/index。无需toNonIndexed重排。source/native其他表面输出0，三个候选face607/339/171分别输出one-hot R/G/B，全部flat。

同一原frame/camera/MSAA4下，目标(660,359)source[.25,.5,0]、native[.25,.25,.25]，剩余贡献均.25来自未在前三通道标记的face。真实face覆盖比例不同，虽然所有candidate均属于先前flat“前表面”类。该结果支持真实MSAA/光栅覆盖差异，不应把先前前后smooth分类结果当依据；此处仍未定位sample位置差异与三角形亚像素光栅误差的具体占比。源无pageerrors，native报告failures空。

证据 `weapon-studio-triangle-mask-comparison.json` 与原始双方HDR/PNG，诊断geometry仅运行时副本，不改持久资产或默认shader路径。生产高光偏差仍未修复、MSAA保留。

## 2026-11-16：极细面614的覆盖与像素中心外插

补B组flat masks(face612/613/其余未标记面)：source[0,0,.25]、native[.25,0,0]。结合A组，source目标来自607(.25)、339(.5)、未标记(.25)；native来自607/339/171/612各.25。所有其他面仍正常depth/cull，不隐藏/discard。

未标记权重恰为1/4，追加flat加权faceID得到153.5，除.25候选614；又用独立face614 one-hot明确确认source权重.25，原pageerrors0。不是直接把resolve整数均值当唯一ID。

C组仅输出face339的dQ*34、其他面输出0（保留depth）：source resolved[-.68310547,-1.29492188,-.71044922]除weight.5，native[-.34155273,-.64746094,-.35522461]除weight.25，均得[-1.36621094,-2.58984375,-1.42089844]逐half一致。该面的坐标没有显示额外差异，不能据此推广到所有面。

CPU使用实际source相机和原FP32顶点、root y1.25/绕Y PI，投影面614面积仅.00287993 pixel²；目标pixel center(660.5,359.5)的2D重心[108.00775,-.985033,-106.02272]，透视外插localX约-.04805747，而顶点X均在前表面阈值侧。这解释smooth dP阈值为何会被误判成后表面；极细三角形在MSAA样本被光栅化但pixel中心远离三角形，材质噪声被外插坐标显著改变。尚需核对GL/Vulkan实际clip坐标/亚像素规则，不能把CPU投影当硬件覆盖证明。

证据triangle-domain-comparison、other-face-candidate、face614-confirmation、triangle-screen-audit JSON与原始HDR；全部运行退出0，无错误，生产资产/材质/MSAA均未改。已把精确结果交Astra顾问建议最小光栅复现。整体高光偏差仍未修复，r6未更新。

## 2026-11-16：面614公共投影输入最小重放

两端顶点投影源码均先modelview再projection，没有从源码直接发现MVP顺序遗漏。为先隔离覆盖，新增 face614-replay-input.json，以CPU原投影screen数据转换同一份FP32 NDC（三顶点w统一1），明确不是原GPU post-VS clip捕获。原同WebGL renderer/context单tri1280×720 HalfFloat、4samples，passthroughvertex、常量1、无depth/cull/blend，目标weight=.25，已复现原GL单面贡献。

`tools/replay_face614.gd` 在Forward+同分辨率/4sample/常量输出，直接POSITION绕开原camera/材质变换：clipY按默认方向取负时weight0；clipY反向后读镜像行360（即flipY回原359）得到weight.25，formatRGBH14。无运行错误，退出0。此实验支持在相同输入下采样方向/布局足以造成614进入或丢失，不等同已证明原source真实GPUclip逐位一致。

证据face614-source-replay.json、face614-native-replay.json，原扫描与CPU quantization-hypothesis同时保留。此前camera.basisY镜像失败不能反驳真正clip方向实验。尚未把镜像或关闭MSAA接入生产；完整world/weapon/post/depth/planar映射仍需顾问检查最窄方案。已请Astra审查existing flip_y路径，避免直接新增广泛引擎API。整体视觉偏差仍未修复，r6未更新。

## 2026-11-16：实际工作台投影Y诊断恢复目标MSAA与噪声

按ponytail最小改动复用现有studio_material_diagnostic和runner，新增仅显式 `*-projection` 诊断变体：shader中PROJECTION_MATRIX[1][1]取反、FRONT_FACING逻辑反转、显式cull_front/back交换，并对readback flipY；不再用会被camera变换处理的basis缩放。默认材质、相机、引擎与MSAA不变。该诊断覆盖颜色管线之前的HDR，不声称post/depth重建已正确。

实际workbench完整几何下，triangle-confirm-projection的face614权重=.25，与source完全一致。noise-projection目标与source逐half一致[.5732421875,.324951171875,0]；4×4低中频差0，dRun最大7.15e-7。两次实机均退出0，failures空、无运行错误。对比报告face614-projection-comparison、noise-projection-comparison以及现有比较器 --projection重放结果。

该证据证明保留原几何与4×MSAA，调整实际光栅方向可恢复本处覆盖和shader输入；不是通过变色、删微面、改hash或关闭AA来掩盖问题。下一步须统一world/weapon颜色与深度、multisample bridges、太阳/planar、后处理UV/投影坐标，不能把逐shader诊断hack直接作为完整生产修复。已请Astra收敛最窄完整方案。r6仍未包含近期工作台环境与自动设备档位等修复。

## 2026-11-16：复用既有组合深度flip边界验证

继续接线检查发现 CombinedDepthBridge 已有 flip_y push constant；不新增重复的DepthSamples翻行开关。新增仅现有 verify_depth_samples 的 --projection 分支，用实际shader PROJECTION_MATRIX Y翻转代替camera反射，组合桥flip_y=true，原始样本读取对应镜像行。默认分支保持不变，无新依赖或生产shader变更。

NVIDIA Forward+ 实际165cases全部完成，4samples、96个部分覆盖像素；捕获深度值与GPU组合预测的内部failures空、退出0、无错误。与旧source fixture逐case比较仍有13/76两处差异。已核对fixture renderer为ANGLE SwiftShader、subpixelBits4、D24、无RTT扩展；不能把内部failures空当当前NVIDIA原作全部一致。此限制与昨日mirror probe记录一致，未放宽2e-6比较门槛。

当前代码支持的最窄边界：3D raw颜色/样本深度统一新朝向，颜色在scene合成入口flip_v、深度仅在既有CombinedDepthBridge一次flip_y，再交既有half-depth/AO/post。不能提前翻soft particles内部SCREEN_UV depth；sun shadow独立视图不随主视图无条件翻。已核对RenderSceneDataRD的flip_y同时驱动投影/逆投影；cluster_builder begin和prev correction另有硬编码，需要同一状态，不可只改单行scene_data.flip_y。引擎尚未修改、构建或部署，r6仍为旧版。

## 2026-11-16：每视口光栅方向引擎接口与首轮GPU验证

新增私有RenderingServer.viewport_set_source_raster_y_up(viewport, enable)，只允许在render buffers首次建立前设置，默认false；resize沿RenderSceneBuffersConfiguration保留。状态同时驱动actual/reference/inverse投影、cluster方向与previous correction。Forward+四条camera render lists（depth/opaque/motion/alpha）传递独立pipeline key，翻转raster front_face；不额外XOR实例cull，shadow/material内部列表默认保持false。scene UBO bit8也记录该状态，项目shader尚未消费。

组合补丁0003从固定原archive逐文件重新应用，26文件SHA全部一致，见engine/raster-origin-patch-verification.json。新binary SHA256 fc54e30a76f0598f45d55d5f215156a97cdbb8afe9c9b8506e2fbe60ee143ade，80338024bytes，构建实际退出0。旧fixed4 binary保留于engine/.build/godot-fixed4-before-raster-origin.x86_64，r6未改。第一次构建因SCons没有导入CCACHE_DIR而访问只读home缓存失败；build_engine.py显式传import_env_vars=CCACHE_DIR后隔离缓存生效，无需系统目录权限。

实际NVIDIA Forward+ MSAA4探针：两个同时渲染、共享材质但相反origin的viewport，三种cull各在65x37及67x39尺寸验证，共6项，规范化颜色逐byte一致，前面绿/剔除黑符合预期，failures空，退出0。首次探针遗漏UPDATE_ALWAYS、离屏视口未绘制而读黑，已修正；没有降低比较标准。报告evidence/raster-origin-verification.json。

复用replay_face614.gd新增--engine-origin，y符号实际来自PROJECTION_MATRIX，而非显式shader常量翻转；引擎新flag启用后目标coverage=.25，与原source微面贡献一致，退出0。报告face614-native-engine-replay.json。这仍是CPU-NDC输入单tri重放，不是原场景GPU post-VS逐位证明。

尚未启用游戏world/weapon/planar flag，也未接入scene颜色、组合深度及reflection mip规范化；当前默认游戏方向仍旧。实际production材质噪声及完整后处理/软粒子/太阳/反射回归仍待完成，不能以本轮局部探针宣布全项目复刻完成。

## 2026-11-16：光栅方向接入实际世界、武器及反射链

在前述引擎接口上补齐SOURCE_RASTER_Y_UP私有spatial builtin，由每scene UBO bit8读取，不使用共享材质uniform。仅Forward+允许开启；Mobile/GLES builtin固定false且setter拒绝true。当前组合补丁仍0003、28文件，固定archive逐文件重放SHA全部一致；patch SHA819fa712cdd09f78b4fad085864a64d5aef7ef0b7e30e76dc24cdbca57b7ae5c，binary SHA bb476c9fd4cbf588904f38de2633b58cf962c3e30225dca8f009bf414bf1e70e，80338024bytes。当前build-result与raster-origin-patch-verification已更新，旧核心探针构建独立保留。

world/weapon启用源方向，各颜色只在scene_port入口TextureRect.flip_v一次；原始MSAA样本不翻，既有CombinedDepthBridge.flip_y=true翻一次后供half-depth/AO/volume/motion/adapt。planar独立启用，ReflectionHdrBridge只在level0 copy翻行，再生成mips。sun viewport默认false，2D后处理不改。七个spatial入口的PCSS/alpha像素坐标共用sourceRasterPixel，切线法线dFdy补偿读取同一scene flag。FX与配对工具的原始world HDR读回也补了flip，保持已有top-left元数据。

新引擎实际GPU共享材质探针扩大至12项：opaque/alpha.55×三cull×两奇数尺寸，包含scene flag与实际投影符号一致性，翻回后字节一致、failures空、退出0。engine-origin实际深度165cases、96部分覆盖、4samples，组合GPU值与原始样本预测全部一致，退出0；旧SwiftShader fixture的跨backend比较仍需保留既有边界，内部通过不等于所有原作像素一致。

水平oblique反射engine-origin探针：red111→0→111，green137/blue96保持，非XR主图不变，HDR green4、8mips、末级非零，normalized viewport与HDR level0全像素色彩分类方向差0，failures空、退出0。实际Main8项生命周期+dispose/reentry也通过，原有尺寸、XR与layer恢复成立；reentry事件reflection→sun→world→weapon。此证据不覆盖完整PBR/太阳shadow-age或性能。

实际rifle-side完整几何，普通noise诊断（没有逐shader投影/FRONT_FACING替换）目标source/native均[.5732421875,.324951171875,0]，4x4低中频差0、dRun最大7.15e-7。原作与Godot匹配相机、3steps、12次zero-dt、manual exposure1的beauty RGB8 MAE由.5629474103降至.2321158854，p95由2降1、p99由8降4。目标亮点从[92,85,73]恢复[243,236,223]，source[252,249,215]，仍有残差；整图max107，不宣布全帧完成。新图weapon-studio-rifle-side-origin.png及两份origin comparison JSON保存，均实际GPU退出0、无shader错误。

本轮runner固定命名的weapon-studio-rifle-side-noise.json/weapon-studio-rifle-side.json已更新为新采集状态；旧PNG/HDR和projection诊断保留，比较新beauty使用独立paired-native历史PNG，不能将更新后的报告当旧构建快照。新r7尚未打包；r6未改。

## 2026-11-16：新方向下完整Main射击/粒子链与实机视频

复用verify_tracer_chain_runtime实际GPU+MovieMaker录制。首次480逻辑帧无射击，failures为long-tracer/heated smoke未到达；抽帧明确为桌面失焦导致正常PAUSED菜单，不是渲染失败或空枪管线。首次失败报告保留raster-origin-tracer-initial-failure.json。仅测试脚本在每次输入前调用现有resume恢复paused并计数，不改生产Main失焦暂停；重录记录controlled_focus_resumes=1。

重录实际480逻辑帧、13shots、87checks，impact→tracer/shell同步顺序、long tracer trail、6次heated smoke在root更新和heat衰减前发出、末尾add/lit/tracer清理全部通过，failures空、退出0、日志无ERROR/WARNING。已查看raster-origin-shooting-frame.png：实际闪光、火花、武器、HUD及雨的方向正常；这不构成soft-particle原作逐像素一致或全面视觉验收。FX/paired HDR采集现均翻原始world读回，保留原top-left元数据；未更改2D后处理算法。

新视频evidence/native-raster-origin-shooting.mp4，1280x720、60fps、481编码帧、8.016667秒、无音轨；H264 MP4全片解码退出0。SHA badcea1d0f65fc3d1187dab0cf0f6e2a05a09b2ccebd3e58566f0084743b5f38，当前engine/脚本hash及媒体信息见raster-origin-shooting-video.json。离线固定帧率录制不证明实时60fps。旧视频和r6包未覆盖。

当前engine-origin深度与旧SwiftShader fixture按未改变2e-6门槛仍仅13/76两处不同；不是原作对照165项全通过。当前局部素材及射击图像误差、完整其他场景/渲染效果审计与新运行包仍未完成。

## 2026-11-16：r7独立运行包

通过既有package_runtime.py生成output/linux-runtime-20261116-r7，不覆盖r6。4,398manifest文件、2,609,430,622bytes，固定engine SHA bb476c9fd4cbf588904f38de2633b58cf962c3e30225dca8f009bf414bf1e70e，包含近期工作台环境/初始化/设备分类和光栅方向全部接线。包说明修正默认cold assets取设备分类的事实，不再误写始终High。

实际cwd=/tmp三次包内GPU启动均退出0且日志无ERROR/WARNING：rifle-side普通noise诊断3steps+12warmup，读取包内真实RGBH目标[.5732421875,.324951171875,0]与source逐half一致；hands fp pistol/open12frames；external脚本从包内res加载真实Main，High/Ultra/High shadow cadence1010/1111/1010和Start暂停panel共10checks通过。验证后逐文件重算全部4,398项size/SHA，failures空，报告evidence/runtime-bundle-r7-verification.json。研究工具及旧研究视频未打入运行包，新截图/报告属于运行时生成内容。

这是可独立启动的未裁剪Linux开发包，不是完成版或跨GPU验收；原作全场景材质/后处理细节对齐仍待继续。README最新启动入口和视频已更新，系统Godot、旧运行包和音频配置均未改。

## 2026-11-16：新方向下完整场景原作对照

复用既有capture_main_paired与compare_main_paired，保留原source快照，旧native PNG/JSON/HDR先归档evidence/main-paired-before-origin。重新采集完整户外、港口、室内：source固定相机、t=.05、manual exposure1、12次zero-dt渲染、隐藏HUD/weapon，GPU均退出0且4份日志无ERROR/WARNING。新采集原始world HDR已翻回canonical，metadata保持top-to-bottom。

完整RGB8 MAE（字节单位，描述性统计）户外.8610948351→.62828125，港口1.1796976273→.7815006510，室内1.3583391204→.7807921007。P99分别11→7、11→8、14→10。尚有局部max108/115/220，不能以低整图平均宣布全部视觉通过。evidence/main-paired-origin-comparison.json保存before/after、engine与16份图片/报告SHA；已查看新港口实机图，天空、海面、吊机、湿地、反射方向正常。

室内最差像素仍861,300，与此前已解释的源transient pooled point历史不同一致：旧普通快照未保存light state。没有修改生产BRDF、roughness或灯光强度；复用既有interior-spec-matched source与--match-source-pool诊断，六个临时pool按source记录输入，保留四盏仓库灯。目标860,300 HDR source[4.62109375,4.5390625,4.10546875]，native[4.6015625,4.51953125,4.09375]，与旧matched结果相同；835,282–878,318 ROI HDR MAE.02735965→.02241550，display MAE3.32903→2.70026。匹配控制说明普通室内快照的大亮点差异不能单独归为shader错误；仍未证明正常游戏FX时间/RNG历史同步。报告interior-highlight-origin-matched-pool.json，原作source文件未覆盖，匹配控制的旧native也已归档。

本轮仅更新对照证据和文档，未改变r7运行包或生产渲染。其他视角/动态光照/后处理/资产细节的完整审计仍待继续；本报告没有新增或放宽通过门槛。

## 2026-11-16：补齐原公开show=render展示场景

直接核对bundle-1.js:85749–85760注册表及ik():37304–37390，发现普通游戏已有材质/效果但缺少此公开观察入口。复用export_material_catalog.cjs新增--render，从真实原HTML在Chrome ANGLE/GL运行结果导出，不手造替代几何；原8字体本地路由继续使用。捕获37网格、24几何、23材质、12texture完整原GPU mip链，约84.51MB，原page errors空，source SHA/font SHA/camera记录于assets/catalog/render/catalog.json，原作截图render-catalog-source.png。exporter断言37节点与14球阵。

复用material_catalog_runner新增--catalog=render和既有studio_render_options，不另建渲染器。原stub环境清interior/physics、禁rain/planar、释放6临时灯；沿用公共地面、解析天空、source太阳与IBL、完整HDR后处理。保留原camera.y毫米末位Math.round语义，用floor(x+.5)且从原double输入求值，映射damage.8/lowHealth.85/ads1/flash.35/fade.5。新增入口默认相机(-8.5,1.7,4.2)和目标(3,1.5,.4)，与source记录相符。

第一次运行虽然计数/贴图checks为空failures，但14匿名球材质导致Godot节点空名ERROR，不能算清洁通过。保留render-catalog-initial-runtime.json和initial.log；共用material_catalog.attach仅对空节点名给CatalogMesh后备名，catalog_material仍保留原空材质名。该加载器只有现有runner调用，普通已命名资产不变。

修正后实际GPU六种模式baseline/damage/low-health/ads/flash/fade全部退出0，日志无ERROR/WARNING，各37节点/35light-ready/34shadowcasters/12GPU原mip hashes通过；实际输出postuniform互斥与源值一致。旧--only=concrete选择回归4节点/3GPUtexturehash通过。已查看原作与native基线截图，球阵/测试墙/发光物体/公共地面可见；没有把截图相似当完整像素验收。数据与脚本SHA汇总evidence/render-showcase-verification.json。README补入口/参数；package_runtime说明补未来打包入口，但r7保持不变且不含本次资产/runner变化。

旧current-completion-audit前三项缺口均已落地，现明确标为历史审计。还需继续核对原10项公开展示中level/backdrop/ground/enemies的独立场景语义及整体视觉/动态状态，不以主游戏已有相关资产推断这些入口已完成。

## 2026-11-16：修复Main仓库风扇停在导出姿态

本轮按用户授权请Astra Ultra只读核对原show=level/backdrop/ground/enemies，优先找到Main真实动画遗漏，而非继续扩展展示框架。原dw()在bundle:50712构造le于(11.95,8.02,-19.5)，noMerge=true；50936每次update执行le.rotation.x+=dt*1.7。prepared对应f91a4d97-05f6-4f6b-9eab-d156700b99ee，父level-dynamic(65192656-a536-4133-a40e-6a94a5f7ae35)，5steel_worn叶片+1steel_dark轴。顾问用实际原THREE与ot/vt构造字面量核对6网格position/normal/uv/index，共24buffer/6920bytes一致；快照角.0850000017恰为源t.050000001×1.7。此前原生仅保留导出变换，没有持续旋转。

source_scene现有运动绑定加入shed_fan，绑定断言位置和六子节点；同一update_backdrop_time绝对非暂停clock调用现有精确Euler basis函数，只旋转叶片+轴Group，护圈/支架不动。沿用Main171初始化与399非paused门控，不增第二时钟或动画模块。暂停冻结、title/dead推进、dt上限及start/retry保持时间语义复用已有路径。

扩展既有backdrop_motion_reference.cjs：定位唯一fan结构，从原dw源码实际提取update函数并在原Three Group执行，sha单列；旧reference/report保存为evidence/*before-fan*。原有verify_backdrop_motion无需改断言/门槛即覆盖新增ids。实际Main GPU720逻辑步、51采样、4080matrix分量，max7.62939454e-7<原1e-5门槛，failures空、退出0、无ERROR。报告shed-fan-motion-verification.json与backdrop-motion-verification.json。

另原作Chrome/GL与Godot固定相机(8,8.02,-19.5)朝(12,8.02,-19.5)，t=.05、manual1、隐藏HUD/weapon、匹配6临时灯输入，捕获PNG与HDR。均退出0，原page errors空、native无ERROR；已查看原生风扇/护圈近景。RGB8 fullMAE.4479441551、P95=2/P99=5/max152，描述性统计不作为新通过门槛，见main-paired-high-shed-fan-*。静态截图证明呈现与几何，持续动画由上述原函数矩阵对照覆盖。

顾问同时核清：Pg的t.updaters来源区只有relay_node定义userData.update，关卡3relay已有现有Relays接线；fw atlas.update仅前8秒检测异步字体贴图version，最终固定字体导出不需要模拟浏览器回调。后续level展示仍须处理公共80m地板、stub level和室内envMap绑定差异；ground的Dw/Lw/Fw纹理仅依赖算法/quality，不能误称因stub改变，真正差异还包括rain第1次fork（Main第2次fork）及遮挡/查询；boat展示须改base、禁root bob、去独立系泊绳组并保留hull摆动。以上尚未据此宣称这些独立入口已完成。r7仍为历史包，不含render入口及本风扇修复。

## 2026-11-16：接入原show=ground与独立雨水流

复用catalog exporter的--ground：在实际原HTML/Chrome GL选择BP的15子mesh测试Group，明确断言原80m公共展示floor已被BP删除（不是遗漏）；导出15几何/15材质/15GPU mipchains、原默认camera(-9,1.65,5.6)，原page errors空。另导出原Gw实际aSeed Float32数组的SHA/count/byte metadata及apron_wet/sea非纹理uniform参考。配置assets/catalog/ground/catalog.json记录source SHA/fonts/source backend；不另建地面shader或替代平面。

原native Main的ground Group五mesh（apron/sea/quaySkirt/rain/rainSplash）保留，其余Geometry与旧仓库点光隐藏。与已有Vg相同的标量/向量uniform逐字段核对，除导出t=.050000001和source=.05的时间记录外一致（live反射参数单独由生产pass更新）。清stub interiorBoxes/skylights、GroundQueries捕获的旧interiors/metalRects及player physics；保留实时planar。source viewFill固定1.1。重新用root第一次fork seed589939774构造已有SaltlineRain，并复接thunder→sky；普通Main第二fork及其他入口不改。

实际MultiMesh中9260rain/eave与900splash实例customdata重组Float32字节，SHA分别c13a22be3fa5b5b27b04d4b322024fe09e587edf7d6a6e4c9d4f1b6cfc628651、383d3e3a9ede3289aeead158ad05954158974e8b12795fae88e3130c50b97af1，与原独立Gw数组一致。此为实际上传数据/API读取，不冒充新的raw GPU seed读回。原15材质纹理均另有GPU mip bytes hash检查。

三次真实GPU启动均退出0、无ERROR/WARNING，15节点/15材料/15miphash/15caster/10lit绑定通过，planar ready；stub interior0、skylight openings0、8禁用槽、drip0。默认auto三帧rain.time=.05；原render入口回归37节点/12miphash也通过。报告ground-showcase-verification.json保存源码/资产SHA和原种子参考。

首次12帧manual1、随后3帧manual1均保留；原renderer默认autoExposure=true，不能据固定曝光图的亮度差去改材质。3帧defaultauto对照整图RGB8 MAE1.4715719、P95=7/P99=18/max95；manual1约23.62。不同时间/曝光历史的三图只是描述性实验，未称单变量修复或完整像素通过。已查看两端地面/测试物/海面/反射截图，原source及native分别保留，见ground-showcase-image-comparison.json。原12帧报告stub_skylights=8表示内部禁用槽数，新报告已改分列openings0/slots8，避免误读为8个实际天窗。

README与未来包说明补--catalog=ground，当前r7保持不变，不含render/ground及风扇后续修复。High为本次实际采集/运行范围；其他cold质量、长时间雷暴与剩余level/backdrop/enemies独立入口仍待继续。

## 2026-11-16：原show=level入口与既有关卡资产精确复用

复用capture_main_paired.cjs新增仅允许level的--show选择，真实原HTML show=level运行时逐原geometry属性/index向Node SHA回调传字节，不导出第二套巨型资产。level root实际133mesh；与prepared Main level子树逐完整attribute descriptor/hash、index/hash、groups、材质名、instanceMatrix/instanceColor及cast/receive flags匹配，133/133一致，最大原world matrix差1.69386245e-9（源snapshot时间记录差）。原材质槽全部envMap=null；环境强度属性集合为[1,1.4]，其中glass/glass_dirty的1.4不应误断言为1。源inventory与reuse audit保存；运行绑定资产level-showcase-bindings.json记录source SHA、snapshot .05、相机、133目标id和78caster。

新level_showcase_runner复用Main、weapon_studio_environment公共80m concrete plane/无rain/无planar/stub环境，恢复原level子树和4仓库灯，清Main indoor环境显式绑定（只设explicit_room=false，不强制修改无参与隐式分支的intensity）。只保留已证明完全一致的现有几何；无原生生成替代。原显示入口不含主游戏真实ground/backdrop/explosives。初始采用源ready snapshot .05，保留该时刻fan/relay pose；默认继续原动画，--level-freeze用于固定snapshot。standalone flow.state=showcase，避免引入Main gameplay/失焦暂停语义；不改普通Main行为。

实际原作固定相机(-32,1.7,6)目标(0,2.4,6.4)、t=.05、manual1和12zero-dt预热采集PNG/HDR，page errors空。原生冻结12帧验证133mesh可见、78shadowcaster、4仓库灯、explicit_room材料0/view_room=false及无rain/planar，退出0、无ERROR/WARNING。普通非冻结12帧时钟从.05推进至.3473526667，checks同样通过，保留自动曝光；不是与冻结图单变量对比。

新配对图main-paired-high-level-native.png已查看，RGB8 MAE.2687123843、P95=1/P99=4/max84。它是描述性图像残差，不是全像素一致/新通过门槛。最终删去冗余explicit_intensity赋值后又GPU重跑冻结路径，level-showcase-final.png与前配对PNG逐byte相同，checks仍空failures。全部来源、文件SHA、live/frozen/final报告见evidence/level-showcase-verification.json。

验证汇总脚本曾错误假设原所有envMapIntensity=1而失败；检查发现3个glass槽为1.4，未改原材质去迎合假设，改验证只要求原无explicit envMap。现生产只清explicit_room，shader隐式分支不读explicit_intensity；上述最终字节重放验证该删行不改变呈现。

README与未来包说明补level入口，r7保持历史版、不包含后续风扇/render/ground/level。还有backdrop/enemies独立展示入口、其他cold quality、材质纹理完整逐byte与全局动态历史等未完成项；本轮没有把133几何一致扩大为纹理/全部资产或完整游戏完成。

## 2026-11-16：背景独立展示与原始分项网格

复用level_showcase_runner接入--showcase=backdrop、--bshow=all/crane/ship/boat/sky，采用原_P相机、公共80m地板、stub环境及现有天空/灯/海鸥shader。Main背景默认行为保留；source_scene增加默认false的backdrop_showcase，仅在展示中禁艇根bob，base改(24,.34,15)，保留hull/radar/spreader/海鸥/闪灯时钟。展示移除Main额外系泊绳和不选中的组件。

原Chrome五项实际采集无page errors。完整attr/index/groups指纹、材质名、worldmatrix、cast/receive对照匹配Main：all32、crane14、ship10、boat6、sky2；不匹配的展示标牌及分项blink保留原始二进制流（分别额外2/2/2/0/1网格），没有放宽几何匹配门槛。collector新增Uint16/Uint32索引转换及原绕序翻转；原始hash仍保存在inventory。标牌材质按唯一同名/同UV/同顶点数原材质引用，贴图逐byte身份仍待另证，不作已验证声明。

实际GPU五项12帧均退出0且无ERROR/WARNING，网格34/16/12/6/3、casters20/9/7/4/0、仓库灯0、explicit_room0、无雨/planar。boat非冻结12帧clock从.05推进到.2826293333且base保持固定；其余冻结原t=.05/manual曝光1。level回归133网格/78casters/4lights通过。全景RGB8 MAE .4345413773、P95=2、P99=7、max76，仅描述性统计。见backdrop-showcase-verification.json和backdrop-showcase-reuse-audit.json。已查看全景native实际截图。

README及未来打包入口说明同步，历史r7不改。仍待enemies独立展示、标牌贴图身份、全动态矩阵及其他quality和整体游戏一致性验收；本轮不宣称完整复刻完成。

## 2026-11-16：敌人五模式展示与受控骨骼对照

新增enemies_showcase_runner继承已有场景runner的view配置，复用现有actor、skin、行为、死亡、effects与公共展示环境，不重写敌人。源KD:83401五模式both/gull/hound/fight/dead的spawn/选项、预热2.6/1.2/1.25/7/.42秒及dead额外30+110步与伤害顺序逐项实现；--epre/--efreeze可调。先从Main导出中未激活pool恢复原构造状态/骨骼，再保持当前rig/lens绑定。

初次setup字段covers错误已保留/tmp/saltline-enemies-both.log并退出130，改为实际cover_points。初次fight最大位置差10.0189m不算通过（enemies-fight-native.json保留）。Astra Ultra确认Main默认Hard污染独立展示，改用现有mission.set_difficulty(standard)原地恢复原Bi/Jy/tb参数；与game-rules.enemies逐字段一致。原hL.damage为空，native展示玩家设invulnerable，health100/alive保持。普通Main难度和伤害路径不改。

原nav.randomPoint使用独立Math.random，eseed9001不能固定fight导航。collector可在实际浏览器响应中仅包裹该函数记录from/radius/result，原HTML文件不改且保留原SHA、instrumented SHA。--source-nav-tape仅源码诊断用tools/enemy_showcase_nav_replay.gd重放35个实际选点，逐次核对入参与数量；日常fight保留正常随机导航。没有用随机快照差异认定生产算法错误或降低阈值。

实际NVIDIA GPU最终五冻结场景+live各12帧均退出0、无ERROR/WARNING、failures空。最大位置误差both1.192e-7/gull2.083e-9/hound0/fight1.980e-6/dead7.153e-7m；局部骨骼max分别9.660e-7/1.470e-6/1.242e-7/1.234e-5/2.358e-6，统一自检门槛1e-4。fight35次nav调用数量一致、float32入参origin差0；live时钟持续推进。已查看双角色native实际截图。见enemies-showcase-verification.json，图像统计仅描述性。

README与未来运行包说明同步。本轮不宣称全部游戏完成：任意eseed、长时间AI/FX历史、其他quality及完整材质/图像一致性尚待核对；诊断nav重放工具不随运行包提供。

## 2026-11-16：r8独立运行包

新建output/linux-runtime-20261116-r8，不覆盖历史r7。4503manifest文件、2762091177bytes，固定引擎bb476c9f…保持不变；纳入风扇/render/ground/level/backdrop/enemies后续源码和资产。原nav重放仅源码诊断helper，不随包扩tools。

从cwd=/tmp、隔离XDG实际GPU启动enemies双角色3帧、backdrop货船3帧、Main20帧，均终端退出0且无ERROR/WARNING；两个展示实际输出报告failures空。三次启动后重读完整manifest，4503文件大小与SHA全一致。见runtime-bundle-r8-verification.json。Main启动仅资源/初始化检查，不替代完整任务或视觉验收；live/defaultfight未比较姿态，报告controlled_pose=false时maximum误差0是占位值，不是零误差结论。

## 2026-11-16：敌人展示预热相机、全局效果与世界骨骼

按原ov:36700相机默认原点、KD:83401预热后返回cam及cL:85896/86001循环时序，修正enemy runner过早view()的行为：预热时camera.position=ZERO，之后切展示相机。原stepped boot在ready前推进3×1/60全局帧；以前只把animation_time设.05，未推进FX及light_pool decay。现复用既有_advance_effects/_process补3步，未冻结敌人在这3步也update，显式efreeze不更新敌人。Main行为不改。

修正前受控fight扫描选id4，灯位置(.83966,3.25051,13.26754)，原作灯为(-5.29496,4.27273,-5.24463)；其余5槽残留22/8.8/8.8/14.4/22强度。修正后选id5，scan位置回到原值浮点精度范围；5槽强度均与源相同降至1e-15量级。原图配对RGB8 MAE3.0572356→.8527434，P99 79→10，仅描述性统计。保留enemies-fight-light-before/after及源图。

加入既有原数据中的group与world bone矩阵检查（原门槛1e-4不变），以及6槽灯位置/强度/linear color/range检查（1e-4/1e-6/1e-5/1e-5）。五模式实际GPU均退出0且无ERROR/WARNING；最大全局骨骼矩阵差1.1449157e-5、灯位置差1.9101988e-6、强度差1.11e-16、颜色差8.34465e-8、range差1.90735e-7。最终受控fight再验并写入runner/reference SHA；实时bootstrap再验通过，未比较姿态/灯误差记null，stdout带controlled_pose，避免0占位值被误读。live/default场景不按原冻结端点强制active数量和顺序，允许自然退役。

见enemy-light-bootstrap-verification.json；已查看修正后实际GPU画面。此修正晚于r8，历史包不改。本轮证明冻结终点灯状态及局部/世界骨骼，不证明逐帧轨迹或全部FX像素。

Astra Ultra下一步只读范围复核确认navigation HUD仍缺原HTML84–86准星opacity .1s ease、gap .06s linear及153–160目标容器 .15s/单marker .25s过渡；当前navigation_hud每帧直接替换并立即隐藏，game_ui未传dt。应复用现有CSS计时类补局部状态，不改投影/尺寸/字体。此次FX与props接线复核未发现新的实质遗漏，不据此穷尽全部细节。

## 2026-11-16：准星与目标标记CSS过渡

navigation_hud复用既有css_opacity_transition及css_transition_timing，实现原HTML84–86准星opacity .1s ease、四臂gap .06s linear、153–160世界marker容器 .15s及自身 .25s ease；GameUI唯一调用传入dt。淡出时继续画当前gap与alpha，dot/四臂/阴影均乘准星alpha；世界标记alpha乘容器fade，罗盘标记不受该容器影响。Ge隐藏时不重新计算gap目标，已有gap过渡仍自然完成。投影、尺寸、字体不改。

marker状态按kind/short保留；列表改变按源setMarkers(83713)重建状态，mission.hud_reset清除旧过渡，首次插入从浏览器首次computed CSS值起步，不人为从.78淡入near/dim。原Chrome实际CSS补采normal/dim/offscreen/near四种新节点样本，均无初始动画；原文件不改。

navigation_transition_reference.cjs沿用项目现有Playwright/Chrome采样模式，实际原CSS的暂停动画精确seek，覆盖10阶段/30采样、120字段，含spread跳变与反向、ADS中途反转、sprint、死亡/隐藏换弹及dim/offscreen/near。实际NavigationHud更新120字段与原值对照：alpha最大4.622073e-7、gap最大3.333569e-5px（Chrome矩阵字符串量化），阈值分别1e-5/1e-4；另4首次样式、3列表/任务重置检查通过。第一次headless日志路径不可写虽数值通过但不算清洁检查；最终隔离XDG、显式/tmp日志退出0无ERROR/WARNING。

实际Main→GameUI→NavigationHud链路再验同120字段通过，4张实际GPU截图；已查看navigation-transition-runtime-03.png中淡出的准星及目标标记。最终runtime nav/GameUI SHA与当前文件一致，见navigation-transition-provenance.json，未以数值样本冒充整幅HUD像素或实体输入验收。历史r8不改。

## 2026-11-16：准星与目标标记的原作过渡

已实现上文识别的导航 HUD 过渡：准星透明度 .1s ease、散布间距 .06s linear、世界标记容器 .15s ease、单标记 .25s ease。`game_ui.gd` 将实际 dt 传给 navigation HUD；沿用原投影、字体和位置计算。独立标记状态在目标列表变化或任务 HUD 重置时重新建立，新标记采用首次计算得到的 CSS 透明度。保留原 ADS、near、dim、offscreen 的优先级，父子透明度相乘；准星隐藏期间保持最后间距目标。

从原 HTML CSS 在真实 Chrome 采集十段连续状态、30 时间点，包括变散布、ADS、冲刺、死亡、隐藏换弹以及多次中断/反转。Godot 实际 NavigationHud 进行120项数值对照，透明度最大误差4.6221e-7、间距最大误差3.3336e-5 px；额外验证4类新建标记首次透明度、列表重建及任务重置。随后实际 NVIDIA GPU运行 Main → GameUI → NavigationHud 同一120项对照，保存4张截图，退出0且日志无ERROR/WARNING。当前源码的SHA与GPU报告一致；详见 navigation-transition-verification.json / navigation-transition-runtime.json。第一次无隔离 XDG 运行的测试主体通过但 user:// 日志路径拒绝，正式复测使用 /tmp 隔离路径且无日志错误。

本次验证覆盖数值过渡与受控Main截图，不证明实体鼠标/手柄输入、整图像素或全部游戏完成；该源码更新晚于r8，包未重打。

## 2026-11-16：r9独立包验证

新建output/linux-runtime-20261116-r9，不覆盖r8。4504manifest文件、2762117526bytes，固定引擎SHA仍bb476c9f…；纳入敌人展示预热相机/全局bootstrap修正和navigation HUD过渡。

从cwd=/tmp与隔离XDG实际GPU启动原生Main20帧、Gull展示3帧，均退出0/日志清洁。另用源码树只读测试驱动加载包内Main/GameUI（所有生产模块与assets由bundle res路径解析），同120 CSS字段对照及4 GPU截图通过，nav与enemy runner当前SHA已核对。三次运行后完整4504manifest文件大小/SHA重新校验无差异；额外捕获文件不属于原manifest清单。见runtime-bundle-r9-verification.json。外部driver不是运行包的日常依赖，普通Main及展示直接由包内run.sh执行。

本轮不等同于全项目逐项完成验收、逐帧玩法/整图像素或实时性能证明；主目标保持进行中。

## 2026-11-16：启动/导入入口与资产清点

修正tools/run.py run/capture默认调用系统Godot的问题，改用现有run_native.sh固定引擎；run显式--game，capture保留--capture，import仍用系统编辑器；保留显式GODOT覆盖与错误门控。更正初诊：Main当前已以args.is_empty()进入完整游戏，旧入口并非因缺--game进入预览，真正缺陷是选用不支持补丁的系统引擎。README验证命令统一固定引擎。

新verify_run_launcher.py在/tmp独立副本执行实际入口，mock子进程边界，8项默认/显式run、capture/import、GODOT覆盖与错误传播通过。实际desktop命令观察到固定二进制和--game，场景加载无错误，随后主动中断130且已确认进程74001消失；不称该次启动为完整退出验证。

系统编辑器实际import曾因3处静态viewport_set_source_raster_y_up调用解析失败；改RenderingServer.call动态解析同一方法/参数，使官方编辑器能导入而实际运行仍用补丁引擎。evidence/output加入.gdignore，避免证据图片及历史包扫描。最终官方4.7.2 --headless --editor --import退出0无ERROR/WARNING，editor-import-clean.log。固定引擎原Main/反射8生命周期及reentry报告通过、日志清洁；该任务后遭turn中断，原终端handle已丢失，未重新启动冒充已观察退出码。

verify_asset_inventory.py核对当前原HTML身份、captured/prepared节点/材质元数据、全部954属性buffer长度/引用及3237042索引绕序（1079014三角形）、132PNG与capturedRGBA8行序、两套mip哈希。729节点/276几何/195材质、112488744属性bytes、159864320 baseRGBAbytes、每套211748784 mipbytes全部通过；该清点不重采原浏览器，也不能把早期RGBA8记录称为HDR证明。隔离/tmp重跑composite generator，所有生成shader与当前文件一致且生产文件未改。

## 2026-11-16：导航并入原Math.random共享域

审计发现navigation._init原来固定PCG seed4207，而源physics.nav.randomPoint40199每次读Math.random，与FX的Et别名58747及天空方向36830共享。导航现在按现有构造注入模式接受random_stream，Main传同一个fx_random；独立AI su9001与rain/explosives/weapon的SourceRng不改，retry也不重建/重播Math.random对象。Astra Ultra只读核清构造/rebuild/path无draw、每次尝试2draw、24次耗尽fallback无额外draw。

原浏览器bundle前安装永久wrapper（避免Et提前捕获旧函数），构造/ready后才启用tape。真实原nav与fx.smoke交错9步136draw，含2/4/8draw成功/重试及两次48draw耗尽；实际Native Navigation/ImpactEffects/Particles共用同tape，calls逐项一致、落点误差0，两个烟粒子，见navigation-random-verification.json。原网格17608格/24路径零差和Hound locomotion回归通过。

当前Main标准难度正常血量/弹药/敌人从原出生点自动行走并射击，1457ticks/146.935m、三目标切断与撤离/结算完成、60shots/31hits/13kills、protected_live_frames0，shared_navigation_fx_random=true。测试单独seed(4207)控制熵，不改生产；源系统focusout正常暂停导致初次受控运行停paused，失败JSON另存。复用tracer测试已采用的计数式resume，仅测试恢复1次，生产暂停逻辑不改。最终退出0/无ERROR/WARNING，health100并非启用无敌。

汇总completion-audit-progress.json；这批源码修正晚于r9。仍需按原需求汇总剩余全项目验收范围，不以资产清点或单次通关代替全效果一致性。

## 2026-11-16：r10运行包及当前审计边界

新建output/linux-runtime-20261116-r10，5556manifest文件、3073741094bytes，固定引擎bb476c9f…不变，包含导航/FX/天空共享随机域及编辑器静态解析兼容修正。源编辑器导入遗留研究图片缓存仍随unpruned开发包保留，体积约3.07GB；无裁剪优化承诺。

从/tmp与隔离XDG实际启动包内Main20帧及完整Standard survival，两次均终端0/日志清洁。外部只读driver只提供测试控制，生产模块/资产全部从包内res路径加载；正常血量/弹药/AI，无传送/无敌/直接切目标，最终complete，随机共享identity为true。完整5556原manifest文件执行后再验大小/SHA无差异，见runtime-bundle-r10-verification.json。r9及以前不覆盖。

完成范围审计仍进行中：当前已复核研究项目的渲染/材质/贴图/光照映射与来源入口、Main资产一致性、编辑器导入、启动入口、渲染生命周期及正常玩法通关。另发现普通Main仍直接以导出时的活动敌人record构造pool：例如首Gull保留gy=.2144021/gp=.2865643且rotor0旋转矩阵非identity，而同次导出的未激活pool初态gy/gp=0、rotor identity；独立enemies展示此前有fresh reset，普通Main尚未共享该冷启动恢复。需核清并修复一次冷启动，不能在每次activate/retry清除原作应保留的pool历史。此项明确未完成，不把本轮其它验证当全部完成。

## 2026-11-16：普通Main敌人冷池与复用历史

确认Main原来把.05秒活动导出record直接作为pool初态，首Gull gy=.2144021/gp=.2865643/sweep=.050000001、rotor非初相；首Hound scan=.0250000005。原XS/jS构造为0，activate/deactivate刻意不清这些历史，所以不是在activate中统一清0。Astra Ultra只读核清7个未用Gull/6个未用Hound模板：同类型状态、同名骨骼matrix和lens初色一致，id0可作原构造见证。

Main构建actor前通过私有_cold_enemy_record一次恢复：深拷贝未激活id0模板、保留本槽rig/lens身份，经set_source_transform恢复group/同名bone并同步Native Skeleton3D，拷贝本槽独立lens初色[6,2.1091956,.30761675]，不是状态lensC[8,4,.7]。独立enemies showcase复用该恢复而不再另写一套bone/material复位。Main普通activate/retry不调用cold恢复。

相关Hound复用差异同时修正：HoundPose.reset会清prevSpeed，但原_activate不清它；Actor.activate现像已有lastPair一样保存/恢复prevSpeed后再pose(.016)。复用prevSpeed3时源俯仰弹簧x=-.0023296，而不是错误0；scan、gait pair也按源保留。

旧Main冷池fixture11604项中的初始版本6951字段有511项残留，enemy-cold-pool-before-fix.json保留。首次fixture未等首帧就销毁Main，伴material-null teardown日志，未归为生产缺陷；最终fixture等首帧后测试/退出清洁。最终11604检查覆盖18池成员、完整源状态、local group/bones及Native Skeleton3D、各槽rig/lens身份、首次激活和脏状态再利用，failures空、最大2.861e-8。

受控7秒fight原全局/局部骨骼、6灯状态回归通过（world最大1.1449e-5）；正常Standard从出生点自动通关再验1457ticks、60shots31hits13kills、3切断/撤离/结算、protected_live_frames0，focus resumes0。三GPU任务均退出0且日志清洁。见enemy-cold-start-provenance.json。r10是恢复前历史包，此项后续包纳入；当前不宣称全图像素或全部轨迹完成验收。

## 2026-11-16：r11包内冷池与正常通关

新建output/linux-runtime-20261116-r11，5556原manifest文件、3073741832bytes，固定引擎bb476c9f…不变。此次包内冷池外部只读fixture11605项通过（含原生Skeleton3D、首次激活、复用及冷构造AI draw=0），完整Standard survival通关再次通过，两次GPU进程均终端0/无ERROR/WARNING；生产资源全部从bundle解析，Main/HoundActor/enemy runner SHA与当前源码一致。执行后全5556原文件大小/SHA再验无差异，见runtime-bundle-r11-verification.json。r10和以前保留。

当前仍保持全项目完成审计进行中；本轮完成的是具体冷状态/复用修复与可运行交付，不将单一标准路线当所有模式/视觉的穷尽证明。


## 2026-11-16：最终技术验收

完整目标按资产、渲染效果、动态玩法、菜单输入、十类展示、研究与本地交付逐项复核。Astra Ultra 当前代码/证据审计未发现新确定遗漏；最终范围见 current-completion-audit.md，18 份证据身份索引见 evidence/final-technical-audit.json。当前资产清点再次通过，当前固定机位 GPU 截图与历史原生输出 SHA 相同。r16 真实 Boot、触摸/桌面捕获与全文件校验通过。技术实现完成，历史阶段的未完成表述保留为过程记录。

不宣称逐像素全等或用户已认可视觉/手感；实体触摸/手柄、Wayland、HiDPI 未实测。音效按要求排除，未提交/推送/部署。
