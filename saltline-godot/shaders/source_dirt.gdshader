shader_type canvas_item;
render_mode unshaded,blend_disabled;

varying vec2 vUv;
float ign(vec2 p){ return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }


uniform sampler2D tNoise:filter_linear,repeat_disable;
float n2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);ivec2 a=ivec2(mod(i,vec2(256.0)));ivec2 b=ivec2((a.x+1)%256,a.y),c=ivec2(a.x,(a.y+1)%256),d=ivec2(b.x,c.y);return mix(mix(texelFetch(tNoise,a,0).r,texelFetch(tNoise,b,0).r,f.x),mix(texelFetch(tNoise,c,0).r,texelFetch(tNoise,d,0).r,f.x),f.y);}
float fbm5(vec2 p){ float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++){ s += a * n2(p); p = mat2(vec2(1.6,1.2),vec2(-1.2,1.6)) * p + 17.3; a *= 0.5; } return s / 0.96875; }
float fbm3(vec2 p){ float a = 0.5, s = 0.0; for (int i = 0; i < 3; i++){ s += a * n2(p); p = mat2(vec2(1.6,1.2),vec2(-1.2,1.6)) * p + 17.3; a *= 0.5; } return s / 0.875; }

uniform float uAspect;
void fragment(){
  vec2 p = vUv * vec2(uAspect, 1.0);
  float acc = 0.0;
  for (int i = 0; i < 70; i++) {
    float fi = float(i);
    vec2 c = vec2(hash12(vec2(fi, 1.7)), hash12(vec2(fi, 9.2))) * vec2(uAspect, 1.0);
    float sz = mix(0.012, 0.085, pow(hash12(vec2(fi, 4.4)), 3.0));
    float r = length(p - c) / sz;
    float disc = smoothstep(1.0, 0.86, r) * (0.35 + 0.65 * smoothstep(0.35, 0.98, r));
    acc += disc * mix(0.15, 0.7, hash12(vec2(fi, 6.1)));
  }
  float smudge = fbm5(vUv * vec2(5.0, 9.0) + 3.0) * fbm3(vUv * 2.3 + 9.0);
  float streaks = pow(n2(vec2(vUv.x * 90.0, vUv.y * 2.0)), 4.0) * 0.25;
  float v = acc * 0.55 + smudge * 0.9 + streaks;
  v *= 0.45 + 0.9 * smoothstep(0.15, 0.75, length(vUv - 0.5));
  COLOR = vec4(vec3(v) * vec3(1.0, 0.96, 0.9), 1.0);
}
void vertex(){vUv=vec2(UV.x,1.0-UV.y); }
