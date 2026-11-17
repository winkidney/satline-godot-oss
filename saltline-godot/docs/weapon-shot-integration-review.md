# 武器射击生产接入审查

本次只读核对 Weapon、Main._weapon_fired、WeaponEffects、RootMotion 的共享状态/随机流，以及原 Q、参考生成器和 CPU/GPU 探针。当前选定射击参数、原 recoil、相机反馈与 flash 已进入生产，未发现阻止交付本阶段的随机数消费、共享状态或重复反馈缺陷。仍有明确的完整 Q 时序与状态边界，不能据此宣称全局随机序列、完整 Q/O、实时根或 IK 已等价。

本审查只新增本文。测试由主线运行，本次核对当前文件与报告，没有重新运行 GPU。

## 共享 S 与随机流

[weapon.gd](../scripts/weapon.gd) 创建一份 motion_state，再用 `RootMotion.new(motion_state, motion_rng.randf, true)` 将其直接交给 root_motion。share_state=true 时不深复制，reload、lifecycle、controls 和 recoil 都修改同一 Dictionary；原有独立 RootMotion 测试仍默认深复制，不改变其接口语义。

生产的 `motion_randf()` 统一经过 root_motion.random，因此随机消费计数包含 spread、shell velocity、recoil 和 flash。root_motion 持有的是 SourceRng 的 Callable，不是回指 Weapon 的 Callable，不形成 Weapon↔RootMotion 强引用环。reset 不重新创建 RNG，符合原 T 不重建武器随机闭包的行为。

原 bundle L79073 把 `S:a` 和 `rng:r` 同时传给两枪；Q 与两枪 recoil 共用流有直接源码依据。当前普通生产路径具有 shell 和 camera recoil 回调，其每发消费为：

| 阶段 | Rifle | Pistol |
| --- | ---: | ---: |
| spread 的角度/半径 | 2 | 2 |
| shell 初速度 xyz | 3 | 3 |
| 原枪 recoil | 7 | 6 |
| flash duration/seed/jet/roll/size/z scale | 6 | 6 |
| 合计 | 18 | 17 |

这是当前这些功能都存在时的计数，不是所有可选回调组合的固定常数。原 Q 缺少 fx.shell 时不消费其三个随机数，原 recoil 缺少 addRecoil 时也有不同消费路径；本轮正常生产两者均存在。

quiet 保留原条件 `time-last_shot > .24 && burst > 0`，只消费一次 `r()*6.28`，随后 burst=0。常数是原文 6.28，未替换为 TAU。CPU 轨迹实测 rifle 总计 `432→433→433`，pistol `408→409→409`，第二个 quiet update 不再消费。

SourceRng 使用原 su 算法，但当前显式 seed=4207 仍是 legacy 入口。原启动 fork、此前初始化消费和全局 RNG 分配尚未对齐；对照两端共同用 4207 只能证明给定同一初态时的算法与消费，不证明原 HTML 开局会得到相同随机结果。shell 自身旋转/弹跳等其他 FX 子系统的随机流也不属于这张武器参数消费表。

## 生产顺序与反馈

[Main](../scripts/main.gd) 仍在 Weapon.update 发出 fired 时同步执行 `_weapon_fired`，之后才调用 weapon_animation.update。射线来自 player.eye；muzzle/eject 使用当时的 root.transform，按主/武器 FOV 的 tan 比缩放 xy，再转到相机世界坐标，与原 `w/S`（L79275–79289）的计算结构相同。

当前主要阶段为：spread → combat → tracer → shell → muzzle light → enemy fire alert → 原 apply_recoil → flash。原 Q（L79379–79433）也在射线、tracer、shell、light 和 weapon:fire 之后调用 recoil，再生成 flash。native 的 explosives/decals/impact 等既有路径仍插在各自位置，本轮未对照完整原命中副作用或全事件总线。

Main 中旧手写 camera recoil 已删除。apply_recoil 只调用一次原 RootMotion.recoil，后者分别调用 Player.add_recoil 和 Player.add_shake。camera_scale 按原 ADS/crouch 处理；枪根冲量使用自身 adsPos/adsRot/adsBack 和 crouch 系数，未把 camera_scale 再乘入所有根冲量。

light 先由 flash_light 发出，后续 `WeaponEffects.fire(..., false)` 只更新 flash，避免再发第二盏 light。effects.fire 继续保留默认 emit_light=true 给独立 preview 使用；不能把默认调用再叠加到正常 fired 回调。

审查发现初版 bloom 在整个 fired/Main 回调返回后才更新，晚于原 Q 的 recoil→bloom→flash 顺序。主线已将其移到 apply_recoil 末尾，并用单调 shot_count 的 `_apply_shot_bloom` guard 保证每发只更新一次；`_shoot` 在 emit 返回后调用同一 guard，仅为没有 recoil 接收者的 Weapon-only 客户端补执行。正常 Main 现在先 recoil、再 bloom、最后 flash，CPU 也新增每发 bloom 对照。shot_count 在 reset/equip 中不回退，因此不会因同一编号重用而跳过下一发。

## 参考独立性与 CPU 证据

