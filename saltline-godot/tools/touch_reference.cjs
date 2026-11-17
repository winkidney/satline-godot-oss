const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=fs.readFileSync(path.resolve(__dirname,'../../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const methods=source.slice(source.indexOf('  var fE = {'),source.indexOf('  var Nt = {'));
class Element{constructor(){this.listeners={};this.style={};this.dataset={};this.classList={add(){},remove(){},toggle(){}};this.children={};}addEventListener(k,fn){(this.listeners[k]??=[]).push(fn)}appendChild(e){this.child=e}querySelector(k){return this.children[k]??=new Element()}emit(k,t){for(const fn of this.listeners[k]||[])fn({changedTouches:t,preventDefault(){},stopPropagation(){}})}}
const canvas=new Element(),ui=new Element(),doc=new Element(),win=new Element();doc.documentElement=new Element();doc.getElementById=id=>id==='view'?canvas:ui;doc.createElement=()=>new Element();
const api=Function('document','addEventListener','navigator','performance','innerWidth',methods+';return gE({events:{emit(){}}});')(doc,win.addEventListener.bind(win),{getGamepads:()=>[]},{now:()=>1000},1280);api.setGameplay(true);
const actions=['fire','ads','reload','swap','jump','interact','pause'];
const ops=[];function add(type,value={}){ops.push({type,...value})}
add('start',{id:1,x:100,y:500});for(const [x,y]of [[100,500],[100,442],[100,446],[158,500],[300,200],[-100,800]])add('motion',{id:1,x,y});
add('start',{id:2,x:800,y:300});for(let i=0;i<40;i++)add('motion',{id:2,x:800+i*7.1,y:300-i*2.9,sensitivity:i%2?1.7:.2,invert:i%3===0});
add('start',{id:3,x:200,y:600});add('finish',{id:3});add('finish',{id:1});add('finish',{id:2});
for(const action of actions){add('button',{action,id:8,on:true,x:1200,y:600});if(action==='fire'){add('motion',{id:8,x:1210,y:580});add('button',{action,id:9,on:false});}add('button',{action,id:8,on:false});}
add('button',{action:'ads',id:8,on:true});add('clear');add('start',{id:10,x:10,y:10});add('motion',{id:10,x:10,y:-48});add('clear');
function sample(op){api.sensitivity=op.sensitivity??1;api.invertY=op.invert??false;api.endFrame();const touch={identifier:op.id,clientX:op.x,clientY:op.y};
 if(op.type==='start'){win.emit('touchstart',[touch]);canvas.emit('touchstart',[touch]);}
 if(op.type==='motion'){canvas.emit('touchmove',[touch]);ui.child?.querySelector('.t-fire').emit('touchmove',[touch]);}
 if(op.type==='finish')canvas.emit('touchend',[touch]);
 if(op.type==='button'){win.emit('touchstart',[]);ui.child.querySelector('.t-'+op.action).emit(op.on?'touchstart':'touchend',[touch]);}
 if(op.type==='clear')win.emit('blur',[]);
 api.update(.016);return {move:[api.move.x,api.move.y],look:[api.look.dx,api.look.dy],sprint:api.sprint,ads:api.ads,held:actions.filter(a=>api.down(a)),pressed:actions.filter(a=>api.pressed(a))};}
const rows=ops.map(op=>({op,expected:sample(op)}));fs.writeFileSync(path.resolve(__dirname,'../assets/export/fixtures/touch-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(source).digest('hex'),methods_sha256:crypto.createHash('sha256').update(methods).digest('hex'),rows}));console.log({steps:rows.length});
