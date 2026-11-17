const fs=require('fs');const root=__dirname+'/..';const source=fs.readFileSync(root+'/../artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const start=source.indexOf('u1 = class {',source.indexOf('var c1 = 4'));const end=source.indexOf('\n    Yg = class {',start);const hh=1,dh=2,GP=4;
const Class=eval('('+source.slice(start,end).trim().replace(/^u1 = /,'').replace(/,$/,'')+')');Math.random=()=>.5;
const cases=[
 {position:[0,.04,-3],velocity:[1,-1,-.2],life:1.37,s0:.04,s1:.015,options:{seed:50.25,gravity:9.81,drag:.9,wind:1,turbulence:.8,flags:1,ramp:1,color:[24,15,6],mode:1,frame:1,stretch:.03}},
 {position:[1,1,-6],velocity:[.2,.3,.4],life:.73,s0:.2,s1:.6,options:{seed:12.5,ramp:2,fade_in:.12,fade_out:.4,color:[9,5.5,2.2],rotation_speed:1.5,frame:5}},
 {position:[-1,.03,-4],velocity:[0,-1,0],life:1.37,s0:.03,s1:.01,options:{flags:2,gravity:9.81,frame:6}},
 {position:[.5,.03,-5],velocity:[1,-1,0],life:1.37,s0:.05,s1:.02,options:{flags:4,ramp:3,seed:24.1,color:[10,4.2,1]}}
];
const pool=new Class(4,true);const mapping={seed:'seed',gravity:'grav',drag:'drag',wind:'wind',turbulence:'turb',flags:'flags',ramp:'ramp',mode:'mode',frame:'frame',stretch:'stretch',fade_in:'fin',fade_out:'fout',rotation_speed:'rotv'};
for(const c of cases){let id=pool.emit(...c.position,...c.velocity,c.life,c.s0,c.s1);for(const [key,value] of Object.entries(c.options)){if(key==='color'){pool.r[id]=value[0];pool.g[id]=value[1];pool.b[id]=value[2]}else pool[mapping[key]][id]=value}}
const frames=[];for(let i=0;i<92;i++){const quads=[];pool.update(1/60,{push(...q){quads.push(q);return true}},{x:0,y:0,z:0},{x:-.8,y:0,z:.3},(i+1)/60);frames.push(quads)}
fs.writeFileSync(root+'/evidence/particle-source-fixtures.json',JSON.stringify({cases,frames}));console.log('Original u1 particle reference: 4 particles, 92 frames');
