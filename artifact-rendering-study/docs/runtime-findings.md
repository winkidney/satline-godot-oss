# 实机画面、消融与数据

本阶段已获用户授权运行。原作在桌面 Chromium / WebGL2 / ANGLE / NVIDIA RTX 4070 SUPER 上运行；Godot 使用同一设备的 Vulkan Forward+。原件 SHA-256 仍为 `b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb`。本页是当前运行证据入口，早期报告中的静态判断保留为源码分析。

## 1. 基线与控制条件

![未经修改的原作](../evidence/runtime/captures/pristine-original.png)

[原件运行记录](../evidence/runtime/pristine-original.json)确认 `advanced=true`、`softShadows=true`、无游戏捕获错误。画面为1280×720、high档、4×MSAA、4096阴影、24步体积积分。早期 headless 会话使用 SwiftShader，随后切换桌面 NVIDIA 会话；以下采集不使用软件渲染结果评价性能。

消融使用[研究副本](../research/index.html)，不改原件。研究副本只开放已有缓冲/纹理、可选 stock PCF 分支及计时钩子；不替换默认视觉算法。`step=1` 在3个模拟帧后停止游戏更新，手动推进渲染阶段。对照固定手动曝光0.7、grain=0，隐藏HTML UI；截图时间、相机、质量和参数随图保存。未来重跑等待 `__ready && __step===0`，防止第2帧ready与第3帧更新之间的竞态。

固定曝光对照的目的是分离贡献，不能把这些图称作默认自动曝光下的最终美术效果。`stats.fps` 在step模式下不代表实时性能。

## 2. 最明显的画面贡献

| 完整组合 | 关闭体积散射 | 关闭地面平面反射 |
| --- | --- | --- |
| ![base](../evidence/runtime/captures/harbor-baseline.png) | ![no volume](../evidence/runtime/captures/harbor-no-volume.png) | ![no planar](../evidence/runtime/captures/harbor-no-planar.png) |

体积散射让远处起重机和集装箱融入亮雾，也让朝太阳方向的光束形成空间层次。关闭后天空仍有云和光晕，几何表面及远景的遮罩关系变硬。这与源码中“方向天空”和“沿视线积分雾”分离的结构一致。

平面反射不只是添加一个亮点。关闭它后，地面失去集装箱轮廓，退回较宽的环境反射；这组机位的地面反而更亮。原因应结合反射内容和radiance替换判断，不能用“镜面开关越亮越正确”作为标准。

| 关闭太阳直射 | 关闭场景环境强度 | 关闭部分镜头效果 |
| --- | --- | --- |
| ![direct off](../evidence/runtime/captures/harbor-no-sun.png) | ![env off](../evidence/runtime/captures/harbor-no-ibl.png) | ![lens off](../evidence/runtime/captures/harbor-no-lens.png) |

这里“关闭太阳”只令方向光强度归零，并影响体积太阳项；天空太阳圆盘、预先捕获的IBL和独立flare仍在。“关闭环境”只将场景environmentIntensity归零，不保证抹去显式材质envMap和独立平面反射。“关闭镜头”去掉flare、dirt、streak、色差、暗角、锐化，但保留tone mapping及固定grade。这些都不是全系统的单因素清空。

原作的主特征来自天空/环境、直射受光、体积透射与反射的配合。材质微纹理负责近处表面差异，不能独自承担整张画面的层次。

## 3. 阴影与雾的专用场景

| PCSS类阴影 | Three stock PCF | 关闭体积散射 |
| --- | --- | --- |
| ![pcss](../evidence/runtime/captures/render-pcss.png) | ![pcf](../evidence/runtime/captures/render-stock-pcf.png) | ![no vol](../evidence/runtime/captures/render-no-volume.png) |

该场景把球体、窄窗、立柱和地面放在同一个方向光下，适合检查阴影边缘与光束。PCSS和stock PCF由加载时的shader chunk分支切换，元数据确认两条路径各自运行。半影随遮挡距离增长的具体机制仍以[公式分析](deep-implementation.md)为准，不能只用这张静帧反推出真实光源尺寸。

SSAO关闭图见[独立对照](../evidence/runtime/captures/render-no-ao.png)。港口场景的AO开关平均像素差约1.77/255，体积开关约8.52/255，平面反射约7.35/255；这些只说明当前机位的变化幅度，不是质量评分或普遍重要性排序。[差异及计时原始记录](../evidence/runtime/comparison.json)

## 4. 近景、材质与粒子

| 手套与袖口 | 材质展示 | 特效运动 |
| --- | --- | --- |
| ![hands](../evidence/runtime/captures/showcase-hands.png) | ![materials](../evidence/runtime/captures/showcase-mats.png) | ![fx](../evidence/runtime/fx-motion.webp) |

