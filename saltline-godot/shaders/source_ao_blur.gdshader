shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform vec2 uResolution;
vec4 sourceSample(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}

varying vec2 vUv;
float ign(vec2 p){ return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

uniform sampler2D tSrc:filter_nearest,repeat_disable; uniform sampler2D tDepthHalf:filter_nearest,repeat_disable; uniform vec2 uDir;
void fragment(){
  float z0 = sourceSample(tDepthHalf, vUv).r;
  float zc = min(z0, 300.0);
  vec4 acc = vec4(0.0); float ws = 0.0;
  for (int i = -3; i <= 3; i++) {
    vec2 uv = vUv + uDir * float(i);
    float z = min(sourceSample(tDepthHalf, uv).r, 300.0);
    float w = (1.0 - abs(float(i)) * 0.22) * max(0.0, 1.0 - abs(z - zc) / (0.04 * zc + 0.02));
    acc += sourceSample(tSrc, uv) * w; ws += w;
  }
  COLOR = ws > 1e-4 ? acc / ws : sourceSample(tSrc, vUv);
}
void vertex(){vUv=vec2(UV.x,1.0-UV.y); }
