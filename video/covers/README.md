# 视频封面

两张封面及宽屏原图保存在本机，不上传至 Git 仓库。

- [16:9 封面](saltline-cover-16x9.png)：1664 × 936，SHA-256 `65f11ccc9f9b3e8583294e911e30e146b7e075ee804df3fe7c66ada438f62de5`。
- [4:3 封面](saltline-cover-4x3.png)：1448 × 1086，SHA-256 `eccd86cfae58918e639eeb4d280e593c811e01db9d34995381434ac939617d01`。

使用内置 imagegen 生成，以本项目 Godot 实录中的海面、港口和机械敌人为画面参考；封面是基于实录的生成画面。参考帧分别取自 `video/recordings/godot/sea-quay-fixed.mp4` 的 1.4 秒、`video/recordings/showcases/replica/backdrop.mp4` 的 3 秒和 `video/recordings/showcases/replica/enemies.mp4` 的 3 秒。

宽屏生成原图为 1672 × 941；经用户同意，左右各裁 4 像素、上裁 2 像素、下裁 3 像素，得到严格 16:9。已逐像素核对保留区域与[生成原图](source/saltline-16-9-generated.png)一致。4:3 版本直接使用生成结果。

## 标题

> 用 Godot 复刻 Fable 5.2 封神之作 Saltline，重现光照材质海水动作物理，技术细节完全拆解，看看 Godot 能力边界在哪，附项目源码，斥巨资 15 亿 token

## 生成提示词

两张图分别使用相同的主体提示词，输入上述三张实录参考帧：

```text
Use case: ads-marketing. Create a finished Chinese video cover for a Godot game recreation and rendering research video. Use the three supplied real game screenshots as visual references: image 1 for reflective ocean water and warm sun, image 2 for Saltline's industrial port, container cranes and blue-gray sky, image 3 for the exact style of its small quadruped robot and hovering drone. Faithful to this game's existing realistic real-time 3D graphics; exciting, elegant Chinese game-technology video thumbnail, cohesive dark navy, warm amber, white. Readable bold contemporary Chinese sans-serif with strong hierarchy, excellent contrast and generous safety margins. Put the port/water/robot on the right or middle and text on a dark readable region, without hiding the major imagery. The complete exact requested title MUST appear legibly on the cover, no missing, substituted or invented characters. Place the following verbatim text across balanced lines:
用 Godot 复刻 Fable 5.2
封神之作 Saltline，
重现光照材质海水动作物理，
技术细节完全拆解，
看看 Godot 能力边界在哪，
附项目源码，斥巨资 15 亿 token
The exact title in ordinary reading order is: "用 Godot 复刻 Fable 5.2 封神之作 Saltline，重现光照材质海水动作物理，技术细节完全拆解，看看 Godot 能力边界在哪，附项目源码，斥巨资 15 亿 token". Give “Godot 复刻” and “Saltline” prominence, make the smaller lines still comfortably legible, and highlight “15 亿 token” as a tasteful accent. Avoid fake user-interface, random filler text, tiny text, cropping characters, watermarks, busy clutter, extra logos, and generic sci-fi robots not matching reference.
```

16:9 版本追加：

```text
Canvas: exact horizontal 16:9 aspect ratio, ideally 1920×1080 or another exact 16:9 pixel size. Optimize for a widescreen Bilibili video cover; use the full canvas, no letterbox.
```

4:3 版本追加：

```text
Canvas: exact horizontal 4:3 aspect ratio, ideally 1600×1200 or another exact 4:3 pixel size. Recompose as a compact version with the same visual identity; make the complete title readable and keep the horizon, crane and quadruped visible; use the full canvas, no letterbox.
```
