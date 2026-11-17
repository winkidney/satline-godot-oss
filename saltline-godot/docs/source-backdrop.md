# 背景闪灯与盘旋海鸟

原186个Standard/Basic材质的onBeforeCompile审计发现两个未迁移族：一个Basic材质控制两个灯光网格的blink属性，另一个Basic材质控制单个背景海鸟网格的aOrbit/aPar。它们独立于敌方Gull actor，当前均已接入。[族审计](../evidence/material-patch-family-audit.json)不等于完整画面校准。

`extract_backdrop_patches.py`从实际导出vertex patch提取原文，生成`source_backdrop.gdshaderinc`，原文fixture和身份保留在assets/export/fixtures。blink的period/phase/duty形成.02到1的smoothstep脉冲，period<=0保持1；插值后乘原HDR vertex color，Basic继续unlit。海鸟保留原轨道中心/半径、角速度、初相、振翅、翼展收缩和转弯倾斜。position.y=-60是shader待抵消偏移，不能直接静态显示。

blink存CUSTOM0，aOrbit/aPar存CUSTOM0/1，均RGBA32F，三分量blink补零。三网格共4464顶点，相关GPU自定义属性逐字节一致，HDR color的CUSTOM3保留。海鸟custom AABB按轨道半径、局部x/z、最大.73振翅、倾斜和两个正弦共3.7米的高度范围保守计算，另加.01米浮点余量；该解析界另核对96组原GPU输出，未把有限采样声称为穷尽所有时间。

`source_backdrop_time`由背景模块独立累计，暂停冻结。原主循环仅在非paused状态调用backdrop.update；此前把它接到全局帧时钟、声称暂停仍更新的解释不正确，现已修正。主渲染step保留`min(dt,.05)`上限。实际playing dt=.1后为.05，随后paused .04与.2均保持.05；灯光和海鸟shader与同一累计值一致。标题、死亡状态继续推进，重试不重置。

- [核心对照](../evidence/backdrop-verification.json)：原NVIDIA Three的96组真实顶点/属性、8时刻.05到300秒，RGBA32F参考对比native float32字节编码。384通道通过，max2.98e-8，没有以half精度隐藏位置误差。
- [实际接线](../evidence/backdrop-runtime-verification.json)：三原网格、生产Basic shader、孤立正交视口。两灯网格78700/78698像素变化，海鸟4489像素变化且可见，属性与mode核对通过。有限实验不证明完整透视/bloom/遮挡合成或所有时间的经验裁剪。
- [生成幂等](../evidence/backdrop-generation-verification.json)。780帧标题/暂停/死亡/两次重试通过，游戏状态暂停冻结保留；240帧反射回归通过。

`backdrop-gulls-0/1.png`是黑底孤立观察图，线性RGB转RGB8，用于看原低模几何和位移，不作为最终天空曝光截图；已查看首图。完整目标仍在推进。

## 船体、吊具与雷达动态

`source_scene.gd`现按原kw.y更新船根升沉、船体局部横纵摇、crane-spreader摆动及货轮radar旋转。船根原朝向与未受动画控制的局部轴保留；每次写绝对姿态，不在导出快照上叠加，避免积累漂移。雷达使用double相位计算后写最终float32 basis，避免先把长时间角度截为float32。

[原函数矩阵对照](../evidence/backdrop-motion-verification.json)使用实际原kw.y和bundled THREE组，51个时刻、3264通道，无失败，最大误差7.63e-7。包含标题/playing/paused/dead、零dt和dt上限；实际Main启动和retry不重置背景时钟。原海鸟与闪灯的属性/可见像素回归仍通过。该证据不等于完整反射/阴影逐像素对齐。
