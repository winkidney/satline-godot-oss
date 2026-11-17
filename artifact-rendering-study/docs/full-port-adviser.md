# Saltline 完整 Godot 移植顾问核对

日期：2026-11-15。本文核对当前 HTML 游戏的源码、现有采集接口和完整移植边界。它是实现与验收建议，没有把未运行的 Godot 功能记为已完成。

## 结论与版本边界

采用原作运行时资产导出、Godot 原生玩法、Godot 原生渲染加专用 shader 的路线。生成出来的几何和纹理应直接保留；状态机、动画求解、碰撞、导航、特效调度和后处理按原作接口重写。完整游戏交付应包括两种模式、三档难度、两把武器、两类敌人、完整港口、手臂动画、菜单与 HUD，以及下文列出的全部可见效果。音效和音乐按用户要求排除。

不能把已有三个 Godot 材质实验算作完整移植，也不能用 WebView 执行 HTML 充当 Godot 游戏。普通 PBR 材质加静态 GLB 只覆盖了原作的一部分内容。

本轮重新计算的来源散列如下：

- `source/saltline.original.html`：`b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb`。
- `source/extracted/bundle-1.js`：`756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

本文所有 `L` 行号对应上述可读 `bundle-1.js`。Three.js revision 为 180，见 [L431](../source/extracted/bundle-1.js#L431)。`legacy-v8` 是旧版归档；当前菜单允许主动替换文档运行旧版，见 [L84054–84078](../source/extracted/bundle-1.js#L84054)，但它不应成为本次默认资产或玩法来源。

## 1. 完整资产与模块入口

启动函数顺序建立 render、mats、physics、props、input、level、backdrop、ground、fx、player、combat、explosives、weapon、enemies、hud、game，见 [L85800–85944](../source/extracted/bundle-1.js#L85800)。完整导出应在这些模块以及 `render.onLevelReady()` 完成后进行，不能以 showcase 的简化 level 作为全关卡。

| 原作模块 | 必须收集的内容 | 源码定位 |
| --- | --- | --- |
| 几何构建和合批 | 原始索引、法线、米制 UV、顶点色、材料分组，合批后的世界变换 | [L35091–35300](../source/extracted/bundle-1.js#L35091) |
| 材质和贴花 | 所有实际配方、所有变体、运行时 GPU 纹理、Canvas 标签及 atlas | [L37394](../source/extracted/bundle-1.js#L37394)、[L38025](../source/extracted/bundle-1.js#L38025)、[L39530–39800](../source/extracted/bundle-1.js#L39530) |
| 36 类道具注册表 | 三类集装箱、护栏/灯杆/围栏、门卫亭、栏杆、继电器、货架、楼梯/步道、冷藏机、桶、托盘/木箱、IBC、叉车、线盘、轮胎、垃圾箱、发电机、油壶/锥桶、气瓶、篷布/沙袋、工具车、投光灯、纸箱、钢管、标牌 | [L40391–40428](../source/extracted/bundle-1.js#L40391) |
| 完整关卡 | gate/yard/shed/quay，集装箱布置，棚屋内外设施，楼梯与可达高处，三台继电器及动态子节点 | [L48034](../source/extracted/bundle-1.js#L48034)、[L51931–52236](../source/extracted/bundle-1.js#L51931) |
| 背景 | 起重机和吊具、KITTIWAKE 船及雷达、撤离艇和系泊绳、城市远景、海鸥、灯 | [L52557](../source/extracted/bundle-1.js#L52557)、[L53566](../source/extracted/bundle-1.js#L53566)、[L54356](../source/extracted/bundle-1.js#L54356)、[L55317–55424](../source/extracted/bundle-1.js#L55317) |
| 地面、海面、天气 | apron、quay skirt、非均匀海面网格、雨线/水花、控制遮罩、道路标记、平面反射参数 | [L55521–56830](../source/extracted/bundle-1.js#L55521) |
| 步枪 | 主体、枪机、弹匣、子弹可见性、瞄具、标识、火焰、枪口/抛壳/瞄准接口 | [L71159–72769](../source/extracted/bundle-1.js#L71159)、[L76790–77214](../source/extracted/bundle-1.js#L76790) |
| 手枪 | 主体、滑套、枪管倾斜、弹匣、止动件、照门发光点、火焰及接口 | [L77215–78107](../source/extracted/bundle-1.js#L77215)、[L78474–78877](../source/extracted/bundle-1.js#L78474) |
| 双臂 | 两侧独立蒙皮几何、35 骨层级、手指参数、helper 骨、握持/IK 求解和材质坐标 | [L73075–73134](../source/extracted/bundle-1.js#L73075)、[L75335–75728](../source/extracted/bundle-1.js#L75335) |
| Hound 四足机 | 20 骨模型、四足 IK、身体弹簧、头/炮塔、弱点和死亡残骸 | [L80522](../source/extracted/bundle-1.js#L80522)、[L81911–82863](../source/extracted/bundle-1.js#L81911) |
| Gull 飞行机 | 13 骨模型、四旋翼、云台/镜头/光锥、频闪灯、毁伤坠落和残片 | [L81023](../source/extracted/bundle-1.js#L81023)、[L81345–81910](../source/extracted/bundle-1.js#L81345) |
| 爆炸物与特效 | 动态红桶/气瓶、引信、火花烟雾、爆炸链；全部粒子/弹壳/碎片/弹痕 atlas 与池配置 | [L58745–60352](../source/extracted/bundle-1.js#L58745)、[L69368–69721](../source/extracted/bundle-1.js#L69368) |
| UI、流程与设置 | HUD、目标标记、无线电文字、标题巡游、暂停/死亡/完成、模式/难度/画质/FOV/近景构图设置 | [L83497–85748](../source/extracted/bundle-1.js#L83497) |

骨数由构造代码计算，导出器仍应从实际 skeleton 校验，而非硬编码这些计数。道具注册表不等于关卡中的实例清单；`level.placed` 是布置信息，最终 `level.root` 才是已经合批的可见几何。两者同时用于校核，不能同时作为完整场景再次实例化。

## 2. 资产出口应当保存什么

### 2.1 推荐导出格式

以版本化 `manifest.json` 加二进制数组为主。GLB 可以作为检查用副产物，但不能担任唯一真相来源。每个输出记录来源散列、生成 seed、质量档、texture size、采样时刻、字体就绪状态、资产 ID、文件散列和依赖 ID。大数组使用 little-endian 原类型二进制，避免 JSON 浮点文本膨胀和整数类型丢失。

建议逻辑结构：

```text
manifest
  source / exporter_version / quality / seed / time / coordinate_convention
  nodes[]       id, parent, type, local_matrix, world_matrix, visible, layers
  geometries[]  index, attributes, groups, draw_range, bounding_box, bounding_sphere
  materials[]   family, variant, standard_fields, shader_fields, texture_refs
  textures[]    shape, dtype, channels, colorspace, origin, sampler, uv_transform
  skins[]       mesh_node, bone_ids, parents, rest, inverse_bind, bind_matrix, bind_mode
  instances[]   geometry_ref, material_refs, matrices, colors, custom_attributes
  bindings[]    semantic_role, node_or_bone_id, source_function, controller
  gameplay      world, physics, nav, level, actors, weapons, modes, difficulty
  samples[]     controlled state, dt sequence, transforms, events, screenshots
