# 当前完成范围审计

## 2026-11-16 最终技术验收

无音频的原生复刻技术实现完成。交付为 `output/linux-runtime-20261116-r16/`；已测环境是 Linux X11、RTX 4070 SUPER、固定 Godot 4.7.2 Forward+ 兼容构建。Astra Ultra 对当前生产代码及证据的收敛审计未发现新的确定功能遗漏。以下是最终结论，下方阶段记录保留历史，不再代表当前待办。

| 原要求 | 当前证明 |
| --- | --- |
| 原游戏资产与程序材质 | 本轮重新运行资产清点，729 节点、276 几何、195 材质、132 纹理及所有记录的属性、索引和 mip 哈希通过；完整材质及道具目录另有 175/297 网格与 115/124 条 GPU 贴图校验。 |
| 光照、阴影、环境、表面和镜头效果 | 实际 HDR 世界/武器、合成深度、AO、体积光、曝光历史、bloom、streak、调色和最终显示已串联。太阳、点光、IBL、平面反射、天空/天气、雨水、海面及微细节均有专项 GPU 与生产场景记录；post/volume/motion 的 96/16/6 组原作对照通过。 |
| 动态武器、角色、战斗与任务 | 实时武器运动、手臂 IK、换弹/掉落、敌人冷池和复用、FX 与爆炸已接入。正常 Standard Mission 从出生点完成三处切断及撤离，1457 ticks、60 发、31 命中、13 击杀、保护帧 0。正常资源 Holdout 完成两波，存在真实伤害、保护帧 0；补给、死亡/重试与最高分持久化另有记录。 |
| 原菜单、HUD 与输入 | 启动、标题、暂停、设置、胜败、响应式布局及系统减少动画均已接入。键鼠/手柄/触摸有真实 Main 链路验证；最新触摸真实捕获回调九状态、760 帧操作和 16 卡片场景通过。 |
| 原十类展示 | mats/props/render/ground/fx/weapon/hands/level/backdrop/enemies 均有独立入口与运行报告；十类交互加载均通过，背景标签、风扇、船体及敌人预热灯池有独立核对。 |
| 本地可运行交付与可复用知识 | r16 包内 Boot 与触摸/桌面生命周期实测退出 0，5,566 个文件及大小/SHA 校验一致。研究项目保留来源、参考图、技术解析和 Godot 迁移表，并链接后续完整原生实现。 |

本轮另采当前原生固定机位画面，SHA 与历史光栅修正后的原生截图完全相同。与原作同机位图的 RGB8 MAE 为 0.62828125、P99 为 7，仅作差异描述，不作为整图相同的声明。报告 `main-paired-high-r16-audit-comparison.json`，新图 `main-paired-high-r16-audit-native.png`，未覆盖旧证据。

最终 18 份证据身份和范围索引见 `evidence/final-technical-audit.json`。旧 `pending_shaders` 中 fx_lit/fx_add 只绑定隐藏导出节点，生产 ImpactEffects/Tracers 使用真实 lit_particle/additive_particle 动态材质。旧完整 Spot 诊断的六处锥角边界失败保留；原游戏没有 SpotLight，实际 Point 路径对照通过，不将未使用辅助函数的差异标成已修复。

边界：不宣称 WebGL/Vulkan 逐像素全等；用户尚未作最终视觉和手感评价；实体触摸/手柄设备、Wayland 与 HiDPI 未实测。按要求排除音效。未提交、推送或部署。上述人工评价和额外平台资格没有被伪装成技术通过，也没有新增为无限实施范围。

2026-11-16 最新复核：主游戏及十类交互展示加载界面已进入 r15，具体运行证据见 boot-loading.md。本轮 Astra Ultra 又确认触摸 Deploy/Resume/Retry 会错误重捕获鼠标，以及暂停卡固定桌面提示；已在源码修正并保留真实回调验证九个状态、760 帧触摸操作及 16 个卡片场景，见 source-touch-input.md。该修正已纳入 r16 并通过包内真实回调和启动验证。研究项目已补后续原生实现/证据索引，明确早期实验与定制引擎路径的区别。此状态不构成全项目最终验收。

