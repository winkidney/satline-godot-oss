shader_type canvas_item;
render_mode unshaded,blend_disabled;
vec4 sourceSample(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}

varying vec2 vUv;
float ign(vec2 p){ return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

uniform sampler2D tPrev:filter_linear,repeat_disable; uniform sampler2D tLum:filter_linear,repeat_disable; uniform sampler2D tDepth:filter_nearest,repeat_disable; uniform sampler2D tWeaponSolarDepth:filter_nearest,repeat_disable; uniform bool uUseWeaponDepth=false; uniform vec2 uSunUv; uniform float uSunOn; uniform float uRate; uniform float uVisRate; uniform float uAspect;
vec4 source_lum(vec2 uv){
 ivec2 size=textureSize(tLum,0);vec2 p=vec2(uv.x,1.0-uv.y)*vec2(size)-0.5;
 ivec2 a=ivec2(floor(p));vec2 f=fract(p);ivec2 hi=size-ivec2(1);
 return mix(mix(texelFetch(tLum,clamp(a,ivec2(0),hi),0),texelFetch(tLum,clamp(a+ivec2(1,0),ivec2(0),hi),0),f.x),mix(texelFetch(tLum,clamp(a+ivec2(0,1),ivec2(0),hi),0),texelFetch(tLum,clamp(a+ivec2(1),ivec2(0),hi),0),f.x),f.y);
}
float source_half_rne(float value){
 if(value<0.00006103515625){float scaled=value*16777216.0;float base=floor(scaled);float f=fract(scaled);return (base+((f>0.5 || (f==0.5 && mod(base,2.0)>0.0))?1.0:0.0))/16777216.0;}
 uint bits=floatBitsToUint(value);return uintBitsToFloat((bits+4095u+((bits>>13u)&1u))&4294959104u);
}
void fragment(){
  float ls = 0.0, ws = 0.0;
  for (int y = 0; y < 5; y++) for (int x = 0; x < 7; x++) {
    vec2 uv = (vec2(float(x), float(y)) + 0.5) / vec2(7.0, 5.0);
    vec2 c = uv - 0.5;
    float w = 1.0 - 0.75 * smoothstep(0.1, 0.55, length(c));       // centre-weighted metering
    float l = luma(source_lum(uv).rgb);
    ls += log(max(l, 1e-4)) * w; ws += w;
  }
  float avg = clamp(exp(ls / ws), 0.002, 40.0);
  float vis = 0.0;
  for (int i = 0; i < 12; i++) {
    float r = sqrt((float(i) + 0.5) / 12.0) * 0.011; float th = float(i) * 2.39996323;
    vec2 uv = uSunUv + vec2(cos(th) / uAspect, sin(th)) * r;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) vis += 1.0;
    else vis += step(0.99999,min(texture(tDepth,vec2(uv.x,1.0-uv.y)).r,uUseWeaponDepth?texture(tWeaponSolarDepth,vec2(uv.x,1.0-uv.y)).r:1.0));
  }
  vis = vis / 12.0 * uSunOn;
  vec4 prev = sourceSample(tPrev, vec2(0.5));
  float a = mix(prev.r, avg, uRate);
  if (!(a > 0.0) || a > 1e4) a = avg;                                 // NaN / first-frame guard
  float v = mix(prev.g, vis, uVisRate);
  if (!(v >= 0.0)) v = vis;
  COLOR = vec4(source_half_rne(a), source_half_rne(v), 0.0, 1.0);
}
void vertex(){vUv=vec2(UV.x,1.0-UV.y); }
