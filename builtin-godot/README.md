# 官方 Godot 内建渲染对照

GitHub 精简版本保留本工程的源码和参数，未上传不属于游戏运行所需的预烘焙对照贴图；本机完整项目仍保留这些文件。缺少贴图时，官方内建对照不能直接完整运行。

此工程用官方 Godot 4.7.2、Forward+、`StandardMaterial3D`、内建灯光、SSAO、体积雾、泛光和屏幕空间反射，展示与原版相同的十个调试场景。它读取同一整合项目中的原版导出几何、贴图和姿态，不加载定制复刻的 shader 或定制引擎。

在整合项目根目录运行：

```sh
godot --path builtin-godot -- --scene=render
godot --path builtin-godot -- --scene=ground
godot --path builtin-godot -- --scene=weapon
godot --path builtin-godot -- --scene=render --diffuse=burley
godot --path builtin-godot pbr_lab.tscn -- --mode=pbr
godot --path builtin-godot pbr_lab.tscn -- --mode=diffuse
godot --path builtin-godot pbr_lab.tscn -- --mode=transparency
godot --headless --path builtin-godot --script res://tests/test_loader.gd
python3 builtin-godot/tests/test_baked_ground.py
python3 builtin-godot/tests/test_calibration.py
```

`--scene` 支持 `mats`、`props`、`render`、`ground`、`level`、`backdrop`、`enemies`、`weapon`、`hands`、`fx`。默认配置按场景使用固定曝光及实测的雾、泛光和 SSAO 参数；默认漫反射为 Lambert，`--diffuse=burley` 可切换 Godot 默认的 Burley。`--frames=120 --capture=/绝对路径/frame.png --report=/绝对路径/report.json` 可输出画面及实际参数，`--seconds=15` 可按经过时间结束。`ground` 默认启用屏幕空间反射，`--no-ssr` 可关闭。

`pbr_lab.tscn` 的三种模式分别展示金属度与粗糙度、Burley 与 Lambert 漫反射、透明图层；它们是独立教学场景，并非原作的额外调试画面。

原版部分颜色贴图的混色、手套纹理和湿地面是在离线阶段依据原版程序烘焙的；运行时仍由内建材质渲染。手套烘焙固定了一个湿度状态，地面烘焙固定了天气、时刻和观察位置；它们并非运行时程序生成的等价实现。`--wet=0..1` 对普通材质采用统一湿度近似；地面低于 0.95 时改用简化材质，避免把固定湿地贴图当成干地。

天空使用捕获的静态背景与环境贴图，色彩使用内建 3D LUT；海面波浪、平面反射、动态雨滴、手部织纹、程序化磨损、粒子与动画仍有差异。源画面与对照分别采集，机器人对照固定同一姿态。详细参数、离线烘焙方法、前后截图和已知局限见 [调校与质检记录](../docs/builtin-calibration.md)。
