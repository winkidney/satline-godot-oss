# 弹痕几何、联合消费与FP32法线

已对齐原Jg.add/clear的生成语义，并把它和完整命中A接入同一条受控Math.random序列。弹痕法线另增加FP32传输，绕过Godot内建ARRAY_NORMAL的oct16量化；只对fx_decals启用，未修改引擎。

## 生成语义修正

原未知kind只回退到concrete UV，其默认尺寸仍是.25，旧Native把kind改成bullet_concrete后用了.34。原size非零即采用，包含负值，旧实现仅接受正size。现保留原kind、按原查UV/默认size，允许负size。

切线、法线归一化、旋转和四顶点使用double标量计算，最终写Vector3/Float32数组时才舍入。base_alpha先按原baseA转换Float32，14个旧槽位淡出再写Float32。160槽覆盖、每槽沿法线的.004+(index%7)*.0003偏移与原UV边距保持不变。

Main._impact_visuals在调用Decals前补与原A相同的零/微小normal回退UP，否则即使粒子方向正确，原hit.normal仍可能让弹痕退化。此处是A路由的回退；直接Jg.add式Decals.add仍保留原零normal和退化quad，不额外把零normal修成UP。

## 原函数与联合序列证据

decal_reference_core.cjs直接提取原Jg.add/clear、ZP和Yw UV函数，构造原Float32缓冲，不运行canvas贴图生成。原atlas为4×2、tile256、边距2/256。原bundle SHA256 756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8；提取方法SHA256 1ef81e2082911bc12584c1c8238bf9e0f392f650036b03df9b8a4f7cccf908b5。

独立175次发射跨160槽，随后clear及两次重发，共178步/531draws。覆盖7kind含unknown、负/默认尺寸、5normal含zero/tiny、透明度与旧槽淡出。212138检查通过，position/UV/custom3颜色/CPU normal/custom2 raw normal的最大比较误差3.552714e-15，tol1e-6。另明确检查Godot使用的反向三角形索引转换，没有声称索引与Three原缓冲字节相同。

impact_decal_reference.cjs将原A及helpers、原jg.add和真实原Jg.add接到一条tape。64组8材质/远近/容量2和80/受控shade1和.2/6时点，Native执行实际Main._impact_visuals方法、真实粒子/碎片/弹痕及light请求。399796检查、57560draws通过，最大误差1.907349e-6；粒子/碎片tol3e-6，弹痕tol1e-6。包括metal/enemy共享节流、严格.09、zero/tiny fallback和弹痕的图块/尺寸/旋转消费。此范围不含puddle、实际遮蔽查询、粒子运动或全游戏事件交错。

## FP32 normal生产路径

隔离引擎rendering_server.cpp613–629表明，即使未启用COMPRESS_ATTRIBUTES，ARRAY_NORMAL也会oct encode并截断为两uint16；1511附近读回decode。测得非零normal与源Float32相差最多4.202127e-5。对明确codec的读回比较误差0，这只能解释运输量化，不能当源normal等价。零normal的oct编码不定义有用单位法线，退化quad的该字段不作codec断言；CPU与CUSTOM2仍逐项比较。

按Astra建议，Decals._rebuild将原normal写入CUSTOM2 RGBA_FLOAT，CUSTOM3继续存原颜色。两套Standard shader新增默认false的source_exact_normal，仅fx_decals绑定true；vertex第一步恢复NORMAL=CUSTOM2.xyz，先于local/world normal和source sun offset计算。现有武器raw-normal条件仍保留，其他材质不启用该开关。

verify_decal_normal_runtime.gd加载实际SourceScene并确认只有一个生产材质启用。Standard/alpha两套生产vertex保留，fragment替换为放大16384倍的local/world/sun-offset误差诊断；三个非零normal，HDR16×16正交探针，保留生产polygon bias。31检查通过，enabled local/world误差为0；shadow offset放大误差最大.0003967285，对应未放大约2.42e-8。关闭exact-normal路径的六个control分别稳定显示.25/.65234375/.68798828，证明探针实际执行并区分两条路径。六次白色几何校准也通过。

这验证实际CUSTOM2缓冲被生产vertex使用，不是完整原Standard fragment、normal-map、IBL或同帧像素比较。原ARRAY_NORMAL运输诊断仍保留，不能据raw通道恢复推导所有后续渲染误差为0。

## 失败记录和实机回归

初始decal-random-initial-failure.json保留尺寸/精度/normal差异；decal-random-normal-codec-difference.json保留标量修正后仅剩的normal运输差异。GPU诊断曾因环境属性名、uniform声明位置和unshaded输出通道出错。关闭路径的control阻止了空黑图被当通过，initial-shader-failure及initial-black JSON已保存。Astra从引擎源码确认unshaded只输出ALBEDO，诊断由EMISSION改为ALBEDO后通过。失败probe按可执行文件/脚本/log精确匹配清理，未操作其他实例。

实际--weapon-preview --near-impact-preview --effects-lifecycle运行420帧，14shots/impacts/shells/tracers、28debris，末add/lit/debris为0。已查看weapon-120/235，能看到实际墙面弹痕。日志clean，结果decal-joint-runtime.json/.log。旧decal170发射容量/平面/UV/淡出回归和Q122484检查继续通过。本轮未改变reset逻辑，未重复780流程。

后续仍需完整游戏随机事件交错、其他方向和动态渲染像素、其他GPU/导出包及所有未完成系统验收。Astra审查见decal-joint-review.md。