当前状态补记（2026-11-16）：下文是实施前审计，原三项已接入，不能继续作为当前缺口。Ultra逐帧阴影与暂停面板Start返回由 `tools/verify_quality_pause_runtime.gd` 及r7独立包10项检查验证；武器/手部工作台由对应runner及r7实际GPU启动验证。后续又接入原show=render，见 `evidence/render-showcase-verification.json`，尚未包含在r7。各项通过范围以实现记录和具体报告为准，不据此宣称全部资产/视觉已完成。

2026-11-16 后续状态：原10项公开展示均已有原生入口；后续只读复核确认的导航 HUD 内部过渡遗漏也已落实，原CSS与实际GameUI120字段对照、首次节点/列表重建/任务重置及r9独立包运行通过，见 `evidence/navigation-transition-provenance.json`、`evidence/runtime-bundle-r9-verification.json`。这些结论不替代全项目完成验收。

以下保留原审计依据和建议。

审计日期：2026-11-16。目标仍是 Godot 复刻原 HTML 的全部资产和效果细节，排除音效。本次只读核对当前生产代码、原始 bundle 与最近实现记录，没有运行 GPU，也没有修改生产文件。以下三项有直接代码证据，应优先于继续调整已知的 2 byte 菜单渐变和单个 wet bead 数值残差。

## 1. Ultra 的太阳阴影没有恢复原作逐帧更新

原作 `bundle-1.js:36943–36953` 的 `ov.Z()` 在绘制主视图前决定是否更新太阳阴影：`quality.name === "ultra" || params.shot || (frame & 1) === 0 || !shadow.map`。所以普通游戏选 Ultra 后，每个渲染帧都会刷新阴影；其他档位通常隔帧刷新。

当前 [sun_shadow_pass.gd](../scripts/sun_shadow_pass.gd) 第 94–101 行只有 `force || force_pending || frame % 2 == 0 || updates == 0`。[render_quality.gd](../scripts/render_quality.gd) 第 47–56 行只传阴影分辨率，没有刷新频率；[main.gd](../scripts/main.gd) 第 418 行调用时也没有传入 Ultra 条件。High 与 Ultra 都是 4096，因此切档甚至不会借尺寸重建触发额外刷新。

这是真实的效果时序缺口。移动敌人、掉落枪械和其他移动投影物在 Ultra 下仍使用上一帧阴影，不能由“4096 尺寸正确”或静态阴影图通过来抵消。

最小工作是给 SunShadowPass 传当前质量策略，在 Ultra 每渲染帧更新，保留其他档位的半频、首次创建及 resize 的 force_pending 路径。无须修改现有 PCSS、深度格式或 caster 材质。原 `shot` 的全频条件属于捕获入口语义，可在对应入口一并传递，不应强制普通 High 全频。

最小验证只需一个连续移动 caster 和 High → Ultra → High 的短序列：检查逐帧 UPDATE_ONCE/实际更新次数，取相邻帧阴影深度或世界阴影小块确认 Ultra 真正更新。覆盖一次原本会跳过的奇数帧即可，不需要新建全材质或全画质矩阵。

## 2. 暂停设置页内的手柄 Start 会直接恢复游戏

原作输入把 button 9 同时映射为 `pause` 与菜单 `start`，见 `bundle-1.js:68596–68614`。`X()` 在 `85638–85651` 特意让 paused 状态不处理菜单 Start；随后 paused 分支在 `85711–85714` 保留防重复时间门槛，再执行 `closePanel() || resume()`。打开 Settings 或 Controls 时，第一次 Start 只关闭面板，仍停在暂停菜单。

当前 [main.gd](../scripts/main.gd) 第 874–877 行也跳过 paused 的菜单 Start，但随后无条件设置 `pause_pending=true`。[game_flow.gd](../scripts/game_flow.gd) 第 141–143 行收到它后直接 `resume()`。因此用户还在调整设置时按 Start，会恢复敌人和游戏模拟，省略原作的一层返回行为。

最小工作是让暂停状态的 pause 消费保留现有 `pause_delay`，到期后先关闭面板并消费本次按下；面板未开才恢复。不能只在 `_poll_gamepad` 里无条件提前关面板，否则会绕过原防重复时间门槛。按住 Start 也不能在下一帧自动恢复，必须等释放后的下一次新按下。

