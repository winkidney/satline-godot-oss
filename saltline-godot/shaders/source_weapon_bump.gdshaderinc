// Original bE dBump. Flipping both Y derivatives leaves this expression invariant.
vec3 sourceWeaponBump(vec3 normal,vec3 view_position,float height){
 vec3 dpdx=dFdx(view_position),dpdy=dFdy(view_position);float dhx=dFdx(height),dhy=dFdy(height);
 vec3 r1=cross(dpdy,normal),r2=cross(normal,dpdx);float determinant=dot(dpdx,r1);vec3 gradient=sign(determinant)*(dhx*r1+dhy*r2);
 return normalize(abs(determinant)*normal-gradient);
}
