async(page)=>await page.evaluate(async()=>{
 const g=__G,w=g.weapon,originalInput=g.input;const sourceNodes=[];g.camera.traverse(n=>{if(n!==g.camera)sourceNodes.push(n)});
 const input={fire:false,ads:false,sprint:false,look:{dx:0,dy:0},pressed:()=>false};g.input=input;
 const originalRecoil=g.player.addRecoil,originalShake=g.player.addShake;g.player.addRecoil=()=>{};g.player.addShake=()=>{};
 const clips={};const dt=1/60;
 const snapshot=()=>sourceNodes.map(n=>{n.updateMatrix();return [...n.position.toArray(),...n.quaternion.toArray(),...n.scale.toArray(),n.visible?1:0]});
 for(const gun of ['rifle','pistol'])for(const kind of ['hip','ads','sprint','reload_tac','reload_empty','fire']){
  w.reset();w.equip(gun);Object.assign(w.debug,{pause:false,freeze:false,noIdle:true,noFire:false,reloadT:null,empty:false,flash:false,ads:false,sprint:false});
  input.fire=false;input.ads=false;g.player.sprinting=false;g.player.speed=0;g.player.vel.set(0,0,0);
  w.snap();for(let i=0;i<12;i++){g.time.t+=dt;w.update(dt)}w.snap();
  if(kind==='ads'){input.ads=true;w.snap()}
  if(kind==='sprint'){g.player.sprinting=true;g.player.speed=6.4;w.debug.sprint=true;w.snap()}
  if(kind.startsWith('reload')){w.ammo=kind==='reload_empty'?0:w.magSize-5;w.reloadNow()}
  const length=kind.startsWith('reload')?(gun==='rifle'?(kind==='reload_empty'?2.72:2.24):(kind==='reload_empty'?1.9:1.5))+.1:kind==='fire'?.5:1;
  const frames=[];
  for(let i=0;i<=Math.ceil(length/dt);i++){
   input.fire=kind==='fire'&&i===0;g.time.t+=dt;w.update(dt);g.scene.updateMatrixWorld(true);frames.push(snapshot());
  }
  clips[gun+'_'+kind]={fps:60,duration:(frames.length-1)*dt,frames};
 }
 g.input=originalInput;g.player.addRecoil=originalRecoil;g.player.addShake=originalShake;w.reset();w.equip('rifle');w.snap();
 const output={schema:1,source:'active original weapon.update and arms.update',node_ids:sourceNodes.map(n=>n.uuid),layout:['px','py','pz','qx','qy','qz','qw','sx','sy','sz','visible'],clips};
 const response=await fetch('http://127.0.0.1:8794',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:'animations/weapon.json',json:output})});
 if(!response.ok)throw new Error(await response.text());
 return {nodes:sourceNodes.length,clips:Object.fromEntries(Object.entries(clips).map(([k,v])=>[k,v.frames.length])),errors:__errors};
})
