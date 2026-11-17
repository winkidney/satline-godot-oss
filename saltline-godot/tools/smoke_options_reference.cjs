const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const body=source.slice(source.indexOf('    function I(j, O = {}) {',source.indexOf('var e5 =')),source.indexOf('    function I(j, O = {}) {',source.indexOf('var e5 ='))+2500);
const match=body.match(/    function I\(j, O = \{\}\) \{[\s\S]*?\n    \}/);if(!match)throw Error('Source smoke missing');
const cases=[['defaults',{}],['zero defaults',{size:0,life:0,count:0,alpha:0}],['fraction count',{count:2.25}],['negative count',{count:-1}],['null rise',{rise:null}],['explicit rise zero',{rise:0}],['custom',{size:.3,life:.9,rise:1.4,count:1,alpha:.25}],['nan count',{count:NaN}]];
const result=cases.map(([name,options])=>{const tape=Array.from({length:256},(_,i)=>((i*73+19)%251)/251);let draws=0,rows=[];const Et=()=>tape[draws++],lt=(a,b)=>a+(b-a)*Et(),ph=()=>[.32,.32,.33],g=()=>.2,M=(...a)=>rows.push([...a.slice(0,9),a[12],Number(a[15])]);eval(match[0]+';I({x:1,y:2,z:3},options)');return{name,options,tape,draws,rows};});
fs.writeFileSync(path.join(__dirname,'../evidence/smoke-options-reference.json'),JSON.stringify(result,null,2));
