# PBR 和材质效果对比：审阅图与补拍方案

**状态：供审阅的历史截图与拍摄方案。** 下面的截图来自先前研究，不是本轮新拍；左侧为浏览器原版，右侧为 Godot 定制复刻。两边并非同步操作，截图仅支持所记录条件下的观察，不能证明全部场景像素一致。Godot 侧使用项目的定制 `ShaderMaterial`，不是官方 `StandardMaterial3D` 的开箱效果。[研究依据](godot-pbr-investigation.md)

## 1. 渲染测试工作台

原版与复刻都显示同一类金属度、粗糙度测试球、遮挡墙和地面。审阅时可以观察高光宽窄、墙边亮度与远处环境；画面相似不代表所有光照公式或其他场景已经一致。

| 原版 Three.js | Godot 定制复刻 |
| --- | --- |
| ![原版渲染工作台](../../saltline-godot/evidence/render-catalog-source.png) | ![Godot 复刻渲染工作台](../../saltline-godot/evidence/render-catalog.png) |

来源：[原版大图](../../saltline-godot/evidence/render-catalog-source.png)、[Godot 大图](../../saltline-godot/evidence/render-catalog.png)、[展示场景验证范围](../../saltline-godot/evidence/render-showcase-verification.json)。

## 2. 同一场景的干湿变化

原版与复刻各记录一次 `wet=0` 和 `wet=1`。先横向看同一湿度下的两种实现，再纵向看各自从干到湿的变化。注意砖墙、混凝土球与公共地面的颜色、反射和水痕。

| 状态 | 原版 Three.js | Godot 定制复刻 |
| --- | --- | --- |
| 干 `wet=0` | ![原版干燥材质](../../saltline-godot/evidence/material-catalog-wet-reference-dry.png) | ![Godot 干燥材质](../../saltline-godot/evidence/material-catalog-full-selection-dry.png) |
| 湿 `wet=1` | ![原版湿润材质](../../saltline-godot/evidence/material-catalog-wet-reference-wet.png) | ![Godot 湿润材质](../../saltline-godot/evidence/material-catalog-full-selection-wet.png) |

原版与 Godot 的历史记录均为第 12 帧，湿度分别固定为 0 或 1；来源分别是[原版记录](../../saltline-godot/evidence/material-catalog-wet-reference.json)、[Godot 干燥记录](../../saltline-godot/evidence/material-catalog-full-selection-dry-runtime.json)和 [Godot 湿润记录](../../saltline-godot/evidence/material-catalog-full-selection-wet-runtime.json)。[干湿响应统计](../../saltline-godot/evidence/material-catalog-wet-response.json)比较的是各自的干湿变化幅度，不是跨引擎逐像素验收。正式视频应核对当前版本后重新实录。

## 3. 正式视频拟追加的效果对比

1. **官方 Godot 标准材质能力**：在独立官方 Godot 4.7.2 样例中固定球体、光源、环境和曝光，只切换金属度与粗糙度；再分别演示清漆和方向性高光。标注“官方标准材质”，与项目定制复刻分开。这一实验尚未创建或拍摄。
2. **同一材质的实现选择**：固定贴图、灯光和视角，演示 Godot 官方材质的默认 Burley 漫反射与可选 Lambert 漫反射；原版和复刻的真实画面另行左右对照。画面若差异很小就如实呈现，不用调光夸大差别；仅切换漫反射模式不代表整套照明已等同。
3. **湿润与反射**：原版和复刻各拍干/湿切换；另用示意测试对照屏幕空间反射与镜像相机，让被反射物体离开主镜头后观察反射是否仍存在。固定摄像机、物体运动和曝光，并说明屏幕空间反射与平面反射的适用条件；该实验尚未建立。
4. **透明限制**：独立官方标准材质样例中展示两层透明物体的排序，以及折射无法看到屏幕外内容的情况。若使用深度预处理或其他替代方式，展示取舍并明确它不能保证解决所有半透明叠层；该实验尚未建立。

后续每组录制需保存引擎和渲染器版本、是否使用项目补丁、材质参数、模型/贴图、灯光、环境、曝光、相机和录制条件。原版与复刻左右并排并标注“非同步操作”；动画图解标“示意”。样例、实际游戏和旧版截图分开标识，不将实验室画面当成游戏原有功能。
