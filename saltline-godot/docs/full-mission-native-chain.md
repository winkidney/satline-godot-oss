# 原生主场景整局任务状态链

`tools/verify_full_mission_runtime.gd` 不走旧的 --mission-preview 分支，直接实例化实际 Main，使用 GameFlow 与 GameUI。采用受控位置跳转和无敌状态，输入为实际 Godot physical E key 事件；不替代出生点步行路线或人工战斗通关。

## 已观察

1100 帧，14 项状态断言通过，日志无脚本错误与告警：

- 初始抵达船只不能撤离，显示 Relays still live 消息。
- 在三处继电器位置分别按住 E，实际切断发生于第 195、405、625 帧；实际任务波次与敌人继续运行。
- 第 625 帧 objective:all，目标文字变为 Get to the boat，导航仅保留撤离标记。
- 第 700 帧抵达船只，实际状态 complete，玩家禁止移动并无敌，HUD 隐藏。
- 第 930 帧延迟后的结算菜单可见。记录时间 11.6666666666668、accuracy=null、kills=0、retries=0、rating=Clean。
- 第 960 帧通过实际 Redeploy 按钮信号重新部署，第 1025 帧回到 playing；第 1100 帧任务计数与交互提示均已重置。

数据与日志：`evidence/full-mission-runtime.json/.log`。截图：`full-mission-0680.png`、`full-mission-0710.png`、`full-mission-0930.png` 等。

## 结果卡片修正

原 HTML `.m-card` / `.m-k` / `.m-h` / `.m-stats` / `.m-rating` 第 278–292 行，原 bundle complete/dead HTML 第 84230 行附近及 setDebrief 第 84633 行。

新增 `result_card_content.gd`，替代以单一等宽 Label 堆叠全部统计。恢复 44px 大写结算标题、独立 46px 橙色评级、左右对齐统计行及分隔线。暂停/死亡标题 62px，死亡标题与顶部边线使用 alarm，背景 veil 透明度 .35；普通卡片 veil 为 .62。恢复卡片 26/26/24px padding 与 1px 外框、3px 顶线对应的内容边距。Holdout 死亡页恢复 Time survived 字段并保留波次、击杀、分数及最高分。

查看卡片内容变化时显式 reset_size，避免暂停菜单更高的旧高度残留到死亡卡片。既有 GameFlow 500 帧、11030 项状态比较通过；实际暂停/死亡/重试/重启流程另外跑 780 帧。

## 边界

这不是人工通关验收：没有证明从出生点到全部目标的步行可达性、战斗平衡、所有玩家选择和全部模式。0 shots 的结算只覆盖 accuracy=null；其他评级/分数算法沿用此前原版对照，此处不扩大其证明范围。

卡片字体栅格与 CSS 精确 margin collapse 未做浏览器逐像素匹配。按钮字距、焦点边框、菜单过渡、窄屏滚动与小高度布局仍未完全对齐。普通按钮继续使用已有 Godot Button，而非宣称原版 UI 已全部复刻。后续仍需设置/输入/画质、资源清单与交付打包，以及整体视觉和人工验收。

最终卡片收缩修正后的 780 帧流程通过：暂停冻结，三次重置，结束于 playing，日志无错误/告警。归档 `evidence/result-card-flow.json/.log`；`result-card-235.png` 与 `result-card-375.png` 为最终暂停/死亡画面。结算截图来自顶部边线修正后的完整 1100 帧运行，其后只增加了通用 reset_size 调用。
