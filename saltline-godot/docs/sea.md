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
- `evidence/sea-runtime.json`与 `native-sea.mp4`：完整场景480帧、8秒/1280×720/60fps，无音轨；三段镜头覆盖码头边、近岸泡沫与开阔海面日光方向。`sea-060.png`近岸看向太阳、`sea-220.png`泡沫带、`sea-380.png`开阔海面。运行日志无shader/script错误。

复现GPU探针需图形环境：`rtk proxy env DISPLAY=:0 godot --path saltline-godot --audio-driver Dummy --display-driver x11 --script tools/verify_sea_gpu.gd`。整体光照/天气/后处理与原作画面验收仍保持未完成。
