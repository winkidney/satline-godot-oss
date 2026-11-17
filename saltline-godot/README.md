# Saltline 原生 Godot 复刻

当前完整渲染预览请用 `rtk proxy saltline-godot/tools/run_native.sh -- --game`（从workspace运行）。它使用已构建的隔离Godot兼容版，默认包含真实湿地平面反射；系统Godot未替换。构建与校验见 `engine/README.md`，反射对比录像见 `evidence/native-planar-reflection.mp4`。

实机视频：[光栅方向修正后实机射击视频](evidence/native-raster-origin-shooting.mp4)，8秒、720p/60fps、无音轨，包含枪口闪光、命中火花、雨水、烟雾与HUD；[武器材质近景](evidence/weapon-studio-rifle-side-origin.png)。当前枪根与双臂使用原实时运动及IK，新增world/weapon/planar每视口光栅方向修正。当前技术验收见 [最终范围与证据](docs/current-completion-audit.md)；固定录制 fps 不代表实时性能，不宣称跨后端逐像素相同。


目标是完整复刻 `../artifact-rendering-study/source/saltline.original.html` 的资产、玩法和视觉效果，不包含音效。资产、渲染系统、Mission/Holdout、菜单输入及十类展示已完成已测 Linux 环境内的技术实现与验证，人工视觉和手感评价尚未进行。源码主入口已补齐启动加载界面，桌面及窄屏减少动画验证见 [启动记录](docs/boot-loading.md)；r16 包包含主入口及十类独立展示的加载界面，并修正触摸模式鼠标捕获和暂停提示。

最新固定机位截图：[当前原生画面](evidence/main-paired-high-r16-audit-native.png)。本轮图像与历史原生输出字节一致，原作对照残差及支持范围见最终审计。

原作浏览器采集脚本需要本机安装的 Playwright 和 Chrome；Node.js 按正常模块解析查找 `playwright`，也可通过 `NODE_PATH` 指向现有模块目录。引擎构建记录在本机生成，不随仓库提交。

历史报告中的工具哈希记录采集当时的文件；采集脚本的 Playwright 路径现改为正常模块解析，故这些历史工具哈希不代表当前脚本哈希。历史报告中的本机路径已脱敏，运行结果和资源哈希保留。

## 运行

本机验证版本 Godot 4.7.2，Forward+，RTX 4070 SUPER。

```sh
rtk proxy python3 saltline-godot/tools/run.py import
rtk proxy python3 saltline-godot/tools/run.py run
```

`import` 使用系统 Godot 编辑器导入资产；`run` 默认调用固定引擎并进入完整游戏。显式 `GODOT` 环境变量可覆盖引擎，运行时覆盖版本须支持本项目的引擎补丁。`capture` 保留静态资产采集用途。

WASD 移动，Shift 冲刺，Ctrl 蹲伏，Space 跳跃，鼠标转向，右键瞄准视野，Esc/P 暂停与恢复，E 按住切断中继点，F12 截图。左键射击，R 装填，1/2 或 Q 切换武器。已有弹药、射速、半自动触发、散布、静态场景射线和相机后坐力。枪根由原实时弹簧/步态/惯性/后坐力D驱动，正常手臂已由原实时握持目标、切枪历史混合、双骨骼/手腕IK、指骨与握持冲击弹簧驱动，枪栓/套筒等六角色已由原实时机械状态驱动，弹匣已接入原实时拔出、脱落、换手和插入轨迹，死亡时武器进入世界层掉落、手臂放松下落，重试恢复；已有原作程序化枪焰、短时枪口光照、原生弹壳弹跳、三层曳光、PBR弹痕、金属火花、受光烟尘、实例碎片和可爆物引爆；其余手臂公开生命周期、其余全局随机流和整体对齐仍未完成。设置新增原作三档武器位置 Close / Three-quarter / Compact 并保存。默认启动进入原生标题菜单，支持 Mission/Holdout、三档难度、设置、暂停、失败重试和撤离结算。

静态 GPU 截图：`evidence/native-assets.png`。镜头移动预览：`evidence/native-preview.mp4`，720p、30fps、200帧，无音频。视频使用确定性镜头路径，不代表完整战斗演示。

