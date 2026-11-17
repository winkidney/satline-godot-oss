# 原局部灯光与统一直接光

原 `bundle-1.js` 22187–22255提供距离衰减、spot平滑锥与Point/Spot信息。`tools/extract_local_lights.py` 字面提取原函数/结构到source-local-lights-original.glsl，并生成机械重命名的生产 `source_local_light_math.gdshaderinc`；已接入主材质统一直接光路径，当前状态与验证见末节。前面的阶段记录保留当时边界。

## 原点光核心验证

`local_light_reference.html` 在NVIDIA后端执行原函数。192组距离/截止距离/decay/角度，使用RGBA16F输出。独立 `verify_local_light.gd -- --point-only` 检查当前实际项目使用的点光路径，192组768通道零失败，原abs.001/rel.0015门槛不变；见point-light-verification.json。零向量Point输入以1e-6位移避开undefined normalize(0)，pow(0,0)不进入测试，不声称这些未定义情况一致。

完整Point+Spot诊断仍保持失败 `local-light-verification.json`：6个Spot visible标记在coneCos=.92边界上不同，NVIDIA OpenGL与Vulkan归一化后跨阈值；其余radiometric输出通过，微小颜色写入RGBA16F后均0。没有加epsilon、扩大门槛或把失败标记成通过。原active项目没有Spot构造，因此此边界不作为当前Point集成门槛，但未宣称完整Spot helper已对齐。

## 四盏仓库原灯与武器补光

源场景有6槽pool、4个level-dynamic PointLight及sun/viewmodel-key。之前加载器把所有源light节点建成Node3D，仓库4点光缺失；pool和key由独立系统重建，所以不能把它们再实例化一遍。

`source_scene.gd` 现只把原level-dynamic点灯建为OmniLight3D，保留原位置、linear颜色、source intensity34、range13、decay2、shadow=false与世界/weapon兼容mask。source_intensity单独存metadata。Godot默认非physical units内部把energy乘PI，所以当前static fallback energy=34/PI，避免额外PI；这只是临时native桥，不等于原attenuation/BRDF。

main保存实际view-key节点，原方向来自position-target=(-.65,.85,1)，室外source强度.9、室内.9*.55=.495；inside采用首室内box严格xz且y<max，不设y下限。fallback energy同样除PI，source_intensity独立保存。该动态强度不与IBL viewFill混用。

`source-local-nodes-verification.json` 实际原4节点位置误差0、颜色差约2.88e-8、源单位/范围/decay/shadow均通过；4个内外/边界key状态及方向误差<=1.28e-7。4灯开关改变36714个HDR抽样点，截图warehouse-lights-on/off.png，已查看开启图。该检查证明补回实际灯与贡献，不证明Native BRDF一致。

360帧sourceSun/PCSS与240帧planar回归均通过，无脚本/shader/引擎错误或泄漏。

## 下一步与边界

原局部点灯仍走Godot native attenuation/GGX。6槽pool已拆分source_intensity与native light_energy，flash/scan/release/TTL共用set_energy，native只接source/PI；源TTL与peak保持原单位。下一阶段应统一source state与native输出，通过原灯数据atlas和既有RE_Direct_Physical替换实际局部光，再按原points(pool6→static4)→sun→key顺序累积。ground/sea对所有directSpec总和仅clamp40一次，sea随后乘glitter；IBL不进这个clamp。

需要隔离native fallback、保持world/weapon源mask、在pool.update之后及reflection/world前上传、验证动态flash/scan和生命周期。源4仓库灯static无flicker，原数据不应被改造成动画灯。顾问依据见local-light-adviser.md。

时序补充：原pool在render.frame开头更新TTL，即使暂停也会衰减。实际game路径已移到_process，每渲染帧一次并保留dt上限.05，physics效果路径不再更新。light-pool-render-timing-verification.json验证四次物理tick不衰减、playing/paused分别一次，源强度100→95→90→88与native /PI一致，persistent42保留。首次测试退出早于GPU flush导致material-null错误，失败日志保留；补齐frame_post_draw后退出清理通过。Gull600帧回归完成，扫描/攻击/死亡流程指标保持。game-flow证据780帧记录pause冻结和两次重置，旧进程句柄已不存在，仅凭现存日志不补称其退出码。

