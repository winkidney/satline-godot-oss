# 枪内六角色实时机械状态

生产已替换步枪bolt/round、手枪slide/barrel/slide-stop/round六角色的采样写入。WeaponPartsMotion按原rig私有状态推进，WeaponPartsView写实际节点；弹匣轨迹、手部目标、trigger blend/hand impulse和完整IK仍未迁移。不是全部枪内动画已经完成。

## 状态与事件顺序

原rifle parts在bundle L77176–77184，pistol parts在L78819–78835，shot/reset/cancel/setLocked在各自相邻rig方法。rifle boltTravel=.062，.072秒正弦行程乘.95并与reload handle override取max。原yS=0，因此步枪空仓虽locked=true，周期结束仍回闭栓，不能按手枪规则持开。

pistol .024秒退后、.066秒周期，slideTravel=.04；空仓保持slideLock=.036，barrel随slide/.006上限1产生.02 pitch和.0025 z偏移，slide-stop按-.06*j旋转。empty reload在thumb/slideRelease/slide节点之间释放，并于slide事件解锁。round在最后一发隐藏，在新弹匣fresh阶段恢复，取消时依据当前ammo恢复可见性。

Native在原Q的flash返回后调用shot，finish/finger之后仅推进active rig的parts一次，随后D和Animation。切枪不清inactive私有历史。取消按reload.weapon/seated/ammo处理；reset清两枪私有状态；endReload仅恢复原方法所清的字段。

Reload kernel把fresh、magin、boltback/bolt/slide私有变化放回原事件分支位置；rifle handle在bolt事件前计算，pistol reload slide pose在连续权重前计算。没有另跑第二份事件扫描或额外弹药转移。已验证的S冲量/事件handler继续共用。

## 六节点所有权

源节点匿名，按固定版本wS/zS创建顺序绑定，原assembly与导出层级已核对。animated node indices为81/84/92/94/98/101，完整Node/Geometry/Material记录见weapon-parts-bindings.json。barrel/slide必须为Group，实际source base均单位basis；barrel y=-.01，stop y=-.0165/z=-.004保留。

Animation在transform/visible写入前跳过这六个owned节点，parts view每帧恢复源base local transform再写原指定轴与round.visible。它不改root或骨骼，不重复叠加上一帧位置。inactive rig读取未推进的私有状态；其root可见性仍由装备状态控制。此路径绑定已钉住的原资产，不是适配任意模型的自动识别器。

## 对照与实机

参考直接提取原私有methods、ge/de、slide helper、reload机械prefix/pose；手部target holders为mock，magazine/arm中段省略。272次显式操作包括healthy/empty shot、周期边界、setLocked、两种reload、取消前后seated、reset与顺序1.59回位内点。Native parts+kernel+实际Animation施加ADS/sprint采样压力，3400项比较，state max3.10862e-15、view max1.54972e-9，门槛1e-12/2e-6不变。不是完整O或原IK轨迹证明。

GPU实际Main470帧，25次持续空仓持锁、2820次六role属性检查。pistol先0弹/0reserve持开，补reserve后empty reload释放；rifle最后一发按yS0闭栓，reload拉到完整.062再回位。检查实际position、rotation和两round.visible，避免只比较状态字典。截图 [空仓持锁](../evidence/parts-runtime-070.png)、[步枪拉柄](../evidence/parts-runtime-408.png) 已查看；scope不扩大为原图像等价。

生产reload119266项、Q1212项和weapon10项回归通过。780帧GPU流程pause冻结、两retry、最终playing，无ERROR/泄漏。证据为weapon-parts-verification.json、weapon-parts-runtime.json、weapon-parts-flow.json及同名clean日志。

Astra审查见weapon-parts-review.md。接下来继续magazine轨迹、armTargets/trigger/hand impulse、实时IK与死亡掉枪，原全局随机fork、完整S/O/时间线和整体图像/性能/导出验收也仍未完成。

复现：

```sh
rtk proxy node saltline-godot/tools/weapon_parts_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-weapon-parts.log --script tools/verify_weapon_parts.gd
rtk proxy env DISPLAY=:0 saltline-godot/tools/run_native.sh --log-file /tmp/saltline-parts-runtime.log --script tools/verify_weapon_parts_runtime.gd -- --game
```