最新油桶实机录像：`evidence/native-barrel-explosion.mp4`，展示真实射击引爆油桶、实例消失、火球与烟团、碎片回收和油桶重置。独立爆炸效果录像为 `evidence/native-explosion.mp4`。实现及局限见 `docs/weapon-effects.md`。

最新原生界面与重试录像：`evidence/native-game-flow.mp4`，13秒/720p/60fps，无音频。包括标题、设置、暂停、死亡与两次重开；通过自动输入和真实 Button 信号驱动，尚不代表手动通关。任务无线电字幕与一次性触发、死亡/重开清理已接入，无配音。详细证据见 `docs/game-flow.md`。

导航HUD录像：`evidence/native-navigation-hud.mp4`，13秒/720p/60fps。覆盖罗盘转向、ADS世界标记隐藏、扩散准星和中继点全部切断后切换EX撤离标记。源函数与真实Three投影对照见 `docs/navigation-hud.md`。

战斗反馈录像：`evidence/native-combat-feedback.mp4`，10秒/720p/60fps；真实射线命中与击杀驱动HUD，包含Weak point标签、受伤方向和重试清理。控制输入与测试边界见 `docs/combat-feedback.md`。

生命/弹药与交互录像：`evidence/native-status-hud.mp4`，12秒/720p/60fps；真实装填、切枪、伤害/回复、按住E断点和重试，见 `docs/status-hud.md`。

瞄具材质录像：`evidence/native-sight-glass.mp4`，9秒/720p/60fps；原作解析镀膜玻璃与准直红色点/环/刻线已接入，覆盖腰射、ADS、射击与受控反射亮度过渡，见 `docs/sight-glass.md`。

海面实机录像：`evidence/native-sea.mp4`，8秒/720p/60fps；原作波浪、法线细节、近岸泡沫与日光碎高光已接入，光照适配边界见 `docs/sea.md`。

雨水实机录像：`evidence/native-rain.mp4`，10秒/720p/60fps；原雨线、檐滴、雨冠和屋顶/天窗遮挡已接入，详见 `docs/rain.md`。默认游戏录像 `native-game-flow.mp4` 已更新为含雨水与当前HUD/瞄具版本。

动态天空录像：`evidence/native-dynamic-sky.mp4`，8秒/720p/60fps；原解析云层与定向片状闪电已接入。96组原Three与Godot HDR GPU读回对照通过，详见 `docs/sky.md`。

原作色调与受伤后处理录像：`evidence/native-post-composite.mp4`，12秒/720p/60fps；包含HDR合成、低血量、受伤脉冲、ADS周边柔化及恢复/重试，当前关闭的效果与验证边界见 `docs/post-composite.md`。

Hound原生程序步态录像：`evidence/native-hound-pose.mp4`，4秒/60fps。它验证世界足点与动态IK的受控运动；后续完整AI、战斗和原生管理器已接入，见 `docs/enemy-implementation.md`。

原AO现已替换默认Godot SSAO，包含MSAA逐sample组合深度、R32F half、原AO8和joint composite。`evidence/native-source-ao.mp4`前2秒关闭、后2秒开启，时间/相机冻结用于对照。原最后显示层、曝光和太阳眩光证据见`docs/final-finish.md`、`docs/solar-flare.md`。

默认已接原 24 步体积光、4096² 太阳阴影及双向深度引导模糊。公式对照、实机阴影开关截图与 6 秒录像见 `docs/volume.md`；阴影输入与资源证据见 `docs/sun-shadow-pass.md`。

## 验证

