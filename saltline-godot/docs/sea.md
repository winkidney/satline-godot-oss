# 原生海面材质

## 原作依据与资源

原始入口 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。保存活动脚本 `../../artifact-rendering-study/source/extracted/bundle-1.js:56262–56491`：Og/Bw/Hw、CP/kP/PP、zP/DP和Ow。活动脚本SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

复用原海面节点b7bbc842-ab5d-46a7-af1b-8e491392b8b7、13620顶点的ee1a3064几何、材质0066994d，以及原detail与detailN纹理（f2f39fc7、1b8032b3）。导出网格本来就是近岸稠密、远方渐疏的非均匀网格，未以一张低面数平面代替。`source_scene.gd`按sea材质名绑定 `shaders/sea.gdshader`，原时间uniform加入现有timed_materials，暂停时与场景材质一起冻结。

## 已迁移公式

`tools/port_sea_shader.py`从已导出的原onBeforeCompile补丁抽取顶点位移块与完整表面块，保留数值常量和纹理采样：

- 4组大波，波长9.5/5.7/3.3/2米，振幅0.06/0.04/0.026/0.016米；水平位移是振幅0.6倍。距(30,0)的50–220米平滑衰减。原GLSL由5位小数常量生成，未拿全精度Hw冒充渲染公式。
- 4组大波斜率与7组细波斜率；细波25–110米衰减，3路原detailN的BA通道增加不同速度、方向与尺度的微法线。
- 距码头x=30和停泊船体圆角距离场的泡沫与污沫；原detail多通道控制破碎泡沫带、颜色、局部粗糙度和法线减弱。不是屏幕贴图。
- 多尺度风斑与长涌浪改变颜色、粗糙度、波面斜率和碎高光强度；按观察方向与太阳水平夹角约束glitter。
- 原地平线雾色在向阳/背阳方向混合，220–860米渐变到80%haze。通过Godot FOG输出接到光照后的颜色阶段。

## 光照适配及未完成差异

Godot材质输出原albedo/roughness和view空间解析法线，使用原始天空环境图作为反射。自定义light使用Lambert、GGX分布、Smith相关遮蔽、原Schlick近似Fresnel，加入gSpark/太阳方位调制与40的直接高光上限。

这部分仍是适配层：Godot LIGHT_COLOR/光照能量与原Three未校准；原作对汇总directSpecular截断，当前在每光源回调截断，多光源极亮时不同。原gOcc同时乘IBL irradiance/radiance且可略高于1；当前通过Godot AO桥接并夹0–1，不完全等价。原作geometry roughness、全局雾、最终曝光与后处理也未逐像素匹配。当前不是实时海面平面反射或折射，原海面此处本来使用PBR环境反射。

Hw全精度水面高度用于原作其他系统，当前native物理/特效并未全面接入该动态高度；不能把渲染位移通过称作全部水面交互已完成。

## 验证与实机

- `evidence/sea-source-verification.json`：原顶点位移块、完整表面块在Godot接口/采样函数改名后保持原式；纹理沿用已采用的WebGL→PNG纵向采样转换。这个静态检查不证明光照适配一致。
- `tools/sea_reference.cjs`执行原Og/Bw初始化及实际CP生成式，从原GLSL常量计算72组参考位移，覆盖近岸、衰减、远海与多个时刻。原Hw使用全精度常量，与同点原渲染公式本来就有微差，样本最大约3.13e-5米。
- `tools/verify_sea_gpu.gd`实际运行native海面顶点代码，仅将采样世界坐标设为受控uniform、将位移编码为输出颜色读回。`sea-wave-gpu-verification.json`：72组0失败，最大1.652毫米；8bit sRGB编码/读回，容差4毫米。没有用重写的CPU函数代替GPU顶点证据。
- 历史 `evidence/sea-runtime.json` 与 `native-sea.mp4`：修复码头闪烁前的完整场景480帧、8秒/1280×720/60fps，无音轨；三段镜头覆盖码头边、近岸泡沫与开阔海面日光方向。`sea-060.png`近岸看向太阳、`sea-220.png`泡沫带、`sea-380.png`开阔海面。运行日志无shader/script错误。

复现GPU探针需图形环境：`rtk proxy env DISPLAY=:0 godot --path saltline-godot --audio-driver Dummy --display-driver x11 --script tools/verify_sea_gpu.gd`。整体光照/天气/后处理与原作画面验收仍保持未完成。

## 码头边缘闪烁修复

近岸镜头中的码头混凝土墙与远景地基侧面都位于 `x=30`。两片不透明表面在同一深度争抢画面，墙面因此在相邻帧切换材质。远景地基来自原版的 [Pe 盒体](../../artifact-rendering-study/source/extracted/bundle-1.js#L55135)，并非海面波浪或视频编码造成。

复刻加载详细码头墙的导出网格时，只把重合侧的 24 个顶点向海侧移动 5 毫米，使码头墙稳定显示在前方。地基和其他顶点不变，导出的原始顶点文件没有改写。曾尝试整体后移地基，但 2 厘米会与下方墙面再次重合；6 厘米虽消除闪烁，却改变了下方墙面的外观，因此均未采用。此调整针对当前导出网格；重新导出后应复核网格身份和重合关系。

`tools/tests/verify_quay_overlap.gd` 在实际场景加载后检查 24 个顶点均已分离、其他顶点未改变。`video/tools/check_quay_flicker.py` 跟踪 `--sea-preview` 机位中近、远处墙面的上下四个区域，检查第 165–319 帧的相邻亮度变化。720p 对照中，近处上层修复前平均／最大跳变为 22.28／54.71，修复后为 0.06／0.74；其余三个区域的最大跳变不超过 0.56。远处下层与修复前的同帧 RGB 平均差为 0.545/255，说明这组采样中的下层外观基本保留；这些都是局部检查，不代表其他位置均无闪烁。[动态对照](../../video/review/quay-flicker-comparison.mp4)和[静态对照](../../video/review/quay-flicker-before-after.webp)保存在本地。原版同机位参考保存在本地 `evidence/main-paired-high-pier-flicker-source.png`，采集参数在同名 JSON 中。

在项目根目录执行以下检查：

```sh
xvfb-run -a -s '-screen 0 1280x720x24' saltline-godot/engine/godot --audio-driver Dummy --display-driver x11 --rendering-driver vulkan --path saltline-godot --script res://tools/tests/verify_quay_overlap.gd
python3 video/tools/check_quay_flicker.py video/recordings/godot/sea-quay-fixed.mp4
```

重录素材、固定步进限制与复现步骤见[录制条件](../../docs/recording-evidence.md#码头修复后重录)。原有 `evidence/native-sea.mp4` 保留为修复前历史证据。
