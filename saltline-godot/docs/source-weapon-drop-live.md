# 死亡掉落实机接入

正常死亡时武器现已脱离相机进入世界层，按原数值轨迹碰撞、反弹和落稳；双臂放松下落并隐藏。retry先恢复武器父节点、layers、cast_shadow和shader，再执行原session reset。落水数值和splash回调已接线，但本轮实机只验证地面路径。

## 接线和材质

Main读取entry alive，若该帧进入时已死，则在Weapon.update前调用drop_view.advance，正常D不运行；若在射击回调中才致死，entry alive仍为true，允许当帧D完成，下帧开始drop。Animation在drop期间跳过枪根和枪子节点采样，不把世界武器重新显示在weapon层。drop flash在effects更新后强制隐藏。

weapon_drop_view保存原父节点及每个mesh的layers/cast_shadow。掉落mesh进入layer1，flash以外开启投影。太阳shadow pass按动态节点登记世界投影对象，source IBL/local/sun服务继续按层和shader path工作。

当前weapon_markings是唯一weapon硬件bias材质，仅供两把枪，未供手臂或世界资产使用。因此在仅一把活动武器掉落期间，临时替换这个ShaderMaterial的shader由weapon3/60 variant变为world3/3是安全的；材质对象和uniform参数保持，湿度/光照服务继续更新。restore还原原shader对象和偏移meta，不替换整份材质。这个共享范围若未来改变需重新审核。

## 验证

`tools/verify_weapon_drop_runtime.gd`实际Main运行400帧，步枪与手枪各一次死亡和retry。首轮在frame20真实weapon.fired回调中施加致死伤害，确认该tick恰一次D且下一帧才开始drop；第二轮tick前致死。281为逐帧门控次数，包含动作状态、世界父节点/层、非空bias迁移、投影flag、太阳投影对象登记、render-only不推进、落稳和手臂隐藏。retry另检查父节点、原shader identity、偏移meta及保存的layers/cast_shadow恢复。失败0。

太阳登记使用node.instance_id，按原half-rate shadow更新预留最初两帧。初轮工具误保留flow_preview导致自动流程重复推进并重置；补充caster检查又曾误用source UUID查询以instance_id为key的表。两份harness失败JSON均保留；没有根据这些工具错误修改生产物理。最终日志无ERROR/泄漏。

已查看drop-runtime-025.png和055.png，确认实际手臂/武器下落渲染。证据为weapon-drop-runtime.json/.log。780帧完整title/pause/death/retry/restart回归pause_frozen=true、最终playing，日志无ERROR/泄漏，见weapon-drop-flow.json/.log。原武器数值1140步36169项、手臂drop180步13500项、装填119266项和弹匣20544+取消128项均回归通过。Astra审查见weapon-drop-live-review.md。

## 限制

分层原函数与实际接线证明不等于完整原O联合回放或全图像素对齐。bounce RNG对应正常无异常的无声audio接收器路径，不声称audio缺失/异常分支等价。独立fixture尚未单独命中首跳低速提前rest和手臂>.9秒超时隐藏分支，实机两枪均经三次反弹落稳，手臂按高度隐藏。公开生命周期、全局初始化RNG、源图完整对齐及其余全游戏验收仍待继续。
