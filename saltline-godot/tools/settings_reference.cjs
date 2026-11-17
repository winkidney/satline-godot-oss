const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=fs.readFileSync(path.resolve(__dirname,'../../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const methods=source.slice(source.indexOf('  var lT = "saltline.settings.v1"'),source.indexOf('  function cc(n) {'));
let raw='null';const load=Function('localStorage','zi',methods+';return iL;')({getItem:()=>raw},{fov:74});
const cases=['null','[]','{}','false','0','"text"','{broken','',JSON.stringify({quality:'ultra',sens:1.85,invertY:true,fov:87,difficulty:'brutal',mode:'holdout',view:3})];
for(const value of [null,true,false,0,-100,1,2,3,999,'2','',[],{},[1],NaN,Infinity])cases.push(JSON.stringify({quality:value,sens:value,invertY:value,fov:value,difficulty:value,mode:value,view:value}));
for(const quality of ['auto','low','medium','high','ultra','bad'])cases.push(JSON.stringify({quality,sens:.1,fov:200,difficulty:'standard',mode:'mission',view:2}));
const rows=cases.map(value=>{raw=value;const expected=load();delete expected.volume;return {raw,expected};});fs.writeFileSync(path.resolve(__dirname,'../assets/export/fixtures/settings-reference.json'),JSON.stringify({rows,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),methods_sha256:crypto.createHash('sha256').update(methods).digest('hex')}));console.log({cases:rows.length});
