// Original mk/gk SL_FX preparation; p is rest-space for triplanar, world-space otherwise.
void sourceWetSurface(vec3 p,vec3 wn,vec4 orm,bool tri,int tint,vec4 macro,vec4 params,float rain,float indoor,vec3 footprint,inout vec4 texel,out float mac,out float mac2,out float wet,out float up,out float bead){
 vec3 mp=p*macro.z;mac=slN3(mp);mac2=slN3(mp*3.7+11.3);
 texel.rgb*=1.0+macro.x*(mac*.65+mac2*.35-.5)*2.0;
 float grime=smoothstep(.5,.85,mac*.6+mac2*.4+(1.0-orm.r)*.3)*macro.w;
 texel.rgb*=1.0-grime*.35;if(tint==1)texel.a*=1.0-grime*.2;
 up=smoothstep(.15,.85,wn.y);float exposure=smoothstep(-.4,-.05,wn.y);float streak=0.0;
 if(!tri){float sc=p.x+p.z;streak=slN3(vec3(sc*9.0,p.y*.55,sc*.7+3.0))*slN3(vec3(sc*29.0,p.y*1.1,7.0));streak=smoothstep(.12,.42,streak)*smoothstep(.3,.7,slN3(vec3(sc*1.1,p.y*.25,1.7)));}
 float w=rain*indoor*exposure;wet=w*mix(params.z*(.55+.9*streak),.75+.5*mac,up);
 if(!tri){float low=(1.0-smoothstep(0.0,.5,p.y))*(1.0-up)*exposure;wet+=w*low*.6;float lg=1.0-low*min(macro.w,.5)*.45;texel.rgb*=lg;if(tint==1)texel.a*=lg;}
 wet=clamp(wet,0.0,1.0);bead=0.0;float bf=clamp(1.0-length(footprint)*120.0,0.0,1.0);
 if(params.w>0.0&&bf>0.0){float b=slN3(p*170.0)*.6+slN3(p*410.0+5.0)*.4;bead=smoothstep(.6,.68,b)*params.w*w*bf*(.4+.6*up+.5*streak);}
}
vec3 sourceWetColor(vec3 color,float wet,vec4 params){float lum=dot(color,vec3(.299,.587,.114));return mix(vec3(lum),color,1.0+.25*wet*params.x*2.0)*(1.0-params.x*wet);}

float sourceWetRoughness(float roughness,float orm_g,vec4 macro,vec4 params,float mac,float mac2,float wet,float bead){float value=roughness*orm_g;value+=macro.y*((mac2-.5)*1.4+(mac-.5)*.8);value=mix(value,value*params.y,wet);return mix(value,.05,bead);}
