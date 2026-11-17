shader_type spatial;
render_mode cull_disabled,specular_occlusion_disabled;
#include "res://shaders/source_raster_coords.gdshaderinc"
#include "res://shaders/source_sun_surface.gdshaderinc"
#include "res://shaders/source_ibl_surface.gdshaderinc"
#include "res://shaders/source_direct_surface.gdshaderinc"
// Source apron equations. Planar radiance replacement is integrated separately.

vec4 sourceSample(sampler2D t,vec2 uv){return texture(t,vec2(uv.x,1.0-uv.y));}
vec4 sourceLod(sampler2D t,vec2 uv,float lod){vec2 edge=0.5/vec2(textureSize(t,0));uv=clamp(uv,edge,vec2(1.0)-edge);return textureLod(t,vec2(uv.x,1.0-uv.y),lod);}


uniform float uTime;
uniform float uRain;
uniform float uWetG;
uniform float uReflOn;
uniform float uReflLod;
uniform float uMarkRes;
uniform float uMaskRes;
uniform sampler2D uMask:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uMarks:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uDetail:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uDetailN:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uRefl:filter_linear_mipmap,repeat_disable;
uniform vec3 uMaskRect; uniform vec4 uMarkRect; uniform mat4 uReflMatrix; uniform vec2 uReflScale;
varying vec3 vGWorld;

