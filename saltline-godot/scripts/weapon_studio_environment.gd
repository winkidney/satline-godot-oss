extends RefCounted
# Original showcase bootstrap: 80m concrete plane, stub level/backdrop, no rain.
static func isolate(game)->Dictionary:
 var scene=game.source_scene
 for node in scene.source_nodes.values():
  if node is GeometryInstance3D or node is OmniLight3D:node.visible=false
 for id in scene.source_nodes:
  if scene.records.get(id,{}).get("name","")=="sky":scene.source_nodes[id].visible=true
 for rig in game.weapon.rigs.values():_restore_visuals(scene.source_nodes[rig.root["$node"]])
 for id in game.weapon_animation.arm_group_ids:_restore_visuals(scene.source_nodes[id])
 scene.source.modules.level.interiorBoxes=[]
 game.player.physics.boxes.clear()
 game.player.pos=Vector3(0,0,4);game.player.eye=Vector3(0,1.68,4)
 game.player.velocity=Vector3.ZERO;game.player.forward=Vector3.FORWARD
 game.player.yaw=0;game.player.pitch=0;game.player.speed=0
 game.player.on_ground=true;game.player.sprinting=false;game.player.crouching=false;game.player.enabled=false
 game.planar_reflection.enabled=false
 game.rain_system.level=0;game.rain_system.target=0;game.rain_system.thunder_timer=INF
 for slot in game.light_pool.slots:game.light_pool.release(slot)
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fx-showcase-geometry.json"))
 var ground=MeshInstance3D.new();ground.name="ShowcaseGround"
 ground.mesh=preload("res://scripts/fx_showcase_geometry.gd")._mesh(data.ground)
 ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material_id=""
 for material in scene.source.materials:
  if material.name=="concrete":
   material_id=material.id;ground.material_override=preload("res://scripts/fx_showcase_geometry.gd")._uncolored_material(scene.materials[material.id]);break
 assert(not material_id.is_empty(),"Source concrete material missing")
 scene.add_child(ground)
 var id="weapon-studio-concrete-ground";ground.set_meta("source_id",id)
 scene.records[id]={"id":id,"geometry":id,"materials":[material_id],"receiveShadow":true,"castShadow":false}
 scene.source_nodes[id]=ground
 return {"ground_size":[80,80],"ground_cast_shadow":false,"level":"stub","rain":false,"material":material_id}
static func _restore_visuals(node:Node)->void:
 if node is GeometryInstance3D:node.visible=true
 for child in node.get_children():_restore_visuals(child)

static func after_frame(game)->void:
 game.rain_system.rain.visible=false;game.rain_system.splash.visible=false
 game.source_ibl_service.view_fill=1.1
 game.source_ibl_service.update(0.0)
 for binding in game.source_scene.weapon_wet_materials:
  if binding[1]=="uArmWet":binding[0].set_shader_parameter(binding[1],.7)
