# 实时画质设置接入

## 原版合同

原 bundle `jr` 五组预设第 34660 行附近、`UM` 第 34728 行、post applyQuality 的 `le` 第 36322 行、render.setQuality/resize 第 37090 行、planar 第 56200 行、rain 第 56703 行。

| 档位 | scale | MSAA | 阴影 | AO taps | 体积光 steps | planar | motion |
| --- | --- | --- | --- | --- | --- | --- | --- |
| test | 1 | 0 | 1024 | 8 | 10 | .5 | off |
| low | .7 | 0 | 2048 | 8 / off | 12 | 0 | off |
| medium | .85 | 2 | 2048 | 12 | 16 | .5 | off |
| high | 1 | 4 | 4096 | 12 | 24 | .5 | on |
| ultra | 1 | 4 | 4096 | 16 | 40 | 1 | on |

原版运行时 setQuality 会切换上述渲染参数，不会重新执行已经生成的材质贴图与雨种子资产。tex/rain 的预设字段被保留，但本轮运行时不因此伪造纹理重生成或粒子数量变化。

## Godot 实现

- `render_quality.gd` 保留五档原参数和原 resize 的像素上限公式。设置页提供 low/medium/high/ultra，持久化 quality，auto 当前对应桌面 high。
- PostPipeline 按物理窗口尺寸与 scale 调整世界、武器、深度、AO/体积光、bloom、motion 与 LDR 通道。修正原匿名窗口回调会把武器 viewport 改回全尺寸的问题。
- 世界和武器 MSAA 同时变化；已有 DepthSamplesBridge 按真实 sample count 重建。低档关闭 AO 合成并停止三个 AO viewport 更新。
- 用独立 Shader 变体替换原循环常数，AO 8/12/16，体积光 10/12/16/24/40；high 默认继续使用原 shader 资源。切换时重置 motion history。
- 阴影调整 viewport 与 depth bridge，重新绑定 source sun 材质的贴图尺寸。反射使用当前实际内部渲染尺寸，再执行原网格对齐与 quality.planar 比例。
- 雨线像素宽度改用内部渲染高度。原版 paused 停止 rain.update，因此暂停中切换画质时仍保留旧 uPix，恢复后更新；没有强行改变该原版行为。

## 验证

`quality_reference.cjs` 直接执行原 jr 和 render.resize，覆盖五档、六种窗口尺寸、四种 DPR、两种 DRS 输入，共 240 种尺寸。`verify_quality.gd` 295 项通过。该纯函数允许 DPR/DRS 参数，不意味着已经接入运行时动态控制器。

`verify_quality_runtime.gd` 通过实际设置按钮切换 low→medium→ultra→high，再恢复运行、切 medium 并把物理窗口改为 960×540。检查真实 world/weapon 深度样本数、深度就绪、阴影尺寸、AO/motion、反射开关、实际绑定 shader 的采样常数及雨像素宽度。当前 460 帧通过记录见 `evidence/quality-runtime.json`。

1280×720 时 low=896×504、medium=1088×612、high/ultra=1280×720。反射 medium=544×304、high=640×360、ultra=1280×720。物理 960×540 的 medium 内部为 816×459、反射 416×232。原 Godot canvas_items UI 在该缩放下仍使用 1280×720 逻辑坐标，已区分逻辑 HUD 尺寸与物理渲染尺寸。

## 限制和失败记录

本阶段原先未接入的 DRS 控制器已在后续接入，见 [source-dynamic-resolution.md](source-dynamic-resolution.md)。仍未完成设备自动档位选择、启动时 CLI q=low/ultra 对纹理与雨种子资产的重新烘焙、移动 DPR/安全区、所有预设的逐像素成像与实时性能验收。只有已导出的 high 资产集。设置面板仍有布局/按钮/滚动细节待复刻。window canvas_items 的逻辑 UI 缩放与原 CSS 响应式还不完全相同，不能把物理渲染尺寸对照扩大为全 UI 等价。

首次扩展测试错误地要求暂停时 rain pixel width 立即变化；源码核对显示原版暂停时本就不更新雨参数。保留 failure JSON 后改为恢复运行时检查，暂停样本仍记录旧值。窗口缩放检查同时发现逻辑 visible_rect 与物理 Window.size 不同，改用实际 Window.size 计算渲染尺寸，避免缩小窗口却仍渲染旧尺寸。

最终 AO-off 停止通道更新后的 460 帧切换/缩放验证通过；日志无错误/告警。同期默认高画质 780 帧流程通过，暂停冻结、三次重置，结束于 playing，`evidence/quality-flow.json/.log`。质量截图 low/high/ultra 为 1280×720 设置页，中档最后一次截图来自物理 960×540。

## Astra 审查后的首帧修正

审查发现并修正：

- 普通窗口 resize 也清除 motion history，匹配原 xe() 的 ee=false。高档改变宽高比为 1200×800，首次 tick uShutter=0，后续恢复 .315789。
- auto 当前仍解释为 high，但冷启动也统一走 apply，避免非默认物理窗口或像素上限未初始化。通过真正 --resolution 960x540 的独立自动档启动验证，40 帧时世界与武器尺寸均 960×540。此项是稳定启动尺寸验证，不是首个呈现帧的附件/像素对照。首次尝试在 SceneTree._initialize 写 Window.size 被启动流程覆盖，失败日志另存，不混作生产初始化证据。
- set_resolution 不再额外执行一次 sun.update，而设置 force_pending 由正常帧消费，避免紧接着的半频更新取消 UPDATE_ONCE。
- 从已有有效阴影图派生 resize_pending，在新的对应尺寸 compositor copy 提交就绪之前保留 warm 太阳辐射开关；太阳通道在 world 前执行。SolarDepthBridge 用 mutex 保护 completed_size，is_ready_for(size) 防止把旧尺寸 callback 当成新尺寸完成。未使用未完成的新尺寸 ready 标记冒充 GPU 像素证明。

测试覆盖阴影调度 tick 44/194/409/454，含同帧 low→ultra→low→high 快速切换；断言真实非空材质集合、source_sun_ready 与 shadow_size、强制请求被消费且最终 UPDATE_ONCE，以及后续对应尺寸 compositor callback 就绪。它证明调度与门控，不证明首个呈现帧已经采样到哪些 shadow texel。

保留限制：反射发生在 sun 前，换尺寸时其“上一帧阴影”可能是新图初始化值；combined/half 深度重建的保守 ready 门控会使 AO/体积光短暂关闭，反射 capture 重建也可能使 uReflOn 暂为0。这些首帧成像连续性仍未逐像素对照，本轮 warm-ready 修复不能扩大为全部后处理/反射无跳变。

Astra 修复后的最终归档：quality-runtime 460 帧通过，四次阴影切换各检查 138 个实际材质的 ready 与对应尺寸，奇偶调度均覆盖；quick-switch 和 resize shutter 均通过。cold auto 40 帧通过；最终默认高档 780 帧流程通过，paused 冻结、三次 reset、最终 playing，三个日志均无错误/告警。
