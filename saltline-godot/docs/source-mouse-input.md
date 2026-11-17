# 原作鼠标输入迁移

来源为本地 `artifact-rendering-study/source/extracted/bundle-1.js`。原始鼠标增益hE位于68202，wheel处理68370起，mousemove过滤/累积68390起，玩家look消费69021起。

生产Main现通过 `source_mouse_input.gd` 在事件阶段累积CPU double dx/dy，游戏tick在player.update之前只消费一次。使用原.0021增益、settings.sens、invertY；任一原始轴绝对值大于400即丢弃整次motion。ADS缩放在消费时按当前weapon.ads做clamp后应用。暂停/非模拟tick、状态转换、session reset清理未消费的look。player.look仍供已有自动预览使用，现同样采用.0021；实时游戏走look_normalized，避免重复增益。

player.look_normalized保留原yaw减dx、pitch减dy和pitchLimit。yaw越过正负4PI时用带符号fmod 2PI，未改成正区间wrap。

上下滚轮均产生swap，接受后280ms内丢弃后续滚动，时间来自Time.get_ticks_msec而非模拟时钟。滚轮不会触发捕获鼠标。原浏览器deltaY是像素/行等单位，Godot event.factor是notch multiplier，两者没有精确单位换算。当前普通notch路径按abs(factor)>=1接受，保留此高精度滚动差异，不能宣称触控板像素阈值一致。也尚未完成输入的手柄/触屏完整迁移。

验证见 `evidence/source-mouse-input-verification.json`，16项检查原增益、累积、拒绝异常事件、invertY、ADS、角度、一次消费、wheel边界、清理与Main加载。这里不是OS真实事件验收。独立player五项移动/跳跃/蹲伏/ADS/冲刺回归通过。旧ADS检查把Camera3D的既有.01度更新阈值误当成到目标的严格误差；初次失败保存在player-verification-fov-initial.json。修正验证为内部fov到目标误差.001和相机相对内部值.010001，未修改生产FOV逻辑。

RTX4070SUPER Forward+全场景780帧回归退出0：pause_frozen=true、死亡、两次retry/restart、最后playing，日志无ERROR/泄漏。见game-flow-runtime.json；它验证生命周期回归，未覆盖原作全部玩法或实时OS输入。

下一步完整武器D应直接接收本层消费出的原始归一化dx/dy，不应从相机yaw/pitch差值反推，避免再次混入ADS缩放、recoil和shake。当前尚未接管武器root。参见weapon-motion-adviser.md。
