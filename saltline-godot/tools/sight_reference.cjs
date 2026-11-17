const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const start=text.indexOf('(a, l) => {',text.indexOf('(o.onBeforeRender =',text.indexOf('  function ME(')));
let brace=text.indexOf('{',start),depth=1,end=brace+1;while(depth){if(text[end]==='{')depth++;if(text[end]==='}')depth--;end++}
let r=0,s={uniforms:{uEnv:{value:1}}};const update=eval('('+text.slice(start,end)+')');const frames=[];
for(let frame=0;frame<600;frame++){
 const intensity=frame<60?1:frame<150?.3:frame<200?.6:frame<260?0:frame<330?2:frame<430?.7:frame<500?1:2;
 update(null,{environmentIntensity:intensity});frames.push({intensity,peak:r,value:s.uniforms.uEnv.value});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/sight-environment-reference.json',JSON.stringify({frames}));console.log({frames:frames.length,final:frames.at(-1)});