```sh
rtk proxy node saltline-godot/tools/physics_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_physics.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_player.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_weapon.gd
rtk proxy node saltline-godot/tools/tracer_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_tracers.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_decals.gd
rtk proxy node saltline-godot/tools/particle_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_particles.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_debris.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_light_pool.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_explosions.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_explosives.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_splash.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_impact_surfaces.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_navigation.gd
rtk proxy node saltline-godot/tools/rng_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_rng.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_enemy_coordinator.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_hound_pose.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_hound_locomotion.gd
rtk proxy node saltline-godot/tools/mission_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_mission.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_game_flow.gd
rtk proxy python3 saltline-godot/tools/port_composite_shaders.py
rtk proxy node saltline-godot/tools/sky_weather_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_sky_weather.gd
rtk proxy node saltline-godot/tools/rain_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_rain.gd
rtk proxy python3 saltline-godot/tools/verify_rain_source.py
rtk proxy python3 saltline-godot/tools/verify_sea_source.py
rtk proxy node saltline-godot/tools/sea_reference.cjs
rtk proxy python3 saltline-godot/tools/verify_sight_source.py
rtk proxy node saltline-godot/tools/sight_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_sight_environment.gd
rtk proxy node saltline-godot/tools/status_hud_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_status_hud.gd
rtk proxy node saltline-godot/tools/combat_feedback_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_combat_feedback.gd
rtk proxy node saltline-godot/tools/hud_projection_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_hud_projection.gd
rtk proxy node saltline-godot/tools/radio_reference.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_radio.gd
rtk proxy python3 saltline-godot/tools/run.py capture
```

碰撞参考样本直接执行原作活动脚本的 `moveCapsule` 函数生成。400组对照包含墙面、顶面、地面和台阶；证据见 `evidence/physics-verification.json`。角色行为检查见 `evidence/player-verification.json`。蒙皮顶点数值检查在场景导入时执行，记录于 `evidence/native-runtime.json`。

## 来源与迁移记录

原作 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp ，用户本地保存的 HTML 为分析依据。原文件 SHA256 `b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb`。活动脚本、研究材料、原作截图和顾问审查位于 `../artifact-rendering-study/`。

资产导出以 `tools/export_source.cjs` 为准，准备步骤为 `tools/prepare_assets.py`。不要以历史旧版本脚本替换活动版本。来源资产权利归原作者，当前保存用于用户要求的本地研究，尚未进行公开分发授权审查。

完整范围与缺口见 `docs/implementation-status.md`。

Hound行为增量验证：`godot --headless --path saltline-godot --script tools/verify_hound_behavior.gd`。该测试覆盖选位、战斗决策和瞄准公式，未代表完整敌人Actor已接入普通游戏。

Hound Actor联动录像：`evidence/native-hound-actor.mp4`，15秒/60fps。包括AI选位与连射请求、程序步态、脚本受击倒地、烟火和持久残骸；玩家伤害和完整战斗仍待接入。

```sh
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_hound_life.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_hit_shapes.gd
```

真实武器战斗录像：`evidence/native-hound-combat.mp4`，15秒/60fps。支持开发测试入口 `godot --path saltline-godot -- --hound-fight`，可移动、射击并受到机械犬伤害，完整任务与敌人队列尚未完成。

```sh
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_combat.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_player_vitals.gd
```

原生八对象池录像：`evidence/native-enemy-pool.mp4`，10秒/60fps。展示受控击杀后的残骸上限、下沉、回收和池满复用。

```sh
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_enemy_manager.gd
```

Gull近距离联动录像：`evidence/native-gull.mp4`，10秒/60fps。包含飞行、旋翼/云台、受控射线受击、旋翼脱落、坠落爆炸和池回收；弹体模拟和共享扫描光待实现。

```sh
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_gull_flight.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_gull_behavior.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_gull_life.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_gull_hit_shapes.gd
```

Gull实际弹体与扫描光录像：`evidence/native-gull-combat.mp4`，10秒/60fps。包含原始弹体网格、玩家伤害、敌人枪焰、共享扫描Omni、坠落爆炸和池回收。

```sh
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_bolts.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_scan_light.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_enemy_muzzle.gd
```

任务流程录像：`evidence/native-mission.mp4`，13秒/60fps。自动传送/无敌用于验证三点切断、动态门/发光和真实敌人增援后撤离，不代表手动通关验收。

开发入口：`godot --path saltline-godot -- --mission`，E持续切断中继点；`--holdout` 进入波次核心。完整原作UI和重开流程待完成。

```sh
rtk proxy node saltline-godot/tools/export_game_rules.cjs
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_mission.gd
rtk proxy saltline-godot/tools/run_native.sh --headless --script tools/verify_relay.gd
```

