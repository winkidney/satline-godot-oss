# 实时画质接入审查

本轮审查 [render_quality.gd](../scripts/render_quality.gd)、PostPipeline、planar reflection、sun shadow、Main/UI 接线及原作质量代码。范围是现有 high 资产集上的运行时画质切换、尺寸和采样数变化、相关缓存与更新顺序；不扩展到未实现的 DRS、设备自动识别或移动端。

审查发现并向主线反馈了窗口 resize 的 motion history、auto 冷启动尺寸路径、阴影强制重绘被半频覆盖、换阴影图时太阳直接光被 ready 位关闭四个问题。当前代码已作局部修复，并补齐下述即时调度/状态、冷启动尺寸及最终流程证据；在本阶段范围内未发现剩余阻断问题。本次仅写本文，没有修改生产代码、引擎或重新运行 GPU。

## 原版合同与独立参考

原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js)：jr/UM 在 L34660/L34728 附近，post applyQuality/resize 在 L36322 起，render.setQuality/resize 在 L37090 起，planar 在 L56200 附近，rain 构造在 L56615 起。源 SHA-256 为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

[quality_reference.cjs](../tools/quality_reference.cjs) 直接提取五组原 jr 和原 render.resize，固定执行 HDR 分支，Native 不参与生成期望值。本次独立禁写重放与 [fixture](../assets/export/fixtures/quality-reference.json) 逐字节一致：SHA-256 `4f85b6dab86bb03c3f47fb8a769d905ba853e31765a21dc9858a7b79313db0a5`；提取方法 SHA-256 `cf8c96e91ef958b12d000d1c97486417f7a9b75fd143429a4fc2f9cf34813d02`。

[295 项报告](../evidence/quality-verification.json) 对应五档 55 个字段和 240 个尺寸案例，零失败。实际有 111 次像素上限缩放、4 个坐标恰好经过 `.5` 取整；没有触发最小尺寸 16。当前正数域的 `floor(x+.5)` 与原 Math.round 一致。四个可见档的参数未发现抄写错误，隐藏 test 档也纳入纯函数对照。

该证据不包含 UM 自动选择、非 HDR 分支、零 DPR 或窗口回退输入。原 `devicePixelRatio || 1` 在 DPR=0 时回退 1，而 Native 纯函数直接接受 0；运行入口固定 DPR=1，不受这个未移植输入域影响。函数允许 DRS 参数不等于已接入原动态控制器。

## 尺寸、采样与材质缓存

[PostPipeline](../scripts/post_pipeline.gd) 统一从物理 Window.size 算内部尺寸，再同步 world/weapon/scene、combined/half depth、AO/volume、motion、六级 down、五级 up、streak 与 LDR。第一级 half 使用 ceil，后续 down 使用右移，匹配原 post resize。最终 post 的 texel/aspect、AO/volume 的 resolution/blur direction 也随尺寸刷新；history/adapt 保持原有小尺寸反馈图，不因画质变化重置曝光历史。

Main 的旧匿名 size_changed 回调现使用同一 render_size，避免后触发的回调把 weapon viewport 改回全窗口。世界和武器一起切换 0/2/4 MSAA；DepthSamplesBridge 从真实附件格式读取 sample count 并重建数组，CombinedDepthBridge 要求两路尺寸和 sample count 一致，默认 selected sample 0 对无 MSAA 和这两种 MSAA 都有效。原/NVIDIA 的跨 API 样本位置边界仍沿用此前 MSAA 结论，本轮没有重新证明边缘像素等价。

AO-off 同时关闭合成贡献和三个 AO viewport 更新；half depth 继续供 volume 等消费者使用，不应一并停掉。AO 8/12/16、volume 10/12/16/24/40 使用有限数量的 Shader 变体缓存；目前字符串替换同时命中循环次数及对应分母，没有留下固定 12/24 的归一化项。Godot 当前 [ShaderMaterial::set_shader](../engine/.build/godot-ed1daf0bf/scene/resources/material.cpp) L387 仅切换 shader，不清 param_cache，因此此处同名 uniform 的既有纹理/参数绑定不会仅因变体替换而全部丢失。此判断针对当前同接口 shader，不能推广到更改 uniform 类型的任意替换。

