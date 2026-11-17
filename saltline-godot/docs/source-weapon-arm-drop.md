# 手臂死亡下落目标

`weapon_arm_blend.gd` 已增加原vS.startDrop/dropUpdate/restore，`weapon_arms.gd`提供start_drop/drop_step将变化目标送入现有Fh模型。当前已接入Main死亡路径，实机证据见source-weapon-drop-live.md。下文记录独立目标内核证据。

从上次正常求解历史复制手腕位置/旋转/手指姿态，两侧按原顺序共抽取6次随机数设置线速度和角速度。每步重力2.2，姿态在.15秒内按五次曲线放松到原di.relaxed；扳机归零，肩/pole保留历史，再调用Fh.solve/update。达到.9秒或手腕y低于-.6后隐藏该侧。隐藏侧跳过后续求解，restore恢复此前visible值并清除正常混合的initialized状态，Fh自身弹簧仍保留。

渲染器已支持按两侧group_visible写arm组可见性。正常更新在dropping时直接返回，不继续推进目标参与度。实际死亡触发、世界层适配与重试恢复接线已由weapon_drop_view.gd完成。

## 对照

`tools/weapon_arm_drop_reference.cjs`执行完整原vS和原Three数学，传入真实di.relaxed，Fh仅作为solver输入记录器。两轮正常初始化/掉落/隐藏/restore，dt含0和.08，比较目标p/q/pose/肩/pole/扳机/lean、两侧可见性、dropping及RNG状态和计数。`verify_weapon_arm_drop.gd`180步13500项max2.69413e-7，容限2e-6，失败0。结果 `evidence/weapon-arm-drop-verification.json`。该证明不包含下落后的Fh整链骨骼对照、生产触发或画面对齐。

## 渲染适配调查

掉落武器必须从武器层2进入世界层1，mesh开启投影，flash除外。现有source IBL/local lights每帧遍历可按层动态更新；sun_shadow_pass.sync_casters可发现进入世界层且开启cast_shadow的源mesh。硬件polygonOffset shader目前按加载时材质mask生成weapon3/60 variant，掉落时需要临时切到world3/3 variant，恢复后回到原variant；只改layers会留下错误偏移。scene.set_source_transform会同步代理和Skeleton，但世界枪根重挂不应影响相机中的手臂组。下一步适配需保存原父节点/layers/shadow/material覆盖，并在retry前恢复。
