# 来源索引

研究日期：2026-11-14。原游戏结论以本地用户提供文件为准；外部资料用于核对 Godot 能力及材料概念。`stable` / `main` 链接会更新，实际实现应按目标版本复核。

## 原始样本与版本

- [用户指定 Artifact](https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp)，自动访问被安全验证阻止，未验证远端与本地内容相同。
- 用户提供 `Saltline (Copy).html`，原样存为 [saltline.original.html](source/saltline.original.html)。哈希与脚本边界见 [source-and-evidence.md](docs/source-and-evidence.md)。
- 内嵌引擎 revision 为 Three.js r180；[官方 r180 源码](https://github.com/mrdoob/three.js/tree/r180)、[官方 r180 许可证](https://github.com/mrdoob/three.js/blob/r180/LICENSE)、[本地 MIT 许可副本](references/THREE-r180-LICENSE.txt)。整个游戏的许可未从库许可推定。
- [Claude 导出说明](https://support.claude.com/en/articles/17153992-what-are-artifacts-and-how-do-i-use-them)，用于用户下载指导。

## 官方文档与原始研究

下列资料在分项报告中对应具体技术；Godot 版本本机静态查询为 `4.7.2.stable.official.ed1daf0bf`，后续已用该版本运行独立实验。

| 资料 | 使用位置 |
| --- | --- |
| [StandardMaterial3D 官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html) | [godot-reference.md](docs/godot-reference.md) |
| [Spatial shader 官方参考](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins) | [godot-reference.md](docs/godot-reference.md) |
| [BaseMaterial3D 官方属性](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-anisotropy-enabled) | [godot-reference.md](docs/godot-reference.md) |
| [Shading language 官方参考](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#using-source-color) | [godot-reference.md](docs/godot-reference.md) |
| [图像导入文档](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html#process-normal-map-invert-y) | [godot-reference.md](docs/godot-reference.md) |
| [环境与后处理官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#background) | [godot-reference.md](docs/godot-reference.md) |
| [灯光与阴影官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html) | [godot-reference.md](docs/godot-reference.md) |
| [ReflectionProbe 官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html) | [godot-reference.md](docs/godot-reference.md) |
| [Environment 官方 API](https://docs.godotengine.org/en/stable/classes/class_environment.html#class-environment-property-ssr-enabled) | [godot-reference.md](docs/godot-reference.md) |
| [StandardMaterial3D 透明说明](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#transparency) | [godot-reference.md](docs/godot-reference.md) |
| [Screen-reading shader 官方文档](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) | [godot-reference.md](docs/godot-reference.md) |
| [Environment 官方处理顺序](https://docs.godotengine.org/en/stable/classes/class_environment.html#description) | [godot-reference.md](docs/godot-reference.md) |
| [3D 抗锯齿官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html) | [godot-reference.md](docs/godot-reference.md) |
| [Irawan 与 Marschner，Specular Reflection from Woven Cloth，2012](https://www.cs.cornell.edu/~srm/publications/TOG12-cloth.html) | [godot-reference.md](docs/godot-reference.md) |
| [Sadeghi 等，A practical microcylinder appearance model for cloth rendering，2013](https://graphics.ucsd.edu/~henrik/papers/practical_microcylinder_appearance_model_for_cloth_rendering.pdf) | [godot-reference.md](docs/godot-reference.md) |
| [SoftBody3D 官方 API](https://docs.godotengine.org/en/stable/classes/class_softbody3d.html) | [godot-reference.md](docs/godot-reference.md) |
| [ORMMaterial3D](https://docs.godotengine.org/en/stable/classes/class_ormmaterial3d.html) | [materials-and-textures.md](docs/materials-and-textures.md) |
| [SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html) | [materials-and-textures.md](docs/materials-and-textures.md) |
| [compute shader 教程](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html) | [materials-and-textures.md](docs/materials-and-textures.md) |
| [官方 compositor 教程](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html) | [rendering-port-map.md](docs/rendering-port-map.md) |
| [CompositorEffect 官方参考](https://docs.godotengine.org/en/stable/classes/class_compositoreffect.html) | [rendering-port-map.md](docs/rendering-port-map.md) |
| [官方体积雾教程](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html) | [rendering-port-map.md](docs/rendering-port-map.md) |
| [CameraAttributes 官方 API](https://docs.godotengine.org/en/stable/classes/class_cameraattributes.html) | [rendering-port-map.md](docs/rendering-port-map.md) |
| [粒子参数](https://docs.godotengine.org/en/stable/tutorials/3d/particles/process_material_properties.html) | [surfaces-fx-and-cloth.md](docs/surfaces-fx-and-cloth.md) |
| [MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) | [surfaces-fx-and-cloth.md](docs/surfaces-fx-and-cloth.md) |
| [官方深度重建](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html#depth-texture) | [surfaces-fx-and-cloth.md](docs/surfaces-fx-and-cloth.md) |
| [Godot Decal 官方教程](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html) | [surfaces-fx-and-cloth.md](docs/surfaces-fx-and-cloth.md) |

## 补充材料概念与图片

- [Filament 的 PBR 技术文档](https://google.github.io/filament/main/filament.html)，可继续阅读 BRDF、IBL、cloth 与成像链路。这是概念参考，不表示 Saltline 使用 Filament。
- [Khronos KHR_materials_sheen](https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_sheen)，用于理解独立织物 sheen 层；其 cushion 图已收集。
- [Khronos KHR_materials_anisotropy](https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_anisotropy)，用于区分材质方向高光与纹理各向异性过滤。
- 参考图的文件、直接下载地址与用途见 [references/README.md](references/README.md)。

## 邻接项目证据

`stocking-lab` 只读用于匹配已有 shader、数据与灯光接口。该项目已有能力只按本轮读取的代码描述，没有在本轮运行核验。链接见 [Godot 技术参考](docs/godot-reference.md)。其模型、贴图和原有证据没有复制到本学习项目。

## 深入研究与运行

- [核心公式与原始资料](docs/deep-implementation.md)补充PCSS、体积积分、Karis、曝光与裁切。
- [实机报告](docs/runtime-findings.md)与[Godot实验](docs/godot-experiments.md)记录当前实际观察。
- [WebGL GPU计时规范](https://registry.khronos.org/webgl/extensions/EXT_disjoint_timer_query_webgl2/)用于disjoint处理。
- Astra Ultra作为本轮顾问审阅采集与Godot边界，发现并修正干湿端点、反射同步、法线方向和采集时序问题。结论仍由运行证据验证。
