const fs=require('fs'),source=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
class Vec{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}copy(v){Object.assign(this,v);return this}toJSON(){return [this.x,this.y,this.z]}}
const callbacks={},n={time:{frame:0},events:{on:(key,fn)=>callbacks[key]=fn}};
const emit=(key,value)=>callbacks[key](value);
const g=Array.from({length:4},()=>({el:{style:{}},life:0,src:new Vec(),op:-1,rot:1e9}));
let me=[],P=null,D=-1,se=0,fe=0;const m={classList:{remove(){}}},S=m;
const si=(_,__,html)=>({innerHTML:html,remove(){},classList:{add(){}}}),w={appendChild(){}},y={className:'',animate(keys,options){animations.push({keys,options})}},animations=[];
let X;const begin=source.indexOf('      n.events.on("player:hitEnemy"');const end=source.indexOf('    let X = {',begin);
eval(source.slice(begin,end));
const methods=source.slice(source.indexOf('      feed(he) {',end),source.indexOf('      reset() {',end));
X=eval('({'+methods+'})');
const arcStart=source.indexOf('      for (let $e of g) {',end),arcEnd=source.indexOf('      if (xe < le.length)',arcStart);
const feedStart=source.indexOf('      for (let $e = me.length - 1;',arcEnd),feedEnd=source.indexOf('    function Y(he)',feedStart);
const arcCode=source.slice(arcStart,arcEnd),feedCode=source.slice(feedStart,feedEnd).replace(/    }\s*$/,'');
const frames=[];
for(let frame=0;frame<600;frame++){
 n.time.frame=frame;let actions=[];
 const fire=(type,value)=>{actions.push({type,...value});if(type==='damage')emit('player:hit',{fromPos:value.pos?new Vec(...value.pos):null});else if(type==='kill')emit('enemy:killed',{type:value.kind});else emit('player:hitEnemy',value)};
 if([0,1,2,3,4,14,55,56,57].includes(frame))fire('damage',{pos:[Math.sin(frame)*8,0,Math.cos(frame)*8]});
 if(frame===12)fire('damage',{pos:null});
 if([5,10,15,20,25,30,90,300,301].includes(frame)){fire('kill',{kind:frame%2?'hound':'gull'});fire('hit',{killed:true,weak:frame%2===1,part:'body'})}
 if(frame===31)fire('hit',{killed:true,weak:true,part:'weak'});
 if(frame===35||frame===80)fire('hit',{killed:false,weak:false,part:frame===80?'weak':'body'});
 if(frame===160){actions.push({type:'reset'});for(const e of me)e.el.remove();me.length=0;for(const e of g)e.life=0}
 const dt=[1/60,.05,.001,.1][frame%4],shown=!(frame>=60&&frame<100),V={pos:new Vec(Math.sin(frame*.1),0,Math.cos(frame*.1)),yaw:Math.sin(frame*.13)*Math.PI},he=dt;
 if(shown){eval(arcCode);eval(feedCode)}
 frames.push({frame,dt,shown,pos:V.pos,yaw:V.yaw,actions,arcs:g.map(e=>({life:e.life,src:e.src,op:e.op,rot:e.rot})),feed:me.map(e=>({kind:e.el.innerHTML.match(/<b>(.*?)<\/b>/)[1],weak:e.weak,life:e.life,out:!!e.out})),hitKind:y.className.replace('h-hit ','')||'hit',lastKill:D});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/combat-feedback-reference.json',JSON.stringify({frames,animations}));console.log({frames:frames.length,animations:animations.length});
