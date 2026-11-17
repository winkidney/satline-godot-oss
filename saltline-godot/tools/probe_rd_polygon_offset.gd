extends SceneTree
var rd:RenderingDevice
var resources:Array[RID]=[]
func keep(rid:RID)->RID:resources.append(rid);return rid
func _initialize()->void:call_deferred("run")
func run()->void:
 rd=RenderingServer.create_local_rendering_device()
 var source=RDShaderSource.new();source.source_vertex="#version 450\nlayout(push_constant,std430)uniform Params{vec4 data;}p;void main(){vec2 points[3]=vec2[](vec2(-1,-1),vec2(3,-1),vec2(-1,3));vec2 xy=points[gl_VertexIndex];gl_Position=vec4(xy,p.data.x+p.data.y*xy.x+p.data.z*xy.y,1);}";source.source_fragment="#version 450\nvoid main(){}"
 var spirv=rd.shader_compile_spirv_from_source(source);var shader=keep(rd.shader_create_from_spirv(spirv));var sample_source=RDShaderSource.new();sample_source.source_compute="#version 450\nlayout(local_size_x=1,local_size_y=1,local_size_z=1)in;layout(set=0,binding=0)uniform sampler2D depth_tex;layout(set=0,binding=1,std430)buffer Result{float values[];}result;void main(){result.values[0]=texelFetch(depth_tex,ivec2(16,16),0).r;}";var compute_shader=keep(rd.shader_create_from_spirv(rd.shader_compile_spirv_from_source(sample_source)));var compute_pipeline=keep(rd.compute_pipeline_create(compute_shader));var sampler=keep(rd.sampler_create(RDSamplerState.new()));var result_buffer=keep(rd.storage_buffer_create(4));var reports=[]
 for format in [RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT,RenderingDevice.DATA_FORMAT_D32_SFLOAT_S8_UINT]:
  var texture_format=RDTextureFormat.new();texture_format.format=format;texture_format.width=32;texture_format.height=32;texture_format.usage_bits=RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
  if not rd.texture_is_format_supported_for_usage(format,texture_format.usage_bits):reports.append({"format":format,"unsupported":true});continue
  var texture=keep(rd.texture_create(texture_format,RDTextureView.new()));var framebuffer=keep(rd.framebuffer_create([texture]));var texture_uniform=RDUniform.new();texture_uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;texture_uniform.binding=0;texture_uniform.add_id(sampler);texture_uniform.add_id(texture);var buffer_uniform=RDUniform.new();buffer_uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;buffer_uniform.binding=1;buffer_uniform.add_id(result_buffer);var uniform_set=keep(rd.uniform_set_create([texture_uniform,buffer_uniform],compute_shader,0));var pipelines={}
  for units in [-4,-3,-2,-1,0,1,2,3,4]:
   var raster=RDPipelineRasterizationState.new();raster.cull_mode=RenderingDevice.POLYGON_CULL_DISABLED;raster.depth_bias_enabled=true;raster.depth_bias_constant_factor=units;raster.depth_bias_slope_factor=0.0;var depth=RDPipelineDepthStencilState.new();depth.enable_depth_test=true;depth.enable_depth_write=true;depth.depth_compare_operator=RenderingDevice.COMPARE_OP_ALWAYS
   pipelines[units]=keep(rd.render_pipeline_create(shader,rd.framebuffer_get_format(framebuffer),RenderingDevice.INVALID_ID,RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,raster,RDPipelineMultisampleState.new(),depth,RDPipelineColorBlendState.new()))
  for z in [.001,.01,.1,.25,.5,.75,.99]:
   var samples=[];var baseline=0.0
   for units in [-4,-3,-2,-1,0,1,2,3,4]:
    var draw_list=rd.draw_list_begin(framebuffer,RenderingDevice.DRAW_CLEAR_DEPTH,[],1.0);rd.draw_list_bind_render_pipeline(draw_list,pipelines[units]);var constants=PackedFloat32Array([z,0,0,0]).to_byte_array();rd.draw_list_set_push_constant(draw_list,constants,constants.size());rd.draw_list_draw(draw_list,false,1,3);rd.draw_list_end();var compute_list=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(compute_list,compute_pipeline);rd.compute_list_bind_uniform_set(compute_list,uniform_set,0);rd.compute_list_dispatch(compute_list,1,1,1);rd.compute_list_end();rd.submit();rd.sync();var bytes=rd.buffer_get_data(result_buffer);var actual=bytes.decode_float(0);samples.append({"units":units,"depth":actual,"bits":bytes.decode_u32(0)})
    if units==0:baseline=actual
   for sample in samples:sample["delta_q24"]=(sample.depth-baseline)*16777216.0
   reports.append({"format":format,"nominal_depth":z,"baseline":baseline,"samples":samples})
 var report={"profiles":reports,"scope":"Public local RenderingDevice hardware raster depth bias,32x32 fullscreen procedural triangle,depth-write ALWAYS then compute sampler read float32;D24S8 vsD32FS8,constant units -4..4 atseven depths. Conventional0..1depth,not Forward+ integration;no slope/reversedZ/weaponrange equivalence claimed."};FileAccess.open("res://evidence/rd-polygon-offset-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"profiles":reports.size()}))
 resources.reverse()
 for rid in resources:
  if rid.is_valid():rd.free_rid(rid)
 rd.free();quit()
