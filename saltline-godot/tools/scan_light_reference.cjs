const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
class Vec{constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}copy(v){return this.set(v.x,v.y,v.z)}addScaledVector(v,t){this.x+=v.x*t;this.y+=v.y*t;this.z+=v.z*t;return this}normalize(){let d=Math.hypot(this.x,this.y,this.z)||1;this.x/=d;this.y/=d;this.z/=d;return this}distanceToSquared(v){return (this.x-v.x)**2+(this.y-v.y)**2+(this.z-v.z)**2}lerp(v,t){this.x+=(v.x-this.x)*t;this.y+=(v.y-this.y)*t;this.z+=(v.z-this.z)*t;return this}toJSON(){return [this.x,this.y,this.z]}}
let _=null,T=false,w=0,S=new Vec(),R=0,nb=new Vec(),attempts=0;
const light={color:{setRGB:()=>{}},distance:0,position:new Vec(1,2,3),intensity:0};
const t=[{id:1,type:'gull',alive:true,pos:new Vec(0,4,0),sensor:new Vec(0,3.83,.27),yaw:.3,gy:.1,gp:.4},{id:2,type:'gull',alive:true,pos:new Vec(5,6,3),sensor:new Vec(5,5.83,3.27),yaw:-.4,gy:.2,gp:.1},{id:3,type:'hound',alive:true,pos:new Vec(),sensor:new Vec(),yaw:0,gy:0,gp:0}];
const n={camera:{position:new Vec()},render:{lightPool:{acquire:()=>{attempts++;return {light}}}},physics:{raycast:(origin,dir,limit)=>{if(dir.y>=0)return null;let dist=-origin.y/dir.y;return dist<=limit?{dist}:null}}};
let begin=text.indexOf('let _ = null,',text.indexOf('async function W5(n)')),at=text.indexOf('function z(k) {',begin),end=text.indexOf('let I = 1,',at),update=eval('('+text.slice(at,end).trim()+')');
const frames=[];for(let frame=0;frame<360;frame++){
 n.camera.position.set(frame>=100&&frame<140?80:Math.sin(frame*.03)*8,1,0);t[0].alive=frame<200||frame>=240;t[0].gp=.4+Math.sin(frame*.02)*.3;t[1].gp=.1+Math.sin(frame*.01)*.1;
 if(frame===180)light.intensity=0;update(1/60);
 frames.push(JSON.parse(JSON.stringify({camera:n.camera.position,firstAlive:t[0].alive,firstPitch:t[0].gp,secondPitch:t[1].gp,energy:light.intensity,position:light.position,timer:w,target:S,gain:R,attempts})));
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/scan-light-reference.json',JSON.stringify({frames,scope:'Original shared Gull z with controlled ground ray, moving camera, nearest live selection, 60m cutoff, no-hit dimming and clear preserving sample state'}));console.log({frames:frames.length,attempts});
