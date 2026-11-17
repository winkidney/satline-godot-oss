# 武器与手臂死亡掉落接线审查

本轮只读审查 [DropView](../scripts/weapon_drop_view.gd)、[DropMotion](../scripts/weapon_drop_motion.gd)、Main / Animation / Session / cancel_reload 及 vS drop 部分；仅本文件由顾问写入。当前未发现正常死亡掉落路径的阻断问题。结论包含武器世界层适配与手臂下落，不包含公开 attach 流程或完整原场景逐帧画面对照。

## 死亡入口和推进顺序

[原 bundle](../../artifact-rendering-study/source/extracted/bundle-1.js) 79611 在 player/input 存在、进入 O 时已经 dead 且未暂停的情况下执行 `oe → le → xe`，随后清 prevFire、隐藏 flash 并返回。若 Q 回调在本次 O 中途造成死亡，原函数没有重查 alive，仍会完成该次 D/正常 arms；下次 O 才进入 drop。

Main._advance_weapon 保存进入时的 `was_alive`：已经 dead 时先 DropView.advance，再让 Weapon.update 走 dead 早退；进入时 alive 的帧仍执行一次 D/arms。这个顺序符合原分支，不应在 Q 回调内直接重挂世界节点并提前启动 drop。暂停由 game_flow 阻止 game tick；单独 render/Animation 不推进 motion 或 arm drop 时间。

DropView.start 的 cancel_reload、停止 switch、清 pending、隐藏 flash 和 arm start 均发生在武器随机速度初始化前。cancel_reload 使用 reload context 的 weapon，恢复对应机械/弹匣/手部目标并发起 `.22` blend；随即 startDrop 捕获已输出的手臂历史，与原 I()/p.startDrop 的关系一致。它不额外推进 reload，也不把未到达的 magin 当作已经提交弹药。

原武器 numeric stage 每次使用原 dt，再按 `ceil(dt/.012)` 分子步；手臂 dropUpdate 每个死亡 tick 一次，先于武器子步。落地后 xe 的 rest settle 仍在同一 tick 运行。当前实现没有在 render 回调中再积分，武器沉水后也继续推进手臂直至其隐藏。

## 世界空间、层级和恢复

原 oe 79449–79491 使用 `tan(mainFov/2)/tan(viewFov/2)`，只将枪根局部 z 除以该比值，再应用 camera rotation/position。当前保留此做法，没有误用 muzzle 的 x/y 缩放公式。根的世界方向为 camera quaternion × 原局部 quaternion；随后移到 source_scene 世界父节点并写 global transform。

所有枪械 GeometryInstance 从 weapon bit 2 改为 world bit 1，cast shadow 开启，flash 保持不投影并隐藏。Animation 在 drop active 时跳过枪根与枪子节点的旧 clip 写入；机械/弹匣的专属 View 仍写取消后的当前状态，不积分新射击或换弹。手臂保持原 camera 父空间下落，和世界中的枪械分离，原本也是如此。

Session.reset 在 Weapon.reset 之前调用 DropView.restore：恢复实际原 parent、单位 scale、原 layers/cast_shadow、原 shader 对象与 material mode，然后 restore 手臂并结束 drop。这里不保存再恢复死亡前局部枪根 pose；原 j() 同样把当前 root 加回 camera、清 scale/visible，下一正常 D 决定新根姿态。不能把缺少“死亡前 pose 回滚”误判为遗漏。

vS.restore 只把 drop_time 设为 -1、progress 设为 1、initialized 设为 false，并恢复 group visibility；不重建 Fh spring/history。Weapon.reset 随后执行已有正常 reset/snap。代码没有引入新的反向 owner 引用；DropView 通过共享 random Callable 使用原 Weapon RNG。

## Shader 与光照服务

适配保留同一个 ShaderMaterial，只把其 shader 从 `saltline_bias_weapon_3` 变体换为 `saltline_bias_world_3`，其余源码不变；restore 返回原 Shader resource identity。这样 D24 原 polygon offset 在世界 depth range 下使用对应单位，不使用片元 DEPTH epsilon。

已核对当前 source 的受影响材质：`weapon_markings`，原 factor/units 为 `-3/-3`，仅由 rifle/pistol 的三个枪械节点使用，源 layer mask 为 2，无 world 或 arm 用户。它确实在两枪间共享，但当前单 active drop 下另一枪隐藏，恢复发生在再次使用前。因此本轮原地切 shader 安全；这个结论不推广到同时展示两个不同 depth-range 实例的未来场景。

