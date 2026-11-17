const fs=require('fs');
const root=__dirname+'/..';
const source=fs.readFileSync(root+'/../artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const start=source.indexOf('Yg = class {',source.indexOf('var c1 = 4'));
const end=source.indexOf('\n    qP = [',start);
const qP=['fx','fy','fz','dx','dy','dz','dist','speed','trav','len','width','r','g','b'];
const Class=eval('('+source.slice(start,end).trim().replace(/^Yg = /,'').replace(/,$/,'')+')');
Math.random=()=>.5;
const pool=new Class();
pool.add({x:0,y:1,z:0},{x:0,y:1,z:-20},16,12.8,7.36,260,.024);
const frames=[];
for(let i=0;i<12;i++){
 const quads=[];
 pool.update(1/60,{push(...args){quads.push(args)}},7,0);
 frames.push({count:pool.n,travel:pool.n?pool.trav[0]:null,quads});
}
fs.writeFileSync(root+'/evidence/tracer-source-fixtures.json',JSON.stringify(frames));
console.log('Original Yg tracer reference: 12 frames');
