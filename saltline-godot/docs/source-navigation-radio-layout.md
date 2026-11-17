# 罗盘和无线电字幕布局

## 原版依据与修改

原 HTML CSS 的 compass 与 world-space objective diamonds 段，以及 radio subtitles 段。原 bundle `sT` 第 83497 行起、`B` 第 83632 行、目标投影第 83833 行起、无线电 `Y` 第 84034 行起。

罗盘：恢复 CSS 的 max-width 420 与窄屏 width=viewport-40；原先错误使用 viewport-64。方位与数字标签按原版 top=12px、字号、行高和字距定位。次方位及数字透明度使用 .64；方向读数使用 IBM Plex Mono 500。目标符号中心 y=49px，目标代号与距离作为同一组按实际字体宽度居中，替代固定左右偏移。世界标记的代号 top=-24px、距离 top=11px，恢复原字距。

无线电：移除固定坐标的横排 CONTROL 和正文，改为屏幕居中、底边距 15%、宽度 min(620,viewport-32)。CONTROL 在正文上方，Barlow Condensed 600/11px、字距 3.74px。正文使用原 Barlow Condensed 500/19px、行高 24.7px、字距 .38px，逐行半透明底板。淡入淡出使用 .3 秒 CSS ease 的 cubic-bezier(.25,.1,.25,1) 曲线。原有 SaltlineRadio 队列与打字逻辑保留。

## 验证

- 原版投影 fixture 640 组、2560 标记、22,770 项比较通过，像素取整最大差异 0；仅证明投影数学，不证明文字栅格化。
- 原版无线电 Y 队列、打字与保持时间对照 720 帧、5760 项比较通过。
- 罗盘修改后 480 帧实际射击链 87 项检查通过，无脚本/渲染错误。截图 `evidence/compass-runtime-075.png` 已目视检查。
- 两项接入后实际 780 帧游戏流程通过，暂停冻结、死亡、重试、重启完成，三次重置，最终 playing；日志无错误。`evidence/compass-radio-flow.json/.log`。
- 实际无线电画面 `evidence/compass-radio-runtime-180.png` 已目视检查。

## 范围限制

Godot 字形抗锯齿、字体基线和 CSS inline box 的逐像素一致性尚未证明。当前正文底板按每行字体宽度构建；浏览器 box-decoration-break 的精确栅格边界、模糊阴影与所有换行边界仍待图像对照。目标标记 opacity 的 .15/.25 秒 CSS 过渡仍未实现，当前直接切换透明度。触屏 safe-area-inset 不在本次桌面改动内。其余菜单、位置标题和 HUD 仍有未校准项，本次不代表完整复刻完成。

当前离线实机录制视频 `evidence/native-current-shooting.mp4`：1280×720，60fps，481 帧，8.016667 秒，无音轨。已检查编码元数据并抽帧目视验证，文件及生产脚本哈希见 `evidence/current-shooting-video.json`。离线录制不证明实时帧率；视频为固定姿态射击，不代表全流程验收。
