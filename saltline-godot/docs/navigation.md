# 原作导航迁移

`SaltlineNavigation` 按活动HTML的physics.nav直接迁移，不使用重新烘焙的Godot导航网格替代原作路线。

网格为142×124，共17608格，格宽0.5米，原点(-40,-32)。障碍按0.5米膨胀，忽略noNav、bulletOnly、过低或高于1.5米的碰撞盒，并封锁边缘及码头外区域。起终点若阻塞，则在最多12格半径内依原作顺序寻找可行单元。

A*保留8方向邻居顺序、1/1.4142代价、Float32累计代价、二叉最小堆相同平局顺序、9000访问上限。对角移动与直线平滑均禁止切过阻塞拐角，路线按最远可见节点简化。动态物理盒数量变化后自动重建；同数量但改变盒位置时需显式调用rebuild，后续动态障碍控制必须保留这一约束。

`tools/navigation_reference.cjs` 从真实原作运行时导出网格及24对起终点，覆盖三个任务继电器、撤离点和随机路线。`tools/verify_navigation.gd` 检查阻塞图、可达性、clearLine、路点数量及全部路点，并验证移除障碍后的重建。结果为17608格零差异、24条路线全部一致、路点误差0。参考保存在 `assets/export/fixtures/navigation-reference.json`，结果为 `evidence/navigation-verification.json`。

随机巡逻点保留24次圆盘采样和最近可行格回退。Main现注入与FX/天空雷电方向相同的fx_random，不再使用固定seed4207独立PCG。原实际nav与fx.smoke交错的136次tape消费及落点一致，见navigation-random-verification.json；默认未记录的浏览器熵不逐值重现。

源代码：`../artifact-rendering-study/source/extracted/bundle-1.js` 39914附近的常量，40190附近的findPath接口，40230–40370的网格/直线检查/最小堆/A*。当前模块已绑定共享物理索引；后续敌人状态机和骨骼已接入，见enemy-implementation.md。导航网格本身的验证仍不等同完整AI验收。

## 敌人可复现随机流

`SaltlineSourceRng` 迁移活动源码34783附近的su Mulberry32及range/int/pick/sign/fork。使用16位分段乘法保留JavaScript Math.imul的低32位语义，避免64位有符号乘法溢出。内部显式调用self.randf，避免Godot同名全局函数改变消费序列。

原作Node参考由 `tools/rng_reference.cjs` 直接提取并执行su函数。四个种子0、1337、4207、4294967295的父流、fork子流和父流继续输出共1152个32位整数逐值相同，无容差。使用32位整数而非JSON小数对照，避免JSON小数读取的末位舍入影响判定。证据为 `evidence/rng-verification.json`。

后续已对齐正常启动的root与四子流账本，见source-bootstrap.md；原本使用浏览器Math.random的效果与导航随机点不能仅由su一致推断逐个相同。敌人逐帧回归必须注入一致的随机流并记录消费顺序。
