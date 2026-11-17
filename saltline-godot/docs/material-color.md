# 原染色、湿润与顶点色顺序

原 `bundle-1.js` Standard片元（约24884行）按 map_fragment→color_fragment→alpha-test 执行；mk替换map_fragment后，染色和湿润色彩均在顶点色之前。此前Godot将顶点色先乘base，再进入tint=1/2，导致采样贴图分量遗漏顶点色调制；现已修正。

生产 `shaders/source_material_color.gdshaderinc` 负责原tint=0/1/2/3 RGB。四个通用shader按纹理准备→tint→湿润修饰→距离裁剪减亮→顶点/实例色→alpha-test执行。SL_ACUT先覆盖alpha，顶点alpha随后相乘；普通原材质补丁tint3才乘采样alpha，未打补丁普通材质仍沿用标准map alpha。BackSide的非扰动法线先反向，三平面重建仍保留其原独立逻辑。

独立参考 `assets/export/fixtures/source-material-color-original.glsl` 直接取原mk染色、湿润色彩和原Three z8 color_fragment。`tools/material_color_reference.html` 与 `tools/verify_material_color.gd` 覆盖48组tint、RGBA贴图、湿度和顶点RGBA，768通道，绝对门槛.001，零失败，max .00048828125。见 `evidence/material-color-verification.json`。此测试验证代数和顺序，不覆盖实际纹理过滤、顶点插值或完整光照。

参考采集新增 onShaderError 立即失败检查。早期提取片段缺首尾换行，导致预处理错误和黑色参考，该无效fixture保留为 `evidence/material-color-reference-invalid.json`，不作通过证据。诊断shader重复uniform声明亦已修复；最终参考和native均重新运行通过。

实际 source-sun-preview360帧正常退出，太阳开关检查零失败；`evidence/material-color-regression.log` 无SCRIPT/SHADER/ERROR/leak。完整湿材质噪声和最终画面仍待验收。