[weapon_shot_reference.cjs](../tools/weapon_shot_reference.cjs) 直接提取完整 Q、原 su（L34783–34801）、原 `w/S`、数学 helpers 和两枪 recoil（L77017–77040、L78679–78697）。生成器没有引用 native 计算结果；独立内存重放生成内容与现有 fixture 一致。

源 bundle SHA256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，Q 原文 SHA256 为 `ec64c6c1e07939e96d26c1cd725342a29a656f6eb4efdefefed796d570af00ac`。

[verify_weapon_shot.gd](../tools/verify_weapon_shot.gd) 实际调用 Weapon._shoot，经过 fired 后调用生产 sample_spread、sample_shell_velocity、apply_recoil 和 Effects.fire，比较 direction、shell velocity、camera/shake 回调数组、六路根速度、flash 参数、bloom、burst 和累计 random_calls。

[CPU 报告](../evidence/weapon-shot-verification.json) 为两枪各 24 发，共 48 发、1,212 项比较，最大绝对误差 `1.16974115282886e-7`，零失败。Vector3 类通道 direction/shell/flash.scale 门槛为 2e-6；其余标量为 1e-11，均拒绝非有限值。总最大误差不能拿来替代标量门槛，随机计数或 recoil 标量不会因 Vector3 容差而获放宽。

burst 1..24 实际覆盖 rifle 的 first/second、burst<4 和 burst<=9 两侧；ADS 0/.4/1 与 crouch 两种状态均组合出现。camera/shake 的数组长度和值一起比较，能检测这些被测方法重复调用反馈。

“完整 Q”指参考执行的原文范围，不代表所有行为都有验收：

- camera/root 为 identity，player velocity 为零，combat 返回无命中；不覆盖真实世界 origin/muzzle/eject 变换和命中结果。
- 初始 ammo=1000，rig.shot 是空替身；未验证最后一发、锁定枪栓/套筒、机械动画或 arm shot 冲量。
- ammo、heat、lastShot 等 Q 写入未列入本轮输出；flashT/flashDur 也由 native Effects 自有状态承接，未证明整份 S 相等。新增 bloom 对照限于这组射击调用，没有证明完整 O 中每帧衰减时的全部 S 同步。
- reference 记录了 order，但 native 验证器主动删除它。因此 combat→tracer→shell→light→fire-event 的完整顺序目前来自源码审查，不能说已经由 1,212 项数值比较证明。若以后加入字符串 trace 比较，须同时增加 String 的精确比较分支，不能沿用当前纯数值 comparator。

## 实际 Main / GPU 探针

[verify_weapon_shot_runtime.gd](../tools/verify_weapon_shot_runtime.gd) 加载真实 Main，仅把 fired 接收点换成记录 wrapper，内部仍调用实际 `_weapon_fired`。旧 root 的 before/after 变换、随机消费、flash/light 发出数在每次调用外围采集。

当前 [weapon-shot-runtime.json](../evidence/weapon-shot-runtime.json) 为 220 帧，9 发 rifle 和 3 发 pistol；两枪分别每发 18/17 draws，flash/light 均各一次，所有 old_root_unchanged 为 true，零失败。最终探针还断言 Main 回调内部 bloom 已按本发 shot 增加一次，在 `_shoot` 返回后的 fallback 之前已完成。早先探针重复 tick、只跑到 rifle 的失败留存在 [initial 报告](../evidence/weapon-shot-runtime-initial.json)；修正 wrapper 的 flow_preview 后重新采集，最终结论以当前双枪报告为准。

这个探针证明实际 Main 路径消费和单次 FX 接通，并且 shot 回调不直接改枪根。它没有把 muzzle/eject 的世界坐标与原 Three 逐项比较；camera_recoil/root_impulse 只是记录而未做断言。单凭该报告不能排除额外、不消费随机数的遗留冲量；本次另通过源码调用点检查确认旧手写反馈已移除、正常生产只有一次 apply_recoil。

## 后续仍须完成的边界

RootMotion 现在参与 recoil 和随机流，但 D.step 仍没有在生产积分或写 root。根和机械子节点继续采样，注入的根速度尚不会按原弹簧逐帧衰减；不能把这些累计值当作已对齐的实时根姿态，或未经状态同步直接热切 D。

motion_state 也仍是部分同步状态：本轮读写需要的 recoil/ADS/recPhase 已连接，旧 Weapon 的其他标量和 Effects flash 状态尚未统一到完整 S。quiet 清的是旧 burst 字段，射击时再同步 S.burst；不能因此声称任意帧整份 S 都与原 O 一致。下一阶段仍需统一 O/D 的状态归属、时钟、全部随机消费与根唯一写入者。

原 `weapon:fire` payload/消费者不等于 native 当前三个参数的 fired 信号及直接 enemy alert，原 shot/parts/arms、完整命中副作用和启动 RNG fork 都须独立迁移验收。本阶段可以交付为“给定同一随机初态，原射击参数、recoil 与 flash 计算进入真实生产路径并通过独立对照”，不扩大为完整原作射击画面或全局随机轨迹已一致。
