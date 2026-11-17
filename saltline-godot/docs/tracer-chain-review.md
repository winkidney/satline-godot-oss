# 曳光 F 与发射链审查

本轮只读核对原 `F/ph/M/u1/Yg`、Weapon 的 smoke 状态块，以及 Main 的同步 impact、玩家/猎犬发射和 FX 更新调用顺序。当前受控原函数证据支持曳光生成与更新进入生产；未发现实际两枪和猎犬正常输入域中的阻断问题。完整游戏事件链、全部 FX 随机消费、通用 smoke 生成和像素结果仍需各自验收，不能由 F 内核通过代替。

本次只新增本文，没有修改生产代码或重跑 GPU。原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)，SHA-256：`756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

## 同步发射与帧顺序

原 `ey.playerShot`（L69259 起）先执行敌人 damage，再同步发出 impact；世界命中也在返回结果前发出 impact。原 FX listener 在 L60253 注册，而普通 boot 先创建 f1（L85922），再创建 yE explosives（L85928）；因此同一 impact 上先完成原 A 的粒子/碎片/decal，再处理爆炸物伤害。yE 的 listener 见 L69619。

[Main](../scripts/main.gd) 当前 `_combat_impact` 同步执行 `_impact_visuals`，然后调用 explosives；`_weapon_fired` 尾部旧的延迟 impact/显式 explosives 已移除。玩家路径变为 combat 内同步命中效果 → F tracer → shell → muzzle light → enemy fire alert → recoil/bloom → flash。这个结构符合原 Q（L79379 起），也避免一次命中走新旧两条入口。原 A 内 decal 顺序已有 [联合审查](decal-joint-review.md)，本轮没有重新证明全部 A 分支。

猎犬路径先 `combat.enemy_shot`，再 tracer、muzzleFlash、额外 light，与原 R（L82599 起）一致。玩家被直接击中时不制造世界 impact，世界命中则先同步处理该 impact；不能把两类结果合并成一条无条件粒子路径。

原主循环 L86028–86069 的 playing 段是 player → weapon → enemies → explosives，之后非 paused 执行 FX。Main 的对应段保持此顺序，FX 此时推进会处理本 tick 刚发射的 tracer。`ImpactEffects.update` 是 tracer 更新的唯一正常入口；不应再在 Main 额外调用一次 tracer.update。

原 FX `le`（L60304）内部先 sanitize dt，再推进 m 和 oe，随后 lit pool → additive pool → Yg → debris → shells。初审指出的 lit/add 反序、Main 在 sanitize 前推进时钟均已修复：当前 Main 和 FX.update 都先把非正 dt 归零，Main 先推进时钟和 smolder，再调用 `update(dt,false)`，由后者依次推进 lit/add/tracer/debris，最后 Main 推进 shells；时钟不会重复增加。

新增 [fx_update_order_reference.cjs](../tools/fx_update_order_reference.cjs) 字面提取原 le 和 yE impact callback；[验证器](../tools/verify_fx_update_order.gd) 实际调用 Main._advance_effects、FX.update 与 Main._combat_impact，用 trace 接收器核对顺序、dt、clock 和伤害。五个 dt 为 -1、0、.016、.05、.001；四种命中输入覆盖 player rifle 28、player pistol 20、enemy 9 和 player damage=0 回退 26。当前 Main 的缺失 damage 也默认 26，显式零另行回退，关闭初审的默认值缺口。

[115 checks 报告](../evidence/fx-update-order-verification.json) 零失败。本次禁写重放与 [fixture](../assets/export/fixtures/fx-update-order-reference.json) 逐字节一致，SHA-256 `4b661d8799fea9ebe69c29c111e45ad79bffe57499c38877257460f3c793336d`；le 原文 SHA-256 `5408d0f5115a503963c7d0e9d527fb14a8c622056d6a923bfd2055fd96fbb5c8`，yE 回调 SHA-256 `f541d2a69d34ba6f0206af47355ddb1fdceb5ca574687f12445be27da4b1d870`。impact/decal 前缀在参考侧按已审 listener/A 顺序记录，新增字面回调证明 yE 的后续伤害选择；接收器内部数值仍由各自测试负责，115 项不等于完整全局 frame/physics 重放。

## F、Yg 与参考独立性

[tracer_trail_reference.cjs](../tools/tracer_trail_reference.cjs) 直接切出完整原 `u1/Yg/qP/ph/M/F`，Three 数学类取自原 bundle；替换随机源、shade 查询和绘制输出接收器，没有引用 Native 的计算结果。本次以拦截写入的方式独立重放，生成 JSON 与磁盘 fixture 逐字节相同。

- [fixture](../assets/export/fixtures/tracer-trail-reference.json) SHA-256：`13850601d4d8c6a946f1a4315cfe735f5c1d66bcf775b650d77e30042ea4b7bc`。
- 被提取方法 SHA-256：`1025c299771261bf7e62a80636e5187e7d9d22c6c2123a2d7d6563175b947a90`。
- [当前报告](../evidence/tracer-trail-verification.json)：2 种 lit 容量，各 80 ops，169,800 checks、366 draws，最大误差 `3.5527136788005e-15`，零失败。时间门槛 1e-10、数值属性门槛 1e-6、计数精确比较，均检查非有限值。

原 F（L59588–59633）先加入 tracer，再检查严格 `clock-last > .07`；通过后先写 last，之后才判断长度 `>2`。Native 保留此顺序，因此短路径也可能消耗一次 trail 时间窗口。`trail:false` 才禁止烟迹，`trail:0` 仍允许；intensity/speed/width 为 0 时回退 16/260/.024。现有参考实际命中这些路径。

[tracers.gd](../scripts/tracers.gd) 把原 Yg 的 distance/speed/travel/length/width 按 Float32 存储，位置/方向/颜色也是 Vector3 的 Float32 域。中心、span、halo 的标量运算完成后再构造最终 Vector3，避免先做 Vector3 运算引入额外舍入。首帧随机推进、至少保留两帧、交换删除和满 48 槽覆盖均与原 Yg（L58112–58164）对应。

独立计数确认每容量有 65 emits、14 updates、1 clear；15 次满 48 槽覆盖、1 次长度 `<.001` 拒绝、7 次 trail timer 更新，其中 5 次产生共 25 次 puff 尝试。每容量有 50 次 tracer 首帧抽样，加 25×3 次 puff 预抽样；cap2 成功 4 次、cap80 成功 25 次，各再耗 4 draws，得到 141+225=366。cap80 的烟池最大占用为 20，饱和路径由 cap2 覆盖。

以下边界保留：

- verifier 覆写 `_draw`，比较的是量化到原 Float32 顶点属性域的 quad 参数，并非 GPU 回读、实际 ArrayMesh 或像素对照。
- Yg 的 length 夹取 2/7 端点未命中，测试中 length 为 2.64–6.072；frames 的 250 上限未命中。这与已覆盖的 F 路径长度 `>2`、trail extent 最大 7 是不同条件。
- 测试 update 只推进 Yg，没有推进 puff 运动；shade 被固定为 1，没有证明真实遮阴查询。两类 pool 的共享更新、透明排序和合成结果也不在该 fixture 中。
- clear op 直接清 tracer/lit pool，并验证 trail timer 保留；实际 `ImpactEffects.clear` 不改 clock/trail timer 由本次源码检查确认，不能说该 public clear 全部行为都已由 fixture 执行。
- 原 ph（L58759）还支持 Three Color 和 CSS/string color；当前 Native 支持默认、数字和数组/Vector3/Color，但不支持字符串。现有默认玩家色及猎犬数值色路径通过，不代表 ph 的全部输入域已完成。

## 武器 smoke 状态和旧 root

[weapon.gd](../scripts/weapon.gd) 把新 smoke 请求放在 quiet/bloom 衰减后、heat 衰减前，与原 O 的 L79694–79714 一致。只有 rifle 的 smoke 配置满足严格时间窗口及 heat>.4 才初始化；已有 smoke 无论当前枪种继续递减。smoke 和 tick 先减 dt，再决定是否发出请求，因此跨过零的那一帧仍可能发最后一团烟；没有接收端时不重置 tick。

Main 的接收函数在 Weapon.update 内同步读取 muzzle，后面才执行 `step_root` 和 animation 提交，因此使用旧 root，符合原 S(A) 的位置。删除旧 smoke_remaining helper 后，正常路径只剩这一个请求入口。生命周期 equip/reset 清 smoke/heat 而保留 smokeTick；此行为也与此前已审的原选择性 reset 相容。

[weapon_smoke_reference.cjs](../tools/weapon_smoke_reference.cjs) 直接提取上述原 O 片段，通过实际 Native Weapon.update 比较四个数值状态、请求数量和五个参数。[当前报告](../evidence/weapon-smoke-verification.json) 为 58 步、9 次请求、335 checks，最大误差 `2.88657986402541e-15`，门槛 1e-11，零失败。本次禁写重放与 fixture 逐字节相同：SHA-256 `2e325935943822e691db44f07dac88283412e2b58beef41f7b7795fa49f2b92e`；原片段 SHA-256 `1cfcac3ce6eefa6140c6b513b28d35da9f192b5130f1c90c1ac1d02e510103c8`。

时间差 .11/.125 的严格排除、窗口内值、heat .4/.400001、tick 恰为零、无接收端后恢复以及 smoke 减成负数后最后一次请求均实际命中。当前 pistol 样本证明继续已有 smoke，没有在启动窗口内单独验证禁止初始化；1.6 上限尚未命中。reset 的参考由 wrapper 按原语义提供清零赋值，不是本 fixture 字面执行 T。muzzle 更新和 smoke 接收器是替身，故这 335 项不证明 muzzle 坐标或通用原 I 粒子的内容。

通用 `ImpactEffects.smoke` 仍需单独原 I/M/u1 对照：原 size/life/count/alpha 使用 `||`，显式零也回退；当前 get 默认语义不同。Native offset/velocity 还使用 Vector3 中间运算，未证明最后写入 Float32 前的精度相同。武器本次传入的这些参数均非零，不能把该潜在通用差异算作已失败的武器状态路径，也不能用状态通过抹掉它。

## 实际 Main / GPU 接入

[verify_tracer_chain_runtime.gd](../tools/verify_tracer_chain_runtime.gd) 在实际 Main 用受控姿态和连续 rifle burst 检查本轮链路。[最终报告](../evidence/tracer-chain-runtime.json) 为 480 帧、87 checks，零失败：本次观测到 13 发，每发检查同步 combat impact callback 发生在本发 tracer/shell 之前，且两者各增加一次。12 次 trail 标记证明时间门槛通过，没有直接断言烟迹粒子增量；frame 96/102/108/114/120/126 共观测到 6 次 hot smoke，逐次检查请求时 root transform 仍等于帧前值，回调后本帧 heat 恰减 dt×.2。这里没有把 muzzle 世界坐标与原作配对，也未比较完整 heat 轨迹。13/12/6 是观测数量，收尾的存在性断言并未固定这些数量；87 项可分解为 13×5+6×3+4。

第 480 帧 additive/lit/tracer 均为 0，证明这批粒子和 tracer 自然结束，不是显式 clear()/资源释放测试。[最终 480 帧日志](../evidence/tracer-chain-runtime.log) 没有 ERROR/泄漏信息；此探针证明真实接入和所断言的先后次序，不是原作整帧 tape 重放，也没有逐像素配对。较早的 [470 帧报告](../evidence/tracer-chain-arms-runtime.json) 和 [日志](../evidence/tracer-chain-arms-runtime.log) 为 11 个共享对象身份、385 FX calls，早于最后的 lit/add 顺序改动，只作该阶段 arms/机械/弹匣与共享服务接入回归，不能替代最终 480 帧证据。最终 [780 帧流程报告](../evidence/tracer-chain-flow.json) 和 [日志](../evidence/tracer-chain-flow.log) 记录 pause_frozen=true、最终 playing、两次 retry，三个 reset 采样的 particles/shells/emitters/decals 均为 0，日志无 ERROR；这是 Native 流程回归，不是原作暂停/重试联合数值轨迹对照。

## 本阶段结论边界

这次能支持的是：原 F/Yg 算法及受控共享 tape 消费通过，Main 的实际玩家/猎犬调用点和同步命中顺序已按原源码调整，原 Weapon smoke 状态块进入生产。现有 Q 的 96 发/2,424 项回归证明此前选定的武器参数路径仍成立；Q 参考中的 FX 接收器仍是替身，不能与本轮 F 报告相加便声称完整 Q+FX 联合消费已证明。

原 96 发 Q、smolder、A+真实 decal 回归已通过，支持本轮改动没有破坏这些已有受控路径。完整事件总线、AI/命中副作用、shell/decal/烟/爆炸物对同一 Math.random 流的全局交错、暂停/重试的原作联合数值轨迹以及完整画面仍是独立边界。原 ph 字符串和通用 I 默认值/粒子精度缺口继续保留；本轮没有把它们标成已完成。
