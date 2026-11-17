const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=fs.readFileSync(path.resolve(__dirname,'../../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function body(marker,from=0){let at=source.indexOf(marker,from),end=source.indexOf('{',at)+1,depth=1;if(at<0)throw Error(marker);while(depth){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}return source.slice(at,end);}
const at=source.indexOf('Kg = class'),methods=['_floorAt(e)','add(e, t)','update(e)','clear()'].map(m=>body(m+' {',at));
const quaternion=body('setFromEuler(e, t = !0) {');
let seed=71,calls=0;const tape=[];const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;const x=seed/4294967296;tape.push(x);calls++;return x;};
const vector=()=>({set(x,y,z,w){this.x=x;this.y=y;this.z=z;this.w=w;this._x=x;this._y=y;this._z=z;this._w=w;return this;}});
const q=Object.assign(vector(),{_onChangeCallback(){},get x(){return this._x},get y(){return this._y},get z(){return this._z},get w(){return this._w}});
// Object.assign evaluates getters; install the quaternion accessors explicitly.
for(const k of ['x','y','z','w'])Object.defineProperty(q,k,{get(){return this['_'+k]},configurable:true});
q.setFromEuler=Function('return ({'+quaternion+'});')().setFromEuler;
const euler={_order:'XYZ',set(x,y,z,order=this._order){Object.assign(this,{_x:x,_y:y,_z:z,_order:order});return this;}};
const compose=body('compose(e, t, i) {');
const matrix={elements:Array(16).fill(0),makeScale(){this.elements.fill(0);this.elements[15]=1;return this},toArray(array,offset){this.elements.forEach((v,i)=>array[offset+i]=v)}};matrix.compose=Function('return ({'+compose+'});')().compose;
const prototype=Function('Math','jw','YP','Xg','Zo','Ov','Kw','$g','Zg','Ds','return ({'+methods.join(',')+'});')(math,vector(),{x:0,y:-1,z:0},euler,q,{pos:vector()},vector(),vector(),vector(),matrix);
const cap=3,pool=Object.assign({cap,next:0,G:{physics:{raycast(){return {point:{y:0},surface:'metal'}}},events:{emit(){}}},mesh:{visible:false,instanceMatrix:{array:new Float32Array(cap*16)}}},prototype);
const fields='px py pz vx vy vz qx qy qz qw wx wy wz age rest floor'.split(' ');
for(const field of fields)pool[field]=new Float32Array(cap);pool.qw.fill(1);pool.state=new Uint8Array(cap);pool.bounces=new Uint8Array(cap);pool.surface=Array(cap).fill('concrete');
const rows=[];
function op(operation){if(operation.kind==='emit')pool.add({x:operation.p[0],y:operation.p[1],z:operation.p[2]},{x:operation.v[0],y:operation.v[1],z:operation.v[2]});else if(operation.kind==='clear')pool.clear();else pool.update(operation.dt);rows.push({op:operation,next:pool.next,calls,order:euler._order,visible:pool.mesh.visible,matrix:Array.from(pool.mesh.instanceMatrix.array),slots:Array.from({length:cap},(_,i)=>Object.fromEntries([...fields,'state','bounces'].map(k=>[k,pool[k][i]])))});}
op({kind:'emit',p:[0,.006,0],v:[1,-.1,2]});op({kind:'update',dt:.016});
op({kind:'emit',p:[1,1,2],v:[2,3,-1]});op({kind:'emit',p:[2,2,3],v:[-1,1,2]});
for(let i=0;i<600;i++){if(i===12)op({kind:'emit',p:[3,1,4],v:[0,-4,0]});if(i===350){op({kind:'clear'});op({kind:'emit',p:[1,2,3],v:[0,2,0]});}op({kind:'update',dt:[1/60,.013,.025][i%3]});}
fs.writeFileSync(path.resolve(__dirname,'../assets/export/fixtures/shell-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(source).digest('hex'),methods_sha256:crypto.createHash('sha256').update(methods.join('')+quaternion+compose).digest('hex'),cap,tape,rows}));
console.log({rows:rows.length,calls});
