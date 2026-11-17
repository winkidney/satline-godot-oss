// Original mk SL_ACUT. Pixel coordinate follows original OpenGL bottom-left origin.
vec2 sourceDistanceAlpha(float sampled_alpha,vec2 uv_footprint,vec2 pixel){
 vec2 fw=uv_footprint*512.0;float lod=log2(max(max(fw.x,fw.y),1e-4));
 float threshold_coarse=.5*exp2(-clamp(lod-1.0,0.0,4.0));
 float ign=fract(52.9829189*fract(dot(pixel,vec2(.06711056,.00583715))));
 float threshold=mix(threshold_coarse,.05+ign*.80,smoothstep(3.5,5.5,lod));
 return vec2(sampled_alpha>threshold?1.0:0.0,mix(1.0,.45,smoothstep(1.5,4.5,lod)));
}
