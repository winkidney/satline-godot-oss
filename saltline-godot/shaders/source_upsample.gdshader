shader_type canvas_item;
render_mode unshaded,blend_disabled;
vec4 sourceSample(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}

varying vec2 vUv;
float ign(vec2 p){ return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

uniform sampler2D tLow:filter_linear,repeat_disable; uniform sampler2D tHigh:filter_linear,repeat_disable; uniform vec2 uTexel; uniform float uMix;
void fragment(){
  vec2 o = uTexel;
  vec3 t = sourceSample(tLow, vUv).rgb * 4.0;
  t += (sourceSample(tLow, vUv + vec2(o.x, 0.0)).rgb + sourceSample(tLow, vUv - vec2(o.x, 0.0)).rgb + sourceSample(tLow, vUv + vec2(0.0, o.y)).rgb + sourceSample(tLow, vUv - vec2(0.0, o.y)).rgb) * 2.0;
  t += sourceSample(tLow, vUv + o).rgb + sourceSample(tLow, vUv - o).rgb + sourceSample(tLow, vUv + vec2(o.x, -o.y)).rgb + sourceSample(tLow, vUv + vec2(-o.x, o.y)).rgb;
  t *= 1.0 / 16.0;
  COLOR = vec4(mix(sourceSample(tHigh, vUv).rgb, t, uMix), 1.0);
}
void vertex(){vUv=vec2(UV.x,1.0-UV.y); }
