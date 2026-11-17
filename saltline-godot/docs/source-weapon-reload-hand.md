# 换弹左手轨迹

`weapon_reload_hand.gd` 迁移原作两枪 reload 的左手位置、旋转、20通道手指姿态及 busy 状态。生产 Weapon/ReloadKernel 已接线，但画面暂保留采样手臂，尚未使用这些目标驱动骨骼。

步枪包含前握到夹匣的分段过渡，pinch/carry换手、cup短暂停留、回插的回弹与轻拉、取拉机柄时的侧向弧线、空仓或战术拉栓和最终回握。拉机柄释放端点按原作保留历史，reset不额外清除原作未清的该端点。手枪包含从支撑握姿取新匣、随匣移动、carry/slap混合和二次曲线回握。

手指过渡使用真实原 di.relaxed/open、mag_pinch.fit.from 和导出 holds。`tools/weapon_reload_hand_reference.cjs` 直接提取 d0/di/fit.from，写入 `assets/export/weapon-reload-hand-poses.json`；参考执行完整原 reload 闭包与方法，不再用弹匣测试的手指零占位。扩展后的弹匣参考生成器仍保留原默认接口，额外返回原左手目标。

生产共享已验证的 MagazineMotion。Kernel在原reload中部的位置，先更新弹匣，再计算左手；手枪旧本地枪根旋转仍由Main在Weapon.update前采集。取消、结束、reset按实际枪种恢复左手目标。手枪的拇指止动权重另存thumb_weight，对应原ue；它不是套筒止动杆的j，不应直接用机械stop_weight替代。

## 验证

`tools/verify_weapon_reload_hand.gd` 独立内核与 `--integration` 生产接线模式均通过1284步、35952通道，最大误差2.01445e-7，容限2e-6。检查p/q/pose/busy，四种空仓/战术路径、边界左右、120Hz密集顺序和reset。Quaternion按等价符号比较。集成模式使用实际Weapon.update及其装填事件和完成清理，并共享生产弹匣；达到装填总时长后期望原endReload的rest目标。时间是显式设置的，未声称覆盖OS输入或完整实机时间链。

证据为 `evidence/weapon-reload-hand-verification.json` 与 `weapon-reload-hand-integration.json`。本阶段没有vS历史混合、Fh IK、指骨更新或整幅画面对齐证据。
