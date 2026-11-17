# 敌人迁移实现与证据

完整敌人系统尚未完成。顾问审查见 [enemy-port-adviser.md](enemy-port-adviser.md)，不把顾问建议或局部数值测试当作完整AI通过。

## 共享感知与攻击协调

`SaltlineEnemyCoordinator` 迁移原作共享requestToken/releaseToken/think/rally/provoke，保留同时攻击上限、最短发放间隔、异类公平等待、感知采样间隔、视锥、seeT/exposure累计、失去目标搜索、附近警戒传播和被动对象规则。

`tools/enemy_coordinator_reference.cjs` 直接读取真实原作ctx方法，用受控LOS和全新su(9001)生成14组令牌操作及360帧感知参考。原生验证3670字段无差异。此测试验证协调器规则，不验证真实敌人移动、实际遮挡几何或整局随机流消费顺序。证据为 `evidence/enemy-coordinator-verification.json`。

原生player新增alive与eye合约，eye取实际带步态与落地位移的相机位置；此变更没有把相机震动角度当逻辑forward。完整伤害/死亡合约仍待迁移。

## Hound程序姿态

`SaltlineHoundPose` 直接迁移E/z/I/US/ll：理想世界足点、对角足组切换、预测落脚、抬脚弧线、身体俯仰/侧倾弹簧、头/炮台/天线姿态和每腿三关节IK。激活足点y按原作初始化为0。该控制器不播放预制步行片段。

骨姿态通过 `SaltlineSourceScene.set_source_transform` 同时写源Bone代理与原生Skeleton3D，保留附着在骨代理上的标签和零件。身体旋转按原作XYZ组合，世界足点逆变换后解各腿，保留伸展上限与最小距离约束。

`tools/hound_pose_reference.cjs` 执行原作真实函数及Three骨层级，采集240帧受控平地加减速和转弯。原生比较四足接触点、换步状态及20骨局部矩阵，57600骨骼字段最大位置/基向量误差约6.3e-5，共14次落脚。证据为 `evidence/hound-pose-verification.json`。

GPU演示为 `evidence/native-hound-pose.mp4`，使用原生蒙皮与程序足点，展示受控移动，不是AI巡逻/攻击演示。当前没有把此控制器当成已完成Hound行为。不同坡面、动态受到冲量、死亡姿态及完整AI驱动仍待接入和对照。

## 敌人材质

原作MeshBasicMaterial现用原生unshaded变体，保留HDR顶点色与贴图；避免发光部件错误接受PBR漫反射。Gull光锥沿用uColor/uGain、视角项与UV渐变公式，使用预乘alpha纯加法，避免此前通用ShaderMaterial兜底形成暗色几何。逐像素曝光、后处理和toneMapped=false的独立语义仍未完成校准。

## Hound路径跟随与运动

`SaltlineHoundLocomotion` 迁移原作M/_/T及存活更新中的运动段。保留目标距离平方0.25的更新门槛、0.6–0.75秒重规划、0.55米路点推进、0.45米到达、转角大于1.1弧度时停止前进，以及距离/转向共同限制速度。

运动按原作顺序更新yawRate/yaw、加减速、Hound间排斥、玩家排斥、push衰减、前探射线、导航阻塞检查、轴向滑动、卡住重规划和地面高度平滑。活动死亡残骸仍参与排斥；没有使用玩家moveCapsule替代。完整engage状态中卡住后的重新选位由信号保留接口，选位器已由SaltlineHoundBehavior接入此信号；普通游戏循环尚未创建完整敌人Actor；独立Actor联动预览已接入。

`tools/hound_locomotion_reference.cjs` 直接提取执行原作M/_/T和原始运动代码段，使用原作真实导航、射线及一个受控活动残骸。720帧位置、速度、朝向、重规划计时、路点、阻塞和到达状态对照通过，最大字段误差约3.2e-5，见 `evidence/hound-locomotion-verification.json`。此验证没有覆盖完整AI选位、战斗分支或所有地形组合。

`--hound-route-preview` 让路径跟随、原生世界足点与IK在同一场景联动。目标为(-24,0,6)，起点(-32,0,6)。这是一条原生目标行走链路，尚不是完整巡逻/攻击状态机。


