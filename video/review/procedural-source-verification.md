# 原版程序生成与 Godot 导出资产核查

核查对象是项目内保存的 [原版 HTML](../../artifact-rendering-study/source/saltline.original.html)、从其活动脚本整理出的 [bundle](../../artifact-rendering-study/source/extracted/bundle-1.js)，以及 [Godot 复刻项目](../../saltline-godot/README.md)当前的导出和加载代码。本文根据代码及已有导出记录核对；本次没有重新运行游戏。

## 结论

- **原版确实大量使用程序生成。**例如叉车由代码组合几何部件并设置参数；许多材质贴图由着色器按照配方在 GPU 上生成，另有通过 Canvas 绘制的文字和标记。已有证据支持这些具体实现，不能据此断言所有资源都是程序生成的：原始 HTML 至少还引用了外部字体。
- **Godot 主要使用原版导出的场景数据，而非重新执行原版完整的模型和贴图生成器。**导出的是场景层级、网格数据、材质参数、纹理和骨骼等；Godot 再根据数据重建对应的网格、节点和材质。材质并非整个原版渲染器的原样复制，效果还需要 Godot 的着色器和渲染逻辑配合。
- **“Godot 没有程序生成”如果指全部内容，是不准确的。**Godot 中仍有实时计算的天空、海浪、雨、程序化动作和粒子轨迹；部分特效网格也在运行时由代码构建。准确的边界是：**没有把原版那套完整的模型和材质贴图生成流程搬过来；导出的基础数据与实时计算的效果共同构成复刻画面。**

## 逐项证据

