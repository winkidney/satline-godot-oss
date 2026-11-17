// Diagnostic only: explicit source GL dot contraction order.
// Mechanically extracted by tools/extract_weapon_detail.py; runtime-zero hash rounding guard.
uniform uint source_weapon_noise_round_guard=0u;
float weaponRound(float x){return uintBitsToFloat(floatBitsToUint(x)+source_weapon_noise_round_guard);}
vec3 weaponRound3(vec3 x){return uintBitsToFloat(floatBitsToUint(x)+uvec3(source_weapon_noise_round_guard));}
vec2 weaponRound2(vec2 x){return uintBitsToFloat(floatBitsToUint(x)+uvec2(source_weapon_noise_round_guard));}
float dh3(vec3 p){p=weaponRound3(p);float angle=weaponRound(fma(p.z,74.7,fma(p.y,311.7,weaponRound(p.x*127.1))));return fract(weaponRound(weaponRound(sin(angle))*43758.5453));}
float dn3(vec3 p){ vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(dh3(i), dh3(i + vec3(1,0,0)), f.x), mix(dh3(i + vec3(0,1,0)), dh3(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(dh3(i + vec3(0,0,1)), dh3(i + vec3(1,0,1)), f.x), mix(dh3(i + vec3(0,1,1)), dh3(i + vec3(1,1,1)), f.x), f.y), f.z); }
vec2 dh2(vec2 p){p=weaponRound2(p);vec2 angles=weaponRound2(vec2(fma(p.y,311.7,weaponRound(p.x*127.1)),fma(p.y,183.3,weaponRound(p.x*269.5))));return fract(weaponRound2(weaponRound2(sin(angles))*43758.5453));}
vec2 dDrops(vec2 uv, float cell, float seed, float thr){ vec2 g = uv / cell, i = floor(g), f = fract(g); float best = 0.0;
  for (int a = -1; a <= 1; a++) for (int b = -1; b <= 1; b++) { vec2 o = vec2(float(a), float(b)); vec2 r = dh2(i + o + seed);
    float keep = step(thr, fract(r.x * 7.31 + r.y * 3.17)); vec2 c = o + 0.2 + 0.6 * r; float rad = (0.14 + 0.20 * fract(r.x * 13.7)) * keep;
    float d = length(f - c); best = max(best, sqrt(max(rad * rad - d * d, 0.0))); }
  return vec2(best * cell, step(1e-6, best)); }

