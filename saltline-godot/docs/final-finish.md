# 原nk最终显示层

依据原活动脚本35998–36034及`35998-nk.glsl.template`。原tk先输出编码后的sRGB RGB及亮度alpha到RGBA8 LDR target，nk再用alpha判断对角邻点的luma contrast，执行FXAA、弱边缘锐化、随亮度调整的动态颗粒以及1/255天空渐变抖动，最后alpha=1输出。HUD在之后绘制，不经过该层。

`scripts/post_pipeline.gd`新增全分辨率LDR中间视口，`source_composite_data.gdshader`保留原tk亮度alpha；原`material`对象仍供GameUI写入伤害/淡出等uniform。`final_material`执行`source_finish.gdshader`，显示TextureRect绑定它。默认uFxaa=1、uSharpen=.3、uGrain=.02，uDither=1；uDither只是离线诊断开关，默认保留原无条件抖动，未添加产品设置。uTime沿用原post全局时间。

原gl_FragCoord是左下原点；native以FRAGCOORD.x与height-FRAGCOORD.y转换一次。源采样vUv与纹理翻转维持既有约定。中间viewport透明以保留数据alpha，但blend_disabled写入的RGB是原tk编码值，最终shader直接读取RGBA数据，不用普通透明混合。

## 验证

`tools/finish_reference.html`直接运行原Three r180和原nk，以64×32 RGBA8图测试斜边、彩色高频点和渐变。八组包含独立FXAA、独立锐化、二者组合与不同时间的原颗粒/抖动。为了辨认确定性滤波误差，0..3组明确关闭grain，并仅在诊断参考中移除dither那一行；4..7组保留选定原随机项。不是把修改后的测试称为全原图。

`tools/verify_finish_gpu.gd`对照实际native RGBA8 GPU输出。确定性四组最大差1个色阶以内，阈值1.01字节，全部通过。带随机项组最大差5个色阶，平均绝对差.03581到.07130字节。记录所有像素误差、P95、噪声均值/RMS和原/native最大振幅；原grain/dither振幅解析上界含量化检查通过。典型完整噪声RMS native1.657/reference1.648字节。跨GPU浮点hash的少量随机像素不同，不声称逐比特相等，也不以噪声幅度检查代替确定性滤波对照。详见`evidence/finish-gpu-verification.json`。

`verify_post_pipeline.gd`另验证真实HDR world/weapon到tk RGBA8再到nk的identity诊断：中间alpha与RGB亮度误差<.004，最终显示RGB不变且alpha=1，12帧同帧HDR链仍通过。该identity探针关闭nk滤波/噪声，仅证明中间alpha与显示不透明语义；非均匀滤波由上一项独立覆盖。

`evidence/native-final-finish.mp4`为12秒1280×720/60fps无音轨，实际默认游戏链、伤害/低血量、完整ADS和重试。`finish-080/120/354/700.png`为对应截图。检查HUD数字/文字保持独立SDR覆盖；世界颗粒和细边平滑已生效。`finish-runtime.json`和finish-*.log保留运行证据，未报脚本、shader或GPU错误/泄漏。

仍缺原体积光/雾/AO、运动模糊、部分材质与照明能量/反射校准、MSAA边缘、质量档位等，不因最终显示层接入而称完整原后处理完成。
