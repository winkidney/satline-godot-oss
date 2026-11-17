extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/menu-veil-css.json"));var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var reference_texture="--veil-reference-texture" in OS.get_cmdline_user_args()
 var tag="reference-texture" if reference_texture else "verification"
 var ui=game.game_ui;var failures=[];var pixel_checks=0;var maximum=0.0
 if reference_texture:
  var material=ShaderMaterial.new();var shader=Shader.new();shader.code="shader_type canvas_item;uniform sampler2D original_rgba:filter_nearest,repeat_disable;void fragment(){COLOR*=texture(original_rgba,UV);}"
  material.shader=shader;material.set_shader_parameter("original_rgba",ImageTexture.create_from_image(Image.load_from_file("res://evidence/menu-veil-original-transparent.png")));ui.title_veil.material=material
 var background_layer=CanvasLayer.new();background_layer.layer=19;root.add_child(background_layer);var background=ColorRect.new();background.color=Color.WHITE;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background_layer.add_child(background)
 for child in ui.root.get_children():
  if child!=ui.title_veil and child!=ui.pause_veil:child.visible=false
 for case in data.cases:
  ui._set_veil(case.screen);ui.veil_opacity_transition.reset(case.alpha);ui._update_veil(0.0)
  for frame in 3:await process_frame
  RenderingServer.force_draw(false)
  var actual=root.get_texture().get_image();actual.save_png("res://evidence/menu-veil-%s-%s-%d-native.png"%[tag,case.screen,int(case.index)])
  var expected=Image.load_from_file("res://evidence/"+case.file)
  for point in [Vector2i(64,64),Vector2i(640,64),Vector2i(1216,64),Vector2i(64,360),Vector2i(640,360),Vector2i(1216,360),Vector2i(64,680),Vector2i(640,680),Vector2i(1216,680)]:
   var a=actual.get_pixelv(point);var b=expected.get_pixelv(point);var error=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)));maximum=maxf(maximum,error);pixel_checks+=1
   if error>1.1/255:failures.append({"screen":case.screen,"alpha":case.alpha,"point":[point.x,point.y],"error":error})
 ui.veil_opacity_transition.reset(1.0);ui.veil_screen="title";var scalar_checks=0;var scalar_maximum=0.0
 for stage in data.stages:
  ui._set_veil(stage.screen);var previous=0.0
  for sample in stage.samples:
   ui._update_veil((sample.ms-previous)/1000.0);previous=sample.ms
   var error=absf(ui.veil_opacity_transition.value-sample.alpha);scalar_maximum=maxf(scalar_maximum,error);scalar_checks+=1
   if error>1e-5:failures.append({"screen":stage.screen,"ms":sample.ms,"alpha_error":error})
 var report={"reference_rgba_texture":reference_texture,"pixel_checks":pixel_checks,"maximum_pixel_error":maximum,"scalar_checks":scalar_checks,"maximum_alpha_error":scalar_maximum,"failures":failures,"scope":"Actual Main GameUI veil methods and GPU draws versus original CSS backgrounds at16 states on white plus18 interrupted-opacity samples. Other UI/world hidden; no whole title typography or input acceptance."}
 FileAccess.open("res://evidence/menu-veil-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();background_layer.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
