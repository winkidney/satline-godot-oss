# 可追加场景与调试展示清单

**供分镜审阅，尚未安排本轮拍摄。** 本清单根据本地原版脚本、复刻源码、已有历史画面与现版成片整理。历史截图和旧视频只能说明当时的条件；本轮尚未重新实录这些新增镜头。原作及衍生素材的公开许可仍待核实。

## 参考画面

下列图集从项目内历史截图整理而成，只用于确认希望补拍的景别和内容。图中已标明原版、Godot 和明显不同的机位；背景工作台中的公共地面不是海面。

- [港口、天空、海面与船只](review/references/01-harbor-sky-sea.webp)
- [机械犬、无人机、武器、手部与特效](review/references/02-actors-and-fx.webp)
- [材质、道具、渲染、地面与关卡工作台](review/references/03-showcases.webp)

每一行所用原文件见[图集来源](review/references/README.md)。

## 补充讲解：原版程序生成与复刻资产路线

原版的叉车等许多场景模型按代码和参数组合，许多基础材质贴图由 GPU 按配方生成并缓存。当前 Godot 复刻先从原版运行结果导出网格、贴图、材质参数、场景层级和骨骼，再用这些数据重建场景和材质；没有完整移植原版模型与贴图生成器。

这条路线保留已导出的基础数据，方便针对同一批资产比较画面。它不自动带来全部生成参数：当前 `props` 道具目录可选择已有道具，但不能直接更换种子重新生成叉车。天空、海浪、湿润和机械犬动作等仍由 Godot 程序实时计算。这里描述的是本次复刻的实现选择，不是 Godot 本身无法程序生成。

**拟补画面**：左右分别拍摄原版与 Godot 的叉车、材质目录和主场景，再用 MG 画出“参数生成模型 / 配方生成贴图 → 导出 → Godot 重建”的流程，以及实时效果的支线。详细代码证据、导出步骤和说法边界见[程序生成与导出重建核查](review/procedural-source-verification.md)。

**PBR 补充对照**：已有渲染工作台和原版/Godot 干湿四张历史图可供审阅；官方标准材质球、漫反射模型、透明叠层及反射方式对照则计划在审阅后单独制作。具体画面和条件见 [PBR 对比页](review/pbr-comparisons.md)，能力和实现依据见 [PBR 调查](review/godot-pbr-investigation.md)。

## 对现版成片的核对

现版前 38 秒主要是集装箱通道、仓库光束、湿地反射和第一人称武器；约 34–36 秒画面上方有很小的飞行物，但不是可辨认的无人机特写。约 05:53–06:41 的动作章节主要还是第一人称枪械、换弹和箱道，机械犬及无人机没有得到清楚展示。对照 [当前剪辑素材表](editor/scripts/build_timeline.py) 和 [当前成片](final.mp4)，原始录屏名含 `weapons-enemies` 不代表已经拍到清晰的敌人近景。

