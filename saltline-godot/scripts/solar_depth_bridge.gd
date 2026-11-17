class_name SaltlineSolarDepthBridge
extends CompositorEffect

# R32F solar-only output. Weapon output is a visibility mask, not scene distance.
var output=Texture2DRD.new()
var weapon_mode=false
var _rd:RenderingDevice
var _shader=RID()
var _pipeline=RID()
var _sampler=RID()
var _target=RID()
var _size=Vector2i.ZERO
var _closing=false
var _mutex=Mutex.new()
var _ready=false
var _completed_size=Vector2i.ZERO
var _pending_size=Vector2i.ZERO
const COMPUTE="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D source_depth;
layout(r32f,set=0,binding=1) uniform restrict writeonly image2D out_depth;
layout(push_constant,std430) uniform Params {ivec2 size;int weapon_mode;int reserved;} params;
void main(){ivec2 p=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(p,params.size)))return;
 float z=texelFetch(source_depth,p,0).r;
 float value=params.weapon_mode!=0?(z>0.0?0.0:1.0):clamp(1.0-z,0.0,1.0);
 imageStore(out_depth,p,vec4(value,0.0,0.0,1.0));}
"""
func _init()->void:
 effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
 access_resolved_depth=true
 access_resolved_color=false

func _compute_source()->String:return COMPUTE
func _initial_clear_value()->Color:return Color(1,0,0,1)

func _initialize_gpu()->bool:
 _rd=RenderingServer.get_rendering_device()
 if _rd==null:return false
 var source=RDShaderSource.new();source.source_compute=_compute_source()
 var spirv=_rd.shader_compile_spirv_from_source(source)
 if not spirv.compile_error_compute.is_empty():push_error(spirv.compile_error_compute);return false
 _shader=_rd.shader_create_from_spirv(spirv);_pipeline=_rd.compute_pipeline_create(_shader)
 var state=RDSamplerState.new();state.min_filter=RenderingDevice.SAMPLER_FILTER_NEAREST;state.mag_filter=RenderingDevice.SAMPLER_FILTER_NEAREST;state.mip_filter=RenderingDevice.SAMPLER_FILTER_NEAREST;state.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;state.repeat_v=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
 _sampler=_rd.sampler_create(state)
 return _pipeline.is_valid()

func _ensure_output(size:Vector2i)->void:
 if size==_size and _target.is_valid():return
 var format=RDTextureFormat.new();format.width=size.x;format.height=size.y;format.format=RenderingDevice.DATA_FORMAT_R32_SFLOAT;format.texture_type=RenderingDevice.TEXTURE_TYPE_2D;format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
 var next=_rd.texture_create(format,RDTextureView.new());var previous=_target
 _target=next;_size=size;output.texture_rd_rid=_target
 if previous.is_valid():_rd.free_rid(previous)

func _render_callback(kind:int,data:RenderData)->void:
 _mutex.lock();var closing=_closing;_mutex.unlock()
 if closing or kind!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:return
 var buffers=data.get_render_scene_buffers() as RenderSceneBuffersRD
 if buffers==null or buffers.get_view_count()!=1:return
 var size=buffers.get_internal_size()
 if size.x<1 or size.y<1:return
 var depth=buffers.get_depth_layer(0)
 if not depth.is_valid():return
 if not _shader.is_valid() and not _initialize_gpu():return
 if size!=_size or not _target.is_valid():
  _mutex.lock();_ready=false;_mutex.unlock()
  if _pending_size!=size:_pending_size=size;call_deferred("prepare_size",size)
  return
 var source=RDUniform.new();source.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;source.binding=0;source.add_id(_sampler);source.add_id(depth)
 var target=RDUniform.new();target.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;target.binding=1;target.add_id(_target)
 var bindings=UniformSetCacheRD.get_cache(_shader,0,[source,target]);var params=PackedInt32Array([size.x,size.y,int(weapon_mode),0]).to_byte_array()
 var commands=_rd.compute_list_begin();_rd.compute_list_bind_compute_pipeline(commands,_pipeline);_rd.compute_list_bind_uniform_set(commands,bindings,0);_rd.compute_list_set_push_constant(commands,params,params.size());_rd.compute_list_dispatch(commands,ceili(size.x/8.0),ceili(size.y/8.0),1);_rd.compute_list_end()
 _mutex.lock();_completed_size=size;_ready=true;_mutex.unlock()

# Publish replacement textures before RenderingServer's queued-material flush.
# Never replace Texture2DRD from inside a compositor render callback.
func prepare_size(size:Vector2i)->void:
 _mutex.lock();_ready=false;_mutex.unlock()
 RenderingServer.call_on_render_thread(_prepare_size_gpu.bind(size))

func _prepare_size_gpu(size:Vector2i)->void:
 _mutex.lock();var closing=_closing;_mutex.unlock()
 if closing:return
 if _rd==null:_rd=RenderingServer.get_rendering_device()
 if _rd==null:return
 _ensure_output(size)
 _rd.texture_clear(_target,_initial_clear_value(),0,1,0,1)
 _pending_size=Vector2i.ZERO

func is_ready_for(size:Vector2i)->bool:
 _mutex.lock();var value=_ready and _completed_size==size;_mutex.unlock();return value

func is_ready()->bool:
 _mutex.lock();var value=_ready;_mutex.unlock();return value

func dispose()->void:
 _mutex.lock();_closing=true;_ready=false;_mutex.unlock();enabled=false
 RenderingServer.call_on_render_thread(_release_gpu)

func _release_gpu()->void:
 output.texture_rd_rid=RID()
 if _rd!=null:
  for resource in [_target,_sampler,_shader]:
   if resource.is_valid():_rd.free_rid(resource)
 _target=RID();_sampler=RID();_shader=RID();_pipeline=RID();_size=Vector2i.ZERO
