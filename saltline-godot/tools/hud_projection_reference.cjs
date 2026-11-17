const fs=require('fs'),crypto=require('crypto');
const source=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const THREE=eval(source.slice(0,source.indexOf('  var Kn = {'))+'return ut;})()');
const start=source.indexOf('      let Ue = Math.round((J / 2 - (Re - ob) * sb)');
const code=source.slice(start,source.indexOf('      let _e = Math.max',start));
const run=new Function('ye','V','ne','Te','Re','J','G','te','ge','ce','oe','s','l','N','x','v','sb','ob',code);
const element=()=>({style:{},textContent:'',classes:{},classList:{toggle(name,value){this.owner.classes[name]=value}}});
const el=()=>{let value=element();value.classList.owner=value;return value};
const cases=[];
for(let i=0;i<640;i++){
 const width=[1280,1920,800,640][i%4],height=[720,1080,600,900][i%4],J=Math.min(420,width-64);
 const camera=new THREE.PerspectiveCamera(60+i%36,width/height,.05,220);
 camera.position.set(Math.sin(i*.3)*18,1.68+Math.sin(i*.23)*5,Math.cos(i*.41)*20);
 camera.rotation.set(Math.sin(i*.113)*1.3,Math.sin(i*.17)*Math.PI,Math.sin(i*.23)*.1,'YXZ');camera.updateMatrixWorld();
 const player={pos:camera.position.clone().add(new THREE.Vector3(0,-1.68,0)),yaw:camera.rotation.y+Math.sin(i*.4)*.03,alive:i%17!==0,sprinting:i%7===0};
 const Te=[0,.49,.5,.6,.601,1][i%6],ne={state:i%13===0?'reloading_hidden':'idle',spread:.001+(i%71)*.001};
 let Re=(-player.yaw*180/Math.PI)%360;if(Re<0)Re+=360;
 const targets=Array.from({length:4},(_,j)=>{let p=new THREE.Vector3(Math.sin(i*.37+j*2)*40,Math.sin(i*.2+j)*7,Math.cos(i*.19+j)*30);if(i%16===0&&j===0)p.copy(player.pos).add(new THREE.Vector3(.2,0,-.2));return{pos:p,kind:j===3?'extract':'relay',cEl:el(),wEl:el(),cDist:el(),wDist:el(),lastD:-1,lastC:1e9,lastW:''}});
 const oe={},s=el(),l=el(),N=el(),x=el(),v=[el(),el(),el(),el()];
 run(camera,player,ne,Te,Re,J,width,height,targets,new THREE.Vector3(),oe,s,l,N,x,v,4,-90);
 cases.push({size:[width,height],compassWidth:J,view:camera.matrixWorld.elements,fov:camera.fov,near:camera.near,far:camera.far,player:player.pos.toArray(),yaw:player.yaw,ads:Te,alive:player.alive,sprinting:player.sprinting,state:ne.state,spread:ne.spread,heading:Re,tape:oe.tapeX,cross:oe.crossOn,gap:oe.gap??null,markers:targets.map(t=>({pos:t.pos.toArray(),kind:t.kind,distance:t.lastD,compass:t.lastC,edge:t.cEl.classes.edge,x:Number(t.lastW.split(',')[0]),y:parseInt(t.lastW.split(',')[1]),offscreen:t.wEl.classes.offscreen,near:t.wEl.classes.near,dim:t.wEl.classes.dim}))});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/hud-projection-reference.json',JSON.stringify({sha256:crypto.createHash('sha256').update(source).digest('hex'),three:THREE.REVISION,cases}));console.log({cases:cases.length,markers:cases.length*4,three:THREE.REVISION});