当前 [verify_gamepad_runtime.gd](../tools/verify_gamepad_runtime.gd) 第 47–50、64–65 行验证的是 B 关闭设置、再 B 恢复，没有验证这个 Start 路径。最小补测是在实际 Main 注入已采用的标准手柄快照：暂停并打开 Settings，等待门槛后按 Start，断言面板关闭且 state 仍为 paused；释放并再次按下才 playing。Controls 共用路径只需加一次同样的中间态检查，不需要实体手柄审批。

标题面板中 Start 关闭面板后启动游戏是原 `85649–85651` 的明确行为，当前 native 在这一点上正确，不应一并改掉。

## 3. 武器与手部专用展示入口尚未接入

这项缺的是原作可直接访问的观察场景，不是普通游戏中的武器、手部资产或 IK。

原作 `bundle-1.js:85749–85760` 注册 `show=weapon` 和 `show=hands`，启动代码 `85813` 与 `85858–85903` 依据 URL 选择实际展示场景，并使用无任务、无敌人的展示环境。这是与已迁移的 `show=mats/props/fx` 同级入口，不只是孤立的内部方法。

- `BD()`，`80178–80295`：两枪都有专门的近景相机和 root/world layer 安排。步枪提供 side/right/top/hands/rhand/muzzle/optic/lower，手枪提供 side/right/top/hands/rear/grip/under；还可以观察 hip/ADS/sprint/fire/reload/locked。侧面等场景把枪根放在世界中，调用 `arms.attach(root, HIP, worldLayer)`，使用户能看到普通第一人称遮挡的握持、枪身另一侧和机械细节。
- `TD()`，`75729–75924`：独立双手/双臂场景，提供 back/palm/side/arm 与第一人称握持视图，使用实际 Fh 骨链、手指姿态与触发动作。它有独立相机和组变换，不等于将默认游戏相机拉近。

当前生产的独立展示 runner 只有 [material_catalog_runner.gd](../scripts/material_catalog_runner.gd) 与 [fx_showcase_runner.gd](../scripts/fx_showcase_runner.gd)。[main.gd](../scripts/main.gd) 第 545–556 行的 `--weapon-preview` 是固定帧射击、ADS、换弹、切枪及自动退出的回归场景，不接受上述展示选择。[weapon_arms.gd](../scripts/weapon_arms.gd) 只有普通握持和死亡掉落呈现；[weapon_arm_blend.gd](../scripts/weapon_arm_blend.gd) 虽已有数值 `attach()`，生产侧没有相应的手臂组重父级/layer/骨骼写入入口。搜索当前 scripts/scenes 也没有 `hview`、`wpose` 或对应 studio runner。

最小工作应复用已有实时 Weapon/Fh、材质和渲染链，建立对应的专用 native 展示入口；先移植源的默认场景与具名观察视图，再接场景需要的 attach/恢复。不要另造静态模型或恢复已删除的采样动画。CLI 选择可沿用现有 catalog/FX runner 的方式，无须为此新增主游戏菜单，也无须先实现任意 `window.__setShot` 调用或所有调参组合。

最小验证是一组可见性明确的样例：步枪 side 与 optic、手枪 grip 与 locked、双手 palm 与一种握持/触发姿态。核对源相机、世界层/武器层、手臂父级、真实骨骼和材质绑定，并留对应截图。目标是这些入口确实能检查原来可见的资产面和动作；不把“截图导出成功”宣称为整图像素一致。

## 完成判断与实施顺序

建议先修前两项局部行为，再做第三项独立展示入口。三项都是可定位的生产缺口，不依赖重新证明实体设备、全部内部 API 或任意参数组合。

此次没有把旧文档中的“手臂仍采样”“仅 high 资产”“缺少 fire/drip/FX 场景”“材料/props 目录不全”等历史文字重新列为缺口。当前实现已覆盖这些阶段。普通游戏从出生点完成任务的证据也继续有效。

菜单渐变的少量 byte 差、wet bead 的单例跨后端差、完整游戏逐像素证据不足应继续保留各自记录，但性质不同：它们不能证明上述三个功能已经完成，也不应成为无限延长复刻工作的唯一理由。本审计只给当前最值得实施的三项，不据此宣称其余所有目标已经穷尽。