void sourceWeaponSurface(int kind,vec3 vObjP,vec3 vONrm,vec3 vWNrm,vec4 vSurf,float pixel_width,float uRain,inout vec3 albedo,inout float roughness,inout float metalness,out float height,out float occlusion,out vec4 detail_debug){
vec3 dP = vObjP; vec3 dAn = abs(vONrm);
vec2 dUV = (dAn.y > dAn.x && dAn.y > dAn.z) ? dP.xz : (dAn.x > dAn.z ? dP.zy : dP.xy);
float dEdge = vSurf.x, dCav = vSurf.y, dBare = vSurf.z, dZone = vSurf.w;
float dPx = pixel_width;                                         // metres of surface per pixel
float dNear = 1.0 - smoothstep(0.00020, 0.00075, dPx);                  // micro detail fades out before it can alias
vec3 dQ = mat3(vec3(0.36,0.48,-0.80),vec3(-0.80,0.60,0.0),vec3(0.48,0.64,0.60)) * dP;       // turned domain: the noise lattice never lines up with the gun
float dLo = dn3(dQ * 34.0), dMid = dn3(dQ * 180.0 + 7.0);
float dGr = (dh3(floor(dP * 2900.0)) - 0.5) * dNear;                    // finest grain: one hash
float dScr = dn3(dP * vec3(640.0, 640.0, 21.0) + 3.0);                  // long fine scratches along the bore
float dHt = 0.0, dR = 0.0; vec3 dAlb = albedo;
float dBreak = dMid * 0.65 + dLo * 0.35;
float dPolish = smoothstep(0.15, 0.85, dEdge) * (0.35 + 0.65 * dLo);     // exposed edges are a little burnished, unevenly
float dWorn = smoothstep(0.60, 0.72, dBreak) * smoothstep(0.55, 0.95, dEdge);   // and worn through in a few patches (high-wear parts only)
float dScratch = smoothstep(0.80, 0.94, dScr) * (0.10 + 0.90 * dZone) * smoothstep(0.30, 0.62, dMid * 0.5 + dLo * 0.5) * (1.0 - smoothstep(0.0007, 0.0020, dPx));
if(kind==0){
  float smear = smoothstep(0.52, 0.82, dn3(dQ * vec3(52.0, 30.0, 15.0) + 11.0));      // palm and finger oil on the flats
  dR = (dLo - 0.5) * 0.14 + (dMid - 0.5) * 0.08 + dGr * 0.10 - smear * 0.12;
  dHt = dGr * 0.000012;
  dAlb *= (0.90 + 0.20 * dLo) * (1.0 - 0.10 * smear);
  dAlb = mix(dAlb, dAlb * 1.7 + 0.005, dPolish * 0.55); dR -= dPolish * 0.06;
  dAlb = mix(dAlb, vec3(0.30, 0.31, 0.33), dScratch * 0.55); dR -= dScratch * 0.10; dHt -= dScratch * 0.000012;
  metalness = mix(metalness, 1.0, max(dWorn, dScratch * 0.5));
  dAlb = mix(dAlb, vec3(0.50, 0.51, 0.53), dWorn); dR = mix(dR, -0.10 + 0.12 * dMid, dWorn);
}else if(kind==3){
  float lay = dn3(vec3(dP.xy * 2600.0, dP.z * 36.0));                                  // surface-ground lay along the bore
  float smear = smoothstep(0.50, 0.80, dn3(dQ * vec3(60.0, 34.0, 20.0) + 11.0));
  dR = (dLo - 0.5) * 0.10 + (lay - 0.5) * 0.14 * dNear + dGr * 0.04 - smear * 0.11;
  dHt = lay * 0.000007 * dNear;
  dAlb *= (0.92 + 0.16 * dLo) * (1.0 - 0.12 * smear);
  dAlb = mix(dAlb, dAlb * 1.9 + 0.006, dPolish * 0.6); dR -= dPolish * 0.06;
  dAlb = mix(dAlb, vec3(0.16, 0.16, 0.17), dScratch * 0.35); dR -= dScratch * 0.06;
  float through = dWorn * 0.8;                                                         // holster wear: grey steel, not silver
  metalness = mix(metalness, 1.0, through); dAlb = mix(dAlb, vec3(0.36, 0.36, 0.37), through); dR = mix(dR, -0.06, through);
}else if(kind==1){
  float oil = smoothstep(0.30, 0.72, dn3(dQ * vec3(46.0, 46.0, 30.0) + 5.0));
  float lay = dn3(vec3(dP.xy * 1400.0, dP.z * 60.0));
  // phosphate: crystalline, porous, drinks oil
  float cR = (dLo - 0.5) * 0.14 + dGr * 0.14 - oil * 0.20, cH = dGr * 0.000022 + dMid * 0.000004;
  vec3 cA = dAlb * mix(1.22, 0.72, oil) * (0.94 + 0.12 * dMid);
  cA = mix(cA, cA * 1.8 + 0.006, dPolish * 0.6); cR -= dPolish * 0.10;
  float cM = metalness; float through = max(dWorn, dScratch * 0.6);
  cM = mix(cM, 1.0, through); cA = mix(cA, vec3(0.40, 0.40, 0.41), through); cR = mix(cR, -0.26 + 0.10 * dMid, through);
  // bare: turned or ground steel, faint lay, a little staining
  float bR = -0.30 + (lay - 0.5) * 0.20 + (dLo - 0.5) * 0.14, bH = lay * 0.000008 * dNear;
  vec3 bA = min(dAlb, vec3(0.78)) * (0.86 + 0.20 * dMid); bA = mix(bA, bA * vec3(0.72, 0.62, 0.50), smoothstep(0.62, 0.9, dLo) * 0.35);
  dAlb = mix(cA, bA, dBare); dR = mix(cR, bR, dBare); dHt = mix(cH, bH, dBare); metalness = mix(cM, 1.0, dBare);
}else if(kind==4){
  // rubber and matte liners (the 'plain' group, absolute vertex albedo): fine moulded grain, chalky bloom, shiny where rubbed
  float bloom = smoothstep(0.45, 0.80, dMid * 0.6 + dLo * 0.4);
  dR = (dLo - 0.5) * 0.10 + dGr * 0.08 - dPolish * 0.22; dHt = dGr * 0.000018;
  dAlb = mix(dAlb, dAlb * 1.5 + 0.012, bloom * 0.35) * (1.0 + 0.35 * dPolish);
}else{
  float st = dn3(dP * 1500.0) * 0.6 + dh3(floor(dP * 3300.0)) * 0.4;                    // mould texture (VDI-ish spark finish)
  dR = (dLo - 0.5) * 0.14 + (st - 0.5) * 0.12 * dNear - smoothstep(0.55, 0.90, dMid) * 0.035;
  dHt = st * 0.000045 * dNear;
  dAlb *= 0.92 + 0.16 * dLo;
  // studded grip zones: 1.15 mm pyramids on a diagonal grid; past the range where they resolve they fold into roughness
  float zk = smoothstep(0.35, 0.60, dZone); vec2 q = vec2(dUV.x + dUV.y, dUV.x - dUV.y) / 0.00115, qc = abs(fract(q) - 0.5);
  float stud = 1.0 - smoothstep(0.10, 0.46, max(qc.x, qc.y)), studK = 1.0 - smoothstep(0.00024, 0.00056, dPx);   // gone before a stud is under two pixels: no moire
  dHt += zk * stud * 0.00028 * studK; dR += zk * (0.10 - stud * 0.16 * studK);
  dAlb *= 1.0 - zk * 0.14 * (1.0 - stud * studK);
  // moulding parting line on the centre plane, flash trimmed
  float pl = (1.0 - smoothstep(0.00012, 0.00034, abs(dP.x))) * step(dAn.x, 0.55) * dNear; dHt += pl * 0.00005; dR -= pl * 0.10;
  // handling shine on edges, a few pale scuffs (polymer whitens where it is scraped)
  float scuff = smoothstep(0.86, 0.96, dScr) * smoothstep(0.45, 0.70, dLo) * (1.0 - smoothstep(0.0007, 0.0020, dPx));
  dAlb = mix(dAlb, dAlb * 1.5 + 0.006, dPolish * 0.5); dR -= dPolish * 0.12;
  dAlb = mix(dAlb, dAlb * 2.0 + 0.015, scuff * 0.35 + dWorn * 0.25); dR += scuff * 0.06;
}
// recesses: darker, rougher, a little pale dust settled in them
float dGrime = dCav * (0.55 + 0.45 * dMid);
dAlb *= 1.0 - 0.50 * dGrime;
dAlb = mix(dAlb, vec3(0.115, 0.100, 0.082), dCav * smoothstep(0.50, 0.85, dLo * 0.5 + dMid * 0.5) * 0.30);
dR += dGrime * 0.22; metalness *= 1.0 - 0.5 * dGrime;
// rain
float dUpN = vWNrm.y, dUp = smoothstep(0.30, 0.75, dUpN) * uRain, dSide = (1.0 - smoothstep(0.10, 0.60, abs(dUpN))) * uRain;
float dDrop = 0.0, dDropH = 0.0, dRun = 0.0;
if (dUp > 0.002) { vec2 dD1 = dDrops(dUV, 0.0050, 3.0, 0.80), dD2 = dDrops(dUV + 0.31, 0.0024, 9.0, 0.90); dDrop = max(dD1.y, dD2.y) * dUp; dDropH = max(dD1.x, dD2.x) * dUp; }
if (dSide > 0.002) dRun = smoothstep(0.80, 0.90, dn3(vec3(dP.x * 420.0 + dP.z * 610.0, dP.y * 9.0, dP.z * 37.0))) * smoothstep(0.42, 0.62, dLo) * dSide * (1.0 - smoothstep(0.0008, 0.0024, dPx));   // run-off: thin, sparse, broken trickles
float dWet = max(dUp * (0.5 + 0.5 * smoothstep(0.3, 0.7, dLo)), dRun * 0.55);
albedo = dAlb * (1.0 - 0.20 * dWet);
roughness = clamp(roughness + dR, 0.12, 1.0);
roughness = mix(roughness, roughness * 0.52, dWet);
roughness = mix(roughness, 0.20, dDrop * 0.8);
float dOcc = 1.0 - 0.80 * dCav;
height=dHt+dDropH*.17;occlusion=dOcc;detail_debug=vec4(dLo,dMid,dGr,dDrop);
}