| 优先级 | 应追加的典型内容 | 现版缺口与建议镜头 | 已有证据与边界 |
| --- | --- | --- | --- |
| 高 | 港口全景和海岸 | 从岸边拍码头、起重机、远处货轮、天空与海面的同框全景，再向海平线慢推；原版与复刻分别拍后按机位对齐 | [海面近岸](../saltline-godot/evidence/sea-220.png)、[开阔海面](../saltline-godot/evidence/sea-380.png)、[Godot 历史海面视频](../saltline-godot/evidence/native-sea.mp4)；历史视频为 720p 受控素材，不能当作本轮新录或全程实时性能证据 |
| 高 | 海面细节 | 拍波浪起伏、阳光碎亮、码头与船体边缘泡沫；随后与雨湿地面的倒影分开对照 | [海面实现和限制](../saltline-godot/docs/sea.md)。海面是波浪位移、解析法线、材质和环境反射组合；不能把它说成湿地所用的实时平面反射或折射，也不能说水面物理交互已全部完成 |
| 高 | 天空与天气 | 抬镜看云层、太阳光环和天空颜色变化；雷电如用受控触发，明确标注 | [动态天空说明](../saltline-godot/docs/sky.md)、[Godot 历史天空视频](../saltline-godot/evidence/native-dynamic-sky.mp4)。该历史素材含受控触发和雨系统信号触发；它不证明完整雷暴光照一致 |
| 高 | 机械犬 Hound | 补腿部行走、身体转向、目标搜索/射击，再给受击和残骸一个近景；配原版侧同类机位 | [原版敌人展示静帧](../saltline-godot/evidence/main-paired-high-enemies-hound-source.png)、[Godot 静帧](../saltline-godot/evidence/enemies-hound-native.png)、[历史战斗视频](../saltline-godot/evidence/native-hound-combat.mp4)。旧片的自动化/测试条件须随画面标注 |
| 高 | Gull 飞行敌人 | 补飞行、旋翼、云台扫描或射击及受击坠落镜头；用与机械犬不同的角度展示 | [原版 Gull 展示](../saltline-godot/evidence/main-paired-high-enemies-gull-source.png)、[Godot Gull 展示](../saltline-godot/evidence/enemies-gull-native.png)、[历史战斗视频](../saltline-godot/evidence/native-gull-combat.mp4)。Gull 敌人不同于背景飞过的装饰海鸟 |
| 高 | 小艇与货轮 | 小艇侧面低角度看船体摇摆，货轮近景看船体、缆绳和雷达；高位回到海岸全景 | [原版小艇](../saltline-godot/evidence/main-paired-high-backdrop-boat-source.png) / [Godot 小艇](../saltline-godot/evidence/backdrop-boat-verified.png)；[原版货轮](../saltline-godot/evidence/main-paired-high-backdrop-ship-source.png) / [Godot 货轮](../saltline-godot/evidence/backdrop-ship-verified.png)。独立展示里小艇固定基准高度并摇摆；未核实可驾驶，不能称驾驶演示 |
| 中 | 叉车、集装箱和工业道具 | 单独给叉车外观，接集装箱门、围栏、货架、线缆卷筒等，展示场景细节密度 | [原版道具目录](../saltline-godot/evidence/prop-catalog-source.png) / [Godot 道具目录](../saltline-godot/evidence/prop-catalog.png)；[原始 36 类道具定义](../saltline-godot/assets/catalog/prop-definitions.json)。叉车是道具清单中的模型，未验证可驾驶 |
| 中 | 起重机与远景动态 | 给吊具摆动、货轮雷达、港口灯光和远处装饰海鸟镜头 | [原版起重机](../saltline-godot/evidence/main-paired-high-backdrop-crane-source.png) / [Godot 起重机](../saltline-godot/evidence/backdrop-crane-verified.png)；[背景动画说明](../saltline-godot/docs/source-backdrop.md)。独立背景展示为调试环境，公共混凝土地面不是真实海面 |
| 中 | 雨、落水与局部细节 | 补雨线、檐滴/天窗落雨、地面雨冠和水珠近景，与整体港口空间连接 | [原版 ground 展示](../saltline-godot/evidence/ground-catalog-source.png) / [Godot ground 展示](../saltline-godot/evidence/ground-catalog.png)、[历史雨视频](../saltline-godot/evidence/native-rain.mp4)。场景开关与环境需要现场复核 |
| 中 | 枪火与命中特效 | 补枪口火焰、曳光、弹着火花/烟尘、爆炸和弹孔的近景，避免只看枪身 | [原版 FX 动画序列](../artifact-rendering-study/evidence/runtime/fx-motion.webp)、[Godot 特效展示静帧](../saltline-godot/evidence/fx-showcase-integration.png)、[FX 说明](../saltline-godot/docs/fx-showcase.md)。前者是固定步进研究序列，FX 独立场景的像素一致性仍待验证 |
| 中 | 任务和可交互场景 | 补中继器交互、目标标记变化和撤离船只的过程，避免只有场景漫游 | [任务历史视频](../saltline-godot/evidence/native-mission.mp4)、[任务链记录](../saltline-godot/docs/full-mission-native-chain.md)。历史视频使用辅助传送/无敌，不冒充手动通关；抵达撤离点不等于驾驶小艇 |
| 中 | 场景构造细节 | 补仓库窗、货架和风扇，及箱体文字、标牌、贴花的近景 | [关卡原版静帧](../saltline-godot/evidence/main-paired-high-level-source.png) / [Godot 静帧](../saltline-godot/evidence/main-paired-high-level-native.png)；风扇和环境各自的现状见 [Godot README](../saltline-godot/README.md) |

## 原版提供的十类调试展示

