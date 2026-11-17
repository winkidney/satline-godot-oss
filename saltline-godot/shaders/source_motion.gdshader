shader_type canvas_item;
render_mode unshaded,blend_disabled;
vec4 sourceSample(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}
vec4 sourceDepth(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}
float source_half_rne(float value){
 if(value<0.00006103515625){float scaled=value*16777216.0;float base=floor(scaled);float f=fract(scaled);return (base+((f>0.5 || (f==0.5 && mod(base,2.0)>0.0))?1.0:0.0))/16777216.0;}
 uint bits=floatBitsToUint(value);return uintBitsToFloat((bits+4095u+((bits>>13u)&1u))&4294959104u);
}

varying vec2 vUv;
float ign(vec2 p){ return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

uniform sampler2D tColor:filter_linear,repeat_disable; uniform sampler2D tDepth:filter_nearest,repeat_disable; uniform mat4 uInvViewProj; uniform mat4 uPrevViewProj; uniform float uShutter; uniform vec2 uRes;
vec4 source_motion(vec2 source_fragcoord){
  vec4 c0 = sourceSample(tColor, vUv);
  float d = sourceDepth(tDepth, vUv).r;
  if (d < 0.05) { return c0; }
  vec4 wp = uInvViewProj * vec4(vUv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0); wp /= wp.w;
  vec4 pc = uPrevViewProj * wp;
  vec2 puv = pc.xy / max(pc.w, 1e-4) * 0.5 + 0.5;
  vec2 vel = (vUv - puv) * uShutter;
  float len = length(vel);
  if (pc.w <= 0.0 || len * uRes.y < 0.75) { return c0; }
  vel *= min(1.0, 0.018 / len);
  float j = ign(source_fragcoord) - 0.5;
  vec3 acc = c0.rgb; float ws = 1.0;
  for (int i = 0; i < 9; i++) {
    vec2 uv = vUv + vel * ((float(i) + 0.5 + j) / 9.0 - 0.5);
    float w = sourceDepth(tDepth, uv).r < 0.05 ? 0.0 : 1.0;
    acc += sourceSample(tColor, uv).rgb * w; ws += w;
  }
  return vec4(acc/ws,1.0);
}
void fragment(){vec4 v=source_motion(vec2(FRAGCOORD.x,uRes.y-FRAGCOORD.y));COLOR=vec4(source_half_rne(v.r),source_half_rne(v.g),source_half_rne(v.b),source_half_rne(v.a));}
void vertex(){vUv=vec2(UV.x,1.0-UV.y); }
