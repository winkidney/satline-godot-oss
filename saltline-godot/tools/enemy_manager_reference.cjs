const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8'),data=JSON.parse(fs.readFileSync('saltline-godot/assets/prepared/scene.json'));
class Vec{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}copy(v){this.x=v.x;this.y=v.y;this.z=v.z;return this}distanceToSquared(v){return (this.x-v.x)**2+(this.y-v.y)**2+(this.z-v.z)**2}toJSON(){return [this.x,this.y,this.z]}}
let begin=text.indexOf('function su(n = 1337)'),e=eval('('+text.slice(begin,text.indexOf('\n  var Hn =',begin)).trim()+')')(9001),Bi=data.modules.enemies.TUNE;
let t=[],i=[],order=[],I=1,L=0,alerts=0,spawns=0;
function actor(slot,type){return {slot,type,active:false,alive:false,id:0,pos:new Vec(),lastKnown:new Vec(),mode:'patrol',modeT:0,passive:false,hasToken:false,sink:0,_activate(p,o){this.active=true;this.alive=true;this.pos.copy(p);this.mode=o.state==='alert'?'investigate':'patrol';this.passive=!!o.passive;this.sink=0},_deactivate(){this.active=false;this.alive=false;this.hasToken=false},_update(dt){order.push([this.id,dt])}}}
const d=[actor(0,'gull'),actor(1,'gull')],m=[0,1,2,3,4,5,6,7].map(i=>actor(i,'hound')),x=[],g={count:0},_=null;
const n={player:{vel:new Vec(3,0,4)},events:{emit:(kind)=>{if(kind==='enemy:alert')alerts++;if(kind==='enemy:spawn')spawns++}}},f={t:0,playerSpeed:0,tokens:2,tokenT:17,lastType:'hound',wantT:{gull:4,hound:5}};
begin=text.indexOf('async function W5(n)');
function take(from,to){let a=text.indexOf(from,begin);return text.slice(a,text.indexOf(to,a)).trim().replace(/,\s*$/,'')}
f.retire=eval('(function '+take('retire(k) {','\n      },\n      h = WS()')+')');
f.addWreck=eval('(function '+take('addWreck(k) {','retire(k) {')+')');
const U={spawn:eval('(function '+take('spawn(k, C, A = {}) {','raycast(k, C, A = 300) {')+')'),clear:eval('(function '+take('clear() {','alert(k, C = 40) {')+')'),alert:eval('(function '+take('alert(k, C = 40) {','update(k) {')+')')};
const M=()=>{},z=()=>{};U.update=eval('(function '+take('update(k) {','debug: {')+')');
function snapshot(result=null){return {result,active:t.map(a=>a.id),wrecks:i.map(a=>a.id),pool:[...d,...m].map(a=>({id:a.id,active:a.active,alive:a.alive,sink:a.sink,mode:a.mode,modeT:a.modeT,lastKnown:a.lastKnown.toJSON()})),time:f.t,playerSpeed:f.playerSpeed,tokens:f.tokens,tokenTime:f.tokenT,lastType:f.lastType,want:f.wantT,nextId:I,alerts,spawns,order:[...order]}}
const operations=[],record=(operation,args,run)=>{let result=run();operations.push({operation,args,expected:snapshot(result&&result.id||null)});};
for(let j=0;j<8;j++)record('spawn',{kind:'hound',pos:[j,0,0],options:{}},()=>U.spawn('hound',new Vec(j,0,0),{}));
record('spawn',{kind:'hound',pos:[0,0,0],options:{}},()=>U.spawn('hound',new Vec(),{}));
for(let j=0;j<7;j++)record('kill',{slot:j},()=>{m[j].alive=false;f.addWreck(m[j])});
record('spawn',{kind:'hound',pos:[20,0,0],options:{state:'alert'}},()=>U.spawn('hound',new Vec(20,0,0),{state:'alert'}));
record('alert',{pos:[2,3,0],radius:40},()=>U.alert(new Vec(2,3,0),40));
record('update',{dt:0},()=>U.update(0));record('update',{dt:.1},()=>U.update(.1));record('update',{dt:.016},()=>U.update(.016));
record('retire',{slot:0},()=>f.retire(m[0]));
record('clear',{},()=>U.clear());
record('spawn',{kind:'gull',pos:[0,3,0],options:{passive:true}},()=>U.spawn('gull',new Vec(0,3,0),{passive:true}));
record('alert',{pos:[0,3,0],radius:40},()=>U.alert(new Vec(0,3,0),40));record('spawn',{kind:'unknown',pos:[0,0,0],options:{}},()=>U.spawn('unknown',new Vec(),{}));
fs.writeFileSync('saltline-godot/assets/export/fixtures/enemy-manager-reference.json',JSON.stringify({operations,scope:'Actual original spawn/addWreck/retire/clear/alert/update with controlled actor pools, excluding bolt and scan light callbacks'}));console.log({operations:operations.length,last:operations.at(-1).expected});
