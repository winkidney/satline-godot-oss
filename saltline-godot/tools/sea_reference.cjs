const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const ks={smoothstep:(x,a,b)=>{let t=Math.max(0,Math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)}},Kn={seaY:-1.6};
const begin=text.indexOf('  var Og = [');eval(text.slice(begin,text.indexOf('  function Ow(',begin)));
const rows=[...CP.matchAll(/float ph = ([\d.-]+) \* dot\(vec2\(([\d.-]+), ([\d.-]+)\), swp.xz\) - ([\d.-]+) \* uTime; sdisp.y \+= ([\d.-]+) \* sin\(ph\); sdisp.xz \+= vec2\(([\d.-]+), ([\d.-]+)\) \* \(([\d.-]+) \* cos/g)].map(m=>m.slice(1).map(Number));
if(rows.length!==4)throw Error('wave extraction');
const cases=[];let roundingDifference=0;
for(let i=0;i<72;i++){
 const x=i%9===0?880:30+Math.sin(i*.51)*170,z=i%11===0?880:Math.cos(i*.73)*170,time=[0,.25,1,8,27.5,100][i%6];
 const amp=1-ks.smoothstep(Math.hypot(x-30,z),50,220),disp=[0,0,0];
 for(const [k,dx,dz,speed,vertical,hx,hz,horizontal]of rows){const phase=k*(dx*x+dz*z)-speed*time;disp[0]+=hx*horizontal*Math.cos(phase)*amp;disp[1]+=vertical*Math.sin(phase)*amp;disp[2]+=hz*horizontal*Math.cos(phase)*amp}
 roundingDifference=Math.max(roundingDifference,Math.abs(Hw(x,z,time)-(-1.6+disp[1])));
 cases.push({world:[x,-1.6,z],time,displacement:disp});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/sea-wave-reference.json',JSON.stringify({cases,roundingDifference,scope:'Actual original CP-generated rounded vertex shader waves; Hw CPU height uses full precision and is intentionally slightly different'}));console.log({cases:cases.length,roundingDifference});