反射从实际内部 render_size 乘 quality.planar，按原 16×8 网格取整并更新 uReflLod。low 关闭 viewport 更新和 uReflOn，保留资源供恢复；重新启用或改变尺寸后仍经原 HDR/mip capture 路径。反射先于 sun、sun 先于 world 的关系没有被画质重建改变。现有报告记录了反射尺寸，但运行时 verifier 只断言 active 开关，没有逐项断言尺寸、LOD、mip 内容或画面。

阴影相机的固定 frustum/matrix 与分辨率无关，不需要因 2048/4096 切换重新生成 caster 材质。接收面 PCSS 的 shadow-size uniform 则必须更新；render_quality 已清 source_sun_service 的弱引用绑定缓存并重新遍历绑定，新 Texture2DRD 继续使用同一输出对象。volume 同样持有该输出对象，矩阵保持不变。当前没有发现稳定状态下仍缓存旧 shadow-size 或旧输出对象的代码路径。

## 本轮发现与修复

1. **纯窗口 resize 未清 motion history。** 原 post resize 在 L36366 左右设 `ee=false`，下一帧不使用旧 VP 做 motion blur；Native 原先只在 set_quality 清 history。窗口改宽高比后可能把投影变化当作运动，造成首帧错误模糊。当前 `_resize` 也设 motion_has_history=false，覆盖纯窗口变化。较早 960×540 案例与 1280×720 同宽高比，且当时 medium 已关闭 motion，不能据它证明该修复。
2. **auto 启动跳过统一应用。** 初版 `_setup_game` 对 auto 不调用 apply，而初始 viewport 从逻辑 visible_rect 创建；物理窗口不同或需要 pixel cap 时，初态可能没有经过 render_size。当前统一执行 `apply(high if auto else saved)`，auto 仍明确映射桌面 high，没有假装完成原 UM 设备识别。
3. **强制 shadow 重绘会被同帧半频覆盖。** 初版 set_resolution 直接 update(true)，随后 Main 的普通 update 可能再次推进 frame 并设 UPDATE_DISABLED。当前 set_resolution 只设置 force_pending，由正常 update 消费一次，避免质量切换要求的重绘被取消。
4. **换 shadow 图时整段太阳直接光被关闭。** prepare_size 会清 depth.ready；原 source_sun_service 据此把 source_sun_ready 设 false，而 shader 用它门控整个太阳 BRDF。当前 resize_pending 只从先前有效图或已有 pending 继承，换图期间保留太阳 radiance，冷启动不会无条件伪造 ready；完成后用 `is_ready_for(viewport.size)` 清 pending。SolarDepthBridge 在提交新尺寸 copy 后，在 mutex 内一起记录 completed_size/ready，避免把旧尺寸完成当作本次完成。

上述 warm-ready 方案依赖已建立的 reflection→sun→world 顺序和强制重绘：新目标先清为 1，随后 sun pass 写入，再由 world 使用。reflection 位于 sun 之前，换尺寸首帧可能读取初始全亮阴影，不能把“太阳不熄灭”扩大为该帧反射阴影像素已与原作相同。当前改动也没有声称修复所有初次启动的 ready 门控延迟。

Post resize 仍会令 combined/half depth 的 ready 暂降，同 tick 的 uAoOn/uVolOn 可以暂为 0；反射尺寸变化时 capture.ready 暂降，同 tick 的 uReflOn 也可以为 0，待后续 process 恢复。这些是现有保守门控的过渡，不是已发现的持久旧资源错误；warm-ready 只解决直接太阳被关闭，不能据此宣称全部 post/planar 首个呈现帧无跳变。

