# 地面查询与移动特效

GroundQueries读取原ground材质uMask对应的1024×1024线性RGBA字节，复用当前高质量资产，不重新发明水洼分布。原Dw生成1024遮罩与导出文件逐字节相同，SHA256 c7133b56e75d0120cf92b88dd55ca5f4e07a71965ea5c3d96e0255112ba65cd6。

Bg采样保留世界矩形x0=-44/z0=-40/size80、半texel偏移、e-1.001上界和四通道双线性插值。puddleDepth保留quayX30、严格矩形和室内XZ边界的-.2返回；isPuddle使用depth>.015；wetnessAt保留海侧1、室内.12、域外.6及原smoothstep混合。CPU直接按原Dw数组顺序读取，不作图像Y翻转。

## 数值证据

ground_query_reference.cjs直接提取原Ug/zw/ps/SP/Dw/Bg及Vg b/g和查询方法。12879点90154项检查通过，max1.11022302462516e-16，tol1e-10，含mask hash、四通道、积水和湿润度，覆盖域边界、quay、室内边界。方法SHA256 6a05e89b6962bc9f5b23dabec1331319fe13aafe8e2d6091dc852360948766b7。采样不含depth严格等于.015的定向用例，不能将代码严格比较与一般网格通过扩展成该等号的数值测试。

## 实际接入

Main创建一个查询服务，player.surface_resolver在pos.y<.05时优先返回water，之后保留非concrete物理contact_surface，最后调用已接入的55个金属区域查询。默认种子4207的原H规则与闭区间区域对照见source-ground-metal.md。

ImpactEffects对向上normal.y>.7、原材质非enemy/water的命中调用水洼查询，且point.y<.08时按water生成溅水。它返回实际材质，Main._impact_visuals用该结果生成后续弹痕，避免水洼仍留下concrete弹痕。未改原hit数据，原命中数据仍供其他接收者使用。旧完整A353470项回归通过。

玩家motion_event信号接入FX。step使用payload.pos或player.pos；land使用当前player.pos。水面位置Y钳至至少0；步行/冲刺大小.4/.55，水中着陆.9；硬地speed>5生成六团烟尘。step/land回调直接查XZ积水，没有player事件surface查询的y<.05门槛，因此屋顶正下方有水洼时仍可能splash，当前保留原作行为。

ground_motion_reference.cjs提取原player:step/land回调和go/M/S/k/u1，用已验证的原地面查询，容量2/256各15操作，12750检查/1818draws通过，max2.384185791e-7、tol2e-6。覆盖walk/sprint、水优先、payload/fallback位置、land speed5严格边界、Y钳制、屋顶行为和饱和/clear。方法SHA256 7104cfd14f62ea8a427f37af702ee0e3f7c9ad9c308e9d236ea8a417abcd102b。只证明事件生成的粒子字段与消费，不是原作整段移动回放。

## 实机证据与边界

verify_ground_runtime.gd运行实际Main/player physics240帧，13检查通过。导航可走水洼[-34,0,-3.75]；37帧实际water sprint step生成10add/7lit，118帧水中落地15add/7lit，183帧硬地落地0add/6lit。另检查积水y0命中抑制decal、y.1仍产生decal。已查看040/190截图确认实际渲染，未作原作同帧像素比较。

首次实机选择的水洼路线只覆盖约1米，玩家第一次stride事件前已走到干地，缺少wet step；保留ground-runtime-initial-short-route.json/.log。随后改为检查完整2.5米路径，未修改生产逻辑或预期数量。最终ground-runtime.json/.log失败0。

780帧完整流程pause_frozen=true、最终playing、reset无残留，见ground-flow.json/.log。当前仅高质量1024遮罩；其他质量模式的512遮罩、其他种子金属区域、实际遮蔽查询、完整decal联合随机消费与整图对齐仍待继续。原bundle SHA256 756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8。
