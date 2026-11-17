extends SceneTree
class Pool extends SaltlineParticles:
 var trace:Array
 var tag:String
 func update(dt:float,_position:Vector3,_wind:Vector3,clock:float)->Array:trace.append({"name":tag,"dt":dt,"clock":clock});return []
class Batch extends SaltlineTracers:
 func _draw(quads:Array)->void:draw_records=quads
class Tracer extends SaltlineTracers:
 var trace:Array
 var fx:SaltlineImpactEffects
 func update(dt:float)->void:trace.append({"name":"tracer","dt":dt,"clock":fx.clock})
class Debris extends SaltlineDebris:
 var trace:Array
 var fx:SaltlineImpactEffects
 func _init(scene,stream):super(scene,stream)
 func update(dt:float)->void:trace.append({"name":"debris","dt":dt,"clock":fx.clock})
class Shells extends SaltlineShells:
 var trace:Array
 var fx:SaltlineImpactEffects
 func _init(scene,physics,stream):super(scene,physics,stream)
 func update(dt:float)->void:trace.append({"name":"shell","dt":dt,"clock":fx.clock})
class Emitters extends SaltlineExplosionEffects:
 var trace:Array
 func _init(effects):super(effects,null,null)
 func update(dt:float)->void:trace.append({"name":"emitters","dt":dt,"clock":fx.clock})
class WeaponView extends SaltlineWeaponEffects:
 func update(_dt:float)->void:pass
class Impact extends SaltlineImpactEffects:
 var trace:Array
 func impact(hit:Dictionary,_direction:Vector3)->String:trace.append({"name":"impact"});return hit.surface
class Decals extends SaltlineDecals:
 var trace:Array
 func _init(scene):super(scene)
 func impact(_hit:Dictionary)->void:trace.append({"name":"decal"})
class Explosives extends SaltlineExplosives:
 var trace:Array
 func _init(scene,physics,effects,stream):super(scene,physics,effects,null,stream)
 func impact(_hit:Dictionary,damage:float)->void:trace.append({"name":"explosives","damage":damage})
func _initialize()->void:call_deferred("verify")
func verify()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/fx-update-order-reference.json"));var trace=[];var failures=[];var checks=0
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[{"name":"fx_debris","id":"debris"},{"name":"fx_shells","id":"shell"},{"name":"fx_decals","id":"decal"}],"modules":{"explosives":{"items":[]}}};scene.source_nodes={}
 for id in ["debris","shell"]:
  var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.mesh=BoxMesh.new();node.multimesh.instance_count=4;scene.source_nodes[id]=node
 var decal_mesh=MeshInstance3D.new();var quad=QuadMesh.new();quad.material=StandardMaterial3D.new();decal_mesh.mesh=quad;scene.source_nodes.decal=decal_mesh
 var physics=SaltlinePhysics.new({"boxes":[],"bounds":{}});var rng=preload("res://scripts/fx_random.gd").new();var camera=Camera3D.new();root.add_child(camera)
 var fx=SaltlineImpactEffects.new();fx.camera=camera;fx.pool=Pool.new();fx.pool.trace=trace;fx.pool.tag="add";fx.lit_pool=Pool.new();fx.lit_pool.trace=trace;fx.lit_pool.tag="lit";fx.batch=Batch.new();fx.lit_batch=Batch.new();fx.debris=Debris.new(scene,rng);fx.debris.trace=trace;fx.debris.fx=fx
 var tracer=Tracer.new();tracer.trace=trace;tracer.fx=fx;fx.tracer_pool=tracer
 var shells=Shells.new(scene,physics,rng);shells.trace=trace;shells.fx=fx
 var emitters=Emitters.new(fx);emitters.trace=trace
 var router=load("res://scripts/main.gd").new();router.game_mode=true;router.weapon_effects=WeaponView.new();router.shells=shells;router.tracers=tracer;router.explosion_effects=emitters;router.impact_effects=fx
 for row in fixture.rows:
  trace.clear();router._advance_effects(float(row.dt));checks+=1
  if trace.size()!=row.expected.size():failures.append("phase count")
  for i in mini(trace.size(),row.expected.size()):
   checks+=3
   if trace[i].name!=row.expected[i].name or abs(float(trace[i].dt)-float(row.expected[i].dt))>1e-12 or abs(float(trace[i].clock)-float(row.expected[i].clock))>1e-12:failures.append({"dt":row.dt,"phase":i,"actual":trace[i],"expected":row.expected[i]})
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));router.weapon=SaltlineWeapon.new(data.modules.weapon)
 var impact=Impact.new();impact.trace=trace;var decals=Decals.new(scene);decals.trace=trace;var explosives=Explosives.new(scene,physics,emitters,preload("res://scripts/source_rng.gd").new(7));explosives.trace=trace;router.impact_effects=impact;router.decals=decals;router.explosives=explosives
 for row in fixture.chains:
  trace.clear();router.weapon.current=row.input.gun;router.weapon.rigs[row.input.gun].def.damage=row.input.damage
  router._combat_impact({"point":Vector3.ZERO,"normal":Vector3.UP,"dir":Vector3.DOWN,"surface":"metal","from":row.input.from,"box":{}})
  checks+=1
  if trace.size()!=row.expected.size():failures.append("impact phase count")
  for i in mini(trace.size(),row.expected.size()):
   checks+=1
   if trace[i].name!=row.expected[i].name:failures.append({"impact_order":trace})
   if row.expected[i].has("damage"):
    checks+=1
    if trace[i].damage!=row.expected[i].damage:failures.append({"damage":trace[i],"expected":row.expected[i]})
 var report={"checks":checks,"steps":fixture.rows.size(),"impact_cases":fixture.chains.size(),"failures":failures,"methods_sha256":fixture.methods_sha256,"impact_callback_sha256":fixture.impact_callback_sha256,"source_sha256":fixture.source_sha256,"scope":"Actual Main._advance_effects and ImpactEffects.update order versus literal original le with traced receivers; clock and nonpositive dt. Actual Main._combat_impact order and player/enemy/fallback damage versus original yE callback. Numeric receiver internals proven separately; no full global frame/physics proof."}
 FileAccess.open("res://evidence/fx-update-order-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 emitters.exploded.disconnect(explosives._chain);router.weapon_effects.free();router.free();impact.free();fx.batch.free();fx.lit_batch.free();fx.free();tracer.free();camera.free()
 for node in scene.source_nodes.values():node.free()
 scene.free();quit(0 if failures.is_empty() else 1)
