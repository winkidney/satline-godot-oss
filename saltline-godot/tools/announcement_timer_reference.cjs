const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=fs.readFileSync(path.resolve(__dirname,'../../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function body(marker,from){let start=source.indexOf(marker,from),end=source.indexOf('{',start)+1,depth=1;while(depth){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}return source.slice(start,end);}
const start=source.indexOf('function sT(n)'),warn=body('warn(he, V = 3) {',start),message=body('message(he, V = 3) {',start);
const a=source.indexOf('se > 0 && ((se -= he)',start),b=source.indexOf('for (let $e = me.length',a),timers=source.slice(a,b).trim().replace(/;$/,'');
const create=Function(`let se=0,fe=0;const node=()=>({textContent:'',on:false,offsetWidth:1,classList:{remove(){this.owner.on=false},add(){this.owner.on=true},toggle(k,v){this.owner.on=v}}});const m=node(),S=node();m.classList.owner=m;S.classList.owner=S;return {${warn},${message},tick(he,on){if(on){${timers};}},snapshot(){return {warning_remaining:se,message_remaining:fe,warning_on:m.on,message_target:S.on}}};`);
const pool=create(),ops=[{kind:'warn',text:'Machines inbound',duration:3},{kind:'message',text:'Relay cut',duration:2}];
for(let i=0;i<60;i++)ops.push({kind:'update',dt:[.016,.05,.1][i%3],on:i<12||i>=40});
for(const duration of [0,-1,.03]){ops.push({kind:'warn',text:'Contact',duration},{kind:'message',text:'Stand by',duration});for(let i=0;i<4;i++)ops.push({kind:'update',dt:.02,on:true});}
ops.push({kind:'message',text:'',duration:3});
const rows=[];for(const op of ops){if(op.kind==='warn')pool.warn(op.text,op.duration);else if(op.kind==='message')pool.message(op.text,op.duration);else pool.tick(op.dt,op.on);rows.push({op,expected:pool.snapshot()});}
fs.writeFileSync(path.resolve(__dirname,'../assets/export/fixtures/announcement-timer-reference.json'),JSON.stringify({rows,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),methods_sha256:crypto.createHash('sha256').update(warn+message+timers).digest('hex')}));console.log({rows:rows.length});
