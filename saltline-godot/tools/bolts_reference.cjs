const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8'),data=JSON.parse(fs.readFileSync('saltline-godot/assets/prepared/scene.json'));
class Vec{constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}copy(v){return this.set(v.x,v.y,v.z)}sub(v){this.x-=v.x;this.y-=v.y;this.z-=v.z;return this}dot(v){return this.x*v.x+this.y*v.y+this.z*v.z}addScaledVector(v,t){this.x+=v.x*t;this.y+=v.y*t;this.z+=v.z*t;return this}normalize(){let v=Math.hypot(this.x,this.y,this.z)||1;this.x/=v;this.y/=v;this.z/=v;return this}toJSON(){return [this.x,this.y,this.z]}}
function take(from,to,begin=0){const a=text.indexOf(from,begin);return text.slice(a,text.indexOf(to,a)).trim().replace(/,\s*$/,'')}
const quaternionMethod=eval('(function '+take('setFromUnitVectors(e, t) {','angleTo(e) {')+')');
const QS={_x:0,_y:0,_z:0,_w:1,setFromUnitVectors:quaternionMethod,normalize(){let l=Math.hypot(this._x,this._y,this._z,this._w);this._x/=l;this._y/=l;this._z/=l;this._w/=l;return this},get x(){return this._x},get y(){return this._y},get z(){return this._z},get w(){return this._w}};
const eT={elements:new Array(16).fill(0),compose:eval('(function '+take('compose(e, t, i) {','decompose(e, t, i) {')+')')},tT=new Vec(),ZD=new Vec(0,0,1),JS=new Vec(),nT=new Vec(),iT=new Vec(),rc=new Vec(),ac=new Vec(),lc=new Vec();
const jd=text.indexOf('function jD(n, e, t, i) {'),jD=eval('('+text.slice(jd,text.indexOf('function KD(',jd)-8).trim()+')');
const Bi=data.modules.enemies.TUNE,x=Array.from({length:Bi.maxBolts},()=>({on:false,life:0,len:0,pos:new Vec(),dir:new Vec(),from:new Vec()}));let matrices=[],events=[],hits=0,emitted=0,dropped=0;
const player={pos:new Vec(0,0,-4),alive:true,crouching:false,health:100,damage(amount,from){hits++;this.health=Math.max(0,this.health-amount);if(this.health<=0)this.alive=false}};
const n={player,events:{emit:(kind,value)=>{if(kind==='impact')events.push(JSON.parse(JSON.stringify(value)))}},physics:{raycast:(origin,dir,limit)=>{if(dir.z>=0)return null;const dist=(-6-origin.z)/dir.z;if(dist<0||dist>limit)return null;return {dist,point:new Vec(origin.x+dir.x*dist,origin.y+dir.y*dist,-6),normal:new Vec(0,0,1),surface:'metal'}}}};
const g={count:0,instanceMatrix:{needsUpdate:false},setMatrixAt:(index,matrix)=>matrices[index]=matrix.elements.map(Math.fround)},E={point:new Vec(),normal:new Vec(),dist:0,surface:'concrete',enemy:null,part:null,dir:new Vec(),from:'enemy'};
const begin=text.indexOf('async function W5(n)'),update=eval('('+take('function M(k) {','let _ = null,',begin)+')');const f={fireBolt:eval('(function '+take('fireBolt(k, C, A) {','addWreck(k) {',begin)+')')};
const frames=[];for(let frame=0;frame<320;frame++){
 player.pos.z=frame%90<45?-4:-8;player.crouching=frame%60>=30;if(frame===160){player.alive=true;player.health=100}
 const spawns=[];if(frame===0||frame%17===0){let count=frame===0?40:7;for(let j=0;j<count;j++){
  const position=new Vec((j%9-4)*.2,.2+(j%7)*.3,0),direction=new Vec(j%5===0?.2:0,j%6===0?.1:0,j%9===0?1:-1).normalize();const available=x.some(slot=>!slot.on);f.fireBolt(position,direction,null);if(available)emitted++;else dropped++;spawns.push({position:position.toJSON(),direction:direction.toJSON()});
 }}
 const dt=frame%19===0?.05:1/60;matrices=[];update(dt);frames.push(JSON.parse(JSON.stringify({spawns,dt,playerZ:player.pos.z,crouching:player.crouching,slots:x,matrices:matrices.slice(0,g.count),hits,emitted,dropped,health:player.health,alive:player.alive,impacts:events.length})));
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/bolts-reference.json',JSON.stringify({frames,events,scope:'Actual original fireBolt/M/jD plus Three setFromUnitVectors/Matrix4.compose; 32-slot saturation, wall occlusion, player crouch/death, reuse and expiry'}));console.log({frames:frames.length,hits,emitted,dropped,impacts:events.length});
