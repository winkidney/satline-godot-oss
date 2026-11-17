# Godot 内建渲染对照：调校与质检

本页描述本机完整项目的官方内建调校。GitHub 精简版本不含非运行所需的预烘焙对照贴图、截图及录像，文本参数和测量结果仍保留。

## 范围和条件

对照对象是原版 HTML 的十个调试展示与本项目的官方 Godot 内建展示，不代表对所有游戏或引擎版本的性能排名。原版使用 `q=high`，约 5 秒时记录相机、光照和自动曝光；Godot 使用 4.7.2 stable official `ed1daf0bf`、Forward+、Vulkan 和同一 NVIDIA GPU。原版与 Godot 在 1280×720 下分别采集，时间和粒子随机状态不完全相同。机器人原版使用 `efreeze=1`，匹配已导出的固定姿态；动态表演不是同步操作。

- [十场景对照图 1](../video/review/calibration/comparison-01.webp) · [对照图 2](../video/review/calibration/comparison-02.webp)
- [原版截图及采集条件](../video/review/calibration/source/) · [Godot 最终截图及实际参数](../video/review/calibration/final-calibrated/)
- [区域误差与原始配置](../video/review/calibration/final-calibrated/comparison.json)

最终使用真实项目默认启动路径采集。表中是截图主体矩形内的 RGB8 平均绝对误差，越小表示该矩形的像素越接近；它包含背景、姿态、曝光、粒子和时间差，**不是材质还原率，也不是主观质量评分**。初始列是调校前的内建对照；初始参考图保留在 `builtin-godot/evidence/`。

| 场景 | 初始 | 调校后 | 仍需说明 |
| --- | ---: | ---: | --- |
| 材质 `mats` | 53.17 | 8.66 | 动态湿润与细节仍是近似 |
| 道具 `props` | 61.44 | 6.33 | 雨珠与程序化细节未逐像素重现 |
| 光照 `render` | 29.29 | 13.99 | 阴影过滤、体积光和地表反射不同 |
| 湿地 `ground` | 29.99 | 12.98 | 固定状态烘焙，SSR 不等同原版平面反射 |
| 港区 `level` | 33.66 | 12.62 | 雾和泛光经过单场景调校，光束形状仍不同 |
| 港口 `backdrop` | 60.02 | 14.10 | 天空是静态图，船与鸟的动态未完全重现 |
| 机器人 `enemies` | 82.05 | 8.54 | 固定相同姿态；探照灯和动态效果不同 |
| 武器 `weapon` | 79.01 | 8.48 | 内建 SSAO 近似源遮蔽，枪体磨损仍不同 |
| 双手 `hands` | 84.17 | 7.54 | 固定姿态及烘焙纹理，动态雨珠和微法线不同 |
| 特效 `fx` | 84.37 | 12.92 | 均值受背景影响很大；烟雾、弹痕、火花和爆炸仍有明显差异 |

## 确认过的问题及处理

### 曝光、环境光与颜色

原版分别使用背景天空和环境光天空，并以自动曝光驱动后处理。对照工程修正了全景方向，分别加载两张捕获图；相机曝光按各展示原版约 5 秒时的数值固定。太阳线性色与方向来自原版；太阳能量采用 `9 / π` 的初始换算，再用太阳和环境光分开采样检查。采样仍保留源 SSAO、体积效果和后处理，因此不是严格的线性 BRDF 分离。环境光强度经扫描选择 1.45，不能直接把不同引擎中名为 intensity 的数值视为等价。

原版的 ACES、AgX 混合与静态调色使用 Godot 内建的色调映射和 3D 颜色查找表近似。查找表由 `builtin-godot/tools/` 的脚本生成，并非在运行时调用原版 shader；截断后的高亮信息不可完全恢复。GPU 色卡检查中，四个未严重截断的混合色样最大通道误差约 0.00681（0–1），并验证线性灰卡、HDR 贴图和黑场抬升。色卡结果不能证明整张画面一致。

### 武器遮蔽

弹匣明显过亮不是材质基础色错误。固定曝光 0.706 时，原版同一像素开启源 SSAO 为 `[54, 50, 42]`，关闭源 SSAO 为 `[172, 138, 93]`；此前 Godot 约为 `[170, 136, 90]`。原版的遮蔽还会影响直接光，且强度随像素亮度和曝光变化。

