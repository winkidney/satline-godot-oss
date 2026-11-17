# 共享发射器池：蒸汽与余烬

原始 bundle-1.js SHA256 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`，W/G/te/oe约59971–60253行定义24个复用槽位，包含steam/smolder/embers/fire/drip。原游戏中公开addEmitter调用见特效展示场景60408–60410；普通爆炸通过G创建smolder。因此本阶段补齐的是原版特效API内容，没有向正常地图自行增加原本不存在的烟柱。

`explosion_effects.gd` 在已验证的smolder池上增加kind、第二累加器与drop状态。`_start_smolder`委托同一槽位分配器，保留原先共享24槽、满池返回不活跃句柄及first-free复用行为。Godot入口为 `add_emitter(position,kind,options)`、`stop_emitter(handle)`、`set_emitter_position(handle,position)`；ttl/scale为数值选项，零值采用原默认INF/1。移动只改位置，不重算启动时的shade，与原setPos相同。

## 本次实现

- steam按13/s严格acc>1产生原lit池烟团；位置扰动、速度、生命1.8–3、尺寸、颜色[.8,.82,.85]、alpha.2、拖曳/升力/风/随机旋转和帧顺序按原M，最后覆盖fin=.12、turb=.9。
- embers按8/s严格acc>1产生原add池粒子，使用atlas帧mo=0、ramp3、颜色[10,4.2,1]、负重力-.5、turb3.5、wind1与fout.5。
- smolder保持原路径；未知kind占位和计时但不产生粒子，与原分支行为一致。此阶段fire/drip未实现，fire后续增量见下文；不能把当前公开入口当作所有kind已完成。

## 对照证据

`emitters_reference.cjs` 直接抽取原G/oe/M/u1执行，使用同一u53随机带与lit/add两池。51操作×2容量场景，覆盖steam/embers/smolder混合、未知kind、严格边界、24槽溢出、移动/停止/复用、TTL/INF、清理和2/256容量耗尽。`verify_emitters.gd` 的28426项检查通过，5331次随机消耗一致，最大误差4.77e-7。见 `emitters-verification.json/.log`。方法哈希 `0b939540b9e594e5bff26529b724a46e0d832a99ec435414dfadf1f8082d2aa3`。

现有smolder回归54176检查通过，6732次随机消耗，最大误差9.54e-7；见 `emitters-smolder-regression.log`。这些检查对照粒子生成状态，没有借此声称整体游戏时间线或运动像素一致。

## 实机

`verify_emitters_runtime.gd` 使用实际Main、生产 `_advance_effects` 与渲染器，冻结玩法物理/AI。在镜头前明确位置创建两个发射器，运行300帧。第120帧累计生成26个lit、15个add粒子；移动蒸汽句柄、停止余烬后不再新增add，第240帧两发射器均停止，第300帧清理通过。最终 `emitters-runtime.json/.log` failures为空，截图 `emitters-steam-embers.png` 已查看，蒸汽和金色余烬可见。

首次驱动在断开capture_mouse之前start，产生无焦点NO GRAB，且发射器部分被场景遮挡。测试改为先断开捕获回调，再启动，使用相机前方无遮挡位置；最终日志正常。没有为测试修改生产鼠标捕获逻辑或特效强度。

尚未完成fire持久点光、drip落地/涟漪、原特效展示场景的完整迁移、所有公开选项JS类型强制转换、全随机事件交错、源浏览器配对动态画面和GPU性能验收。此阶段通过不代表所有特效或整个游戏复刻完成。

## 持续火焰增量

`_fire` 按原oe生成24/s主火焰，4/s的第二累加器同时生成lit烟和add余烬，保持严格acc>1、参数求值与随机调用顺序。主火焰atlas Gg=5/ramp2，余烬mo=0/ramp3；满粒子池时不额外消耗仅成功分配后使用的旋转随机数。

fire从原共享点光池acquire持久槽，色0xff8a3a、范围9，初始位置为发射点上方0.5。强度按 `(14+6*sin(t*23)+4*sin(t*37.7))*scale`。TTL、stop与clear释放槽并置零强度；其他发射器继续共用24槽。setPos只移动发射器，原版点光仍留在最初位置，现保留这一行为。

### 原版对照

`fire_reference.cjs` 在前述原G/oe/M/u1基础上，进一步执行原W构造器及渲染器实际lightPool对象v，未另写火焰或灯光参考公式。4场景为粒子容量2/256×点光容量0/2，51操作含点光耗尽、移动、停止、复用、到期、混合占槽与清理。`verify_fire.gd` 124020项检查通过、30034次随机消耗一致，最大误差1.20e-7；粒子状态及光槽身份、强度、固定位置、范围和线性颜色均比较。方法哈希 `8ebbc3c90c0e84123e4556752cb11e9b832f4b88df9372dbfecd4f4c20c6349b`，见 `fire-verification.json/.log`。

蒸汽/余烬28426检查及原smolder54176检查继续通过。独立小容量是边界测试，实际Main仍使用原6个点光槽，没有缩减生产容量。

### 实机照明

`verify_fire_runtime.gd` 运行实际Main的生产特效与渲染路径240帧：火焰/烟/余烬产生、持久槽不衰减、shader数据纹理中的强度更新、固定点光位置、TTL释放、复用和clear通过，日志正常。粒子/灯状态见 `fire-runtime.json/.log`。

第90帧冻结FX模拟与世界dt，拍摄 `fire-light-on.png` 和 `fire-light-off.png`。两图已查看，关闭点光后火焰粒子仍明亮，集装箱、地面与枪械的暖色光显著消失，证明效果包含场景/武器照明，不只是自发光火焰贴片。

`compare_fire_light.py` 留下诊断差异：集装箱区域平均RGB差9.44/255，枪械16.63/255，地面12.52/255。`fire-light-difference.json` 不是源浏览器像素验收，也不将所有GPU内部状态都称作严格冻结；控制的是FX模拟、相机和传给Main的世界dt。没有借此宣称整幅图或BRDF完全等价。

fire持久点光已接入；drip落地/涟漪、原展示场景、完整JS选项强制转换、全随机事件交错与源浏览器动态配对仍未完成。

## 滴水增量

`_drip` 接入原oe的1.6/s累加器，每次减去1+随机数×0.6，保留负余量。fall计时为sqrt(2×max(height,.05)/9.81)，下落粒子初速度-.2，atlas fh=6、重力9.81、flags=2、fout=.98；计时与真实初速度轨迹并不完全同步，这是原实现行为。

先递减现有drop计时，严格小于零才生成S涟漪和三颗溅射，再处理新的滴水。涟漪固定y=.014、life.8、尺寸.05→.55；溅射从y=.03产生，使用原go散射，life.35。scale不影响drip，落地点不查物理地面。若发射器移动，旧粒子继续下落，但之后的涟漪位置读当前发射器坐标，保留原行为。

为避免2.6等高度先经过Vector3 float32后改变CPU落地计时，发射器增加position64，公共add/set位置同时支持Vector3与三分量double数组。原生Vector3输入仍保留它自身已有的精度边界；数组可从原JSON保留double。steam/embers/fire生成参数使用此双精度位置，最终粒子和Node位置仍按原渲染边界转float32。旧smolder路径未借此改写。

### 原版对照

`drip_reference.cjs` 执行原G/oe/S/go/M/u1/W，54操作×2容量场景，包含严格acc>1、drop==0不触发、最低/负高度、2.6等double位置、空池/满池、同帧落地和新滴水顺序、下落过程中移动、复用和clear。`verify_drip.gd` 31594检查通过，3947次随机消耗一致，最大误差2.39e-7。方法哈希 `7dea761f8111a890218a6e5a0c221a3142578c1a40c13ac02bba46a6c11eb87e`，见 `drip-verification.json/.log`。

双精度位置改动后，fire124020检查、steam/embers28426检查及旧smolder回归继续通过。数字证明给定输入的生成和计时，不代表全部真实游戏轨迹一致。

### 实机

`verify_drip_runtime.gd` 在实际Main生产FX/渲染路径运行360帧。固定Mulberry种子4207生成FX输入随机带，共46次消耗，6次下落、2个涟漪、6颗溅射，落地y、每次三颗、TTL及在第51帧移动后的落点断言通过。见 `drip-runtime.json/.log`，截图 `drip-ripple.png` 已查看，可见贴地环状涟漪。

首次驱动第99帧才满足移动条件，却错误地检查第82帧已发生的首个涟漪，应判为测试前置条件不成立，不能据此改生产实现。现把移动窗口提前至首滴飞行中，并在涟漪出现后等待10帧取景。之后固定随机带，避免随机滴水间隔覆盖drop计时造成重复运行数量波动；该受控随机带不是生产Math.random熵一致性证明。

五类共享发射器的生成分支现已接入；完整原FX展示场景、通用smoke选项、所有效果交错的整局源时间线、浏览器配对运动/像素与性能仍未完成。
