class_name SaltlineDepthSamplesBridge
extends CompositorEffect

# Render-thread-only raw reverse-Z sample array for a later compositor effect.
# No Texture2DRD/Canvas consumer, so output publication has no Canvas cache window.
var output_rd=RID()
var output_size=Vector2i.ZERO
var samples=0
var _rd:RenderingDevice
var _sampler=RID()
var _shaders={}
var _pipelines={}
var _closing=false
var _ready=false
var _mutex=Mutex.new()
const COMPUTE="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
#ifdef MULTISAMPLE
layout(set=0,binding=0) uniform sampler2DMS source_depth;
#else
layout(set=0,binding=0) uniform sampler2D source_depth;
#endif
layout(r32f,set=0,binding=1) uniform restrict writeonly image2DArray output_depth;
layout(push_constant,std430) uniform Params{ivec2 size;int samples;int reserved;} params;
void main(){ivec3 p=ivec3(gl_GlobalInvocationID);if(any(greaterThanEqual(p.xy,params.size)) || p.z>=params.samples)return;
#ifdef MULTISAMPLE
 float d=texelFetch(source_depth,p.xy,p.z).r;
#else
 float d=texelFetch(source_depth,p.xy,0).r;
#endif
 imageStore(output_depth,p,vec4(d,0,0,1));}
"""
func _init()->void:
 effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT;access_resolved_depth=false;access_resolved_color=false
func _initialize(mode:bool)->void:
 if _rd==null:
  _rd=RenderingServer.get_rendering_device();var sampler=RDSamplerState.new();sampler.min_filter=RenderingDevice.SAMPLER_FILTER_NEAREST;sampler.mag_filter=RenderingDevice.SAMPLER_FILTER_NEAREST;_sampler=_rd.sampler_create(sampler)
 if _shaders.has(mode):return
 var source=RDShaderSource.new();source.source_compute=COMPUTE.replace('#version 450','#version 450\n#define MULTISAMPLE') if mode else COMPUTE
 var spirv=_rd.shader_compile_spirv_from_source(source)
 if not spirv.compile_error_compute.is_empty():push_error(spirv.compile_error_compute);return
 var shader=_rd.shader_create_from_spirv(spirv);_shaders[mode]=shader;_pipelines[mode]=_rd.compute_pipeline_create(shader)
func _render_callback(kind:int,data:RenderData)->void:
 _mutex.lock();var closing=_closing;_mutex.unlock()
 if closing or kind!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:return
 var buffers=data.get_render_scene_buffers() as RenderSceneBuffersRD
 if buffers==null or buffers.get_view_count()!=1:return
 var mode=buffers.get_msaa_3d()!=Viewport.MSAA_DISABLED;var source_rd=buffers.get_depth_layer(0,mode)
 if not source_rd.is_valid():return
 _initialize(mode)
 if not _shaders.has(mode):return
 var source_format=_rd.texture_get_format(source_rd);var count=[1,2,4,8,16,32,64][source_format.samples];var size=buffers.get_internal_size()
 if size!=output_size or count!=samples or not output_rd.is_valid():
  var format=RDTextureFormat.new();format.width=size.x;format.height=size.y;format.array_layers=count;format.texture_type=RenderingDevice.TEXTURE_TYPE_2D_ARRAY;format.format=RenderingDevice.DATA_FORMAT_R32_SFLOAT;format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
  var previous=output_rd;output_rd=_rd.texture_create(format,RDTextureView.new());output_size=size;samples=count
  if previous.is_valid():_rd.free_rid(previous)
 var input=RDUniform.new();input.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;input.binding=0;input.add_id(_sampler);input.add_id(source_rd)
 var target=RDUniform.new();target.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;target.binding=1;target.add_id(output_rd)
 var shader=_shaders[mode];var uniform_set=UniformSetCacheRD.get_cache(shader,0,[input,target]);var params=PackedInt32Array([size.x,size.y,count,0]).to_byte_array()
 var commands=_rd.compute_list_begin();_rd.compute_list_bind_compute_pipeline(commands,_pipelines[mode]);_rd.compute_list_bind_uniform_set(commands,uniform_set,0);_rd.compute_list_set_push_constant(commands,params,params.size());_rd.compute_list_dispatch(commands,ceili(size.x/8.0),ceili(size.y/8.0),count);_rd.compute_list_end()
 _mutex.lock();_ready=true;_mutex.unlock()
func is_ready()->bool:
 _mutex.lock();var value=_ready;_mutex.unlock();return value
func dispose()->void:
 _mutex.lock();_closing=true;_ready=false;_mutex.unlock();enabled=false;RenderingServer.call_on_render_thread(_release)
func _release()->void:
 if _rd==null:return
 if output_rd.is_valid():_rd.free_rid(output_rd)
 if _sampler.is_valid():_rd.free_rid(_sampler)
 for shader in _shaders.values():_rd.free_rid(shader)
 output_rd=RID();_sampler=RID();_shaders.clear();_pipelines.clear();output_size=Vector2i.ZERO;samples=0
