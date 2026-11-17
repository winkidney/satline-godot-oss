# 地面查询、积水与玩家运动效果审查

本轮高质量 1024 mask 查询、积水优先分类和 step/land FX 接入通过已列验证，未发现该范围内的生产阻断。玩家 surface resolver 仍是原 H 的部分迁移，`groundSurfaceAt/metalRects` 尚未接入；当前结果不能表述为完整地面材质分类已对齐。本次只读审查，只新增此文档。

原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 第 55552–55602 行的 Dw/Bg、第 56767–56817 行的 Vg 查询、第 68984 行附近玩家 H，以及第 60263–60303 行的 step/land 回调。实现见 [ground_queries.gd](../scripts/ground_queries.gd)、[impact_effects.gd](../scripts/impact_effects.gd) 和 [Main 接线](../scripts/main.gd)。

GroundQueries 读取当前场景唯一 uMask 绑定所指向的原始 RGBA byte 文件，保留原数组方向，不经过 PNG 翻转、纹理过滤或 sRGB 转换。Bg 的世界范围为 x=`−44..36`、z=`−40..40`，采样坐标有 `−.5` texel 偏移，上限仍为 `resolution−1.001`。Native 按原运算顺序对四个 byte 双线性插值并除 255。

`puddle_depth` 对 x>30、范围外或室内返回 −.2，否则返回 `.5−red`。`is_puddle` 使用严格 `>.015`。室内只检查 XZ，盒边界和世界范围均严格排除边界。`wetness_at` 的判断次序也保留原文，先 x>30，再室内，再范围外，最后用 red/green 和原 smoothstep 计算。该次序决定重叠区域的结果，不能随意合并条件。

[query 参考](../tools/ground_query_reference.cjs) 先执行原 Dw 重建 1024² RGBA，再与历史 uMask raw 逐字节比较，随后用重建数组执行原 Bg/Vg methods。当前资产 SHA 与重建结果完全相同。包装层的 smoothstep 与原 ST 公式相符，Fi/Kn 常量已核对。Native 测试另检查实际加载 mask 的 SHA，并比较四个通道、depth、wetness 与 puddle 布尔值，独立计数为 `12879×7+1=90154`。

Main 创建同一 query 并分别交给 player surface resolver 与 FX。玩家 resolver 保留原 H 的水优先规则 `player.y<.05 && is_puddle(x,z)`，随后暂时回退碰撞 surface 或 concrete。原 H 在非水、接触 surface 为 concrete 或空值时还调用 level.groundSurfaceAt，当前没有该 metalRects 查询。

Impact 在 normal 归一化后，仅对非 enemy/water、`normal.y>.7`、积水且 `hit.y<.08` 的命中改为 water。它返回最终 surface，Main `_impact_visuals` 用命中字典副本传给 decals，因而 water 不再留下弹孔，同时不会修改 Combat 的原命中记录。既有 enemy 分类仍由 Combat 提供。两个高度阈值 `.05` 与 `.08` 来自不同原调用，不应统一。

原 step 回调优先用 payload.pos，缺少时用 player.pos，water surface 或 XZ puddle 任一成立即发 splash，步行 scale=.4、冲刺=.55。原 land 始终使用当前 player.pos，忽略 payload.pos；water 时 scale=.9，否则只有 speed>5 才发六个 dust puff。两者生成位置的 y 都取 max(0,y)。这些回调直接查 XZ puddle，没有玩家 H 的 y<.05 门槛，当前保留了这个原行为。

[motion 参考](../tools/ground_motion_reference.cjs) 字面执行原 callbacks 和 splash/puff helpers，并使用已独立验证的原 query。wet/dry 点从 fixture 选择，但期望值重新运行原代码，没有复用 Native 分类结果。每档容量含 7 次 step、5 次 land 和 3 次 clear。payload/fallback 位置差异、water 优先、speed=5 不发射而 5.0001 发射、负 y clamp 和 y=2 的 XZ puddle 行为均命中。y=2 用例是回调规则测试，不是实测屋顶碰撞。

