# 武器冷启动状态与随机子流

生产Weapon现在从原I5的75字段冷启动S开始，时间为0。默认武器RNG使用全局seed4207的第4次fork得到3554171070，而非直接4207。reset保留RNG/时钟历史，遵循原T；不会每次retry重新抽同一段随机数。

此前scene.json导出于shot模式3帧后，六字段非冷启动值：t=.050000001、cooldown=-.001、flashT=-.050000001、idleT=.050000001、breath=.07857895131232057、wallT=.04666666600000001。资产导出仍保留原记录，生产不再借它初始化运动。显式initial_state/random_seed参数用于隔离参考测试，不是生产回退。initial_state只提供运动S并同步time，其余legacy字段、slots与rig private仍各自初始化，因此不是任意Weapon存档恢复接口。startup_info.mode只记录S来源，seed_mode独立记录canonical_fork或explicit_seed。

## 原作冷启动观测

`tools/instrument_weapon_startup.py`从未修改的原bundle生成研究目录output/playwright/startup-instrumented.js/.html，只增加su的seed/state/calls/parent元数据及I5前后状态快照。原数值运算和fork抽样保留。通过已安装Playwright CLI在本地8793运行normal title、q=high、noaudio=1、step=1、dt=.016666667；collect_weapon_startup.cjs记录为assets/export/fixtures/weapon-startup-observed.json。

全局root观测为seed4207，weapon fork之前calls3，I5返回后calls4。依次fork为level589939774、rain1278876144、explosives1883172587、weapon3554171070。关卡和雨各自内部消耗子流，不继续推进root。武器I5返回时自己的calls=0。ready后虽然渲染跑了3步，title不推进weapon，S.t仍为0。应用errors为空/fatal=null，唯一浏览器console error是favicon404。

weapon_startup_reference.cjs直接求值原a字面量及pn，75字段与浏览器构造前/原T之后完全一致，使用原su重算4个fork及武器前64次抽样。生成器直接gate ready/fatal/errors、fork前root calls3、fork后/ready calls4、四子流全部seed以及root state和weapon draws0。原HTML SHA256 b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb；bundle SHA256 756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8；观测JS SHA256 7b00f3bf1dbb5e6dd3a3a0f3ef9c464a1da774d64ecd816b39ed71a2c0e15e93。清单见weapon-startup-instrumentation.json。

## 验证

verify_weapon_startup.gd验证实际默认构造S、seed、前64抽样、reset不重置RNG和显式历史输入，共233检查失败0。首次脚本使用reference方法名与RefCounted内建冲突，已改load_reference并重跑，保留初始错误日志。

Q参考扩展到历史seed4207/导出状态和canonical seed3554171070/冷状态，两枪共96发2424比较，原容限未变，max1.17e-7。canonical用例使用默认Native构造，历史用例显式注入原fixture输入。controls211164/public22786/reload119266/root adapter1200步/weapon10检查继续通过；没有改期望去迎合新状态。

GPU verify_weapon_startup_runtime.gd实际Main确认mode/seed/time0，并复用470帧手臂、机械角色与弹匣路径：32900代理骨骼+32900Skeleton3D、940弹匣检查通过。780帧完整流程pause冻结、最终playing，日志无ERROR/泄漏。见weapon-startup-runtime.json/.log与weapon-startup-flow.json/.log。

## 范围

本次确认默认导出世界seed4207、normal/noaudio启动的weapon fork和初始S。它不证明所有query/showcase/异常模块回退路径、完整原O联合时序、全局FX/AI流或原图像素完全等价。Native只在武器侧使用正常fork顺序，其他全局流仍待迁移。Astra审查见weapon-startup-review.md。
