class_name SaltlineHalfDepthBridge
extends SaltlineSolarDepthBridge

# Reuses only GPU target lifecycle. Values are actual world view-distance R32F;
# weapon mask is used solely for the source d<.05 bypass sentinel, never distance.
var combined_source:Texture2DRD
var world_source:Texture2DRD
var weapon_source:Texture2DRD
var near_plane=.08
var far_plane=900.0
const HALF_COMPUTE="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D world_depth;
layout(set=0,binding=1) uniform sampler2D weapon_mask;
layout(r32f,set=0,binding=2) uniform restrict writeonly image2D half_depth;
layout(push_constant,std430) uniform Params{ivec2 full_size;ivec2 half_size;vec2 near_far;ivec2 reserved;} params;
void main(){
 ivec2 p=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(p,params.half_size)))return;
 ivec2 original_half=ivec2(p.x,params.half_size.y-1-p.y);
 ivec2 source_original=min(original_half*2,params.full_size-ivec2(1));
 ivec2 source_native=ivec2(source_original.x,params.full_size.y-1-source_original.y);
 float d=texelFetch(world_depth,source_native,0).r;
 float mask=params.reserved.x!=0?1.0:texture(weapon_mask,(vec2(source_native)+.5)/vec2(params.full_size)).r;
 precise float range=params.near_far.y-params.near_far.x;
 precise float product=d*range;precise float denominator=params.near_far.y-product;
 precise float z=params.near_far.x*params.near_far.y/denominator;
 if(mask<.5 || d<.05)z=.01;
 imageStore(half_depth,p,vec4(z,0,0,1));
}
"""
func _compute_source()->String:return HALF_COMPUTE
func _initial_clear_value()->Color:return Color(far_plane,0,0,1)

func _render_callback(kind:int,data:RenderData)->void:
 _mutex.lock();var closing=_closing;_mutex.unlock()
 if closing or kind!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:return
 var buffers=data.get_render_scene_buffers() as RenderSceneBuffersRD
 if buffers==null or buffers.get_view_count()!=1 or (combined_source==null and (world_source==null or weapon_source==null)):return
 var full_size=buffers.get_internal_size();var size=Vector2i(maxi(4,ceili(full_size.x*.5)),maxi(4,ceili(full_size.y*.5)))
 if size!=_size or not _target.is_valid():
  _mutex.lock();_ready=false;_mutex.unlock()
  if _pending_size!=size:_pending_size=size;call_deferred("prepare_size",size)
  return
 var world=combined_source.texture_rd_rid if combined_source!=null else world_source.texture_rd_rid;var weapon=world if combined_source!=null else weapon_source.texture_rd_rid
 if not world.is_valid() or not weapon.is_valid():
  _mutex.lock();_ready=false;_mutex.unlock();return
 if not _shader.is_valid() and not _initialize_gpu():return
 var bindings:Array[RDUniform]=[]
 for entry in [[0,world],[1,weapon]]:
  var uniform=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;uniform.binding=entry[0];uniform.add_id(_sampler);uniform.add_id(entry[1]);bindings.append(uniform)
 var target=RDUniform.new();target.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;target.binding=2;target.add_id(_target);bindings.append(target)
 var uniforms=UniformSetCacheRD.get_cache(_shader,0,bindings)
 var params=PackedInt32Array([full_size.x,full_size.y,size.x,size.y]).to_byte_array();params.append_array(PackedFloat32Array([near_plane,far_plane]).to_byte_array());params.append_array(PackedInt32Array([int(combined_source!=null),0]).to_byte_array())
 var commands=_rd.compute_list_begin();_rd.compute_list_bind_compute_pipeline(commands,_pipeline);_rd.compute_list_bind_uniform_set(commands,uniforms,0);_rd.compute_list_set_push_constant(commands,params,params.size());_rd.compute_list_dispatch(commands,ceili(size.x/8.0),ceili(size.y/8.0),1);_rd.compute_list_end()
 _mutex.lock();_ready=true;_mutex.unlock()