## Hound选位、战斗决策与瞄准

`SaltlineHoundBehavior` 迁移原作w及S中的决策与瞄准代码。选位考虑射程、可走性、移动距离、掩体偏好、队友攻击方向和站位、实际视线，并依原顺序消耗共享敌人随机流。保留7个导航采样、5个玩家周围候选，以及无可用候选时原地回退。

决策覆盖patrol、investigate/search、engage中的move/aim/cool/tele/burst/wind/lunge/recover。保留攻击令牌、预警时间、连射间隔、冷却、近距离扑击和恢复。发射与近战通过信号交给Actor，当前没有声称它们已经完成实际命中与玩家伤害。头部/炮台的目标、转速上限、俯仰限制、扫描与蹲伏按原公式更新。

调用顺序为 `decide → locomotion.move → pose.step → aim → pose.pose`。原作枪口取上一帧骨世界矩阵，后续Actor接入不得提前重排。受伤烟雾、信号灯、完整射击回调、伤害与死亡残骸仍待迁移。

`tools/hound_behavior_reference.cjs` 从保存的原作直接提取w、M/_/T、S决策段和瞄准段执行。控制导航候选、LOS、感知与令牌发放，不把此受控测试当整局AI验证。30次选位、900帧决策及180帧瞄准，共24660字段对照通过，最大数值误差约3.64e-8；10次射击请求、2次近战请求、4次预警与原作一致。证据为 `evidence/hound-behavior-verification.json`。

复现命令：

```sh
node saltline-godot/tools/hound_behavior_reference.cjs
godot --headless --path saltline-godot --script tools/verify_hound_behavior.gd
```


## Hound受击、命中形状与死亡Actor

`SaltlineEnemyHitShapes` 迁移原作KS球与ZS近似胶囊求交。ZS沿轴求一个最近点后测球，保留原实现，没有替换为标准解析胶囊。Hound先测0.155米头部弱点，再测两个本体形状，严格保留最近命中。480条受控射线命中/部位全部一致，含362次命中、103次弱点命中。Vector3输入为单精度，近乎平行的轴向射线会放大舍入；最大位置/法线联合数值偏差约0.000403，测试容差0.001，见 `evidence/enemy-hit-shapes-verification.json`。

`SaltlineHoundLife` 迁移伤害对侧向、滚转、俯仰与竖直弹簧的冲量，保留weak部位俯仰冲量1.6倍。调用方仍须按原combat规则施加弱点伤害倍率，不能把冲量倍率当生命伤害倍率。死亡释放攻击令牌，随机侧倒，足点滑移，重力落体和0.22回弹；6.5秒后保留活动残骸，收到sink后才下沉回收。FX参数的共享敌人随机流消费顺序也保留。

`tools/hound_life_reference.cjs` 执行原作真实damage/L/U，用受控pose回调验证状态和特效请求。非致命本体、弱点与致命伤害后912帧，共81228个递归比较通过，最大数值误差约1.83e-6，71次特效请求及后续随机数一致。此证据验证生命周期和请求参数，不证明所有粒子逐像素一致，见 `evidence/hound-life-verification.json`。

`SaltlineHoundActor` 组合感知、选位、移动、足点、瞄准、姿态、信号灯和镜头材质；使用原骨枪口世界位置发射请求并施加射击弹簧冲量。通用smoke/sparks接口接入粒子池，死亡倒地通过原生Skeleton3D与附着骨代理渲染。Actor退出显式断开RefCounted信号引用，避免组合模块形成持有环。

`--hound-actor-preview` 是15秒GPU联动演示，使用真实场景导航、原作掩体候选、共享感知和攻击令牌。两次受击由脚本触发，射击射线交点仅记录，尚未调用完整玩家伤害。录像 `evidence/native-hound-actor.mp4` 展示行为、受击、倒地、烟火与残骸。完整敌人管理器、普通游戏刷怪、玩家伤害、枪焰、Gull及波次仍待接入，不能称为完整战斗已完成。


## 原生战斗与玩家生命

