# 原版动态分辨率控制器

## 原版依据

原 bundle 第 36837–36892 行 S/R，render.frame 第 37137 行的 performance.now 帧间隔输入，resize 第 37105 行将 quality.scale 与 S.scale 相乘并应用像素上限。

`scripts/dynamic_resolution.gd` 为纯数值控制器，`render_quality.gd` 同步消费 resize、setQuality 和 quality:auto 动作。Main 在雨/材质/HUD 更新后、反射/太阳/后处理执行前采样单调时钟，与原 render.frame 的调用位置对应。暂停时仍采样渲染耗时。测量使用 Time.get_ticks_usec，不使用已截断的 gameplay dt。

## 保留行为

- 初始 3.5 秒稳定期；超过 1500ms 的单次间隔不参与统计，也不推进等待时间。
- 45 个样本或累计 900ms 形成统计窗口；严格大于 21.5ms 才降低比例，超过 30ms 减 .2，超过 45ms 直接降到 .6。
- 上调要求均值严格小于 17.4ms，且等待结束；降比例后等待翻倍，最多 60 秒。
- 最低比例仍超过 26ms 连续两次，则 ultra→high→medium→low 降档，比例回到 .8。到 low 后不再降低档位。
- 恢复负载只逐步恢复渲染比例，不自动升回更高质量档位。保留原负 settle/upWait 数值，不擅自归零。
- 手动切画质保留控制器状态。自动降档更新实际 effective_quality，但不覆盖或保存用户 quality 偏好。

Godot 专用策略：自动化 --script 与预览入口默认禁用墙钟自适应，以对应原 shot/show 的确定性需求；正常交互入口启用，--dynres=0 可禁用，--dynres=1 可显式启用诊断。显式覆盖不是原 Web 参数优先级的逐字复刻。硬件自动初始档位仍未实现，auto 当前解析为 high。

## 证据

`dynamic_resolution_reference.cjs` 直接提取执行原 R(G)，fixture 包含 36 例 / 7494 次采样，覆盖严格阈值、稳定期、无post、禁用、大间隔、60秒上限、最低档持续慢以及恢复。`verify_dynamic_resolution.gd` 82335 项原参考比较，加 5 项 Native flag 检查，共 82340 项通过，最大误差 7.106e-15。比较包含非有限数检测。

`verify_dynamic_resolution_runtime.gd` 在实际 Main 渲染阶段用 ControlledQuality 注入已知耗时：前350个呈现帧每帧一个50ms样本，之后每呈现帧批量20个10ms恢复样本。总720个实机呈现帧，分别在125/219/313帧降为high/medium/low；比例改变导致真实world/weapon viewport重建，组合与半分辨率深度就绪；最终low的比例恢复1，设置仍为auto，effective为low，并能恢复游戏。报告 `evidence/dynamic-resolution-runtime.json/.log`。恢复批量样本不是一次真实呈现对应一次测量，也不是性能测试。

`verify_dynamic_resolution_wallclock.gd` 不手动驱动Main，不注入时间，保留真实引擎process/physics；通过 --dynres=1 为诊断脚本开启控制器。最终观测8.372425秒、1119个测量，越过3.5秒稳定期，scale保持1、high、未触发调整。它证明真实时钟被消费并开始统计，不能证明真实重负载自动降档、帧率目标或整局性能达标。`evidence/dynamic-resolution-wallclock.json/.log`。

## 范围与记录

本次没有实现设备自动档位识别、冷启动各档资产烘焙、全部窗口/DPR下的UI像素响应式、切换首帧AO/反射的像素连续性；此前 quality-review 的边界继续有效。实际重负载下的性能与视觉权衡仍需单独测量。

首次420帧真实时钟观测只经过约3秒，仍在初始稳定期。保留 initial-settle JSON 后延长至至少8秒，不能把前次观察扩大为稳定期后控制器评估。实机启动曾遇自动审批服务 Bad Request，动作未执行；相同审批流程重试成功，没有绕过审批。
