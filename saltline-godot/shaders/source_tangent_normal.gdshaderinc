// Original Three getTangentFrame + DOUBLE_SIDED T/B correction.
mat3 sourceTangentFrame(vec3 q0,vec3 q1,vec2 st0,vec2 st1,vec3 normal,float face){
 vec3 q1perp=cross(q1,normal),q0perp=cross(normal,q0);
 vec3 tangent=q1perp*st0.x+q0perp*st1.x;
 vec3 bitangent=q1perp*st0.y+q0perp*st1.y;
 float determinant=max(dot(tangent,tangent),dot(bitangent,bitangent));
 float factor=determinant==0.0?0.0:inversesqrt(determinant);
 return mat3(tangent*factor*face,bitangent*factor*face,normal);
}
vec3 sourceTangentNormal(vec3 view_position,vec2 normal_uv,vec3 normal,vec3 map_normal,float face){
 float y_sign=SOURCE_RASTER_Y_UP?1.0:-1.0;
 return normalize(sourceTangentFrame(dFdx(view_position),dFdy(view_position)*y_sign,dFdx(normal_uv),dFdy(normal_uv)*y_sign,normal,face)*map_normal);
}