`SaltlineCombat` 迁移原作ey，玩家射击先测静态场景，再用静态命中距离限制敌人最近命中；弱点伤害乘2.2。敌人射击按玩家中心投影点，使用水平0.38米、竖直0.95米的严格范围判定，保留静态遮挡，没有用胶囊替代。爆炸按敌人脚点距离线性衰减，LOS目标高0.5米；玩家按身体上方1米测距与LOS，伤害为一半。统计保留shots/hits/kills和可爆物blasts。

`tools/combat_reference.cjs` 执行原作真实ey及敌人管理器raycast，控制场景墙面、LOS和角色命中形状。240组射击/爆炸场景、2160字段通过，58次敌人命中、41次击杀、80次爆炸统计与原作一致；最大误差约6.1e-7。此证据验证规则，不等于完整所有敌人类型与场景均已验证。见 `evidence/combat-verification.json`。

玩家迁移damage/heal、无敌、受伤脉冲、延迟回血、死亡碰撞与死亡相机下坠倾斜。`tools/player_vitals_reference.cjs` 执行原作真实damage/heal/W及死亡N/Z/Q，平地受控碰撞下600帧、6600字段通过，最大误差约5.83e-8。普通移动与武器、爆炸物规则回归通过。死前受伤UI、后处理和完整重置/失败流程仍待接入。

`--hound-combat-preview` 运行15秒原生战斗联动：固定玩家位置、自动跟踪与开火输入，使用实际武器弹药、射线、弱点倍率、敌人AI射击、玩家伤害、回血和敌人倒地。击杀由武器命中触发，没有脚本扣敌人生命。录像与证据为 `evidence/native-hound-combat.mp4`、`evidence/hound-combat-runtime.json`。瞄具玻璃/准星、敌人枪焰、原作HUD与全部管理器仍未完成。

`--hound-fight` 提供同一角色的交互测试入口，可WASD、瞄准射击及受到真实敌方伤害；它是开发测试入口，不代表已完成原作任务或波次。程序退出清理战斗信号和Actor引用。


## 原生池管理与残骸队列

`SaltlineEnemyManager` 迁移原作spawn/addWreck/retire/clear/alert/update。活动Actor和共享协调器状态列表同时维护生成顺序，Combat只遍历活动列表，更新按原作倒序、dt上限0.05。玩家速度按6的指数速率平滑后用于Hound散布。武器噪声0.3秒节流和爆炸30米警戒已接入。

池满时Hound复用残骸队列的最老一具。队列超过5具时，先移出最老者并令sink=0.001，保留活动对象，等下沉完成后retire。原作clear保留时间、next ID、RNG状态、攻击令牌历史及噪声冷却；原生也保留这些值。池对象的Combat信号注册与活动列表分离，避免池复用时重复计数，并在退出显式断开引用环。

`tools/enemy_manager_reference.cjs` 直接提取原作对应函数，使用受控Actor池验证26组操作，共4047个递归比较通过，最大数值误差约2.4e-8。覆盖池耗尽、7次残骸加入、超限下沉标记、最老残骸复用、alert、反向更新、dt截断和clear后历史保留。测试的Gull为受控桩，没有代表真实飞行/弹体已实现。见 `evidence/enemy-manager-verification.json`。

普通运行现构造8个原生Hound池对象，默认隐藏，开发战斗入口通过manager.spawn生成，不再绕过池单独创建Actor。武器、敌人和爆炸物更新顺序调整为weapon → enemies → explosives，随后更新FX。Gull的10对象池、bolt弹体、共享扫描灯、任务波次和默认开局布置仍未完成。

`--enemy-pool-preview` 用8只真实蒙皮Hound验证7次受控击杀和一次池满复用。600帧后活动ID为4、5、6、7、8、9，存活2、残骸队列4，next ID为10，时间10秒；两具超限残骸已下沉回收。录像 `evidence/native-enemy-pool.mp4`，状态 `evidence/enemy-pool-runtime.json`。此场景的击杀由脚本触发，不能当武器命中验证，武器链路另有combat-preview证据。


## Gull飞行、云台与生命周期