默认通用 Standard 现使用原太阳 Lambert/GGX 与 8+16 PCSS，覆盖 250 个原对象，保留逐对象阴影接收标记。实现与验证见 `docs/source-sun.md`，6 秒开关录像为 `evidence/native-source-sun.mp4`；ground/sea/arms 等特殊材质迁移及完整反射仍在进行。

太阳迁移现已扩展到ground/sea/arms，覆盖全部138个原Standard材质、254个原对象；局部光/IBL、特殊总光修饰和完整反射仍在进行，详见 `docs/source-sun.md`。

原版目录中此前未实例化的六种材质可单独查看：

```sh
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game
```

包含 asphalt、brick、anodized_black、carbon、armor_orange、water_dark 的原版平面与球体样本，Escape退出。它复用主场景服务后隔离原地图；完整48材质/贴花/36道具展示入口仍待完成。

完整原版48材质与贴花/标签展示目录：

```sh
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full
```

包含原版175个网格及公共混凝土地面。115条GPU mip链读回校验通过，参考图见 `evidence/material-catalog-full-source.png`，Godot图见 `evidence/material-catalog-full.png`。

原版36类道具默认展示目录：

```sh
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=props
```

原始seed7、集装箱门开度0.6、源布局和相机。截图见 `evidence/prop-catalog.png` 与 `prop-catalog-source.png`。当前入口为固定展示，其他种子/参数生成与原版查询过滤仍待接入。

按原版布局规则筛选道具或材质，支持顺序与重复项：

```sh
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --names=forklift,container20,barrel
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --only=brick,glass
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --only=decals
```

`--names` 自动选择道具目录，`--only` 自动选择完整材质目录；只接受已收录名称。未知名称报错，尚未移植原版未知道具的占位箱行为。

目录湿度沿用原版 `wet` 参数，例如干燥对照：

```sh
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --only=brick,concrete --wet=0
```

`--wet=1` 为默认雨湿，支持其他有限数值。它修改材质的共享湿度输入，不改变天气模拟或贴图内容。r4独立运行包已包含此选项。


低画质冷启动材质目录保留原版生成结果，可与高画质目录独立选择：

```bash
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full --asset-quality=low --only=brick,concrete --catalog-frames=12
```

`--asset-quality` 选择已导出的贴图资产，不等同于菜单渲染画质。已提供 low/high/ultra 全材质目录；medium 的目录未单独导出，会明确报缺失。主游戏的冷启动低画质贴图、地面查询和雨初始化仍需接入。


主游戏低画质冷启动：

```bash
./tools/run_native.sh -- --game --cold-quality=low
```

它在创建材质前统一选择原版低分辨率材质、地面与海面纹理、512像素表面查询掩码和低画质雨初始化。显式 `--cold-quality` 的启动档位优先于保存设置；未指定它时采用保存的菜单画质。运行中主动切换菜单画质仍立即生效，但不重新生成纹理。默认及 `--cold-quality=high` 保持高画质资产。此启动选项支持已验证的 low/medium/high/ultra；medium、ultra 的主场景纹理与 high 一致，雨量和渲染参数按对应档位初始化。ultra 材质展示目录已包含 hero asphalt2048，当前主场景未使用该纹理。

主场景资产检查见 `evidence/cold-quality-low-assets.json`，截图见 `evidence/cold-quality-low-assets.png`。较早关于主游戏低画质仍未接入的说明已由此进展取代；完整原版像素一致性仍待验证。


最新独立 Linux 开发运行包：`output/linux-runtime-20261116-r16/`。包含 r15 全部功能，并修正触摸 Deploy/Resume/Retry 的鼠标捕获及暂停提示；旧版本保留。

```bash
./output/linux-runtime-20261116-r16/run.sh -- --game
```

包内附带固定引擎、资产与导入缓存，约3.07GB；运行需要支持 Vulkan Forward+ 的 Linux 桌面环境。独立运行检查见 `evidence/runtime-bundle-r16-verification.json`；包内主入口加载及保留真实捕获回调的触摸/桌面九个状态检查通过，5,566 个文件校验一致。[包内触摸暂停截图](output/linux-runtime-20261116-r16/evidence/touch-capture-paused.png)。十类展示加载及正常任务通关的历史证据保留，本轮未重跑完整任务。此包保留未裁剪导入缓存；实体触摸屏、Wayland 和 HiDPI 未实测。

