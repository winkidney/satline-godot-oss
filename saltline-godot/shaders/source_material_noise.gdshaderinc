// Match the original NVIDIA WebGL affine FMA, retaining rounded hash products/sums.
// Fully splitting this first multiply/add instead matches the historical SwiftShader reference.
uniform uint source_noise_round_guard=0u;
float sourceNoiseRound(float x){return uintBitsToFloat(floatBitsToUint(x)+source_noise_round_guard);}
vec3 sourceNoiseRound3(vec3 x){return uintBitsToFloat(floatBitsToUint(x)+uvec3(source_noise_round_guard));}
float slH(vec3 p){p=sourceNoiseRound3(p);vec3 q=sourceNoiseRound3(fma(p,vec3(.3183099),vec3(.71,.113,.419)));q=sourceNoiseRound3(fract(q));q=sourceNoiseRound3(q*17.);float xy=sourceNoiseRound(q.x*q.y);float xyz=sourceNoiseRound(xy*q.z);float sx=sourceNoiseRound(q.x+q.y);float s=sourceNoiseRound(sx+q.z);return fract(sourceNoiseRound(xyz*s));}
float slN3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.0-2.0*f);return mix(mix(mix(slH(i),slH(i+vec3(1,0,0)),f.x),mix(slH(i+vec3(0,1,0)),slH(i+vec3(1,1,0)),f.x),f.y),mix(mix(slH(i+vec3(0,0,1)),slH(i+vec3(1,0,1)),f.x),mix(slH(i+vec3(0,1,1)),slH(i+vec3(1,1,1)),f.x),f.y),f.z);}
