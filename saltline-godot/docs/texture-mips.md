# 原GPU mip链与sRGB修复

旧 `_texture()` 对编码PNG直接调用 `Image.generate_mipmaps()`。受控黑白sRGB棋盘经原Three glGenerateMipmap 后lod1/2采样 .5029296875，旧native路径仅 .2158203125；最大差 .287109375。`tools/verify_material_mip_cpu.gd` 保留旧路径诊断，预期失败，证据 `material-mip-cpu-failure.json`。不把旧失败测试误作新生产路径的验收。

生产改为保留原GPU生成的数据，不用近似gamma平均替代。`tools/material_mip_export.html` 用原Three r180、原GPU RGBA8 base读回、原colorSpace/wrap/min/mag重新上传并glGenerateMipmap；逐张检查base bytes完全不变，再以Framebuffer逐level读取编码RGBA8。按Godot Image逐level翻行后导出完整链。无mip过滤的纹理不额外生成mip。

132张原记录完整链共211748784字节，源数据与SHA256在 `assets/export/texture-mips/manifest.json`；实际采集backend为ANGLE Vulkan SwiftShader。`tools/prepare_assets.py` 校验SHA后准备 `.miprgba` 并在scene记录路径。runtime `_texture()` 直接 `Image.create_from_data`，避免PNG导入及CPU mip重新计算。原PNG仍保留作查看和旧数据fallback。

`tools/verify_texture_mips.gd` 从真实工厂加载的128张GPU纹理读回206418520字节，全部哈希一致：127张匹配原GPU准备链；天空噪声沿用既有原始bottom-to-top专用shader契约，单独与原raw SHA核对。最初按统一翻行预期比较天空导致一条失败，未改天空生产路径，只修正了验证对象契约。完整报告 `evidence/texture-mips-verification.json`。

完整场景source-sun-preview360帧退出0、太阳/阴影标记及贡献检查通过，日志 `source-mips-regression.log` 无SCRIPT/SHADER/ERROR/leak。证明数据上传和集成运行，不证明硬件双线性、trilinear、anisotropic采样与原后端逐像素一致。原128纹理中少数特殊shader还采用其既有独立采样规则；完整效果仍需验收。

原始 `.miprgba` 是运行时资源数据，后续导出打包必须显式包含；正式Godot导出包装仍属未完成工作。

补充范围：132条源记录中3条原type=HalfFloat（两张PMREM、旧planarReflection），早期RGBA8 base已损失HDR。mip数据哈希一致只说明保留了该旧RGBA8读回，不能恢复HDR。当前实际PMREM未接生产IBL；planarReflection已由独立实时HDR反射替代。PMREM补采与身份对照见pmrem-hdr.md。

## 原NVIDIA后端mip链与双行序

生产 `assets/export/texture-mips/manifest.json` 现为ANGLE NVIDIA RTX4070SUPER/OpenGLES3.2重导，逐张base bytes仍与历史RGBA8导出完全一致。与此前SwiftShader mip相比，129张有差异、4263528个通道改变，最大204字节（主要来自非二次幂标签）。具体比较见 `material-mips-backend-comparison.json`。不假定两后端glGenerateMipmap过滤完全相同。

旧SwiftShader完整manifest及改变过的旧二进制压缩保留 `evidence/material-mips-swiftshader-changed.zip`；未改变者与当前目录相同，不重复归档。生产按历史原版相同NVIDIA后端优先，而不是挑较易通过的Swift参考。

prepare同时产生top-to-bottom与原始bottom-to-top两种逐level数据，不在运行期调用会重生mip的Image.flip_y。实际generic用原行序，专用shader保留契约。NVIDIA数据接入后的128个GPU变体完整SHA读回全部通过；360帧source-sun-preview零失败，无错误/泄漏，日志nvidia-mips.log与nvidia-mips-regression.log。不能据此宣称完整三线性/各向异性或最终场景图像一致。
