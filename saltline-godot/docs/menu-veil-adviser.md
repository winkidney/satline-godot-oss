# 菜单遮罩的剩余字节差异

本次只读核对原 CSS、当前 shader、Main UI verifier、PNG 和 Godot 本地源码，没有运行 GPU 或修改生产。当前更值得检查的是 Chrome 渐变绘制时的预乘色、中间图像及取整，不是继续调整 opacity 曲线或随意更改颜色端点。

## 正确的合成结构

[原 CSS](../../artifact-rendering-study/source/saltline.original.html:197) 是同一 `.m-veil` 上的两层 background，横向层在上，纵向层在下，最后应用整个元素的 opacity。[CSS Color 的 opacity 定义](https://drafts.csswg.org/css-color-4/#transparency) 也规定对元素整体合成结果应用透明度。

两层 RGB 相同，因此无限精度下可以写成：

```text
a = ah + av * (1 - ah)
premultiplied_rgb = (6,8,10)/255 * a
group_rgba = (premultiplied_rgb, a) * opacity
```

当前单 shader 先合并 alpha、再由 `modulate.a` 整体调制，数学结构成立。不要改成先将两个 alpha 各乘 opacity 后再 source-over；那会改变重叠区域的透明度。右下 `(1216,680)` 已在横向渐变 72% 终点之外，`ah=0`，仍有差异，也不能由两层重叠顺序解释。

## 已有排除证据

- [报告](../evidence/menu-veil-verification.json) 为 144 个像素采样、18 个中断/反转采样。透明度最大误差约 `4.34e-7`，剩余两个超阈值点均为 title、opacity `.8`；本次不调整 `1.1/255` 门槛。
- 右下 title：opacity `1` 两端都是 `(101,102,103)`；opacity `.8` 原为 `(130,131,133)`，Native 为 `(132,133,134)`。但同一坐标的单色 paused `.62` 遮罩在这两个 opacity 值上均与 Native 逐字节一致。故全局 blend、整体 opacity 传递错误的优先级较低。
- ColorRect 走 `TYPE_RECT/SHADER_VARIANT_QUAD`；[InstanceData.modulation](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/renderer_canvas_render_rd.h#L356-L373) 为 `float[4]`，[赋值](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp#L2517-L2520) 也直接保存 float。这里没有 UNORM8/half 的 modulate 打包；`.8=204/255` 本身还可被 UNORM8 精确表示。
- 参考的静态像素用 `transition:none` 和显式 opacity，不依赖过渡推进。因此“截图恰好处于错误插值时刻”不是首要解释。opacity=1 白底结果相同也不证明两边透明 RGBA 中间值相同。

`209/255、128/255、179/255` 目前只是改善端点差异的量化假设，尚不能证明 Chrome 恰在这个阶段量化原 `.82/.5/.7`。先固定当前实验条件，不继续以两点残差拟合端点。

## 只建议一个最小实验

在同一 Chrome 页面、同一尺寸和 DPR，对比 A/B：

1. A 保留原双 gradient，元素 opacity `.8`，白底。
2. 将原双 gradient 在 opacity `1`、透明页面背景下捕获为透明 RGBA PNG。B 用这张图作为同尺寸、不缩放的 img，元素 opacity `.8`，白底。背景不得预先混入白色；截图应使用 `omitBackground` 并明确覆盖 html/body 的背景。记录 computed opacity、元素 rect、DPR 和图像尺寸，仍只比较现有失败点及其邻域。

若 B 重现 A，说明显式 RGBA 中间合成足以解释当前结构差异，可再把 Native 改为两层先画入透明 SDR 目标、随后整体调制，并核对实际预乘/取整。若 B 不重现 A，则 Chrome 将 opacity 下推到渐变绘制、渐变抖动或采用不同精度路径仍是候选；增加普通 RGBA8 SubViewport 不会自动解决，不应先提交该结构改动。

本次读取时部分原有 PNG 与报告的两点失败名单并非完全一致，可能正在被并行实验覆盖。上面的已知失败数字按当前报告和指定点记录，不把额外 PNG 差异升级成新的稳定结论；下一次实验应成套保存 PNG、报告与 hash。
