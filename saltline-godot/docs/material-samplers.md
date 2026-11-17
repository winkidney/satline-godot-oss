# 通用材质采样状态

源 `assets/export/scenes/main.json` 的 texture wrapS/wrapT、minFilter 与props贴图引用为依据。审计发现所有实际 map/normal/roughness 的repeat/offset/rotation/channel一致，rotation均0；albedo为sRGB，normal/ORM为linear-data。该结论限当前导出场景。

旧通用shader全部repeat_enable，遗漏标签/贴花原ClampToEdge。`source_scene.gd::_generic_shader` 现按每张实际贴图的wrap与minFilter创建缓存shader变体，当前共6种。四个generic将albedo/ORM/normal采样函数分开，避免Godot禁止同一sampler函数参数混用不同过滤/重复状态。已有实际数据只有两轴同时Repeat或Clamp、Linear/LinearMipmapLinear，未声称实现未出现的混合轴或Mirror状态。

动态shader保留 `source_shader_path` metadata，`source_sun_service` 通过该来源继续分类，避免资源路径为空时把材质错误排除出原太阳。首次回归发现的分类失败日志保留 `sampler-sun-identity-failure.log`；修正后360帧 `source_sun_preview_failures=[]`，不是通过改预期隐藏失败。

验证：

- `tools/verify_material_sampler_bindings.gd` 独立检查183个真实generic材质、284个采样绑定，其中50个clamped，与原记录零差异；证据 `material-sampler-bindings-verification.json`。
- `tools/material_sampler_reference.html` 原Three采样与实际native工厂/空间Quad，48个2×2 RGBA8颜色、边界UV样本。24个Clamp样本最大差0。Repeat样本10个超过预设.002门槛，最大差 .00390625，失败保留 `material-sampler-verification.json`；不能宣称完整采样一致。当前怀疑硬件线性过滤舍入，尚未逐级证明，未放宽门槛。
- 该诊断刻意使用非mip Linear以隔离边界；实际generic场景主要使用mip/aniso，诊断不支持其已对齐的结论。贴图mip生成、各LOD过滤及跨后端差异仍需继续。
- 完整场景360帧运行、太阳迁移/receiveShadow/贡献回归通过，日志 `sampler-regression.log` 无脚本、shader、引擎错误或泄漏。

## 硬件过滤进一步定位

Astra新增 `verify_sampler_filter_precision.gd`：32变体×56UV，关闭source_color、RGBA32F仍复现硬件偏差，新增内部UV使Clamp也出现失败；不能归因于Repeat状态本身。手动四texelFetch+mix的16变体均通过，原Three同wrap样本max .00048828125，理想bilinear max .00041014。见 `sampler-filter-precision-verification.json`。尚未把该诊断直接用于所有生产材质，避免错误强制LOD0或丢失各向异性。当前48样本Clamp误差0仅限原选取UV，不代表所有夹取插值通过。

sRGB mip生成另发现明显错误并已修复，详见texture-mips.md；与硬件linear过滤的小偏差为不同问题。

## 同NVIDIA后端及行序诊断

新增 `assets/export/fixtures/material-sampler-reference-gpu.json`，实际ANGLE NVIDIA后端。原生产翻行数据+反转V坐标对该48样本仍10失败，max .0078125，见 `material-sampler-gpu-verification.json`；不能把原SwiftShader误差简单解释成原NVIDIA一致。

在独立测试保留原GPU bottom-to-top数据并取消采样V翻转后，48组全部数值相等、max0，见 `material-sampler-gpu-source-rows-verification.json`。这说明硬件线性过滤对翻行等价变换并非逐位不变，且保留原行序是比手动bilinear更贴近原NVIDIA的候选。该方向当前仅诊断，生产纹理、专用shader行序与mip尚未一并修改。命令为 `tools/run_native.sh --script tools/verify_material_sampler.gd -- --reference-gpu --source-rows`，旧Swift参考及旧生产对照仍保留。

## 原始行序生产接入

通用材质现在通过 `_texture(reference,true)` 读取每层原始bottom-to-top `.source-miprgba`，sourceFetchAlbedo/Orm/Normal直接按原UV采样。source_flip_y默认false；true只用于旧路径诊断。专用ground/sea/arms/FX维持已有各自采样契约。使用独立source_row_textures缓存，避免同一数据在不同shader契约间错误复用；当前真实128资产恰对应128GPU变体，无额外GPU副本。

`prepare_assets.py` 在离线阶段对原GPU每个mip层逐行翻转，分别保存查看/专用路径与通用原始行序，且各自SHA。禁止直接调用Image.flip_y处理完整mip：Godot实现会clear_mipmaps再generate_mipmaps，重新引入CPU颜色空间与过滤差异。

真实生产factory测试 `verify_material_sampler.gd -- --reference-gpu` 不再修改shader代码；48组原NVIDIA夹取/重复采样全相等，max0，`material-sampler-gpu-source-rows-verification.json`。该诊断为无mip Linear，仍不代替所有实际mip/aniso/梯度验收。旧prepared-rows分支通过 `--prepared-rows` 可复现历史差异。

`verify_texture_mips.gd` 覆盖实际原始行序generic与专用prepared行序，两类GPU数据共128个206418520字节完整哈希一致。360帧真实场景与原太阳迁移/阴影/贡献检查通过，日志 source-rows-regression.log、nvidia-mips-regression.log。完整画面仍需进一步对照。
