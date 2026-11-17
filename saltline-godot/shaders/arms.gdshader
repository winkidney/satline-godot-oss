shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/source_raster_coords.gdshaderinc"
#include "res://shaders/source_sun_surface.gdshaderinc"
#include "res://shaders/source_ibl_surface.gdshaderinc"
#include "res://shaders/source_direct_surface.gdshaderinc"
// Exact source armSurface, armMicro and armBump equations.
uniform float uArmWet; varying vec4 vArmRest; varying vec4 vArmHand; varying vec3 vArmN;

float aBand(float x, float a, float b, float w) { return smoothstep(a - w, a, x) * (1.0 - smoothstep(b, b + w, x)); }
float aHash(vec3 p) { p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float aNoise(vec3 x) { vec3 i = floor(x), q = fract(x); q = q * q * (3.0 - 2.0 * q);
  return mix(mix(mix(aHash(i), aHash(i + vec3(1, 0, 0)), q.x), mix(aHash(i + vec3(0, 1, 0)), aHash(i + vec3(1, 1, 0)), q.x), q.y),
             mix(mix(aHash(i + vec3(0, 0, 1)), aHash(i + vec3(1, 0, 1)), q.x), mix(aHash(i + vec3(0, 1, 1)), aHash(i + vec3(1, 1, 1)), q.x), q.y), q.z); }
// hc = (A, F, D, S), rs = rest position + zone. Returns albedo; rough, h (metres), kind as in surfaceJS.
vec3 armSurface(vec4 hc, vec4 rs, float gD, out float rough, out float h, out float kind) {
  float A = hc.x, F = hc.y, D = hc.z, S = hc.w, x = rs.x, y = rs.y, z = rs.z; vec3 col; h = 0.0;
  if (rs.w > 0.5) {
    float ang = atan(D, S);
    col = vec3(0.046, 0.068, 0.106); rough = 0.50; kind = 4.0;
    col *= 0.80 + 0.26 * smoothstep(-0.9, 0.6, F);
    float bandM = aBand(A, 0.128, 0.172, 0.0012), refl = aBand(A, 0.1445, 0.1555, 0.0008);
    col = mix(col, vec3(0.5, 0.145, 0.028), bandM); col = mix(col, vec3(0.42, 0.42, 0.4), refl); rough = mix(rough, 0.62, bandM); rough = mix(rough, 0.30, refl); kind = mix(kind, 5.0, refl);
    h += 0.00035 * bandM + 0.00015 * refl;
    float edge = aBand(A, 0.1268, 0.1292, 0.0006) + aBand(A, 0.1708, 0.1732, 0.0006);
    col = mix(col, vec3(0.5, 0.44, 0.3), 0.55 * edge * step(fract(ang * 9.5), 0.62));
    float hem = 1.0 - smoothstep(0.0655, 0.0675, A), rib = 0.5 + 0.5 * cos(ang * 44.0);
    col = mix(col, vec3(0.028, 0.04, 0.062), hem); col *= mix(1.0, 0.62 + 0.5 * rib, hem); h += 0.0007 * rib * hem; rough = mix(rough, 0.82, hem); kind = mix(kind, 3.0, hem);
    float sa = atan(sin(ang + 1.9), cos(ang + 1.9)) / 0.045, seam = exp(-sa * sa) * (1.0 - hem);
    rough = mix(rough, 0.34, seam * 0.8); col *= 1.0 - 0.25 * seam;
  } else {
    float j1 = (F < 0.5 ? 0.044 : F < 1.5 ? 0.0405 : F < 2.5 ? 0.044 : F < 3.5 ? 0.0412 : 0.0325), j2 = (F < 0.5 ? 0.077 : F < 1.5 ? 0.064 : F < 2.5 ? 0.0702 : F < 3.5 ? 0.0657 : 0.0513), j3 = (F < 0.5 ? 0.106 : F < 1.5 ? 0.086 : F < 2.5 ? 0.094 : F < 3.5 ? 0.088 : 0.0713);
    float u = A < j1 ? A / j1 : A < j2 ? 1.0 + (A - j1) / (j2 - j1) : 2.0 + (A - j2) / (j3 - j2);
    float thumb = 1.0 - smoothstep(0.35, 0.65, F), digit = smoothstep(0.003, 0.010, A), cuff = smoothstep(0.0045, 0.0060, z);
    float sw = 0.025 + 0.31 * digit * mix(1.0, smoothstep(0.9, 1.15, u), thumb);
    float back = smoothstep(sw - 0.035, sw + 0.035, D), palmar = 1.0 - smoothstep(-sw - 0.035, -sw + 0.035, D), side = 1.0 - back - palmar;
    float r = length(rs.xyz);
    col = vec3(0.15, 0.156, 0.094); rough = 0.92; kind = 0.0;
    col = mix(col, vec3(0.066, 0.071, 0.05), side); rough = mix(rough, 0.95, side);
    col = mix(col, vec3(0.33, 0.245, 0.14), palmar); rough = mix(rough, 0.66, palmar); kind = mix(kind, 1.0, palmar);
    float cap = smoothstep(2.40, 2.46, u) * (1.0 - palmar);
    col = mix(col, vec3(0.33, 0.245, 0.14), cap); rough = mix(rough, 0.66, cap); kind = mix(kind, 1.0, cap);
    float ex = (x - 0.0165) / 0.02, ez = (z - -0.037) / 0.028, he = sqrt(ex * ex + ez * ez), heelOn = palmar * (1.0 - digit);
    float heel = (1.0 - smoothstep(0.94, 1.0, he)) * heelOn;
    vec3 wv = rs.xyz - vec3(-0.0441353, -0.0181279, -0.0549348), sdv = vec3(0.010842, 0.00935037, -0.0109097); float wt = clamp(dot(wv, sdv) / 0.000324, 0.0, 1.0);
    float sdist = length(wv - sdv * wt), saddle = (1.0 - smoothstep(0.0158, 0.0168, sdist)) * (1.0 - smoothstep(0.30, 0.50, D));
    float reinf = max(heel, saddle) * (1.0 - cuff);
    col = mix(col, vec3(0.235, 0.172, 0.1), reinf); rough = mix(rough, 0.76, reinf); h += 0.0005 * reinf; kind = mix(kind, 1.0, reinf);
    float prow = max(aBand(he, 0.86, 0.89, 0.012) * heelOn, aBand(sdist, 0.0138, 0.0144, 0.0003) * (1.0 - smoothstep(-0.25, -0.05, D))) * (1.0 - cuff);
    float ge = 9.0, gE; vec3 gv; vec2 gl = vec2(0.0), gL;
    gv = rs.xyz - vec3(-0.0335, 0.0115, -0.093); gL = vec2(gv.x * 0.997551 - gv.z * 0.0699428, gv.x * 0.0699428 + gv.z * 0.997551); gE = length(vec3(gL.x * 81.9672, gv.y * 129.87, gL.y * 71.4286)); if (gE < ge) { ge = gE; gl = gL; }
    gv = rs.xyz - vec3(-0.011, 0.0135, -0.098); gL = vec2(gv.x * 0.99995 - gv.z * 0.00999983, gv.x * 0.00999983 + gv.z * 0.99995); gE = length(vec3(gL.x * 81.9672, gv.y * 129.87, gL.y * 71.4286)); if (gE < ge) { ge = gE; gl = gL; }
    gv = rs.xyz - vec3(0.0105, 0.012, -0.0935); gL = vec2(gv.x * 0.998201 - gv.z * -0.059964, gv.x * -0.059964 + gv.z * 0.998201); gE = length(vec3(gL.x * 81.9672, gv.y * 129.87, gL.y * 71.4286)); if (gE < ge) { ge = gE; gl = gL; }
    gv = rs.xyz - vec3(0.0305, 0.0085, -0.0845); gL = vec2(gv.x * 0.990216 - gv.z * -0.139543, gv.x * -0.139543 + gv.z * 0.990216); gE = length(vec3(gL.x * 92.115, gv.y * 129.87, gL.y * 80.3859)); if (gE < ge) { ge = gE; gl = gL; }
    float gs = 9.0; vec2 gp, gb;
    gp = rs.xz - vec2(-0.0335, -0.0885); gb = vec2(0.0225, -0.005); gs = min(gs, length(gp - gb * clamp(dot(gp, gb) / dot(gb, gb), 0.0, 1.0)));
    gp = rs.xz - vec2(-0.011, -0.0935); gb = vec2(0.0215, 0.0045); gs = min(gs, length(gp - gb * clamp(dot(gp, gb) / dot(gb, gb), 0.0, 1.0)));
    gp = rs.xz - vec2(0.0105, -0.089); gb = vec2(0.02, 0.009); gs = min(gs, length(gp - gb * clamp(dot(gp, gb) / dot(gb, gb), 0.0, 1.0)));
    float lobe = clamp(1.15 - ge, 0.0, 1.0), guard = max(1.0 - smoothstep(0.94, 1.0, ge), (1.0 - smoothstep(0.0066, 0.0074, gs)) * smoothstep(0.004, 0.006, y - 0.0025)) * smoothstep(0.15, 0.35, D);
    float top = smoothstep(0.835, 0.875, D), fs = fract(u);
    float ribs = aBand(fs, 0.24, 0.80, 0.02) * (1.0 - 0.85 * (aBand(fs, 0.405, 0.435, 0.008) + aBand(fs, 0.605, 0.635, 0.008)));
    float bars = top * ribs * (u < 2.0 ? 1.0 : 0.0) * (u < 1.0 ? 1.0 - thumb : 1.0) * digit;
    float rz = (-0.047 + 0.22 * x - z) / 0.0085, ri = clamp(floor(rz + 0.5), 0.0, 2.0);
    float plate = aBand((rz - ri) * 0.0085, -0.0016, 0.0016, 0.0006) * aBand(x, -0.0175 + 0.004 * ri, 0.0200 - 0.002 * ri, 0.0012) * smoothstep(0.62, 0.70, D) * (1.0 - digit);
    float rub = max(guard, max(bars, plate));
    col = mix(col, vec3(0.06, 0.062, 0.068), rub); rough = mix(rough, 0.46, rub); kind = mix(kind, 2.0, rub);
    float rim = aBand(ge, 0.80, 0.87, 0.02) * guard;
    float slot = (aBand(gl.y, -0.0052, -0.0036, 0.0004) + aBand(gl.y, 0.0012, 0.0028, 0.0004)) * aBand(gl.x, -0.0052, 0.0052, 0.0006) * (1.0 - smoothstep(0.70, 0.80, ge)) * guard;
    h += 0.0011 * bars + 0.0010 * plate + 0.0006 * guard * (0.4 + 0.6 * lobe) - 0.00035 * rim - 0.0006 * slot;
    col *= (1.0 + 0.5 * guard * lobe * lobe) * (1.0 - 0.3 * rim) * (1.0 - 0.55 * slot);
    float dash = step(fract(r / 0.0024), 0.60), free = (1.0 - rub) * (1.0 - cuff) * (1.0 - saddle);
    float gd = clamp(gD, 25.0, 700.0), sA = abs(D - sw) / gd, sB = abs(D + sw) / gd, sd = min(sA, sB), groove = (1.0 - smoothstep(0.0, 0.0006, sd)) * free;
    float row = aBand(sd, 0.0010, 0.0016, 0.00025) * free * (sA < sB ? step(sw, D) : step(D, -sw));
    float cs = abs(u - 2.43) * (j3 - j2), capSeam = (1.0 - smoothstep(0.0, 0.0006, cs)) * (1.0 - palmar);
    float capRow = aBand(cs, 0.0010, 0.0016, 0.00025) * (1.0 - palmar) * step(fract(S * 5.5 + D * 2.0), 0.6);
    float gr = max(groove, capSeam); h -= 0.00045 * gr; col *= 1.0 - 0.45 * gr;
    float st = max(row * dash, max(capRow, prow * 0.55)); col = mix(col, vec3(0.5, 0.44, 0.3), 0.85 * st); h += 0.00022 * st;
    float c1 = (A - j1) / 0.0013, c2 = (A - j2) / 0.0013, c0 = (A - 0.0135) / 0.0014;
    float cre = (exp(-c1 * c1) + exp(-c2 * c2)) * digit, root = exp(-c0 * c0) * (1.0 - thumb) * palmar;
    h -= 0.0006 * (cre * palmar + root) + 0.00025 * cre * back * (1.0 - rub); col *= 1.0 - 0.35 * (cre * palmar + root);
    float ang = atan(y, x), rib = 0.5 + 0.5 * cos(ang * 46.0);
    col = mix(col, vec3(0.062, 0.066, 0.056), cuff); col *= mix(1.0, 0.70 + 0.45 * rib, cuff); h = mix(h, 0.0005 * rib, cuff); rough = mix(rough, 0.88, cuff); kind = mix(kind, 3.0, cuff);
    float strap = aBand(z, 0.0165, 0.0345, 0.0005) * smoothstep(-0.55, -0.45, D) * cuff;
    col = mix(col, vec3(0.036, 0.038, 0.04), strap); h = mix(h, 0.0012, strap); rough = mix(rough, 0.80, strap); kind = mix(kind, 0.0, strap);
    float tabE = strap * aBand(x, 0.0080, 0.0280, 0.0008) * smoothstep(0.2, 0.3, D); col = mix(col, vec3(0.06, 0.062, 0.068), tabE); h += 0.0009 * tabE; rough = mix(rough, 0.45, tabE); kind = mix(kind, 2.0, tabE);
    float srow = strap * (1.0 - tabE) * (aBand(z, 0.0176, 0.0186, 0.0003) + aBand(z, 0.0324, 0.0334, 0.0003)) * step(fract(ang * 14.0), 0.6); col = mix(col, vec3(0.5, 0.44, 0.3), 0.8 * srow);
    float tab = aBand(z, 0.0078, 0.0140, 0.0003) * aBand(x, -0.0225, -0.0090, 0.0005) * smoothstep(0.3, 0.4, D); col = mix(col, vec3(0.56, 0.15, 0.03), tab); h += 0.0006 * tab; rough = mix(rough, 0.7, tab); kind = mix(kind, 0.0, tab);
    col *= 1.0 - 0.4 * aBand(z, 0.0040, 0.0064, 0.0006);
  }
  return col;
}
// sub-millimetre detail by kind: weave (0), pebbled grain (1), moulded rubber (2), knit rib (3), waxed ripstop + beads (4), glass bead tape (5)
vec3 armMicro(vec3 col, vec4 hc, vec4 rs, vec3 rn, float kind, float wet, inout float rough, inout float h) {
  vec3 p = rs.xyz, an = abs(rn); an = an * an; an /= an.x + an.y + an.z + 1e-5;
  float px = max(length(dFdx(p)), length(dFdy(p))), fine = 1.0 - smoothstep(0.00018, 0.00050, px);      // fade detail the pixels cannot hold
  float wf = 5712.0, weave = (sin(p.y * wf) * sin(p.z * wf)) * an.x + (sin(p.x * wf) * sin(p.z * wf)) * an.y + (sin(p.x * wf) * sin(p.y * wf)) * an.z;
  float n1 = aNoise(p * 950.0), n2 = aNoise(p * 2300.0 + 7.3), big = aNoise(p * 90.0 + 3.1);
  float kFab = 1.0 - min(1.0, abs(kind - 0.0)), kLea = 1.0 - min(1.0, abs(kind - 1.0)), kRub = 1.0 - min(1.0, abs(kind - 2.0)), kRib = 1.0 - min(1.0, abs(kind - 3.0)), kShell = 1.0 - min(1.0, abs(kind - 4.0)), kRefl = 1.0 - min(1.0, abs(kind - 5.0));
  h += fine * (kFab * 0.00005 * weave + kLea * 0.00011 * (n1 * 0.7 + n2 * 0.3 - 0.5) + kRub * 0.00003 * (n2 - 0.5) + kRib * 0.00006 * weave + kShell * 0.000035 * weave + kRefl * 0.00004 * (n2 - 0.5));
  col *= 1.0 + fine * (kFab * 0.06 * weave + kLea * 0.16 * (n1 - 0.5) + kRib * 0.08 * weave + kShell * 0.04 * weave) + (big - 0.5) * (0.16 * kLea + 0.10 * kFab + 0.10 * kShell + 0.06 * kRub);
  rough += (big - 0.5) * (0.10 * kLea + 0.10 * kShell + 0.12 * kRub) + fine * (n1 - 0.5) * 0.10 * kLea;
  // rain beads on the shell (laid out in the sleeve's own angle / length coordinates) and, sparser, on the rubber
  if (wet > 0.01 && (kShell + kRefl + kRub) > 0.3) {
    vec2 q = rs.w > 0.5 ? vec2(atan(hc.z, hc.w) * 0.046, hc.x) : vec2(dot(p, vec3(0.8, 0.0, 0.6)), dot(p, vec3(-0.42, 0.7, 0.57)));
    float bead = 0.0, wetR = 0.0;
    for (int o = 0; o < 2; o++) {
      float cell = o == 0 ? 0.0085 : 0.0041; vec2 g = q / cell + float(o) * 13.7, id = floor(g), fr = fract(g);
      float r1 = aHash(vec3(id, 1.0 + float(o))), r2 = aHash(vec3(id, 5.0)), r3 = aHash(vec3(id, 9.0));
      float rad = (o == 0 ? 0.0019 : 0.0010) * (0.55 + 0.6 * r3), on = step(r1, (o == 0 ? 0.42 : 0.5) * wet * (rs.w > 0.5 ? 1.0 : 0.5));
      float d = length((fr - (0.25 + 0.5 * vec2(r2, r3))) * cell) / rad;
      bead = max(bead, on * sqrt(max(0.0, 1.0 - d * d)) * rad * 0.55); wetR = max(wetR, on * (1.0 - smoothstep(0.85, 1.0, d)));
    }
    h += bead; rough = mix(rough, 0.07, wetR); col *= 1.0 - 0.18 * wetR;
  }
  rough = clamp(rough, 0.05, 1.0);
  return col;
}
vec3 armBump(vec3 N, vec3 vp, float h) {
  vec3 dpx = dFdx(vp), dpy = dFdy(vp), r1 = cross(dpy, N), r2 = cross(N, dpx);
  float det = dot(dpx, r1); vec3 g = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
  return normalize(abs(det) * N - g);
}


varying vec3 v_view_pos;
void vertex(){vArmRest=CUSTOM1;vArmHand=CUSTOM2;vArmN=CUSTOM0.xyz;v_view_pos=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;source_sun_shadow_coord=source_sun_shadow_matrix*vec4((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+normalize(MODEL_NORMAL_MATRIX*NORMAL)*.02,1.0);}
void fragment(){
 vec3 source_non_perturbed=normalize(NORMAL);
  vec3 armPx = dFdx(v_view_pos), armPy = dFdy(v_view_pos), armNg = normalize(cross(armPx, armPy)), armR1 = cross(armPy, armNg), armR2 = cross(armNg, armPx);
  float armGD = length(dFdx(vArmHand.z) * armR1 + dFdy(vArmHand.z) * armR2) / max(abs(dot(armPx, armR1)), 1e-12);
  float armRough, armH, armKind; vec3 armCol = armSurface(vArmHand, vArmRest, armGD, armRough, armH, armKind);
  armCol = armMicro(armCol, vArmHand, vArmRest, normalize(vArmN), armKind, uArmWet, armRough, armH);

 ALBEDO=armCol;ROUGHNESS=armRough;METALLIC=0.0;NORMAL=armBump(normalize(NORMAL),v_view_pos,armH);
 if((source_sun_active&&source_sun_ready)||(source_local_active&&source_local_ready))EMISSION+=sourceDirectRadiance(ALBEDO,0.0,armRough,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),(VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz,sourceRasterPixel(FRAGCOORD.xy,VIEWPORT_SIZE,SOURCE_RASTER_Y_UP),VERTEX,VIEW_MATRIX,sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS));

 if(source_ibl_ready){IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);if(source_ibl_radiance_enabled)EMISSION+=sourceIblRadiance(ALBEDO,0.0,armRough,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),INV_VIEW_MATRIX,1.0);}
}
