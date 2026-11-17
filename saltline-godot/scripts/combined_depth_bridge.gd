class_name SaltlineCombinedDepthBridge
extends SaltlineSolarDepthBridge

# Original reference resolves the selected MSAA sample after world/weapon depth test.
# Production hookup also needs verified camera/sample orientation; default game is unchanged.
var world_samples:SaltlineDepthSamplesBridge
var weapon_samples:SaltlineDepthSamplesBridge
var selected_sample=0
var flip_y=false
const COMBINED_COMPUTE="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2DArray world_samples;
layout(set=0,binding=1) uniform sampler2DArray weapon_samples;
layout(r32f,set=0,binding=2) uniform restrict writeonly image2D combined_depth;
layout(push_constant,std430) uniform Params{ivec2 size;int selected;int flip_y;} params;
void main(){ivec2 p=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(p,params.size)))return;
 ivec2 q=ivec2(p.x,params.flip_y!=0?params.size.y-1-p.y:p.y);
 float zw=texelFetch(world_samples,ivec3(q,params.selected),0).r;
 float zv=texelFetch(weapon_samples,ivec3(q,params.selected),0).r;
 precise float dw=1.0-zw;precise float dv=(1.0-zv)*.05;
 float result=zv>0.0?min(dw,dv):dw;
 imageStore(combined_depth,p,vec4(result,0,0,1));}
"""
func _compute_source()->String:return COMBINED_COMPUTE
func _render_callback(kind:int,data:RenderData)->void:
 _mutex.lock();var closing=_closing;_mutex.unlock()
 if closing or kind!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or world_samples==null or weapon_samples==null:return
 var size=world_samples.output_size
 if size!=weapon_samples.output_size or world_samples.samples!=weapon_samples.samples or selected_sample<0 or selected_sample>=world_samples.samples:
  _mutex.lock();_ready=false;_mutex.unlock();return
 if size!=_size or not _target.is_valid():
  _mutex.lock();_ready=false;_mutex.unlock()
  if _pending_size!=size:_pending_size=size;call_deferred("prepare_size",size)
  return
 if not world_samples.output_rd.is_valid() or not weapon_samples.output_rd.is_valid():return
 if not _shader.is_valid() and not _initialize_gpu():return
 var bindings:Array[RDUniform]=[]
 for pair in [[0,world_samples.output_rd],[1,weapon_samples.output_rd]]:
  var uniform=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;uniform.binding=pair[0];uniform.add_id(_sampler);uniform.add_id(pair[1]);bindings.append(uniform)
 var target=RDUniform.new();target.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;target.binding=2;target.add_id(_target);bindings.append(target)
 var uniforms=UniformSetCacheRD.get_cache(_shader,0,bindings);var params=PackedInt32Array([size.x,size.y,selected_sample,int(flip_y)]).to_byte_array()
 var commands=_rd.compute_list_begin();_rd.compute_list_bind_compute_pipeline(commands,_pipeline);_rd.compute_list_bind_uniform_set(commands,uniforms,0);_rd.compute_list_set_push_constant(commands,params,params.size());_rd.compute_list_dispatch(commands,ceili(size.x/8.0),ceili(size.y/8.0),1);_rd.compute_list_end()
 _mutex.lock();_completed_size=size;_ready=true;_mutex.unlock()
