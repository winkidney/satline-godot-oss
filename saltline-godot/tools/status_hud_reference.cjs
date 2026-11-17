const fs=require('fs'),source=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const start=source.indexOf('      let _e = Math.max(1, Math.min(60, ne.magSize');const end=source.indexOf('      for (let $e of g) {',start);
const run=new Function('ne','V','n',`const el=()=>({classes:{},textContent:'',className:'',classList:{toggle(name,on){this.parent.classes[name]=on}}});const make=()=>{const e=el();e.classList.parent=e;return e};const oe={hp:-1,hpSeg:-1},U=make(),k=make(),A=make(),H=make(),F=make(),L=make(),z=make(),R=make(),I=Array.from({length:10},make);let ee=[];const C={children:[]};Object.defineProperty(C,'innerHTML',{set(value){C.children=Array.from({length:(value.match(/<i>/g)||[]).length},make)}});`+source.slice(start,end)+`return {mag:oe.mag,ammo:oe.ammo,reserve:oe.reserve,ammo_text:U.textContent,reserve_text:k.textContent,low:oe.low,cue:oe.cue,urgent:F.className.includes('urgent'),health:oe.hp,segments:oe.hpSeg,hurt:oe.hurt,critical:R.classes.crit};`);
const cases=[];
for(let i=0;i<800;i++){
 const data={mag:[0,15,30,60,80,-1][i%6],ammo:[0,1,4,8,9,15,30,-1,62][i%9],reserve:[0,1,150,9999,Infinity][i%5],state:['idle','reloading','switching','firing','sprinting'][i%5],health:[100,99.6,99.5,99.49,71.1,30,29.1,20.01,0,-1][i%10],max_health:100,has_alt:i%3!==0,device:i%4===0?'pad':i%4===1?'touch':'mouse',touch:i%4===1};
 const ne={magSize:data.mag,ammo:data.ammo,reserve:data.reserve,state:data.state,name:'Test',current:'a',slots:data.has_alt?[{id:'a',name:'A',ammo:0,reserve:0},{id:'b',name:'B',ammo:15,reserve:Infinity}]:[]};
 const expected=run(ne,{health:data.health,maxHealth:data.max_health},{input:{device:data.device,touch:data.touch}});
 cases.push({data:{...data,reserve:Number.isFinite(data.reserve)?data.reserve:'infinity'},expected});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/status-hud-reference.json',JSON.stringify({cases}));console.log({cases:cases.length});
