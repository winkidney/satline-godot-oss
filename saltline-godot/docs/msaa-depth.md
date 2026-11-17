# 原MSAA组合深度与默认工程取舍

原Three r180实际探针`tools/msaa_depth_reference.html`创建与原HDR相同的HalfFloat+UnsignedIntDepth MSAA4 target。世界写forward depth=.8，武器通过真实gl.depthRange(0,.05)把投影深度.4写为.02，随后按原renderer路径resolve。五种边缘、每种33个亚像素位置共165例，颜色coverage与depth均通过GPU Float32 copy读回。

参考ANGLE SwiftShader报告samples=4、SUBPIXEL_BITS=4、WEBGL_multisampled_render_to_texture=false。96例部分覆盖的颜色为.25/.5/.75，但depth只为.8/.02；平均、min、max规则分别与多例不符。边缘位置指向GL样本0的(.375,.125)。这是本机参考路径的实测，不是从blit NEAREST或GL规范推断全平台规则。原请求D24，实际底层物理精度未从请求格式强行推定。

`depth_samples_bridge.gd`在真实POST_TRANSPARENT读取引擎MSAA附件，以sampler2DMS逐sample存入自持R32F数组，不用Godot默认平均resolve。`combined_depth_bridge.gd`在武器capture之后，从同帧两张数组按sample合并：world=1-zW，weapon有coverage时候选=.05*(1-zV)，取min；空武器样本保留world。最后按原参考选择样本0写full-resolution R32F。游戏没有CPU回读。该R32F进入原half-depth、AO及太阳可见性，武器不再以any-coverage二值mask代替完整组合深度。

## 后端差异的判别实验

`verify_depth_samples.gd`用相同165例真实几何和MSAA4验证native每层数据及GPU合并；另保留--mirror、--quantize4诊断。汇总`evidence/msaa-depth-analysis.json`固定各report SHA。

| 配置 | 颜色coverage不匹配 | 样本0深度不匹配 |
|---|---:|---:|
| 正常native | 27/165 | 54/165 |
| 镜像相机后还原图像 | 6/165 | 2/165 |
| 镜像+仅诊断的4位屏幕顶点量化 | 0/165 | 0/165 |

NVIDIA Vulkan实际vulkaninfo报告subPixelPrecisionBits=8，原软件参考4。后两种判别实验分别解释样本位置方向和亚像素栅格精度差异。量化只用于诊断，不修改默认世界资产。捕获/GPU合并对native实际数据的全部断言均通过；表中源对照差异单列，不能把native捕获通过说成跨后端边缘全等。

## 默认路径决定

经[Astra镜像审查](msaa-orientation-adviser.md)，负basis虽有引擎剔除支持，但默认镜像会影响双面NORMAL、朝相机billboard等既有着色。默认保留原逐sample合并、depthRange、样本0规则，使用native正常MSAA采样，明确接受并记录该后端边缘位置差异，不强行模拟SwiftShader全部栅格细节。镜像和4位量化继续是隔离诊断，不进入产品链。原算法完整移植与跨驱动像素全等分别报告，未放宽容差掩盖差异。

默认已连接原AO，关闭过渡Godot SSAO；R32F half-depth、AO8三个阶段、joint-bilateral HDR scene composite按原顺序执行。详见[AO实现](ao-kernels.md)。体积光和其他尚缺效果仍继续迁移。
