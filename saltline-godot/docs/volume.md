# 原 Y9 体积光与默认渲染接入

默认游戏现在执行原固定 4096² caster 阴影 → 深度 → 半分辨率 24 步散射 → 两次深度引导模糊 → joint composite → bloom/曝光/调色/最终处理。没有开启 Godot 原生体积雾替代原公式。世界与视图武器保持独立深度；武器 sentinel 和天空路径按原 shader 处理。

## 公式与格式

依据 `artifact-rendering-study/source/shaders/35674-Y9.glsl.template`、`35731-QM.glsl.template`，由 `tools/port_composite_shaders.py` 生成 `source_volume.gdshader` 和 `source_volume_blur.gdshader`。源参数为 24 步、最大距离 170、sigma .0034、远景 haze .42、仓库 dust 6，太阳辐射为原太阳颜色乘 9×.85。保留双 HG 相位、室内盒密度、阴影比较 bias .0006、环境散射与远处解析延续。雷暴按原环境辐射乘数 1+thunder×1.5 更新；该响应尚未单独做实机雷暴对照。

阴影将原 packed RGBA 解码值等价存为 R32F，独立输入证明见 [sun-shadow-pass.md](sun-shadow-pass.md)。散射 RGB 与透射率 alpha 必须同时保留；三个半分辨率 viewport 使用透明背景和 blend_disabled，存储 RGBA16F，每次输出显式半精度 round-to-nearest-even。普通不透明 Canvas 背景会丢失透射率，不能这样配置。

默认仅在阴影与半深度准备完成后开启最终体积光合成。阴影按原 high 隔帧更新，散射每帧更新。生产路径不做 CPU 图像读回。主场景释放时先停后处理消费者，再释放阴影输入；诊断退出帧对空 shadow pass 加保护。

## 已验证范围

- `tools/volume_reference.html` 在原 Three shader 上生成 16 组 GPU 参考：8 个室内、室外、远景等视角各覆盖阴影开关，深度含武器、近景、远景和天空。原 RGBA16F 三阶段逐 24576 通道对照，零失败；原始散射最大误差 .000488，模糊最大误差 .0009765625，原容差 max(.002,0.3%)。见 `evidence/volume-gpu-verification.json`，复现脚本 `tools/verify_volume_gpu.gd`。
- 默认后处理回归 `tools/verify_post_pipeline.gd` 通过；该受控脚本没有注入 shadow pass，验证关闭体积光时原管线不变，不冒充端到端体积光数值对照。
- 实机场景 `--volume-preview` 冻结时间和相机，清空敌人。前 120 帧关闭体积光，中 120 帧开启真实阴影体积光，最后 120 帧仅用于诊断地关闭体积光阴影。对比图为 `volume-100.png`、`volume-220.png`、`volume-340.png`。原阴影 4096² 准备完成，透射率最低 .5668945；有阴影最大散射 2.0410156，无阴影 5.5664063。开启体积光改变 37494 个抽样 HDR 像素；移除阴影再改变 51700 个。见 `evidence/volume-runtime.json`。
- `evidence/native-source-volume.mp4` 为上述 6 秒 720p60 原生录像，无音轨。实机和录制日志均无 SCRIPT/SHADER/ERROR/泄漏。录像固定帧率与编码耗时不能证明稳态实时帧率；Movie Maker 根 viewport 计时也不能代表全部子 viewport GPU 成本。

这些证明源公式、格式以及完整场景的可见贡献；尚未证明整幅原版游戏逐像素相等、所有天气/画质选项或最终性能预算。MSAA 跨后端边缘差异继续见 [msaa-depth.md](msaa-depth.md)。

复现：`rtk proxy env DISPLAY=:0 godot --path saltline-godot --audio-driver Dummy --display-driver x11 -- --volume-preview`。
