shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/source_raster_coords.gdshaderinc"
#include "res://shaders/source_triplanar.gdshaderinc"
#include "res://shaders/source_sun_surface.gdshaderinc"
#include "res://shaders/source_direct_surface.gdshaderinc"
#include "res://shaders/source_ibl_surface.gdshaderinc"
#include "res://shaders/source_weapon_detail.gdshaderinc"
#include "res://shaders/source_weapon_bump.gdshaderinc"
uniform int source_weapon_kind=-1;
uniform bool source_exact_normal=false;
uniform bool source_markings_bump=false;
uniform float source_weapon_rain=1.0;
varying vec4 source_weapon_surface;
varying vec3 source_weapon_world_normal;
uniform sampler2D albedo_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D orm_tex:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_tex:filter_linear_mipmap_anisotropic,repeat_enable;
uniform bool source_flip_y=false;
uniform bool has_map=false;
uniform bool has_orm=false;
uniform bool has_ao_map=false;
uniform bool has_normal=false;
uniform bool vertex_color=false;
uniform bool triplanar=false;
uniform int material_side=2;
uniform bool sl_fx=false;
uniform vec3 base_color=vec3(1.0);
uniform vec3 emission_color=vec3(0.0);
uniform float roughness_value=1.0;
uniform float metallic_value=0.0;
uniform float opacity_value=1.0;
uniform float alpha_cut=0.0;
uniform bool source_material_patch=false;
uniform bool distance_alpha_cut=false;
uniform vec2 source_uv_scale=vec2(1.0);
#include "res://shaders/source_alpha_cut.gdshaderinc"
#include "res://shaders/source_material_color.gdshaderinc"
#include "res://shaders/source_tangent_normal.gdshaderinc"
uniform int tint_mode=0;
uniform vec2 uv_repeat=vec2(1.0);
uniform vec2 uv_offset=vec2(0.0);
uniform float tri_scale=1.0;
uniform vec2 normal_scale=vec2(1.0);
uniform float wetness=1.0;
uniform vec4 wet_params=vec4(0.0,1.0,0.0,0.0);
uniform vec4 macro_params=vec4(0.0,0.0,1.0,0.0);
uniform float interior=1.0;
varying vec3 local_pos;
varying vec3 local_n;
varying vec3 world_pos;
varying vec3 world_n;
varying vec3 view_pos;
varying vec4 v_hdr_color;
#include "res://shaders/source_material_noise.gdshaderinc"
#include "res://shaders/source_wet_surface.gdshaderinc"
vec4 sourceFetchAlbedo(vec2 uv){return texture(albedo_tex,vec2(uv.x,source_flip_y?1.0-uv.y:uv.y));}
vec4 sourceTriAlbedo(vec3 p,vec3 weights){return sourceFetchAlbedo(p.zy)*weights.x+sourceFetchAlbedo(p.xz)*weights.y+sourceFetchAlbedo(p.xy)*weights.z;}
vec4 sourceFetchOrm(vec2 uv){return texture(orm_tex,vec2(uv.x,source_flip_y?1.0-uv.y:uv.y));}
vec4 sourceTriOrm(vec3 p,vec3 weights){return sourceFetchOrm(p.zy)*weights.x+sourceFetchOrm(p.xz)*weights.y+sourceFetchOrm(p.xy)*weights.z;}
vec4 sourceFetchNormal(vec2 uv){return texture(normal_tex,vec2(uv.x,source_flip_y?1.0-uv.y:uv.y));}
uniform bool instance_color=false;
varying vec3 instance_tint;
void vertex(){if(source_exact_normal||source_weapon_kind>=0)NORMAL=CUSTOM2.xyz;source_weapon_world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);source_weapon_surface=CUSTOM0;instance_tint=INSTANCE_CUSTOM.rgb;v_hdr_color=CUSTOM3;local_pos=(triplanar&&source_tri_skinned)?CUSTOM1.xyz:VERTEX;local_n=(triplanar&&source_tri_skinned)?CUSTOM2.xyz:NORMAL;world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_n=normalize(MODEL_NORMAL_MATRIX*NORMAL);view_pos=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;source_sun_shadow_coord=source_sun_shadow_matrix*vec4(world_pos+world_n*.02,1.0);vec3 axis_x=vec3(1,0,0),axis_y=vec3(0,1,0);if(triplanar&&source_tri_skinned){mat3 skin=sourceTriBone(int(BONE_INDICES.x))*BONE_WEIGHTS.x+sourceTriBone(int(BONE_INDICES.y))*BONE_WEIGHTS.y+sourceTriBone(int(BONE_INDICES.z))*BONE_WEIGHTS.z+sourceTriBone(int(BONE_INDICES.w))*BONE_WEIGHTS.w;axis_x=skin*axis_x;axis_y=skin*axis_y;}source_tri_axis_x=normalize(mat3(MODELVIEW_MATRIX)*axis_x);source_tri_axis_y=normalize(mat3(MODELVIEW_MATRIX)*axis_y);}
void fragment(){
 if((material_side==0&&!FRONT_FACING)||(material_side==1&&FRONT_FACING))discard;
 if(material_side==1||(material_side==2&&!FRONT_FACING))NORMAL=-NORMAL;
 vec3 source_non_perturbed=normalize(NORMAL);
 vec2 uv=(UV*uv_repeat+uv_offset)*source_uv_scale;vec3 tw=pow(abs(normalize(local_n)),vec3(6.0));tw/=max(dot(tw,vec3(1)),.00001);
 vec4 texel=vec4(1.0);vec4 orm=vec4(1.0);
 if(has_map)texel=triplanar?sourceTriAlbedo(local_pos*tri_scale,tw):sourceFetchAlbedo(uv);
 if(has_orm)orm=triplanar?sourceTriOrm(local_pos*tri_scale,tw):sourceFetchOrm(uv);
 float mac=.5,mac2=.5,wet=0.0,up=0.0,bead=0.0;
 if(sl_fx)sourceWetSurface(triplanar?local_pos:world_pos,normalize(INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz,orm,triplanar,tint_mode,macro_params,wet_params,wetness,interior,fwidth(triplanar?local_pos:world_pos),texel,mac,mac2,wet,up,bead);
 vec3 col=sourceMaterialColor(base_color,texel,tint_mode);
 float rr=roughness_value*orm.g;
 if(sl_fx){col=sourceWetColor(col,wet,wet_params);rr=sourceWetRoughness(roughness_value,orm.g,macro_params,wet_params,mac,mac2,wet,bead);}
 if(has_normal&&triplanar)NORMAL=sourceTriNormal(local_n,tw,sourceFetchNormal(local_pos.zy*tri_scale).xyz,sourceFetchNormal(local_pos.xz*tri_scale).xyz,sourceFetchNormal(local_pos.xy*tri_scale).xyz,normal_scale,source_tri_axis_x,source_tri_axis_y,material_side==2&&!FRONT_FACING?-1.0:1.0);
 if(has_normal&&!triplanar){vec3 mapn=sourceFetchNormal(uv).xyz*2.0-1.0;rr=sqrt(rr*rr+clamp(1.0-length(mapn),0.0,1.0)*.6);mapn.xy*=normal_scale*(1.0-.45*wet*up);
 NORMAL=sourceTangentNormal(view_pos,UV*uv_repeat+uv_offset,normalize(NORMAL),mapn,material_side==2&&!FRONT_FACING?-1.0:1.0);}
 float surface_alpha=opacity_value;
 if(tint_mode==3||!source_material_patch)surface_alpha*=texel.a;
 if(distance_alpha_cut){vec2 cut=sourceDistanceAlpha(texel.a,fwidth(uv),sourceRasterPixel(FRAGCOORD.xy,VIEWPORT_SIZE,SOURCE_RASTER_Y_UP));surface_alpha=cut.x;col*=cut.y;}
 if(vertex_color){col*=v_hdr_color.rgb;surface_alpha*=v_hdr_color.a;}
 if(instance_color)col*=instance_tint;
 float source_weapon_height=0.0,source_weapon_occlusion=1.0,source_metal=metallic_value*orm.b;
 if(source_weapon_kind>=0){vec4 detail_debug;sourceWeaponSurface(source_weapon_kind,local_pos,local_n,source_weapon_world_normal,source_weapon_surface,length(fwidth(local_pos)),source_weapon_rain,col,rr,source_metal,source_weapon_height,source_weapon_occlusion,detail_debug);NORMAL=sourceWeaponBump(normalize(NORMAL),view_pos,source_weapon_height);}
 if(source_markings_bump)NORMAL=sourceWeaponBump(normalize(NORMAL),view_pos,-surface_alpha*.00005);
 if(alpha_cut>0.0&&surface_alpha<alpha_cut)discard;
 ALBEDO=max(col,vec3(0.0));ROUGHNESS=clamp(rr,.045,1.0);METALLIC=clamp(source_metal,0.0,1.0);AO=has_ao_map?orm.r:1.0;EMISSION=emission_color;
 if(source_ibl_ready){IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);if(source_ibl_radiance_enabled){vec3 detail_diffuse,detail_specular;sourceIblTerms(ALBEDO,METALLIC,rr,0.0,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),INV_VIEW_MATRIX,has_ao_map?orm.r:1.0,1.0,vec3(0),0.0,detail_diffuse,detail_specular);EMISSION+=detail_diffuse*source_weapon_occlusion+detail_specular*(source_weapon_occlusion*source_weapon_occlusion);}}
 if((source_sun_active&&source_sun_ready)||(source_local_active&&source_local_ready)){vec3 detail_diffuse,detail_specular;sourceDirectTerms(ALBEDO,METALLIC,rr,0.0,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),(VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz,sourceRasterPixel(FRAGCOORD.xy,VIEWPORT_SIZE,SOURCE_RASTER_Y_UP),VERTEX,VIEW_MATRIX,sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS),detail_diffuse,detail_specular);EMISSION+=detail_diffuse*mix(1.0,source_weapon_occlusion,.35)+detail_specular*mix(1.0,source_weapon_occlusion,.6);}
}
