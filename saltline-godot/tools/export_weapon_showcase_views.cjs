// Literal BD camera table extraction; executes only the bounded object expression.
const fs=require('node:fs');
const vm=require('node:vm');
const crypto=require('node:crypto');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const source=path.resolve(root,'../artifact-rendering-study/source/extracted/bundle-1.js');
const text=fs.readFileSync(source,'utf8');
const start=text.indexOf('      s = {',text.indexOf('async function BD('))+10;
const end=text.indexOf(',\n      o = window.__setShot',start);
if(start<10||end<start)throw Error('BD table boundary missing');
const views=vm.runInNewContext('('+text.slice(start,end).trim()+')',{}, {timeout:1000});
if(Object.keys(views.rifle).length!==8||Object.keys(views.pistol).length!==7)throw Error('Unexpected BD view count');
const output=path.join(root,'assets/export/weapon-showcase-views.json');
fs.writeFileSync(output,JSON.stringify(views,null,2)+'\n');
fs.writeFileSync(output.replace('.json','.provenance.json'),JSON.stringify({source:'artifact-rendering-study/source/extracted/bundle-1.js',sha256:crypto.createHash('sha256').update(text).digest('hex'),function:'BD',table:'s',rifle:8,pistol:7},null,2)+'\n');
console.log('Exported 15 BD inspection views');
