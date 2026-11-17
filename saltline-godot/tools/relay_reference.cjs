const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
function body(marker){const a=text.indexOf('{',text.indexOf(marker));let depth=0;for(let i=a;i<text.length;i++){if(text[i]==='{')depth++;if(text[i]==='}'&&--depth===0)return text.slice(a,i+1)}}
let q='live',ue=.9,de=0,$=.7,se=0,fe=0,me=0,spin=0,door=0;const gv=16752680,Dk=16767392,zk=16721940,is=Math.PI,ge={},j={copy(value){this.value=value;return this}},O=(color,level)=>{};
const xe=[{rotateY:value=>spin+=value}],le=[{rotateY:value=>door+=value}];const set=eval('(ce)=>'+body('ge.setState = (ce) =>')),update=eval('(ce)=>'+body('ge.update = (ce) =>'));
const frames=[];for(let frame=0;frame<300;frame++){
 if(frame===20)set('cutting');if(frame===60)set('cut');if(frame===160)set('live');if(frame===190)set('cutting');if(frame===230)set('cut');
 const dt=frame===10?.2:.05;update(dt);frames.push({dt,state:q,phase:ue,cutTime:de,spinSpeed:$,hinge:se,hingeVelocity:fe,hingeTarget:me,level:ge.level,color:j.value,spin,door});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/relay-reference.json',JSON.stringify({frames,scope:'Actual original relay setState/update; live pulse, cutting flicker/spinner, cut fade and spring hinge, reset and dt cap'}));console.log({frames:frames.length});
