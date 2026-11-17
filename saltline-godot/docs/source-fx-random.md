# FX 共享随机数

Main 创建一个 fx_random.gd 服务，注入 impact、additive/lit 粒子池、debris、shells、decals、explosion、sky、主 tracer 与两个绘制 batch，共 11 个接收点。原作 Math.random 与 su 派生流分开，Native 也保留这个边界。清空粒子或重试不会重新播种该服务。

默认服务由两次 Godot randi 构造 53 位 [0,1) 数值，不声称复现 V8 的熵序列。测试可注入 double tape，非法输入或耗尽会报错并返回 NAN，不能静默回退到其他随机源。range 调用明确使用 self.randf，避免落到 Godot 全局函数。整数范围先 floor 再加下界，避免 near1 舍入越界。

## 原函数对照

fx_random_reference.cjs 提取原 u1 emit/clear 和 thunder callback，共用受控 Math.random。196 操作包含双池交错、容量拒绝、clear、显式覆盖 seed、闪电与范围取样，共 183 次 draw。tape 用 53 位十六进制整数保存，避免 JSON decimal 近 1 样本被解析成 1。25837 检查失败 0，最大误差 3.33988862122325e-8，主要为最终 Vector3 转换。非零整数下界 near1 单项通过。4096 默认样本检查有限且位于 [0,1)，不构成统计分布或浏览器熵等价证明。

## 实机证据

verify_fx_random_runtime.gd 在实际 Main 运行 470 帧，11 个接收点对象身份一致，301 次 FX 抽样，失败 0。原有 70 骨代理与 Skeleton、弹匣和机械部件检查通过。780 帧 UI 流程含暂停、死亡、重试、重新开始，pause_frozen=true，最终 playing，日志无 ERROR。tracer 原函数 12 帧回归通过，最大 quad 字段误差 1.1920929e-6。相关 JSON 和日志位于 evidence/fx-random-*。

## 仍需对齐

共享对象并不证明完整函数抽样顺序。Native 某些 emit 调用先构造带随机 rotation/frame 的 options，而原作先 emit 消耗 seed 再写这些字段。需要逐函数提取原实现，并用同一 tape 比较输出和每步 draw 计数。impact、splash、explosion、shell、decal 等完整事件联合序列尚未证明。当前测试也未单列非法 tape 与耗尽的报错用例。全游戏图像、完整流程及资产验收继续进行。

参考原 bundle SHA256 为 756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8。Astra 复核见 fx-random-review.md。

## 烟尘 helper 顺序修正

原 bundle 58852 附近 M 先调用 l.emit，成功后才设置 rotation、rotation_speed、frame。Native puff 现按相同顺序执行，满池立即返回，不消耗后续随机数。赋值同时保留原 Float32 字段精度。

新增 puff_random_reference.cjs 直接提取原 M 与 u1，用 capacity3、20 次调用、两次 clear、固定/随机 frame 交错比较。32 次 draw 和 184 项字段/计数检查通过，最大误差 2.77556e-17。方法 SHA256 c2cc46cb75d953ad24ae21d2612bb4a03617aa70b73bf1b928d34ad65c0715ff。三档 splash 数量回归通过。修正后实际 Main 470 帧 11 处共享身份、骨骼/机械/弹匣回归通过，FX calls305。默认随机输入不同会改变运行事件分支，此计数不应与前次301解读为固定序列对照。

此项仅证明 M/puff，不证明调用者 splash/dust 的全序列。其他带随机 options 的 emit 仍待逐项处理。

## 溅水完整生成序列

新增 splash_random_reference.cjs 直接提取原 go/M/S/k/u1，比较生成后的两个粒子池全部字段和每次 splash 后的累计抽样数。尺寸 .4/1/2，容量 2/12/80，每组连续生成两次制造饱和，再 clear 后生成；共 9 组、27 次 splash、4527 draws。14781 检查通过，最大字段误差9.536743e-7，容限2e-6，包含 Native Vector3 的单精度运算。方法SHA256 10ad9ebcf1b56ad78d5bc13477367090ff91e1d10d9039d34e9642f7d5d2dacf。

修正 S 对应水面波纹为先 emit/seed，再成功时取 rotation；失败不额外取样。第二圈 fin=.35、溅水覆盖 rotation/fout 均按原 Float32 写入。原 M、S 顺序修正后，本范围的累计消费一致。其他函数中的随机 options 尚未全部处理。