修复后的 [最终 runtime 报告](../evidence/quality-runtime.json) 已补四次即时 transition：测试 frame 45/195/410/455 对应更新前 shadow tick 44/194/409/454，明确覆盖调度奇偶两侧。四次各有 138 个有效绑定材质，实际 source_sun_ready 为 true、source_sun_shadow_size 匹配新尺寸；更新后均保持 UPDATE_ONCE、force_pending=false、resize_pending=true。frame 455 还在同帧连续执行 low→ultra→low→high。随后等待 process_frame 并 force_draw，再检查对应尺寸 is_ready_for，均通过，关闭半频覆盖和太阳 radiance 暂降的验收缺口。

frame 435 在 high 将窗口改为非 16:9 的 1200×800，并显式触发 size_changed，确认 history 已清、首次 uShutter=0；frame 445 记录恢复为 `0.315789473684211`。这是 resize 回调和 shader uniform 的验证，不是 motion 输出像素比较；恢复断言在第十个后续 tick，并非逐帧证明恰在下一 tick 恢复。shadow ready trace 证明着色开关/更新计划及之后对应尺寸 copy 回调已经执行，不能等同首个呈现帧已消费新阴影的像素证明。

## 已有运行证据和范围

[quality-runtime.json](../evidence/quality-runtime.json) 的 460 帧经真实设置按钮走 low→medium→ultra→high，再恢复运行并在 medium 把物理窗口改为 960×540。记录并检查 world/weapon MSAA、内部尺寸一致、combined/half depth ready、shadow size、AO/motion 标志、绑定 shader 的循环常数和 planar 开关，failures 为空；[日志](../evidence/quality-runtime.log) 无 ERROR/WARNING。

1280×720 下 low=896×504、medium=1088×612、high/ultra=1280×720；物理 960×540 的 medium=816×459。该报告中的反射尺寸分别记录为 medium 544×304、high 640×360、ultra 1280×720，缩窗后 medium 416×232，但这些是观测值，不是 verifier 的独立尺寸断言。雨 pixel width 只在 playing 的 medium 快照直接核验；暂停四档快照保留旧值符合原 paused 不执行 rain.update。frame 410 恢复 high 后没有再次采样断言。

[quality-startup.json](../evidence/quality-startup.json) 和 [日志](../evidence/quality-startup.log) 使用真正的 `--resolution 960x540` 冷启动，在第 40 帧确认 auto→high，以及 world/weapon 的 SubViewport.size 均为 960×540，零失败。它不验证启动首帧、深度 ready、GPU 附件格式或设备自动档位选择；此前仅在工具初始化内赋 Window.size、随后被启动设置覆盖的尝试，不作为新的生产缺陷证据。

[quality-flow.json](../evidence/quality-flow.json) 和 [日志](../evidence/quality-flow.log) 已更新为全部生产修复后的最终 780 帧默认高档流程回归，pause_frozen=true、两次 retry、三次 reset，最终 playing。最终 runtime/startup/flow 三份日志均无 ERROR/WARNING。该流程不等于四档都执行过完整死亡/重试，也不证明原版逐事件状态或像素一致；本节引用的 460/40/780 帧归档均为本轮最终版本。

原 rain 的质量字段在构造时决定实例数，不是 setRain 强度：low/medium/high-ultra/test 分别为 rain 4760/7460/9260/3860（含 260 drips），splash 450/720/900/360。原 render.setQuality 本身不重建这些实例，因此当前 high 资产集的热切换保留实例数是合理范围；不同质量冷启动还改变 rain 子流消费和初始雷电 timer，不能只改 visible count 便宣称等价。tex 资产质量和原 low 冷启动 PCSS 10 taps（L36721–36723；high 初始化为 16）也不由本轮热切换证明。

本阶段可以交付为“原预设与内部尺寸算法接入现有渲染链，四档稳态资源、切换即时调度/状态、auto 启动尺寸和 Native 流程通过各自验证”。完整冷启动多质量资产、DRS/自动设备选择、移动 DPR、全部预设的逐像素成像与性能，以及逻辑 canvas UI 的完整响应式布局，均保留在 [阶段说明](source-quality-settings.md) 的未完成范围内。
