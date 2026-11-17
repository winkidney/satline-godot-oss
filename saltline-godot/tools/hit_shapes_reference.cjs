const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
class Vec{constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}copy(v){return this.set(v.x,v.y,v.z)}sub(v){this.x-=v.x;this.y-=v.y;this.z-=v.z;return this}dot(v){return this.x*v.x+this.y*v.y+this.z*v.z}addScaledVector(v,t){this.x+=v.x*t;this.y+=v.y*t;this.z+=v.z*t;return this}normalize(){let d=Math.hypot(this.x,this.y,this.z)||1;this.x/=d;this.y/=d;this.z/=d;return this}toJSON(){return [this.x,this.y,this.z]}}
const qh=new Vec(),eb=new Vec(),$S=new Vec(),_s=new Vec(),Gh=new Vec(),Yn={stand:.72};
let at=text.indexOf('function KS(n, e, t, i, s, o)'),end=text.indexOf('\n  var qh =',at);const KS=eval('('+text.slice(at,end).trim()+')');at=text.indexOf('function ZS(n, e, t, i, s, o, r)');end=text.indexOf('\n  var Bi =',at);const ZS=eval('('+text.slice(at,end).trim()+')');
const g={pos:new Vec(1,.2,-2),headPos:new Vec(1.2,1.1,-1.4),yaw:.7,sY:{x:-.04},crouch:.05};
at=text.indexOf('_raycast(k, C, A, F) {',text.indexOf('function jS(n, e, t, i)'));end=text.indexOf('_update(k)',at);const raycast=eval('(function '+text.slice(at,end).trim().replace(/,\s*$/,'')+')');
const cases=[];let hits=0,weak=0;for(let i=0;i<480;i++){
 const angle=i*.173,origin=new Vec(1+Math.sin(angle)*4,.2+(i%19)*.095,-2+Math.cos(angle)*4),target=i%3===0?g.headPos:new Vec(1,.2+(i%13)*.07,-2),dir=new Vec().copy(target).sub(origin).normalize(),limit=i%7===0?1:200,prior=i%11===0?2:200;
 const hit={dist:prior,point:new Vec(),normal:new Vec()};const found=raycast(origin,dir,limit,hit);if(found){hits++;if(hit.part==='weak')weak++}
 cases.push({origin:origin.toJSON(),direction:dir.toJSON(),limit,prior,found,dist:hit.dist,point:hit.point.toJSON(),normal:hit.normal.toJSON(),part:hit.part||null});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/enemy-hit-shapes-reference.json',JSON.stringify({state:g,cases,scope:'Original KS/ZS/Hound _raycast, normalized rays, constrained range and prior nearest hit'}));console.log({cases:cases.length,hits,weak});
