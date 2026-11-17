const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=fs.readFileSync(path.resolve(__dirname,'../../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const start=source.indexOf('setPrompt(he, V = 0) {',source.indexOf('function sT(n)'));let end=source.indexOf('{',start)+1,depth=1;while(depth){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}const method=source.slice(start,end);
function element(){return {textContent:'',classes:{},attrs:{},classList:{toggle(k,v){this.owner.classes[k]=v}},setAttribute(k,v){this.attrs[k]=v}};}
const E=element(),key=element(),T=element(),M=element();for(const e of [E,key,T,M])e.classList.owner=e;
key.textContent='E';M.attrs['stroke-dashoffset']='119.38';
const n={input:{touch:false,device:'mouse',setPrompt(){}}},oe={promptOn:false,promptKey:'E',promptText:'',promptT:0};
const api=Function('E','_','T','M','n','oe','rb','return ({'+method+'});')(E,key,T,M,n,oe,2*Math.PI*19);
const ops=[{value:null,t:0},{value:'Cut relay A',t:0}];
for(const device of ['mouse','pad','touch'])for(const t of [0,.0024,.0025,.0026,.123456,.5,.999,1])ops.push({value:'Cut relay B',t,device});
ops.push({value:null,t:0},{value:'Cut relay C',t:.25,device:'mouse'},{value:'',t:0});
const rows=[];for(const op of ops){n.input.touch=op.device==='touch';n.input.device=op.device||'mouse';api.setPrompt(op.value,op.t);rows.push({op,expected:{active:oe.promptOn,key:key.textContent,text:T.textContent,progress:oe.promptT,dash_offset:Number(M.attrs['stroke-dashoffset']),busy:!!E.classes.busy,wide:!!key.classes.wide}});}
fs.writeFileSync(path.resolve(__dirname,'../assets/export/fixtures/interaction-reference.json'),JSON.stringify({rows,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),method_sha256:crypto.createHash('sha256').update(method).digest('hex')}));console.log({rows:rows.length});
