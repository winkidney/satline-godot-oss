shader_type canvas_item;
render_mode unshaded,blend_disabled;
vec3 sourceTriNormal(vec3 rest_normal,vec3 weights,vec3 encoded_x,vec3 encoded_y,vec3 encoded_z,vec2 strength,vec3 axis_x,vec3 axis_y,float face_direction){
 vec3 slOn=normalize(rest_normal);vec3 slTx=encoded_x*2.0-1.0;vec3 slTy=encoded_y*2.0-1.0;vec3 slTz=encoded_z*2.0-1.0;
 slTx.xy*=strength;slTy.xy*=strength;slTz.xy*=strength;
 slTx=vec3(slTx.xy+slOn.zy,abs(slTx.z)*slOn.x);slTy=vec3(slTy.xy+slOn.xz,abs(slTy.z)*slOn.y);slTz=vec3(slTz.xy+slOn.xy,abs(slTz.z)*slOn.z);
 vec3 slNo=normalize(slTx.zyx*weights.x+slTy.xzy*weights.y+slTz.xyz*weights.z);
 vec3 slA=normalize(axis_x);vec3 slB=normalize(axis_y);vec3 slC=cross(slA,slB);
 return normalize(slA*slNo.x+slB*slNo.y+slC*slNo.z)*face_direction;
}

uniform vec3 uNormal;uniform vec3 uAxisX;uniform vec3 uAxisY;uniform vec3 uSampleX;uniform vec3 uSampleY;uniform vec3 uSampleZ;uniform vec2 uScale;uniform float uFace;
void fragment(){vec3 n=normalize(uNormal);vec3 weights=pow(abs(n),vec3(6.0));weights/=dot(weights,vec3(1.0));vec3 result=sourceTriNormal(uNormal,weights,uSampleX,uSampleY,uSampleZ,uScale,uAxisX,uAxisY,uFace);COLOR=vec4(result*.5+.5,1.0);}