| 范围 | 原版 | Godot 复刻 | 证据与边界 |
| --- | --- | --- | --- |
| 模型和场景 | 应用代码创建盒体等几何；叉车生成函数按参数组合车体、车轮和其他部件。 | 采集原版运行时场景的网格顶点、索引、变换等，加载时重建 `ArrayMesh` 和场景树。 | [原版盒体/UV 构建](../../artifact-rendering-study/source/extracted/bundle-1.js#L35091)、[原版叉车](../../artifact-rendering-study/source/extracted/bundle-1.js#L46510)、[导出场景和网格](../../saltline-godot/tools/export_source.cjs#L18)、[Godot 加载与组装](../../saltline-godot/scripts/source_scene.gd#L34)。这些证据说明被采集的内容，不证明源码中的每个对象均遵循同一种生成方式。 |
| 材质与贴图 | 材质配方定义参数和纹理集合；生成函数使用渲染目标产生颜色、ORM 和法线等贴图并缓存。材质还通过代码设置参数和着色器补丁。 | 从已运行的原版读取材质记录以及 GPU 上的纹理像素；经转换后加载对应纹理，创建 Godot 材质并绑定适配的着色器。 | [配方表](../../artifact-rendering-study/source/extracted/bundle-1.js#L39113)、[生成和缓存](../../artifact-rendering-study/source/extracted/bundle-1.js#L39595)、[材质创建](../../artifact-rendering-study/source/extracted/bundle-1.js#L39721)、[导出材质和纹理](../../saltline-godot/tools/export_source.cjs#L64)、[转换脚本](../../saltline-godot/tools/prepare_assets.py#L13)、[Godot 纹理和材质](../../saltline-godot/scripts/source_scene.gd#L205)。贴图按需生成并缓存，与材质在运行中实时着色是两件事，不能说原版每帧重做整套贴图。 |
| 文字与外部资源 | 一些标牌通过 Canvas 绘制；HTML 引用 Google Fonts。 | 导出的内容可包含原版绘制后的纹理，但字体引用提醒这一事实不能扩展为“原版没有任何外部资源”。 | [原版文字绘制](../../artifact-rendering-study/source/extracted/bundle-1.js#L38087)、[原版字体引用](../../artifact-rendering-study/source/saltline.original.html#L3)、[原版静态调查范围](../../artifact-rendering-study/docs/source-and-evidence.md#L30)。 |
| 骨骼与动态动作 | 原版场景导出器采集骨骼、绑定关系和姿态参考。 | 载入骨骼后，机械犬等仍按当前位置、目标足点和逆向运动学实时计算姿势。 | [导出蒙皮](../../saltline-godot/tools/export_source.cjs#L27)、[重建骨架](../../saltline-godot/scripts/source_scene.gd#L333)、[机械犬步态与腿部求解](../../saltline-godot/scripts/hound_pose.gd#L41)。这是在导出模型上生成动作，不等于重新生成整只模型。 |
| 天空、水、雨与特效 | 原版存在实时着色与动态更新；导出器也捕获用于环境光照的天空数据。 | 加载导出数据，同时运行动态天空、海面顶点位移、雨与粒子更新；曳光可运行时构建网格。 | [逐帧更新](../../saltline-godot/scripts/main.gd#L406)、[天空 shader](../../saltline-godot/shaders/dynamic_sky.gdshader#L8)、[海面 shader](../../saltline-godot/shaders/sea.gdshader#L20)、[粒子更新](../../saltline-godot/scripts/particles.gd#L16)、[曳光网格](../../saltline-godot/scripts/tracers.gd#L63)、[天空实现说明](../../saltline-godot/docs/sky.md)。可见天空是动态计算；其中用于环境光照的天空数据则有预先捕获的部分，不能笼统地说所有天空光照都每帧重烘。 |

## 原版数据怎样进入 Godot

1. 原版运行后，采集脚本遍历场景，记录层级、网格、材质、纹理引用、骨骼和光源等；网格属性和索引保存为二进制文件。见 [export_source.cjs](../../saltline-godot/tools/export_source.cjs#L18)。
2. 采集脚本把原版 GPU 纹理读取为像素文件，同时记录颜色空间、采样和尺寸等信息；另外捕获天空环境数据。见 [纹理读取](../../saltline-godot/tools/export_source.cjs#L69)和[天空数据导出](../../saltline-godot/tools/export_source.cjs#L86)。这一步拿到的是纹理数据，不是对整幅游戏画面截图。
3. 准备脚本转换纹理行顺序、保存 PNG 或 mip 数据，并调整三角形顶点绕序；同时生成 Godot 使用的场景记录。见 [prepare_assets.py](../../saltline-godot/tools/prepare_assets.py#L13)。
4. Godot 根据记录创建场景节点、`ArrayMesh`、纹理和材质，结合专门实现的 shader 与运行逻辑渲染。见 [source_scene.gd](../../saltline-godot/scripts/source_scene.gd#L34)。原版固定构造阶段的部分随机结果已导出，复刻恢复相应后续随机状态，而不是重复这些构造过程，见 [source_bootstrap.gd](../../saltline-godot/scripts/source_bootstrap.gd#L1)。

一次已有采集记录统计了 729 个节点、276 份网格、195 个材质和 132 个纹理，记录中没有未支持纹理或采集错误：见 [export-summary.json](../../saltline-godot/assets/export/export-summary.json)。这是该次采集的规模与状态，不保证覆盖游戏所有状态和未来版本。

## 对复刻和视频的意义

- 这条路线保留采集时的基础资源数据，便于把精力放在场景重建、材质与渲染行为的对应上；但它不自动带来原版生成器的全部可调参数或所有随机变体。例如道具目录目前是固定展示，其他种子/参数生成尚未接入，见 [项目说明](../../saltline-godot/README.md#L191)。
- 贴图数据相同也不代表最终像素必然一致：网格正反面、纹理方向和采样、材质、光照与后处理都需要匹配。采集和转换步骤本身就显示了格式转换的必要，见 [三角形绕序转换](../../saltline-godot/tools/prepare_assets.py#L40)和[动态天空说明](../../saltline-godot/docs/sky.md)。
- 画质选择也有明确范围：材质展示目录选择的是**已导出的**资产，运行中切换画质不会重新生成整套贴图。见 [画质说明](../../saltline-godot/README.md#L212)。
- 原版使用代码生成大量几何与贴图这一事实，并不单独证明 Godot 做不到同类程序生成；这里说的是**本次复刻选择和已经实现的路线**，不能直接等同于引擎能力上限。

## 建议加入的视频讲解

旁白建议：

> 原版的很多场景模型是用代码搭出来的，比如叉车由车体、车轮等部件组合而成。锈蚀等材质贴图也由程序在显卡上生成，并缓存起来重复使用。Godot 复刻采用了资源导出的路线：先从原版提取网格、纹理和场景信息，再在 Godot 里重建。原版完整的模型和贴图生成器并没有一起移植，但天空、海浪、雨水和机械犬动作仍然会实时计算。

MG 建议：左边依次出现“形状部件 → 组合模型”和“材质配方 → GPU 生成贴图 → 缓存”；中间一条导出箭头连接“网格 / 贴图 / 场景 / 骨骼”；右边显示“Godot 重建场景”，同时叠加一条“天空 / 海浪 / 雨 / 动作 → 实时计算”的动态分支。两侧放叉车或材质目录对应画面，避免将流程动画误作实机画面。字幕按本片约定去掉标点并以空格断句。
