# 原 Z9 相机运动模糊

`source_motion.gdshader` 由原 `35778-Z9.glsl.template` 生成。按原相机历史重投影，在 HDR 场景合成之后、bloom/曝光/调色之前执行。原 9 taps 加中心样本，屏幕速度低于 .75 像素则绕过，最大 UV 速度 .018；武器深度 <.05 绕过且不参与邻域积累。保留原 IGN 抖动和 RGBA16F 显式 RNE 存储。

默认 high 开启。每帧保存当前相机 view-projection，无论效果是否启用；首帧、dt<=0 和关闭效果时 shutter=0。正常 shutter=min(.5,1/190/max(dt,.001))，对应原源码。Godot 原生 reverse-Z 不用于该投影重建，CPU 根据当前真实相机投影尺度和 near/far 构造 Three/OpenGL -1..1 深度矩阵，再乘相机逆世界矩阵。输入 combined R32F 仍是原编码深度。

生产管线固定分配全分辨率 motion viewport，下游 bloom 与 tk 都消费它。关闭时原 shader 返回中心样本。逻辑分辨率变化同步目标和 uRes，释放时先停止消费者。

## 证据与未完成项

`tools/verify_motion_gpu.gd` 已在 RTX4070SUPER Vulkan 运行：静止、亚像素运动、相机后方三种绕过逐像素零误差，武器区域所有案例零误差。运动条纹原亮度 .125..4，模糊后内部范围 1.673828..2.451172，14336 个世界像素变化，恒定绿色通道零误差。见 `evidence/motion-kernel-verification.json`。

接入后 `verify_post_pipeline.gd` 原 HDR、调色、逻辑 resize 回归通过，见 `evidence/post-pipeline-verification.json`。这些是原生语义检查；后续已补原 Three GPU 数值对照、原相机矩阵检查和实机开关录像，详见下文。完整画质设置和所有相机轨迹的视觉验收仍待完成。

源实现：`artifact-rendering-study/source/extracted/bundle-1.js:35778` 和 `:36479`；画质 high/ultra 开启、其余关闭，原质量表在 `:34690`。后续需要接完整画质选项。

实际场景太阳视角 480 帧回归也通过（含仓库与转向，体积光同时启用），日志 `evidence/motion-game.log`，原太阳遮挡门控检查零失败。这仅证明共同运行和太阳检查，不代替运动模糊专门视觉验收。

## 原 GPU 与相机参考

`tools/motion_reference.html` 使用原 bundle 的 Three r180 和未改动 Z9 公式生成原 RGBA16F 输出；`motion_gpu_reference.cjs` 采集至 `assets/export/fixtures/motion-gpu-reference.json`。6 组包含静止、微小运动、旋转、平移、快速旋转、组合运动。`verify_motion_reference.gd` 逐 49152 通道检查，原预设容差 max(.004,0.3%)，零失败；静止/微小运动/本测试旋转组完全一致，平移/快速/组合的最大差分别 .0078125/.005859375/.00390625，平均误差均低于 .00018。浮点与硬件线性采样差异保留，不宣称位一致。

同脚本将原 cameraWorld 设置给实际 Camera3D，再调用生产 `_source_view_projection`，与原 Three 的 viewProj 比较。当前参考使用同一 74 度、aspect2、near.08/far900 的相机，六组 current 相机相同而 previous 变化；因此是一个真实相机配置的矩阵检查，不是六个不同配置。矩阵分量最大误差 5.722e-6。更多 FOV/near/far/宽高比和轨迹仍可扩展。

## 实机对比

`--motion-preview` 重复相同 240 帧相机摆动轨迹：前半关闭运动模糊，后半开启。世界天气与时间正常继续，不把两段称为逐帧相同世界状态。AO、原体积光和 bloom 同时启用。第120/360帧同相机位置分别测量本帧 motion 前后 HDR 图；关闭时差为零，开启时 31378 个抽样像素 RGB 总差大于 .003，shutter=.31578947。见 `evidence/motion-runtime.json`。

`evidence/native-source-motion.mp4` 为 8 秒 1280×720、60fps、无音轨的实机开关录像。对应静帧为 `motion-120.png`、`motion-360.png`。专门录像与原 GPU 对照日志均无 shader/script/GPU 错误及泄漏；录像输出帧率不代表稳态运行性能。
