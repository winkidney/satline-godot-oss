# 原生战斗HUD反馈

## 实现与源码依据

`combat_feedback.gd`维护命中动画、击杀列表和四个受伤方向槽，`navigation_hud.gd`绘制，`game_ui.gd`连接实际事件。Combat新增enemy_killed通知，在原有统计增长后同步发出，早于同次player_shot的hit_enemy；不改变伤害或射线选择。Mission另发hud_reset用于整局重置，clearRadio只清无线电，按原作区分。

依据：保存活动脚本 `../../artifact-rendering-study/source/extracted/bundle-1.js` 约83631–83678（监听）、83786–83825（feed/hitmarker/reset）、84001–84031（更新）；保存HTML CSS约90–101、115–118行。活动脚本SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，原始入口 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。

- 普通命中白色，弱点橙色，击杀红色；四个角段，普通宽2px、击杀3px。原作关键帧初始缩放1.15或1.5、35%处1、末尾0.92；240ms或击杀420ms，ease-out。原生用三次贝塞尔(0,0,0.58,1)求解；同时保留未结束动画，以匹配原Web Animations未取消旧动画的行为。
- 击杀列表最多4条，寿命4.2秒；最后0.6秒触发0.5秒ease透明度淡出。最新击杀与弱点击杀必须同一process frame，才追加橙色Weak point。敌人类型使用600字重，其他文字500字重，13px与0.18em字距。
- 受伤来源为空则忽略；优先选择空槽，四槽均满则替换life最小者。1.5秒寿命，方向为atan2(dx,-dz)+yaw，整数度，透明度=round(clamp(life/0.6)*20)/20。按原CSS显示72vh或94vw内的弧线与箭头。
- 暂停隐藏HUD并停止弧线/列表寿命；浏览器动画不受此门控，原生命中动画和已开始的淡出仍按渲染时间推进。重开清列表和方向寿命，不擅自清除原作保留的动画历史。

## 验证

`tools/combat_feedback_reference.cjs`直接执行原作三个真实事件回调、feed/hitmarker方法、方向更新与feed更新循环。600帧覆盖四槽填满/替换、空来源、四条列表上限、同帧与跨帧弱点、暂停冻结、过期、reset；同时捕获原hitmarker的动画参数。

`evidence/combat-feedback-verification.json`：10396比较，0失败，最大误差4.44e-16。两端使用相同字面步长 `[1/60,.05,.001,.1]`，避免JSON十进制解析末位影响恰在0.05透明度量化边界的结果。`evidence/combat-verification.json`：240原战斗用例2160字段仍通过，新增通知没有改变伤害/统计规则。

`--feedback-preview`使用完整原生场景及真实Combat/Player事件：

| 帧 | 验证 |
|---|---|
| 100/101 | 实际player_shot命中body，白色hit |
| 150/151 | 实际player_shot命中weak，橙色weak |
| 200/201 | 实际弱点致命射线，红色kill并追加Weak point |
| 260/261 | 第二只Hound实际body击杀，第二条feed |
| 300–340/341 | 五次真实player.damage，四个方向槽填满并替换 |
| 360–390/380 | 转向时方向弧线随逻辑yaw更新 |
| 400–440 | 暂停隐藏HUD并保留寿命，恢复后继续 |
| 500/510 | retry执行完整重置，feed空、四槽life均0 |

200帧为隔离身体胶囊遮挡，射线从弱点正上方2米发出，其余从主相机发出；均走真实最近世界/敌人射线、伤害、死亡及事件链。该自动探针不是手动枪械战斗验收，也不证明相机枪口与弹道所有细节已完成。录像 `evidence/native-combat-feedback.mp4` 为10秒/1280×720/60fps，无音轨。截图 `feedback-201.png` 弱点击杀，`feedback-341.png` 四方向，状态见 `combat-feedback-runtime.json`。

尚未逐帧对照浏览器Web Animations实际像素与CSS文字渲染；源动画参数、生命周期对照和原生GPU画面是本阶段证据。方向弧线为原SVG圆弧的原生折线近似；后续生命/弹药/环形交互已接入，见 `status-hud.md`；伤害后处理及剩余渲染仍待完成。
