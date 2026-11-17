# 启动加载界面

2026-11-16：源码默认入口改为 `scenes/boot.tscn`。先呈现加载层，再装载 Main。字体、颜色、间距、响应式字号、进度条和阶段文案取自原 HTML 的 #boot 样式及原 bundle 的 fa 调用。参考生成器为 `tools/boot_layout_reference.cjs`，产物为 `assets/export/fixtures/boot-layout-reference.json`。

Main 与 SourceScene 通过可选回调报告真实构建阶段；默认无回调调用仍同步。加载期间禁用 Main 处理和输入。最终等待世界/武器合成深度实际完成当前尺寸后显示 Ready，再恢复游戏并淡出。修正 CombinedDepthBridge 完成时漏记尺寸的状态，未改变深度计算公式。原作阶段权重是预设值，不代表已完成资产的百分比。

`tools/verify_boot_runtime.gd` 两次原生 GPU 运行均退出 0，failures 为空：1280×720 正常动画、360×720 减少动画。后者通过私有 Portal 会话报告系统偏好 1，未修改真实桌面设置。报告为 `evidence/boot-normal-runtime.json` 和 `evidence/boot-reduced-runtime.json`。覆盖 11 次呈现、材料与节点阶段、布局、Main 初始化期间停用、实际深度就绪、输入放行、0.6 秒淡出或减少动画瞬时淡出、进度条仍为 0.25 秒、700ms 后移除及最终标题。

截图包括 `evidence/boot-normal-00.png`、`boot-normal-fade.png`、`boot-normal-title.png` 及对应 reduced 文件。几何布局有 CSS 数值核对，字体栅格化未声称逐像素相同。私有 DBus 测试工具有 PyGObject register_object 弃用提示，Godot 两次运行无 ERROR/WARNING。

深度回归 `tools/verify_depth_samples.gd -- --engine-origin` 退出 0：165 个几何覆盖案例、96 个部分覆盖像素、4 个 MSAA 样本均通过；每例另核对合成器完成尺寸，报告 `evidence/depth-samples-engine-origin-verification.json`。新增状态未改变已有深度数值结果。

独立展示已接入共用加载层。十类交互入口分别通过真实运行器 setup 验证，报告 `evidence/showcase-boot-verification.json`。其阶段为 .04/.12/.92/1；最后等待实际深度完成，放行输入并淡出。带显式帧数限制的诊断入口继续使用原同步流程，保持采样帧和截图语义。FX 测试驱动首次清理遗漏曝光回调，修正驱动后单独复测退出 0，生产 FX 未改。

r15 已生成，包内主入口加载和四帧 backdrop 诊断从 /tmp 实测退出 0。5,566 个文件、3,074,723,633 字节及 SHA 重新校验一致；报告 `evidence/runtime-bundle-r15-verification.json`。r14 保持原样。本轮未重跑完整任务，Wayland 和 HiDPI 未实测。