verify_splash.gd 的三档数量、配置和寿命回归通过；实际Main470帧/11共享对象/305calls和骨骼、机械、弹匣检查通过。此运行并非受控溅水像素比较，也不是全游戏随机序列证明。具体结果 splash-random-verification.json、splash-random-runtime.json/.log。原作和Godot完整运动、像素联合对照仍需另验。

dust 的 shade 抽样顺序已改为原 L 的 speed 后、life/end-size 前，并保留原法线归一化。原 L/go/M/u1 提取21组、5586draws、12519检查通过，max9.536743e-7，限UP/无遮挡场景。方法SHA256 90339e3d0a3a0c94f705479e8faa30556d5d59bffa6b9cec60379e46aadd1a32。

## 最终扩展与复核修正

溅水和尘土容量扩展至0/1/2/7/12/15/80，共21组各63次调用，包含全满、仅一槽与clear。size1/cap15覆盖第一道波纹成功、第二道失败。溅水10115draws、25419检查含15项定向scatter通过，max4.768372e-7。尘土5586draws、12519检查通过，max9.536743e-7。前述9组数字为中间结果，以本段和最新JSON为准。

scatter改为double标量计算，仅长度恰好0时用1作分母，恢复原go对近零非零向量的行为，最终一次转Vector3。定向输入覆盖零/近零/端点与三个axis。不是任意浮点全域等价证明。puff比较补有限性检查。所有新fixture先量化到k/2^53，再同时供原literal与u53十六进制编码使用，Native解码因此不引入额外输入差异。

扩展测试首次用8192长度tape，原生成器耗尽而未覆盖旧fixture，已扩为32768并确认新21组生成成功。directed样例曾误含不合法Math.random值1，已改为1-EPSILON/2并保留splash-directed-invalid-input.json。不能将这些测试输入错误当生产失败，也不能丢失失败记录。

最终scatter修改前的780流程通过；修改后的470实机11共享对象/295calls、骨骼/机械/弹匣检查全部通过，结果见splash-dust-runtime。Astra复核见splash-random-review.md。

## 火花与命中闪光

原 T/_ 中的抽样顺序是 scatter四次、speed两次、life、size、红色shade、绿色shade，再emit内部seed。旧Native先取size、共用一次shade且延后life，造成消费次数和色彩都不一致。已按原顺序改为红绿独立shade；蓝色保持原常量比例。

新增flash对应原w，先emit再成功时rotation，满池不取rotation。金属、敌人命中、通用sparks、敌人muzzle使用此helper；敌人命中恢复w的fade_out=.2、sk=1.5及随机rotation。随机frame仍由调用者在emit前求值，满池也消耗这一项，与原参数求值一致。

sparks_random_reference.cjs直接提取go/T/_/w/u1，21组count2/9/18与容量0/1/2/7/12/15/80，连续饱和及clear，外加两道flash和随机frame。6485draws/12429检查通过，max1.907348636e-6，tol2e-6。方法SHA256 d4b9f63758d7b19bb9f13cd70cd823404630d1ecfcce5b4faea7815dffe3e479。

另提取完整原H及其helper，21组scale0/.55/1、同七容量，包含原scale0回退1，1812draws/13149检查通过，max1.907348633e-6。方法SHA256 290c8355d54cefb7bd33aa6b5f7ccc3fbad0848a7084b33efa1a9fb814c414e0。仅UP方向/默认color、发射后粒子字段和消费计数；light请求本测试stub，光照配置由已有enemy-muzzle-verification另验。没有声称原H任意方向/颜色/像素全域等价。

实际Main470帧11共享对象/332FXcalls、骨骼/机械/弹匣检查通过。原粒子运动3376字段/92帧回归、爆炸物180步8180检查/40leak以及既有敌人muzzle配置回归通过。日志与结果为sparks-random-*、muzzle-random-*。FX默认输入不同可导致跨次call总数不同，不是固定序列对照。

剩余已定位：ExplosionEffects.flash仍有独立先rotation后emit实现；完整原Q和emitters联合随机顺序待整体对照。Main当前命中decals在impact之前，而原A的p.add在分支尾，需连同原A的碎片、光源节流、木材概率闪光和地面积水重分类一起处理。当前helper通过不能扩展为完整A/Q或全游戏一致。

## 完整命中 A 的生成状态