`SaltlineGullFlight` 迁移原作v前段：巡逻环绕、调查/搜索、交战环绕、失去视线追踪最后位置、轨道方向/半径变化、分帧前/下/上探测、天花板限制、逐轴反弹避障、地面保底、速度/加速度限制和受伤失稳。保留YXZ机身姿态、升力随动及四个旋翼的不同旋转速度。1200帧受控碰撞平面与模式切换对照，58800个比较通过，最大误差约2.36e-5，见 `evidence/gull-flight-verification.json`。

`SaltlineGullBehavior` 迁移v后段：双闪信号灯、巡逻扫描和目标跟踪云台、灯球/枪管俯仰、HDR镜头颜色、攻击令牌、预警、预测移动目标的连射、散布、射击反冲和受伤烟火。完整原作v在相同受控环境下1200帧、82636个比较通过，包括12次弹体请求、73次受伤FX请求和3次预警；随机流继续值一致，最大误差约4.51e-5。此时弹体请求尚未形成实际飞行/伤害，见 `evidence/gull-behavior-verification.json`。

`SaltlineGullLife` 迁移原作damage/m/x：受击速度冲量和随机姿态冲量、随机丢失一只旋翼、旋转加速坠落、扫掠射线碰撞、持续烟火、坠落爆炸和立即回收。直接执行原作函数生成64帧受控坠落参考，共2992个递归比较、36次FX请求及后续随机流一致，最大误差约1.34e-6，见 `evidence/gull-life-verification.json`。Gull不加入Hound残骸队列。

Gull射线保留原作y轴2.3倍缩放的扁椭球及原法线近似，没有头部弱点。480条射线、324次命中与原作一致，最大数值误差约2.35e-6，见 `evidence/gull-hit-shapes-verification.json`。

`SaltlineGullActor` 与 `SaltlineGullPose` 组合上述模块，写入源Bone代理和原生Skeleton3D。原生管理器现在按原作顺序构造10个Gull和8个Hound池对象，激活保留可选参数的随机数消费语义。激活状态本身尚未单独做批量原作数值对照，不能由飞行测试推断它已全面验证。

`--gull-preview` 使用真实场景射线和感知，近距离观察相机跟随飞行单位。第360帧从Gull上方发出一条受控Combat射线，触发旋翼丢失、坠落、爆炸及池回收。录像为 `evidence/native-gull.mp4`，状态为 `evidence/gull-runtime.json`。这条射线用于生命周期测试，并非玩家实际手动瞄准演示。实际bolt池、弹体伤害、敌人枪焰和最近Gull共享扫描光仍待实现。


## Gull实际弹体、共享扫描光与敌人枪焰

`SaltlineBolts` 迁移原作32槽fireBolt/M/jD。弹体每帧先扣寿命、限制扫掠终点到最近墙面，再测玩家身体轴线的线段间距离，小于0.36米时造成原作boltDamage；保留蹲伏高度、死亡排除、击中后先于寿命回收的顺序。没有用hitscan代替实际飞行。显示直接复用原作enemies下的弹体网格、材质与32容量MultiMesh，原局部-z方向几何随源Quaternion和局部z长度变换。保留1.3秒寿命、70m/s速度和最大1.5米尾长。

`tools/bolts_reference.cjs` 执行真实原作fireBolt/M/jD及Three setFromUnitVectors/Matrix4.compose，含Float32实例矩阵。320帧、232830个递归比较通过，最大误差约4.12e-5，覆盖池满丢弃8次、生成158枚、玩家命中19次、墙面命中117次、过期18枚与池复用。两端用相同dt表达式生成时间步，避免JSON小数读取在恰好归零寿命边界改变一帧。见 `evidence/bolts-verification.json`。

`SaltlineGullScanLight` 迁移原作z，首次更新尝试从六灯池获取一个持久Omni槽。获取失败不重试。只选择相机60米内最近的存活Gull，每0.1秒沿该Gull云台方向采样14米射线，将Omni置于命中点前0.6米；无命中则用8米并降为0.3增益。位置按12、强度按8的指数速率平滑。没有每个Gull各建灯，也没有将原Omni替换成SpotLight。clear保留采样计时与目标，仅将强度清零；dispose释放槽。

