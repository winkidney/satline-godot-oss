# 原太阳直接光与 PCSS：独立核心和反射兼容验证

本阶段移植原 Three Standard 的太阳 Lambert/GGX 与原 jM 表面 PCSS，并在真实固定4096阴影图的受控反射场景验证。后续已默认接入全部138个原Standard材质、254个原对象；完整局部光/IBL及特殊多光源总和仍未迁移；不能据此宣称全场景照明或完整平面反射已完成。

## 为什么迁移太阳项

此前原斜投影在 Godot XR 入口裁剪几何正常，但原生 cascade 从斜投影推导 near/far 得到10.147/-2.701，导致墙面阴影丢失。原作本就使用固定单图而非Godot多级cascade。沿用已完成的 SunShadowPass、移植原接收端PCSS和直接BRDF，既避免该标准投影假设，也更接近原照明语义。顾问选择与源码依据见 [planar-adviser.md](planar-adviser.md)。

## BRDF 原公式

`tools/extract_sun_brdf.cjs` 从原 bundle Three r180 ShaderChunk 提取 IncidentLight、ReflectedLight、PhysicalMaterial、Lambert、Schlick、SmithCorrelated、GGX 和 RE_Direct_Physical。原文存为 `assets/export/fixtures/source-sun-brdf.glsl`，Godot可复用函数为 `shaders/source_sun_brdf.gdshaderinc`。仅移除Godot参数不需要的`const in`限定，保留条件分支。

原 Standard 使用 Lambert 而非 Burley；太阳输入为线性(1,.72,.42)×9。diffuse=base×(1-metal)；F0=mix(.04,base,metal)，ground另混到.075；rough=min(max(input,.0525)+geometryRoughness,1)。SmithCorrelated与exp2 Schlick均保留，不继承当前native sun energy3，也不额外乘π。

`sun_brdf_reference.html` 实际在原Three GPU执行提取函数，漫反射与镜面分别写RGBA16F。96组包含metal0/.35/1、粗糙度下限、geometryRoughness标量、掠射、湿F0和visibility1/.6/0。`verify_sun_brdf.gd` 检查768通道，原预设max(.002,.3%)零失败；高光最大42752，覆盖真实HDR而非只测0..1。该测试的geometryRoughness是输入标量，尚未证明任意曲面导数或纹理材质准备。证据 `evidence/sun-brdf-verification.json`。

## PCSS 原公式

`tools/extract_sun_pcss.cjs` 实际执行原 jM，按原高画质生成8次blocker search、16次filter。保持toFixed(3)后的frustum(88.699,54.781)、depth141.881、bias=-.00012、radius1。它不是Y9的单tap/.0006算法。

接收平面depth gradient由实际fragment dFdx/dFdy计算；斜率限幅、.35 texel补偿、Vogel/IGN旋转、blocker平均、距离相关penumbra、最小1.25texel过滤半径和图边缘淡出全部来自原生成字符串。仅将packed RGBA解码改为等价标量R32F读取，并在采样时做一次源UV y翻转。FRAGCOORD也转为原底部起始。

`sun_pcss_reference.html` 用实际原packed RGBA阴影和原jM计算；原生probe以相同数值深度输入对照。16组共131072通道，覆盖有/无blocker、不同接收深度/斜率、图边缘/图外、半阴影强度和不同radius；绝对阈值.002零失败，最大.00048828125。大多数受阴影组同时含0与1可见度，部分强度组最低.5，不是全亮空测试。见 `evidence/sun-pcss-verification.json`。

## 实际反射阴影恢复

`source_sun_surface_probe.gdshader` 在空间vertex中以原world normal偏移.02计算shadowCoord；fragment用最终view normal、view方向、原太阳方向和逐分量法线导数准备BRDF，再结合原PCSS。输出是已经完成BRDF与阴影的线性直接radiance，经EMISSION出口累加；材质保持shaded，不把裸反射图或albedo当自发光。受控场景没有native太阳，故不存在重复加光。

`tools/verify_planar_source_sun.gd` 使用与之前cascade问题相同的相机/反射投影结构，在深度0..40的墙、方块和悬空遮挡物上运行固定4096 source caster pass。为原低角度太阳调整悬空遮挡物位置，确保墙面实际接收其投影，不要求暗像素数量等于旧native cascade的434。geometry均用与导出资产一致的ArrayMesh，cast和receive在本fixture均开启。

结果：无阴影时7814亮像素，有阴影时7206；开启原PCSS使752像素显著暗化。普通GL与原oblique在两种状态下都逐像素相同，最大差0，零失败。原生cascade的失败对照保留不改绿；替代路径成功单独记录在 `evidence/planar-source-sun-verification.json`。截图 `planar-source-sun-sun_shadow-true.png` 是受控诊断场景，不是最终原游戏画面。

## 仍需完成

- 真正原Three几何/normalBias端到端画面对照和更多曲面、法线贴图、非均匀缩放、双面、skin/MultiMesh。
- 默认原场景 Standard/ground/sea/weapon等逐材质接入、receiveShadow/castShadow/Basic独立规则，排除native同一太阳且保留局部灯与原emission。
- ground/sea对所有灯directSpecular求和后clamp40，武器detail对总直接光的遮蔽修饰；只拆出太阳时不能宣称跨灯总和等价。
- reflection读旧太阳图→按原条件更新固定图→main/weapon/Y9的顺序，首帧、暂停/恢复、resize与强制更新。
- 最终反射地面接入、实机开关录像、全场景照明和GPU性能。