| 证据 | 结果 | 可支持的范围 |
| --- | --- | --- |
| [地面查询](../evidence/ground-query-verification.json) | 12879 点、90154 checks；失败 0；最大误差 `1.11022302462516e-16`，阈值 `1e-10` | 原 1024 mask、四通道 Bg、Vg 查询及空间边界 |
| [运动回调与生成](../evidence/ground-motion-verification.json) | 2 容量 × 15 操作，12750 checks、1818 draws；失败 0；最大误差 `2.38418579101562e-7`，阈值 `2e-6` | 同 u53 tape 的原 callbacks、查询与粒子初始字段 |
| [既有完整 A 回归](../evidence/impact-random-verification.json) | 353470 checks、56727 draws，失败 0 | 原有八类发射路径；该受控测试仍不注入 puddle query |
| [最终实机接入](../evidence/ground-runtime.json) | 240 帧、13 checks，失败 0 | 实际 Player 运动信号、resolver、FX 数量和 water decal 路由 |
| [流程回归](../evidence/ground-flow.json) | 780 帧、暂停冻结、两次 retry、最终 playing | reset 无残留的流程接入检查 |

Motion 两档分别消费 759/1059 次随机数，合计 1818；tape 在原函数运行前量化为 u53，Native 解码同一值。两份生成器禁写重放均与最终 fixture 逐字一致，检查数量也已独立复算。

最终实机在 wet=`[-34,0,-3.75]` 起步，frame 37 的 water sprint step 生成 10 additive/7 lit，frame 118 的 wet land 生成 15/7，frame 183 的 dry hard land 生成 0/6。另验证积水位置 y=0 禁止 decal、y=.1 保留 decal。首轮短路线未命中 wet step 的 [失败报告](../evidence/ground-runtime-initial-short-route.json) 与日志已保留，最终通过来自重选测试路线后的重跑。本次核对 [实机日志](../evidence/ground-runtime.log) 与 [流程日志](../evidence/ground-flow.log)，均无 ERROR/泄漏报告。主线已查看第 40/190 帧图片，它们属于接入观察，不作为原作像素等价证据。

仍需保留的范围如下。

- 本轮只证明当前高质量 1024 mask。512 质量模式、其他导出资产或运行期 mask 变更没有对应证据。初始化目前依赖当前场景唯一 uMask 绑定。
- 12879 点覆盖空间外沿、quay 和室内边界，并有 776 个 puddle 点，但没有 depth 恰为 `.015` 的样本。该数值等号分支目前依据代码核对，不能写为定向测试已命中。实机也未覆盖 normal.y=.7、impact.y=.08、player.y=.05 的等号。
- groundSurfaceAt/metalRects 缺失仍会影响非水区域的 surface 结果。当前 contact fallback 是明确的过渡，不等于原完整 H。
- Motion 的遮挡环境为空，shade 为 1；未证明实际阴影查询、地面高度查询、完整玩家世界轨迹、粒子运动/排序、自然回收或受控像素。
- wetness_at 的函数输出已对照，其他系统对该 API 的使用与地面材质最终渲染不由此测试证明。全 FX/decal 联合随机消费仍是独立范围。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| uMask raw | `c7133b56e75d0120cf92b88dd55ca5f4e07a71965ea5c3d96e0255112ba65cd6` |
| ground-query 提取函数 | `6a05e89b6962bc9f5b23dabec1331319fe13aafe8e2d6091dc852360948766b7` |
| ground-query-reference.json | `8673f4f03b3047eeb1519f9aab1dae3a87c27b3cb68179989300d9d02a3403aa` |
| ground-motion 提取函数 | `7104cfd14f62ea8a427f37af702ee0e3f7c9ad9c308e9d236ea8a417abcd102b` |
| ground-motion-reference.json | `cda396077de49e1cf2c62ad7cc3ef8590465e571c1348e77d271b2167e7e2d6e` |
