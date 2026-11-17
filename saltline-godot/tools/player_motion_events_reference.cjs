const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function between(start,end,offset=0){const a=source.indexOf(start,offset),b=source.indexOf(end,a);if(a<0||b<0)throw Error('missing '+start);return source.slice(a,b);}
const T=eval(source.slice(0,source.indexOf('  var Kn = {'))+'return ut;})()'),start=source.indexOf('    function N(J) {',source.indexOf('    function H() {',source.indexOf('        addShake(J = 0.3)')));
const jump=between('        (r = A.onGround ? Nt.coyote','        (A.vel.y -= Nt.gravity * J * 0.5),',start).trim().replace(/,$/,';');
const land=between('        if (!l && c > 0.12) {','        (c = 0),',start);
const rescue=between('        A.pos.y < Kn.seaY - 2.2 &&','        (A.speed = Math.hypot',start).trim().replace(/,$/,';');
const step=between('      if (A.onGround && A.speed > 0.5) {','      let X = A.onGround',start);
const listeners=between('    n.events &&\n      n.events.on &&\n      (n.events.on("player:step"','    let l = {');
const helpers=between('  var Hn = (n, e, t) =>','  var a0 = ');
const factory=new Function('THREE','Nt','row','listeners',`const Kn={seaY:-1.6};${helpers};const J=row.dt,G={pressed:()=>row.jump},oe=true,Pz=Math.sqrt(2*Nt.gravity*Nt.jumpApex),A={pos:new THREE.Vector3(...row.pos),vel:new THREE.Vector3(...row.velocity),onGround:row.ground,crouching:row.crouch,sprinting:row.sprint,yaw:0};let r=row.coyote,a=row.jump_buffer,o=row.crouch?Nt.crouchHeight:Nt.standHeight,l=row.ground,c=row.air_time,u=row.fall_speed,x={v:0},f=row.phase,M=row.shake;const C=new THREE.Vector3(...row.safe_pos),events=[],damage=[],motion={stepEv:0,jumpEv:0,landEv:-1},handlers={};const n={events:{on:(type,fn)=>(handlers[type]??=[]).push(fn),emit:(type,payload)=>{for(const fn of handlers[type]||[])fn(payload);events.push({kind:type.replace('player:',''),payload:JSON.parse(JSON.stringify(payload)),phase:f,shake:M,flags:{...motion}});}}};new Function('n','a',listeners)(n,motion);function F(){return row.can_stand;}function H(){return row.resolved_surface||row.surface;}A.addShake=value=>M=Math.min(1,M+value);A.damage=(amount)=>{damage.push(amount);M=Math.min(1,M+.22+amount/70);};${jump};A.vel.y-=Nt.gravity*J*.5;if(A.vel.y< -40)A.vel.y=-40;const ce=A.vel.y;A.pos.fromArray(row.result_pos);A.vel.fromArray(row.result_velocity);A.onGround=row.result_ground;if(!A.onGround)A.vel.y-=Nt.gravity*J*.5;if(A.onGround){${land};c=0;u=0;}else{c+=J;u=Math.max(u,-A.vel.y);}${rescue};A.speed=Math.hypot(A.vel.x,A.vel.z);const B=A.crouching?Nt.stride.crouch:A.sprinting?Nt.stride.sprint:Nt.stride.walk;${step};return {events,damage,flags:motion,phase:f,impact:ce,height:o};`);
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/prepared/scene.json'),'utf8')),rows=[];
function add(name,overrides){const row={name,dt:1/60,pos:[-20,0,0],velocity:[0,0,0],ground:true,crouch:false,sprint:false,coyote:0,jump_buffer:0,air_time:0,fall_speed:0,phase:0,shake:0,safe_pos:[-20,0,0],jump:false,can_stand:true,surface:'concrete',resolved_surface:'',result_pos:[-20,0,0],result_velocity:[0,0,0],result_ground:true,...overrides};rows.push({input:row,expected:factory(T,data.modules.player.tuning,row,listeners)});}
add('jump',{jump:true,result_ground:false,result_pos:[-20,.1,0],result_velocity:[0,6,0]});
add('coyote_jump',{ground:false,coyote:.05,jump:true,result_ground:false,result_velocity:[0,6,0]});
add('jump_from_crouch',{crouch:true,jump:true,can_stand:true,result_ground:false,result_velocity:[0,6,0]});
add('crouch_blocked',{crouch:true,jump:true,can_stand:false});
for(const air_time of [.12,.120000001,.5])for(const speed of [0,7.5,7.5001,13,13.5])add('land/'+air_time+'/'+speed,{ground:false,air_time,velocity:[0,-speed,0],fall_speed:speed,result_ground:true,surface:'metal'});
for(const force of [7.375,7.5,7.625,12.875,13,13.125])add('exact_force/'+force,{dt:0,ground:false,air_time:.5,velocity:[0,-force,0],fall_speed:force,result_ground:true});
add('land_peak',{ground:false,air_time:.4,velocity:[0,-3,0],fall_speed:14,result_ground:true,resolved_surface:'water'});
add('no_land_short_air',{ground:false,air_time:.1,velocity:[0,-8,0],fall_speed:8,result_ground:true});
for(const sprint of [false,true])for(const phase of [.99,.1,-.5])for(const dt of [0,1/60,.8])add('stride',{sprint,phase,dt,result_velocity:[sprint?6.4:3.8,0,0],surface:'metal'});
add('idle_negative_round',{phase:-.5,dt:.05});
add('rescue',{ground:false,pos:[35,-4,0],result_pos:[35,-4.1,0],result_ground:false,result_velocity:[0,-4,0]});
const coverage={jump:0,land:0,step:0,rescued:0,no_event:0,multi_stride_single:0};
for(const sample of rows){if(!sample.expected.events.length)coverage.no_event++;for(const event of sample.expected.events)coverage[event.kind]++;if(sample.input.name==='stride'&&sample.input.dt===.8&&sample.expected.events.filter(e=>e.kind==='step').length===1)coverage.multi_stride_single++;}
if(Object.values(coverage).some(value=>value===0))throw Error('missing event branch '+JSON.stringify(coverage));
const result={coverage,source_sha256:crypto.createHash('sha256').update(source).digest('hex'),segments_sha256:crypto.createHash('sha256').update(jump+land+rescue+step+listeners).digest('hex'),rows,scope:'Original literal player jump/land/rescue/stride sections and weapon event listeners. Controlled collision results/surface resolver; excludes full source physics/camera, puddle/level H resolver and complete movement update.'};
fs.writeFileSync(path.join(root,'assets/export/fixtures/player-motion-events-reference.json'),JSON.stringify(result));console.log(JSON.stringify({cases:rows.length,segments_sha256:result.segments_sha256}));
