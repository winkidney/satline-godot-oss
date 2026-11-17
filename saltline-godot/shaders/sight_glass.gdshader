shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled;
uniform float uBright=7.0;
uniform vec3 uSun=vec3(.9163473615,.2250853235,.3311255204);
uniform vec3 uSunCol=vec3(1.0,.72,.42);
uniform vec3 uZen=vec3(.055,.085,.13);
uniform vec3 uHor=vec3(.16,.22,.3);
uniform float uTilt=.1;
uniform float uEnv=1.0;
varying vec3 vView;
varying vec3 vFwd;
varying vec3 vRight;
varying vec3 vUp;
varying vec3 vWPos;
varying vec3 vWN;
varying vec2 vUv;
varying vec3 sight_camera;
void vertex(){
 vUv=UV;
 vView=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
 vFwd=(MODELVIEW_MATRIX*vec4(0.0,0.0,-1.0,0.0)).xyz;
 vRight=(MODELVIEW_MATRIX*vec4(1.0,0.0,0.0,0.0)).xyz;
 vUp=(MODELVIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
 vWPos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vWN=normalize(mat3(MODEL_MATRIX)*normalize(vec3(0.0,-uTilt,1.0)));
 sight_camera=INV_VIEW_MATRIX[3].xyz;
}
void fragment(){

        vec3 d = normalize(vView), fw = normalize(vFwd);
        float k = max(dot(d, fw), 1e-3);
        vec2 a = vec2(dot(d, normalize(vRight)), dot(d, normalize(vUp))) / k;      // tangent of the angle off the bore axis
        float r = length(a), px = max(fwidth(r), 1e-5);
        float dotR = max(0.0011, px * 0.9), ringW = max(0.00045, px * 0.6);
        float dotI = 1.0 - smoothstep(dotR - px, dotR + px, r);
        float ring = 1.0 - smoothstep(ringW - px * 0.5, ringW + px, abs(r - 0.0128));
        float ang = atan(a.y, a.x);
        float tick = (1.0 - smoothstep(0.0, px * 1.2 + 0.0004, min(abs(a.x), abs(a.y)))) * step(0.0128, r) * (1.0 - smoothstep(0.0165, 0.0175, r));
        float ret = clamp(dotI + ring * 0.8 + tick * 0.8, 0.0, 1.0);
        // faint halo so the bloom has something to hold on to
        ret += 0.05 * exp(-r * r / 0.00002);
        vec3 retCol = vec3(1.0, 0.11, 0.045) * ret * uBright;
        // coated glass: sky/sun reflection through a ruby-teal dichroic coating, stronger at grazing angles
        vec3 wv = normalize(vWPos - sight_camera); vec3 n = normalize(vWN); if (dot(n, wv) > 0.0) n = -n;
        vec3 rf = reflect(wv, n);
        float fres = pow(1.0 - abs(dot(wv, n)), 3.0);
        vec3 sky = mix(uHor, uZen, clamp(rf.y * 1.4 + 0.2, 0.0, 1.0));
        float sd = max(dot(rf, uSun), 0.0);
        sky += uSunCol * (pow(sd, 6.0) * 0.6 + pow(sd, 90.0) * 6.0);
        sky = mix(vec3(0.050, 0.047, 0.043), sky, uEnv); sd *= uEnv;               // under a roof the glass mirrors the room, not the sky
        // multi-layer dichroic coating: the reflected tint walks teal -> violet -> amber as the glass turns away from the
        // eye (thin-film path length grows with the angle), a soft diagonal sheen band, and a thin dark edge
        float band = smoothstep(0.25, 0.5, vUv.x * 0.6 + vUv.y) * (1.0 - smoothstep(0.62, 0.95, vUv.x * 0.6 + vUv.y));
        float ndv = abs(dot(wv, n)), ph = (1.0 - ndv) * 2.6 + vUv.y * 0.35 + vUv.x * 0.12;
        vec3 film = 0.5 + 0.5 * cos(6.2832 * (ph + vec3(0.62, 0.30, 0.12)));
        vec3 coat = mix(mix(vec3(0.30, 0.52, 0.95), vec3(1.0, 0.62, 0.28), clamp(fres * 2.2 + vUv.y * 0.75 - 0.15, 0.0, 1.0)), film * vec3(0.85, 1.0, 0.95), 0.28);
        vec2 e = abs(vUv - 0.5) * 2.0; float edge = smoothstep(0.90, 1.0, max(e.x, e.y));
        float refl = 0.12 + 0.60 * fres + 0.07 * band;
        // dust and a thumb smear on the outer surface: only where light rakes it
        vec2 dc = vUv * vec2(150.0, 100.0), di = floor(dc); float dh = fract(sin(dot(di, vec2(127.1, 311.7))) * 43758.5453);
        float speck = step(0.988, dh) * (1.0 - smoothstep(0.10, 0.36, length(fract(dc) - 0.5 - (fract(dh * 57.3) - 0.5) * 0.5)));
        vec2 sq = (vUv - vec2(0.70, 0.30)) * vec2(1.0, 1.7); float smudge = exp(-dot(sq, sq) * 9.0) * (0.6 + 0.4 * sin(vUv.x * 90.0 + vUv.y * 60.0));
        float lit = 0.06 + 1.6 * pow(sd, 3.0) + fres;
        // faint emitter glow that stays visible off-axis (what you see of a powered sight from the hip)
        vec2 eg = (vUv - vec2(0.5, 0.16)) * vec2(1.0, 1.6); retCol += vec3(1.0, 0.10, 0.04) * 0.20 * exp(-dot(eg, eg) * 60.0) * (1.0 - smoothstep(0.985, 0.9995, k));
        vec3 col = (sky * 1.5 + vec3(0.03, 0.035, 0.045)) * coat * refl * (1.0 - edge) + retCol;
        col += (uHor * 0.5 + uSunCol * 0.25) * lit * (speck * 0.45 + smudge * 0.03);
        float alpha = clamp(0.20 + 0.32 * fres + 0.05 * band + 0.6 * edge + speck * 0.2 * lit + smudge * 0.02, 0.0, 0.94);
        ALBEDO=col;ALPHA=alpha;
      
}