## 局部灯数据上传已接入，BRDF消费待完成

source_local_light_data.gd每帧在pool.update之后、reflection/sun/world之前上传4×11 RGBA32F：前六行原pool顺序、接着原四仓库灯顺序、最后key。太阳在实际BRDF累积时仍须插在points与key之间。四列依次是world position/range、linear color乘source intensity/decay、world direction/type、原mask/visible/source intensity。原mask独立于native fallback位，禁止从light_cull_mask高位反推源图层。key方向保留camera-parent world basis，暂停仍更新数据。

local-light-data-verification.json在实际Main验证playing/paused分别上传一次、源95/93与原mask3、隐藏灯标记、四原仓库行及室内key .495，整张176通道GPU读回逐字节一致。测试初版遇鼠标捕获错误和连续绘制等待，日志保留；最终关闭测试捕获并显式force_draw驱动GPU，退出0且无SCRIPT/SHADER/引擎错误或泄漏。当前atlas尚未绑定生产shader，native fallback仍负责局部直接光，因此不声称原attenuation/GGX或ground/sea总spec clamp已完成。

## 统一原直接光默认接入

source_direct_surface.gdshaderinc复用原PointInfo、PhysicalMaterial与RE_Direct_Physical，十点光按pool6→warehouse4顺序，随后太阳PCSS，最后武器key。直接在当前view空间计算light vector，避免重建world位置再变回view的精度损失。ground/sea仅在全部directSpec累加后clamp40一次，sea随后乘glitter，IBL独立。原sourceSunTerms保留供旧独立太阳核对，生产五类shader改用sourceDirectTerms/Radiance。太阳关闭的诊断不再连带关闭local。

source_local_light_service.gd默认迁移254对象；动态材质通过source_shader_path识别。全部支持的surface迁移才隔离native；Basic保持unlit。world/weapon fallback使用bit18/17，与原sun bit19分离，shader实例active占slot11。Point native mask只含两个fallback位，key仅weapon位；fallback关闭迁移时恢复原mask，dispose先解绑材质再释放atlas。每帧上传后扫描新几何。实际灯选择使用CAMERA_VISIBLE_LAYERS，剥离fallback高位并将world-only bit4映射原world1；不能以对象layers推断收灯相机。

原NVIDIA Three独立组合参考72组、576通道，与生产sourceDirectTerms对照全过，15组实际触及高光限幅，abs.002/rel.003沿用既有sunBRDF门槛。包括十点光顺序、不同source强度、cutoff、visibility、相机mask1/2、view旋转、metal/rough/wetF0和clamp后glitter。此核对关闭PCSS、几何法线导数0，不能据此宣称全部材质或完整像素一致。见direct-lights-verification.json及direct_lights_reference.html；fixture源为literal原函数，不调用生产helper。

实际Main双pass：local off/on改变world42267、weapon5881个HDR抽样点。全部11 native灯在Main更新后强制energy1000，实际draw前值逐灯记录均1000，两pass差0；避免Main把key/pool能量重置后误判隔离。enabled off/on回入差0，原mask恢复。231个world几何临时layers3，key off/on世界差0、weapon29309点变化，证明按当前相机收灯。初版错采scene_port合成图导致共享层检查失败，保留local-light-service-composite-probe-failure.json；已改world_port独立读回。实际截图local-direct-on/off.png，开启图已查看。

Astra审查同时修正手臂armBump输入：原Three先normalize插值法线，Godot现同样先normalize(NORMAL)，生成器同步。三个special shader完整重生两次幂等，反射/IBL/直接光接入均保留，见local-direct-generation-verification.json。完整视觉、材质其他procedural patch、动态战斗光视觉与性能、packaging等总目标继续。

最终回归：sourceSun360帧、planar240帧failure均空，独立原灯节点审核更新为切换source_intensity后通过（39814 HDR点变化），所有最终日志无SCRIPT/SHADER/引擎错误或泄漏。另见local-direct-source-sun.log、local-direct-planar.log、local-direct-source-nodes.log。
