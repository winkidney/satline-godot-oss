# 原作研究副本与采集工具

`index.html`复用原作HTML/CSS并引用`game.js`和`study.js`。内嵌legacy-v8不复制进研究页面，因此旧版切换入口隐藏；原件仍完整保存。`diagnostic.patch`列出相对可读原脚本的全部应用改动：post/材质数据出口、纹理强制再生成、可选stock PCF、可选GPU计时。没有替换默认shader公式。

## 运行与采集

需要Python3、Node/npx、Playwright CLI及可用桌面浏览器。本轮使用Codex现有Playwright技能包装脚本；其他环境可用相同版本的CLI替换路径。采集器在学习项目的上一级目录启动CLI，保证截图路径一致。

先在本项目根目录的独立终端启动只监听本机的服务器：

```bash
rtk proxy python3 -m http.server 8793 --bind 127.0.0.1
```

另开终端，在本项目根目录执行：

```bash
rtk proxy bash ~/.codex/skills/playwright/scripts/playwright_cli.sh -s=saltgpu open http://127.0.0.1:8793/research/index.html --headed
rtk proxy bash ~/.codex/skills/playwright/scripts/playwright_cli.sh -s=saltgpu resize 1280 720
rtk proxy python3 tools/collect_browser.py tools/capture_original.cjs --name original-ablation
rtk proxy python3 tools/collect_browser.py tools/capture_showcases.cjs --name showcases
rtk proxy python3 tools/collect_browser.py tools/capture_details.cjs --name detail-validation
rtk proxy python3 tools/collect_browser.py tools/capture_numeric.cjs --name numeric-buffers
rtk proxy python3 tools/collect_browser.py tools/capture_pristine.cjs --name pristine-original
```

`collect_browser.py`把CLI大输出留在ignored `output/playwright`，把截图、纹理与JSON另存进`evidence/runtime`。截图路径和JSON中的`file`保留最初输出位置，`archived_file`指向持久副本。当前存档元数据按实际采集取得，不保证换驱动后逐像素相同。

本轮已关闭创建的浏览器和本地服务器。停止自己的采集会话可执行：

```bash
rtk proxy bash ~/.codex/skills/playwright/scripts/playwright_cli.sh -s=saltgpu close
```

## 控制语义

- `study.reset()`恢复启动时的tune/quality，把手动曝光设0.7、grain设0；不重置所有游戏状态。冻结采集另外依赖step模式已经停止。
- `study.frame(n)`只推进渲染，不能当作完整游戏推进；动态特效采集通过`__step`推进真实主循环。
- `soft=0`仅研究副本可用，加载时使用Three原生PCF。`shot/show`开启快速曝光适应，因此普通曝光响应另用autostart/dynres=0场景。
- `mode=hdr`是Reinhard加近似gamma的8位预览，raw PNG仍量化。数值出口使用`binary=true`，格式/type/shape/endian随文件存档；float16由Uint16承载位模式。
- 当前GPU query范围是post每次绘制，启用时会产生测量开销。遇到disjoint整批丢弃；不把四帧采样当长期性能结果。

截图、数值和消融边界详见[实机报告](../docs/runtime-findings.md)。原始源码行号始终使用`source/extracted/bundle-1.js`，不使用插入钩子后的行号。