```

建立稳定 ID 表，所有引用用 ID，不依赖可能为空或重复的 `Object3D.name`。JSON 序列化必须处理 `Infinity`、TypedArray、Map、Set 与循环引用。手枪 reserve 为 `1 / 0`，见 [L78620–78638](../source/extracted/bundle-1.js#L78620)；普通 `JSON.stringify` 会将其改成 `null`，应显式导出 `unlimited_reserve: true`。

导出隐藏对象。未选中的武器、未激活的敌人池、枪口火焰、空弹匣状态零件都可能在初始帧不可见。`weapon` 在初始化时给两把枪隐藏并挂到相机，见 [L79073–79094](../source/extracted/bundle-1.js#L79073)；敌人池创建 10 只 Gull 和 8 只 Hound，见 [L83126–83135](../source/extracted/bundle-1.js#L83126)。以 `visible == true` 过滤会漏掉必需资产。

### 2.2 几何、节点和实例

- 逐项保存 attribute 名、itemSize、normalized、component type、stride/offset、count 和原始数组。至少覆盖 position、normal、uv、color、skinIndex、skinWeight，以及武器 `aSurf` 和双臂 `aRest/aHand`。未知自定义 attribute 应使完整性检查失败，不能静默丢弃。
- 保存 geometry groups 的 start/count/materialIndex、drawRange 和所有材料槽。保留 indexed 与 non-indexed 表达的语义。若 Godot 将 groups 拆成 surfaces，要在 manifest 中记录拆分映射。
- 几何共享和材质共享分别去重。不要把每个池成员都复制一遍高精度网格；也不要把独立 lens/emissive 材质合成一份后，让一只敌人受伤时所有敌人同时变色。
- 顶点色必须保留原浮点范围。敌人颜色常量包含 `Bs=[1.15,1.15,1.15]`、`Bn=[2.4,2.5,2.6]`、`HD=[9,9,9.6]`，见 [L80463–80473](../source/extracted/bundle-1.js#L80463)。导出器不能转成8位归一化颜色；导入后要读回验证目标COLOR存储是否量化或夹值，必要时用浮点CUSTOM承载并在shader中使用。
- 保存本地矩阵及父节点，世界矩阵用于验算。单位保持米，先用已知集装箱尺寸、玩家高 1.8 米及枪口方向验证。Three 的材质正面与 Godot 三角形绕序约定需要用单面测试三角形确认；只反转必要索引，不同时翻轴、改法线和 UV。
- `InstancedMesh` 保存 count、instanceMatrix、instanceColor；自定义 `InstancedBufferGeometry` 保存每项实例 attribute 及 divisor。Godot 可用 MultiMesh 或专门缓冲实现，但不得以展开后丢失动态属性的静态 mesh 代替粒子/雨。
- 红桶会跨gameplay对象进行实例化，单个爆炸物的 `inst[]` 保存 mesh、实例槽、原矩阵，销毁/重置通过这些槽隐藏/恢复，见 [L69548–69603](../source/extracted/bundle-1.js#L69548)。导出每个爆炸物到全部实例槽的映射，否则碰撞、血量和显示会脱离。
- 合批入口 `ig()` 跳过 noMerge、SkinnedMesh、InstancedMesh、多材质节点，其余几何已经乘进 matrixWorld，见 [L35239–35295](../source/extracted/bundle-1.js#L35239)。若再次给合批几何乘原 prop 变换，会产生双重变换。
- 关卡会把 noMerge 后代 `attach` 到 dynRoot，并移除 relay 原壳的 children，见 [L51979–52029](../source/extracted/bundle-1.js#L51979)。因此 `objective.object` 不是可靠的动态子树根。必须另存 relay controller 到实际 emissive、旋转天线和弹簧面板节点的绑定。

Godot 的 ArrayMesh 支持标准数组与 CUSTOM0..3，自定义浮点格式可以承载 `aSurf/aRest/aHand`。应明确写出每个来源 attribute 对应哪个 CUSTOM 通道和格式，不用 UV2 偷存未知数据。[Mesh 官方参考](https://docs.godotengine.org/en/stable/classes/class_mesh.html)、[ArrayMesh 官方参考](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)

### 2.3 材质、纹理与字体

现有 `study.texture(target)` 能读取给定 render target，但不是自动枚举所有资产的出口。原作材质系统只缓存最终 albedo/ORM/normal；临时 MRT 的高度通道可能被其他配方复用，且临时资源在闲置后释放，见 [L39600–39678](../source/extracted/bundle-1.js#L39600)、[L39777](../source/extracted/bundle-1.js#L39777)。需要在生成每份配方时保存需要的临时高度，不能等最终全场景遍历时再读一个共享目标。

完整纹理收集应遍历材质标准槽、uniform、场景 environment、渲染器自有目标和缓存；覆盖 CanvasTexture、DataTexture、普通 render target、多附件 target 及 cubemap。只遍历 `material.map` 会漏掉海面/湿地遮罩、雨/粒子 atlas、镜头污渍、瞄具专用资源及环境探针。

每份纹理记录实际尺寸、像素格式、颜色空间、alpha 语义、wrap、filter、mipmap、anisotropy、repeat/offset/rotation 和 flipY。GL 读回默认底行优先，现有预览 PNG 已做垂直翻转，二进制未翻转，见 [runtime-findings.md](runtime-findings.md)。不要再统一翻一次。normal 方向用斜光测试确认，不凭贴图颜色猜测是否翻绿通道。

albedo 与颜色贴花保留 sRGB 语义，ORM、法线、地面 mask 等保留线性数据。`study.texture(..., {mode:'hdr'})` 是有损 8 位查看图，不能用作 HDR 环境或反射输入。保存 float16/float32 原始值或线性 EXR。原作 PMREM 是 Three 专用布局；Godot 不能直接把这个 atlas 当普通环境图。应输出捕获时的六个线性 HDR cubemap 面或转换成 panorama，再由 Godot 构建自身 radiance，并用高光对照验收差异。

材质序列化要记录标准 PBR 参数及 `defines/userData.sl/customProgramCacheKey` 对应的变体。`onBeforeCompile` 函数不会自动变成 Godot 材质。公共材质需要重写染色权重、湿润、macro、三平面、normal 方差粗糙度补偿、chainlink coverage；专用 shader 还有湿地、水、双臂、枪械、镜片、粒子与环境灯。源码入口见 [L39507–39528](../source/extracted/bundle-1.js#L39507)、[L39717–39757](../source/extracted/bundle-1.js#L39717)、[L70488](../source/extracted/bundle-1.js#L70488)、[L75282](../source/extracted/bundle-1.js#L75282)。

标签 atlas 和武器文字 atlas 必须在字体完成加载及重绘后读取，保存最终图、布局 rect、字体文件与字体名称。原作字体就绪后重画，见 [L39085](../source/extracted/bundle-1.js#L39085)，地面标记只等字体最多 350ms，见 [L56744–56752](../source/extracted/bundle-1.js#L56744)。导出器应另设明确的字体就绪门槛，以免将 fallback 字体永久烘进资产。

## 3. 动画绑定、rest pose 与运行时控制

### 3.1 双臂和双敌人均需真实骨骼

双臂 mesh 同时带四权重 skin、`aRest`、`aHand`，见 [L75361–75376](../source/extracted/bundle-1.js#L75361)。手指每指有 4 个控制量，20 维 pose 不是 20 根骨头。每段手指还有 helper 骨，以主骨和 rest 旋转中点调整关节体积；左右手在几何和旋转上做对应镜像，见 [L75404–75479](../source/extracted/bundle-1.js#L75404)。保留全部骨骼和权重，不重新自动绑定。

手臂在创建时先设置基准姿态，再用显式单位 bindMatrix 绑定，见 [L75593–75611](../source/extracted/bundle-1.js#L75593)。导出时保存以下三组独立状态：

1. 绑定时的骨骼父子关系、local rest、boneInverse、bindMatrix、bindMatrixInverse、bindMode。
2. 采样帧的 local pose、world matrix，以及 mesh 所属根的变换。
3. 控制量和语义绑定，例如 shoulder、elbow pole、wrist target、20 维 finger pose、trigger、握枪 socket。

不能把导出时正在持枪的姿态当作 bind pose，再直接套用原来的 inverse bind。验收以原 Three skinning 公式和目标顶点结果为准，见 [L9372–9387](../source/extracted/bundle-1.js#L9372)。Godot 端的每骨变换与 Skin bind 应重建同一 mesh-local skin matrix；先统一骨骼空间，再验证，不靠多试几次转轴修补。

Godot Skeleton3D 的 global pose 指相对 skeleton 的姿态，不是世界变换。Skin 的骨索引或骨名必须与导出的权重映射一一对应。读取 rest、pose 时也不能把另一引擎的“相对 rest 的增量”语义自行套上去。[Skeleton3D 官方参考](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html)、[Skin 官方参考](https://docs.godotengine.org/en/stable/classes/class_skin.html)

敌人 rig 由 `Oh` 构建，按照材料槽合并刚性权重网格；`z5()` 建骨并绑定，Gull 的透明旋翼盘/光锥 extraMesh 使用同一 skeleton，见 [L80298–80443](../source/extracted/bundle-1.js#L80298)。头、枪口、镜头、旋翼和四条腿需要语义骨名，弱点和攻击判定也必须跟随对应姿态。

### 3.2 程序动画不能靠一个播放循环替代

| 动画组 | 要移植的输入、输出和时序 | 源码定位 |
| --- | --- | --- |
| 双臂 IK | 肩与 pole、手腕位置/方向、reach/关节限制、前臂扭转分布、两侧镜像 | [L75404–75692](../source/extracted/bundle-1.js#L75404) |
| 握持和手指 | 20 维 pose，握把/护圈/弹匣碰撞体，按手指求贴合、拇指自碰撞、trigger 弯曲 | [L73278–73509](../source/extracted/bundle-1.js#L73278)、[L74711–75086](../source/extracted/bundle-1.js#L74711) |
| 双手微动 | 发射冲击、手指弹簧、手腕惯性、helper 骨体积修正 | [L75444–75479](../source/extracted/bundle-1.js#L75444)、[L75694–75720](../source/extracted/bundle-1.js#L75694) |
| 近景武器运动 | ADS、跑步、步频、呼吸、惯性、后坐、着地、蹲姿、靠墙回缩、检视和换枪 | [L72827–73019](../source/extracted/bundle-1.js#L72827)、[L78944–79027](../source/extracted/bundle-1.js#L78944)、[L79622–80131](../source/extracted/bundle-1.js#L79622) |
| 换弹 | 弹匣离枪、旧/新切换、装入、拍入、重新握持、枪机/滑套；战术与空仓两条时间线 | [L73020–73072](../source/extracted/bundle-1.js#L73020)、[L77040](../source/extracted/bundle-1.js#L77040)、[L78698](../source/extracted/bundle-1.js#L78698) |
| 死亡掉枪 | 从近景相机空间转世界空间，改 layer/阴影，抛物、墙碰撞、反弹、静置或沉水，双臂同步退出 | [L79444–79621](../source/extracted/bundle-1.js#L79444) |
| Hound | 对角足交替落地、地面高度、身体 roll/pitch 弹簧、头/炮塔跟踪、预警、射击、扑击、倒地和残骸下沉 | [L81960–82863](../source/extracted/bundle-1.js#L81960)，步态见 [L82626–82750](../source/extracted/bundle-1.js#L82626) |
| Gull | 巡逻/绕玩家、姿态倾斜、旋翼转动、云台、预警灯、射击，掉旋翼、旋转坠落、碰撞爆炸 | [L81384–81910](../source/extracted/bundle-1.js#L81384) |
| 场景动态 | relay 三状态灯光/天线/面板弹簧，吊具摇摆、雷达、艇体起伏、海鸥和背景灯 | [L43684–43781](../source/extracted/bundle-1.js#L43684)、[L55378–55403](../source/extracted/bundle-1.js#L55378) |

步枪战术/空仓换弹为 2.24/2.72s，手枪为 1.5/1.9s。弹药在 `magin` 事件结算，而非整个换弹动画结束时统一填满，见 [L79061–79072](../source/extracted/bundle-1.js#L79061)。应保留事件跨帧检测、每阶段只触发一次及中断语义。

可离线导出固定握持的解算结果、关键帧轨迹及逐帧参考姿态，用于 Godot 实现校验。运行时仍要接收移动速度、瞄准、枪口墙距、地面和战斗状态，并处理混合、打断与弹簧。把整场动作烘成唯一不可交互的动画不能满足完整复刻。

## 4. 玩法数据出口和原生实现边界

### 4.1 碰撞与导航

原作 `physics.boxes` 直接提供最终世界 AABB，字段包括 min/max、surface、tag、noNav、bulletOnly、playerOnly，见 [L39923–39957](../source/extracted/bundle-1.js#L39923)。这些比从可见 mesh 重新生成凸包更接近原作实际玩法。

`moveCapsule()` 是水平圆柱加高度处理的自定义求解，不是通用物理引擎 capsule 接触；默认半径 0.32、高度 1.8、台阶 0.42 米，含水平分步、墙面滑动和顶碰。`raycast()`、groundHeight、lineOfSight 对 bulletOnly/playerOnly 的使用也不同，见 [L39958–40167](../source/extracted/bundle-1.js#L39958)。在 Godot 先原生重写相同算法和标志语义；可额外建立 PhysicsBody 供编辑器观察，但未经轨迹等价验证，不把默认 `move_and_slide()` 当作原行为。

导航出口已有 `physics.nav._grid()`，返回 blocked/w/h/minX/minZ/cell。格距 0.5 米，区域 X[-40,31]、Z[-32,30]，生成时按 0.5 米膨胀障碍，排除 noNav/bulletOnly/低物体/高架物，八邻接 A* 禁止斜穿角，并简化可见路径，见 [L39914–39922](../source/extracted/bundle-1.js#L39914)、[L40168–40380](../source/extracted/bundle-1.js#L40168)。先导出栅格并原生复写寻路与 clearLine，普通 Godot navmesh 不是等价默认选择。

爆炸物销毁会移除碰撞盒并令 nav dirty，reset 会补回，见 [L69461–69469](../source/extracted/bundle-1.js#L69461)、[L69641–69646](../source/extracted/bundle-1.js#L69641)、[L69688–69692](../source/extracted/bundle-1.js#L69688)。因此初始 baked grid 只是快照，运行中还要重建原规则。斜放道具的碰撞盒已经按长轴拆分再变换、略收缩，见 [L48175–48219](../source/extracted/bundle-1.js#L48175)，不得把它替换成一个外接大盒。

### 4.2 地图与目标

直接导出 level 的 `playerStart/objectives/extraction/enemySpawns/zones/interiorBoxes/cinematicPath/coverPoints/skylights/shedLights/vantage/placed/explosives`，见 [L52201–52235](../source/extracted/bundle-1.js#L52201)。目标中的 object 改为稳定 controller/节点 ID。保留生成时已经修正到可走格的出生点和 coverPoints，见 [L52174–52199](../source/extracted/bundle-1.js#L52174)。

还需导出 `groundSurfaceAt()` 使用的金属区域、ground 的 puddleDepth/wetnessAt/seaHeight 参数与数据图，不能只导出方法名。玩家水坑脚步、受水影响的表现及碰撞命中材质依赖这些查询，见 [L48243–48263](../source/extracted/bundle-1.js#L48243)、[L56784–56820](../source/extracted/bundle-1.js#L56784)。

三台继电器可按任意接近顺序切断，交互距离 2.2 米、朝向点积门槛 0.45、持续 2.4s；中止后进度按每秒 1.6 回退。目标变化控制灯和动画、警告文字、增援及最终追击，全部切断后进入艇边范围完成任务，见 [L84651–84669](../source/extracted/bundle-1.js#L84651)、[L85482–85554](../source/extracted/bundle-1.js#L85482)。

### 4.3 玩家、武器、敌人、模式

| 系统 | 需要一致的行为与数据 | 源码定位 |
| --- | --- | --- |
| 玩家 | 行走3.8、冲刺6.4、蹲行1.9、ADS2.4 m/s；地/空加速、重力21、1m跳高、coyote、buffer、蹲顶限制、落水救回、受伤、回血、镜头后坐 | [L68784–69247](../source/extracted/bundle-1.js#L68784) |
| 步枪 | 30发、150备弹、720rpm、26伤害、300射程、自动；三种视图、扩散/热量/枪口烟、战术和空仓换弹 | [L76954–77045](../source/extracted/bundle-1.js#L76954)、[L78910–80131](../source/extracted/bundle-1.js#L78910) |
| 手枪 | 15发、无限备弹、420rpm、34伤害、120射程、半自动；三种视图、滑套空仓锁定及释放 | [L78608–78725](../source/extracted/bundle-1.js#L78608) |
| 命中与爆炸 | 世界遮挡优先；敌人独立解析 hitbox；Hound weak伤害倍率2.2；玩家伤害、击杀统计、LOS限制的范围伤害 | [L69248–69365](../source/extracted/bundle-1.js#L69248)、[L82171](../source/extracted/bundle-1.js#L82171) |
| Gull | HP45基础值、三发burst、预警0.55s、速度/高度/距离控制、实体飞弹、濒死冒烟与爆炸范围伤害 | [L81345–81910](../source/extracted/bundle-1.js#L81345) |
| Hound | HP140基础值、四发burst、预警0.5s、距离选位/cover、重寻路、卡住恢复、近距离扑击、弱点、残骸 | [L81911–82863](../source/extracted/bundle-1.js#L81911) |
| AI共享管理 | 视距45、视锥200°、丢失/搜索、声音事件调查、rally、攻击token数量/间隔/类型公平性、池回收、最多5具残骸及32发bolt | [L82897–83370](../source/extracted/bundle-1.js#L82897) |
| 可爆物 | 桶和气瓶的HP、引信、伤害/半径/连锁、碰撞移除、视觉泄漏、重置 | [L69368–69721](../source/extracted/bundle-1.js#L69368) |
| Mission | 初始巡逻、每个relay增援、错峰出生、隐藏/远距选点、同时存活上限、撤离追兵、失败/重试/完成 | [L84651–84669](../source/extracted/bundle-1.js#L84651)、[L85131–85592](../source/extracted/bundle-1.js#L85131) |
| Holdout | 递增波次、敌人比例/HP/伤害/冷却/并发增长、波间9s、补弹90上限240、回血35、每两波重置爆炸物、积分和本地最佳成绩 | [L84751–84767](../source/extracted/bundle-1.js#L84751)、[L84863–84972](../source/extracted/bundle-1.js#L84863) |
| 难度和设置 | Standard/Hard/Brutal，默认Hard；难度同时改变敌人/玩家回血/增援/token；画质auto/low/medium/high/ultra、灵敏度、反转Y、FOV、武器构图持久化 | [L84080–84134](../source/extracted/bundle-1.js#L84080)、[L84670–84750](../source/extracted/bundle-1.js#L84670) |
| UI及输入 | 键鼠、手柄、触控、相应按键提示、手柄瞄准辅助、血量/弹药/目标/方向/命中与弱点反馈、警告、无线电文字、菜单焦点 | [L68169–68783](../source/extracted/bundle-1.js#L68169)、[L83497–84650](../source/extracted/bundle-1.js#L83497)、[L85600–85655](../source/extracted/bundle-1.js#L85600) |

表中数值是基础设定，不是默认 Hard 应用后的所有最终值。运行数据应同时导出原始 tuning 和各难度补丁，避免将已修改的全局对象反复叠乘。近战输入在 input 映射中存在，但功能覆盖必须追到消费者，不能仅凭按键名宣布已实现独立近战系统。

去掉音效后仍保留 `weapon:fire/explosion/player:step/player:land/enemy:* /objective:* /game:state` 的逻辑事件。AI 的“听到枪声”实际上监听 weapon:fire 事件，见 [L83355–83369](../source/extracted/bundle-1.js#L83355)，删除声音合成器不应删除这种调查/警觉行为。无线电的文字提示属于 HUD，也保留。

主循环顺序要固定：input → game → player → weapon → enemies → explosives → fx/ground/level/backdrop/mats → hud → render；paused、dead、complete 各自更新范围不同，见 [L85974–86082](../source/extracted/bundle-1.js#L85974)。建议原生模拟用可注入 dt 的同一调度入口，先对齐1/60s序列，再检查可变帧率。Math.random 在部分粒子与导航随机点仍被直接使用，见 [L58745–58749](../source/extracted/bundle-1.js#L58745)、[L40204–40218](../source/extracted/bundle-1.js#L40204)；只设置 `seed` 不会让所有视觉随机完全可重放。

## 5. 所有效果覆盖清单

以下项目全部属于完整画面范围。Godot 内置同名效果只能先作为候选，是否等价要由同机位对照决定。已存在的分析详见 [rendering-port-map.md](rendering-port-map.md)、[materials-and-textures.md](materials-and-textures.md)、[surfaces-fx-and-cloth.md](surfaces-fx-and-cloth.md)。

| 检查项 | 原作定位 | Godot实现和必须观察的证据 |
| --- | --- | --- |
| 天空、方向地平线、太阳圆盘、FBM云及闪电 | [L35303–35486](../source/extracted/bundle-1.js#L35303) | 自定义 sky shader；固定方向/时间对照，亮闪和云方向一致 |
| 独立天空 IBL、室内环境捕获 | [L35476](../source/extracted/bundle-1.js#L35476)、[L37190–37232](../source/extracted/bundle-1.js#L37190) | 保存捕获参数和HDR；室内外高光与平均亮度，避免太阳能量重复 |
| 单太阳、六槽局部光池、近景补光 | [L36710–36793](../source/extracted/bundle-1.js#L36710)、[L36954–36973](../source/extracted/bundle-1.js#L36954) | 枪火、火源、爆炸、室内武器亮度及池满时的复用 |
| 接触硬化阴影、bias和更新节奏 | [L35489–35609](../source/extracted/bundle-1.js#L35489)、[L36947–36952](../source/extracted/bundle-1.js#L36947) | 近/远遮挡半影；不把默认硬阴影算通过 |
| 半分辨率SSAO、深度滤波和亮部保护 | [L35632–35673](../source/extracted/bundle-1.js#L35632)、[L35731–35777](../source/extracted/bundle-1.js#L35731) | 杂物接触、细杆边缘、亮面不被统一压黑 |
| 体积散射、透射、阴影光束、室内尘雾、远雾 | [L35674–35730](../source/extracted/bundle-1.js#L35674) | 逆光港口、棚屋入口、梁柱光束及远景空气透视 |
| 相机运动模糊 | [L35778–35799](../source/extracted/bundle-1.js#L35778) | 转镜9采样轨迹、近景排除、无重复模糊 |
| 多级bloom与横向streak | [L35800–35843](../source/extracted/bundle-1.js#L35800) | 亮灯、太阳、枪口的扩散尺度和横向条，不只比较均值 |
| 镜头污渍、太阳flare/ghost/ring、遮挡历史 | [L35844–35898](../source/extracted/bundle-1.js#L35844)、[L35930–35961](../source/extracted/bundle-1.js#L35930) | 太阳从箱体后显露/遮住，ghost位置和响应时间 |
| 中心加权自动曝光和适应 | [L35844–35870](../source/extracted/bundle-1.js#L35844)、[L36530](../source/extracted/bundle-1.js#L36530) | 由户外进入棚屋的0/0.27/1.07/3s序列 |
| ACES/AgX混合、固定grade、暗角、grain、dither、FXAA、锐化 | [L35900–36028](../source/extracted/bundle-1.js#L35900) | 原顺序和颜色空间；灰阶/亮灯/暗部梯度；避免二次tone map或gamma |
| ADS外围模糊/色差、受伤红边、低血、死亡去饱和、淡出 | [L35945–35997](../source/extracted/bundle-1.js#L35945)、[L85657–85738](../source/extracted/bundle-1.js#L85657) | 每种状态独立触发，再检查叠加和恢复 |
| 武器独立FOV与遮挡层 | [L36695–36701](../source/extracted/bundle-1.js#L36695)、[L36942–36996](../source/extracted/bundle-1.js#L36942) | 主FOV74/武器54，三种近景构图，贴墙不裁掉枪，前景不错误起雾 |
| 所有公共材质：UV/三平面、宏观变化、湿润、雨珠、normal补偿 | [L39345–39504](../source/extracted/bundle-1.js#L39345) | 同位置近中远斜视，检查纹理比例、湿高光、缩小闪烁 |
| chainlink透明覆盖和远距过滤 | [L37770](../source/extracted/bundle-1.js#L37770)、[L39459–39485](../source/extracted/bundle-1.js#L39459) | 网格细线近远均可辨，慢速平移无异常丢失 |
| Canvas做旧贴花、标签atlas、玻璃透明排序 | [L38025–38163](../source/extracted/bundle-1.js#L38025)、[L48349–48468](../source/extracted/bundle-1.js#L48349) | 相同文字/图案、alpha和边缘，不穿底面、不Z-fighting |
| 武器aSurf材料与瞄具玻璃 | [L70138–70244](../source/extracted/bundle-1.js#L70138)、[L70348–70538](../source/extracted/bundle-1.js#L70348) | 裸材/磨损/凹腔、雨珠、标线、角度Fresnel/薄膜色/灰尘指印 |
| 双臂材料域、分区、织纹、罗纹、缝线、雨珠 | [L75171–75334](../source/extracted/bundle-1.js#L75171) | 换弹形变时纹理固定、指节和袖口不丢细节、毫米细节远退场 |
| 湿地分区、标记、裂缝、油污、水膜、雨圈 | [L55521–56156](../source/extracted/bundle-1.js#L55521) | 同坐标mask采样、积水边缘与湿暗过渡、近处路标 |
| 地面平面反射、粗糙度mip与坡度扭曲 | [L56157–56258](../source/extracted/bundle-1.js#L56157) | 箱体/灯柱轮廓位置、粗糙地与水坑反射清晰度，不能用SSR替代 |
| 海面几何波/细波normal、岸/船泡沫、风斑、碎光、地平线雾 | [L56259–56490](../source/extracted/bundle-1.js#L56259) | 岸边近波、远处轮廓、船体接缝；CPU seaHeight与shader同一参数 |
| 雨、棚顶/天窗遮蔽、檐口滴水、水花 | [L56500–56728](../source/extracted/bundle-1.js#L56500) | 室外/棚内/天窗下对照，像素线宽、数量与亮度保持 |
| 受光烟尘/火焰、premultiplied与additive两池、软粒子 | [L57585–57860](../source/extracted/bundle-1.js#L57585)、[L58745–58833](../source/extracted/bundle-1.js#L58745) | 烟层遮挡、逆光边缘、地面软交界；不把所有亮粒子改成加法 |
| 枪火、曳光、弹壳、碎片、命中火花/烟尘/水花/弹痕 | [L58272–58744](../source/extracted/bundle-1.js#L58272)、[L58834–60009](../source/extracted/bundle-1.js#L58834) | 金属/木/混凝土/水/敌人分别命中，方向、寿命、反弹与池回收 |
| 持续steam/smolder/embers/fire/drip发射器 | [L60010–60252](../source/extracted/bundle-1.js#L60010) | 每类发射器稳定运行、火光随时间变化、滴水落地反馈 |
| 水坑脚步和落地尘/水花 | [L60253–60307](../source/extracted/bundle-1.js#L60253) | 由真实surface/puddle查询触发，跳跃落地强度一致 |
| 爆炸物泄漏、引爆、连锁、火光和相机冲击 | [L69613–69720](../source/extracted/bundle-1.js#L69613) | 多桶连锁、LOS遮挡伤害、碰撞移除与reset |
| Gull旋翼盘/扫描锥/频闪/镜头，Hound弱点/炮口/受击/死亡 | [L81384–81910](../source/extracted/bundle-1.js#L81384)、[L81960–82863](../source/extracted/bundle-1.js#L81960) | 预警与伤害时间一致；损坏零件和残骸池完整 |
| Relay发光/闪烁/熄灭、天线减速、面板弹簧 | [L43684–43781](../source/extracted/bundle-1.js#L43684) | live/cutting/cut全过程及重试还原 |
| 吊具、雷达、艇体、海鸥、背景灯 | [L55251–55424](../source/extracted/bundle-1.js#L55251) | 固定时间运动对照及远景轮廓 |
| 质量档、MSAA、动态分辨率、显式失败状态 | [L34661–34727](../source/extracted/bundle-1.js#L34661)、[L36848–36894](../source/extracted/bundle-1.js#L36848)、[L37073–37135](../source/extracted/bundle-1.js#L37073) | 每档真实启用项、buffer尺寸、实际GPU；功能失败不能靠stub通过 |

建议以 Forward+ 为目标。CompositorEffect 可安排额外 pass，但回调在渲染线程，且只在 Forward+/Mobile 支持。[Godot compositor 官方说明](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html) 原作最后在 sRGB 后做 FXAA/grain；将其放进 Godot HDR compositor 后又接受引擎 tone mapping，会改变结果。输出链必须先画出每一步的颜色空间，再实现。

原作 world 与 viewmodel 共享HDR目标，并将 viewmodel深度压到0..0.05，随后AO/体积/模糊按约定跳过前景。Godot使用reverse-Z，不能照抄这个深度阈值。[Godot 深度重建官方说明](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html) 更稳妥的实现是明确的世界HDR、viewmodel颜色/遮罩、世界深度，再按原作用途合成；只有最终颜色进入共同的bloom/曝光/grade。独立视口方案必须验证HDR精度和透明层完整性。

## 6. 高风险、实现次序和验收门槛

### 6.1 最先消除的风险

| 风险 | 常见失真 | 决定是否可继续的检查 |
| --- | --- | --- |
| 动态绑定丢失 | relay只剩静态壳，换弹弹匣不离枪，Gull扫描锥脱离云台 | bindings中每项引用存在，逐控制量改变能移动正确节点 |
| 初始姿态与bind混淆 | 手臂炸开、手指双重旋转、模型首帧正确后续变形 | rest与三个动作姿态的CPU蒙皮顶点对照 |
| 合批/坐标重复变换 | 港口看似完整但场景漂移、旋翼方向反、单面不可见 | 世界AABB、地标、单位、法线与绕序独立检查 |
| 只导map/初始可见对象 | 少了手枪、敌人、制服细节、灰尘、光锥或屏幕效果 | 几何/材质/纹理/骨/绑定/实例闭包覆盖，无未解析引用 |
| 通用shader替代专用材质 | 材料变塑料、双臂纹理滑动、链网远处消失 | 近中远和斜光材料采样，不以全景截图遮掩 |
| 反射/后处理重复转换 | 港口湿地及逆光整体失真 | HDR、深度、反射、曝光与最终颜色分别读回 |
| 通用物理/nav替代原规则 | 台阶/边界/射线/出生点改变，敌人堵死或穿角 | 同输入轨迹和路径节点对照，爆炸前后重复 |
| 忽略时间线事件 | 换弹中断刷弹、弹药延迟、敌人预警与开火错位 | 每事件采样时间及次数，状态切换边界前后各一帧 |
| 仅seed控制重放 | 粒子/路径随机仍漂移，图像差异被误当实现错误 | 记录所有RNG源与dt，视觉随机单独冻结/回放 |
| 依赖静默fallback | 看起来能开机，实际武器/敌人/特效为空 | 原作和Godot采集都断言无module stub、无shader fallback |

不能将一个大静态场景导出成功当作资产完成。先完成 manifest 与导入器的完整性校验，再建立静态全港口及所有角色的真实材质；同时建立原生gameplay与事件接口。随后接入双臂/武器、双敌人、所有场景动态和FX，最后按原作渲染链校准画面。每一步保留全范围清单，未通过项列为未完成，不能将后续工作改名为可选美化。

### 6.2 必要自动检查

- 资产清单闭包完整；文件散列、数组长度、索引范围、group范围、权重骨索引和权重和有效；所有未知attribute/material family/controller都报错。
- 导入前后总三角形数、各材料surface数、实例数、骨数、节点关系、世界AABB与关键地标一致。共享去重前后都记录计数口径。
- 对双手、Hound、Gull分别抽样顶点，比较绑定姿态和至少三个动作姿态。建议静态坐标误差≤1e-5m、动作关键点误差≤1e-3m作为第一轮门槛；这些是项目建议阈值，不是已达到的测量。
- 为双枪空仓/非空仓换弹分别取每个事件前后、弹匣离枪中段、ADS、冲刺、换枪和死亡掉枪的采样。核对手腕、枪口、弹匣和指尖，事件误差≤一个1/60s模拟步。
- 路径检查包含棚门、集装箱拐角、楼梯/高处、围栏边界、码头边、已爆炸/重置的桶位。对地面高度、LOS、射线表面和玩家轨迹分别比对。
- 状态检查包含暂停保持、受伤回血、死亡重试、任意relay顺序完成Mission、提前到艇边拒绝完成、Holdout至少三波及双波重置爆炸物、三档难度重开不累积参数。
- FX池与敌人池完成多次激活/回收，残骸超过5具、bolt满池、持续发射器结束/重试、两把枪多次切换不残留隐藏节点或灯光。

### 6.3 必要画面与交互证据

复用已有原作1280×720、高画质、RTX4070 SUPER采集机位，见 [runtime-findings.md](runtime-findings.md)。固定相机、FOV、dt、模拟时刻、曝光、grain、quality和字体；先做固定曝光0.7/grain0的消融对照，再验证默认自动曝光和动态grain。研究副本 `study.frame()` 只推进渲染，不推进完整游戏；动作采样需走真实主循环 `__step`，并等待 `__ready && __step === 0`，见 [research/README.md](../research/README.md)。

最低画面组合包括入口全景、棚屋内外、码头/海面/撤离艇、全道具扫描、双枪三种构图、双手换弹、Gull/Hound预警攻击死亡、三台relay切断、每类命中材质、爆炸物连锁、每类持续发射器、晴暗视向的flare与曝光。动态证据用无损WebP或原始逐帧PNG，不能只交首帧。

像素差和SSIM只作定位工具。几何轮廓、字形、纹理物理尺度、动作事件和关键效果覆盖优先逐项判断；随机粒子不应凭一张全屏均值宣称一致。最终人类视觉检查仍需基于同条件成对画面。

交付至少包含可直接启动的Godot项目及完整运行入口、来源/导出manifest、转换工具、原生脚本和shader、操作说明、完成一次Mission及多波Holdout的运行记录、画面对照、性能数据和明确的未通过项。无声是需求范围，不是错误；崩溃、stub、缺资产和缺效果不能归入无声裁减。

性能采样须覆盖完整游戏帧，含世界、阴影、反射、武器、透明FX和后处理。已有104条原作post query只测后处理阶段，不能证明全帧预算。记录真实GPU/驱动/renderer、分辨率、质量档、p50/p95/p99、持续时间、对象池数量与内存走势。若某效果超预算，顾问给出保留该效果的分辨率/更新频率/批次方案，并用消融和时间序列比较；不得以删掉该效果或退化成缩减demo作为完成结论。