官方 Godot 在此工程中同时设置 `ssao_light_affect` 和 `ssao_ao_channel_affect`，并扫描半径与强度。仅改前者在实际渲染中没有起效；[官方 4.7.2 对应版本 shader](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1858-L1866)中的参数组合说明了原因。`radius=0.5、intensity=8` 对枪身、弹匣、手套的多个区域较均衡；湿地使用较弱的 `intensity=1`，避免整体过暗。两种 SSAO 的算法及原版对第一人称独立渲染通道的处理仍不同。

[原版 AO 开关实测](../video/review/calibration/ablation/) · [Godot SSAO 扫描](../video/review/calibration/ssao-channel-1/) · [原版片元输入与光照分量](../video/review/calibration/weapon/source-fragment.json)

### 地面、手套与透明特效

湿地面的颜色、粗糙度和法线从原版地面程序在约 5 秒、湿度 1、固定相机位置下离线烘焙，再由 `StandardMaterial3D`、贴图与内建 SSR 渲染。扫描后粗糙度贴图下限为 51/255，材质高光 0.25、线性底色倍率 2；这些是针对该机位的美术调校，不是原版参数。原版随天气、位置和时间变化的积水、波纹及平面反射没有被静态贴图取代。

手套原几何没有 UV；离线运行源表面函数后按三角形烘焙颜色和粗糙度图集，保留原网格骨骼权重，运行时使用内建材质。对法线强度 0、0.1、0.25、0.5、1 的截图测试中，强法线产生明显接缝，当前默认关闭。贴图图集的固定状态、过滤与接缝仍限制近景效果。

早期内建对照使用的天空球在透明物体之后绘制，遮住了雨与烟；修正绘制顺序和雨粒可见包围盒后，新增 GPU 回归测试验证它们在截图中确实可见。烟团、曳光、闪光和地面受光由 Godot 内建粒子、精灵、材质和灯光近似；它们不是源特效的一比一移植。

### 体积雾与泛光

测试了多组官方内建体积雾和泛光。按截图区域误差，港区选择体积雾密度 0.04、泛光 0.7；湿地选择 0.02、0.7；远景使用 0.005、0.3。材质、道具、手与特效使用较轻的雾；光照、机器人和武器展示不启用，以避免局部回退。参数与截图保存在 [atmosphere](../video/review/calibration/atmosphere/)；固定参数无法完整复现源程序随画面亮度变化的散射与光束。

## 复现与检查

需要 Linux x86_64、官方 Godot 4.7.2、Forward+ 可用的 GPU、Python 3、NumPy、Pillow，以及用于原版采样的 Chrome 和 Playwright。`GODOT_BIN` 可指定官方 Godot 可执行文件；Node 的 `NODE_PATH` 需能找到 `playwright`。涉及窗口的命令应在独立 X 显示会话执行。

```sh
python3 builtin-godot/tests/test_baked_albedo.py
python3 builtin-godot/tests/test_baked_ground.py
python3 builtin-godot/tests/test_calibration.py
godot --headless --path builtin-godot --script res://tests/test_loader.gd
xvfb-run -a -s '-screen 0 1280x720x24' python3 video/tools/validate_builtin_scenes.py --defaults --output final-calibrated
python3 video/tools/make_calibration_sheets.py
```

GPU 透明效果检查：将 `test_transparency.gd` 分别以 `--scene=ground`、`--scene=fx` 运行；`color_probe.gd` 检查颜色与 LUT。原版与 Godot 的采样、消融、材质烘焙脚本及记录保留在 `video/tools/` 和 `builtin-godot/tools/`。中间扫描保留当时的设置和结果；之后的天空排序、粒子与默认值修正会影响重跑结果。不同 GPU、浏览器、驱动和录制时刻也可能改变结果。

调校后录屏位于 `video/recordings/showcases/builtin-calibrated/`，画面以固定步长逐帧输出，并非实时帧率；`video/review/comparisons/` 对照图已使用新版。旧版 `video/recordings/showcases/builtin/` 是调校前素材。原版及衍生资产的再发布授权尚未核实，本项目保持本地或私有状态。
