const fs=require('fs'),crypto=require('crypto');
const source=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const start=source.indexOf('    function Y(he) {',source.indexOf('      clearRadio() {'));
const update=source.slice(start,source.indexOf('    return B(), X;',start));
const rules=JSON.parse(fs.readFileSync('saltline-godot/assets/game-rules.json'));
let O=[],q=null,ue=0,de=0,$=0,visible=false,started=[];
const Q={textContent:''},Z={classList:{add:()=>visible=true,remove:()=>visible=false}},n={events:{emit:(_,v)=>started.push(v.text)}};
eval(update);
const frames=[];
for(let frame=0;frame<720;frame++){
 const actions=[];
 const add=(text,secs)=>{actions.push({type:'add',text,secs});if(text)O.push({text,secs})};
 const clear=()=>{actions.push({type:'clear'});O.length=0;q=null;visible=false};
 if(frame===0){add(rules.radio.intro,1.2);add(rules.radio.contact,.4);add('',3)}
 if(frame===150){clear();add(rules.radio.low,.1)}
 if(frame===250){add('A',0);add('Next',.05)}
 if(frame===320){add(rules.radio.all,1);add(rules.radio.done,.6)}
 if(frame===440)clear();
 if(frame===460)add('Hold',.2);
 if(frame===500){clear();add('Replacement after reset',.3)}
 const dt=[1/60,.05,.001,.1][frame%4];Y(dt);
 frames.push({actions,dt,text:Q.textContent,visible,cursor:ue,typed:de,remaining:$,current:q,queue:JSON.parse(JSON.stringify(O)),started:[...started]});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/radio-reference.json',JSON.stringify({sha256:crypto.createHash('sha256').update(source).digest('hex'),frames}));
console.log({frames:frames.length,started:started.length});