共享扫描光360帧、4680个比较通过，最大误差约1.25e-6，含最近存活目标切换、距离排除、命中/未命中、clear和获取失败只尝试一次，见 `evidence/scan-light-verification.json`。实际照明仍受Godot衰减、色调映射及整体曝光校准影响，不把数值参数一致当逐像素照明一致。

敌人通用枪焰按原作fx.H发射四层闪焰、轴向闪焰、三枚火花、一团烟雾和短时灯池闪光。Hound缩放0.9且保留额外22强度枪口光，Gull缩放0.55。四种缩放配置、464字段/范围比较通过，见 `evidence/enemy-muzzle-verification.json`。FX内随机采样仍用原生独立生成器，对照验证配置与范围，未声称整个FX随机序列匹配Math.random。

新增 `evidence/native-gull-combat.mp4`，10秒/60fps。GPU验证3枚原始弹体网格可见并命中玩家，HP降至70，3次敌人枪焰，52次共享光遮挡采样，峰值强度26，随后受控射线击杀、旋翼脱落、坠落爆炸及池回收。运行无脚本错误或退出资源泄漏，见 `evidence/gull-runtime.json`。初始任务布置、全部波次/胜败/重开UI、部分材质和后处理仍未完成。


## 任务核心与中继点

`SaltlineMission` 迁移原作pT中的难度、出生点评分、初始巡逻、增援队列、中继点和Holdout规则。`assets/game-rules.json` 由 `tools/export_game_rules.cjs` 从保存的原作常量提取，附源SHA256；保留standard/hard/brutal基准与覆盖值。切换难度时重置标量和数组，保留已绑定敌人模块的tuning字典引用，避免连续波次倍率累乘。

出生点按距离、LOS隐藏偏好和六秒内复用惩罚评分，保留两个位置扰动随机数、地面可走性检查及空目录回退。队列每帧最多成功处理一个待生成对象，达到maxAlive后延迟一秒；生成失败1.5秒后重试，第六次失败移除该项。三次中继点断开分别生成原波次，全部断开后启动有限追击增援。

交互保留2.2米范围、0.45朝向门槛、0.9米内免朝向、2.5米高度差、2.4秒持续切断和停止时1.6/秒回退。撤离只检查三点已断、玩家存活及撤离范围，不要求消灭全部敌人。结算按原作时间、命中率与重试数计算评级。

Holdout迁移首波延迟、数量/地面单位比例、错峰、HP/伤害/冷却缩放、存活上限增加、击杀计分、波次奖金、补弹/回血与每偶数波重置爆炸物。最高分持久化及完整菜单/复活编排仍待实现。

`tools/mission_reference.cjs` 执行原作完整pT控制器，替换输入、HUD、敌人生成、LOS/导航为受控桩。三档难度及非法值回退、260帧任务流程和1100帧Holdout，共444125个递归比较通过，最大误差约1.89e-6。覆盖交互朝向/中断、三点断开、12次生成失败、撤离Surgical评级、三波计分7180和补给；此测试不验证桩以外的实际敌人战斗或完整UI。见 `evidence/mission-verification.json`。

`SaltlineRelayAnimation` 迁移原作relay_node.setState/update，包含live发光脉冲、cutting闪烁/加速天线、cut余辉衰减和带限位回弹的门铰链弹簧。300帧3300字段对照通过，最大误差约1.8e-15。`SaltlineRelays` 通过原唯一发光材质绑定导出的dynamic组，将源local rotateY增量应用于六个材质分组门片和天线，不移动静态碰撞盒，与原作一致。见 `evidence/relay-verification.json`。

`--mission` 可交互运行当前任务核心，E持续切断中继点；`--holdout` 进入波次核心。两者仍使用开发HUD，原作标题/设置/暂停/任务HUD、前导镜头、胜败呈现和完整重开未完成。

`--mission-preview` 提供13秒GPU验证，自动传送至三点并持续交互，再传送撤离；测试启用无敌。中继点在145/365/585帧断开，681帧撤离，11名实际敌人和增援队列同时更新。录像 `evidence/native-mission.mp4`、状态 `evidence/mission-runtime.json`。它证明原生任务/视觉/敌人联动，不证明完整手动通关体验已验收。