## 默认场景的通用 Standard 迁移

`source_sun_surface.gdshaderinc` 现由普通/透明两个Standard shader使用。vertex保存按world normal偏移.02的shadowCoord；fragment保留原emission，再加入完成Lambert/GGX与PCSS计算的太阳radiance。最终normal使用当前已有材质的扰动结果；geometryRoughness使用normal-map之前的当前view normal导数。Basic两种unshaded shader不含太阳项。

`source_sun_service.gd` 遍历当前同World3D的几何，按实际生效的surface/override材质分类，支持实例材质副本；只有所有受光surface可迁移的对象才启用。逐对象instance uniform控制太阳与原receiveShadow。castShadow继续独立由原caster pass处理。动态新几何也会被发现，未知材质仍走原路径。

原生sun仅照独立layer20，已迁移对象不带该层，避免重复直接光；原world/weapon层保留，因此相机和其他灯选择不变。未迁移对象带layer20，保留原native sun。Godot的light_cull_mask与shadow_caster_mask独立，迁移未修改后者；见[官方Light3D](https://docs.godotengine.org/en/4.5/classes/class_light3d.html#class-light3d-property-shadow-caster-mask)。fallback地面仍可使用原生caster，这不是反射cascade的修复证明，特殊材质还须迁移原太阳。

首帧深度未准备好时，原太阳项关闭；就绪后启用。退出先关闭ready、将材质sampler解绑到持有的白色RF fallback，再销毁太阳深度。生产无CPU图像读回。

### 原场景实机证据

`--source-sun-preview` 冻结时间和相机，保留其他灯/IBL、AO/Y9/bloom及最终后期。前120帧只关闭已迁移的直接太阳项（不会回退native太阳），中120帧开启太阳+PCSS，末120帧仅诊断关闭接收阴影。独立审核依据原导出material.type/name及node.receiveShadow，不用service自己的路径分类作为期望值。

全部301个原geometry节点被审核：250个原对象属于可迁移组合，其中原239个receiveShadow=true、11个false。所有迁移、接收标记和native sun排除检查零失败。service还管理54个fallback/unlit/动态几何，该数字不是54个受光特殊材质。诊断末段覆盖关闭阴影，service报告的receivers仍记录原标记数量，另有shadows_enabled=false和独立expected_receivers=0说明实际状态。

太阳开启使8603个抽样HDR像素RGB总差>.003；关闭PCSS再改变5494个。三张截图为 `source-sun-100.png`、`source-sun-220.png`、`source-sun-340.png`，数据见 `evidence/source-sun-runtime.json`。6秒720p60无音轨录像 `evidence/native-source-sun.mp4`。480帧真实场景motion-preview回归也通过。

这证明当前通用材质太阳与阴影接入、对象规则和可见贡献；不能代替完整原版PBR材质图像对照。原法线/triplanar/武器detail等剩余材质差异、特殊材质、原局部灯BRDF、全光求和后的clamp、反射时序和整体性能仍在原任务范围内。

## 地面、海面、手臂的后续接入

默认service现覆盖ground/sea/arms三个特殊shader，原138个Standard材质对应254个对象全部启用原太阳；其中243个原receiveShadow=true、11个false。Basic和原ShaderMaterial仍独立分类。`source_sun_surface.gdshaderinc` 将太阳漫反射和镜面项分开返回，通用wrapper保持原先sum语义。

- ground按max(gPuddle,gSoak*.5)把F0从.04混到.075，原太阳镜面单项限幅40，保留原波纹normal、粗糙度和待接的RP环境辐射。此处是太阳单项限幅；与其他局部灯先合并再clamp的完整原语义仍待全部直接光迁移。
- sea按位移后的实际vertex位置计算shadowCoord，原vGWorld仍保留未位移位置用于表面纹理/雾；保留gSpark与太阳azimuth修饰，原太阳specular限幅40后乘sea_glitter。原native `light()`继续处理其他局部灯，仍有总光clamp差异。
- arms在原armSurface/armMicro/armBump完成后，以最终normal和原roughness求太阳；视图normal导数在bump之前记录。左右两只手保留原receiveShadow=true和castShadow=false。

`--source-sun-preview` 独立原记录审计在254个迁移对象上通过；太阳开关改变11185个抽样HDR像素，阴影开关改变13070个。实际已包含地面接收原PCSS的贡献，不把总变化全归给任何单个材质。480帧solar-preview（开放海面、仓库、转向）回归通过，无shader/script/GPU错误。更新后的6秒录像仍为 `evidence/native-source-sun.mp4`，前面的250对象记录是先前阶段。

三份源表面生成器现通过 `tools/sun_shader_bridge.py` 自动重接太阳部分，ground之后再接RP生成器。重新从原shader生成ground/sea/arms后，与当前文件去空白比较完全一致，防止下次重生成覆盖迁移内容。

仍需做真实曲面/normalBias与原Three端到端画面对照、武器aSurf/detail完整准备、全部局部光与IBL、原多光求和后处理、动态反射及性能验收。这次通过不等于原材质准备已逐项完整相同。