原版源码的 [showcase 注册表](../artifact-rendering-study/source/extracted/bundle-1.js#L85749)列出下表十类。原版可通过本地页面查询参数 `?q=high&show=<名称>` 选择；Godot 命令从 `saltline-godot/` 目录执行。表内链接是**现有历史静帧**，不是这次已完成的新录；未来要放入视频，需先确认当下入口和机位并重新实录。原先研究采集脚本只覆盖其中七类，[采集记录](../artifact-rendering-study/evidence/runtime/showcases.json)不能被误读成十类都拍过。

| 原版 `show` | 展示内容 | 已有原版 / Godot 画面 | Godot 入口与拍摄要点 |
| --- | --- | --- | --- |
| `mats` | 48 种材料、球体/平面及贴花标签 | [原版](../saltline-godot/evidence/material-catalog-full-source.png) / [Godot](../saltline-godot/evidence/material-catalog-full.png) | `./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full`；补全景和金属、布、玻璃、锈蚀局部特写 |
| `render` | 金属度/粗糙度球阵、窄窗、遮挡和灯光测试；可观察伤害/低血量等后处理 | [原版](../saltline-godot/evidence/render-catalog-source.png) / [Godot](../saltline-godot/evidence/render-catalog.png) | 同一 runner 用 `--catalog=render`；与 48 材质样本是两个不同场景 |
| `ground` | 测试物、雨湿地面、海水、平面反射及雨水 | [原版](../saltline-godot/evidence/ground-catalog-source.png) / [Godot](../saltline-godot/evidence/ground-catalog.png) | 同一 runner 用 `--catalog=ground`；对比湿地倒影、海面和落雨 |
| `props` | 集装箱、叉车、货架等 36 类港口道具 | [原版](../saltline-godot/evidence/prop-catalog-source.png) / [Godot](../saltline-godot/evidence/prop-catalog.png) | 同一 runner 用 `--catalog=props`；`--names=forklift,container20,barrel` 可聚焦道具，入口为展示而非可驾驶证明 |
| `level` | 独立关卡几何、仓库灯和部分场景动画 | [原版](../saltline-godot/evidence/main-paired-high-level-source.png) / [Godot](../saltline-godot/evidence/main-paired-high-level-native.png) | `./tools/run_native.sh --script scripts/level_showcase_runner.gd -- --game`；此隔离场景不含完整主游戏湿地、背景及室内环境探针 |
| `backdrop` | 起重机、船、小艇和远景，可分 `crane/ship/boat/sky` | [原版全景](../saltline-godot/evidence/main-paired-high-backdrop-source.png) / [Godot 全景](../saltline-godot/evidence/backdrop-all-verified.png) | 同一 level runner 加 `--showcase=backdrop --bshow=boat`，可替换子项；调试公共地面不能标成真实海面 |
| `enemies` | Hound、Gull、战斗和损毁状态 | [原版双敌人](../saltline-godot/evidence/main-paired-high-enemies-both-source.png) / [Godot 双敌人](../saltline-godot/evidence/enemies-both-native.png) | `./tools/run_native.sh --script scripts/enemies_showcase_runner.gd -- --game --eshow=both`；另有 `gull/hound/fight/dead`，战斗选点带随机性 |
| `weapon` | 枪身、瞄具、射击/换弹姿态 | [原版](../saltline-godot/evidence/weapon-studio-rifle-side-source.png) / [Godot](../saltline-godot/evidence/weapon-studio-rifle-side.png) | `./tools/run_native.sh --script scripts/weapon_showcase_runner.gd -- --game --wgun=rifle --wpose=side`；第一人称 `fire` 展示枪口光，不代表发射弹药 |
| `hands` | 手掌、手背、袖口材质、手势及握持 | [原版手部](../artifact-rendering-study/evidence/runtime/captures/showcase-hands.png) / [Godot 手掌](../saltline-godot/evidence/hands-studio-palm.png) | `./tools/run_native.sh --script scripts/hands_showcase_runner.gd -- --game --hview=palm --hpose=open`；现有两张图视角条件未核齐，须重拍才作正式对照 |
| `fx` | 子弹击中、曳光、爆炸、烟火等 | [原版爆炸](../saltline-godot/evidence/fx-showcase-source-explosion.png) / [Godot 展示](../saltline-godot/evidence/fx-showcase-integration.png) | `./tools/run_native.sh --script scripts/fx_showcase_runner.gd -- --game --fx-mode=all`；另有 `impact/tracer/explosion`，见 [运行和误差边界](../saltline-godot/docs/fx-showcase.md) |

## 建议补拍顺序

1. 先录港口主场景和海岸：宽景、海面细节、天空/天气；再录小艇、货轮、起重机与叉车。分别记录原版和 Godot 的版本、机位、天气、曝光和是否暂停。
2. 再录机械犬与 Gull 的独立展示和实际战斗；单独录中继与撤离流程。无法同时操作时延续“分别实录、非同步操作”的标注。
3. 从十类调试入口中优先拍全材质 `mats`、渲染测试 `render`、地面 `ground`、道具 `props`、敌人 `enemies` 和特效 `fx`；其余作为短蒙太奇或技术段落插画。
4. 画面明示“原版调试展示”“Godot 复刻调试展示”“历史固定条件”或“独立教学实验”。实际可用时间和原版/Godot 差异以重新拍摄、对照核查为准。
