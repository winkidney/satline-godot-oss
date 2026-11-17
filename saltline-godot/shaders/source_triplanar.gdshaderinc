uniform sampler2D source_tri_palette:filter_nearest,repeat_disable;
instance uniform bool source_tri_skinned:instance_index(8)=false;
instance uniform int source_tri_palette_base:instance_index(9)=0;
varying vec3 source_tri_axis_x;
varying vec3 source_tri_axis_y;
mat3 sourceTriBone(int slot){int row=source_tri_palette_base+slot;return mat3(texelFetch(source_tri_palette,ivec2(0,row),0).xyz,texelFetch(source_tri_palette,ivec2(1,row),0).xyz,texelFetch(source_tri_palette,ivec2(2,row),0).xyz);}
vec3 sourceTriNormal(vec3 rest_normal,vec3 weights,vec3 encoded_x,vec3 encoded_y,vec3 encoded_z,vec2 strength,vec3 axis_x,vec3 axis_y,float face_direction){
 vec3 slOn=normalize(rest_normal);vec3 slTx=encoded_x*2.0-1.0;vec3 slTy=encoded_y*2.0-1.0;vec3 slTz=encoded_z*2.0-1.0;
 slTx.xy*=strength;slTy.xy*=strength;slTz.xy*=strength;
 slTx=vec3(slTx.xy+slOn.zy,abs(slTx.z)*slOn.x);slTy=vec3(slTy.xy+slOn.xz,abs(slTy.z)*slOn.y);slTz=vec3(slTz.xy+slOn.xy,abs(slTz.z)*slOn.z);
 vec3 slNo=normalize(slTx.zyx*weights.x+slTy.xzy*weights.y+slTz.xyz*weights.z);
 vec3 slA=normalize(axis_x);vec3 slB=normalize(axis_y);vec3 slC=cross(slA,slB);
 return normalize(slA*slNo.x+slB*slNo.y+slC*slNo.z)*face_direction;
}
