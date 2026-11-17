# 武器控制状态生产接入审查

本次只读核对 `weapon_motion_controls.gd`、`weapon.gd`、Main 的 look 接线、原 O、参考生成器和验证器。当前迁移的控制公式与执行顺序符合原作，未发现阻止交付本阶段的运行代码缺陷。审查发现的字符串比较漏洞已修复并重验。结论是原 wants、逻辑 ADS/sprint、inspect 窗口、finger、dry 冲量及死亡早退的选定控制路径已进入实际 Weapon；不代表完整 O、D、掉枪、实时根或 IK 已完成。

审查只新增本文，不修改生产代码或测试。以下报告由主线运行，本次核对其文件、日志与参考输入，没有重复运行 GPU。

## 公式与执行顺序

来源是 [原 bundle](../../artifact-rendering-study/source/extracted/bundle-1.js) 的 O（L79607–79788）。[控制核](../scripts/weapon_motion_controls.gd) 与 [Weapon 接线](../scripts/weapon.gd) 保留了以下顺序：

| 阶段 | 原位置及本轮确认 |
| --- | --- |
| alive 早退 | L79607–79618：死亡时清 previous_fire 并在时钟、换弹和控制推进前返回。native 不再在死亡期间推进 weapon.time。 |
| sprint / wants | L79633–79639：先计算 sprint、用原 j0 表达式更新 sprintT，再写 spWant/urgent，之后才处理本帧 pressed reload / autoReload。 |
| dry | L79673–79688：保留自动枪 dryDone 与手枪 edge/fire_queue 的原有入口，先 emit dry，再给 bump.v 减 .08。 |
| ADS | L79715–79719：在本帧换弹/射击阶段之后计算可 ADS 条件；adsLin 用原线性推进与 clamp，adsE 用原 Ot，同时写 adsWant。 |
| idle / inspect | L79731–79750：活动使 idleT=0，已有 inspect 先推到至少 2.9；随后加 dt、计算三个窗口，只有 time>3.5 才结束并清 idleT。 |
| finger | L79763：使用 `target + (value-target)*exp(-30*dt)`，正常生产 target 为 fire && can_fire；没有改成不同运算顺序的 lerp。 |

inspect 的活动条件保留严格阈值：speed>.2、abs(look.dx)+abs(look.dy)>.002、sprintT>.1；阈值相等时不触发该条件。自动 inspect 要求材质/枪定义的 inspect 为真、当前 inspect<0 且 idleT>24。三路权重分别使用原 `.5 / 1.4 / 1.5 / 2.8 / 2.9` 时刻，计算窗口后才检查 >3.5，未提前截掉尾部。

`spWant/urgent` 读取的是处理本帧 reload 请求之前的状态，ADS 和 idle/inspect 读取的是处理之后的状态。这个差别是原 O 的顺序；不能为“同步”把它们移到同一段。当前代码顺序已经核对，但 literal O 的空仓测试没有发出 reload 请求，不能说该前后关系已由那条轨迹独立验证。

切枪开始时清 motion_state.inspect，equip/reset 沿用已验证的选择性生命周期核。holster 在切枪阶段更新后复制到 motion_state.hol。新增 `inspect` 状态的优先级位于 switching/reloading 之后、sprinting/firing 之前，与原 E.state 相同。

## Main 的 look 合同

[Main](../scripts/main.gd) 的 game_mode tick 只调用一次 source_mouse_input.consume。override 未提供 Dictionary look 时使用本帧累计值，再把同一 input.look 交给 `player.look_normalized()` 和随后的 Weapon.update。没有在武器侧再次乘鼠标灵敏度，也没有把 player 已乘 ADS 系数的相机旋转差反推成 look。

因此本轮 inspect 的 `.002` 阈值读取原归一化输入；未来 D 的 sway 也应继续读取这份输入。Main 最终通过 get 默认 0 读取 dx/dy，允许 override 缺少单个字段。没有模拟的帧会 clear，状态切换/reset 也清积累，避免恢复时重放旧 mouse delta。本结论针对实际 game_mode 路径；非 game 的旧预览仍有直接 player.look 调用，不在这次归一化桥验收范围内。

## 独立参考与已修复的验证漏洞

[参考生成器](../tools/weapon_motion_controls_reference.cjs) 直接提取原 spWant/urgent、idle/inspect、finger 片段及数学 helpers；另提取完整原 O，在受控 stub 环境中运行。它没有读取 native 控制实现来生成 expected。源身份为：

