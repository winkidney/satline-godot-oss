# 隔离 Godot 渲染兼容构建

> **当前构建（2026-11-16）**：基于官方 Godot 4.7.2 `ed1daf0bf`，应用 `0004-saltline-reduced-motion-portal.patch`，包含原28文件渲染补丁及6文件Linux偏好接线，共34文件；二进制 SHA256 `639baccce7c7c63638da889fba58b3797316b09be1df9da0bd49c839af1a5788`。`build-result.json` 是本机重建时生成且不入库的记录；当前事实以该记录、`source-manifest.json` 和[平台验证](../evidence/portal-motion-engine-provenance.json)为准。系统 Godot 未替换；下文旧 SHA、文件数及“当前”表述为历史记录。

Linux减少动画使用已有FreeDesktopPortalDesktop：一次标准Portal读取、原子缓存、既有SettingChanged监听，无新增线程、CLI依赖或每帧D-Bus查询。实际X11主机返回0；私有总线验证初值0/1/缺键、通知、未知uint和无效类型，18000次getter仍只读Portal一次；实际Main/GameUI跟随0/1通知通过。Wayland委托代码已包含，但本二进制仍`wayland=no`，未实机验证Wayland。旧引擎和metadata保存在`.build/godot-before-reduced-motion`、`raster-origin-build-result.json`及`source-manifest-before-reduced-motion.json`，历史运行包不改。

当前二进制为 `4.7.2.stable.saltline_oblique_source_bias`，80333928字节，SHA256 `1f621cd3a85ba413b3a385b2a19b828bc145bf2da9e86f9fc515908a1a639a2f`。原斜投影保留；引擎选项 `rendering/saltline/source_depth_24` 缺省false，本项目现已静态设为true，默认启用D24与48源贴花材质硬件偏移。该值只在启动前或完整重建buffers/材质/pipeline时决定。

当前补丁`patches/0001-saltline-render-fidelity.patch`覆盖11文件。从固定原archive直接应用后所有SHA均一致，见`evidence/source-bias-patch-verification.json`。旧仅斜投影manifest/build-result和补丁保留历史记录，当前重建入口读取manifest.patch_file。

D24选项保留R32 storage/resolve早返回，只将真实depth attachment优先设为D24S8；无支持时沿用既有fallback，实机必须核对实际格式。四私有Forward+模式是saltline_bias_world_2/3/4和saltline_bias_weapon_3，使用硬件raster bias，reverse-Z反号、weapon常量项×20；depth/color pipeline均保留偏移，且禁止shared shadow material吞掉状态。

当前50组Forward+常量/斜率探针通过，0/4xMSAA实际附件均D24S8，prepass/color一致，斜率从未偏移GPU深度梯度测量，2q24门槛不变、最大残差1.375q24。另32组透明遮挡/alpha/depthWrite=false与实际源贴花/刻字验证通过，48材质75网格全部映射。四相机完整场景格式读回128，D24太阳360/AO240/volume360/反射240及8case生命周期/重入通过；780帧游戏流程通过。太阳4096²全图D32/D24最大差1q24，无超出量化界的像素。原packed shadow、weapon独立range量化和跨驱动r仍保留边界，见 [实现记录](../docs/source-polygon-offset.md)。能力guard要求source_bias引擎、Forward+与D24所需usage，unsupported时不注入D24单位；这不等于跨GPU数值校准。

系统 Godot 不会被替换。官方源码固定提交 `ed1daf0bf001b61586d9930840f2f1394092c079`，tarball约71.9MB，SHA256与补丁/被改文件校验见 `source-manifest.json`。源码、对象文件与venv在被忽略的 `.build/`、`.venv/` 中；可审阅补丁在 `patches/`。

## 触发问题

原反射使用oblique near plane。水平相机时，原light culler假设有限8角视锥，三平面求交失败；其标准near/far提取也会得到inf/负数。已有非水平反射探针还发现native cascade丢失墙面阴影。原太阳改用固定源PCSS恢复了太阳项，但局部灯裁剪/cluster仍需要参考投影，不能只吞错误或改普通绘制投影。

## 补丁边界

仅当XR为mono、接口名为 `SaltlinePlanarProjectionProbe` 时启用。项目接口协议为标准透视只修改原oblique深度行；引擎保留exact XY/offset，以Camera3D原near/far恢复canonical reference深度行。它不是泛用XR任意投影支持。

实际几何frustum、实际/previous绘制投影、inverse projection与Compositor返回值保留oblique。light culler、directional shadow拟合、局部灯shadow coverage/更新、Forward+ cluster建表、CPU/GPU scalarnear/far、LOD与sort使用同一reference。CameraData和RenderSceneDataRD的getter在没有override时返回原投影，shadow/material/heightfield/UV2/SDFGI内部构造默认保持旧路径。

反射关闭CPU occlusion、SSAO/SSIL/SSR/TAA/native fog等未验证路径，不把这些功能宣称为已支持。CPU occlusion本身保留actual projection。原固定太阳PCSS仍是最终复刻目标，补丁的native cascade修复只作为兼容探针。

`version.status` 包含 `saltline_oblique` 供脚本识别；stock Godot不会误开这条路径。反射视口已默认启用，继续保留太阳链。source_bias与反射能力独立，现已在本项目生产配置启用。

## 重建

在workspace运行：`rtk proxy python3 saltline-godot/engine/build_engine.py --jobs 8`。脚本校验固定archive/patch及修改文件，使用本地venv固定SCons4.11.1/zstandard0.25.0，不安装系统包。依赖系统g++、pkg-config和X11开发基础；当前构建使用动态libstdc++、wayland=no、lto=none、debug_symbols=no、disable_path_overrides=no。源/补丁不一致时停止，不覆盖开发者改动。