ShaderMaterial 对象、uniform 名称、source_material_id 和外部服务绑定保持不变；变体复制 `source_shader_path`，使 sun/IBL/local 服务仍识别原材质种类。本地固定引擎的 [ShaderMaterial::set_shader](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/resources/material.cpp#L387) 不清空 param_cache，支持该保留 uniform 的方式。当前代码恢复 material 的原 `source_polygon_offset_mode`，并恢复原 shader 自带的 metadata；没有用新材质替代原对象导致湿度服务继续更新旧对象。

source_sun / source_local / source_ibl 每次 render 动态遍历实际层级。drop 后 IBL viewmodel instance flag 应变为 false，local camera mask 由实际 world camera 决定；retry 后重新识别 weapon 层。sun shadow 的 sync_casters 动态加入和移除符合 world layer、cast_shadow 条件的枪械 proxy，flash 排除。现有 shadow 更新节拍仍沿用原项目实现，本轮不将其扩大为每像素无延迟阴影证明。

## RNG 与数值证据

两份 fixture 经顾问拦截写入后独立重算，均逐字节一致。参考中的 RNG 还与原 literal su(4207) 连续比较 1000 次，误差 0；这验证算法，不表示 legacy seed4207 已与原完整启动 fork/消费次数对齐。

[武器数值报告](../evidence/weapon-drop-verification.json)：1140 步 / 36169 检查，0 failures，最大误差 `2.22044604925031e-15`，门槛 `1e-10`。对照原 oe/le/xe/j，包含 physics/splash 参数与 RNG state/count；arm dropUpdate receiver 在此参考中 mock，因此它不单独证明手臂轨迹或 Main 入口。

[手臂 drop 报告](../evidence/weapon-arm-drop-verification.json)：180 步 / 13500 检查，0 failures，最大误差 `2.69412797404556e-7`，门槛 `2e-6`。原 vS startDrop/dropUpdate/restore、真实 relaxed pose 与 Three 数学保留；Fh mock 记录 solver 输入。它覆盖两轮 drop/restore、零/大 dt、隐藏和 RNG，不等于手臂 Fh 骨骼联合轨迹的原函数重放。

每次启动共 11 draws：arms 6 次，再武器 5 次。flat/wall 参考每轮三个 bounce 依次耗 `3/3/2` 次；最后一次进入 rest，不再抽角速度。沉水当帧仍继续剩余子步，导致 fixture 中四次 splash，此处保留原行为。Euler order 也不在 start 重置：原共享 te 第一次 rest 后变为 YXZ，之后的新 drop 继续使用；当前跨轮实现与原一致。

静音实现按“音频服务可调用且不抛异常”的原路径消费两个 bounce pitch RNG，再省略声音输出。原 ee 在 audio/play 缺失时不消费，在第一次 play 抛异常时只消费一次；当前 fixture 与 native 不仿真这两种失败条件，不能宣称所有音频缺失/异常路径等价。

当前武器数值序列均在第三次 bounce 进入 rest，未定向验证低速 `<1.1` 的首/次跳提前停止；手臂样本均先因 y `<-.6` 隐藏，未单独命中 `.9s` 超时分支。代码条件已对照原文，但这些独立分支不列为 fixture 实测覆盖。

## 实际运行证据及范围

[最终 runtime](../evidence/weapon-drop-runtime.json) 为 400 帧、两枪各一次死亡/retry、starts=2、restores=2、281 个逐帧门控计数，failures 为空。281 是 active-drop 帧与两个恢复检查点的计数，不是全部属性或标量比较数量。覆盖实际世界 reparent、掉落层、非空 bias 迁移、shader identity 及 bias metadata 恢复、原 layers/cast_shadow 逐项恢复、手臂隐藏/恢复，以及重复 Animation.update 不推进 drop。帧 100/310 明确要求 resting 且两臂已隐藏，两枪实际均三次 bounce 后 rest。

第一轮在帧 20 的真实 weapon.fired 回调中 damage 致死；probe 断言该 tick D 恰好推进一次，快照记录此时 drop 尚未 active，帧 21 才启动。第二轮帧 230 在 tick 前致死，同 tick 启动 drop。这样两条死亡入口均已有运行时证据，不再只凭代码判断同帧顺序。

最终 probe 还逐掉落节点检查 flash 除外的投影 flag，并按 node instance_id 确认已登记到 source sun caster bindings；按现有半频 shadow 更新节拍，启动后的前两帧不要求登记完成。该断言证明 caster 接入，不扩大为阴影图像或同帧无延迟证明。`/tmp/saltline-drop-runtime.log` 未检出 ERROR 或泄漏记录。

首轮 [harness 失败报告](../evidence/weapon-drop-runtime-initial-harness-failure.json) 已保留。其 flow_preview 未关闭，使手动 game tick 之外又进入自动 preview 推进/重置；修正工具后重跑通过，没有为掩盖该失败修改生产掉落公式。

retry 在 restore 前捕获 view.saved，再逐项比较恢复后的 layers/cast_shadow；另保存全 scene ShaderMaterial 的 shader identity 和 bias metadata，恢复后逐项核验。uniform 连续值仍由同材质对象、同 uniform 定义及引擎 set_shader 行为支持，本 probe 没有增加逐 uniform 数值轨迹对照。

fixture SHA-256：武器 `b63b179345dac6d0a6d86a11bb6ad2c1cbc76c78fa5ff8362cd57c7740ff1ca2`；手臂 `b56a2d8862756ce4cf740d4fb3a6c9efbc45e91cd11f5c854971384896579bf9`。原 source SHA-256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

本轮可确认正常 death drop 已接入实际世界及手臂路径。公开 attach、音频实播、异常音频分支、原完整启动 RNG、整条原 O 与 native 的同输入联合轨迹以及原图像对照不由这些证据完成。
