# 原生雨线、檐滴与落地雨冠

原始入口 https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp 。来源为保存活动脚本 `../../artifact-rendering-study/source/extracted/bundle-1.js:56492–56731`，LP/FP雨线、NP/UP雨冠、Vw实例生成、Gw控制器。活动脚本SHA256为 `756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8`。

## 资源和公式迁移

`source_scene.gd`将aSeed的InstancedBufferGeometry改为原生MultiMesh：雨线9000条、檐滴260条、雨冠900个，原种子来自原始float32二进制，直接存入INSTANCE_CUSTOM，不重新随机生成。原四顶点条带和索引复用。两个透明材质替换原先不透明占位并取消隐藏，透明排序优先级100/99保持雨线晚于雨冠；无阴影、不写深度、双面、加法混合。

`tools/port_rain_shaders.py`从导出Shader生成 `rain.gdshader`、`rain_splash.gdshader`：

- 雨线沿(-2.6,-9.4,1.1)速度乘种子系数，在相机周围26×15×26米盒内循环；宽度不低于约0.75像素，保留物理宽度/像素宽度面积补偿、近远淡出、太阳方向的相函数和环境光。
- 四个室内盒严格内部剔除，八个天窗允许雨落入；低于x>30的-1.6米海面或其他位置的0米地面剔除。未额外发明逐滴CPU射线。
- aSeed.w<0选择檐口滴水：屋檐南边z=-10.72、x从-16到12，自7米高处重力自由落体；原1.19秒循环、雨量选取和滴水开关保留。
- 雨冠使用原sHash、周期0.26–0.4秒、相机位置按4米网格吸附，玩家附近更密；读取原湿地mask判断水洼，地面、室内与码头范围限制保留。小冠形由片段解析函数生成；原dots权重是0，未擅自增加飞散粒子。

`rain.gd`迁移Gw.update：雨量按dt×0.8向目标平滑、0.01阈值控制显示、FOV/渲染高更新像素宽度、遮挡盒扩大0.15/1/0.3米、天窗半尺寸和檐滴开关、雷暴计时。主循环在未暂停时更新，重试不清天气时间；雨量同步原地面材质uRain。

## 验证证据

| 证据 | 结果与范围 |
|---|---|
| `rain-source-verification.json` | 原雨线/雨冠片段公式经输出接口改名后保留；同时检查实例通道、加法和深度模式，不代表最终颜色已逐像素匹配 |
| `rain-verification.json` | 直接执行原Gw.update闭包1000帧，98521比较，0失败；雨量/可见性、分辨率回退、盒/天窗/檐滴、一次雷暴事件；给两端同一受控seed1337和字面步长，最大误差约4.20e-7 |
| `rain-gpu-verification.json` | 实际native雨滴顶点Shader、INSTANCE_CUSTOM和原盒/天窗参数，读回kill标志；9组户外、屋顶、天窗、地面、海面、屋顶上方、檐滴关闭/开启均通过 |
| `rain-seed-verification.json` | 真实Forward+渲染后端读回MultiMesh所有40640个float分量，0误差，包含负檐滴种子。dummy headless后端不能保留可读实例缓冲，验证脚本要求GPU |
| `rain-runtime.json` | 完整原生场景600帧，9260雨/檐滴、900雨冠，户外/低机位/屋内/檐口及雨量降低；种子转移也在完整场景读回 |
| `game-flow-runtime.json` | 新雨水集成后780帧标题/设置/暂停/死亡/重试，pause_frozen包含rain_time；三次reset仍通过 |

录像 `evidence/native-rain.mp4`：10秒/1280×720/60fps，无音轨。`rain-090.png`户外雨线，`rain-155.png`低机位雨冠/水洼，`rain-240.png`屋内，`rain-390.png`檐口。默认 `native-game-flow.mp4`同步更新到本阶段当前画面。

## 边界

控制器暂用独立seed1337雷暴随机流，尚未对齐全局原rng.fork消耗顺序；原导出雨滴实例种子本身已精确保留。后续thunder信号已连接原天空云内闪光（见sky.md），原后处理闪光尚未完成，也没有音效。原source质量档切换重建数量、完整室内环境亮度适配、镜头污渍/眩光和其他湿润参数仍待迁移。当前场景雨色受Godot过渡曝光/灯光影响，未证明最终像素与原作一致。雨冠完整动态坐标尚未逐个GPU数值对照，当前证据为源公式、种子传递和完整场景运行。

GPU验证命令：`rtk proxy env DISPLAY=:0 godot --path saltline-godot --audio-driver Dummy --display-driver x11 --script tools/verify_rain_gpu.gd`，种子检查将script改为 `tools/verify_rain_seeds.gd`。
