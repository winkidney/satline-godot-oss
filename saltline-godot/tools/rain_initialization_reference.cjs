const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const rngText=s.slice(s.indexOf('  function su(n = 1337)'),s.indexOf('  var Hn = '));
const su=Function(rngText+'return su;')();
const text=s.slice(s.indexOf('  function Vw(n, e, t)'),s.indexOf('  function Gw(n, e)'));
class Attribute{constructor(array,itemSize){this.array=array;this.itemSize=itemSize;}}
class Geometry{setAttribute(k,v){(this.attributes??={})[k]=v;return this;}setIndex(v){this.index=v;return this;}}
const Vw=Function('Ra','nt','Xs','an','K',text+'return Vw;')(Geometry,Attribute,Attribute,class{},class{});
const seed=JSON.parse(fs.readFileSync(path.join(root,'assets/export/source-bootstrap.json'))).streams.rain.seed;
const cases=[];
for(const [quality,scale] of Object.entries({test:.4,low:.5,medium:.8,high:1,ultra:1})){
 const rng=su(seed);let calls=0;const next=()=>{calls++;return rng();};
 const drops=Math.round(9000*Math.max(.15,scale||.5)),splashes=Math.round(900*Math.max(.15,scale||.5));
 const rain=Vw(drops,260,next).attributes.aSeed.array,splash=Vw(splashes,0,next).attributes.aSeed.array;
 const thunder_timer=22+next()*25;
 const files={};for(const [name,a] of Object.entries({rain,splash})){const file='fixtures/rain-init-'+quality+'-'+name+'.bin';fs.writeFileSync(path.join(root,'assets/export',file),Buffer.from(a.buffer));files[name]=file;}
 cases.push({quality,scale,seed,drops,splashes,calls,state:(seed+Math.imul(calls,1831565813))>>>0,thunder_timer,files});
}
const result={source_sha256:crypto.createHash('sha256').update(s).digest('hex'),literal_Vw_sha256:crypto.createHash('sha256').update(text).digest('hex'),cases,scope:'Original literal Vw and su, original Gw counts and initial timer. Constructor arrays, not whole-game cold-quality proof.'};
fs.writeFileSync(path.join(root,'assets/export/fixtures/rain-initialization.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(cases.map(({files,...c})=>c)));