手套中大块材料区、指节护块、袖口罗纹和雨珠的尺度不同。源码使用rest/material坐标、区域标记和不同细节频率，比在整只手上均匀叠一张噪声图更有辨识度。该模块是标准PBR加程序表面输入，不是纱线BRDF或布料解算。

原作提供render、ground、mats、hands、weapon、fx、backdrop等showcase入口。本次均实际运行，高级渲染和软阴影启用，游戏错误数组为空。[各场景记录](../evidence/runtime/showcases.json)

动态特效WebP来自12个固定步进状态，每帧推进8/60秒模拟时间；逐帧解码与PNG完全一致。它是步进研究序列，不是实时帧率录像。初始FX静态画面尚未到烟火生成时间，不能用空场景截图判断特效不存在；运动序列才显示粒子寿命内的变化。

## 5. 真正生成的贴图与中间缓冲

| fabric normal | fabric高度预览 | 地面反射预览 |
| --- | --- | --- |
| ![normal](../evidence/runtime/texture-fabric-normal.png) | ![height](../evidence/runtime/texture-fabric-height.png) | ![planar](../evidence/runtime/buffer-planar-reflection.png) |

实际导出fabric、paint、chainlink、tarp四套配方，各包含颜色RGB、单独alpha、ORM、normal和高度预览。high配置不是每张都1024：fabric为256²、paint为1024²、chainlink和tarp为512²。原作按配方size缩放分辨率，保留以米定义的tile和以毫米定义的bump。

alpha仍须按材质解释：染色权重、线网覆盖或透明度不是同一语义。材质图的可视颜色也不等于受光后的最终颜色。

![线性深度预览](../evidence/runtime/buffer-depthHalf.png)

缓冲导出包含scene、half-depth、AO、体积散射/透射、bloom层、streak、镜头污渍和平面反射。必须分清两种文件：

- PNG是8位查看图。`mode=hdr` 实际使用 `pow(v/(1+v),1/2.2)` 映射，不是HDR文件；float的raw模式仍夹到0..1并量化。高度灰图也会丢掉原双通道精度。
- [numeric-buffers.json](../evidence/runtime/numeric-buffers.json)列出真正的GPU读回字节：depthHalf为little-endian float32；volA和adapt为float16，Uint16Array仅承载其位模式；fabric height保存RGBA8，其中 `h=R+G/255`。二进制按GL底行优先存储，PNG已经上下翻转。adapt导出固定ping-pong索引0，不保证是最新适应值。

NumPy读取示例：

```python
depth = np.fromfile('numeric-depthHalf.bin', dtype='<f4').reshape(360, 640, 1)
volume = np.fromfile('numeric-volA.bin', dtype='<f2').reshape(360, 640, 4)
# 如需与PNG坐标一致，沿第0轴翻转。
```

场景控制遮罩与其他纹理的生成逻辑见[表面与特效报告](surfaces-fx-and-cloth.md)，本轮没有声称穷尽所有GPU资产。

## 6. 普通模式的曝光适应

为避开shot/show模式的快速适应，另开 `autostart=1&dynres=0` 的普通模式。先朝亮处稳定120个渲染帧，再把相机移入室内，固定dt=1/60并只推进渲染。

| 转入室内后模拟时间 | 历史亮度 | 曝光乘数 | 太阳可见度 |
| --- | --- | --- | --- |
| 0 s | 0.2349 | 0.600 | 1.00 |
| 0.267 s | 0.2053 | 0.633 | 0.11 |
| 1.067 s | 0.1427 | 0.863 | 0.00 |
| 3.000 s | 0.0802 | 1.408 | 0.00 |

这是该固定场景的测光响应，支持亮度历史逐渐更新、曝光随之上升的判断。不是人眼测量，也不是墙钟帧率。[完整数据](../evidence/runtime/detail-validation.json)

## 7. 成本与验证边界

使用 `EXT_disjoint_timer_query_webgl2` 对研究副本的post绘制测量4个渲染帧，共104条query，无disjoint。示例中体积积分中位约0.178ms、grade约0.156ms、AO约0.047ms；分辨率、样本数和范围全部保存在[记录](../evidence/runtime/comparison.json)。down/up各层尺寸不同，不能把混合尺寸的单项中位数当作整条金字塔耗时。

这些计时不含世界主绘制、阴影捕获、平面反射、纹理生成、数据导出或完整帧呈现，不证明总帧预算通过。工具检测到disjoint会丢弃待完成查询，避免以后误记为有效。`mats.textureMB`是源码估算值，不是设备显存实测。

本阶段完成了原作实机与三个[Godot实验](godot-experiments.md)，但没有做完整游戏QA、移动设备验证、跨驱动回归或精确视觉复刻。
