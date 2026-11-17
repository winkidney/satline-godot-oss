# Ground、sea、arms 的原 IBL 接入审查

本次只读审查原源码、现有专用 shader、生成器和 IBL service，未修改生产代码。建议扩展共享 helper 输出原 `indirectDiffuse/indirectSpecular`，让三个专用材质各自提供原 F0、辐射输入修饰和最终 normal/roughness，再把结果加入现有 EMISSION。

沿用 [通用 IBL 审查](ibl-integration-adviser.md) 的双零 native ambient/sky 条件。不能将地面反射当成最终发光直接叠加，也不能把海面 `gOcc` 当作通用 AO。

## 原材质与环境绑定

[原导出场景](../assets/export/scenes/main.json) 和 [NVIDIA 环境绑定](../assets/export/fixtures/environment-bindings.json) 确认以下三者均为 MeshStandardMaterial，base color 白、metalness=0、opacity=1、FrontSide、无 emissive、无 AO/normal/roughness 图、无显式 envMap、无环境旋转。

| 材质 | 原基础 roughness | 表面实际 roughness | 环境 |
|---|---:|---|---|
| `apron_wet` | 1 | AP 的 `gRough` 替换基础值 | world，sky×2；RP 可以替换环境 radiance 的一部分 |
| `sea` | .1 | zP 的 `gRough` 替换基础值 | world，sky×2；两路环境输入再乘 `gOcc` |
| `saltline_arm` | .8 | armSurface/armMicro 的 `armRough` 替换基础值 | weapon，室外 sky×2×viewFill，室内 room×viewFill |

不能把 `.8/.1/1` 再乘进过程计算出的 roughness。三个材质的材质级 envMapIntensity=1 在 implicit 环境分支中不额外生效。地面和海面不会因主相机进入室内改用 room。

原对象共四个：`apron`、`sea` 使用世界层，左右两个 `arm-mesh-*` 使用 weapon 层。专用接入后，原资产覆盖应由 generic 的 135 材质/250 对象扩展到 138 材质/254 对象，另行统计运行时复制体。

## 地面的执行顺序

原 [Nw patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L56104) 顺序是：AP 得到颜色、`gRough/gNxz/gPuddle/gSoak`；建立原 PhysicalMaterial；修改湿 F0；采样 PMREM；执行 RP 修改 radiance；最后运行间接 BRDF。

湿 F0 应在 multiscattering/DFG 之前写入：

```text
wetF0 = max(gPuddle, gSoak * .5)
F0 = mix(vec3(.04), vec3(.075), wetF0)
```

保持源码的 mix 权重，不另加没有来源的 clamp。这个 F0 同时改变 single scattering、multi scattering 和由能量补偿衰减的间接漫反射。只改变最终 specular 的颜色不能复现原算法。

