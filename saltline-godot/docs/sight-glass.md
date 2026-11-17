# 瞄具镀膜玻璃与准直准星

原先发黑的瞄具窗口来自导入器对未知ShaderMaterial的深色不透明占位。现在 `source_scene.gd` 按uBright/uTilt识别原作瞄具材质，绑定 `shaders/sight_glass.gdshader`，渲染优先级5、双面、不写深度、预乘透明、无额外雾。该材质已经从pending_shaders移出。

## 原始依据与迁移

来源：保存的活动脚本 `../../artifact-rendering-study/source/extracted/bundle-1.js:70143–70244`，ME多边形玻璃构造函数；原始入口 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。活动脚本SHA256为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。导出材质ID `fce6cd56-3237-4bcd-af66-86f908942da2`，网格节点 `8e7f44cc-264c-4925-894f-d51f18a4ffe7`，原始几何与UV保持不变。

`tools/port_sight_shader.py`从导出记录生成Godot片段公式；没有画替代瞄准贴图。主要机制：

- 在view空间比较观察方向与玻璃局部枪管前向轴，得到离轴角度的正切a；点、半径0.0128圆环、轴向刻线以该角度生成。点半径和环线宽由fwidth控制，保证分辨率变化时可读。uBright初值7，红色HDR辐射。
- world空间计算倾斜法线(0,-0.1,1)、反射方向和三次方菲涅耳；地平线/天顶颜色与太阳6次/90次方高光形成解析环境反射。此处原作本来不是实时反射贴图。
- 掠射角与UV改变薄膜相位，青/紫/琥珀镀膜随视角变化；对角反光带、边缘暗化、150×100程序灰尘网格、拇指擦痕及离轴发射器光晕一并保留。
- 输出col和alpha时保持原作premultipliedAlpha约定，使用Godot blend_premul_alpha；col不能再乘一次alpha，否则HDR准星会变暗。玻璃不写深度，保留原外壳遮挡。
- `sight_environment.gd`迁移原onBeforeRender的环境峰值历史、0值回退1、ratio阈值0.55/0.4、每渲染帧0.12插值。普通游戏在游戏更新后、渲染前更新；标题不更新不可见玻璃。

## 验证

| 证据 | 结果及边界 |
|---|---|
| `sight-source-verification.json` | 原导出片段公式除camera/output接口改名和移除原显示编码include外一致；不代表跨引擎色调映射已匹配 |
| `sight-environment-verification.json` | 实际执行原ME.onBeforeRender函数600帧，与原生1200值对照，0失败，最大误差1.11e-16 |
| `sight-blending-verification.json` | 真实Godot GPU使用同一shader顶点/render_mode，将片段临时设为固定辐射(.2,.1,0)/alpha .25；黑底约(.20156,.09990,0)，白底约(.94731,.84687,.75294)，符合col+bg×.75，最大误差.00313；8bit sRGB读回后转linear，允许.025 |
| `sight-glass-runtime.json` | 540帧完整原生场景，腰射/ADS/射击，世界相机74→52、武器54度；受控环境强度1→.3→1使镀膜反射平滑切换，shader正常编译、无占位 |

`evidence/native-sight-glass.mp4`为9秒/1280×720/60fps，无音轨。`sight-080.png`为腰射玻璃，`sight-200.png`为ADS准星，`sight-350.png`为受控低环境反射。原生Shader在完整场景中透明显示真实世界，ADS准星与枪管轴对准；腰射有离轴发光。

## 尚未完成

目前普通游戏的sight_environment_intensity默认1，测试入口显式切到0.3再回1。完整原作室内/遮蔽环境亮度系统尚未迁移，不能把受控反射过渡称作自动室内适配完成。原作tonemapping/colorspace include由当前Godot环境替代，完整曝光/体积光/bloom等后处理仍待校准；未做原作与Godot最终瞄具画面的逐像素比较。原武器连续弹簧/动态IK仍待迁移，此次只修复独立瞄具材质。
