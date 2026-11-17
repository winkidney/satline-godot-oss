# 启动后共享随机流

Main现持有一个source_bootstrap，任务使用其global root，武器和爆炸物使用各自child对象。reset/retry复用这些对象，不重新seed。关卡、雨、爆炸物资产的构造随机结果已导出，因此恢复其构造后的状态，不重复生成几何和朝向。雨流后续已接入自然雷电timer，见source-rain-startup.md；其Math.random闪光方向仍需继续。

## 冷启动账本

原normal title/qhigh/noaudio/default4207的root已fork4次，state3031300163。四子流的seed/state/calls如下。

| 子流 | seed | 构造后state | calls | 当前运行用途 |
| --- | ---: | ---: | ---: | --- |
| level | 589939774 | 759034465 | 183 | 资产已烘焙，保留状态 |
| rain | 1278876144 | 1866875301 | 40641 | 共享自然雷电timer |
| explosives | 1883172587 | 3586856006 | 15 | 连锁延时，15次为新增桶yaw |
| weapon | 3554171070 | 3554171070 | 0 | 射击/运动/掉落 |

source_bootstrap_reference.cjs读取已保存的浏览器观测，直接gate ready/fatal/errors、qhigh/noaudio/无shot/show、rootseed4207、boot/ready parent calls/state、四child及固定postbuild calls。原su重新执行全部构造draw并验证state，生成每流64个u32。观测文件本身SHA256记入source-bootstrap.json。

SourceRng增加calls计数，seed setter清零计数，算法不变。335检查精确验证5条流的seed/state/calls和64个原始uint32输出。初版十进制JSON float直接==因解析末位造成失败，保留source-bootstrap-initial-json-equality.json；最终比较原始u32，没有调整RNG或放宽位输出要求。

## 爆炸物与特效隔离

原yE中的s只用于构造桶yaw和explosion事件的连锁delay。原泄漏update调用fx.sparks/smoke，这些走Et/lt，也就是Math.random。旧Native错误地用爆炸物PCG生成烟偏移，导致泄漏污染后续连锁延时。现在爆炸物使用post15的SourceRng，漏烟调用已有FX公共方法；FX自身仍走其独立随机源，未假称Math.random序列已全局对齐。

explosive_stream_reference.cjs直接运行原chain callback和update(dt0)漏烟分支。180步、8180检查、40次leak，通过。Native实际FX sparks/smoke执行，确认其随机源有消费，而explosive state不动；链式RNG state/count精确一致，fuse/tick最大误差1.16451e-9，Vector3输入容限2e-6。请求顺序也与原sparks/smoke/light一致。没有比较FX粒子随机数值。

## 任务与实机

原完整pT参考新增canonical root4207、先4draw模式；Native默认Mission构造使用postbuild root。mission260帧+holdout1100帧共480866比较，通过，3波/7180分。历史1337参考显式注入，482543比较继续通过。game flow11030比较、RNG1152位样本与爆炸物21资产/三次blast/reset也通过。

GPU470帧检查实际Main stream对象身份，mission/root、weapon/child、explosives/child均共享预期对象，AI保留独立seed9001。70骨及机械/弹匣回归通过，末态root.calls115、explosives15、weapon37。780帧完整流程pause_frozen=true、最终playing，日志无ERROR/泄漏。详见source-bootstrap-runtime.json/.log、source-bootstrap-flow.json/.log和mission-canonical-verification.json。

## 剩余

这只确认固定默认导出世界的上述账本和接线，未覆盖任意seed/quality/showcase/异常boot分支。原FX使用Math.random，不能将它解释为root的某个fork；目前Native各FX随机源、共享draw顺序、完整AI/整场景随机时序还需继续。原rain构造最后一draw已包含在40641中，现已按最后构造draw恢复timer，未再次抽取。Astra审查见source-bootstrap-review.md。
