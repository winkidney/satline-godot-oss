# Godot 实验与实机验证

2026-11-14。独立项目见 [godot/README.md](../godot/README.md)。本轮已实际运行，使用 Godot 4.7.2、Vulkan Forward+、NVIDIA GeForce RTX 4070 SUPER；具体版本与设备API见 [runtime.json](../godot/captures/runtime.json)，完整最终启动日志见 [runtime.log](../godot/captures/runtime.log)。不修改 `stocking-lab`。

## 1. 微细节：低于像素的纹理不能继续按点采样

[核心 shader](../godot/shaders/micro.gdshader) 将静止顶点坐标传至片段，以 `pitch_mm * 0.001` 规定纹理周期。`max(length(dFdx(p)),length(dFdy(p)))` 估计每像素材料长度，足迹从周期的0.3到0.85倍时淡出微法线和微颜色。退出的法线能量用 `sqrt(base_roughness² + variance)` 保留为更宽的平均高光。

这借鉴 Saltline 的真实尺寸、导数退出和法线方差补偿思想，但这里的variance是由退出比例得到的解析近似，不是读取normal mip长度，也不是各向异性织物BRDF。没有声称完全符合统计微表面理论。

| 过滤开启 | 过滤关闭 | 更近机位，4mm周期 |
| --- | --- | --- |
| ![filtered](../godot/captures/micro-filtered.png) | ![raw](../godot/captures/micro-unfiltered.png) | ![close](../godot/captures/micro-close.png) |

相同远机位下，开启后整体受光更平滑；关闭时保留高频点采样纹理。近景图是另一组距离与周期参数，不能拿它与远景图当单因素对照。慢速移动镜头记录见 [lossless WebP](../godot/captures/micro-motion.webp)，素材是12个固定相机位置，各帧等待渲染稳定后保存，不是实时帧率录像。

## 2. 湿润：同一状态联动属性；平面反射另有相机成本

[wet.gdshader](../godot/shaders/wet.gdshader) 用一份连续湿润量同步让颜色变暗、roughness从0.8趋近0.075，并压低微凹凸。颜色与粗糙度参数是教学配置，不是尼龙/水膜的测量值。

| 潮湿并开启平面反射 | 同一湿润量，关闭平面反射 | 干燥 |
| --- | --- | --- |
| ![wet](../godot/captures/wet-planar.png) | ![no planar](../godot/captures/wet-no-planar.png) | ![dry](../godot/captures/dry.png) |

`lab.gd`把主相机位置和观察方向关于y=0镜像，up设为DOWN，采用投影矩阵把世界位置变为反射UV。地面只在主相机layer中出现，避免捕获自身形成反馈。绿色测试物跨过反射平面，[object.gdshader](../godot/shaders/object.gdshader)在镜像相机中丢弃y<0片段。

这是逐材质裁切，不是原作的相机斜裁切矩阵。新增材质必须实现同样规则；当前只验证本实验物件。可调反射分辨率为主视口的0.25–1倍，更新间隔1–8帧；未用这些数值推断GPU耗时。反射粗糙度是9tap近似，而非原作HDR mip采样。

反射相机独立使用Linear tone mapping、固定曝光、关闭glow，采样声明source_color。这样避免先Filmic再把它当原始光能重复处理，但普通SubViewport输出仍有LDR裁切。材质将反射加到EMISSION，未替换环境BRDF辐射，可能额外增能，不能当作严格PBR平面镜方案。

## 3. 镜头：材质成立后再加入风格

| Clean | Glow + grade + streak | 开启自动曝光 |
| --- | --- | --- |
| ![clean](../godot/captures/lens-clean.png) | ![styled](../godot/captures/lens-styled.png) | ![auto](../godot/captures/lens-auto-exposure.png) |

曝光与Filmic由Environment处理，自动曝光由CameraAttributesPractical控制，感光度范围设置100–1600 ISO。原生glow先处理HDR亮区；[lens.gdshader](../godot/shaders/lens.gdshader)在3D输出之后做25tap横向卷积，再加固定调色与暗角。UI在更高CanvasLayer中显示，不参与镜头处理。

