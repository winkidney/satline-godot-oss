# PMREM HDR资产补采（NVIDIA来源对照通过，未接入光照）

源记录两张 `PMREM.cubeUv` 均type1016 HalfFloat，384×512与768×1024。早期 `tools/export_source.cjs` 统一采样至RGBA8目标，无法保留>1亮度；该旧文件仍保留，不覆盖。

`tools/export_pmrem_hdr.cjs` 启动原HTML，等待ready且step=0，遍历原scene材质与environment，按唯一name/dimensions映射历史记录ID。texelFetch逐像素复制到RGBA32F目标，读回无编码、无clamp、bottom-to-top数据；记录原sourceHash、Three版本、真实params/time及SHA256。

两次数据分别存 `assets/export/environment/pmrem/`（high/seed4207/autostart/dt1/60）与 `pmrem-shot/`（历史high/shot1/noaudio1/dt.016666667）。两张最大亮度6与355.5；前者19363个RGB通道>1、后者2130个，所有通道有限。采集工具与manifest保留可复现来源。

尚未证明与历史快照完全一致：将新HDR clamp并round到UNORM8后，与历史RGBA8存在最大17/253字节差，超1LSB通道分别7249/约67500；shot参数重采并未消除。平均差小于最大差，但不能凭近似视觉认定资产身份已一致。须进一步区分旧texture2D过滤读回与新texelFetch、环境更新时机或其他状态差异。Astra正在审查，见后续pmrem-adviser.md。

当前Godot材质仍未使用这两张PMREM，原生环境光/IBL近似尚待替换；这些HDR数据只作为原始参考资产，不宣称完成环境光照复刻。采样器无mip硬件linear与手动bilinear诊断表明应独立验证CubeUV采样和粗糙度映射，再接实际材质。

## NVIDIA同后端重采通过

历史pristine-original记录的原浏览器是ANGLE NVIDIA RTX4070SUPER/OpenGLES3.2；此前参考session为SwiftShader。独立headed session重采到 `assets/export/environment/pmrem-gpu/`，manifest明确记录实际backend、源HTML本地SHA、原params/time、每张SHA。两张HDR clamp到UNORM8后与旧读回最大差均1、超过1LSB通道均0。768×1024峰值6，384×512峰值382.25；采用此目录作为后续IBL首选。不能从旧clipped数据单独证明>1值，但原源码、参数、后端与保留区间对照形成一致来源证据。

同一冻结SwiftShader场景的旧filtered8/fetch8/fetch32对照见 `evidence/pmrem-readback-compare.json`：filtered与fetch8最大差1，无超过1LSB；fetch8与clamp-quantize fetch32完全一致。由此排除新旧读取方法是此前17/253差异的主因；内容生成后端是关键区别。SwiftShader两目录保留作跨后端对照，不覆盖历史资产。

`export_pmrem_hdr_live.cjs` 后续已增加浏览器端实际served-document SHA计算，以避免仅用历史export脚本硬编码sourceHash作来源证明。当前已保存NVIDIA数据有本地实际HTML SHA，浏览器端字段需下一次重采补上，未伪造已采集字段。完整环境光照仍未接入。

后续接入状态：canonical NVIDIA HDR现已用于138个Standard的原IBL，完整记录见source-ibl.md。采集manifest中的未接入标记为采集当时状态，不作为当前运行状态；资产原始来源字段保持不变。
