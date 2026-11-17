const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const nativePlayer=process.argv.includes('--native-player');
const T=eval(source.slice(0,source.indexOf('  var Kn = {'))+'return ut;})()');
function between(start,end){let a=source.indexOf(start),b=source.indexOf(end,a);if(a<0||b<0)throw Error('missing '+start);return source.slice(a,b);}
const math=between('    pn = (n, e = 1) =>','  function Ru('),constants=between('  var Js = K,','  async function I5('),D=between('    function D(B, X, re, Y, he, V, ne) {',`    if (
      (T(),`);
const helpers=between('  var Hn = (n, e, t) =>','  var a0 = '),ease=between('  var RE = St,','  var dn = ');
const rifleRecoil=between('      recoil(B, X, re) {','      reload(B, X) {').trim().replace(/,$/,'');
const pistolRecoil=between('      recoil(ge, ce, P) {','      reload(ge, ce) {').trim().replace(/,$/,'');
const factory=new Function('THREE','initial','rig','recoilMethods',`const K=THREE.Vector3,St=THREE.Quaternion;${helpers};${ease};${constants};var pn;${math};let a=structuredClone(initial),l={noIdle:false},calls=0,queries=0,hit=null;const r=()=>{const value=[.07,.91,.32,.68,.5][calls%5];calls++;return value;};const bh={rifle:rig.motion,pistol:rig.motion};const methods=rig.id==="rifle"?new Function("s","o","bh","u0","return ({"+recoilMethods.rifle+"}).recoil;")(a,r,bh,u0):new Function("i","s","bh","u0","return ({"+recoilMethods.pistol+"}).recoil;")(a,r,bh,u0);const n={physics:{raycast:()=>{queries++;return hit===null?null:{dist:hit};}}};let q=new THREE.Quaternion(),ue=new THREE.Quaternion(),de=new THREE.Euler(),$=new K(),se=new K(),fe=new K();const me=B=>B*(.35+.65*Math.abs(B)),ge=B=>B*(1.6-.6*Math.abs(B)),ce=B=>B*(1.45-.45*Math.abs(B)),P=(B,X)=>{if(Math.abs(B.x-X)<1e-5&&Math.abs(B.v)<1e-4)Xn(B,X);};${D};return {a,step(row){Object.assign(a,structuredClone(row.patch));for(const [key,value] of Object.entries(row.impulses))a[key].v+=value;a.t+=row.dt;const camera=[],shakes=[];if(row.fire){const avatar={crouching:row.player.crouching};if(row.camera_enabled){avatar.addRecoil=(pitch,yaw)=>camera.push([pitch,yaw]);avatar.addShake=value=>shakes.push(value);}methods(row.burst,row.camera_scale,avatar);}l.noIdle=row.no_idle;hit=row.hit;n.physics.raycast=row.no_raycast?null:()=>{queries++;return hit===null?null:{dist:hit};};D(Math.min(row.dt,.1),rig,row.player,row.input,...row.inspect);rig.root.updateMatrix();return {camera,shakes,state:structuredClone(a),position:rig.root.position.toArray(),quaternion:rig.root.quaternion.toArray(),matrix:rig.root.matrix.toArray(),random_calls:calls,wall_queries:queries};}};`);
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/prepared/scene.json'),'utf8')),cases=[];
for(const gun of ['rifle','pistol']){
 const rig=structuredClone(data.modules.weapon.rigs[gun]);rig.root=new T.Object3D();const initial=structuredClone(data.modules.weapon.debug.S);
 for(const key of ['kZ','kP','kY','kR','kX','kU']){initial[key].w=rig.motion.recoil.spr[key][0];initial[key].z=rig.motion.recoil.spr[key][1];}
 for(const [keys,spr] of [[['swY','swP'],rig.motion.sway.spr],[['jY','jP','jR'],rig.motion.air.spr],[['inZ','inX','inP','inR'],rig.motion.inertia.spr]])for(const key of keys){initial[key].w=spr[0];initial[key].z=spr[1];}
 const original=factory(T,initial,rig,{rifle:rifleRecoil,pistol:pistolRecoil}),steps=[];
 for(let i=0;i<600;i++){
  const dt=[1/60,1/240,.033,.05,0,.2][i%6],air=i%120>=60&&i%120<80,previousAir=(i-1)%120>=60&&(i-1)%120<80;
  const player={onGround:!air,speed:i%100<70?(i%150<90?3.8:6.4):0,vel:{x:Math.sin(i*.07)*3,y:air?4-(i%120-60)*.6:0,z:Math.cos(i*.09)*4},yaw:Math.sin(i*.03)*4,crouching:i%110>=85,sprinting:i%150>=90,eye:[0,1.68,0],forward:[0,0,-1],tuning:i%2?{stride:{walk:1.55,sprint:2.1,crouch:1.05}}:{}};
  const row={dt,player,input:{look:{dx:i%40===0?30:Math.sin(i*.19)*.015,dy:i%41===0?-30:Math.cos(i*.17)*.013}},inspect:[Math.sin(i*.02)*.4,Math.cos(i*.015)*.3,i%160>130?.7:0],no_idle:i>=450&&i<480,hit:i%90<30?null:i%90<60?rig.motion.wall.near*.5:rig.motion.wall.far*.7,patch:{adsWant:i%100>=25&&i%100<65,spWant:player.sprinting,urgent:i%7===0,reloadW:i%140>100?.8:0,rackW:i%140>125?.65:0,hol:i%180>150?-Math.sin((i%180-150)*.14):0,antYT:Math.sin(i*.1)*.003,antRT:Math.cos(i*.13)*.02,stepEv:i%13===0?1:0,jumpEv:air&&!previousAir?1:0,landEv:!air&&previousAir?8:-1},impulses:{}};
  if(i%37===0)Object.assign(row.impulses,{kZ:.6,kP:1.4,kY:-.3,kR:.7,kX:.08,kU:.12,bump:-.08});
  if(i===240)Object.assign(row.patch,{breath:4096.01,gait:2048.01});
  if(i===300){row.dt=0;Object.assign(row.player,{onGround:true,speed:0});Object.assign(row.patch,{gait:-.5,gOff:structuredClone(initial.gOff),gOffT:0,stepEv:1,landEv:-1,wasGround:true});row.patch.gOff.x=0;row.patch.gOff.v=0;}
  row.fire=i%25===0;row.burst=[1,2,3,4,9,10][Math.floor(i/25)%6];row.camera_scale=.55+(i%3)*.15;row.camera_enabled=i%50!==0;row.patch.adsE=(i%100)/99;row.no_raycast=i%77<5;
  if(i%83===0)delete row.player.eye;
  if(i%89===0)row.player.forward=null;
  if(i%97===0)row.player.vel=null;
  if(i%101===0)row.player.tuning=null;
  if(i===311){row.dt=0;row.input.look=null;row.patch.swY={...initial.swY,x:1,v:2};row.patch.swP={...initial.swP,x:-1,v:-2};}
  if(i%103===0)row.input.look=null;
  if(i===200)Object.assign(row.patch,{lastVy:0,landEv:0});
  if(nativePlayer){row.no_raycast=false;row.ray_far=rig.motion.wall.far;row.player.eye=[0,Math.fround(1.68),0];row.player.forward=[0,0,-1];row.player.tuning??={};row.player.vel??={x:0,y:0,z:0};for(const key of ['x','y','z'])row.player.vel[key]=Math.fround(row.player.vel[key]);}
  steps.push({input:row,expected:original.step(row)});
 }
 if(steps[300].expected.state.gOffT!==.5)throw Error('negative-half round not covered');
 if(steps[311].expected.state.swY.x!==rig.motion.sway.max*2.5||steps[311].expected.state.swY.v!==0||steps[311].expected.state.swP.x!==-rig.motion.sway.max*2.5||steps[311].expected.state.swP.v!==0)throw Error('hard clamp not covered');
 cases.push({gun,initial,steps});
}
const report={native_player_quantized:nativePlayer,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),recoil_sha256:crypto.createHash('sha256').update(rifleRecoil+pistolRecoil).digest('hex'),D_sha256:crypto.createHash('sha256').update(D).digest('hex'),scope:'Literal original D and original bundled Three math. Two independent rig trajectories from exported debug.S plus explicit coefficient setup. Literal original rifle/pistol recoil methods at48 fire steps, synthetic external wants/reload/inspect/events and fixed RNG. Directed negative-half rounding, hard sway clamps, null look/vel/tuning and unavailable ray paths; not original O or production integration.',cases};
fs.writeFileSync(path.join(root,'assets/export/fixtures/'+(nativePlayer?'weapon-root-adapter-reference.json':'weapon-root-motion-reference.json')),JSON.stringify(report));console.log(JSON.stringify({cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),source_sha256:report.source_sha256,D_sha256:report.D_sha256}));
