# 原版任务 HUD 与画面对照

## 画面观察

本轮以本地原版 `ground-instrumented.html` 的实际浏览器渲染核对 Godot 截图。该副本只暴露地面查询，不改 HUD 或材质。原版 `__ready=true`、`__fatal=null`、`__errors=[]`。1280×720，对照相机 [-20,1.68,-.5] 看向 [-20,1.68,-20]，原版实际 FOV 74，frame 9。截图归档 `evidence/roof-original-browser.png`。

右上棚屋的彩色竖纹在原版截图中同样存在。因此没有针对这项调整材质。此次观察只证明原版也有这一现象，不证明两引擎的纹理采样或整幅画面像素一致。Godot 射击截图带后坐力，世界时间与相机角度未逐项对齐，不能计算全图误差。

## 任务提示修正

依据原 HTML CSS 第 64–76 行，原 bundle sT.setObjective / setTally / setRelays 第 83681–83711 行，以及 update 第 84016–84020 行：

- 左上 16px 边距，2px 橙色边线、OBJECTIVE 小标题、20px 大写任务文字和继电器方框。
- 使用已有的 Barlow Condensed 600 和 IBM Plex Mono 500 原字体资产；恢复分级字号、字间距及换行宽度。
- 内容改变时清空已显示字符，以每秒 46 个字符逐字显示。同一内容每帧传入不会重启。任务 HUD 重置时也清空，重试可重新显示。
- Holdout 使用 Stand by 或 Wave N · score，分数按英文千位分组，并隐藏继电器方框。

新文件 `scripts/objective_hud.gd` 接入实际 GameUI。CSS 的 opacity 过渡、多层模糊阴影、浏览器字形栅格化及严格逐像素排版尚未证明一致。边线闪烁使用 Godot 时间函数近似 CSS ease-out，不能声称像素复刻。其他 HUD 元素仍有待逐项校准。

## 验证

原版浏览器直接执行 10 步 setObjective/update 并读取 DOM textContent，记录 `evidence/objective-original-observed.json`。`tools/verify_objective_hud.gd` 对照这 10 个状态，并检查实际 GameUI._reset_hud 及分数分组，共 12 项通过。

实际 RTX 4070 SUPER 主场景 480 帧、13 次射击，现有 87 项射击链检查通过；已目视检查 `evidence/objective-hud-runtime-075.png`。日志 `evidence/objective-hud-runtime.log` 无脚本/渲染错误。该检查验证集成，没有覆盖所有屏幕尺寸或全部任务状态。

首次运行新全局类时因 Godot 类缓存尚未登记导致解析失败。改用显式 preload 后重跑通过；首次运行产生的射击链成功数字不作为 HUD 集成证据。

最终 780 帧流程回归通过：暂停时钟保持、死亡后重试及再次重启完成，结束于 playing，三次重置。日志无错误，归档 `evidence/objective-hud-flow.json/.log`。此流程覆盖重置调用链，逐字重置状态由上面的独立 12 项测试断言。
