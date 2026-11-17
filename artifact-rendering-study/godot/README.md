# Saltline / Godot 独立实验

Godot 4.7.2、Forward+。这些是研究原作方法的教学实现，不是原作画面的数值复刻，也不依赖丝袜项目。

```bash
rtk proxy python3 tools/run.py run
rtk proxy python3 tools/run.py capture
rtk proxy python3 tools/verify_captures.py
```

直接用 Godot 编辑器打开 `project.godot` 也可。Linux runner 复用当前 DISPLAY，配置/用户数据放在独立 `/tmp/saltline-godot-*`。图像验证和WebP编码额外需要Python Pillow。截图为1280×800，capture退出前检查引擎错误，日志在 `captures/runtime.log`。

左侧选择实验；1/2/3/4 也可切换，方向键近远/转镜，R 恢复固定机位，F12 保存手动截图。各参数按实验独立观察，当前未生效的参数不影响对应场景。

- **微细节**：rest position的XY作为材料域，pitch_mm规定真实尺度，屏幕导数估算足迹；低于像素后减弱法线与颜色微细节，同时增加未解析法线的平均粗糙度。过滤开关做A/B。此实验的方差是解析近似，不是Saltline的normal mip长度算法；球面投影也不等同于完整袜体chart。
- **湿润与反射**：湿润场同步改变基础色、roughness和微法线，扰动乘wetness*(1-wetness)保证0/1端点精确。法线由world.xz高度解析梯度生成，不使用屏幕导数作为方向。镜像Camera3D使用向下的up方向，地面分层剔除防止反馈，物件shader仅在镜像相机中裁掉y<0片段。调reflection_scale与update_interval观察分辨率及更新策略；反射纹理和投影矩阵仅在同一刷新帧更新，跳帧时一起保持。粗糙度用9tap反射采样近似，未假设SubViewport有可用mipmap。
- **镜头**：Filmic、曝光、原生glow与独立Canvas屏幕shader组合；后者增加25tap横向高亮卷积、固定分离色调与暗角。auto_exposure单独开启CameraAttributesPractical，静态捕获证明开关运行，未证明完整适应时间常数。
- **窄窗与雾**：使用墙、窗、方向光和窗外聚光灯，切换 Godot 内置体积雾。这个几何场景用来观察雾和遮挡，聚光灯是教学补光；当前光束边界较软，不能当作原版体积光的等价实现。

反射视口使用独立Linear tone mapper、固定曝光且关闭glow，作为颜色贴图解码，减少重复Filmic。它仍是普通SubViewport输出，有LDR高光裁切和加法EMISSION混合局限，不等价原作线性HDR radiance替换。裁切是逐材质fragment discard，不是斜裁切投影；未参与此shader的外来材质需要额外适配。以上边界均是教学实验的一部分。

真实GPU采集、A/B差异与实现对应详见 [实验报告](../docs/godot-experiments.md)。