此卷积是在已色调映射的屏幕图上提取高亮，无法恢复HDR强度或准确复现原作曝光相关阈值；没有重复应用ACES/AgX或手动sRGB转换。它展示的是处理阶段的选择，而非原作完整后处理移植。自动曝光静态图只证明该路径能运行，尚未测量亮暗切换适应曲线。

## 4. 采集、检查与边界

运行 `rtk proxy python3 tools/run.py capture` 自动采集42张PNG，包括主要状态、近景、自动曝光、12帧微细节镜头移动、干湿精确端点、3个湿地观察机位与16帧节流反射动态镜头；保存引擎、设备、相机、画面尺寸和实际参数。左侧UI同步自动采集参数，避免截图上显示错误开关状态。最终日志无SCRIPT ERROR/SHADER ERROR/ERROR，capture正常退出。

- [图像差异统计](../godot/captures/verification.json) 比较排除左侧UI后的像素差，确认开关产生实际画面变化；像素变化不是物理正确性或人工审美批准。
- 自动曝光初次误把感光度当成无单位乘数，使用0.1–4 ISO导致严重过曝；已改为100–1600 ISO，错误结果保留为 [诊断图](../godot/captures/diagnostic-invalid-iso.png)，用于说明API单位不能照搬。
- 两次早期启动曾因Environment枚举名称错误而解析失败，已修正为REFLECTION_SOURCE_SKY；成功运行记录只指修正后的最终版本。
- 原作同类效果的实现、参数与局限见 [渲染迁移表](rendering-port-map.md)、[材质报告](materials-and-textures.md)；本实验截图不作为原作截图。
- 没有用截图数量、平均帧间隔或设备型号宣称性能预算通过。HDR反射、相机斜裁切和完整TAA稳定性仍需独立工程实现，不能由本实验结果外推。

## 5. Astra Ultra 顾问审查后的修复与回归

顾问指出静态对照可能掩盖三个实现问题，本轮已修正并重新GPU采集42个状态：

1. **湿润端点**。空间扰动改为 `wetness*(1-wetness)*noise`。因此wetness=0和1都不受噪声影响，分别是真正全干与全湿；中间量仍可有连续斑驳。[全干端点](../godot/captures/dry-endpoint.png)、[全湿端点](../godot/captures/wet-endpoint.png)。验证工具对41×41材料坐标网格数值检查两端，结果严格为[0,0]和[1,1]。这项是公式数值检查，截图是对应GPU画面，不把数值网格称作GPU读回。
2. **反射贴图与投影同一时刻**。主相机输入先更新，仅实际刷新SubViewport的帧才更新镜像相机及公开的view/projection；跳过更新时保持旧纹理和旧投影配对。`runtime.json`保存update_interval=4的逐帧轨迹，工具检查跳帧时公开矩阵完全不变且存在多次刷新。这样允许低频反射图像本身变旧，但不会用新相机矩阵投影旧图而额外滑动。
3. **法线不依赖屏幕朝向**。不再把dFdx/dFdy高度当切线坡度。按world.xz解析求两组高度函数梯度，以1.2mm幅值构造 `normalize(-dh/dx,1,-dh/dz)`，再经VIEW_MATRIX变到受光空间。这适用于本实验未变换的水平面，不是一般变形网格的通用切线框架。

新增[节流反射动态WebP](../godot/captures/reflection-motion.webp)有16个连续移动机位，更新间隔4帧，逐帧与PNG无损解码相等；它用于检查时序而不是实时帧率基准。多机位以wetness=0.35保留可见微法线坡度，避免全湿压平后掩盖方向错误；参考为[角度0](../godot/captures/wet-angle-00.png)、[角度1](../godot/captures/wet-angle-01.png)、[角度2](../godot/captures/wet-angle-02.png)。这些证据增加对镜头变化的覆盖，不能代替任意场景的完整反射正确性证明。
