extends SceneTree
func _initialize()->void:
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/scenes/main.json"))
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/player-surface-reference.json"))
 var query=preload("res://scripts/ground_queries.gd").new(source)
 var player=SaltlinePlayer.new(source.modules.player,SaltlinePhysics.new(source.physics));player.surface_resolver=query.resolve_player_surface
 var failures=[];var checks=0
 for row in fixture.rows:
  player.pos=Vector3(row.position[0],row.position[1],row.position[2]);player.ground_surface=row.contact
  var actual=player.event_surface();checks+=1
  if actual!=row.expected and failures.size()<30:failures.append({"position":row.position,"contact":row.contact,"actual":actual,"expected":row.expected})
 var report={"checks":checks,"failures":failures,"source_sha256":fixture.source_sha256,"methods_sha256":fixture.methods_sha256,"scope":fixture.scope+" Actual Native Player.event_surface and bound ground resolver."}
 FileAccess.open("res://evidence/player-surface-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