输出为 `.build/godot-ed1daf0bf/bin/godot.linuxbsd.template_debug.x86_64`，当前已构建为可运行项目的debug template，不是editor。D24/bias的本轮完整场景gate已过，总工程仍不是完成品。

模板默认禁止加载裸项目/CWD，必须显式disable_path_overrides=no。首次缺少该选项曾触发加载拒绝，当前重建选项已固定并验证。

## 本轮已完成的构建与 GPU 验证

上个仅斜投影构建修正加载选项后已可运行，大小80329832字节，SHA256现保存在 `oblique-only-build-result.json`。下文为该阶段证据。模板默认路径限制已解决。

水平mono探针：下方红marker111像素裁至0，上方green137/blue96不变，主非XR图bytes一致；HDR4保留、8个mip和末级非零。点光/spot/sun/4split-shadow两种投影均逐像素一致，有482像素实际native阴影贡献。原固定PCSS在同一水平视角产生822阴影暗化像素，两投影逐像素一致。此前俯仰视角的434像素native cascade失败，在新构建中两图最大差0，仍有434像素阴影，旧stock失败报告单独保留。

完整原场景120帧水平初始相机无light-culler错误。冻结院子关闭/开启反射，15683个抽样HDR像素变化，四个对象排除与main/reflection/weapon掩码通过，回调顺序为reflection→sun→world→weapon。4秒视频 `evidence/native-planar-reflection.mp4`。此证据不覆盖动态shadow-age、resize/重入、所有投影和整机性能。

当前使用该构建启动时默认开启反射：workspace执行 `rtk proxy saltline-godot/tools/run_native.sh -- --game`。stock Godot继续可运行已有太阳/后处理，但不误开需要此补丁的反射。新启动脚本无音频输出，不安装/替换系统可执行文件。

后续完整场景生命周期验证已通过非整齐/最小逻辑缩放、高度/显式停用恢复、XR和layer还原、重建顺序。反射现用显式child-of-sun依赖；非周期单caster128图的真实GPU采样证明反射读旧图、主图读更新图，8帧误差0。对应证据见docs/planar-reflection.md，不扩大到全部角色动态PCSS或性能验收。


## Private fixed4 texture sampler

The current manifest uses `patches/0002-saltline-render-fixed4.patch`, preserving all earlier mono-reference projection and source-depth/bias work. The combined patch modifies16 files and replays cleanly against the pinned archive (see `fixed4-patch-verification.json`). Previous manifest is retained as `source-manifest-before-fixed4.json`.

Spatial Forward+ shaders may use `filter_linear_mipmap_anisotropic_4` with `repeat_disable` or `repeat_enable`. It binds existing MaterialStorage default4x/bias0 samplers at Forward+ render-pass bindings37/38, independently of viewport8x. Existing filter enum values/default6 and legacy sampler bindingbank stay unchanged. Regular and SDFGI uniform-set construction both contain the bindings. Other backends explicitly reject the hint before their filter indexing paths. No ShaderRD/globalCanvas filter extension or sampler resource lifetime change.

This private hint is fixed4x,LOD bias0,using current project linear mip interpolation. It does not promise viewport mip-bias inheritance or cross-API pixel identity. GPU fixed4 clamp/repeat invariance and ordinary4 equality are checked by `tools/verify_fixed4_sampler.gd`; ordinary8 is a non-equality control. The shader's unsupported GLES compile diagnostic is separately verified. Main showcase360frames and31decalnormal checks pass, but SDFGI-specific runtime rendering and independent reflection/decal image parity remain separate acceptance work.

Current binary SHA256: `9babcf87a5bae54b005c9000ca1c5dfe6827e74f831b333eece269e96421b64a` (80,333,928bytes). PatchSHA256 `cb86dd61338593418e7dcce1947e4ed01c9e84bb43069c1e9ebc71dce66e2fa1`. `build-result.json` is authoritative. `refresh_patch.py` regenerates combined patch/checksums from the current manifest-listed sourcefiles against the pinned archive; run it only after intentional engine edits, then rebuild.

## Per-viewport source raster origin (integration pending)

Current manifest is `patches/0003-saltline-source-raster-origin.patch` (26 files); pristine archive replay passes. The current binary is 80,338,024 bytes, SHA256 `fc54e30a76f0598f45d55d5f215156a97cdbb8afe9c9b8506e2fbe60ee143ade`. Historical sections above describe earlier binaries; `build-result.json` remains authoritative.

Private `RenderingServer.viewport_set_source_raster_y_up(viewport, enable)` must be called before that viewport creates 3D render buffers; default false. It changes depth correction and pipeline front-face together, retains instance cull behavior, and includes origin in the pipeline cache. Resize retains the flag. Native post effects and full-game coordinate normalization are not validated or enabled by this interface. GPU shared-material opposite-origin/cull/odd-resize checks and face614 CPU-NDC coverage replay pass; see implementation-status. Old fixed4 binary and r6 package are retained. Build now explicitly imports CCACHE_DIR into SCons instead of touching home cache.

The raster-origin integration now adds spatial builtin `SOURCE_RASTER_Y_UP` from the per-scene flag. Enabling origin is restricted to Forward+; other backends retain false. Current patch has28files, SHA `819fa712cdd09f78b4fad085864a64d5aef7ef0b7e30e76dc24cdbca57b7ae5c`; binary SHA `bb476c9fd4cbf588904f38de2633b58cf962c3e30225dca8f009bf414bf1e70e`. World/weapon/planar use the flag and normalize their outputs once at existing bridges. The earlier integration-pending paragraph is historical. GPU12material/cache checks,165depth cases, horizontal oblique/HDR/mips and full-scene8case lifecycle/reentry pass within their documented scope. Full-game visual fidelity remains incomplete.
