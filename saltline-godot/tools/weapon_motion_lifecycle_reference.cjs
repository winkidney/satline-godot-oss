const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function between(start,end){const a=source.indexOf(start),b=source.indexOf(end,a);if(a<0||b<0)throw Error('missing '+start);return source.slice(a,b);}
const equip=between('    function _(B) {','    function T() {'),reset=source.slice(source.indexOf('    function T() {',source.indexOf('    function _(B) {')),source.indexOf('    function w(B, X) {',source.indexOf('    function _(B) {')));
const snap=between('        snap() {\n          let B = n.player,','        view: 1,').trim().replace('snap() {','function snap() {').replace(/,$/,'');
const math=between('  var RE = St,','  function Ru('),helpers=between('  var Hn = (n, e, t) =>','  var a0 = '),constants=between('  var Js = K,','  async function I5(');
const factory=new Function('initial','sourceRigs',`const St=function(){},K=function(){};${helpers};${math};${constants};let a=structuredClone(initial),E={},u={active:false},g=true,l={ads:false,sprint:false},n={player:{},input:{}};const make=id=>({id,motion:sourceRigs[id].motion,def:{magSize:30,reserve:100},slot:{},root:{visible:false},flash:{visible:false},reset(){},snapArms(){}});const m=make('rifle'),x=make('pistol'),v={rifle:m,pistol:x},y=[m,x],p={snap(){}};let b=m;function j(){}${equip};${reset};${snap};return {a,apply(row){Object.assign(a,structuredClone(row.patch));n.player=row.player;n.input=row.input;u.active=row.switching;l.ads=row.debug_ads;l.sprint=row.debug_sprint;if(row.action==='equip')_(v[row.gun]);else if(row.action==='reset')T();else snap();return structuredClone(a);}};`);
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/prepared/scene.json'),'utf8')),initial=structuredClone(data.modules.weapon.debug.S),original=factory(initial,data.modules.weapon.rigs),steps=[];
for(let i=0;i<96;i++){
 const patch={t:5+i*.13,breath:1+i*.17,landSide:i%2?-1:1,recPhase:.3+i*.11,lastVy:-.4-i*.02,wallT:.07,wasGround:false,spWant:true,gait:3.3,exert:.8,reloadW:.65,rackW:.35,hol:.7,adsWant:true,antYT:.02,antRT:.03,reload:i%5===0?{t:.4}:null};
 for(const [key,value] of Object.entries(original.a))if(value&&typeof value==='object'&&'x'in value&&'v'in value)patch[key]={...value,x:.11+i*.001,v:-.3-i*.002};
 const row={action:['equip','snap','reset','snap'][i%4],gun:i%3?'pistol':'rifle',patch,player:{onGround:i%3!==0,crouching:i%3===0,sprinting:i%3===1},input:{fire:i%7===0,ads:i%4===1},switching:i%9===0,debug_ads:i%11===0,debug_sprint:i%13===0};
 if(i%17===0)row.player.onGround=null;
 steps.push({input:row,expected:original.apply(row)});
}
const coverage={equip:0,reset:0,snap:0,stance_zero:0,stance_one:0,ads_zero:0,ads_one:0,sprint_zero:0,sprint_one:0};
for(const row of steps){coverage[row.input.action]++;if(row.input.action==='snap'){coverage[row.expected.stance.x===1?'stance_one':'stance_zero']++;coverage[row.expected.adsV.x===1?'ads_one':'ads_zero']++;coverage[row.expected.spV.x===1?'sprint_one':'sprint_zero']++;}}
if(Object.values(coverage).some(count=>count===0))throw Error('Missing lifecycle branch '+JSON.stringify(coverage));
const result={coverage,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),lifecycle_sha256:crypto.createHash('sha256').update(equip+reset+snap).digest('hex'),initial,steps,scope:'Literal original equip/reset/snap and helpers, one shared S over96 operations with explicitly dirty springs/history. Pure state only: mock nodes/arms/drop/slots side effects are not validated, no production cutover.'};
fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-motion-lifecycle-reference.json'),JSON.stringify(result));console.log(JSON.stringify({steps:steps.length,source_sha256:result.source_sha256,lifecycle_sha256:result.lifecycle_sha256}));
