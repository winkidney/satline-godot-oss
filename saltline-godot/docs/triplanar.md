# 原三平面法线与骨骼坐标

源实现见 `../../artifact-rendering-study/source/extracted/bundle-1.js` 的 hk/dk/pk/mk/gk/xk/vk 材质补丁（39343–39510 行）。顾问审阅见 [triplanar-adviser.md](triplanar-adviser.md)。

原实现使用静止姿态位置和法线计算三轴 UV 与 abs(normal)^6 权重。蒙皮只改变切向坐标轴：单位 X/Y 经混合骨矩阵及 model-view 转换后逐顶点归一化，片元再次归一化，再叉乘得到 Z；Z 不单独归一化。法线贴图的 XY 乘 normalScale，三平面路径没有普通 UV 路径的湿度衰减。

Godot 在用户 vertex() 前已蒙皮 VERTEX/NORMAL。因此原位置和法线分别保存在 CUSTOM1/2，避免把已变形位置当成贴图坐标，也避免重复蒙皮。BONE_INDICES/WEIGHTS 仍可读取原权重。共享 RGBA32F 图集保存 mesh-local 骨矩阵，实例参数选择各自起始行；18 个角色共 290 行，4×290×16 = 18560 字节。skeleton_updated 回调在骨骼更新后写入图集。普通生产路径不读取 GPU。

实现：`scripts/triplanar_palette.gd`、`scripts/source_scene.gd`、`shaders/source_triplanar.gdshaderinc` 与四个通用材质 shader。Standard 材质使用原三轴法线融合；Basic 保留不受光语义。材质 side 参数独立控制正反面和双面法线翻转。

现有证据：

- `evidence/skin-vertex-inputs-verification.json`：真实 Skeleton/ArrayMesh 验证原骨索引、权重、静止 CUSTOM 属性与原生蒙皮输入；NORMAL 压缩差约 3.92e-5。
- `evidence/triplanar-normal-verification.json`：直接提取原 vk GLSL，48 组、768 通道 GPU 对照通过，最大差 0.00048828125，预设绝对门槛 0.001。
- `evidence/triplanar-palette-verification.json`：290 个矩阵与原 Three attached-skin 矩阵对照，最大差约 1.49e-7；改变一个骨骼后首帧 GPU 图集与当前姿态一致，其他角色数据不变。

这些证据分别覆盖输入、公式和骨矩阵，不能替代完整动画画面验收。三轴纹理实际采样足迹、完整湿度/污渍/水珠/距离裁剪与非三平面切线基仍需继续对齐。

连续动画验收：`tools/verify_triplanar_animation.gd` 分别运行真实 Gull 与 Hound actor preview 150 帧，每 10 帧读取 GPU 图集并对照全部当前骨骼矩阵。两种角色均 15 次采样、14 次后续变化、最大差 0、零失败。对应 `evidence/triplanar-animation-gull.json` 与 `triplanar-animation-hound.json`。额外完整 Gull 600 帧预览正常退出，覆盖三次射击、转子损坏与坠毁；该流程记录为 `gull-runtime.json`。
