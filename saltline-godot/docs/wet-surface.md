# 通用湿度材质对齐

当前状态：生产噪声已修复，48组完整湿度准备GPU对照通过；以下保留排查过程。完整空间材质图像与性能仍待验收。

源：`../../artifact-rendering-study/source/extracted/bundle-1.js` 的 pk/mk/gk（约39370–39500行）。新实现为 `shaders/source_wet_surface.gdshaderinc`，四个通用材质已接入。原先的简化 `.3+.7*up` 湿度模型已替换为原朝向 exposure、竖向 streak、贴地 low、grime、bead 与湿润增饱和步骤。macro 两组噪声统一使用三平面静止空间或非三平面世界空间，避免混用坐标。污渍和宏观明暗先作用于采样颜色，再进入 tint；湿润饱和度与暗化随后作用于染色结果。粗糙度依次应用 macro、湿度与水珠。

实际 Gull 场景100帧编译/运行正常退出，无 shader/script error。数值验收尚未通过，不能据此宣布完整材质一致。

对照工具：`tools/wet_reference.html` 执行提取的原 mk SL_FX 块，原高频噪声函数保持不变。用 uniform footprint 替代 fwidth，控制48种坐标、朝向、雨量、triplanar/tint组合；原输出写 RGBA16F 的 wet/up/bead/sample-red。Godot `tools/verify_wet_surface.gd` 调用生产 include，预设绝对门槛 .001。诊断视口须 transparent_bg=true 且 shader blend_disabled，才能保留 alpha 数据通道；早期诊断配置导致 alpha强制1/混合，已修正。

当前结果 `evidence/wet-surface-verification.json`：768通道，部分高频bead偏差最大 .187805，部分streak影响wet约 .004395；多数sample-red差在 .001内。未放宽门槛。高频浮点哈希跨后端精度差异只是待查假设，顾问正在审查。还需覆盖最终tint/roughness、真实导数、完整画面及距离alpha-cut。

## 后续代数独立通过与噪声诊断

`tools/wet_finish_reference.html` 直接执行原mk湿润增饱和/暗化与gk粗糙度；`verify_wet_finish.gd` 对照生产sourceWetColor/sourceWetRoughness，48组mac/mac2/wet/bead、768通道零失败，最大差 .00048828125。该测试显式输入噪声准备结果，不支持噪声本身已对齐的结论。

首乘法运行期uint位型屏障、完整hash左结合乘法/求和屏障均未通过48组完整准备测试，失败分别保留 `wet-surface-first-guard-failure.json`、`wet-surface-full-guard-failure.json`。这些屏障只存在独立diagnostic shader；生产slH未改。后续应先定位逐位corner差异，不盲目增加屏障。

## 原参考独立性补强

湿度参考现直接读取从原pk模板字面提取的 `source-wet-noise-original.glsl`，不再复用生产shader的noise文本；浏览器shader编译错误立即抛出。重新采集48组与旧参考所有像素差0，见 `evidence/wet-reference-independence.json`。本轮实际backend为ANGLE Vulkan SwiftShader（WebGL2），已写入fixture；这证明当前数值差异来自与该原参考后端的对照，不能直接推及所有浏览器GPU。生产noise仍未改变。

## 生产噪声修复通过

最终采用 `shaders/source_material_noise.gdshaderinc`：普通运行期 uint uniform `source_noise_round_guard=0` 建立 Bitcast→IAdd→Bitcast 依赖，在 slH 输入、首乘/加、fract、乘17、左结合乘积与求和关键中间量固定float32结果。不能把guard改成const或specialization constant，否则编译器可消除屏障。

关键原因不只是首个FMA。角点表达式 `(floor(x)+corner)*c` 在内联后可被重排为 `floor(x)*c+corner*c`，舍入位置不同；入口屏障固定了角点加法结果。Astra的独立RD与CPU拟合支持该解释，尚无驱动机器码反汇编，不把具体优化形式当作跨驱动保证。完整诊断和指纹见 `wet-adviser.md`、`wet-hash-precision-verification.json`、`wet-canvas-noise-verification.json` 与 `wet-guard-variants-verification.json`。

四个generic材质及生产湿度probe共享同一noise include，材质工厂显式设置guard=0。`verify_wet_surface.gd` 重跑原48组768通道，零失败，最大差 .00048828125，原绝对门槛 .001未放宽。旧plain shader另存 `source_wet_plain_probe.gdshader`，变体工具仍可重现失败；原参考GLSL不改。

完整source-sun-preview360帧退出0、太阳开关验证零失败，`evidence/noise-tangent-regression.log`无脚本、shader、引擎错误或泄漏。已查看更新后的 `source-sun-220.png`，场景正常显示。该回归不能证明所有实际坐标/导数/纹理采样或性能一致。
