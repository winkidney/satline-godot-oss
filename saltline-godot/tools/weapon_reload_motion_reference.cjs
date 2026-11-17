const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function between(start,end){const a=source.indexOf(start),b=source.indexOf(end,a);if(a<0||b<0)throw Error('missing '+start);return source.slice(a,b);}
const T=eval(source.slice(0,source.indexOf('  var Kn = {'))+'return ut;})()');
const math=between('  var RE = St,','  function Ru(');
const timingText=between('    ft = {','  var xU = '),timings=new Function('let '+timingText+'return {rifle:ft,pistol:It};')();
const eventsText=between('    function f(B, X, re, Y) {','    let p = vS('),makeEvent=new Function('n',eventsText+'return f;');
const rifleHead=between('      reload(B, X) {','        let Re = O.pose;').replace('reload(B, X) {','return function(B, X) {');
const rifleTail=between('        let Ue = Ot(X / 0.3)', '      },\n      endReload()');
const pistolHead=between('      reload(ge, ce) {','        let B = 0,').replace('reload(ge, ce) {','return function(ge, ce) {');
const pistolTail=between('          (i.reloadW = Math.min(', '      },\n      endReload()');
const windows='const '+between('    B1 = (n, e, t) =>','    Uh = ').trim().replace(/,$/,';')+'const '+between('    H1 = (n, e, t) =>','    Yy = ').trim().replace(/,$/,';');
const stateText=rifleHead+rifleTail+pistolHead+pistolTail;
function make(gun,state,ev,arm){
 const prelude='const St=THREE.Quaternion;'+math+';'+windows;
 const body=gun==='rifle'?`let $=false,se=0;const yS=0;const f={visible:false},x={left:{impulse:arm}},F={partial:true};${rifleHead}${rifleTail}};`:`let xe=false;const d={visible:false},b={left:{impulse:arm}};${pistolHead}${pistolTail}};`;
 return new Function('THREE','s','i','ft','It','n','arm',prelude+body)(T,state,state,timings.rifle,timings.pistol,{ev},arm);
}
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/prepared/scene.json'),'utf8')),cases=[];
for(const gun of ['rifle','pistol'])for(const empty of [false,true])for(const mode of ['dense','boundary','coarse-revisit']){
 const initial=structuredClone(data.modules.weapon.debug.S),state=structuredClone(initial),events=[],arm=[],traces=[];
 const ev=makeEvent({events:{emit:(_,event)=>{events.push(structuredClone(event));traces.push({phase:event.phase,ammo:reload.rig.slot.ammo,reserve:reload.rig.slot.reserve,bump:state.bump.v,kZ:state.kZ.v,kP:state.kP.v,kR:state.kR.v});}}}),method=make(gun,state,ev,value=>arm.push(value));
 const duration=timings[gun][empty?'empty':'tac'],reload={t:0,T:duration,empty,f:{},seated:false,rig:{id:gun,slot:{ammo:empty?0:6,magSize:gun==='rifle'?30:15,reserve:100}}};
 const reloadInitial=structuredClone(reload);
 let times=[];
 if(mode==='dense')for(let i=0;i<Math.ceil((duration+.1)*240);i++)times.push(i/240);
 if(mode==='boundary'){
  for(const value of Object.values(timings[gun]).filter(x=>typeof x==='number'))for(const offset of [-1e-9,0,1e-9])times.push(value+offset);
  const derived=gun==='rifle'?[.3,timings.rifle.magin+.08,timings.rifle.magin+.36,timings.rifle.atHandle-.04]:[.22,timings.pistol.magin+.03,timings.pistol.magin+.35,timings.pistol.magin+.05,timings.pistol.magin+.33,timings.pistol.slide+.04,timings.pistol.slide+.28,timings.pistol.thumb-.08];
  for(const value of [...derived,0,.03,timings[gun].magout-.14,timings[gun].insert-.1,timings[gun].regrip+.025,duration-.46,duration-.06,duration,duration+.1])for(const offset of [-1e-9,0,1e-9])times.push(value+offset);
  times.sort((a,b)=>a-b);
 }
 if(mode==='coarse-revisit')times=[0,0,.3,1.5,.2,1.5,2.3,2.3,.1,3,0,3];
 const steps=[];
 for(const time of times){reload.t=time;method(reload,time);steps.push({time,event_time:time,expected:{state:structuredClone(state),flags:structuredClone(reload.f),events:structuredClone(events),arm_impulses:arm.length,slot:structuredClone(reload.rig.slot),seated:reload.seated,traces:structuredClone(traces)}});}
 const productionState=structuredClone(initial),productionReload=structuredClone(reloadInitial),productionEvents=[],productionTraces=[],productionArm=[];
 const productionEv=makeEvent({events:{emit:(_,event)=>{productionEvents.push(structuredClone(event));productionTraces.push({phase:event.phase,ammo:productionReload.rig.slot.ammo,reserve:productionReload.rig.slot.reserve,bump:productionState.bump.v,kZ:productionState.kZ.v,kP:productionState.kP.v,kR:productionState.kR.v});}}});
 const productionMethod=make(gun,productionState,productionEv,value=>productionArm.push(value));
 for(const time of times){if(time>=duration)break;productionReload.t=time;productionMethod(productionReload,time);}
 productionReload.t=duration;productionMethod(productionReload,duration);
 productionState.reloadW=productionState.rackW=productionState.antYT=productionState.antRT=0;
 const production_final={state:productionState,slot:productionReload.rig.slot,seated:productionReload.seated,events:productionEvents,traces:productionTraces,arm_impulses:productionArm.length};
 cases.push({gun,empty,mode,initial,duration,steps,production_final});
}
const report={source_sha256:crypto.createHash('sha256').update(source).digest('hex'),state_segments_sha256:crypto.createHash('sha256').update(stateText).digest('hex'),timings,cases,scope:'Original literal state-bearing reload prefix and suffix with original event f/h; geometry/arms-target middle is intentionally omitted. Dense240Hz/boundaries/coarse duplicate and backward timestamps, both guns and empty/tactical; no production integration or parts/IK proof.'};
fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-reload-motion-reference.json'),JSON.stringify(report));console.log(JSON.stringify({cases:cases.length,steps:cases.reduce((sum,c)=>sum+c.steps.length,0),source_sha256:report.source_sha256,state_segments_sha256:report.state_segments_sha256}));
