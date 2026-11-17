# 原环境光照（138 Standard已接入，完整画面对照待完成）

## HDR加载与CubeUV

原Three r180 `bundle-1.js` U8（约21865–21965行）经 `tools/extract_cube_uv.py` 字面提取到 `assets/export/fixtures/source-cube-uv-original.glsl`，生产桥为 `shaders/source_cube_uv.gdshaderinc`。保留getFace平局规则、六面UV、粗糙度分段映射、小粗糙度log2、minMip/minTile与相邻roughness层插值。只将采样换为Godot textureLod(...,0)，因为原PMREM是无mip Linear且roughness层位于同一atlas内。

`scripts/pmrem_textures.gd` 校验canonical `environment/pmrem-gpu/manifest.json` SHA，按原始bottom-to-top上传RGBA16F，不做sRGB解码或mip生成。两张完整GPU读回恢复RGBA32F后SHA均与原HDR资产一致，保留峰值382.25及alpha>1，没有裁剪。

`tools/cube_uv_reference.html` 执行原U8，NVIDIA同后端、同RGBA16F格式和原行序，两张真实PMREM×14方向×8粗糙度=224组，3584通道。Godot生产helper+loader对照零失败，max .0001220703125；预设绝对.001或相对.0015取较大，未调整。14组包含HDR采样，采样最高6。证据 `cube-uv-verification.json`，包含两张完整GPU上传roundtrip结果。较高贴图峰值由全数据SHA验证，不将采样未覆盖的峰值当作方向测试已覆盖。

## 间接光BRDF

`tools/extract_indirect_brdf.py` 提取原 DFGApprox、EnvironmentBRDF、computeMultiscattering、RE_IndirectDiffuse_Physical、RE_IndirectSpecular_Physical、computeSpecularOcclusion 到source-indirect-brdf-original.glsl；生产 `source_indirect_brdf.gdshaderinc` 只移除Godot不需要的const-in修饰。保留Standard能量补偿与最大分量漫反射衰减。

独立原参考还执行原b8 AO块，仅把AO贴图red替换为明确输入uniform，intensity=1。96组金属度、粗糙度、视角、湿F0、radiance/irradiance和AO，768通道GPU对照零失败；RGBA16F可见结果一致，报告最大数值差约7.4e-18（读取转换末位），预设abs.001/rel.0015不变。证据 `indirect-brdf-verification.json`。该测试不含实际环境方向采样、SH或主图材质。

## 核心验证时的边界（历史）

这些核心尚未替换当前场景原生环境光/IBL。接入前必须补核：全局scene.environmentIntensity、材质envMap覆盖/keepEnvIntensity、室内env选择、环境旋转、原ambient/hemisphere/lightProbe、AO只对正确间接项生效、ground/sea原反射与总spec限幅、arms/view-fill特殊处理。原导出props没有包含envMap，不能凭texture尺寸直接给所有材质套室内/室外图；应从原运行时与源码补绑定数据。

不得把核心对照通过当作完整材质或最终画面一致；局部光照、实时环境更新与性能、全目标其余事项继续保留。

## 原环境绑定补采

`export_environment_bindings.cjs` 在原NVIDIA冻结运行时收集195材质，按原遍历顺序映射前逐项检查type/name、roughness/metalness/opacity/side/vertexColors与color，身份零失败；实际served HTML SHA也记录在 `assets/export/fixtures/environment-bindings.json`。原scene环境强度2、旋转0；22个Standard显式室内PMREM强度1，其他隐式环境使用scene强度。Three对envMap=null使用scene.environmentIntensity，不能乘材质上无效的envMapIntensity=1.4。原没有ambient/hemi/probe，故PMREM irradiance只进入IndirectSpecular函数（该函数内部已含能量补偿diffuse），不重复加Lambert环境项。

## 通用Standard默认接入

`scripts/source_ibl_service.gd` 与 `source_ibl_surface.gdshaderinc` 已在默认game路径启用，覆盖135个原通用Standard材质、250个原对象（19个weapon对象），另有一个实际material复制体。ground/sea/arms三个专用材质仍未迁移IBL。

world隐式用sky×2；weapon隐式室外sky×2×viewFill、室内room×1×viewFill；显式room始终用材质强度1，不额外乘viewFill。实例slot10按原layer2标记weapon，当前原对象没有双层歧义。viewFill从原3帧快照值起步，后续采用原XZ sun-facing目标与dt×2.5平滑；室内边界严格x/z且只测y<max，没有y下界。

