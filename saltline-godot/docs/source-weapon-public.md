# 武器公开接口与三档位置

已接入equip、set_visible、set_view、snap、add_ammo、set_wetness。原私有运动生命周期继续由weapon_motion_lifecycle驱动，呈现层通过WeakRef连接Animation，避免Weapon→Animation→drop→Weapon的强引用环。

立即equip按原顺序取消换弹、结束渐变切枪、清pending/hol、执行私有equip并snap手臂。保留原公开ads的同步特点：私有adsE在equip时归零，公开E.ads仍保持上次值，直到下一次update或snap。set_visible同步当前枪根和手臂，隐藏时按原ye条件禁用射击；死亡中则保留原手臂可见性到restore。snap对当前玩家/输入与debug ADS/sprint设置运动状态、两枪private手指参与度和手臂混合，不额外推进时间。

set_view按原1..3四舍五入和截取选择两枪views，并更新实际D所读的pose。rigs由输入深复制，避免多个Weapon测试实例选择视角时互相污染。set_wetness即时更新原武器湿度材质，下一帧仍由原环境湿度策略推进；不锁定湿度。

设置面板增加原Close/Three-quarter/Compact，选择值经set_view标准化并存入现有settings文件，载入时应用；reset保留位置选项。测试保存到evidence/public-ui-settings-test.json，没有写用户实际设置。按钮修复了长文字最小尺寸挤占相邻按钮、旧面板choices在queue_free前仍残留，以及选中focus文字颜色问题。

## 验证

weapon_public_reference.cjs提取原公开方法、私有equip和原数学，用显式dirty S生成128组操作。节点/手臂side-effect接收器是mock，此项不代表实际GPU节点。verify_weapon_public.gd通过22784项原函数合同与两项隐藏开火/再次显示扳机检查，共22786项，最大误差0，容限1e-12。参考方法SHA256 8aebae20e8f4402998a0d12ae8005cd5d00eb46418f39967a91b28302d746b84。

verify_weapon_public_runtime.gd实际Main运行150帧/30检查，真实按钮选2/3、确认保存、三档D画面，立即装备、显示/隐藏、snap、湿度shader与补弹，均通过。已查看public-runtime-032.png面板和075.png第三档实机画面。初始布局失败JSON保留。结果与日志weapon-public-runtime.json/.log，日志无ERROR/泄漏。

公开方法状态/呈现接线已覆盖这些指定用例，尚不等于全原O联合时序、全部异常类型、drop中任意公开API重排或全图像素对齐。attach等手臂公开流、全局初始化/RNG、画质/DRS及其余整游戏验收继续进行。

780帧完整流程回归pause_frozen=true、最终playing，日志无ERROR/泄漏，见weapon-public-flow.json/.log。
