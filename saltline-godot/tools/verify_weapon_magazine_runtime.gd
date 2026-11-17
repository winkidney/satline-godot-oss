extends "res://tools/verify_weapon_parts_runtime.gd"
var magazine_rows=[]
var last_reload_gun=""
var magazine_checks=0
func matrix(tr:Transform3D)->Array:
 return [tr.basis.x.x,tr.basis.x.y,tr.basis.x.z,0,tr.basis.y.x,tr.basis.y.y,tr.basis.y.z,0,tr.basis.z.x,tr.basis.z.y,tr.basis.z.z,0,tr.origin.x,tr.origin.y,tr.origin.z,1]
func _process(dt:float)->bool:
 if game==null or finishing:return super._process(dt)
 var old={}
 for gun in game.weapon.rigs:old[gun]=game.source_scene.source_nodes[game.weapon.rigs[gun].root["$node"]].quaternion
 var result=super._process(dt)
 for gun in game.weapon.rigs:
  var actual:Quaternion=game.weapon.magazine_motion.root_rotations[gun]
  if absf(absf(actual.dot(old[gun]))-1.0)>1e-6:fail("magazine did not read old local root rotation")
  var node=game.source_scene.source_nodes[game.weapon_animation.parts_view.roles[gun+"_magazine"]]
  if not node.transform.is_equal_approx(game.weapon.magazine_motion.poses[gun]):fail("magazine overwritten by sample")
  magazine_checks+=1
 if not game.weapon.reload.is_empty():
  var context=game.weapon.reload;last_reload_gun=context.weapon
  var q:Quaternion=game.weapon.magazine_motion.root_rotations[context.weapon]
  var node=game.source_scene.source_nodes[game.weapon_animation.parts_view.roles[context.weapon+"_magazine"]]
  magazine_rows.append({"gun":context.weapon,"time":context.t,"root_rotation":[q.x,q.y,q.z,q.w],"empty":context.empty,"start":context.t==0,"reset":false,"matrix":matrix(node.transform)})
 elif last_reload_gun!="":
  var node=game.source_scene.source_nodes[game.weapon_animation.parts_view.roles[last_reload_gun+"_magazine"]]
  magazine_rows.append({"gun":last_reload_gun,"time":0,"root_rotation":[0,0,0,1],"empty":false,"start":false,"reset":true,"matrix":matrix(node.transform)})
  last_reload_gun=""
 return result
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 game.get_viewport().get_texture().get_image().save_png("res://evidence/magazine-runtime-%03d.png"%requested)
func finish()->void:
 var report={"frames":frame,"magazine_checks":magazine_checks,"mechanical_role_checks":node_checks,"hold_checks":hold_checks,"rows":magazine_rows,"failures":failures,"scope":"Actual Main/Weapon/renderer reload matrix captures and pre-update local-root quaternion checks. Original JS replay compares recorded local matrices separately; no full IK/image proof."}
 FileAccess.open("res://evidence/weapon-magazine-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"frames":frame,"magazine_checks":magazine_checks,"rows":magazine_rows.size(),"failures":failures}));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
