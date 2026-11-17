const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');const at=s.indexOf('        he.smoke &&',s.indexOf('  async function I5(n)')),end=s.indexOf('      let Ve = ',at),body=s.slice(at,end),run=Function('a','B','he','n','S','A',body);
const state={t:0,lastShot:-9,heat:0,smoke:0,smokeTick:0},ops=[
 {time_before:.1,last_shot:0,heat:.400001,dt:.01},
 {time_before:.100001,last_shot:0,heat:.4,dt:.01},
 {time_before:.100001,last_shot:0,heat:.400001,dt:.01},
 {time_before:.115,last_shot:0,heat:.5,dt:.01},
 {time_before:.1149999,last_shot:0,heat:.5,dt:.01},
 {heat:.7,smoke:.2,smokeTick:.005,gun:'pistol',dt:.01},
 {smoke:.001,smokeTick:0,gun:'pistol',dt:.01},
 {smoke:.2,smokeTick:0,available:false,dt:.02},
 {available:true,dt:.02},
 {reset:true},
 {smoke:.4,smokeTick:.01,dt:.01}];for(let i=0;i<45;i++)ops.push({dt:1/60,gun:i%7===0?'pistol':'rifle'});ops.push({reset:true},{dt:.016666667});
let gun='rifle',available=true;const rows=[];
for(const op of ops){const requests=[];
 if(op.reset){state.heat=0;state.smoke=0;gun='rifle';}
 else{if(op.time_before!==undefined)state.t=op.time_before;if(op.last_shot!==undefined)state.lastShot=op.last_shot;for(const key of ['heat','smoke','smokeTick'])if(op[key]!==undefined)state[key]=op[key];if(op.gun)gun=op.gun;if(op.available!==undefined)available=op.available;state.t+=op.dt;run(state,op.dt,{smoke:gun==='rifle'},{fx:available?{smoke:(_position,options)=>requests.push(options)}:{}},()=>{},{});}
 rows.push({op,expected:{...state,gun,available,requests}});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-smoke-reference.json'),JSON.stringify({rows,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(body).digest('hex'),scope:'Literal original I5 O smoke block through heat decay; production smoke availability guard, rifle/pistol, strict timing/heat boundaries, ongoing expiration, reset preserving tick. Source reset smoke/heat assignments supplied; not full O or muzzle transform.'}));console.log(JSON.stringify({steps:rows.length,requests:rows.reduce((n,r)=>n+r.expected.requests.length,0)}));