vec3 gHash3(vec2 p){ vec3 q = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973)); q += dot(q, q.yzx + 33.33); return fract((q.xxy + q.yzz) * q.zyx); }
float gH1(vec2 p){ vec3 q = fract(vec3(p.xyx) * .1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float gVN(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(gH1(i), gH1(i + vec2(1.0, 0.0)), f.x), mix(gH1(i + vec2(0.0, 1.0)), gH1(i + vec2(1.0, 1.0)), f.x), f.y); }
// 4-tap B-spline bicubic of the base level: no texel edge of a data map can ever show, however close the camera is
vec4 gBicubic(sampler2D t, vec2 uv, float res){
  vec2 p = uv * res - 0.5; vec2 i = floor(p); vec2 f = p - i; vec2 f2 = f * f, f3 = f2 * f;
  vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0, w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
  vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0, w3 = f3 / 6.0;
  vec2 g0 = w0 + w1, g1 = w2 + w3;
  vec2 h0 = (i + w1 / g0 - 0.5) / res, h1 = (i + w3 / g1 + 1.5) / res;
  return (sourceLod(t, vec2(h0.x, h0.y), 0.0) * g0.x + sourceLod(t, vec2(h1.x, h0.y), 0.0) * g1.x) * g0.y
       + (sourceLod(t, vec2(h0.x, h1.y), 0.0) * g0.x + sourceLod(t, vec2(h1.x, h1.y), 0.0) * g1.x) * g1.y;
}
// one sparse layer of rain rings: every cell gets a new drop (position, size, strength) each cycle, thin soft crest
// that fades as it expands. Returns a slope (xz) contribution.
vec2 gRipple(vec2 p, float t, float cell, float seed){
  vec2 q = p / cell + seed * 17.3; vec2 id = floor(q); vec2 f = fract(q);
  vec3 h0 = gHash3(id + seed);
  float tt = t * (0.5 + 0.55 * h0.x) + h0.y * 9.0;
  float cyc = floor(tt), life = fract(tt);
  vec3 h = gHash3(id + seed + cyc * 7.31);
  vec3 hc = gHash3(id.yx + cyc * 3.71 + seed * 5.0);
  float on = step(h.z, 0.16 + 0.5 * uRain);
  float rmax = mix(0.1, 0.36, h.x * h.x);
  vec2 c = mix(vec2(rmax + 0.05), vec2(0.95 - rmax), hc.xy);
  vec2 dv = (f - c) * cell; float d = length(dv);
  float r = life * rmax * cell;
  float w = 0.005 + 0.02 * life;
  float x = (d - r) / w;
  float ring = x * exp(-x * x) * 2.3;
  float amp = 1.0 - life; amp = amp * amp * on * mix(0.3, 1.0, h.y) * smoothstep(0.0, 0.06, life);
  return (dv / max(d, 1e-4)) * ring * amp;
}


vec4 sourceReflectionLod(sampler2D t,vec2 uv,float lod){return textureLod(t,vec2(uv.x,1.0-uv.y),lod);}

void vertex(){vGWorld=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;source_sun_shadow_coord=source_sun_shadow_matrix*vec4(vGWorld+normalize(MODEL_NORMAL_MATRIX*NORMAL)*.02,1.0);}
void fragment(){
 vec3 source_non_perturbed=normalize(NORMAL);
 float gRough=1.0;vec2 gNxz=vec2(0.0);float gPuddle=0.0,gWet=0.0,gFilm=0.0,gSoak=0.0;
 vec4 diffuseColor=vec4(1.0);
{
  vec2 gxz = vGWorld.xz;
  float gDist = length(CAMERA_POSITION_WORLD - vGWorld);
  // ---- unique large-scale masks (puddle height, dampness, oil, wear) ----
  vec2 muv = (gxz - uMaskRect.xy) * uMaskRect.z;
  float mIn = smoothstep(0.0, 0.05, min(min(muv.x, 1.0 - muv.x), min(muv.y, 1.0 - muv.y)));
  vec4 mk = mix(vec4(0.66, 0.5, 0.0, 0.5), gBicubic(uMask, muv, uMaskRes), mIn);
  // ---- tiling detail ----
  vec4 d1 = sourceSample(uDetail, gxz * 0.21);
  vec4 d2 = sourceSample(uDetail, gxz * 1.37 + 0.37);
  vec4 n1 = sourceSample(uDetailN, gxz * 1.37 + 0.37);
  vec4 n0 = sourceSample(uDetailN, gxz * 0.21);
  float grain = d2.r;
  // ---- slabs: 6 m expansion joints with tar sealing ----
  vec2 sj = gxz / 6.0;
  vec2 sf = (0.5 - abs(fract(sj) - 0.5)) * 6.0;
  float jd = min(sf.x, sf.y) + (d1.a - 0.5) * 0.035;
  float jaa = fwidth(jd) + 1e-5;
  float tarW = 0.022 + 0.03 * d1.g;
  float tar = (1.0 - smoothstep(tarW - jaa, tarW + jaa, jd)) * clamp(tarW / jaa, 0.0, 1.0);
  float groove = (1.0 - smoothstep(0.004, 0.012 + jaa, jd)) * clamp(0.02 / jaa, 0.0, 1.0);
  vec2 sid = floor(sj);
  float sh = fract(sin(dot(sid, vec2(127.1, 311.7))) * 43758.5453);
  float sh2 = fract(sh * 7.31 + 0.13);
  // ---- cracks, some sealed with tar ----
  float crArea = smoothstep(0.6, 0.76, mk.a * 0.7 + sh * 0.45);
  float cfw = fwidth(d1.b) * 1.5 + 0.004;
  float crack = smoothstep(0.955 - cfw, 0.975, d1.b) * crArea;
  float seal = smoothstep(0.915 - cfw, 0.94, d1.b) * crArea * step(0.72, sh2);
  // ---- base albedo: worn asphalt in the yard, concrete slabs on the quay ----
  float conc = smoothstep(15.6, 16.6, gxz.x + (d1.g - 0.5) * 0.6);
  vec3 alb = mix(vec3(0.125, 0.125, 0.13), vec3(0.22, 0.215, 0.2), conc);
  alb *= (0.8 + 0.4 * sh2) * (0.8 + 0.4 * d1.g) * (0.62 + 0.76 * grain);
  alb += vec3(0.11, 0.105, 0.095) * smoothstep(0.58, 0.78, d2.a) * (1.0 - conc * 0.6);    // pale aggregate
  float polish = smoothstep(0.38, 0.72, mk.a);                                            // traffic-polished lanes
  alb *= mix(1.0, 0.78, polish);
  alb = mix(alb, vec3(0.018, 0.018, 0.02), max(max(tar, seal * 0.4) * 0.94, crack * 0.9));
  alb *= 1.0 - 0.62 * mk.b;                                                               // oil
  // ---- painted markings (worn, chipped) + tyre rubber ----
  vec2 kuv = (gxz - uMarkRect.xy) * uMarkRect.zw;
  float kIn = step(0.0, kuv.x) * step(kuv.x, 1.0) * step(0.0, kuv.y) * step(kuv.y, 1.0);
  vec3 mp = sourceSample(uMarks, clamp(kuv, vec2(0.5/uMarkRes), vec2(1.0-0.5/uMarkRes))).rgb;
  float kpx = max(fwidth(kuv.x), fwidth(kuv.y)) * uMarkRes;
  if (kpx < 1.0) mp = mix(gBicubic(uMarks, kuv, uMarkRes).rgb, mp, smoothstep(0.5, 1.0, kpx));   // magnified: no texel blocks
  mp *= kIn;
  float kw = clamp(kpx * 0.5, 0.16, 0.5);
  // chips: world-space procedural noise down to sub-centimetre (never the texels of a map)
  float chipN = 0.5;
  if (max(mp.r, mp.g) > 0.02) {
    float cf2 = 1.0 - smoothstep(6.0, 18.0, gDist), cf3 = 1.0 - smoothstep(2.5, 7.0, gDist);
    chipN = gVN(gxz * 17.0) * 0.45 + mix(0.5, gVN(gxz * 57.0 + 11.0), cf2) * 0.33 + mix(0.5, gVN(gxz * 181.0 + 5.0), cf3) * 0.22;
  }
  float chip = chipN * 0.62 + d1.a * 0.38;
  float wear = clamp(mk.a * 1.25 - 0.22 + mp.b * 0.6, 0.0, 1.0);
  float wt = mix(0.24, 0.55, wear);
  float keep = smoothstep(wt - 0.045, wt + 0.045, chip) * (1.0 - max(tar, crack));
  float eN = (chipN - 0.5) * 0.55 * (1.0 - kw * 2.0);
  float pY = smoothstep(0.5 - kw, 0.5 + kw, mp.r + eN) * keep;
  float pW = smoothstep(0.5 - kw, 0.5 + kw, mp.g + eN) * keep;
  alb *= 1.0 - 0.6 * mp.b * (1.0 - 0.5 * conc);
  float fade = 0.72 + 0.28 * d1.g;
  alb = mix(alb, vec3(0.52, 0.34, 0.035) * fade, pY * 0.94);
  alb = mix(alb, vec3(0.47, 0.47, 0.44) * fade, pW * 0.94);
  float paint = max(pY, pW);
  // ---- water: one continuous gradient  standing water -> soaked band -> damp -> drier patches ----
  // organic shoreline: world-space noise (40 / 15 / 5 cm) on the water-level comparison, independent of the mask res
  float sf2 = 1.0 - smoothstep(25.0, 60.0, gDist), sf3 = 1.0 - smoothstep(8.0, 22.0, gDist);
  float sn1 = gVN(gxz * 2.5 + 3.0), sn2 = mix(0.5, gVN(gxz * 6.7 + 17.0), sf2), sn3 = mix(0.5, gVN(gxz * 20.0 + 9.0), sf3);
  float sn = sn1 * 0.5 + sn2 * 0.3 + sn3 * 0.2;
  float depth = 0.5 - mk.r + (sn - 0.5) * 0.11 + (d1.g - 0.5) * 0.03 + (grain - 0.5) * 0.012 + groove * 0.04 + crack * 0.02 - paint * 0.01;
  float puddle = smoothstep(0.0, 0.035, depth) * uWetG;                 // mirror weight (~5 cm ramp)
  float deep = smoothstep(0.0, 0.22, depth);                           // 0 at the rim (bed shows) .. 1 a hand deep
  float bandW = 0.05 + 0.15 * sn1 * sn1 + 0.05 * d1.g;                  // soaked band, roughly 10-30 cm, varies along the shore
  float soak = smoothstep(-bandW, 0.0, depth) * uWetG;
  float fringe = smoothstep(-0.65, -0.02, depth);                      // damp halo, about a metre
  float dryP = 1.0 - smoothstep(0.2, 0.42, mk.g + fringe * 0.55 + (d1.g - 0.5) * 0.25 + (sn - 0.5) * 0.12);
  float damp = (1.0 - dryP) * uWetG;
  float wet = clamp(damp * 0.7 + soak * 0.3, 0.0, 1.0);
  float film = clamp(soak * (1.0 - smoothstep(0.35, 0.95, grain + (1.0 - soak) * 0.6)) + groove * 0.5, 0.0, 1.0) * (1.0 - paint * 0.4);
  alb *= mix(0.95, mix(0.7, 0.54, 1.0 - paint), damp);
  alb *= mix(1.0, 0.5, soak);
  // standing water: shallow rim shows the wet bed, deeper water goes murky and dark (never a black cut-out)
  alb = mix(alb, alb * mix(0.85, 0.4, deep) + vec3(0.004, 0.006, 0.0065) * deep, puddle);
  diffuseColor.rgb *= alb;
  // ---- roughness: dry ~0.72 -> damp 0.36..0.56 -> soaked 0.1..0.2 -> water 0.055, all smooth ramps ----
  float rough = mix(0.74, 0.42, damp) + (grain - 0.5) * 0.24 + (d1.g - 0.5) * 0.16 + conc * 0.03 - paint * 0.05;
  rough -= polish * 0.07 + mk.b * 0.16 + max(tar, seal) * 0.1;
  rough = mix(rough, 0.2 + (grain - 0.5) * 0.14, soak * 0.9);
  rough = mix(rough, 0.13, film * 0.8);
  rough += smoothstep(10.0, 80.0, gDist) * 0.04;
  rough = mix(clamp(rough, 0.1, 1.0), 0.055, puddle);
  // ---- normal (world xz slope): aggregate grain + lumps break up the mirror outside puddles ----
  vec2 nxz = (n1.rg - 0.5) * mix(2.1, 0.7, max(film, soak * 0.6)) + (n0.ba - 0.5) * 0.3;
  nxz *= 1.0 - puddle;
  float wsum = puddle + film * 0.2;
  vec2 wv = sourceSample(uDetailN, gxz * 0.13 + uTime * vec2(0.031, 0.017)).ba - 0.5;
  vec2 wv2 = sourceSample(uDetailN, gxz.yx * 0.31 - uTime * vec2(0.043, 0.027)).ba - 0.5;
  if (wsum > 0.004) {
    float rf = 1.0 - smoothstep(10.0, 34.0, gDist);
    vec2 rip = vec2(0.0);
    if (rf > 0.0) {
      vec2 gp2 = vec2(0.8 * gxz.x - 0.6 * gxz.y, 0.6 * gxz.x + 0.8 * gxz.y);
      vec2 r2 = gRipple(gp2, uTime * 0.87, 1.31, 2.0);
      rip = gRipple(gxz, uTime, 0.83, 1.0) + vec2(0.8 * r2.x + 0.6 * r2.y, -0.6 * r2.x + 0.8 * r2.y) * 0.9 + gRipple(gxz.yx, uTime * 1.13, 0.57, 3.0).yx * 0.6;
      rip *= rf * (0.3 + 0.7 * uRain) * 0.3 * smoothstep(0.0, 0.08, depth);
    }
    nxz += (rip + (wv * 0.03 + wv2 * 0.018) * (0.4 + 0.6 * deep)) * wsum;
    rough += (1.0 - rf) * 0.03 * puddle * uRain;
  }
  gSoak = soak;
  gRough = rough; gNxz = nxz; gPuddle = puddle; gWet = wet; gFilm = film;
}
 ALBEDO=diffuseColor.rgb;ROUGHNESS=gRough;METALLIC=0.0;
 NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(vec3(-gNxz.x,1.0,-gNxz.y)));
 SPECULAR=mix(.5,.9375,max(gPuddle,gSoak*.5));
 if((source_sun_active&&source_sun_ready)||(source_local_active&&source_local_ready)){vec3 diffuse,specular;sourceDirectTerms(ALBEDO,0.0,gRough,max(gPuddle,gSoak*.5),normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),(VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz,sourceRasterPixel(FRAGCOORD.xy,VIEWPORT_SIZE,SOURCE_RASTER_Y_UP),VERTEX,VIEW_MATRIX,sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS),diffuse,specular);EMISSION+=diffuse+min(specular,vec3(40.0));}
 vec3 source_planar_rgb=vec3(0.0);float source_planar_weight=0.0;
 // SOURCE_PLANAR_RADIANCE_BEGIN
 if(uReflOn>0.0)
{
  vec3 gV = normalize(CAMERA_POSITION_WORLD - vGWorld);
  vec4 rc = uReflMatrix * vec4(vGWorld.x, 0.0, vGWorld.z, 1.0);
  vec2 ruv = rc.xy / max(rc.w, 1e-4);
  vec2 gf = normalize(-gV.xz + vec2(1e-5)); vec2 gs = vec2(-gf.y, gf.x);
  float sinE = clamp(gV.y, 0.03, 1.0);
  float dk = (gPuddle + gFilm * 0.15 + 0.03) / (1.0 + length(CAMERA_POSITION_WORLD - vGWorld) * 0.07);
  vec2 tilt = vec2(dot(gNxz, gs) * sinE, dot(gNxz, gf)) * dk;
  tilt = clamp(tilt, vec2(-0.12), vec2(0.12));
  ruv += tilt * uReflScale;
  float r = source_ibl_ready?sourceIblRoughness(gRough,source_non_perturbed):ROUGHNESS;
  // puddles: sharp mirror. Damp asphalt: only a heavily blurred, vertically stretched reflection that tightens a
  // little at grazing angles (so it reads as a sheen, not as a second mirror)
  float graz = pow(1.0 - clamp(gV.y, 0.0, 1.0), 5.0);
  float lodP = clamp(r * 9.5 - 0.45, 0.0, 6.5) + 0.9;      // puddles: a touch soft, never razor sharp
  float lodD = clamp(3.0 + r * 6.5 - 3.4 * graz, 2.0, 7.5);
  float lod = mix(mix(lodD, min(lodD, 2.6 + r * 5.0), gSoak), lodP, gPuddle) + uReflLod;
  vec2 st = vec2(0.0, r * 0.11 + (1.0 - gPuddle) * 0.05);
  vec2 lo = vec2(0.002), hi = vec2(0.998);
  vec3 pr = sourceReflectionLod(uRefl, clamp(ruv, lo, hi), lod).rgb * 0.5
          + sourceReflectionLod(uRefl, clamp(ruv + st, lo, hi), lod + 0.6).rgb * 0.25
          + sourceReflectionLod(uRefl, clamp(ruv - st * 0.6, lo, hi), lod + 0.6).rgb * 0.25;
  pr = min(pr, vec3(48.0));
  float pw = mix(1.0 - smoothstep(0.55, 0.9, r), 1.0, max(gPuddle, gSoak)) * uReflOn;
  source_planar_rgb=pr;source_planar_weight=pw;
}

 // SOURCE_PLANAR_RADIANCE_END
 if(source_ibl_ready){IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);if(source_ibl_radiance_enabled){vec3 diffuse,specular;sourceIblTerms(ALBEDO,0.0,gRough,max(gPuddle,gSoak*.5),normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),INV_VIEW_MATRIX,1.0,1.0,source_planar_rgb,source_planar_weight,diffuse,specular);EMISSION+=diffuse+specular;}}
 else RADIANCE=vec4(source_planar_rgb,source_planar_weight);

}