fragment在source_ibl_ready时以IRRADIANCE/RADIANCE双零覆盖原生ambient/sky，再将原间接结果加到EMISSION，保留既有太阳和局部直接光路径。避免ambient_light_disabled，因其会改变保留的native direct能量补偿。仅当前无后续GI/probe/SSIL/SSR的配置成立。通用wet不改变F0；geometry roughness在最终rr之后用于所有环境方向/层/DFG/AO。AO仅在真正aoMap存在时应用，修正fx_decals有ORM但无AO的例外。

验证：

- `ibl-runtime-verification.json`：135/22材质与250节点view标记独立审计零失败，19weapon；严格室内边界通过。原IBL关闭/开启有47065个HDR抽样点变化、sum约6787.81，截图 `ibl-off.png`/`ibl-on.png`。该检查证明真实贡献，不证明完整原图逐像素相同。
- `ibl-native-suppression-verification.json`：真实generic空间Quad，原生ambient和proceduralSky反射能量0→10，source-ready差0；readyfalse对照全部256像素改变、max RGB20.242，证明原生控制有效且未叠加到source IBL。当前不覆盖lateGI。
- `ibl-sun-regression.log`：360帧原太阳/PCSS/迁移标记及贡献回归零失败，无引擎错误。
- 双环境尺寸参数化后的CubeUV224组与两张完整HDR GPU SHA回归通过。

接入时Godot拒绝函数参数遮蔽global uniform名称，已在可复现提取器中分别命名局部cube_texel/cube_max_mip；最终编译及实机均通过。顾问边界见ibl-integration-adviser.md。

后续仍需专用材质IBL、完整原材质耦合采样/最终图对照、室内移动viewFill时序、更多质量配置与性能。原生局部灯光BRDF仍为待替换项；不将这阶段标记为全光照完成。

## 专用地面、海面与手臂默认接入

`sourceIblTerms` 现显式传湿F0、两路环境缩放、辐射覆盖RGB/weight并返回独立diffuse/specular；generic wrapper保持原接口。地面RP先得到最终roughness（与BRDF共用sourceIblRoughness），三tap结果cap48后只混入radiance，不再额外乘环境强度；iblIrradiance仍来自原PMREM，湿F0按max(puddle,soak*.5)混到.075。source-ready时双零native并加原BRDF；未ready时保留旧native RADIANCE后备。ready但radiance关闭时保持双零，不落回旧反射。

海面把原gOcc线性乘radiance/iblIrradiance，保留约.24–1.05的范围，AO参数传1；direct glitter/clamp保持独立。新增IBL仍进入已有native FOG混合，精确原DP haze含half-pack差异尚待画面对照。手臂用最终bump normal与weapon实例标记，按既有室内环境/viewFill切换。装饰Basic gulls继续不受IBL影响。

全部138个源Standard、254原对象已绑定，21weapon对象、22显式room；实际139个material含一个复制体。原source material ID metadata统一设置，支持三个早返回专用工厂。

验证：

- `special-ibl-gpu-verification.json`：72组原CubeUV+环境采样+间接BRDF耦合，湿F0/planar辐射cap混合、raw gOcc及arms环境选择576通道零失败。RGBA16F结果一致，数值最大差约7.4e-18；原abs.001/rel.0015门槛不变。不包含完整程序化表面/实际planar捕获。
- `ibl-all-standard-runtime-verification.json`：全部138/254环境/viewtag/边界审核零失败，原IBL总开关有47894个HDR抽样点变化。
- `special-ibl-runtime-verification.json`：逐材质关闭/开启，地面13651、海面22543、手臂743个HDR抽样点改变；其他材质保持开启。截图special-ibl-*-on/off.png，已查看最终海面/地面图。
- 最终360帧太阳/PCSS回归、240帧实际planar回归通过，反射开关15859个抽样点变化且原producer顺序正确。IBL未ready的旧planar fallback探针也通过。

生成器审计发现原ground生成器仅产基础shader，reflection由独立工具追加，直接在sun bridge后接IBL会遗漏RP。该问题曾导致planar回归失败，日志保留special-ibl-planar-regeneration-failure.log。现在port_ground_shader完整串联sun→reflection→IBL，reflection工具可重入重建；三种shader连续生成两遍结果一致，evidence/special-ibl-generation-verification.json。最终通过证据均在修复重建后重新运行，不依赖出错前的文件。

仍未完成：所有原程序化材质/贴图实际耦合的完整图像对照、局部灯光原BRDF及所有灯求和后的40限幅、环境更新与室内动态时序、haze精确混合、质量/性能、其余游戏和包装要求。138材质IBL接入不是完整渲染复刻完成。
