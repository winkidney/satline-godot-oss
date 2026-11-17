extends SceneTree
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/dynamic-resolution-reference.json"));var failures=[];var checks=0;var frames=0;var maximum_error=0.0;var events_count=0
 for test in fixture.cases:
  var controller=preload("res://scripts/dynamic_resolution.gd").new();controller.state=test.initial.duplicate(true);var quality=test.quality
  for row in test.rows:
   frames+=1;var events=controller.sample(row.ms,quality,test.post);events_count+=events.size();checks+=1
   if events!=row.events and failures.size()<20:failures.append({"case":test.name,"frame":frames,"events":events,"expected":row.events})
   for event in events:
    if event.kind=="quality":quality=event.name
   checks+=2
   if quality!=row.quality or controller.state.size()!=row.state.size():failures.append("quality/state shape "+test.name)
   for field in row.state:
    checks+=1
    if typeof(row.state[field])==TYPE_BOOL:
     if controller.state[field]!=row.state[field]:failures.append(field)
    else:
     var error=absf(float(controller.state[field])-float(row.state[field]));maximum_error=maxf(maximum_error,error)
     if (not is_finite(error) or error>1e-9) and failures.size()<20:failures.append({"case":test.name,"field":field,"error":error})
 var quality_script=preload("res://scripts/render_quality.gd")
 for flags in [[[],[],false,true],[["--script"],[],false,false],[[],[],true,false],[[],["--dynres=0"],false,false],[["--script"],["--dynres=1"],true,true]]:
  var quality=quality_script.new();quality.configure(PackedStringArray(flags[0]),PackedStringArray(flags[1]),flags[2]);checks+=1
  if quality.dynamic.state.enabled!=flags[3]:failures.append("native dynamic configuration")
 var report={"actual_script_arg_present":("--script" in OS.get_cmdline_args()),"native_configuration_checks":5,"cases":fixture.cases.size(),"frames":frames,"checks":checks,"events":events_count,"maximum_error":maximum_error,"failures":failures,"source_sha256":fixture.source_sha256,"method_sha256":fixture.method_sha256,"scope":"Literal original render R(G), state and direct resize/setQuality/quality:auto calls; settling, disabled/no-post, >1500ms, strict averages, quality floor and recovery. Controlled timings, no performance claim."}
 FileAccess.open("res://evidence/dynamic-resolution-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
