# 金属区域与完整玩家地表分类

当前默认种子4207、高质量场景的55个metalRects已从原版实机取得并接入GroundQueries。ground_surface_at保留原uw.k的闭区间比较和原矩形顺序；resolve_player_surface按原玩家H先检查低处积水，然后保留非concrete接触材质，最后调用关卡金属区域查询。区域查询只看XZ，不自行增加高度或碰撞限制。

## 原版实录与来源绑定

instrument_ground_surface.py从未改动的本地bundle生成观察副本，仅在uw返回对象时将原i数组和k函数引用挂到window。原HTML与bundle文件未覆盖，没有替换区域生成、随机数或查询算法。Playwright专用salt-ground会话以q=high/shot=1/noaudio=1/step=1/dt=.016666667冷启，ready=true、fatal=null、errors=[]、frame3。参数未指定seed，原boot85808的su(+(n.seed||4207))因此使用4207。玩家起点[-32,0,6]及yaw与当前资产一致；起点匹配只是额外校验，不用它代替seed检查。

收集原数组、原isMetal和原level.groundSurfaceAt的12978个结果，含网格、各矩形端点/中心及±1e-7边缘点。实际浏览器后端ANGLE/NVIDIA RTX4070 SUPER；唯一console error是favicon404。实际取得的instrumented.js响应SHA与本地生成manifest一致。采集完成已关闭本轮专用浏览器，其他会话未改动。

文件来源如下。

- 原bundle SHA256：756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8。
- 原HTML SHA256：b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb。
- 观察脚本实际响应SHA256：5ec83ad2c8dbb5599b6175649a649155cd7bf66d17c7b46e4ecf32546917e5a3。
- ground-metal-observed.json SHA256：2c9e281a598556eb7a412dfd0991682cc31523ad2d53409100e4d44468765141。

观察脚本、HTML、manifest和CLI原始结果在artifact-rendering-study/output/playwright/ground-*；最终fixture在assets/export/fixtures/ground-metal-observed.json，生产区域在assets/export/ground-metal-rects.json。

collect_ground_surface.cjs供Playwright run-code --filename使用，decode_ground_surface.py解码保存结果。解码器在写资产前校验当前bundle、原HTML与观察脚本文件哈希，固定启动参数/质量/帧，并按原seed默认及uint32规则比对scene.seed，拒绝不同种子的重采结果。一次重新解码产物SHA不变。

## 双精度边界与验证

原JS数字经JSON与Python标准双精度解析后编码为little-endian float64 hex，矩形边界和probe坐标均提供该编码。Native直接decode_double恢复，不依赖Godot JSON十进制解析来决定严格边界。GroundQueries加载元数据时验证与当前source.seed一致。

verify_ground_metal.gd的12978点、25957项比较通过，含2889个metal结果，逐项比较原live isMetal和groundSurfaceAt输出及55区域数量。此项调用double坐标API，不能扩大为Native玩家运动已使用double位置。

player_surface_reference.cjs另外直接提取原uw.k、level.groundSurfaceAt与玩家H，用已验证原积水查询执行55区域中心加干/湿点，4高度×5接触材质，共1140例。先将输入位置quantize到Native Vector3，再给原函数，Native使用真实Player.event_surface与绑定resolver，1140检查通过。方法SHA256 adde250ada8e3795f26be808bbea4809f287d36f9683c1efaea490c60bfb7812。输入域限制是明确的，不能据此声称原JS整段运动的double轨迹已一致。

## 实机接入与剩余边界

verify_ground_metal_runtime.gd加载实际Main，对55区域中心height2检查concrete fallback→metal和显式wood优先，共110检查通过。随后实际运行原240帧湿地脚步/水中落地/硬地落地与积水decal抑制回归，13检查通过。结果ground-metal-runtime.json/.log、ground-runtime.json；没有把静态区域探针称为金属表面的完整行走轨迹。

原90154项mask/查询回归继续通过。此轮没有变更reset/clear逻辑，也未重复780流程；上一轮780为积水接入时证据。新分类主要改变事件surface，音频按目标省略，不新增金属脚步音效。

当前区域仅绑定默认种子4207和当前烘焙关卡。其他种子、512质量mask、重建关卡区域、完整movement/FX/decal随机时序与受控像素仍需验证。Astra复核见ground-metal-review.md。
