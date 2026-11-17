# 动态天空和云内闪电

## 来源与实现

原始入口 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。保存活动脚本 `../../artifact-rendering-study/source/extracted/bundle-1.js`：约35300–35485的tv/nv/qM/H9/O9/V9/XM/YM，36828的thunder监听，37141–37149的闪光更新。源SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

`tools/port_sky_shader.py`从导出原片段生成 `dynamic_sky.gdshader`，`source_scene.gd`在原sky立方体上绘制。保留原4通道256×256确定性噪声、3/5 octave FBM、风向时间偏移、云底脊纹、向阳密度梯度自遮蔽、云隙/太阳孔、火烧云边缘、太阳光环/圆盘、低于地平线雾色与地面反弹。原材质0c4ecf1e、节点0717faa7、噪声8f3efb14均复用。

顶点只用视图旋转，不随相机平移；POSITION用Godot反向Z的远深度0，扩大包围盒避免真实世界位置导致立方体误裁剪。可见天空在world层1，武器层2不绘制。原作初始化时YM捕获uEnv=1的环境（省略太阳盘、辐射夹6），当前继续保留原HDR lighting panorama用于IBL；动态云层与闪光没有每帧重烘环境，这与原作结构一致。最终亮度仍经过当前Godot过渡后处理。

`sky_weather.gd`迁移原方向/波形：thunder强度0回退0.6、最大1；原三次随机数决定西侧闪光方向与高度；前0.9秒按exp(-5t)、47/13频率乘积和0.35比例衰减。雨系统thunder连接到该模型。天空时间和闪光在暂停时继续，雨的世界时间仍暂停，遵循原renderer.frame与level.update分工。

## GPU颜色对照与精度修复

`tools/sky_reference.html`提取保存bundle中实际Three r180引擎，加载原导出RGBA噪声和原片段Shader；用原Shader在Float32 render target采样96组direction/time/uEnv/uFlash。Playwright collector为 `tools/sky_gpu_reference.cjs`。原始参考保存在 `assets/export/fixtures/sky-gpu-reference.json`，无需运行完整游戏或连接外部网络。

`tools/verify_sky_gpu.gd`用native片段及同一噪声，在use_hdr_2d=true、线性tone mapper的RGBA16F离屏目标读回，比较288通道。容差固定为max(0.004,参考辐射×0.002)。最终96组0失败，最大绝对误差0.003844，relative floor0.1最大约0.00095。证据 `sky-gpu-verification.json`。此探针隔离了片段方程，最终相机立方体/后处理另用完整实机验证。

第一次直接硬件LINEAR过滤时，2组/4通道失败，case65红色偏差约0.019695。改为原始RGBA数据直接采样、去掉PNG纵向翻转算术并未改变结果。Astra Ultra协助用NumPy复算确认：原Three参考运行于ANGLE SwiftShader，Godot为RTX4070SUPER Vulkan；噪声硬件过滤的插值路径差异可经FBM/relief三次方放大。现n2用四次texelFetch和显式双线性mix，实现原采样的数学插值，原参考与原验收容差保持不变。

原噪声在native天空路径直接上传导出RGBA字节，不经PNG翻转，避免额外坐标变换。四点采样的整数坐标按256循环。其余云层公式保持原式，仅改Godot接口与矩阵构造。剩余HDR误差属于渲染与读回链路残差，不能只归因于单次float16转换。

辅助诊断 `tools/sky_precision_reference.py`仅依赖NumPy（本次2.4.4），结果为 `evidence/sky-precision-analysis.json`，精确bilinear复算对原Three平均误差4.93e-7、最大约2.315e-5。它是原因调查，**不代替原Three GPU参考**。旧完整失败报告已覆盖，诊断仅保留实际读到的8个样本和4个失败通道，不伪装成完整旧报告。后端记录见 `sky-reference-backend.json`。

## 状态与实机验证

`sky-weather-verification.json`：原实际thunder回调和闪光表达式500帧3000比较，0失败，最大误差3.34e-8；覆盖随机方向、重触发、0回退、负数/超过1强度、0.9秒边界。

`sky-runtime.json`与 `native-dynamic-sky.mp4`：480帧/8秒/1280×720/60fps，无音轨。固定相机看向云层；第120帧受控触发便于观察，第300帧将真实雨系统计时置0、下一帧由实际thunder信号驱动天空，报告记录事件。`sky-060.png`常态，`sky-121.png`闪光早期，`sky-126.png`短暂波形，`sky-180.png`衰减后。完整场景验证远深度天空不遮挡吊机/集装箱。

仍缺原post thunder对体积光/雾/后处理的贡献、镜头污渍/眩光、完整室内曝光/环境适配，以及全局随机fork一致性。当前只完成动态天空与云内闪光，不宣称整个雷暴光照完成。4次texelFetch增加天空采样成本，需随后整体性能验收；未用静态图替代云层。

重建原GPU参考需仅本机HTTP服务根目录为工作区、端口8795，页面 `/saltline-godot/tools/sky_reference.html`；通过既有Playwright collector保存结果，再复制到fixture。nativeGPU命令：`rtk proxy env DISPLAY=:0 godot --path saltline-godot --audio-driver Dummy --display-driver x11 --script tools/verify_sky_gpu.gd`。