当前包已包含启动画质优先级修正；历史 r4 中显式启动档位仍可能被保存设置覆盖。


Ultra 沥青材质查看：

```bash
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full --asset-quality=ultra --only=asphalt
```

完整 high/low/ultra 材质目录和道具目录已重新使用本地原版字体导出；此更新晚于r4运行包。

上述晚于r4的材质、画质优先级、UI过渡、设置控件和控制说明更新均已纳入r5；r4保持历史版本。r5仍是开发运行包，完整复刻尚未验收。

### 武器近景观察（开发入口）

复用实时手臂骨骼与原资产，可独立观察原 BD 的具名世界空间视角：

```sh
./tools/run_native.sh --script scripts/weapon_showcase_runner.gd -- --game --wgun=rifle --wpose=side
```

步枪：side/right/top/hands/rhand/muzzle/optic/lower；手枪：side/right/top/hands/rear/grip/under。Escape 退出。自动截图可加 `--studio-frames=12 --studio-capture=res://evidence/studio.png`。第一人称 `--wpose=hip|ads|sprint|fire|reload|empty|locked|switch` 也已接入；`--wt=0.62` 固定换弹时刻，`--wads` 开启瞄准。fire 沿用原版调试枪口闪光，不发射弹药。`switch` 默认推进 .14 秒后冻结，可用 `--wt` 指定；`--wlook=south|east|north|west|nw` 改变第一人称观察方向，`--wview=1|2|3` 选择武器位姿；近景也支持 `--wempty` 和 `--wt`；历史 r5 包不含此新增源码。

### 独立手部工作台（开发入口）

```sh
./tools/run_native.sh --script scripts/hands_showcase_runner.gd -- --game --hview=palm --hpose=open
```

支持 back/palm/side/arm 视角；JE 拟合后的 15 种姿态（含 rest/relaxed/open/flat/fist 与各握持姿态），逗号分隔可分别指定右、左手。`--htrig=anim` 动态扣扳机，或传数值；`--hblend=open,fist` 动态混合，第三项可固定权重；`--hwet=0.8` 固定手部湿润度（默认原版0.7；保留 TD 直接参数语义）。截图参数与武器工作台一致。`--hview=fp --hheld=rifle` 或 `--hheld=pistol` 可观察第一人称握持手势（此入口只展示双手，不显示枪械），支持动态扳机；`--hgun=x,y,z,rx,ry,rz` 覆盖枪位姿（旋转为弧度、YXZ，可省略旋转）；`--hgrip=x,y,z` 使用双手对称 foregrip 分支。

两个工作台均支持 `--cam=x,y,z,tx,ty,tz --fov=30 --exposure=1`，exposure 保留原版自动曝光；需要固定曝光时使用 --manual-exposure=1。上述工作台及后续环境、初始化修正均已纳入 r7；r5/r6 保持历史版本。

## 原作 render 展示入口

源码工程已接入原 `show=render`：14个粗糙度/金属度球、测试墙与遮挡结构、发光物体和80m公共地面，共37网格、23材质、12条原GPU mip链。

```sh
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=render
```

以上命令在saltline-godot目录执行，Escape退出。可复用 `--cam=x,y,z,tx,ty,tz --fov=74 --exposure=1`；固定曝光使用 `--manual-exposure=1`。原作按相机高度的毫米末位选择后处理：1.700为基线，1.701受伤，1.702低血量，1.703 ADS，1.704闪光，1.705淡出。例如追加 `--cam=-8.5,1.701,4.2,3,1.5,0.4`。

[当前截图](evidence/render-catalog.png)、[原作截图](evidence/render-catalog-source.png)、[验证记录](evidence/render-showcase-verification.json)。六种后处理状态、37节点/35光照绑定/34阴影caster、每次12条GPU贴图hash及原concrete目录回归通过。r7尚不含此后续入口；完整原作像素对齐与其他独立展示入口仍待核对。

仓库风扇已在源码工程接入原每秒1.7弧度的连续旋转，暂停冻结、恢复继续；只旋转原5叶片与轴，护圈保持静止。[近景](evidence/main-paired-high-shed-fan-native.png)与[原函数对照](evidence/shed-fan-motion-verification.json)。此修复晚于r7打包。