补齐金属/敌人共享 impact_flash_time=-1 的光源节流，条件保持 clock-last>.09，颜色、位置、半径、能量与原A一致；不在clear时重置该时钟。wood使用dust返回的shade，只有shade>.5才消费概率draw，概率<.3时调用原w对应flash。法线平方长度<1e-6回退UP，入射方向平方长度<=1e-6回退-normal。正常Main玩家射击和敌人命中将弹痕从impact前移动到impact后，符合原A分支尾p.add的相对位置。

impact_random_reference.cjs直接提取原A、go/M/_/T/w/S/R/L/k/u1及原jg.add，使用原Float32数组保存碎片；p.add不消费随机数。64组覆盖8材质、远近、容量2/80及受控shade1/.2，每组6时间点0/.05/.09/.090001/.18/.180002。metal组交替enemy，检查共享节流互相抑制；加入zero/tiny入射与法线回退。最终56727draws、353470字段/计数/光源请求检查通过，max1.907348636e-6、tol3e-6。原方法SHA256 ef64dc9256df30ab0ba47c7c88989e11863bad5c2ea51a2ea19e5a3516c822db。

Native使用真实粒子池、真实debris.emit与共享服务。碎片slot保留CPU color，该值直接驱动MultiMesh custom_data写入；fixture比较原jg.add保存的RGB，含wood、copper/steel等分支。初次在headless空RenderingServer直接get_instance_custom_data全部读回0，失败保留impact-random-headless-color-readback.json。改为CPU生成状态比较后，用实际RenderingDevice另验4种碎片色12通道，custom-data API读回误差0，见debris-color-runtime.json。这不是着色后像素证明。

实际Main含射击470帧11共享对象/315FXcalls、骨骼/机械/弹匣检查通过；780流程pause_frozen=true、最终playing、两次retry。两项实机回归在添加CPU color字段之前，新增字段通过随后实际GPU颜色写读测试验证。结果impact-random-verification.json、impact-random-runtime.json/.log、impact-random-flow.json/.log。早期32组或64组四时间点数字被最终六时间点结果替代。

仍缺原ground.isPuddle重分类与着陆/步行水花事件；受控shade不是实际太阳遮蔽查询证明。A fixture的p.add是无draw接收器，因此尚未证明弹痕与其他消费者交错后的完整随机序列，也不覆盖所有方向、实际运动或整图像素。Main relative order修正有代码与接入回归支持，不能扩展为完整p.add联合证明。原Q及emitters仍待下一阶段。

## 爆炸 Q 初始生成

ExplosionEffects.flash委托原w对应fx.flash。lit火球改为先emit/seed，成功后按frame、rotation、rotv取样；add火球成功后才取rotation。烟团覆盖fin/fout/turb按Float32保存；火花life先于width；地面冲击圈使用原S对应ripple。Q碎片传递最初E(j)得到的floor，避免在抬高后的碎片位置重新查询地面。

新增scatter_components返回double三分量，既有scatter包装成Vector3保持调用接口。Q高速火花直到最终velocity构造才转换Vector3，避免散射方向提前舍入放大。初测速度误差3.814697e-6超过原3e-6阈值，保留explosion-random-initial-precision.json；修正中间精度后通过，没有放宽阈值。

explosion_random_reference.cjs直接提取原Q、go/M/_/T/w/S/R/u1与原jg.add。48组尺寸.1/.4/1/1.9/4/6含clamp，容量2/256、floor0/-50、shade1/.2。122052项字段/计数/碎片RGB/光源请求/发射器创建检查通过，68808draws，最大1.907348636e-6，容限3e-6。原方法SHA256 6631ce8fdd69669354a5ef8d22515402c01d527d6d2330ea4591714470432ff5。Native真实decal参与消费；原p.add接收器仅固定消费三次并记请求，没有完整几何对照。G只记创建，没有原oe或24槽复用验证。原末尾explosion事件的raw size和发送顺序也未由该fixture证明。部分floor0的小尺寸因爆点高度1仍为非grounded，地面分支由较大尺寸覆盖。

六尺寸数量clamp回归通过；受影响scatter的溅水25419检查继续通过。实际Godot --explosion-preview330帧，1次size1.9爆炸，93add/70lit含后续smolder、24debris、2灯、1scorch，末帧粒子/碎片/emitters均0，日志无ERROR。已查看explosion-031.png闪光与045火球展开图，只作实际渲染接入检查，不是原作同帧像素等价证明。结果explosion-random-verification.json、explosion-random-runtime.json/.log。

