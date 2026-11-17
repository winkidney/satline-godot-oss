# 雨随机流与自然雷电时序

雨系统已接入Main共享rain子流，默认从构造后calls40641继续。初始倒计时使用构造最后一次抽样恢复，不再额外randf。正常游戏rain.time和全局animation_time均从0开始；重试不重建rain，不重置倒计时或随机流。

## 初始化

原Gw用4次draw生成每个rain/splash aSeed：4×[(9000+260)+900]=40640。最后一次draw用于E=22+t()*25，累计40641。此时seed1278876144、state1866875301，初始E=31.229654591763392。assets/export/source-bootstrap.json记录last_construction_sample与rain.initial_state，SourceRain读取这个状态，构造不再抽数。下一次事件各抽两次，先新间隔30+t()*30，再强度.3+.7*t()。

旧1337参考仍用显式预抽一次的rng与initial_state，不影响生产canonical路径。初始shader uTime/uRain也同步为所选状态。正常Main原先继承导出global .050000001，现按原cL.time从0开始；非game隔离snapshot仍使用当前导出年龄.050000001，同步rain.time并从初始timer扣除该年龄，不额外抽样。这仅恢复当前未过首次雷电的已知快照，不是任意时间存档恢复。

暂停时原循环global time继续，ground/rain停止，因此“global与rain相等”只针对不暂停的路径，不把暂停期间二者相等当不变量。render天空闪光衰减继续推进。

## 原函数与实机证据

rain_reference.cjs执行完整原Gw.update闭包。历史1337为1000帧/98000比较/2000精确RNG检查，1事件；canonical默认为3000帧/294000比较/6000精确RNG检查，4事件。scalar容限1e-10，max2.84e-14；Vector3/4沿用1e-5，max4.20e-7。检查雨强/目标、time/timer、可见性、像素宽度、interior/skylight/eave以及雷电强度与RNG state/count。参考和Native强度已加finite guard，均通过。

verify_rain_thunder_runtime.gd运行实际Main ambient路径1450帧，固定dt .05，模拟72.5秒。自然事件在625和1431帧，强度.783887012978084和.609752463223413，最终calls40645。global/rain时钟与原timer匹配，10150检查失败0，sky value非零34帧。没有强制timer=0。Gameplay保持在启动状态，不能将此当整游戏时序或性能证明。

已查看rain-thunder-0625.png，捕获实际雷电帧渲染。事件到SkyWeather及PostPipeline.volume_thunder的代码路径保留，实机检查sky值；没有把此项扩大成所有后处理像素的原图对照。780完整流程pause_frozen=true、最终playing，日志无ERROR/泄漏。结果rain-canonical-verification.json、rain-thunder-runtime.json/.log、rain-startup-flow.json/.log。SkyWeather原受控随机方向/闪光表达式500帧回归通过。

原Gw.update SHA256 7238574fc745406116523c03559b42bb5bc90487ea5b78eec292b325a7b5f747。修改finite guard后重新跑了CPU两模式，并直接核对相同归档GPU两事件finite/数值，未为纯guard重复跑长GPU。Astra审查见rain-startup-review.md。

## 剩余

雷电方向的原Math.random三次抽样与其他FX共享次序仍未对齐。相同自然timer/强度不等于相同闪光方向、完整O/render循环或原全图像素等价。其他Math.random FX、全部质量/DRS与整游戏验收仍需继续。
