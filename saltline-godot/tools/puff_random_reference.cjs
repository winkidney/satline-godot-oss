const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
const at=s.indexOf('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)'),last=s.indexOf('    function _(',at),method=s.slice(at,last);
let calls=0;const tape=Array.from({length:256},(_,i)=>Math.round((((i*79+17)%257)/257)*2**53)/2**53),MathProxy=Object.create(Math);MathProxy.random=()=>tape[calls++];
const Pool=Function('Math','return ('+particle+');')(MathProxy),l=new Pool(3,true),M=Function('l','Et',method+'return M;')(l,MathProxy.random);
const rows=[];
for(let i=0;i<20;i++){
 if(i===6||i===13)l.clear();
 const frame=i%2===0?-1:7;
 const id=M(.1,.2,.3,.4,.5,.6,.7,.8,.9,.11,.22,.33,.44,.55,.66,.77,.88,frame);
 const result=id<0?null:Object.fromEntries(['seed','rot','rotv','frame','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk'].map(k=>[k,l[k][id]]));
 rows.push({frame,result,calls});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/puff-random-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+method).digest('hex'),tape,tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),rows,scope:'Literal original M and u1; capacity3, rejection, clear, fixed/random frame; all post-emit random calls conditional on success.'}));
console.log(JSON.stringify({steps:rows.length,calls}));
