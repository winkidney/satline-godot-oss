# 实时D根运动与双臂过渡

生产Main现默认使用原D计算活动枪的相机局部绝对变换。射击/换弹/控制驱动先更新共享S，再调用D一次，最后动画适配器提交根。旧根采样和额外holster位移/旋转退出生产路径。双臂仍使用原采样骨骼，并应用一次刚性组差值；这不是原实时IK。

最新实机视频为 [native-live-root.mp4](../evidence/native-live-root.mp4)，10秒、1280×720、60fps、无音轨，包含ADS、射击、换弹和切枪。截图见 [ADS](../evidence/live-root-video-ads.png) 与 [pistol](../evidence/live-root-video-pistol.png)。固定MovieMaker fps不能作为实时性能证据。原录制额外产生1帧场景销毁后的纯灰尾帧，最终明确只保留600个游戏帧。hash/ffprobe和生产脚本hash见live-root-video.json。

## 生产所有权

Weapon从导出debug.S快照初始化运动状态，逻辑time现同样从S.t开始，保持这个明确初态。它不是已经证明原标题阶段全部时间线一致。reset继续按原选择性规则保留time/breath等历史，不对正在运行的旧部分S做热切换；新场景从一开始就推进D。

`Main._advance_weapon`在入口保存was_alive，先运行Weapon.update与同步Q回调，再按入口alive决定本帧D。原O只在入口判断alive，故若Q中的爆炸/自伤使玩家当帧死亡，仍需完成本帧D，下一帧才早退。本轮已修正初版在update之后重新读alive的差异。

Weapon.step_root把原生Player的on_ground/speed/velocity/yaw/eye/forward/crouch/sprint/tuning映射为原D接口。SourcePhysics无命中空Dictionary转换成null，命中保留dist；原dtcap只在D内部为.1。每个实际模拟tick只积分当前rig一次，render阶段不重复。

动画器在启用live模式后不再写两枪root、key light或target。仍从同clip/时间/ADS/sprint混合计算sampleRoot，恢复每个arm group的本帧采样姿态后只乘一次 `liveRoot * sampleRoot.affine_inverse()`。骨节点代理与Skeleton3D pose继续双写，gun children默认保留动作clip，不被静态ADS/sprint抹掉；后续六机械角色已由parts view取得所有权，见source-weapon-parts.md。活动根只在末尾写一次，旧holster增量禁用。死帧和session.reset中未提供liveRoot时只读现有根，不回退旧采样；真实掉枪仍待迁移。

## 独立适配与过渡测试

`weapon_root_motion_reference.cjs --native-player`在执行原字面D之前把输入vel量化到Native Player的Vector3，并补足有效Player合同；expected仍来自原JS，不读native结果。1200步对实际Weapon.step_root，全部S max1.13243e-14，最终矩阵max2.33474e-7。保留原1e-8/2e-6门槛。RNG、墙查询次数及origin/direction/far独立检查。它验证D适配器，未替代完整O和世界轨迹验收。

真实动画代码在导出104节点层级与70个Skeleton骨slot上进行22组、66次重复live更新，45500项变换检查，max3.53883e-7，门槛2e-6。覆盖fire/hip idle/reload、ADS/sprint、双枪、inactive root/key/target保留、无额外holster、arm差值不累积、骨双写和freeze/reset。baseline是原clip采样，不是独立原IK预期。初版测试给空源name直接赋Node.name产生引擎错误，已用仅测试节点的ID fallback修正并重跑；初次日志保留。

## 实机场景

220帧probe检查195个live tick，逐tick D与root commit各1次，暂停/已死帧为0；render后再次检查step/commit和根变换未覆盖。205帧在射击回调中置alive=false，致死当帧仍提交，后续停止。玩家jump/land等标志被D消费并清零。全场景每live tick检查360个bone/proxy target，合计70200次，包含70个武器动画骨slot。它是双写一致性，不是原IK或全部GPU顶点等价证明。

两枪实际Q仍保持每发18/17次武器随机消费、单flash/light、bloom一次，且回调内旧root未修改，随后才D提交。摄取图41/161帧已检查；双臂肩部刚性随组移动仍是明确限制。probe为自动输入，并关闭桌面鼠标捕获；初次resume因未获X11 grab报NO GRAB的日志保留，修正探针后clean。

最终780帧完整流程pause冻结、两次retry、最终playing，日志无ERROR/泄漏；控制211164项、换弹119266项、weapon10项及机械件6240项回归通过。证据为weapon-live-root-runtime.json/.log、weapon-live-root-flow.json/.log、weapon-root-adapter-verification.json和weapon-live-animation-verification.json。

## 剩余范围

六机械角色与空仓锁定后续已接入，见source-weapon-parts.md。仍需实时IK、magazine轨迹/armTargets/手部private、死亡掉枪、公开equip/snap完整副作用、原全局RNG fork和完整S/标题时间线、表面H与step/land FX、完整图像/性能/导出及全部游戏目标仍继续。不能把本阶段描述为整个原作已复刻。

Astra审查见weapon-live-root-review.md。

复现：

```sh
rtk proxy node saltline-godot/tools/weapon_root_motion_reference.cjs --native-player
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-root-adapter.log --script tools/verify_weapon_root_adapter.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-live-animation.log --script tools/verify_weapon_live_animation.gd
rtk proxy env DISPLAY=:0 saltline-godot/tools/run_native.sh --log-file /tmp/saltline-live-root-runtime.log --script tools/verify_weapon_shot_runtime.gd -- --game
```
