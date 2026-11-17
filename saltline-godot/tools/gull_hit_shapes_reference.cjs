const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
class Vec{constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}copy(v){return this.set(v.x,v.y,v.z)}sub(v){this.x-=v.x;this.y-=v.y;this.z-=v.z;return this}dot(v){return this.x*v.x+this.y*v.y+this.z*v.z}addScaledVector(v,t){this.x+=v.x*t;this.y+=v.y*t;this.z+=v.z*t;return this}normalize(){let d=Math.hypot(this.x,this.y,this.z)||1;this.x/=d;this.y/=d;this.z/=d;return this}toJSON(){return [this.x,this.y,this.z]}}
const g={pos:new Vec(1,.2,-2)},d=g;
const begin=text.indexOf('function XS('),at=text.indexOf('_raycast(y, b, g, E) {',begin),end=text.indexOf('_update(y)',at),raycast=eval('(function '+text.slice(at,end).trim().replace(/,\s*$/,'')+')');
const cases=[];let hits=0;
for(let i=0;i<480;i++){
 const angle=i*.173,origin=i%4===0?new Vec(1,.8+(i%7)*.2,-2):new Vec(1+Math.sin(angle)*4,-.5+(i%19)*.09,-2+Math.cos(angle)*4),target=new Vec(1,.17+(i%9-4)*.06,-2),dir=new Vec().copy(target).sub(origin).normalize(),limit=i%7===0?.1:200,prior=i%11===0?.1:200;
 const hit={dist:prior,point:new Vec(),normal:new Vec()};const found=raycast(origin,dir,limit,hit);if(found)hits++;
 cases.push({origin:origin.toJSON(),direction:dir.toJSON(),limit,prior,found,dist:hit.dist,point:hit.point.toJSON(),normal:hit.normal.toJSON(),part:hit.part||null});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/gull-hit-shapes-reference.json',JSON.stringify({state:g,cases,scope:'Actual original Gull _raycast ellipsoid with 2.3 y scaling, prior nearest hit and range bounds; no weak part'}));console.log({cases:cases.length,hits});
