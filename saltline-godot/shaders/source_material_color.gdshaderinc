// Original mk tint runs before Three color_fragment (vertex/instance color).
vec3 sourceMaterialColor(vec3 base,vec4 texel,int tint){
 if(tint==1)return texel.rgb+base*texel.a;
 if(tint==2){float luminance=clamp(dot(texel.rgb,vec3(.3333))/.19,.55,1.35);return mix(texel.rgb,base*luminance,texel.a*.96);}
 return base*texel.rgb;
}
