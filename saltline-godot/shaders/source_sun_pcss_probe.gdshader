shader_type canvas_item;
render_mode unshaded,blend_disabled;
#include "res://shaders/source_sun_pcss.gdshaderinc"
uniform sampler2D tShadow:filter_nearest,repeat_disable;
uniform vec2 uShadowSize;uniform vec2 uSlope;uniform vec2 uOffset;uniform vec2 uScale;uniform vec2 uResolution;
uniform float uDepth;uniform float uRadius;uniform float uIntensity;
void fragment(){vec2 source_uv=vec2(UV.x,1.0-UV.y);vec2 uv=source_uv*uScale+uOffset;float z=uDepth+dot(source_uv-.5,uSlope);float value=getShadow(tShadow,uShadowSize,uIntensity,-.00012,uRadius,vec4(uv,z,1.0),vec2(FRAGCOORD.x,uResolution.y-FRAGCOORD.y));COLOR=vec4(value,value,value,1.0);}
