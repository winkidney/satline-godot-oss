# 太阳投影、遮挡与原眩光接线

原代码`bundle-1.js:36519–36529`按cameraPos+sunDir*500投影，正面dot>.05，NDC边缘1..1.3衰减；Q9十二点真实深度遮挡以.12秒适应可见性；tk的flare再乘adapt.g*uSunOn，增益.16，静态dirt参与调制。移植保留这个双重uSunOn逻辑，不擅自简化。太阳方向/颜色直接来自导出天空材质原uniform。

`scripts/solar_projection.gd`使用当前Camera3D.unproject_position，转换为原左下UV。`tools/solar_projection_reference.cjs`直接提取原代码块，使用原Three r180生成640组FOV/俯仰/偏航/roll/aspect参考。`tools/verify_solar_projection.gd`验证front分类与fade全部通过，正面UV最大误差.0000124，fade最大.00000115。接近正交于视线时UV极大且对Float32敏感，全部记录但仅在原front门限通过时约束UV；该门限关闭时uSunOn=0，不影响眩光。最大未门控UV误差10.2869来自一个太阳几乎在相机平面的无效投影，不隐瞒为全域UV完全相等。

默认pipeline.tick每帧同时更新Q9/tk的uSunUv、uSunOn；两路真实深度未就绪时强制uSunOn=0。世界/武器深度来源和resize修复见[双深度桥](solar-depth.md)。原uFlare=.16、uSunCol=(1,.72,.42)，未为截图加亮。测光曝光仍由原Q9驱动。

## 实机证据

`--solar-preview`走实际默认游戏链，清空敌人，只控制相机：海面(60,3,25)看太阳并左右移动视线，仓库空闲走道(-11,1.68,-23)看同一太阳，再回海面转离太阳，最后回到太阳方向。仓库位置经过原碰撞盒检查，避免相机穿入货物。相机诊断移动不代表人工游戏验收；HUD玩家状态不随诊断相机传送。

`evidence/native-solar-flare.mp4`为8秒1280×720/60fps无音轨。`solar-100.png`为开放海面，`solar-220.png`为实际仓库遮挡，`solar-340.png`为太阳转到背面，`solar-460.png`为回到太阳方向。`solar-runtime.json`保存8次实际adapt GPU读回，读回只在诊断截图时进行，正常游戏不读回。开放帧可见性约1，仓库220帧接近0，背面340帧uSunOn=0，回看后重新恢复。所有预期断言通过，`solar-runtime.log`无SCRIPT/SHADER ERROR、ERROR或泄漏。

首次接线曾过早访问尚未初始化的sky_weather，已改成直接读已加载source_scene天空材质，并完整重跑录像。当前证据来自修正后的最终运行。

仍未证实原Three D24与Godot的MSAA4边缘resolve完全一致；强遮挡/空背景通过不能代替细网格、斜边和武器轮廓的逐亚像素比较。全局光照/材质与原图仍有差异，体积光/原AO/运动模糊/nk等后处理未完成。
