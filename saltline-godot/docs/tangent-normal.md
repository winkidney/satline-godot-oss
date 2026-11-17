# 原非三平面法线切线基

原Three `getTangentFrame` 见 `bundle-1.js` FR（约23071行），双面T/B校正见PR（约22984行），原vk采用该tbn。源场景无导出tangent属性、无flatShading材质，因此通用normal-map采用导数切线基。

生产 helper `shaders/source_tangent_normal.gdshaderinc` 保留原 det==0 时scale=0语义；双面背面先翻非扰动normal，再对T/B乘faceDirection。相比旧实现，补齐双面T/B校正，取消人为det下限，并以反向dFdy还原WebGL导数方向。切线基的UV使用原normalMapUv（当前map repeat/offset），不乘uSlUv.xy；贴图采样仍使用原slUv。

参考 `source-tangent-original.glsl` 直接提取原getTangentFrame，`tools/tangent_reference.html`运行真实导数。32组镜像UV、零UV、正背面与map方向对照：Canvas512通道、真实空间QuadMesh/Camera98304通道均零失败，max .00048828125，绝对门槛 .001。见 `tangent-verification.json` 和 `tangent-spatial-verification.json`。空间探针使用真实Vulkan投影，但仍为受控线性梯度；源模型插值、normal贴图实际过滤与各纹理独立变换尚需画面验证。

真实场景360帧回归通过，日志见 `noise-tangent-regression.log`。不据此宣称完整原PBR材质已一致。
