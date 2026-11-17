# 原生游戏状态、重开与任务无线电

本阶段迁移原作活动脚本的状态编排和第一版原生菜单，目标仍是完整复刻；本记录不代表全游戏完成。

## 实现与依据

- `scripts/game_flow.gd` 对应原作 `bundle-1.js:84799–85748` 的pT控制器：标题Catmull-Rom相机、正常2.4秒/重试1.1秒intro、暂停0.35秒防抖、死亡1.5秒后菜单、撤离3.3秒后菜单、淡出/去饱和、重试计数、模式保留和Holdout最高分。
- `scripts/session.gd` 对应原作Q重置顺序：清敌人/FX/统计、武器/爆炸物、任务/玩家、动画和巡逻布置；保留原作未清空的时钟/RNG/池游标。
- `scripts/game_ui.gd` 用原生Control构建标题/设置/暂停/死亡/结算菜单。字体见 `assets/fonts/manifest.json` 和三份OFL许可；标题按原作198px和0.15em字距。菜单仍需逐像素校准。
- `scripts/mission.gd` 的radio_requested/radio_cleared与 `scripts/radio.gd` 对应原作Vu/pT事件及HUD Y函数（约83766、84032、85469–85707）：58字符/秒、打字完成后的停留计时、无队列上限、逐行切换、空文本忽略、显式清理。HUD每帧更新无线电，暂停也继续计时，与原作主循环一致。
- 文案由 `tools/export_game_rules.cjs` 从Vu直接提取，随原活动脚本SHA256记录；未凭空编写任务台词。Holdout补给原先误接message，现改为原作radio。

源文件：`../../artifact-rendering-study/source/extracted/bundle-1.js`，SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。在线原始来源：https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。行号针对该保存快照。

## 验证

| 证据 | 覆盖与结果 |
|---|---|
| `evidence/game-flow-verification.json` | 执行原作完整pT，500帧11030比较，0失败，最大误差6.03e-6；标题轨迹、intro中暂停、死亡重试、撤离重部署、最高分更新/保留 |
| `evidence/mission-verification.json` | 完整pT受控260任务帧+1100 Holdout帧，482543比较，0失败；新增首次发现重复事件、低血量、三点断开、撤离与补给radio序列 |
| `evidence/radio-verification.json` | 直接执行原作HUD Y函数，720变步长帧5760比较，0失败；9行启动、排队、空文本、零时长、打字/停留边界、清空与替换 |
| `evidence/player-vitals-verification.json` | 600帧及真实A.reset对照，9015字段，0失败；ADS/FOV死亡恢复、健康和原作保留状态 |
| `evidence/game-flow-runtime.json` | 780帧GPU自动输入，真实Button信号；暂停停止玩家/敌人/武器/任务，三次reset恢复HP100、30/150步枪弹药、21爆炸物、595碰撞盒、5巡逻敌人，特效池清空，三次无线电队列/当前行均清空；第143帧启动真实intro台词 |

录屏 `evidence/native-game-flow.mp4` 为1280×720、60fps、13秒，无音轨。截图 `flow-045.png` 标题、`flow-060.png` 设置、`flow-180.png` intro与无线电、`flow-215.png` 暂停、`flow-375.png` 死亡、`flow-550.png` 游戏HUD。GPU设备RTX4070SUPER，Forward+，Godot4.7.2。

## 仍缺的验收和功能

罗盘、世界目标标记和扩散准星已在后续导航HUD阶段接入，见 `navigation-hud.md`。后续命中/击杀/方向伤害反馈已接入，见 `combat-feedback.md`。环形交互、弹药/生命样式也已在后续阶段接入，见 `status-hud.md`；warning/message只是第一版文字呈现。设置缺画质与武器位置，键鼠缺近战F/滚轮切枪，其他输入方式未完成。持久化已有读写代码，但还没有跨进程恢复测试。GPU重试通过自动驱动，不能证明手动整局通关；受控pT对照也不证明整个系统全局RNG一致。海水、天气、反射、完整后处理与材质精度另见主状态清单。


后续雨水集成回归：原生780帧流程重新运行，pause_frozen同时检查rain_system.time；三次reset仍通过。默认录像已更新到雨水、玻璃与生命/弹药HUD均启用的版本。