- 原 bundle SHA256：`756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。
- 三段控制原文 SHA256：`68eb2754c9a4869bc647cd6827f296073c789964c7a2b712ebb6b6df03be39eb`。
- 完整 O 原文 SHA256：`b833679d09edc6afee4f91ad924ba93bd0161d98546394a6fe0be62cb2d969a3`。

审查发现初版 compare 没有特判 String，state 和 dry.weapon 会落入 float 转换，不同非数字字符串可能同为 0 而通过。[最终验证器](../tools/verify_weapon_motion_controls.gd) 已把 String 纳入精确比较分支，重新运行后仍通过。最终结论依据修复后的报告，不用初版数值通过来证明状态名或枪名一致。

当前 [weapon-motion-controls-verification.json](../evidence/weapon-motion-controls-verification.json) 为独立 block 640 步，加两枪实际 Weapon.update 对原 literal O 的 4,900 步；共 211,164 项比较，最大绝对误差 `1.4210854715202e-14`，门槛 `1e-12`，零失败。数值检查拒绝 NaN/Inf。参考与 native 的初始时钟都显式设为导出 S.t；这是一项对照前提，生产新建 Weapon 的 time 仍为 0，不据此声称启动快照时钟已经相等。

## 覆盖是否真正命中

本审查直接统计 fixture，而非只依据生成器循环数量：

- 独立 block 的两枪用例中，fire、ADS、reload、switch、speed、sprint 六个 inspect 中断条件，每枪均各作为首个命中条件出现 10 次，look 为 17 次。包含 null look、阈值附近和 inspect 尾部时刻。
- literal O 的每枪 2,450 步中，各有 14 次 dry、10 步死亡早退、24 步 fire 被 sprint 阈值阻挡、12 步 ADS 被 sprint 阈值阻挡。
- Rifle 实际输出 idle 2,109 步、inspect 210 步、sprinting 131 步；三个 inspect 窗口分别有 113、108、203 个非零样本。
- Pistol 实际输出 idle 2,319 步、sprinting 131 步，没有自动 inspect，符合其定义。独立 block 中强制的 inspect 状态用于验证公式，不应冒充手枪的正常自动 inspect 行为。

最终 fixture/report 已保存 coverage：两枪各 ADS want 188、sprint want 130、dead 10、dry 14；rifle inspect 210、任一窗口非零 203，pistol 均为 0。生成器断言 rifle 必须实际 inspect、pistol 不得自动 inspect，并拒绝 dead/ADS/sprint/dry 任一缺失。该记录与本审查独立统计一致，最终比较数和误差保持不变。

独立 case 还定向检查 idleT=24、dt=0 不开始 inspect，以及下一步超过 24 才开始；不把仅靠长轨迹越过阈值当作等号边界证明。

完整 O 原文不等于完整 O 行为被测试：ammo/reserve 固定为 0，pressed 恒 false，u.active 为 false；没有执行实弹 Q、换弹、自动换弹或切枪分支，也没有 RNG。D、parts、arms、死亡更新 helpers 被 stub，drop 被预设为 already active。测试比较的是 17 个顶层控制/逻辑结果（含 windows 和 dry 集合），没有比较整份 S、drop/flash 结果或变换。

本轮也核对到 [reload 集成报告](../evidence/weapon-reload-integration-verification.json) 119,266 项零失败及 [Weapon 常规回归](../evidence/weapon-verification.json) 10 项通过；对应本轮临时日志为 `/tmp/saltline-controls-reload.log`、`/tmp/saltline-controls-weapon.log`。这些补充原有换弹/射击状态机回归，不应合并成一条已经对齐全部 O 的原文轨迹。

## 保留的生产边界

1. **S 仍是部分同步状态。** 本轮同步 t、sprintT、hol、adsWant/adsLin/adsE，直接计算 spWant/urgent、idleT/inspect/finger、dry bump；发弹时还写 burst/lastShot。cooldown、spreadS、prevFire 等其他旧 Weapon 字段仍不是全程以 motion_state 为唯一来源，burst 的后续归零也仍在旧字段。实际比较会读取对应的旧 Weapon 逻辑值，不能说整份 motion_state 已与原 O 相等。
2. **inspect 和 finger 尚未生成实时可见姿态。** motion_inspect 保存三个原窗口，但还没有 D 消费者；finger 也没有接原 parts/armTargets。根、子节点和双臂仍采样。出现 inspect 状态不等于原检查枪身动作已经可见。
3. **死亡只接了控制早退。** 原 O 在早退前还运行 drop/死亡更新并隐藏 flash；本轮只有选定控制与 clock 冻结被验证。不能据此宣布原掉枪、flash 清理和死亡姿态完成。
4. **debug/可见性分支仍有限。** 原 g/noFire、pause、debug ADS/sprint、flash 对 finger 的强制输入等不属于当前正常生产控制参数。暂停由上层 flow 决定是否调用 update，不能等同于已经迁移 O 内部所有调试分支。
5. **后续 D 接管仍需一次性切换。** 保持原时钟、共享 S、玩家 step/jump/land 和随机流的顺序，再停止采样根及旧 holster 增量；不能将新窗口或冲量直接叠到已经包含这些动作的采样根上。

本阶段可以表述为“原武器控制目标与窗口进入生产，并以独立原片段和受控 literal O 验证”。完整 O、实时根、机械零件、手臂 IK 与死亡掉枪仍须单独验收。主线后续另保存了 [controls flow 报告](../evidence/weapon-motion-controls-flow.json)、[运行日志](../evidence/weapon-motion-controls-flow.log) 和 [CPU clean log](../evidence/weapon-motion-controls-clean.log)；这些实机结果不扩大本文的控制公式审查范围。
