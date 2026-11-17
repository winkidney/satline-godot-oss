# 生命、弹药和环形交互HUD

原生实现 `scripts/status_hud.gd` 由GameUI驱动；移除了旧开发HP/弹药文字和水平进度条。依据为保存的活动脚本 `../../artifact-rendering-study/source/extracted/bundle-1.js:83743–83765,83926–84000`，CSS来自保存HTML约102–153行。源快照SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`；原始入口 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。

## 行为与样式

- 弹匣尺寸为int后0回退30，再夹1–60。弹药数字两位、备弹三位；Infinity和备弹>=9999显示∞。真实武器仍为步枪30/150、手枪15/∞。
- 低弹阈值ammo<=ceil(mag×0.27)，大数字和已装弹pips橙色。提示按装填优先，其次切枪隐藏提示，再处理空仓或低弹。空仓且未装填的urgent样式红色0.7秒分两档闪烁。状态数学支持原作键鼠/手柄/触屏文案，但游戏其他输入方式尚未完整实现。
- Big Shoulders Display700字重76px弹药主数字，3×11px pips间隔2px；武器名和Q备用武器弹药沿右下角显示。字符间距按原CSS设置。
- HP向上取整，10段条按ceil(ceil(health)/maxHealth×10)点亮；<=3段用危急红。health<maxHealth-0.5显示，0.12秒淡入、0.6秒淡出，使用CSS ease贝塞尔。正常满血隐藏。
- 真实最近可交互中继点显示48px键环，半径19、3px线宽、从顶部顺时针；进度按round(t×200)/200量化。接近点、面向/距离、切断/取消等条件由原Mission控制，未另造可交互判定。文字框为原CSS plate背景与橙色左边框。

## 验证

`tools/status_hud_reference.cjs`实际执行原作完整弹药/生命HUD代码块并用轻量DOM记录输出，非重写JS公式。800组输入覆盖mag0/负数/大于60、空仓/低弹临界、有限/无限备弹、装填/切枪提示优先级、三种输入文案、生命取整/分段/显示和危急阈值。`evidence/status-hud-verification.json`：9600比较、0失败。

`--status-preview`使用完整原生场景，720帧自动驱动真实武器/玩家/Mission：

| 帧 | 实机状态 |
|---|---|
| 80 | 初始30/150，HP100，生命条透明度0 |
| 120 | HP25、三段危急生命条，步枪8发及Low ammo |
| 170 | 真实装填中，Reloading覆盖Low ammo |
| 290 | 装填结束，30发、备弹128 |
| 340 | 真实切枪到手枪15/∞，副武器显示步枪30/128 |
| 430 | 切回步枪并传送到真实中继点，持续按interact，进度0.2153 |
| 520 | 仍按interact，进度0.8403；真实延迟回血已开始 |
| 560 | 真实交互完成，cut1，提示环消失 |
| 620 | heal恢复100，生命条隐藏；受控设为0弹/0备弹，提示Empty—Q swaps |
| 700 | retry完成，cut0，步枪30/150，HP100 |

视频 `evidence/native-status-hud.mp4`：12秒/1280×720/60fps，无音轨。`status-120.png`为低血低弹，`status-430.png`为环形交互，完整数据见 `status-hud-runtime.json`。弹药8和0/0是隔离HUD边界的受控赋值，装填/切枪/受伤/回血/交互/重试走实际系统。传送并自动按住E不代表手动通关。

字体基线、CSS容器换行、淡入淡出和环形线段的逐像素浏览器对照仍需完成。目标面板与打字、警告/消息动画、其他输入方式，以及剩余材质和后处理仍未完成。