剩余需要原oe smolder更新、24槽复用与clear后的时序对照，以及完整decal交错、实际遮蔽/地面查询和图像对齐。不能将初始Q通过扩展为整个爆炸生命周期完成。

## 余烟原G/oe生命周期与固定槽

原W保留24槽，G从低索引找首个inactive，oe固定槽序更新。旧Native把alive压紧排列，早期槽位到期后新发射器只能排到末尾，会改变多个发射器交错抽样顺序。现在emitter_slots固定24，_start_smolder复用首个空槽，满池不创建；update按槽序执行；clear仅active=false。emitters getter提供按槽序过滤的活跃字典供统计，不能对临时数组clear以清理真实池，旧数量验证改调用effects.clear。

保留严格time>ttl才停、accumulator>1才发射，dt非正按原le入口转0；ttl=INF和acc恰好1的样例均对照。字段fin按Float32写入。当前仅smolder，原W还由steam/fire/embers/drip共用，其他kind互相占位/释放及其完整行为仍未迁移。source中addEmitter显式调用位于KP showcase，不能据此省略完整API目标。

smolder_reference.cjs直接提取原G/oe/M/u1，仅激活smolder，容量2/256各78步。覆盖第25次满槽拒绝、首槽部分到期后复用、持续存活旧槽、严格ttl/acc边界、INF、负dt入口处理、clear和粒子池饱和。54176项槽状态/返回槽/计数/粒子生成字段比较通过，6732draws，max9.536743e-7、粒子tol3e-6，时间/累积标量tol1e-10。原方法SHA256 0b939540b9e594e5bff26529b724a46e0d832a99ec435414dfadf1f8082d2aa3。

Q fixture同时补真实Native exploded signal观察，原回调记录raw size与发送当时draw、debris、add/lit计数，证明初始生成后发出且不把clamp后的q替换原size。增加432检查，原Q最终122484检查/68808draws通过，替代上一节122052及raw-size未验边界。不是原事件全部接收者、链式损伤联合时序证明。

固定槽后实际Godot爆炸330帧，93add/70lit、24debris、2lights、1scorch，末粒子/碎片/emitters均0。780游戏流程pause冻结、最终playing，三次reset快照emitters均0。日志无ERROR，结果smolder-runtime.json/.log、smolder-flow.json/.log；旧六尺寸数量回归通过。原oe测试仅生成状态，不含粒子运动与渲染像素；新固定槽没有增加其他generic emitter kinds。Astra审查见smolder-review.md。

## 地面事件接入更新

前文的积水重分类、步行/着陆FX缺口现已在高质量1024遮罩范围接入并对照。原mask再生成逐字节一致；90154地面查询、12750回调字段/消费检查及240/780实机通过。详见source-ground-queries.md。level groundSurfaceAt metalRects、其他质量遮罩与整段移动/像素仍未完成，不能据此扩大为全部地面行为等价。

## 默认关卡metalRects补齐

原版实机55区域/12978原查询已取得，闭区间25957检查通过。原玩家H完整优先级1140例与实际Main110静态区域/接触优先检查及240帧事件回归通过。详见source-ground-metal.md；默认4207范围的metalRects缺口关闭，其他种子、质量模式和完整运动/像素仍未证明。

## Jg与A联合消费接齐

原Jg/add/clear独立178步212138检查/531draws通过，修复unknown尺寸、负size、double顶点和F32淡出。真实原A+Jg与Native Main路由64组399796检查/57560draws通过，关闭了原A的decal消费空接收器缺口。仅fx_decals新增FP32 CUSTOM2 normal恢复，31GPU诊断及真实420帧射击通过。见source-decals-joint.md；完整游戏交错/像素仍未证明。

## F烟迹、热烟与同步调用链

玩家/猎犬接原F五团烟迹，Yg F32写入与属性计算对齐，169800检查/366draws通过。玩家impact/decal/爆炸物改为combat信号同步执行，再F/shell；更新按原le lit→add→Yg→debris→shell，115调度/伤害检查通过。热烟归Weapon原smoke/Tick，335状态/options检查通过。最终480帧13shot/12trail标记/6hot smoke、87检查及780reset流程通过。通用ph/I与完整原帧Math.random交错仍未完成。见source-tracer-chain.md。
