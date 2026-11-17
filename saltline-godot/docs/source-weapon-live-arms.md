# 正常实时手臂接入

正常持枪、ADS、冲刺、射击、两枪换弹与切枪的手臂已接入实时目标/历史混合/IK/指骨和握持冲击弹簧，生产不再采样这70根手臂骨骼。死亡drop仍未实现，此阶段不代表完整原游戏验收完成。

最新实机视频 [native-live-arms.mp4](../evidence/native-live-arms.mp4) 为1280×720、60fps、10秒、无音轨，包含仓库内ADS/射击、换弹与切枪；固定MovieMaker帧率不证明实时性能。metadata/probe/生产脚本hash见live-arms-video.json。室外新截图为arms-runtime-110.png和350.png；已检查这两张及live-arms-video-ads.png。

## 实现

weapon_arm_pose.gd实现原Fh的20通道pose/trigger、限位、五指弹簧、15根主指骨与15根helper、手腕移动惯性。spring/velocity/shown保留原Float32存储，IK和quaternion数学使用double数组。helper使用原rest到当前旋转的半权重slerp，并按弯曲量偏移位置。dt<=0不推进弹簧，dt>.05按原截到.05。

weapon_arms.gd连接armTargets、vS和两侧Fh模型。D之后每个活跃tick更新一次；射击impulse为rifle右.55/左.35，pistol右.8/左.6；magin左1。取消换弹blend .22，切枪进入draw前blend .13。normal reset恢复private参与度并snap混合，保留原Fh弹簧/历史实例。原触发参与度和pistol拇指止动权重分别处理，不能用机械止动杆权重替代。

Animation在采样写入前跳过所有arm节点。live组保持相机局部identity，取消旧的整体枪根差值；70根骨骼通过source_scene.set_source_transform同时写入代理节点与Skeleton3D。纯clip隔离测试在未运行live arms时保留旧路径。

## 证据

完整原Fh构造/methods以及原指骨助手函数使用真实Three Bone层级，只有geometry/material/Skeleton.bind被mock。840步、240240项pose/shown/trigger及35骨本地p/q对照最大误差5.55e-16，容限1e-10。它不直接导出private spring/inertia，也不单独证明整个source初始化。独立IK边界测试另覆盖reach/lean/退化情况，见source-weapon-arm-ik.md；不要把这些极限归入Fh的840行用例。

GPU verify_weapon_arms_runtime.gd运行实际Main 470帧，每帧一次arms.step，32900代理骨骼与32900 Skeleton3D骨骼检查均通过，无采样覆盖，组identity。同期940弹匣、2820机械角色检查通过。它是实际写入接线检查，原coupled整链对照仍待补强。

780帧完整流程pause_frozen=true、最终playing，包含失败/retry/restart；日志无ERROR或泄漏。原装填事件119266、弹匣20544+取消128、目标48960、混合37800、IK48640项回归通过。结果与日志见evidence/weapon-arms-runtime.json/.log、weapon-live-arms-flow.json/.log、weapon-arm-pose-verification.json等。Astra审查见weapon-arms-live-review.md。

## 剩余范围

死亡武器与手臂drop、公开attach/view/snap生命周期、原初始化状态/全局RNG和整幅源画面对齐仍需继续。当前分层原函数证明和实际骨骼写入证明，不等于原完整coupled时序/整游戏图像已完全一致。
