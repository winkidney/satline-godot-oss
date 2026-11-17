const fs=require('node:fs'),path=require('node:path');const {make,T,source_sha256,stage_sha256}=require('./weapon_arm_blend_reference.cjs');
const root=path.resolve(__dirname,'..'),relaxed=JSON.parse(fs.readFileSync(path.join(root,'assets/export/weapon-reload-hand-poses.json'),'utf8')).relaxed;
const {api,calls}=make(T,relaxed),rows=[];let state=4207,draws=0;const random=()=>{draws++;let t=state=(state+1831565813)>>>0;t=Math.imul(t^(t>>>15),1|t);t=((t+Math.imul(t^(t>>>7),61|t))^t)>>>0;return ((t^(t>>>14))>>>0)/4294967296};
const targets={};for(const [side,sign]of [['r',1],['l',-1]])targets[side]={p:[sign*.1,-.1,-.02],q:new T.Quaternion().setFromEuler(new T.Euler(.1,sign*.2,.15)).toArray(),pose:Array.from({length:20},(_,i)=>Math.fround(.3+.02*i)),pole:[sign*.8,-.6,0],sh:[sign*.2,-.23,.15],trig:.6};
const rootPose={p:[.1,-.1,-.25],q:new T.Quaternion().setFromEuler(new T.Euler(.2,.1,-.15,'YXZ')).toArray()};
for(let j=0;j<180;j++){
 const reset=j===90,normal=j===0||j===90,start=j===1||j===91;
 if(reset)api.restore();
 if(normal)api.update(1/60,{armTargets(out){for(const side of ['r','l']){const t=targets[side],o=out[side];for(const k of ['p','pole','sh'])o[k].fromArray(t[k]);o.q.fromArray(t.q);o.pose.set(t.pose);o.trig=t.trig;}}},{position:new T.Vector3().fromArray(rootPose.p),quaternion:new T.Quaternion().fromArray(rootPose.q)});
 if(start)api.startDrop(random);
 const dt=[0,1/60,1/120,.031,.08][j%5];api.dropUpdate(dt);
 rows.push({input:{reset,normal,start,dt,targets,root:rootPose},expected:{r:JSON.parse(JSON.stringify(calls.right)),l:JSON.parse(JSON.stringify(calls.left)),visible:{r:api.right.group.visible,l:api.left.group.visible},dropping:api.dropping,random_state:state,random_calls:draws}});
}
const result={source_sha256,stage_sha256,rows,scope:'Literal original vS startDrop/dropUpdate/restore with real relaxed pose and original Three math; mocked Fh records solver inputs. Two drop/restore cycles, dt0/large dt, hide timing and RNG. No Fh bones/production/render proof.'};fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-arm-drop-reference.json'),JSON.stringify(result));console.log(JSON.stringify({steps:rows.length}));
