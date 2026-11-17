# 源码、版本与证据

## 取得了什么

最初链接为 <https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp>。自动获取只拿到 Claude 外壳；内容接口返回 Cloudflare 验证，未从该接口取得游戏。用户随后提供 `Saltline (Copy).html`，本研究以此文件为准。没有对远端当前页面与该文件做内容一致性验证。

原件保存为 [source/saltline.original.html](../source/saltline.original.html)，没有改写。SHA-256 为：

```text
b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb
```

原件 3,552,524 字节；HTML 标题为 `Saltline (Copy)`。引擎 revision 在[当前脚本 L431](../source/extracted/bundle-1.js#L431) 为 `180`。这确认包里内嵌 Three.js r180，不代表所有库中导出的功能都被游戏使用。

下载失败时的外壳单独保留在 [source/platform/](../source/platform/)，它不参与游戏渲染技术分析。外壳的 build hash、frame UUID 和 manifest pin 不能作为游戏版本号。

## 两个 script 必须分开

| 原始 HTML 位置 | 内容 | 本研究处理 |
| --- | --- | --- |
| L378，第一个 script | `type="application/octet-stream" id="legacy-v8"`，内容为 base64 | 解码为 [legacy-v8.html](../source/extracted/legacy-v8.html)，仅存档；不是默认执行脚本 |
| L379，第二个 script | 当前游戏 IIFE，内嵌引擎和应用 | 保存 [bundle-1.raw.js](../source/extracted/bundle-1.raw.js)，另生成 [bundle-1.js](../source/extracted/bundle-1.js) 供阅读 |

旧版并非绝对不会执行。当前脚本的 [aT()，L84058](../source/extracted/bundle-1.js#L84058) 可解码它并替换整个文档；菜单在 [L84505](../source/extracted/bundle-1.js#L84505) 提供切换入口。因此需要把“默认当前版本”和“手动切换旧版”区分。当前报告没有研究旧版的渲染实现，也没有触发切换。

文件内还有一个指向早期版本的链接，见 [L84214](../source/extracted/bundle-1.js#L84214)。这属于文件内的版本说明，尚未访问核对，不当作当前样本来源的替代。

## 资源是怎样组织的

HTML 外部标签只列出 Google Fonts 的预连接与样式表。应用部分包含大量程序化几何、Canvas 纹理、GPU 纹理生成和 GLSL。当前应用段静态检索未发现外部图片/模型的 loader 调用。Three.js 自身包含 loader 类和 `fetch`，仅搜索库里的关键字不能推断游戏确实发起了这些请求。

因此，目前收集到的是**生成贴图的代码**，不是运行后 GPU 中的纹理成品。没有运行烘焙，不能展示“已导出原作 albedo/normal/ORM”。外部字体可能影响 UI 和 Canvas 文字标记；离线完整性仍待运行核验。

主要代码区域如下，行号对应 Prettier 3.5.3 的可读副本：

| 区域 | 代码起点 |
| --- | --- |
| Three.js 引擎 | L1–34629 左右 |
| 太阳/场景尺度/质量档 | [L34630](../source/extracted/bundle-1.js#L34630) |
| 几何与 UV、倒角、顶点色、合并 | [L35091](../source/extracted/bundle-1.js#L35091) |
| 渲染器、天空、后处理 | [L35301](../source/extracted/bundle-1.js#L35301) |
| 材质与程序贴图 | [L37392](../source/extracted/bundle-1.js#L37392) |
| 场景结构与远景 | [L48031](../source/extracted/bundle-1.js#L48031)、[L52262](../source/extracted/bundle-1.js#L52262) |
| 地面、水、雨水 | [L55437](../source/extracted/bundle-1.js#L55437) |
| 粒子、贴花、碎片 | [L56878](../source/extracted/bundle-1.js#L56878) |
| 武器和近景衣袖 | [L69723](../source/extracted/bundle-1.js#L69723)、[L75087](../source/extracted/bundle-1.js#L75087) |
| 敌人 | [L80296](../source/extracted/bundle-1.js#L80296) |
| 场景 showcase 与程序入口 | [L85749](../source/extracted/bundle-1.js#L85749)、[L85800](../source/extracted/bundle-1.js#L85800) |

几何也会影响材质观感。方体/圆柱/管线的 UV 以物体尺寸布置，倒角形成可接住高光的边缘，顶点色表达局部变化；静态几何按材质和阴影/渲染层合并。这些可以分别对应 Godot 的导入网格/ArrayMesh、材料坐标、顶点属性、手工 ArrayMesh 合并和重复几何的 MultiMesh 方案。不要在变形丝袜上直接照搬静态场景合并或世界投影方式。

## 怎样复现提取

以下命令只做文本处理和 AST 解析，不运行下载的脚本。工作目录为本项目根目录。

```bash
rtk proxy python3 tools/extract_source.py source/saltline.original.html --out source/extracted
```

当时使用工作区已有的可信 Prettier 3.5.3。先把 raw 副本复制为可读副本，再格式化，避免改写原始脚本：

```bash
rtk proxy cp source/extracted/bundle-1.raw.js source/extracted/bundle-1.js
rtk proxy ../kspeeder/ks-admin/node_modules/.bin/prettier --parser babel source/extracted/bundle-1.js --write
rtk proxy node tools/extract_shaders.cjs source/extracted/bundle-1.js ../kspeeder/ks-admin/node_modules/prettier/plugins/babel.js source/shaders
```

迁到别的工作区时，替换 Prettier 与 Babel plugin 路径即可。格式化版本改变可能使文档行号失效；原件及 raw 脚本哈希不受影响。AST 提取保留插值模板但不求值；普通引号字符串和运行时拼接不保证全部提取，因此 shader 文件夹是阅读辅助，不是完整 shader 构建系统。

## 初始阶段与当前验证

初始阶段仅验证原件、文本提取、静态解析和链接。用户随后明确授权实机，现已运行原作并取得GPU贴图、缓冲、画面对照和有限post计时，同时完成三个独立Godot实验。详见[实机报告](runtime-findings.md)。

访问原链接时曾启动浏览器，但只停留在安全验证外壳，未加载游戏；该会话已经关闭。延后阶段的工作仅限静态研究；后续授权后已开展本地实机阶段。
