# Saltline 亮点算法的实现细节

本页按用户提供样本的 [当前可读脚本](../source/extracted/bundle-1.js) 整理，所有 `#L` 均指该固定副本。它补充已有概览，目的是让读者能重新实现这些做法，而不是只认出算法名。以下是静态实现证据，原作运行和截图结果另见实机研究记录；本页不宣称编译、画面或性能已经通过。

## 1. 先看数据契约

后处理工厂 [L36029](../source/extracted/bundle-1.js#L36029) 创建全屏三角形，所有中间 pass 关闭 tone mapping 和混合，主要缓冲见 [L36117](../source/extracted/bundle-1.js#L36117)。

| 缓冲 | 代码格式与用途 | 必须保留的语义 |
| --- | --- | --- |
| scene / motion | RGBA half-float，线性过滤 | 线性 HDR，不能先压到 sRGB 后再做散射、曝光或 bloom |
| depthHalf | 支持 float color buffer 时用单通道 float，否则 RGBA half-float；nearest | 正的视空间距离，不是硬件深度 |
| aoA / aoB | RGBA unsigned byte，nearest | 0 遮蔽、1 可见；低频量可用较低精度 |
| volA / volB | RGBA half-float，nearest | RGB 是累计入射散射；A 是剩余透射率 T，不是覆盖率 |
| down[6] / up[5]、streakA/B | RGBA half-float，线性过滤 | 曝光之前的 HDR 辐射近似 |
| adapt[2] | 1×1 RGBA half-float ping-pong | R 适应亮度，G 太阳可见度；这是两种历史状态，不是 TAA |
| ldr | RGBA unsigned byte，线性过滤 | RGB 已手动 sRGB 编码；A 暂存亮度供 FXAA 使用 |
| dirt | 512×288 RGBA unsigned byte | 屏幕上的镜头污渍，不是世界材质纹理 |

半屏深度 pass [L35632](../source/extracted/bundle-1.js#L35632) 以 `texelFetch` 取全屏坐标 `2*p`，避免 texel 边界附近的线性采样混合造成斜地面条带。它不是 2×2 最近深度归约。普通 WebGL 深度 d 解码为：

```text
z = near*far / (far - d*(far-near))
d < 0.05 → z = 0.01   # 本项目近景物件的特殊标记
```

这个标记依赖近景 pass 压缩硬件深度的约定，不能移植成 Godot 的通用近裁面规则。Godot reversed-Z 和 NDC 范围不同，需按目标渲染器重建深度。

## 2. 软阴影：米制半影、接收面 bias 和旋转盘采样

入口 [jM()，L35540](../source/extracted/bundle-1.js#L35540) 替换 Three 的 `getShadow()` chunk，因此是全局方向阴影路径的修改，而非一个材质里的边缘模糊。前置拟合把场地边界变到光空间，得到 shadow map 覆盖的米制宽、高、深度范围。

### 接收面 bias

对投影后坐标 `sc=(u,v,z)`，通过屏幕导数解出 shadow UV 平面上的深度梯度：

```text
dx = dFdx(sc); dy = dFdy(sc)
det = dx.u*dy.v - dx.v*dy.u
dz/du = (dy.v*dx.z - dx.v*dy.z)/det
dz/dv = (dx.u*dy.z - dy.u*dx.z)/det
```

`abs(det) <= 1e-12` 时梯度为零，避免退化投影除零；梯度还被限制到 `±0.003/max(texelSize)`。中心接收深度为 `zr = sc.z + shadowBias - 0.35*dot(abs(gradient),texelSize)`，每个偏移 o 的比较深度继续加 `dot(o,gradient)`。这样大过滤核采到斜面另一位置时，不会仍拿中心深度比较。常数 bias 和 receiver-plane bias 解决的问题不同，不能只把一个固定偏移加大。

### 搜索与过滤

采样盘使用黄金角 `2.39996323` 的 Vogel 分布，半径 `sqrt((i+0.5)/N)`，按屏幕 interleaved-gradient noise 旋转。完整规则可简化为：

```text
searchRadiusUV = 0.55*shadowRadius / shadowFrustumMeters
blockers = depth < zr + dot(sampleOffset,gradient)
无 blocker → 全亮
gapMeters = max(zr-averageBlockerDepth,0)*shadowDepthMeters
penumbraMeters = clamp(gapMeters*0.022*shadowRadius,
                      0.012*shadowRadius,0.60*shadowRadius)
filterRadiusUV = max(penumbraMeters/frustumMeters,1.25*texelSize)
lit = average(step(receiverDepthAtOffset,sampledDepth))
lit = mapEdgeFade(lit,2% border)
return mix(1,lit,shadowIntensity)
```

通常 8 次 blocker search，再做 10 或 16 次比较；不存在遮挡物时跳过后面的过滤。这里的 `0.022` 是为外观放大的太阳角度近似。正交方向光深度差乘深度范围后直接是距离，因此没有直接使用点光源 PCSS 的相似三角形分母。边界淡出也不是物理阴影，而是避免 shadow frustum 边缘跳变。

PCSS 的“搜索遮挡物 → 估计半影 → 可变核 PCF”结构可对照 [NVIDIA 原始集成白皮书](https://developer.download.nvidia.com/whitepapers/2008/PCSS_Integration.pdf)。本例是在这个结构上的方向光和美术改编，不是白皮书代码的逐项复现。接收面偏移与 PCF 的背景可对照 [GPU Gems 3 第 8 章](https://developer.nvidia.com/gpugems/gpugems3/part-ii-light-and-shadows/chapter-8-summed-area-variance-shadow-maps)，但本例没有使用该章标题中的 summed-area variance shadow maps。

## 3. 体积光：透射与散射一起累计

核心 [Y9，L35674](../source/extracted/bundle-1.js#L35674) 从半屏视距重建世界射线。积分上限是场景深度或 `uMaxDist`，天空只走最大距离的 55%。它读取太阳 shadow map 对每个采样点作一次可见性判断。

方向散射使用两瓣 Henyey–Greenstein 形状：

```text
HG(mu,g) = (1-g*g)/(4*pi*(1+g*g-2*g*mu)^(3/2))
phase = min(0.55*HG(mu,0.78)+0.45*HG(mu,0.25),1.15)
```

窄瓣强调朝太阳看的金色空气，宽瓣保留侧向光束；限制峰值是明确的美术控制。高度密度为 `shape(h)=0.30+0.70*exp(-max(h,0)/5.5)`，所以高处仍有 30% 基础密度。室内 box 将 extinction 乘 `1+dust`，同时减弱环境项。

```text
acc = 0; T = 1; previousDistance = 0
for i in [0,N):
    f = (i+1)/N
    end = maxDistance*f*(0.35+0.65*f)
    ds = end-previousDistance
    p = camera + ray*(previousDistance + ds*pixelNoise)
    extinction = sigma*shape(p.y)*(1+dust*insideBox(p))
    segmentT = exp(-extinction*ds)
    source = shadowedSun*phase*artisticNearWeight + ambientTerm
    acc += T*source*(1-segmentT)
    T *= segmentT
```

这是每段常量介质下的指数透射累计，前方的 T 同时衰减后方散射。代码没有独立求解多重散射、相机光圈或真实气溶胶参数。`nearWeight` 从近处约 2.3 降到远处 0.55，室内趋向 1.6，因此即便密度相同，光束亮度仍有人为距离设计。

采样点噪声按屏幕像素固定，不随帧改变；本段没有体积时间重投影。近端步距更小，降低近物体处漏采，但低步数仍可能有条带或遮挡泄漏。超出 raymarch 范围的非天空几何用两端高度密度平均估计光学厚度，再混向观察方向的地平线颜色，这是廉价续接，不是又一段阴影光束积分。

最终缓冲写 `(acc,T)`，合成为 `scene*T+acc`。把 alpha 当覆盖率做普通透明混合，会把语义颠倒。

## 4. SSAO 与深度引导滤波

[X9，L35641](../source/extracted/bundle-1.js#L35641) 不依赖场景 normal buffer。它从左右、上下邻点中各选与中心深度更接近的一侧，重建两个视空间差向量，再叉乘为 normal，以减少跨轮廓深度跳变污染。

采样半径 `R = radius*(0.6+0.4*clamp(z/12,0,1))`；投影后的 UV 半径限制为至少 3 个半屏像素、至多 0.14。螺旋覆盖三圈，每像素随机旋转。对样本位移 v 的贡献为：

```text
f = max(R²-dot(v,v),0)
contribution = f³ * max((dot(v,n)-(0.015+0.004*z))/(dot(v,v)+0.004),0)
AO = max(0,1-intensity*sum*5/(R⁶*N))
```

深度 70–140 m 逐渐回到 AO=1；近景标记与超过 140 m 的像素直接跳过。AO taps 依质量为 8/12/16，不是射线追踪或全局光照。

AO 与体积各做横、竖两遍 7-tap 双边过滤，[QM，L35731](../source/extracted/bundle-1.js#L35731)：空间权重为 `1-0.22*abs(i)`，深度权重为 `max(0,1-abs(z-z0)/(BLUR_TOL*z0+0.02))`。深度先截到 300，以控制远端权重范围。

全分辨率合成 [L35745](../source/extracted/bundle-1.js#L35745) 取四个半屏邻点，以双线性权重乘 `1/(0.015+abs(zh-z)/z)`，防止低分辨率雾和 AO 越过前景边缘。明亮像素再把 AO 强度最多减去 80%，遮蔽色略偏冷。这是合成规则，不能认为它精确地只遮蔽了 PBR 的环境漫反射项。

## 5. Bloom、光条与曝光为何必须分开

### 多尺度 bloom

[j9，L35800](../source/extracted/bundle-1.js#L35800) 每级读取 13 个位置。首级先形成五个局部平均组，再按 `K(c)=1/(1+0.08*luma(c))` 加权归一化，压低孤立极亮值；后续级使用固定归一化核。所有样本先限制到 `[0,400]`。

建立六级降采样，再以 9-tap tent 核逐级放大五次，[K9，L35820](../source/extracted/bundle-1.js#L35820)。每级结果是 `mix(highResolutionLevel,filteredLowerLevel,0.62)`。最终主图与 bloom 也是 `mix(scene,bloom,0.065)`，不是普通的加法亮斑。它对整幅 HDR 图生成金字塔，没有先用亮度阈值抠出“亮区”。

### 横向光条

[J9，L35830](../source/extracted/bundle-1.js#L35830) 是单独两遍 15-tap 水平 Gaussian 近似，权重 `exp(-x²/18)`。第一遍从 `down[2]` 取样，先减 `streakThreshold/max(exposure,0.2)`；第二遍阈值为零，进一步拉宽。最后以蓝色倾向和独立强度相加。

因此 bloom 与 streak 不能共用“一个阈值加一个强度”描述。光条是镜头空间卷积，材质各向异性是局部 BRDF，两者的方向和遮挡规则都不同。

### 测光和历史

[Q9，L35844](../source/extracted/bundle-1.js#L35844) 在 7×5 网格上取中心加权对数亮度，指数还原为几何平均，限制到 `0.002..40`。适应系数通常为 `1-exp(-dt/1.5)`，前两帧直接初始化。自动曝光乘数是 `clamp((0.12/adaptedLuminance)^0.85,0.6,2)`，再乘手动曝光。

同一个 1×1 缓冲的 G 存 12 点太阳深度遮挡结果，以约 0.12 s 常数平滑。它控制 flare 的出现与消失，不是场景颜色的时间抗锯齿。太阳在屏幕外、背后及刚被遮挡时都有显式行为，不能只画一个永远可见的亮圆。

## 6. ACES / AgX 混合与编码边界

[tk，L35891](../source/extracted/bundle-1.js#L35891) 接收线性 HDR scene、bloom、streak、污渍和适应纹理。重要顺序是：

```text
scene radial RGB offsets / ADS peripheral softness
→ bloom mix + dirt*bloom + blue streak + occlusion-tested flare
→ manual*auto exposure + flash
→ mix(ACES_Fit(HDR),AgX_Fit(HDR),0.25)
→ display-linear split tone / S curve / lifted blacks / saturation
→ vignette / damage / fade
→ clamp + piecewise sRGB encoding
→ store sRGB brightness in alpha
→ FXAA / sharpening / grain / dither
```

ACES 分支含输入矩阵、`c*1.3`、Hill 风格有理函数和输出矩阵；AgX 分支含 Rec.2020 变换、inset、`[-12.47393,4.026069]` 的 log2 曝光范围、六次多项式对比、独立 look power/saturation、outset 和 gamma 处理。两者分别输出到可混合的显示线性范围，再进行手动 sRGB 编码。这里是项目的拟合与艺术组合，不应描述为标准 ACES 输出变换或完整 Blender 色彩管理。

FXAA [L35998](../source/extracted/bundle-1.js#L35998) 读取 alpha 中的 sRGB 亮度，强对比时沿估计边缘方向增加采样；锐化在强边缘处退让。grain 随时间和亮度变化，最后额外加入约一个 8-bit 级别的静态 dither，避免渐变色带。移植时若让引擎再执行一次 tone mapping 或 sRGB 转换，整条链的亮度、颜色和阈值都会改变。

Godot 可以用原生 tone mapper/glow 做同类近似；精确复现这条顺序需要独立输出链路。不能把整个终端 shader 放进 spatial `fragment()` 并期待引擎后处理自动等价。

## 7. 微法线方差与开孔覆盖率

[粗糙度补丁 L39472](../source/extracted/bundle-1.js#L39472) 读取 mip 过滤后的 normal，解码后不先归一化，取长度 `L`：

```text
varianceProxy = clamp(1-L,0,1)
roughness = sqrt(roughness²+0.6*varianceProxy)
```

彼此差异很大的 normal 被平均后长度缩短，用额外粗糙度表示未解析的方向变化。若 normal 的每级 mip 都提前归一化，这个统计信号会丢失。代码只在普通切线 normal 路径启用，没有给三平面分支同样补偿。它是 Toksvig 类思路的近似，本例未标注论文来源，不能声称逐项实现了某个命名算法。

[线网 LOD L39459](../source/extracted/bundle-1.js#L39459) 则估计 `lod=log2(max(fwidth(uv)*512))`。阈值从 0.5 随 LOD 降低，使更多微细线段保留下来；LOD 3.5–5.5 逐渐混向屏幕噪声阈值 `0.05+0.8*IGN`。同时 RGB 随 LOD 降至 45%，避免幸存采样代表过大面积而形成白片。

这是一套覆盖与能量的美术补偿，不保证严格平均覆盖守恒，也没有 TAA。硬编码 512 对非 512 纹理的足迹估计会偏移，应在复现时改为实际纹理尺寸。屏幕固定噪声的运动观感必须实机检查。

## 8. 平面反射与斜裁切

[Uw()，L56157](../source/extracted/bundle-1.js#L56157) 创建 half-float HDR target，带 mipmap、无 MSAA。主相机位置 `(x,y,z)` 镜到 `(x,-y,z)`，观察目标和 up 的 y 分量也取反；低于平面附近 0.03 m 时关闭反射。

先构造投影纹理矩阵 `bias * reflectedProjection * reflectedView`；再把世界平面 `y+0.01=0` 变到反射相机空间，用它替换投影 near plane。按源码的列主序规则：

```text
q = ((sign(plane.x)+P[8])/P[0],
     (sign(plane.y)+P[9])/P[5], -1, (1+P[10])/P[14])
c = plane * (2/dot(plane,q))
P[2]=c.x; P[6]=c.y; P[10]=c.z+1; P[14]=c.w
```

这对应 [Eric Lengyel 的 oblique near-plane 方法](https://terathon.com/lengyel/Lengyel-Oblique.pdf)：通过修改投影避免渲染镜面后侧的无效几何。本例 WebGL 投影的公式不能原样套进 Godot reversed-Z。

反射前隐藏地面、海面和雨，避免自反射和重复特效，`finally` 恢复可见性；另只渲染世界 layer，避免第一人称持物进入地面镜像。target 以质量比例缩放、宽高分别对齐 16/8。反射投影采样通过坡度扭曲和 mip LOD 表达从积水镜面到潮湿模糊的连续变化，但 mip blur 不是严格的粗糙 BRDF 卷积。

该 target 只绑定 apron 地面，不绑定海面。天空 PMREM、室内 cubemap、地面平面反射是三条独立来源。若只有一个总开关，调试时很容易把它们误认成 SSR。

## 9. 成本应怎样报告

以下是源码结构成本，不是 GPU 测量：

| 阶段 | 可确认的工作量 | 需要测量后才能判断的部分 |
| --- | --- | --- |
| PCSS | 每个受光片元 8 次搜索，发现 blocker 后再 10/16 次过滤 | cache、阴影覆盖、材质与 early return 带来的真实耗时 |
| SSAO | 半屏 8/12/16 taps，另有中心及邻域深度重建 | 高质量下瓶颈是否在深度纹理带宽 |
| 体积光 | 半屏 N 次积分，通常每步一次 shadow lookup | shader loop 与 shadow fetch 的重叠、阴影开关影响 |
| 双边模糊 | AO 与体积各横竖 7 taps | 减半分辨率后的带宽与边缘保真取舍 |
| bloom | 六次 down、五次 up；down 13 taps、up 9 taps 加一份 high | 各级尺寸快速缩小，不能简单按全屏 11 pass 估计 |
| streak | 两遍各 15 taps | 小缓冲但长跨度，实际采样局部性与带宽 |
| 平面反射 | 新相机重新绘制世界，生成 mip | 额外场景 draw 通常比一个屏幕滤镜更依赖几何复杂度 |

性能结论必须附设备、分辨率、质量、实际启用分支与采样方法。CPU 帧间隔不等于 GPU pass 时间，软件渲染器结果也不能当作独立显卡预算。
