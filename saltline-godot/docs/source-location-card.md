# 开场地点字幕

原版依据：原 HTML CSS 第 329–335 行 `.loc-card` 和 `locin`；原 bundle 第 84282 行文本、第 84617 行 locationCard 的 class 切换，以及第 85649–85665 行 intro 显示时机。

## 实现

`location_hud.gd` 替代原固定坐标的两行 Label。左边距 max(16px,5.5vw)，底边距 28vh；保留 16px 内边距、3px 橙线。标题使用原 Big Shoulders Display 700，字号 clamp(19px,3vw,34px)，行高 1.05、字距 .16em。副标题使用原 IBM Plex Mono 400，11px、行高 1.4、字距 .1em、大写与 .64 透明度。宽度按两段文本的内在宽度收缩，再受视口宽度限制。

标题揭示使用 clip_contents 子控件实现原 clip-path。原 CSS `locin 1.1s steps(28,end)` 从右裁切 100% 变化到 -2%，Godot 使用 floor(clamp(t/1.1)*28)/28*1.02。整体淡入淡出 .5 秒，使用原默认 ease 曲线。显示状态仍由原已移植的 GameFlow.intro_card_changed 触发；相同 true 不重启动画，新的显示周期重新揭示。

## 验证

`generate_location_css_reference.py` 从未修改的原 HTML 提取完整 stylesheet，构建独立对照页；`location_css_reference.cjs` 在浏览器中暂停原 `locin` Animation 并设置 currentTime，读取 computed clipPath。14 个采样点归档在 `assets/export/fixtures/location-css-reference.json`，原始 CLI 记录 `evidence/location-css-browser-observed.txt`。此页不运行游戏，不证明字体布局。

`verify_location_hud.gd` 比较实际浏览器采样与生产 reveal_fraction，并验证重复显示、淡出完成、再次播放。全部通过；最大比例误差 4.286e-7 来自浏览器 computedStyle 的十进制百分比输出舍入，门槛 1e-6。报告 `evidence/location-hud-verification.json`。原 HTML SHA256 为 b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb。

原版 GameFlow 500 帧、11030 项比较通过。最终 GPU 实机 780 帧流程完成于 playing，暂停冻结、三次重置，日志无脚本/渲染错误。归档 `evidence/location-hud-flow.json/.log`。`evidence/location-hud-180.png` 已目视检查。

## 边界及失败记录

逐像素字体抗锯齿、CSS fractional font-size、inline 换行、模糊阴影仍待对照。当前 Godot 字号取整，淡出中途反向切换没有完整实现 CSS reversing-shortening-factor。桌面布局不包含移动设备 safe-area-inset。

首次脚本解析碰到 Godot 内置 wrap 函数重名，重命名为 wrapped_lines 后重跑。首次独立测试在 SceneTree._initialize 阶段使用 get_viewport_rect，导致尚未入树错误；改为 deferred 后干净通过。上述失败运行不作为最终集成证据。
