const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function between(start,end,offset=0){const a=source.indexOf(start,offset),b=source.indexOf(end,a);if(a<0||b<0)throw Error('missing '+start);return source.slice(a,b);}
const math=between('  var RE = St,','  function Ru('),helpers=between('  var Hn = (n, e, t) =>','  var a0 = ');
const inspect=between('        ye ||','      (E.state = ne',source.indexOf('      let ze = X.speed || 0,',source.indexOf('    function O(B) {',source.indexOf('    function _(B) {'))));
const targets=between('        (a.spWant = Re),','        re.pressed && re.pressed("reload")').trim().replace(/,$/,';');
const finger=between('        (a.finger = j0(a.finger,','        Y.parts(').trim().replace(/,$/,';');
const factory=new Function('initial',`const St=function(){};${math};${helpers};let a=structuredClone(initial),l={flash:false};return {a,step(row,definition){Object.assign(a,structuredClone(row.patch));const B=row.dt,X={speed:row.speed},re=row.input,he=definition,ne=row.switching,ye=row.fire,Ue=row.can_fire,Re=row.sprint,ze=X.speed||0;${targets};if(row.dry)a.bump.v-=.08;${inspect};${finger};return {state:structuredClone(a),inspect:[je,Ze,qe]};}};`);
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/prepared/scene.json'),'utf8')),cases=[];
for(const gun of ['rifle','pistol']){
 const initial=structuredClone(data.modules.weapon.debug.S);initial.idleT=23.98;const original=factory(initial),steps=[];
 for(let i=0;i<320;i++){
  const row={dt:[0,1/240,1/60,.05,.1][i%5],input:{ads:false,look:null},speed:0,switching:false,fire:false,can_fire:true,sprint:i%19===0,dry:i%31===0,patch:{reload:null,sprintT:0}};
  if(i>=80&&i<160){const k=i%8;row.patch.inspect=.3;row.patch.idleT=2;row.fire=k===0;row.input.ads=k===1;row.patch.reload=k===2?{}:null;row.switching=k===3;row.speed=k===4?.200000001:0;row.input.look=k===5?{dx:.002000001,dy:0}:null;row.patch.sprintT=k===6?.100000001:0;}
  if(i===160){row.patch.inspect=-1;row.patch.idleT=24;}
  if(i>=240&&i<260){row.patch.inspect=i%2?3.5:2.9;row.input.look={dx:[.002,.002000001,.001999999][i%3],dy:0};row.dt=i%2?.001:0;}
  steps.push({input:row,expected:original.step(row,data.modules.weapon.rigs[gun].def)});
 }
 cases.push({gun,initial,steps});
}
const originalO=between('    function O(B) {','    let q = new St(),',source.indexOf('    function _(B) {'));
const productionFactory=new Function('initial','rig',`const St=function(){};${math};${helpers};let a=structuredClone(initial),l={pause:false,noFire:false,ads:false,sprint:false,reloadT:null,flash:false,freeze:false},g=true,u={active:false},E={},windows=[0,0,0],dry=[];const b={id:rig.id,def:rig.def,slot:{ammo:0,reserve:0},parts(){},flash:{visible:false,material:{uniforms:{uInt:{value:0},uHeat:{value:0}}}}};const W={active:true};function le(){}function xe(){}const p={update(){}};function D(B,Y,X,re,je,Ze,qe){windows=[je,Ze,qe];}const n={player:null,input:null,events:{emit:(type,event)=>{if(type==='weapon:dry')dry.push({time:a.t,weapon:event.weapon});}}};${originalO};return {step(row){n.player=row.player;n.input={...row.input,pressed:()=>false};O(row.dt);return {t:a.t,adsWant:a.adsWant,spWant:a.spWant,urgent:a.urgent,idleT:a.idleT,inspect:a.inspect,finger:a.finger,bump:a.bump.v,adsE:a.adsE,adsLin:a.adsLin,sprintT:a.sprintT,spreadS:a.spreadS,cooldown:a.cooldown,previous_fire:a.prevFire,state:E.state||'idle',windows:[...windows],dry:structuredClone(dry)};}};`);
const production_cases=[];
for(const gun of ['rifle','pistol']){
 const rig=data.modules.weapon.rigs[gun],initial=structuredClone(data.modules.weapon.debug.S),original=productionFactory(initial,rig),steps=[];
 for(let i=0;i<2450;i++){
  const active=i>=1850,alive=!(i>=2100&&i<2110),speed=active&&i%80<30?3.8:0;
  const row={dt:active?[0,1/240,1/60,.033,.05,.2][i%6]:1/60,player:{alive,sprinting:active&&i%90>65,speed,onGround:i%70<65,on_ground:i%70<65,crouching:active&&i%83>65},input:{fire:active&&i%45<7,ads:active&&i%75>=30&&i%75<55,look:active&&i%35===0?{dx:.004,dy:-.001}:null}};
  steps.push({input:row,expected:original.step(row)});
 }
 production_cases.push({gun,initial,steps});
}
const coverage={};
for(const sample of production_cases){const rows=sample.steps;coverage[sample.gun]={inspect_frames:rows.filter(r=>r.expected.inspect>=0).length,nonzero_windows:rows.filter(r=>r.expected.windows.some(v=>v>0)).length,dead_steps:rows.filter(r=>!r.input.player.alive).length,ads_wanted:rows.filter(r=>r.expected.adsWant).length,sprint_wanted:rows.filter(r=>r.expected.spWant).length,dry_events:rows.at(-1).expected.dry.length};}
if(coverage.rifle.inspect_frames<1||coverage.pistol.inspect_frames!==0)throw Error('inspect policy not covered');
for(const c of Object.values(coverage))if(!c.dead_steps||!c.ads_wanted||!c.sprint_wanted||!c.dry_events)throw Error('missing production control branch');
if(cases[0].steps[160].expected.state.inspect!==-1||cases[0].steps[161].expected.state.inspect<0)throw Error('strict24 boundary not covered');
const result={coverage,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),segments_sha256:crypto.createHash('sha256').update(targets+inspect+finger).digest('hex'),cases,production_cases,original_O_sha256:crypto.createHash('sha256').update(originalO).digest('hex'),scope:'Literal target/inspect/finger blocks640 steps plus production Weapon controls compared against literal full O4900 steps with empty ammo/reserve. Original parts/flash/drop/D are mocks; drop assumed already active. Only selected control/logical fields and dry events checked. Explicit same exported initial clock in production test; no complete O/RNG/root/drop/IK proof.'};
fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-motion-controls-reference.json'),JSON.stringify(result));console.log(JSON.stringify({cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),segments_sha256:result.segments_sha256}));
