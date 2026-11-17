const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');const {T}=require('./weapon_magazine_reference.cjs');const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8'),offset=s.indexOf('  function yE(n) {');
const prefix='n.events.on("explosion", ',start=s.indexOf(prefix,offset)+prefix.length,end=s.indexOf('    function m(v) {',start),chain=s.slice(start,end).trim().slice(0,-2);
const a=s.indexOf('      update(v) {',end),b=s.indexOf('    };\n  }',a),update=s.slice(a,b).trim().replace(/,$/,'');
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/prepared/scene.json'),'utf8')),t=data.modules.explosives.items.map(v=>({...structuredClone(v),pos:new T.Vector3(...v.pos.map(Math.fround)),leak:new T.Vector3(...v.leak.map(Math.fround)),leakDir:new T.Vector3(...v.leakDir.map(Math.fround))}));
const su=Function(s.slice(s.indexOf('  function su(n = 1337)'),s.indexOf('  var Hn = '))+'return su;')(),seed=1883172587,raw=su(seed);let calls=0;const random=()=>{calls++;return raw()};for(let j=0;j<15;j++)random();
const callback=Function('t','s','return ('+chain+');')(t,random),requests=[];
const n={fx:{sparks(){requests.push('sparks')},smoke(){requests.push('smoke')}},render:{lightPool:{flash(){requests.push('light')}}}},api=Function('t','n','a','m','return ({'+update+'});')(t,n,new T.Vector3(),()=>{throw Error('unexpected detonation')});
const rows=[];for(let j=0;j<180;j++){
 requests.length=0;let input;
 if(j%9===0){input={action:'reset'};for(const v of t){v.alive=true;v.hp=v.spec.hp;v.fuse=-1;}}
 else if(j%3===0){input={action:'leak',index:j%t.length};t[input.index].fuse=1.6;t[input.index].tick=0;api.update(0);}
 else{const center=t[(j*7)%t.length].pos.clone().add(new T.Vector3(.2*(j%3),0,-.1)).toArray().map(Math.fround);input={action:'chain',position:center,size:[.7,1,2][j%3]};callback({pos:new T.Vector3().fromArray(center),size:input.size});}
 rows.push({input,expected:{fuses:t.map(v=>v.fuse),ticks:t.map(v=>v.tick),rng_state:(seed+Math.imul(calls,1831565813))>>>0,rng_calls:calls,requests:requests.slice()}});
}
const result={source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(chain+update).digest('hex'),rows,scope:'Literal original explosion event callback and explosives.update dt0 leak branch; source positions quantized to native storage before original evaluation. Source su post15 baked yaw draws. FX/light request receivers mocked; no particle random/output proof.'};fs.writeFileSync(path.join(root,'assets/export/fixtures/explosive-stream-reference.json'),JSON.stringify(result));console.log(JSON.stringify({steps:rows.length,methods_sha256:result.methods_sha256}));
