# 罗盘、世界目标标记与扩散准星

## 原作规则与原生实现

实现位于 `scripts/hud_projection.gd`（数学与可见性）和 `scripts/navigation_hud.gd`（原生Control绘制），由GameUI每帧更新。源码依据是保存的 `../../artifact-rendering-study/source/extracted/bundle-1.js:83490–83536,83713–83743,83829–83925`，原HTML CSS约44–62、84–89、154–161行。源快照SHA256为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。原始入口：https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。

| 项目 | 迁移规则 |
|---|---|
| 罗盘 | 航向=-yaw角度归一到0–360；显示三位整数，每度4px；5/15/45度三级刻度，N/NE/E等方向；原作刻度带移动按0.5px量化 |
| 罗盘目标 | 相对方位归一到[-180,180)，夹到宽度一半减14px，边缘透明度0.55；显示字母与水平距离四舍五入到米 |
| 世界位置 | 真实主相机变换和FOV；中继点原位置加1.9m，撤离加1.2m；使用原OpenGL投影深度判定ce.z>1，避免Godot反向Z约定改变背面判断 |
| 屏幕夹取 | 原NDC水平±0.9、垂直±0.82；背面先翻转x/y再夹取；转换到整数屏幕像素 |
| 可见性 | 米数小于3隐藏，视野中心弱化；ADS>=0.5隐藏世界标记，罗盘仍保留。未完成中继点逐个消失，全切断后显示EX。Holdout没有中继点 |
| 准星 | ADS<=0.6且存活且非reloading_hidden；间距=tan(spread)/tan(FOV/2)×半屏高+4+冲刺10，夹4–70后量化0.5px；四条9×2px及中心2×2px |

目标和罗盘不做额外墙体遮挡测试，与原HUD一致。世界投影使用实际镜头含摇晃的姿态，罗盘航向来自逻辑yaw。字形使用原作字体的保存副本。

## 验证证据

`tools/hud_projection_reference.cjs` 直接执行保存快照中的Three r180（原引擎导出对象），用真正的PerspectiveCamera和Vector3.project执行原HUD代码块，不以重写的JS算法充当参考。640组相机/玩家输入覆盖四种尺寸和纵横比、多FOV、俯仰/横滚/逻辑yaw差异、ADS/冲刺/死亡/隐藏装填状态。

`tools/verify_hud_projection.gd` 比较22770个值，2560个目标中2358个离屏、44个近距、13个中心弱化，0失败，样本屏幕误差0px。原生Transform3D使用float32，所以验证允许屏幕舍入相差最多1px；当前样本没有使用这一余量，所有分类要求完全相同。证据 `evidence/hud-projection-verification.json`。

`--navigation-preview` 在完整原生场景中自动转向、瞄准与射击，再直接调用三个cut_relay以检查HUD生命周期。780帧，截图与 `evidence/navigation-hud-runtime.json` 记录：170帧A/B/C，215帧ADS1且准星隐藏，460帧B/C，520帧C，590帧EX，675帧ADS1，730帧EX。目标实际绘制见 `navigation-170.png`、`navigation-300.png`、`navigation-590.png`；视频为 `native-navigation-hud.mp4`（720p/60fps/13秒，无音轨）。直接调用cut_relay不能证明手动按住E成功，原来的任务交互验证另有证据。

## 未完成

CSS中的opacity0.25秒过渡、准星transform0.06秒插值、字体字距和阴影仍需像素校准；当前使用原生绘制并即时更新状态。后续命中/击杀/受伤方向已接入，见 `combat-feedback.md`；后续生命/弹药条、环形交互已接入，见 `status-hud.md`；目标打字及整体像素校准仍未完成。后续武器瞄具玻璃与准星材质已迁移，见 `sight-glass.md`。此阶段不构成完整游戏或全渲染验收。
