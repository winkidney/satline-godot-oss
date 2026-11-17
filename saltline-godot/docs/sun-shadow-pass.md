# 原固定太阳阴影输入

本阶段实现`scripts/sun_shadow_pass.gd`和三个专用depth shader，为原Y9体积光提供真实world-only阴影数据。现已接入默认 Y9 体积光，端到端实机证据见 [volume.md](volume.md)。本页的独立阴影测试仅证明输入组件。

公开Godot4.7.2 API不能导出原生方向光shadow atlas/cascade，而原Y9读取固定单图。依据[Astra调查](volume-shadow-adviser.md)，使用独立World3D caster pass，不重新执行主场景PBR、灯光或屏幕后处理。复用原Mesh、MultiMesh缓冲、Skin/Skeleton3D，代理只同步变换和有效可见性。caster按已知source_id及当前world层/cast_shadow筛选，视图武器和无来源效果不混入。

## 原投影和阴影规则

`tools/sun_shadow_reference.cjs`直接提取原ZM函数，再调用原Three DirectionalLightShadow.updateMatrices，生成`assets/export/fixtures/sun-shadow-camera.json`，包含固定V/P/world-to-shadow矩阵及256点参考。

接收区域[-41,-.2,-33]..[37,32,31]，caster区域[-41,-3,-64]..[72,36,34]；width88.69879459、height54.78106061，near112.07668703、far253.95743746，位置(181.2694723,60.9170647,65.2251041)。原high4096²纹理覆盖非等比矩形。保守方形Camera.size取width，代理vertex修改PROJECTION_MATRIX的y对角乘width/height=1.61915074；不手写POSITION，不镜像相机，不改变原资产。

默认shadow side反转：可见FrontSide的阴影画BackSide，BackSide画FrontSide，DoubleSide画双面；显式shadowSide优先。alphaTest保持原map alpha×opacity，alphaMap按green数据字段；当前caster只有两种chainlink alphaTest=.5，alphaMap均null。原texture repeat/offset和采样方向保留。不透明caster跳过无用alpha纹理读取。没有加入材质接收端bias/normalBias，原Y9只在后续比较使用.0006。

专用相机POST_TRANSPARENT经既有GPU depth bridge输出R32F forward depth，nearest消费者将来取.r替代原packedRGBA解码，y只转换一次。只在帧前准备/发布R32F，回调不换wrapper。普通high按渲染帧偶数更新，其他帧保持已完成图；update(force=true)供ultra或截图参数语义使用，不等于武器开火。

## 验证

- `verify_sun_shadow.gd`：原Three实际非VSM packedRGBA8 shadowMap+原Y9 decode对照native独立caster R32F。使用原矩形frustum、诊断64²图，front/back/double、非对称alpha孔洞全部覆盖；4096像素0差异超阈值，最大depth误差8.95e-8，256点world-to-shadow最大误差3.63e-7。证据`sun-shadow-verification.json`。
- `verify_sun_shadow_animation.gd`：跨独立World3D共享实际Skin/Skeleton3D与MultiMesh实例缓冲，非周期bone/instance移动，检查偶数更新和奇数持有的GPU像素重心。8帧全部通过，1个骨骼平面及2实例，不冒充所有原角色动画验收。证据`sun-shadow-animation-verification.json`。
- `verify_sun_shadow_scene.gd`：真实prepared场景4096²，148个caster代理、142个MeshInstance含18个skin，以及6个MultiMesh；135个当时有效可见，unsupported为空。分层抽样262144点，86366点被遮挡，minDepth=.1813227。提交primitive960324与静态原可见caster三角形总上界一致。它证明实际源几何进入图，不是全原场景4096图逐像素对照。
- 两次创建/渲染/释放：基线GPU计数653598320字节，启用1313642032，新增660043712约629.5MiB；每次清理后均656630640，无逐轮增长。统计含引擎全部attachment/缓存，不只是R32F。冷/暖墙钟包括shader编译、读回及分析，不能当稳态GPU帧时间。每个更新帧150 draw calls、960324 primitives；正式Y9启用后仍需测实际GPU预算。

`sun-shadow-source-4096.png`是实际源caster阴影深度数据可视化，不是最终游戏截图。原始受控浮点图另存EXR。三份log归档无SCRIPT/SHADER/GPU ERROR或泄漏。

复现：先`rtk proxy node saltline-godot/tools/sun_shadow_reference.cjs`，三个GPU脚本用`rtk proxy env DISPLAY=:0 godot --path saltline-godot --audio-driver Dummy --display-driver x11 --script tools/verify_sun_shadow.gd`，按需替换animation/scene脚本名。原GPUfixture页面和采集器见tools/sun_shadow_reference.html、sun_shadow_gpu_reference.cjs。

## 后续接线

原high Y9需24步、原太阳辐射9×.85、阴影遮挡、棚屋密度、双相位散射、天空路程与远处解析延续，再经RGBA16F双向深度引导模糊和joint composite。默认已接原 shadow 更新节奏、Y9 每帧更新和首帧 ready 门控，producer 顺序已通过完整场景贡献检查。稳态完整 GPU 成本仍待测量。

阴影格式/跨后端栅格边缘、完整原4096场景图对照、多骨骼动态源角色长序列和真正稳态GPU成本仍需单列。当前两种原alpha-test材质和textureUV变换已覆盖，未宣称支持任意未来alphaMap独立UV变换或customDepthMaterial。