RP 的 [原代码](../../artifact-rendering-study/source/extracted/bundle-1.js#L56064) 使用 `material.roughness`，即：

```text
r = min(max(gRough, .0525) + geometryRoughness, 1)
```

三 tap LOD、纵向 stretch、`pw`、cubeUV roughness 层和 DFG 必须共用这个最终 `r`。现有生成器把 `material.roughness` 简化成 Godot `ROUGHNESS=gRough`；本次扩展应消除这个语义分叉。当前地面是平面，几何粗糙度通常为零且 gRough 下限高于 .0525，但不能据此把两种定义永久混用。

RP 原样保留三个样本的 `.5/.25/.25` 权重、各自 LOD、uv clamp 和 `pr=min(pr,48)`。随后只执行：

```text
environmentRadiance = PMREM_radiance * 2
radiance = mix(environmentRadiance, pr, pw)
iblIrradiance = PI * PMREM_roughness1 * 2
```

`pr` 是反射场景已经得到的 HDR 辐射，不能再乘环境强度 2。RP 不修改 `iblIrradiance`，也不修改 diffuseColor。结果是平面反射影响 single-scattering 间接镜面，而 PMREM 驱动的间接漫反射与 multi-scattering 仍保留。不能先混最终 IBL 总颜色，也不能直接把 `pr*pw` 加到 EMISSION。

建议把 RP 输出保存为局部 `overrideRGB/overrideWeight`，传给共享 source IBL helper，在调用 `RE_IndirectSpecular_Physical` 前完成混合。该 helper 的材质 AO 输入为 1。

原 `min(reflectedLight.directSpecular,40)` 位于全部灯光累积之后，和 RP 的输入 `pr<=48` 是两件事。不要给 source indirectSpecular 再套 40 的 clamp。现有太阳单独 clamp 与 native local-light 分支尚不等于原多灯总和 clamp，本次仍单列 pending。

### 就绪状态与旧路径

状态分支应以 `source_ibl_ready` 判断：

- ready：双零 IRRADIANCE/RADIANCE，启用时加 source IBL，RP 只作为 helper 的输入。
- not ready：保留旧 native 环境和 `RADIANCE=vec4(pr,pw)` fallback。

`source_ibl_ready=true` 而诊断开关 `source_ibl_radiance_enabled=false` 时，应仍双零 native 且不加入 source IBL，不能落回旧 RADIANCE。否则 IBL off 探针会重新出现 native 间接光。

反射 producer 的 ready 与 PMREM ready 是两个独立状态。PMREM 已就绪而 `uReflOn=0` 时应正常使用 sky radiance；不能把未就绪的黑反射图以 pw=1 混进去。保留目前 producer 的 `uReflOn` 门控。旧 ground 的 `specular_occlusion_disabled` 与 RADIANCE fallback 有历史关联，不能在保留 fallback 的同时无验证地移除。

## 海面的遮蔽与高光

原 [sea patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L56450) 在环境采样之后、间接 BRDF 之前执行：

```text
radiance *= gOcc
iblIrradiance *= gOcc
```

`gOcc` 来自近岸/船体距离与 swell，其范围约为 `.24..1.05`。允许大于 1 是原行为。共享 helper 应提供独立的线性环境缩放参数；sea 传 `gOcc`，AO 传 1，wetF0 传 0，planar override weight 传 0。

不能沿用当前 `AO=clamp(gOcc,0,1)` 来表达这条源公式。通用 AO 对 diffuse 和 specular 使用不同函数，specular occlusion 还依赖 view/roughness，并会丢掉 >1 的增益。新 source IBL ready 时可将 AO 明确设为 1；旧 AO 近似若需保留，只属于 not-ready fallback。

这个缩放不影响 directDiffuse/directSpecular、颜色或材质 F0。海面 F0 保持 .04，不能套用地面的 .075 湿 F0。固定材质及视角后，gOcc 从 1 改成 1.05 应让两个间接项都增加 5%，直接光不变，这是最小区分测试。

原 sea 的 [glitter patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L56461) 仅处理已累积的 directSpecular：先总和 clamp40，再乘 `gSpark*mix(.3,1,az³)`。环境镜面不能乘这个 glitter，也不能被该 clamp 限制。现有 source sun 和每个 native local light 分别 clamp 的差异继续保留，不因 IBL 接入而宣称完成。

原远处 haze 在最终 outgoingLight 上执行。[DP](../../artifact-rendering-study/source/extracted/bundle-1.js#L56350) 对应当前 shader 的 FOG 输出。新增 source IBL 加入 EMISSION 后仍应经过这次 haze；不要在 helper 中预先混 haze，再由 FOG 混第二次。

Godot 的 custom FOG 分支将 RGB 预乘 opacity、将 alpha 转为 transmittance，再在最终颜色总和后混合，因此当前 sea 路径会覆盖 EMISSION。环境本身关闭普通 fog 不影响这个自定义值；不要给 sea 添加 `fog_disabled`。内部 fog 系数会 pack 成 half，和原 FP32 outgoingLight mix 仍需数值对照，不能只凭顺序正确便宣称完全相同。[custom FOG 处理](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1487-L1530)、[最终混合](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L3095)

## 手臂的 normal、roughness 与环境

原 [QE patch](../../artifact-rendering-study/source/extracted/bundle-1.js#L75282) 只替换颜色、roughness 和 bump normal，没有特殊 F0 或环境遮蔽。颜色来自 armSurface/armMicro，metalness=0、F0=.04、AO=1；手臂湿度不是地面 wetF0。

`armRough` 已在 armMicro 限制到 [.05,1]，随后原 PhysicalMaterial 再应用 `.0525 + geometryRoughness` 的规则。供 geometry roughness 使用的 normal 必须在 `armBump` 前保存；环境方向、dotNV 与 DFG 使用 `armBump` 后的最终 normal。

`armBump` 的位置参数原为 `-vViewPosition`，等于实际 view-space vertex position。当前 `v_view_pos=MODELVIEW_MATRIX*VERTEX` 对应这个语义；不能改成 rest-space 位置。rest/hand attributes 继续只服务原过程纹理。

两个 arms 节点都必须设置实例 slot 10 的 viewmodel 标记，并绑定 source 材质 ID。不能只把 arms shader 加进 SUPPORTED，却因为专用 factory 没有 `source_material_id` 而在审计中静默使用空记录。室内判定、viewFill 与 generic weapon 相同；不要把左右手的材质默认强度 1 当作固定最终强度。

## 当前 pass 的相机与世界坐标

Godot Forward+ 将 `CAMERA_POSITION_WORLD` 映射为当前 `inv_view_matrix[3].xyz`，不是 MAIN_CAM_INV_VIEW_MATRIX。[编译映射](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L787)

当前 ground 使用该 builtin；sea 在 vertex 从 `INV_VIEW_MATRIX[3]` 传出 `sea_camera`。两者适合当前 main、reflection 和其他场景 capture pass。不要把全局主相机位置 uniform 用于这些表面距离、glitter、haze 或 IBL 方向。

原 sea 的 `vGWorld=swp` 保存位移前的世界点，之后仅 `transformed/VERTEX` 加波浪位移。这个区别用于原细节纹理、相机距离、glitter 和 haze，应保留。与此同时，Standard 的几何 view direction 来自实际变形后的 view-space position，不能用未位移的 vGWorld 重建它来替代 `normalize(-VERTEX)`。

主相机只用于 weapon 的室内环境选择和 viewFill 更新。当前 pass 的 INV_VIEW_MATRIX 则用于最终 normal/reflect vector 转到 PMREM 世界方向。其他 world Standard 对象在反射/capture pass 中也遵循后者，不能被主相机方向锁定。

装饰性的 `saltline-gulls` 在 [55282–55304](../../artifact-rendering-study/source/extracted/bundle-1.js#L55282) 使用 MeshBasicMaterial，仅 patch vertex，不需要 IBL；不要和敌机 Standard 材质混同。其创建条件是 sky/crane 场景开关，不是环境光材质开关。IBL service 扩展仍限 Standard 三个专用 shader，不能扩大为所有 world 对象。`ground.stub` 的普通 asphalt fallback 也不是 apron 专用 IBL 的额外触发条件。

当前 planar producer 将 apron/sea/rain 等从 reflection camera 层排除，避免地面采样自己正在生成的反射图。扩展 IBL service 的遍历和层标记时不能恢复这些排除层。ground/sea 即使改在 MAIN_ONLY_LAYER，slot10 仍应为 false；arms 不进入世界反射 pass。

原三个材质均 FrontSide，而现有 ground/arms 使用 cull_disabled，这是已有的背面行为边界。IBL 接入测试不要把从背面看见的结果当作原作应有光照；本轮若不调整剔除，应继续记录该边界。

## 共享 helper、生成器与验收

共享 helper 至少需要分别表达湿 F0、线性环境缩放、radiance override RGB/weight 和材质 AO，不能用一个“occlusion”参数混合不同语义。最好输出 indirectDiffuse/indirectSpecular 两项，以便独立测试，最后再求和加入 EMISSION。generic 调用保持 wetF0=0、环境缩放=1、override weight=0，保留现有 AO 语义。

同时更新 ground/sea/arms 的原提取生成器、sun/IBL bridge 注入顺序和 service SUPPORTED/材质 ID/实例标记。重跑生成器后必须仍得到同一 helper 接线；不要只改已生成的 `.gdshader`。共享 helper 变更后重跑已有 135/250 generic 验收，防止特殊参数污染通用路径。

最小新增验证：

1. Ground：固定真实 PMREM 和受控反射纹理，pw=0/部分/1，湿 F0=0/.5/1，比较原 RP+物理 BRDF。改变 pr 时 indirectDiffuse 应不变；planar 部分不额外乘环境强度，pr 输入保留48限幅。
2. Ground：覆盖 PMREM ready/reflection ready 四种组合与 radiance-enabled off，验证没有黑图以满权重进入、没有 native/source 双加，也没有 off 回落 native。
3. Sea：gOcc=.24/1/1.05 直接比两个间接项，确认线性缩放；直接光/glitter 固定不随 gOcc 改变。单独验证 haze 只混一次。
4. Arms：实际左右手、dry/wet、相机内外与 viewFill，确认 slot10、最终 bump normal 和 .0525 几何粗糙度规则；不要只用一个平面常量 normal 探针代替。
5. 实景：两份 PMREM、native 双零抑制和 HDR>1；旋转主相机及 reflection camera 后，world Standard 对象的环境方向随当前 pass 正确变化，ground/sea 排除层保持，装饰 gulls 仍按原 Basic 材质绘制。记录新增三材质四对象与 runtime copy 的覆盖。

所有原参考应在已经确认的 NVIDIA 后端执行。特殊 IBL 与实景贡献通过后，可声明三个专用材质的间接光接入；多灯 directSpecular 总和限幅、原生 local-light BRDF、背面行为和完整最终画面仍按各自证据判断。
