extends SaltlineSolarDepthBridge
# Linear reflection colour capture plus original-compatible RGBA16F mip chain.
var _mip_shader=RID()
var _mip_pipeline=RID()
var _mip_views=[]
var mip_count=1
var allow_test_upload=false
var flip_y=false
const COLOR_COMPUTE="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D source_color;
layout(rgba16f,set=0,binding=1) uniform restrict writeonly image2D out_color;
layout(push_constant,std430) uniform Params {ivec2 size;int flip_y;int reserved1;} params;
void main(){ivec2 p=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(p,params.size)))return;ivec2 q=ivec2(p.x,params.flip_y!=0?params.size.y-1-p.y:p.y);imageStore(out_color,p,texelFetch(source_color,q,0));}
"""
const MIP_COMPUTE="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D source_level;
layout(rgba16f,set=0,binding=1) uniform restrict writeonly image2D target_level;
layout(push_constant,std430) uniform Params {ivec2 source_size;ivec2 target_size;} params;
float positive_half(float v){if(v<0.00006103515625){float a=v*16777216.0;float b=floor(a);float f=fract(a);return (b+((f>0.5||(f==0.5&&mod(b,2.0)>0.0))?1.0:0.0))/16777216.0;}uint b=floatBitsToUint(v);return uintBitsToFloat((b+4095u+((b>>13u)&1u))&4294959104u);}
float half_rne(float v){return sign(v)*positive_half(abs(v));}
vec4 sample_at(ivec2 p){return texelFetch(source_level,clamp(p,ivec2(0),params.source_size-1),0);}
void main(){ivec2 p=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(p,params.target_size)))return;
 vec2 location=(vec2(p)+0.5)*vec2(params.source_size)/vec2(params.target_size)-0.5;ivec2 a=ivec2(floor(location));vec2 f=fract(location);
 vec4 v=mix(mix(sample_at(a),sample_at(a+ivec2(1,0)),f.x),mix(sample_at(a+ivec2(0,1)),sample_at(a+ivec2(1)),f.x),f.y);
 imageStore(target_level,p,vec4(half_rne(v.r),half_rne(v.g),half_rne(v.b),half_rne(v.a)));}
"""
func _initialize_gpu()->bool:
 if not super._initialize_gpu():return false
 var source=RDShaderSource.new();source.source_compute=MIP_COMPUTE;var spirv=_rd.shader_compile_spirv_from_source(source)
 if not spirv.compile_error_compute.is_empty():push_error(spirv.compile_error_compute);return false
 _mip_shader=_rd.shader_create_from_spirv(spirv);_mip_pipeline=_rd.compute_pipeline_create(_mip_shader);return _mip_pipeline.is_valid()
func _init()->void:
 effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT;access_resolved_depth=false;access_resolved_color=true
func _compute_source()->String:return COLOR_COMPUTE
func _initial_clear_value()->Color:return Color(0,0,0,1)
func _ensure_output(size:Vector2i)->void:
 if size==_size and _target.is_valid():return
 var format=RDTextureFormat.new();format.width=size.x;format.height=size.y;format.format=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT;format.texture_type=RenderingDevice.TEXTURE_TYPE_2D;mip_count=1+int(floor(log(float(maxi(size.x,size.y)))/log(2.0)));format.mipmaps=mip_count;format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
 if allow_test_upload:format.usage_bits|=RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
 var next=_rd.texture_create(format,RDTextureView.new());var previous=_target;_target=next;_size=size;_mip_views=[]
 for level in mip_count:_mip_views.append(_rd.texture_create_shared_from_slice(RDTextureView.new(),_target,0,level,1))
 output.texture_rd_rid=_target
 if previous.is_valid():_rd.free_rid(previous)
func _render_callback(kind:int,data:RenderData)->void:
 _mutex.lock();var closing=_closing;_mutex.unlock()
 if closing or kind!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:return
 var buffers=data.get_render_scene_buffers() as RenderSceneBuffersRD
 if buffers==null or buffers.get_view_count()!=1:return
 var size=buffers.get_internal_size();var color=buffers.get_color_layer(0)
 if not color.is_valid():return
 if not _shader.is_valid() and not _initialize_gpu():return
 if size!=_size or not _target.is_valid():
  _mutex.lock();_ready=false;_mutex.unlock()
  if _pending_size!=size:_pending_size=size;call_deferred("prepare_size",size)
  return
 var source=RDUniform.new();source.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;source.binding=0;source.add_id(_sampler);source.add_id(color)
 var target=RDUniform.new();target.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;target.binding=1;target.add_id(_mip_views[0])
 var bindings=UniformSetCacheRD.get_cache(_shader,0,[source,target]);var params=PackedInt32Array([size.x,size.y,int(flip_y),0]).to_byte_array()
 var commands=_rd.compute_list_begin();_rd.compute_list_bind_compute_pipeline(commands,_pipeline);_rd.compute_list_bind_uniform_set(commands,bindings,0);_rd.compute_list_set_push_constant(commands,params,params.size());_rd.compute_list_dispatch(commands,ceili(size.x/8.0),ceili(size.y/8.0),1);_rd.compute_list_end()
 _generate_mips()
 _mutex.lock();_ready=true;_mutex.unlock()

func _generate_mips()->void:
 var previous_size=_size
 for level in range(1,mip_count):
  var next_size=Vector2i(maxi(1,previous_size.x>>1),maxi(1,previous_size.y>>1))
  var source=RDUniform.new();source.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;source.binding=0;source.add_id(_sampler);source.add_id(_mip_views[level-1])
  var target=RDUniform.new();target.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;target.binding=1;target.add_id(_mip_views[level])
  var bindings=UniformSetCacheRD.get_cache(_mip_shader,0,[source,target]);var params=PackedInt32Array([previous_size.x,previous_size.y,next_size.x,next_size.y]).to_byte_array()
  var commands=_rd.compute_list_begin();_rd.compute_list_bind_compute_pipeline(commands,_mip_pipeline);_rd.compute_list_bind_uniform_set(commands,bindings,0);_rd.compute_list_set_push_constant(commands,params,params.size());_rd.compute_list_dispatch(commands,ceili(next_size.x/8.0),ceili(next_size.y/8.0),1);_rd.compute_list_end();previous_size=next_size
func _release_gpu()->void:
 if _rd!=null and _mip_shader.is_valid():_rd.free_rid(_mip_shader)
 _mip_shader=RID();_mip_pipeline=RID();_mip_views=[];super._release_gpu()
