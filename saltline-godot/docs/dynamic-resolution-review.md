# 动态分辨率接入审查

本轮只读审查原 R(G)、[dynamic_resolution.gd](../scripts/dynamic_resolution.gd)、[render_quality.gd](../scripts/render_quality.gd)、PostPipeline/Main/UI 接线及受控、墙钟两种运行探针。当前范围内未发现生产集成阻断：原控制器的数值行为进入实际 Main render 阶段，scale 变化和自动降档同步使用已接入的画质重建路径，手动画质与持久化偏好没有被自动调节混为一份状态。本次仅新增本文，没有修改生产代码或重跑 GPU。

## 原控制器与参考独立性

原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) L36848–36892 的 R(G)，入口为 L37137 附近 render.frame 的 `performance.now()` 差值；初始 S 在 L36839 附近，setQuality 在 L37090。源 SHA-256：`756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

[dynamic_resolution_reference.cjs](../tools/dynamic_resolution_reference.cjs) 字面提取原 R 与 jr，Q.resize/setQuality 和事件总线作为记录接收器；初始 S 由 wrapper 写出，经源码核对与原值一致。它没有读取 Native 算法结果。本次拦截写入独立重放，生成内容与 [fixture](../assets/export/fixtures/dynamic-resolution-reference.json) 逐字节一致：SHA-256 `5942af13f53001c41ee3e541d07c35ac76807e13b7b88714ecd6b8d9dde1c1c1`；R 原文 SHA-256 `c4bbea97f36cc41c8b8df6e83004e52ca9f1a2e3d19ffdb6b241d7f214b62d09`。

[最终纯函数报告](../evidence/dynamic-resolution-verification.json) 为 36 cases、7,494 个输入帧、44 个事件、82,340 checks，最大误差 `7.105427357601e-15`，零失败。其中 82,335 项属于原状态/事件比较，另外 5 项是 Native CLI 配置策略检查，不能全部称为原 R 的独立比较。数值门槛保持 1e-9；初审指出比较器缺少有限值检查后，主线已加入 `not is_finite(error)`。

逐式核对结果：

- disabled、无 post、单次超过 1500ms 时提前返回，不推进 settle/upWait。正常采样先减少这两个计时器；settle 尚未结束时清空统计窗口。
- 达到 45 个样本或累计 900ms 就计算均值。严格 `>21.5` 降 scale，`>30` 降 .2，`>45` 直接到 .6；严格 `<17.4` 才考虑上调。十等分取整发生在 floor 判断之前，当前合法正 scale 域与原 Math.round 一致。
- 满足 floor 条件的连续两次评估才降质量；降档设置 scale=.8、settle=2、upDelay=4，保留当时 upWait。Native 没有额外重置等待时间。
- 精确均值 17.4/21.5/26/30/45 均有定向输入。26 清零 floorHits、不降档，26.0001 在满足 floor 条件时降档；upDelay/upWait=60 的上限实际命中。
- low 档 scale=.6 持续慢 101 帧，仍保持 low/.6、floorHits 从 4 增至 10，无质量事件。快帧只恢复 scale，不自动恢复 high/ultra 档位，符合原函数。

记录 stub 证明直接调用顺序，不证明实际 resize 副作用、异常回调语义或真实运行性能；后两者由下述接线审查和各自探针限定范围。

## Main 入口、状态归属和顺序

render_quality.frame 在 [Main._process](../scripts/main.gd) 的 render 阶段调用一次，位于 rain/sky/UI 更新后、planar/sun/post 更新前。原主循环也先完成相应游戏/FX 更新，再进入 render.frame 采样 R。暂停和 title 仍执行 render 阶段并采样，符合原作 DRS 不因暂停自动冻结的行为。雨 uPix 在 DRS resize 当帧仍可能来自旧高度、下一非 paused 更新才刷新，这与原结构对应，不应为了立即追随尺寸把 DRS 移到 rain.update 之前。

默认输入为相邻 `Time.get_ticks_usec()` 的差值除以 1000；首个无显式测量的调用只登记时间、不采样，类似原 C=0 的第一帧。即使 controller disabled，previous_usec 仍更新，避免日后启用时误把整个禁用期间当作一帧。`measured_ms` 是诊断注入入口，正常 Main 不传该参数；观测计数/日志不参与原 R 的决策。

dynamic_resolution.sample 先更新自身 S，再按原顺序给出 resize 或 quality→auto 事件。render_quality 在同一个 frame 调用内消费事件：scale-only 写 Post.dynamic_scale 并 `_resize()`；降档调用现有 apply，再发 quality_auto。后续 Main 在同一轮把新内部尺寸交给 planar，更新 sun 和 post，未把 DRS 事件推迟到下一 physics tick。

手动 apply 保留同一 dynamic 对象和整份 S，没有重置 scale、settle、upWait、upDelay、floorHits 或 previous_usec，符合原 setQuality 不重建 S。画质变化会清 motion history，但那是图像投影历史，不是 DRS 统计状态。画质与动态 scale 的乘积仍经过原像素上限算法；world/weapon、combined/half depth、post、反射和阴影变更继续复用 [上一阶段审查](quality-review.md) 的路径，DRS 没有另建一套资源缓存。

`current` 表示生效档位，GameUI.effective_quality 只提供显示来源；settings.quality 保留用户选择。自动降档既不赋 settings.quality，也不调用 UI._save。原 UI L84335 同样仅在持久化值为 auto 时显示当前 n.quality；手动选择的值不会因自动降档被悄悄改写。当前运行探针断言的是这两个字段，没有把按钮样式刷新或设置文件内容当作已验证输出。

Native configure 默认对 `--script` 和已有 game preview 模式关闭 DRS，`--dynres=0` 也关闭；显式 `--dynres=1` 可以覆盖这些开关。这是本项目的诊断适配策略。原 URL 的 shot/show 本身总是禁用 DRS，即使 dynres=1 也不会覆盖；两者不能称为字面相同的参数优先级。这里也未实现 UM 的设备自动档位选择。

## 受控实际 Main 接入

[verify_dynamic_resolution_runtime.gd](../tools/verify_dynamic_resolution_runtime.gd) 用 ControlledQuality 覆写测量入口，仍从实际 Main._process 进入 controller/apply/resize。前 350 轮注入 50ms，此后每轮批量注入 20 个 10ms 样本；720 轮工具更新不是恢复阶段“一次呈现对应一个实测样本”。

[runtime 报告](../evidence/dynamic-resolution-runtime.json) 零失败，[归档日志](../evidence/dynamic-resolution-runtime.log) 无 ERROR/WARNING：从 ultra/1 开始，frame 88 到 ultra/.6，125 降 high/.8，219 降 medium/.8，313 降 low/.8，374/385 把 low 的 scale 恢复到 .9/1。三次 quality_auto 顺序为 high、medium、low，未提升质量档位。该工具检查相应 world/weapon 尺寸以及 combined/half depth readiness，最终 settings.quality 仍为 auto、effective_quality 为 low，随后恢复 playing。

例如 medium/.8 得到 870×490、medium/.6 得到 653×367、low/.8 得到 717×403，恢复 low/1 后为 896×504，体现 preset.scale 与动态 scale 的共同作用。shadow 数值有记录，但该探针没有独立断言每次 shadow 尺寸或所有反射/AO/volume 图像内容；它也没有覆盖手动切档时保留全部 S 的数值轨迹，此项目前来自上述代码审查。

## 真实墙钟入口

[verify_dynamic_resolution_wallclock.gd](../tools/verify_dynamic_resolution_wallclock.gd) 保留 Main 的真实引擎 process/physics 回调，不手动调用 Main._process，也不注入 measured_ms；用 `--dynres=1` 显式覆盖脚本默认禁用策略。[墙钟报告](../evidence/dynamic-resolution-wallclock.json) 记录 8.372425 秒观察、1,119 个测量样本，最后一次间隔 6.902ms，settle 已过零，控制器继续累积统计，failures 为空；[归档日志](../evidence/dynamic-resolution-wallclock.log) 无 ERROR/WARNING。

这次观察位于 title 场景，current=high、scale=1、内部尺寸 1280×720，changes 为空。它证明真实时间采样路径被 Main 消费，没有证明实际机器负载下已经触发自动降档，更不能由最后一次 6.902ms 推导稳定帧率、游戏性能达标或整体帧时间分布。探针结束时额外等待 process_frame/force_draw，observer 帧号和采样数也不是严格的 GPU 呈现计数。

本阶段证据分别支持：给定相同输入的原 R 数值行为、注入测量下的实际资源接线、真实墙钟测量的入口可达性。跨 API 原画面、真实游玩负载下的闭环效果与性能目标、设备自动选择和不同 boot 资产质量仍保留边界；上一阶段列明的 AO/volume/planar resize 首个呈现帧门控及 reflection 读取前帧阴影的像素边界也不会因 DRS 内核通过而消失。
