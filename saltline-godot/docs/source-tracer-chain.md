# 曳光烟迹与实际发射链

原F的五团轨迹淡烟现已接入玩家和猎犬的曳光入口；Yg状态写入恢复Float32，实际命中、弹痕、爆炸物、曳光和弹壳的同步顺序也按源码修正。武器枪口余烟由Weapon.update持有状态，在原heat衰减前发出请求。

## F与Yg

ImpactEffects.tracer先调用主tracer_pool.emit，再判断clock-last>.07和trail严格不为false。通过节流后先更新last，即使距离<=2也会消耗本次节流窗口；距离>2才沿起点至min(distance,7)的轨迹生成五团puff。烟迹速度为dir.x/z*.6，Y固定.05，fin覆盖为原Float32 .25。clear不重置FX时钟或trail timer。支持实际玩家默认色、猎犬hex色、数组和Native Color/Vector3；hex转换使用原ya常数和double中间值。

Native Yg的dist/speed/len/width/travel按Float32写入，首帧推进在update时才抽一次随机数。center/axis/halo/head颜色先标量计算，最终写入Vector3/Float32属性，避免提前量化。48池满时覆盖槽0、移除时尾部交换，以及短曳光至少显示两帧规则保留。

tracer_trail_reference.cjs直接提取原F/ph/M/u1/Yg与qP，统一u53 tape。容量2/80各80操作，包括65次emit、14次Yg update和1次clear，覆盖>.07、距离2边界、默认0回退、trail=false与数字0、hex/array色、48槽覆盖、极短拒绝、尾交换和clear后timer。169800检查/366draws通过，max3.552714e-15，tol1e-6。原quads按原GPU属性的Float32域比较，Native覆写_draw收集构造结果，不是GPU回读。方法SHA256 1025c299771261bf7e62a80636e5187e7d9d22c6c2123a2d7d6563175b947a90。Yg len夹取2/7端点及frames250未由该序列命中。

## 同步发射与更新顺序

原boot先构造f1再构造yE，所以FX impact listener先于爆炸物impact listener。原combat.playerShot同步触发impact，随后Q才调用F tracer和shell。旧Main把玩家_visuals推迟到_weapon_fired尾部，敌人路径也没把impact交给爆炸物。

现在_combat_impact对所有from先做_visuals，再调用爆炸物impact：player使用当前枪damage，0按原fallback26；其他来源用9。玩家F/shell在combat返回后发生，猎犬F在combat后、muzzleFlash前发生，匹配原C0发射函数。实际枪定义伤害均非零，fallback另作测试。音频按目标省略。

Main效果更新先对非正dt置0，再推进FX clock、执行smolder。ImpactEffects.update按原le顺序更新lit、add、Yg、debris，最后Main更新shell。主tracer_pool由FX update更新，避免旧预览路径重复推进。weapon视觉更新仍先行，它不在le接收器比较范围。

fx_update_order_reference.cjs提取原le和yE impact回调。真实Main._advance_effects/FX.update以trace接收器比较dt[-1,0,.016,.05,.001]的顺序和clock；Main._combat_impact另测player两枪、enemy9、player0→26，共115检查通过。原impact/decal trace前缀按已审listener和A顺序记录，yE伤害回调才是本fixture新字面提取；接收器内部由独立数字测试证明，不能扩大为全游戏帧联合回放。

## 枪口热烟归属

旧FX独立保存smoke_remaining/smoke_tick并在所有actor及shell更新后发烟，用到的是新root和衰减后的heat。现在使用motion_state.smoke/smokeTick，在Weapon.update原位置、heat衰减前触发smoke_requested。Main立即读取旧gun root的muzzle调用通用smoke，随后才运行root/arms与敌人、爆炸物。Source lifecycle reset清smoke但保留Tick，保持旧语义。若没有smoke接收者，Tick不重置，符合原n.fx.smoke可用性门控。

weapon_smoke_reference.cjs字面提取原I5 O的smoke块到heat decay，58步/9请求，实际Native Weapon.update的335检查通过，max2.88658e-15。覆盖窗口、heat.4、Tick0、持续烟、负remaining仍可末次发烟、接收者缺席、reset保留tick。reset参考赋值来自已审T，不是此次重新提取全T；pistol例只证明继续已有smoke，不单独证明窗口内不初始化。此项对状态与options，不包含通用I的全部粒子数值或原muzzle坐标。

## 实机证据

verify_tracer_chain_runtime.gd实际Main480帧、87检查失败0。13次射击均逐发检查impact callback早于本发tracer/shell，两者随后各增1。12次事件观察到trail timer==clock，其中第2发间隔4/60小于.07，按节流未发trail。timer标记不是逐发五团粒子增量断言，五团数值由F独立参考证明。

96/102/108/114/120/126帧共6次热烟，实际信号时gun root transform仍等于本帧更新前；信号时heat与本帧结束后相差dt*.2。此处证明时机，不是原作muzzle坐标配对。480末add/lit/tracers自然归零，不据此声称显式clear API或资源释放已独立证明。已查看075/115实机图。

本轮较早470帧11共享引用/385FXcalls及骨骼/机械/弹匣回归通过，归档tracer-chain-arms-runtime；它早于最后lit/add顺序等微调，不冒充最终代码的逐字快照。最终780流程pause冻结、最终playing、两次retry，三次reset的particles/shells/emitters/decals均0，见tracer-chain-flow.json/.log。原Q96shots/2424、smolder54176、A+decal399796回归通过。

## 仍需保留

通用ph字符串/CSS颜色及缓存、通用I的size/life/count/alpha显式0默认规则仍未完整迁移；实际玩家/猎犬当前输入为默认或数字色、武器烟参数均正值。通用I的粒子位置中间精度也没有在此次状态参考中证明。

完整带particle motion/排序、所有actor/事件/天候交错的Math.random原帧回放、源pixel配对、弹壳旋转历史及其他未完成系统仍需继续。原bundle SHA256 756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8。Astra复核见tracer-chain-review.md。