## 原作 ground 展示入口

源码工程已接入原 `show=ground`，包含原15个测试物体、湿地面、海水、实时平面反射及独立雨水流。

```sh
./tools/run_native.sh --script scripts/material_catalog_runner.gd -- --game --catalog=ground
```

在saltline-godot目录执行，Escape退出；相机/FOV/曝光参数沿用render展示。默认保留原自动曝光。[三帧默认曝光截图](evidence/ground-catalog-auto.png)、[原作截图](evidence/ground-catalog-source.png)、[验证记录](evidence/ground-showcase-verification.json)。测试物15条GPU mip链、9260雨线/檐滴与900雨冠种子hash、无室内遮挡/檐滴及实时反射检查通过。当前仅High资产采集验证，未将其他cold quality或完整像素一致性当作已通过。此入口晚于r7打包。

## 原作 level 展示入口

源码工程已接入原 `show=level`，使用经原作字节与矩阵对照的133个现有关卡网格、4盏仓库灯、原80m公共混凝土地板及连续风扇/中继点动画。该入口没有主游戏的湿地、背景场景或室内环境探针。

```sh
./tools/run_native.sh --script scripts/level_showcase_runner.gd -- --game
```

在saltline-godot目录执行，Escape退出；`--cam/--fov/--exposure/--manual-exposure`沿用工作台参数。`--level-freeze`停在原ready快照，`--level-frames=12 --level-capture=res://evidence/level.png`用于采集。[冻结配对图](evidence/main-paired-high-level-native.png)、[原作图](evidence/main-paired-high-level-source.png)、[验证记录](evidence/level-showcase-verification.json)。当前仅High及记录视角验证，r7尚不含此入口。

原作背景独立展示（源码工程）：

```sh
./tools/run_native.sh --script scripts/level_showcase_runner.gd -- --game --showcase=backdrop
./tools/run_native.sh --script scripts/level_showcase_runner.gd -- --game --showcase=backdrop --bshow=boat
```

`--bshow` 支持 `all/crane/ship/boat/sky`，默认 all，Escape 退出。复用已有背景资产；分项灯组及展示专用标牌保留原始几何，小艇固定展示高度并持续摇摆。验证记录见 `evidence/backdrop-showcase-verification.json`。r7 历史包不包含此入口。

原作敌人独立展示（源码工程）：

```sh
./tools/run_native.sh --script scripts/enemies_showcase_runner.gd -- --game --eshow=both
./tools/run_native.sh --script scripts/enemies_showcase_runner.gd -- --game --eshow=dead --efreeze
```

`--eshow` 支持 `both/gull/hound/fight/dead`；`--epre=秒数` 改变预热，`--efreeze` 停止敌人更新，Escape 退出。采用原作标准敌人参数与不会受伤的展示玩家。战斗模式保留随机选点；源码诊断可另加 `--source-nav-tape --efreeze` 重放原作采集的选点以核对骨骼，日常运行不需要该参数。

敌人展示的后续源码修正：预热相机与三帧全局效果更新已对齐原作；6盏临时灯及角色根/世界骨骼检查通过，见 [验证记录](evidence/enemy-light-bootstrap-verification.json)。此修正晚于 r8，历史运行包未覆盖。

导航 HUD 已补原作准星/间距及目标标记的中断、反向过渡；Chrome 原 CSS 与实际 GameUI 各120字段检查通过，见 [验证记录](evidence/navigation-transition-provenance.json) 和 [过渡中画面](evidence/navigation-transition-runtime-03.png)。

准星与目标标记现已接入原作透明度和间距过渡；[GPU过渡画面](evidence/navigation-transition-runtime-03.png)和[核对记录](evidence/navigation-transition-runtime.json)。该修正晚于 r8。

普通游戏敌人冷池现一次恢复原构造初态，旋翼/云台、骨骼及每槽材质身份已核对；激活/重试仍保留原池复用历史。r11包内11,605项检查及正常血量标准任务通关通过，见 [验证记录](evidence/enemy-cold-start-provenance.json)。
