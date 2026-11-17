const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8'),data=JSON.parse(fs.readFileSync('saltline-godot/assets/prepared/scene.json')),rules=JSON.parse(fs.readFileSync('saltline-godot/assets/game-rules.json'));
class Vec{constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}copy(v){return this.set(v.x,v.y,v.z)}distanceTo(v){return Math.hypot(this.x-v.x,this.y-v.y,this.z-v.z)}toJSON(){return [this.x,this.y,this.z]}}
const K=Vec,Hn=(x,a,b)=>Math.max(a,Math.min(b,x)),Is=x=>Hn(x,0,1),j0=(a,b,r,dt)=>a+(b-a)*(1-Math.exp(-r*dt)),ou=(a,b,x)=>{let t=Is((x-a)/(b-a));return t*t*(3-2*t)};
function takeObject(name){let marker=text.indexOf('var '+name+' =');if(marker<0)marker=text.indexOf('    '+name+' =');let at=text.indexOf('{',marker),depth=0;for(let j=at;j<text.length;j++){if(text[j]==='{')depth++;if(text[j]==='}'&&--depth===0&&text[j]==='}')return eval('('+text.slice(at,j+1)+')')}}
const xi=takeObject('xi'),lb=takeObject('lb'),cs=takeObject('cs'),dT=['NORTH','NORTH-EAST','EAST','SOUTH-EAST','SOUTH','SOUTH-WEST','WEST','NORTH-WEST'],Vu=takeObject('Vu');
const canonical=process.argv.includes('--canonical');
const sourceRngAt=text.indexOf('function su(n = 1337)'),rng=eval('('+text.slice(sourceRngAt,text.indexOf('\n  var Hn =',sourceRngAt)).trim()+')')(canonical?4207:1337);if(canonical)for(let j=0;j<4;j++)rng();
let callbacks={},progress=0,done=0,all=0,relayStates=[],spawnCalls=0,failed=0,alerts=0,failSpawn=false,nextId=1,interact=false,debrief=null,resupplies=0,explosiveResets=0;
const events={on:(name,fn)=>(callbacks[name]??=[]).push(fn),emit:(name,value)=>{if(name==='objective:progress')progress++;if(name==='objective:done')done++;if(name==='objective:all')all++;for(const fn of callbacks[name]||[])fn(value)}};
const level=JSON.parse(JSON.stringify(data.modules.level));level.playerStart.pos=new Vec(...level.playerStart.pos);level.extraction.pos=new Vec(...level.extraction.pos);for(const point of level.enemySpawns)point.pos=new Vec(...point.pos);for(const objective of level.objectives){objective.pos=new Vec(...objective.pos);objective.object={userData:{setState:(state)=>relayStates.push([objective.id,state])}}}
const player={tuning:JSON.parse(JSON.stringify(rules.player)),pos:new Vec(),eye:new Vec(),forward:new Vec(0,0,-1),health:100,maxHealth:100,alive:true,shake:0,invulnerable:false,enabled:true,reset(start){this.pos.copy(start.pos);this.eye.set(this.pos.x,this.pos.y+1.68,this.pos.z);this.health=100;this.alive=true;this.invulnerable=false;this.enabled=true},addShake(value){this.shake=Math.min(1,this.shake+value)},heal(value){if(this.alive)this.health=Math.min(100,this.health+value)},damage(value){if(!this.alive||this.invulnerable)return;this.health=Math.max(0,this.health-value);events.emit('player:hit',{amount:value});if(this.health===0){this.alive=false;events.emit('player:dead',{})}}};
const enemies={TUNE:JSON.parse(JSON.stringify(rules.enemies)),list:[],spawn(kind,pos,options){spawnCalls++;if(failSpawn){failed++;return null}const actor={id:nextId++,type:kind,pos:new Vec().copy(pos),alive:true};this.list.push(actor);return actor},clear(){this.list.length=0},aliveCount(){return this.list.filter(a=>a.alive).length},alert(){alerts++}};
const combat={stats:{shots:0,hits:0,kills:0},reset(){this.stats={shots:0,hits:0,kills:0}}},weapon={slots:[{reserve:150}],reset(){this.slots[0].reserve=150}};
const radioEvents=[];const hud=new Proxy({radio:(text,secs)=>radioEvents.push([text,secs]),clearRadio:()=>radioEvents.push(["clear"]),reset:()=>radioEvents.push(["clear"])},{get:(target,key)=>key in target?target[key]:()=>{}}),menus=new Proxy({settings:{difficulty:'hard',mode:'mission'},setDebrief(value){debrief=value},setDead:()=>{}},{get:(target,key)=>key in target?target[key]:()=>{}});
const hT=()=>menus,document={addEventListener:()=>{}},addEventListener=()=>{};
const n={render:{post:{saturation:1}},player,level,hud,input:{down:()=>interact,pressed:()=>false,mode:'drag',device:'mouse',setGameplay:()=>{},requestLock:()=>{},exitLock:()=>{}},enemies,combat,weapon,fx:{clear:()=>{}},explosives:{reset:()=>explosiveResets++},events,params:{shot:1},camera:{position:new Vec()},time:{t:0},rng,physics:{lineOfSight:(position)=>position.x<0,nav:{isWalkable:(x,z)=>Math.abs(x)<35&&Math.abs(z)<29}}};
let at=text.indexOf('function pT(n) {'),end=text.indexOf('\n  var mT =',at),game=eval('('+text.slice(at,end).trim()+')')(n);
const used=()=>Object.fromEntries([...game.run.used].map(([point,time])=>[level.enemySpawns.indexOf(point),time]));
function snapshot(){const run={};for(const key of ['time','retries','cut','allCut','queue','waveHot','alertT','pursuitT','pursuitLeft','extractHint','intensity','mode','wave','waveOn','breakT','score','kills','wavesCleared','contactSaid','lowSaid'])run[key]=game.run[key];run.used=used();return JSON.parse(JSON.stringify({state:game.state,radioEvents,run,relays:game.run.relays.map(r=>({id:r.id,t:r.t,cut:r.cut,cutting:r.cutting})),active:enemies.list.map(a=>({id:a.id,type:a.type,pos:a.pos,alive:a.alive})),flow:xi,tuning:enemies.TUNE,regen:[player.tuning.regenDelay,player.tuning.regenRate],playerHealth:player.health,progress,done,all,relayStates,spawnCalls,failed,alerts,nextId,reserve:weapon.slots[0].reserve,explosiveResets,debrief:game.state==='complete'?debrief:null}))}
const difficulties=[];for(const key of ['standard','hard','brutal','missing']){game.setDifficulty(key);difficulties.push({key,flow:JSON.parse(JSON.stringify(xi)),tuning:JSON.parse(JSON.stringify(enemies.TUNE)),regen:[player.tuning.regenDelay,player.tuning.regenRate]})}
game.setDifficulty('hard');game.start({skipIntro:true,mode:'mission'});const initial=snapshot(),frames=[];
for(let frame=0;frame<260;frame++){
 const index=frame<110?0:frame<170?1:2;const point=level.objectives[index].pos;player.pos.set(point.x,point.y,point.z+1.5);player.forward.set(0,0,frame<10?1:-1);interact=frame<40||frame>=50;
 if(frame>=230)player.pos.copy(level.extraction.pos);player.eye.set(player.pos.x,player.pos.y+1.68,player.pos.z);failSpawn=frame>=120&&frame<210;
 if(frame===160)for(const actor of enemies.list)actor.alive=false;
 if(frame===220)Object.assign(combat.stats,{shots:10,hits:6,kills:4});
 if(frame===15||frame===16)events.emit("enemy:alert",{});
 if(frame===45)player.damage(75);
 game.update(1/20);frames.push(snapshot());
}
failSpawn=false;game.start({skipIntro:true,mode:'holdout'});const holdoutInitial=snapshot(),holdout=[];
for(let frame=0;frame<1100;frame++){
 interact=false;if(frame===140)player.damage(40);
 if(frame%20===19)for(const actor of enemies.list)if(actor.alive){actor.alive=false;events.emit('enemy:killed',{enemy:actor,type:actor.type})}
 game.update(1/20);holdout.push(snapshot());
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/'+(canonical?'mission-canonical-reference.json':'mission-reference.json'),JSON.stringify({canonical,difficulties,initial,frames,holdoutInitial,holdout,scope:'Actual full original pT with controlled enemy spawn/LOS/nav/HUD/input; difficulty, relay interruption/cuts, failure retries, extraction and Holdout waves/resupply/score'}));console.log({missionFrames:frames.length,state:frames.at(-1).state,debrief:frames.at(-1).debrief,holdoutFrames:holdout.length,waves:holdout.at(-1).run.wave,score:holdout.at(-1).run.score,spawnCalls,failed});
