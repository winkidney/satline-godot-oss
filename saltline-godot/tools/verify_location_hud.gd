extends SceneTree
func _initialize()->void:call_deferred("verify")
func verify()->void:
 var script=preload("res://scripts/location_hud.gd")
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/location-css-reference.json"))
 var failures=[];var maximum_error=0.0
 for row in fixture.rows:
  var error=absf(script.reveal_fraction(row.seconds)-row.reveal);maximum_error=maxf(maximum_error,error)
  if error>.000001:failures.append(row)
 var card=script.new();root.add_child(card);card.show_card(true);card.update_frame(.5);var before=card.reveal_time;card.show_card(true)
 if card.reveal_time!=before:failures.append("repeated show restarted animation")
 card.show_card(false);card.update_frame(.5)
 if card.visible or card.alpha!=0:failures.append("hide did not finish fading")
 card.show_card(true)
 if card.reveal_time!=0:failures.append("new show did not reset reveal")
 var report={"samples":fixture.rows.size(),"maximum_error":maximum_error,"failures":failures,"source_html_sha256":fixture.source_html_sha256,"scope":"Browser-sampled original CSS clip-path compared with native reveal fraction; repeated-show, fade completion and replay lifecycle. No typography/pixel assertion."}
 FileAccess.open("res://evidence/location-hud-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));card.free();quit(0 if failures.is_empty() else 1)
