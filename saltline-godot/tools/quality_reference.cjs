const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=fs.readFileSync(path.resolve(__dirname,'../../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function block(marker,from=0){const start=source.indexOf(marker,from);if(start<0)throw Error(marker);let end=source.indexOf('{',start)+1,depth=1;while(depth){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}return source.slice(start,end);}
const presetsCode=block('jr = {').replace(/^jr = /,''),presets=Function('return ('+presetsCode+');')();
const resize=block('resize() {',source.indexOf('setQuality(G) {'));
const rows=[];
for(const name of Object.keys(presets))for(const screen of [[320,240],[1280,720],[1920,1080],[2560,1440],[3840,2160],[999,777]])for(const dpr of [1,1.25,2,3])for(const drs of [.65,1]){
 const n={quality:presets[name]},t={clientWidth:screen[0],clientHeight:screen[1]},window={devicePixelRatio:dpr},S={scale:drs},Q={resolution:{set(x,y){this.x=x;this.y=y}}},g={setSize(){}},b={image:{}},i={setPixelRatio(){},setSize(){}},a={updateProjectionMatrix(){}},l={updateProjectionMatrix(){}};
 Function('n','t','window','S','Q','g','b','i','a','l','M','E','return ({'+resize+'});')(n,t,window,S,Q,g,b,i,a,l,true,null).resize();rows.push({name,screen,dpr,drs,size:[Q.resolution.x,Q.resolution.y]});
}
fs.writeFileSync(path.resolve(__dirname,'../assets/export/fixtures/quality-reference.json'),JSON.stringify({presets,rows,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),methods_sha256:crypto.createHash('sha256').update(presetsCode+resize).digest('hex')}));console.log({presets:Object.keys(presets).length,rows:rows.length});
