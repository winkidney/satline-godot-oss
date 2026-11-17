# 原实时武器根运动与后坐力核

`weapon_root_motion.gd` 实现原D和两枪recoil。D现已默认接管生产枪根，与Weapon及reload/controls共享S；双臂仍是采样加组差值过渡。最新生产证据、截图和视频见source-weapon-live-root.md。

## 来源和接口

原始本地源码为 `artifact-rendering-study/source/extracted/bundle-1.js`，SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。D 位于79801–80128，其字面片段SHA256 `dd28a8747963c75e7086a1f37855f9bdd495f8928054e12cdc08dc82ea25a023`；rifle recoil 位于77017–77039，pistol recoil 位于78679–78696，合并片段SHA256 `4437779e70f04044ec9a483eaede0a2581a60734fec477418a1849de78cbdd94`。

构造器接收显式initial S和随机Callable，内部深复制状态。生产应只创建一份两枪共享的S。`step(dt,rig,player,input,inspect,raycast)` 返回相机局部绝对Transform3D，内部只按原D把dt上限设为.1；a.t须由外部O阶段按原始dt推进。没有额外时间积分、子步或根节点写入。

`recoil(gun,rig,burst,camera_scale,crouching,add_recoil,add_shake)` 将原冲量注入同一份S；可选回调分别接收相机pitch/yaw和shake。相机回调缺失时，保留原表达式的随机消费差别。camera_scale按原方法只进入相机反馈，不能擅自乘到枪身冲量。实际接入后需替换现有Main相机后坐力分支，防止重复调用。

## 已迁移计算

ADS双弹簧、退出补偿、独立sprint/reload/rack弹簧；贴墙查询和非线性holster；呼吸/漂移/CPU noise；步幅弹簧、gait/gOff重同步与步态波；世界速度转局部后的惯性高通；原look归一化输入的sway速度冲量、硬限位和tanh；jump/land边沿、落地随机侧倾、双蹲伏弹簧、空中下坠目标；六路recoil、bump、anticipation；最终YXZ base/detail四元数组合与pivot补偿。

保留原.999 critical弹簧分支、指定弹簧P snap、Math.round负半整数向正方向取整、单次gait/breath回绕、旧exert读取顺序、落地即便零幅度也消费随机数。标量历史保持CPU double；最后构造Godot float32 Vector3/Basis/Quaternion。

原raycast接口无命中为null。生产适配SourcePhysics时须把其空Dictionary结果显式转null，并使用dist字段；本模块不应直接绑定未适配的SourcePhysics方法。原JS对raycast异常有try/catch，GDScript没有等价异常捕获，生产适配器必须保证接口有效。player缺失或null的vel/tuning/look走原fallback，onGround只有布尔false代表空中。

## 独立轨迹证据

生成器 `tools/weapon_root_motion_reference.cjs` 直接提取原D、两枪recoil、pn/en/Xn/AE/sa/ry、Hn/u0/Is/j0/_1/Ot和常量，并在原bundle自带Three向量/欧拉角/四元数上执行。expected不是从native实现反向生成。初始S明确来自导出的debug.S快照，a.t=.050000001、breath已推进；对每把枪显式配置其原spring参数，不冒充原reset/equip操作。

两枪各600步，共1200步。dt含0、1/240、1/60、.033、.05、.2，验证D的.1 cap与外部原始时钟不同。覆盖idle/noIdle、ADS进出、sprint/urgent、显式reload/rack/anticipation/inspect、world velocity/yaw、crouch、jump/land、墙距离和无ray/无eye/无forward、null vel/tuning/look，以及breath/gait回绕。48次原recoil触发涵盖burst1/2/3/4/9/10、ADS、crouch和有/无相机回调，仍保留独立人工spring冲量测试。

第300步定向dt0、gait=-.5、gOff=0、stepEv=1、speed0，expected gOffT=+.5，由生成器断言。第311步定向dt0、swY.x=1/v2、swP.x=-1/v-2，expected限位到正负max*2.5且v0，亦由生成器断言。输入patch深复制，避免S更新反向篡改fixture输入。

验证器 `tools/verify_weapon_root_motion.gd` 比较每步全部S、相机反馈、最终16通道矩阵；拒绝NaN/Inf。随机数和墙查询同时比较模块计数与独立Callable实调计数，并验证eye/forward/far参数。当前186072个标量比较，max误差1.13243e-14，最终矩阵max误差3.73752e-7。门槛分别1e-8与2e-6，未为本轮结果放宽。详见 `evidence/weapon-root-motion-verification.json`。

复现：

```sh
rtk proxy node saltline-godot/tools/weapon_root_motion_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --log-file /tmp/saltline-root-motion.log --script tools/verify_weapon_root_motion.gd
```

## 剩余接入

原reload、controls、player事件、recoil/Q内流和D根接管均已进入生产，见source-weapon-live-root.md。仍需原实时IK、parts/armTargets、死亡掉枪、公开equip/snap完整副作用、全局初始化fork、完整S与标题时间线、全场景图像/性能/导出验收。本文件早期独立数值轨迹只证明其原范围，后续生产证据另列。

Astra审查见 `weapon-root-motion-review.md`，整体接入约束见 `weapon-motion-adviser.md`。
