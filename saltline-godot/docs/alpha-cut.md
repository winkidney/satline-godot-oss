# 原距离透明裁剪

原 `bundle-1.js` mk 的 SL_ACUT 块（约39465行）已提取到 `assets/export/fixtures/source-alpha-cut-original.glsl`，生产 helper 为 `shaders/source_alpha_cut.gdshaderinc`。它按 fwidth(UV)×512 估计LOD，降低近中距离阈值，再以原IGN屏幕抖动过渡至远距离覆盖，同时把存活片元亮度逐步降至 .45。主图原OpenGL像素坐标使用 Godot FRAGCOORD.y 翻转。

`source_scene.gd` 把原 SL_ACUT define 传入两个 chainlink 材质，保留 alphaTest=.5。四个generic shader共享裁剪逻辑；补齐 uSlUv.xy 乘数。原补丁 tint3 乘采样alpha，其他tint保留opacity/顶点alpha；未打sl补丁的普通材质仍采用正常map-alpha路径。

`tools/alpha_cut_reference.html` 执行原GLSL片段，`tools/verify_alpha_cut.gd` 调用生产helper。96组纹理footprint、贴图alpha和像素坐标，1536通道，绝对门槛 .001，零失败，最大差 .00048828125；见 `evidence/alpha-cut-verification.json`。这是公式对照，不是完整铁丝网实际UV导数、mip或MSAA采样一致性证明。真实场景100帧编译运行正常，无引擎错误。阴影depth材质未接此彩色片元补丁，仍按原固定alpha-test语义处理。

后续完整 source-sun-preview 360帧回归退出0，`source_sun_preview_failures=[]`，日志 `evidence/alpha-wet-regression.log` 无 SCRIPT/SHADER/ERROR/leak。该回归只证明集成运行与既有太阳开关验证未退化，不替代铁丝网画面验收。
