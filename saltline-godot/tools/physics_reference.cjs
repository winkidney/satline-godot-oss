const fs=require('fs');
const root=__dirname+'/..';
const source=fs.readFileSync(root+'/../artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const start=source.indexOf('moveCapsule(M, _, T,');
const end=source.indexOf('\n        nav: {',start);
const text=source.slice(start,end).trim().replace(/,$/,'');
const data=JSON.parse(fs.readFileSync(root+'/assets/prepared/scene.json'));
const vec=a=>({x:a[0],y:a[1],z:a[2]});
const e=data.physics.boxes.map(b=>({...b,min:vec(b.min),max:vec(b.max)}));
const Kn={groundY:0,seaY:-1.6,quayX:30},hg=.42,n={};
const solver=eval('({'+text+'})');
let seed=4207;const rng=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
const cases=[];
for(let i=0;i<400;i++){
 let p,v,ground;
 if(i<200){const b=e[i%e.length];p={x:b.min.x+(rng()*2-.5)*(b.max.x-b.min.x),y:b.max.y+(rng()-.5)*.9,z:b.min.z+(rng()*2-.5)*(b.max.z-b.min.z)};}
 else p={x:-40+rng()*82,y:rng()*4,z:-30+rng()*60};
 v={x:(rng()-.5)*15,y:(rng()-.5)*20,z:(rng()-.5)*15};ground=rng()>.5;
 const height=rng()>.5?1.8:1.15,dt=1/60;const before={...p},velocity={...v};
 const result=solver.moveCapsule(p,v,dt,.32,height,ground);
 cases.push({pos:Object.values(before),vel:Object.values(velocity),dt,height,ground,position:Object.values(p),velocity:Object.values(v),on_ground:result.onGround,hit_wall:result.hitWall,hit_ceil:result.hitCeil});
}
fs.writeFileSync(root+'/evidence/physics-source-fixtures.json',JSON.stringify(cases));
console.log('400 fixtures generated directly from active original moveCapsule');
