const fs=require('fs'),path=require('path'),crypto=require('crypto');const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');const T=eval(s.slice(0,s.indexOf('  var Kn = {'))+'return ut;})()');
function section(a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<0)throw Error(a);return s.slice(i,j)}
function fn(a){const start=s.indexOf(a);let depth=0;for(let i=s.indexOf('{',start);i<s.length;i++){if(s[i]==='{')depth++;if(s[i]==='}'&&!--depth)return s.slice(start,i+1)}throw Error(a)}
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
// I has an options default {} before its body, so extract by the next function boundary.
const start=s.indexOf('    function I(j, O = {}) {'),smoke=s.slice(start,s.indexOf('\n    function ',start+10));

const methods=section('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)','    function _(')+smoke;
const tape=Array.from({length:8192},(_,i)=>((i*79+17)%8191)/8191);let calls=0;const math=Object.create(Math);math.random=()=>tape[calls++];const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(math);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
const options=[{}, {count:2.2,size:.3,life:.9,rise:1.4,color:0x151515,vel:[.5,1.5,-.25]}, {count:0,alpha:0,size:0,life:0}, {count:1,color:'rgba(20,40,60,.3)'}, {count:1,color:'invalid'}, {count:1,color:[.8,.2,.1]}, {count:1,color:'invalid'}, {count:-1}, {count:1,rise:null}, {count:1,color:'#abc'}];const cases=[];
for(const capacity of [2,64]){const l=new Pool(capacity,true);const ph=Function('Qe','let e5=new Qe(),Lo=[1,1,1];'+fn('function ph(n, e, t, i) {')+';return ph;')(T.Color);const api=Function('Et','lt','l','ph','g',methods+';return I;')(math.random,(a,b)=>a+(b-a)*math.random(),l,ph,()=>.2);const rows=[];
for(let pass=0;pass<2;pass++){if(pass)l.clear();for(const raw of options){const o={...raw};if(o.vel)o.vel=new T.Vector3(...o.vel);api(new T.Vector3(1,2,3),o);rows.push({options:raw,clear:pass===1&&raw===options[0],calls,particles:Array.from(l.order.slice(0,l.n),id=>Object.fromEntries(fields.map(k=>[k,l[k][id]])))});}}cases.push({capacity,rows});}
fs.writeFileSync(path.join(root,'assets/export/fixtures/smoke-pool-reference.json'),JSON.stringify({tape,cases,source_sha256:crypto.createHash('sha256').update(s).digest('hex')}));console.log({calls,cases:cases.length});
