const fs=require('node:fs'),path=require('node:path'),core=require('./decal_reference_core.cjs');const root=path.resolve(__dirname,'..'),tape=Array.from({length:2048},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>tape[calls++];const p=core.create(M),rows=[];
const kinds=['bullet_metal','bullet_concrete','bullet_wood','scorch','soot','bullet_glass','unknown'],normals=[[0,1,0],[1,0,0],[.3,.7,-.2],[0,0,0],[.000001,.000002,.000003]];
for(let i=0;i<175;i++){
 const op={point:[(i%13)*1.7,1.1,-(i%17)*1.3].map(Math.fround),normal:normals[i%normals.length].map(Math.fround),kind:kinds[i%kinds.length],size:i%11===0?-.2:i%5===0?.43:0,shade:.2+(i%4)*.2,alpha:i%3===0?.8:.92};const [x,y,z]=op.point,[nx,ny,nz]=op.normal;p.add({x,y,z},{x:nx,y:ny,z:nz},op.kind,op.size,op.shade,op.alpha);
 if(i<12||i>=158)rows.push({index:i,op,calls,expected:core.snapshot(p)});else rows.push({index:i,op,calls,expected:null});
}
p.clear();rows.push({op:{clear:true},calls,expected:core.snapshot(p)});
for(let i=0;i<2;i++){const op={point:[1,2,3],normal:i?[0,0,0]:[0,1,0],kind:i?'bullet_wood':'unknown',size:0,shade:.7,alpha:.8};const[x,y,z]=op.point,[nx,ny,nz]=op.normal;p.add({x,y,z},{x:nx,y:ny,z:nz},op.kind,op.size,op.shade,op.alpha);rows.push({index:'post-clear-'+i,op,calls,expected:core.snapshot(p)});}
fs.writeFileSync(path.join(root,'assets/export/fixtures/decal-random-reference.json'),JSON.stringify({tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),rows,source_sha256:core.source_sha256,methods_sha256:core.methods_sha256}));console.log(JSON.stringify({steps:rows.length,calls}));
