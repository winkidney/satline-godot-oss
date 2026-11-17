# 官方 Godot 内建材质对照

这是独立的 Godot 4.7.2 Forward+ 对照工程。它读取同一整合项目内 `saltline-godot/assets/` 的原版导出数据，使用官方引擎、`StandardMaterial3D`、内建灯光及环境；不会加载定制复刻的私有 shader 或引擎接口。

在整合项目根目录运行：

```sh
godot --path builtin-godot -- --scene=render
godot --path builtin-godot -- --scene=ground --wet=1 --ssr
godot --path builtin-godot -- --scene=render --diffuse=lambert
godot --headless --path builtin-godot --script res://tests/test_loader.gd
```

`--scene` 支持 `mats`、`props`、`render`、`ground`、`level`、`backdrop`、`enemies`、`weapon`、`hands`、`fx`。可用 `--frames=90 --capture=/绝对路径/frame.png --report=/绝对路径/report.json` 在指定帧后保存画面和条件，也可用 `--seconds=15` 按经过的渲染时间结束；均不指定时持续运行。报告中的 `nodes` 是场景加载的源网格数量，不包含新增灯光和粒子。`--wet=0..1` 只对源数据中带湿度参数的普通材质施加统一变暗与粗糙度近似，不等于原版湿润算法。`ground` 默认启用内建屏幕空间反射，可用 `--no-ssr` 关闭，其他场景可用 `--ssr` 打开；默认使用 Burley 漫反射，`--diffuse=lambert` 只切换该项。

贴图沿用导出的原始颜色、法线和 ORM；原版没有保存切线，因此对带 UV 的网格生成切线。Godot 接收颜色、法线与 ORM 的方式、直接光和色调映射与原版存在差异。天空采用原版采样得到的静态环境图；海水、湿地和粒子使用内建近似，布料的细织纹与雨珠未移植。敌人展示使用记录的骨骼姿态，手掌使用原版姿态数学与内建材质；当前不等同于原版完整动态模拟。每次报告列出适用范围，不能将它当成原版像素一致或不同硬件性能结论。
