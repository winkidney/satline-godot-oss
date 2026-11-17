# 武器掉落数值核心

`weapon_drop_motion.gd` 迁移原oe/le/xe/j的数值阶段，数值阶段和世界层适配现已接入生产。下文保留独立数值证据范围，实机接线见 source-weapon-drop-live.md。

起始变换保留世界相机与武器视场角的tan比例，只修正局部z，再乘相机位置/旋转。初速度带玩家速度的.6，角速度与原随机抽样顺序一致。以ceil(dt/.012)细分，重力13.5；先做水平射线碰撞，再更新位置和角度，随后groundHeight。地面接触高度.045，反弹系数.3、水平/角阻尼.55，低速或第三次触地进入rest。rest最多.5秒缓动到侧躺与高度.024。无地面且高度低于-1.7时隐藏并发splash .8。

保留原隐含历史：临时Euler初始XYZ，第一次rest后变为YXZ，restore/start不重置此顺序，所以第二次下落的增量角顺序也为YXZ。不能每帧固定XYZ。落水分支也按原continue保留当前细分循环行为。

不产生音效，但保留bounce audio原分支的随机消耗，最多4次接触，每次2个随机数，避免音频省略改变后续视觉随机流。原初始化的全局RNG分叉仍未证明；本测试只在显式给定seed4207下对照掉落路径。手臂startDrop先消耗的6次随机数由明确适配器输入，尚不意味着手臂轨迹实现完成。

## 验证

`tools/weapon_drop_reference.cjs` 执行原oe/le/xe/j及原vS.startDrop，使用原Three相机/Object3D、显式physics回调和无声audio接收器。仅arm dropUpdate及场景事件接收器mock；参考不读native输出。flat/wall/void三组各380步，两次start和restore，变化dt含0和.08，比较所有状态与ray/ground/splash参数、共享RNG state/count。

`tools/verify_weapon_drop.gd` 1140步36169项通过，最大误差2.22e-15，容限1e-10。结果 `evidence/weapon-drop-verification.json`。原源SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`；掉落片段与armStart SHA256 `258c384bff223138c09d6b6945a5f9d55e3ca5b5e46e1c5319080eba30bba5ad`。

这些证据只证明给定输入下的数值与物理查询边界。尚未覆盖实际世界碰撞、render layers/影子、武器回到view camera、手臂死亡动画或整游戏画面对齐。
