# MetalRects 与玩家 H 分类审查

本轮补齐当前默认 4207/high 场景的 55 个 metalRects 和原 H 的 surface 优先级，未发现该范围内的生产阻断。这更新了 [上一轮地面审查](ground-query-review.md) 中 metalRects 尚未迁移的状态。原 double 查询与 Native Vector3 输入域分别验证，没有将静态分类扩称为整场移动轨迹一致。本次只读审查，只新增此文档。

原始依据为 [bundle-1.js](../../artifact-rendering-study/source/extracted/bundle-1.js) 第 48312 行的 `uw.k`、第 52224 行的 `level.groundSurfaceAt`、第 68983 行附近的玩家 `H`。Native 对应 [ground_queries.gd](../scripts/ground_queries.gd) 与实际 `Player.event_surface()`。

[插桩脚本](../tools/instrument_ground_surface.py) 只在 uw 返回对象的两处，将原 `i` 数组与 `k` 函数引用赋给 window，同时将相同引用作为原属性值返回。它没有替换原函数、重算矩形或增加随机消费。生成 JS/HTML 写入独立 output，原 bundle 和 HTML 保持不变；ready 后才复制已经构建完成的 55 个矩形。因此后续关卡构造向原数组 push 的内容仍在观测内。

[采集脚本](../tools/collect_ground_surface.cjs) 对每个 probe 同时调用原闭包 k 与实际 level 方法。当前冷启动实录为 `q=high&shot=1&noaudio=1&step=1&dt=.016666667`、frame 3、time=.050000001，ready=true、fatal=null、errors=[]；没有 seed 参数，按原 boot 的 `n.seed || 4207` 使用默认 4207。记录的后端为 NVIDIA ANGLE/OpenGL ES 3.2，此处分类本身是 CPU 查询。

来源链已核对。原 bundle/HTML 对应插桩 manifest，生成 JS 与浏览器采集的 script URL 响应 SHA 一致，rects metadata 再绑定完整 observation SHA。[解码桥](../tools/decode_ground_surface.py) 已补齐写资产前的参数、high/frame3、三份文件 SHA 及有效 seed 校验；有效 seed 按默认值和 uint32 规则与 scene.seed 比较。此前只靠 player_start 匹配不足以绑定 seed 的问题已修复，重跑后资产 SHA 未变。

原 k 使用 `x>=minX && x<=maxX && z>=minZ && z<=maxZ`，四条边均为闭区间。Native 保留相同顺序与比较，没有添加 epsilon。Python 桥将原 JSON 数值编码成 f64LE hex，Native 用 `PackedByteArray.decode_double` 读取矩形和 probe。独立核对 220 个边界标量、25956 个 probe 坐标标量，IEEE double 位模式全部保持；避免了再次经 Godot JSON 数字解析影响精确边界。

观测包含 12978 次点查询，由空间网格和每矩形 min/max/中心及边界 ±1e-7 组成。直接以原 literal k 和 lossless 坐标重放，结果与 live 记录零差异。Native 同时比 metal 布尔值与 level surface，另检查矩形数量，独立计数为 `12978×2+1=25957`。这是闭区间边界证据，不代表实际玩家坐标保持原 JS double 精度。

当前 resolver 的优先级与原 H 一致：先检查 `y<.05` 的 puddle 并返回 water；其次保留非空且非 concrete 的碰撞 contact；最后调用 ground_surface_at，得到 metal 或 concrete。原 level 方法在正常路径总是返回这两种非空字符串，因此 H 末尾 `L || "concrete"` 的兜底不改变当前已绑定生产路径的结果。

[Player 参考](../tools/player_surface_reference.cjs) 字面提取 H/k/level 方法，用原观测矩形及前轮已验证的原 puddle query。55 个矩形中心加 wet/dry 两点，分别搭配四个高度与五种 contact，共 `57×4×5=1140` 行。验证器调用真实 Native Player.event_surface 和绑定 resolver，直接比较字符串。

这些位置先在 JS 中 Math.fround 后才交给原函数，明确把对照域限定为 Native Vector3 可表示值。标称高度 `.05` 实际为 `.05000000074505806`，不能写成原 JS double 精确 `.05` 等号已测；`.049` 与该值分处阈值两侧。water、wood、metal 等 contact 的优先级均在同一组合矩阵中执行。

| 证据 | 结果 | 可支持的范围 |
| --- | --- | --- |
| [原 live metal 查询](../evidence/ground-metal-verification.json) | 55 rects、12978 probes、25957 checks，失败 0 | 当前烘焙矩形、原 k/level 查询、f64 闭区间边界 |
| [实际 Player H](../evidence/player-surface-verification.json) | 1140 checks，失败 0 | Native Vector3 输入域内的 water/contact/level 优先级 |
| [mask 查询回归](../evidence/ground-query-verification.json) | 90154 checks，失败 0 | 前轮 1024 mask/Bg/Vg 查询保持通过 |
| [Main metal 接入](../evidence/ground-metal-runtime.json) | 240 帧中 110 项 metal/contact 静态检查，失败 0 | 55 个中心处 y=2、contact=concrete 得 metal，contact=wood 保持 wood |
| [同轮运动回归](../evidence/ground-runtime.json) | 240 帧、13 checks，失败 0 | 实际 wet step、wet land、dry hard land 与 water decal 路由 |

本轮 [实机日志](../evidence/ground-metal-runtime.log) 已核对无 ERROR/泄漏报告。110 项检查是实际 Main 上的静态 resolver 检查，没有把它们计作 110 次真实金属碰撞或步伐。运动回归仍使用受控输入和传送，不包含原作完整同输入世界轨迹。

独立禁写重生插桩 JS/HTML/manifest、decoded observation、rects metadata 和 player fixture，均与归档逐字一致。Player fixture 当前不单独携带 observation SHA，重现时需要保留其生成器、下表 observation 及已验证 ground-query 资产；本次已把这些依赖一起核验。

边界仍为当前默认 seed 4207/high、已观测的 55 个烘焙矩形。其他 seed、512 mask 或不同场景导出没有对应证据。原 sourceSurface 方法在这些合法输入下已迁移，缺失依赖时的异常兜底、完整玩家运动精度、实际音频、FX 联合随机调度和受控像素仍不能由本轮分类测试推导完成。

| 内容 | SHA-256 |
| --- | --- |
| 原 bundle | `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8` |
| 原 HTML | `b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb` |
| 插桩 JS / 采集响应 | `5ec83ad2c8dbb5599b6175649a649155cd7bf66d17c7b46e4ecf32546917e5a3` |
| ground-metal-observed.json | `2c9e281a598556eb7a412dfd0991682cc31523ad2d53409100e4d44468765141` |
| ground-metal-rects.json | `8be3624e1d30fae6175c1297d929951ec0f961beb21e5c872f96bf249588330e` |
| H/k/level 提取函数 | `adde250ada8e3795f26be808bbea4809f287d36f9683c1efaea490c60bfb7812` |
| player-surface-reference.json | `990ff21a38da6c341fc0c8106f6d00c8e551e2d09f63c11a9ff9090f43c6d92c` |
