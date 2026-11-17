const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=fs.readFileSync(path.resolve(__dirname,'../../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function block(marker,from=0){const start=source.indexOf(marker,from);let end=source.indexOf('{',start)+1,depth=1;if(start<0)throw Error(marker);while(depth){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}return source.slice(start,end);}
const initial={scale:1,enabled:true,acc:0,n:0,settle:3.5,upWait:4,upDelay:4};
const method=block('function R(G) {',source.indexOf('enabled: !(e.shot')),presets=Function('return ('+block('jr = {').replace(/^jr = /,'')+');')();
const specs=[{name:'outlier',quality:'high',frames:[1501,2000,1500,0,16,50]},{name:'disabled',quality:'high',patch:{enabled:false},frames:[16,100,1500]},{name:'post-unavailable',quality:'high',post:false,frames:[16,100,1500]},{name:'degrade-and-recover',quality:'ultra',frames:[...Array(350).fill(50),...Array(7000).fill(10)]}];
for(const ms of [17.3999,17.4,21.5,21.5001,26,26.0001,30,30.0001,45,45.0001])for(const scale of [.6,.7,1])specs.push({name:`boundary-${ms}-${scale}`,quality:'high',patch:{scale,settle:0,acc:44*ms,n:44,upWait:0,floorHits:1},frames:[ms]});
specs.push({name:'up-delay-cap',quality:'high',patch:{settle:0,acc:44*31,n:44,upWait:0,upDelay:40},frames:[31]});
specs.push({name:'low-floor-remains-low',quality:'low',patch:{scale:.6,settle:0,acc:44*50,n:44,upWait:0,floorHits:4},frames:Array(101).fill(50)});
const cases=[];
for(const spec of specs){const state={...initial,...spec.patch},n={quality:{...presets[spec.quality]},events:{emit(kind,value){events.push({kind:'auto',name:value.name});}}};let events=[];
 const Q={resize(){events.push({kind:'resize'});},setQuality(value){n.quality=value;events.push({kind:'quality',name:value.name});}};
 const run=Function('S','M','n','Q','jr','console',method+'return R;')(state,spec.post!==false,n,Q,presets,{log(){}});const rows=[];
 for(const ms of spec.frames){events=[];run(ms);rows.push({ms,state:{...state},quality:n.quality.name,events});}
 cases.push({name:spec.name,initial:{...initial,...spec.patch},quality:spec.quality,post:spec.post!==false,rows});
}
fs.writeFileSync(path.resolve(__dirname,'../assets/export/fixtures/dynamic-resolution-reference.json'),JSON.stringify({cases,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),method_sha256:crypto.createHash('sha256').update(method).digest('hex')}));console.log({cases:cases.length,frames:cases.reduce((a,c)=>a+c.rows.length,0)});
