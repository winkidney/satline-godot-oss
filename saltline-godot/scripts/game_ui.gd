class_name SaltlineGameUI
extends CanvasLayer
var touch_input

signal setting_changed(key:String,value:Variant)
signal ui_sound(kind:String)
class TrackedTitle extends Control:
 var font:Font
 var text="SALTLINE"
 var font_size=198.0
 func _draw()->void:
  var raster=int(ceil(font_size));var ratio=font_size/raster
  var baseline=(font_size*.8-font.get_height(raster)*ratio)*.5+font.get_ascent(raster)*ratio
  for i in text.length():
   var x=font.get_string_size(text.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,raster).x*ratio+i*font_size*.15
   draw_set_transform(Vector2(x,baseline+2),0,Vector2.ONE*ratio);draw_string(font,Vector2.ZERO,text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,raster,Color(0,0,0,.35))
   draw_set_transform(Vector2(x,baseline),0,Vector2.ONE*ratio);draw_string(font,Vector2.ZERO,text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,raster,Color("e8e4da"))
  draw_set_transform(Vector2.ZERO)
const BONE=Color("e8e4da")
const SIGNAL=Color("ffb347")
const STEEL=Color("a4aaa8")
var flow:SaltlineGameFlow
var card_scroll:ScrollContainer
var card_scrollbar:VScrollBar
var card_margin:MarginContainer
var card_content
var card_actions:VBoxContainer
var card_gap:Control
var card_window=Vector2.ZERO
var weapon:SaltlineWeapon
var root:Control
var menu_root:Control
var title:Control
var title_veil:ColorRect
var pause_veil:ColorRect
var mode_note
var card:PanelContainer
var panel:PanelContainer
var hud:Control
var buttons:Dictionary={}
var choices:Array=[]
var settings={"sens":1.0,"invertY":false,"fov":74.0,"difficulty":"hard","mode":"mission","view":1,"quality":"auto","volume":0.8}
var panel_open=false
var panel_tab="settings"
var panel_return_focus:WeakRef
var setting_outputs={}
var quality_note:Label
var panel_fonts={}
var effective_quality="high"
var shown_screen=""
var title_legend
var responsive_title
var title_bars
var veil_screen="none"
var veil_initialized=false
var veil_opacity_transition=preload("res://scripts/css_opacity_transition.gd").new(.5)
var hud_on=false
var hud_opacity_transition=preload("res://scripts/css_opacity_transition.gd").new(.35)
var status_hud:SaltlineStatusHud
var feedback=SaltlineCombatFeedback.new()
var navigation_hud:SaltlineNavigationHud
var objective
var location
var radio
var comms=SaltlineRadio.new()
var announcements
var source_post=false
var post:ShaderMaterial
var label_font:Font
var mono:Font
var display_font:Font
var save_path="user://saltline-settings.json"

func setup(controller:SaltlineGameFlow,gun:SaltlineWeapon,settings_path:String="user://saltline-settings.json",composite:ShaderMaterial=null)->void:
 preload("res://scripts/motion_preference.gd").refresh(DisplayServer.accessibility_should_reduce_animation())
 hud_opacity_transition.timing.respects_motion_preference=false
 flow=controller;weapon=gun;save_path=settings_path;layer=20
 label_font=load("res://assets/fonts/barlow-condensed-500.ttf");mono=load("res://assets/fonts/ibm-plex-mono-400.ttf");display_font=load("res://assets/fonts/big-shoulders-display-900.ttf")
 if not save_path.is_empty() and FileAccess.file_exists(save_path):
  settings=preload("res://scripts/source_settings.gd").decode(FileAccess.get_file_as_string(save_path))
 if settings.quality not in ["auto","low","medium","high","ultra"]:settings.quality="auto"
 settings.view=weapon.set_view(settings.view)
 settings.sens=clampf(float(settings.sens),.2,3);settings.fov=clampf(float(settings.fov),60,95)
 if settings.difficulty not in ["standard","hard","brutal"]:settings.difficulty="hard"
 if settings.mode not in ["mission","holdout"]:settings.mode="mission"
 flow.selected_mode=settings.mode;flow.mission.set_difficulty(settings.difficulty);flow.mission.player.set_fov(settings.fov)
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 if composite!=null:post=composite;source_post=true
 else:_post()
 _build_hud();_build_menu();_build_panel()
 flow.menu_changed.connect(_show);flow.intro_card_changed.connect(func(value):location.show_card(value))
 flow.radio_requested.connect(_radio)
 flow.mission.radio_requested.connect(_radio);flow.mission.radio_cleared.connect(_clear_radio);flow.mission.hud_reset.connect(_reset_hud)
 flow.mission.manager.combat.enemy_killed.connect(_enemy_killed);flow.mission.manager.combat.hit_enemy.connect(_enemy_hit);flow.mission.player.hit.connect(_player_hit)
 navigation_hud.feedback=feedback
 flow.mission.warning.connect(_warning);flow.mission.message.connect(_message)
 _show(flow.menu)

func _post()->void:
 var layer_post=CanvasLayer.new();layer_post.layer=3;add_child(layer_post)
 var rect=ColorRect.new();rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer_post.add_child(rect)
 post=ShaderMaterial.new();post.shader=load("res://shaders/flow_post.gdshader");rect.material=post

func _label(parent:Node,text:String,position:Vector2,size:int=18,font:Font=null)->Label:
 var label=Label.new();label.text=text;label.position=position;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_color_override("font_color",BONE);label.add_theme_font_override("font",_ui_font(parent,font if font!=null else label_font));label.add_theme_font_size_override("font_size",size);parent.add_child(label);return label
func _ui_font(parent:Node,font:Font)->Font:
 if not font is FontFile:return font
 if not ((panel!=null and panel.is_ancestor_of(parent)) or (title!=null and title.is_ancestor_of(parent))):return font
 var key=font.resource_path
 if not panel_fonts.has(key):
  var copy=font.duplicate();copy.oversampling=1.0;panel_fonts[key]=copy
 return panel_fonts[key]
func _style(color:Color,border:Color)->StyleBoxFlat:
 var box=StyleBoxFlat.new();box.bg_color=color;box.border_color=border;box.set_border_width_all(1);box.content_margin_left=22;box.content_margin_right=22;box.content_margin_top=10;box.content_margin_bottom=10;return box
func _button(parent:Node,text:String,rect:Rect2,action:String,primary:bool=false)->Button:
 var css_menu_button=(title!=null and title.is_ancestor_of(parent)) or (card!=null and card.is_ancestor_of(parent)) or action.begins_with("select_") or action in ["close","fullscreen"]
 var button=preload("res://scripts/title_button.gd").new() if css_menu_button else Button.new();button.text=text;button.position=rect.position;button.custom_minimum_size=rect.size;button.size=rect.size
 button.add_theme_font_override("font",_ui_font(parent,load("res://assets/fonts/barlow-condensed-600.ttf")));button.add_theme_font_size_override("font_size",16)
 button.add_theme_stylebox_override("normal",_style(SIGNAL if primary else Color(.043,.051,.059,.65),SIGNAL if primary else Color(.91,.89,.85,.42)))
 button.add_theme_stylebox_override("hover",_style(BONE,BONE));button.add_theme_color_override("font_color",Color("0b0d0f") if primary else BONE);button.add_theme_color_override("font_hover_color",Color("0b0d0f"));button.add_theme_color_override("font_focus_color",Color("0b0d0f") if primary else BONE);button.add_theme_color_override("font_pressed_color",Color("0b0d0f") if primary else BONE)
 if css_menu_button:
  button.configure(primary)
  if action in ["close","fullscreen"]:button.configure_small()
 button.pressed.connect(_action.bind(action));button.pressed.connect(func():ui_sound.emit("click"));button.mouse_entered.connect(func():ui_sound.emit("hover"));parent.add_child(button);buttons[action]=button;return button

func _build_menu()->void:
 title_bars=preload("res://scripts/title_bars.gd").new();title_bars.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(title_bars)
 menu_root=Control.new();menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(menu_root)
 var veil=ColorRect.new();veil.color=Color.WHITE;veil.material=ShaderMaterial.new();veil.material.shader=preload("res://shaders/title_veil.gdshader");veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(veil);root.move_child(veil,title_bars.get_index());title_veil=veil
 pause_veil=ColorRect.new();pause_veil.color=Color(6.0/255,8.0/255,10.0/255,.62);pause_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);pause_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(pause_veil);root.move_child(pause_veil,title_bars.get_index())
 title=Control.new();title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;menu_root.add_child(title)
 responsive_title=preload("res://scripts/title_layout.gd").new();title.add_child(responsive_title);responsive_title.setup(self)
 title_legend=preload("res://scripts/title_legend.gd").new();title.add_child(title_legend)
 card=PanelContainer.new();var card_style=_style(Color(.043,.051,.059,.9),Color(.91,.89,.85,.2));card_style.content_margin_left=1;card_style.content_margin_right=1;card_style.content_margin_top=3;card_style.content_margin_bottom=1;card_style.border_width_top=3;card_style.border_color=Color(Color("e8e4da"),.2);card.add_theme_stylebox_override("panel",card_style);menu_root.add_child(card);card.resized.connect(_center_card);card.draw.connect(_draw_card_edge)

func _choices(parent:Node,key:String,values:Array,position:Vector2,width:float,labels:Array=[])->void:
 var panel_choices=panel!=null and panel.is_ancestor_of(parent)
 var full_width=width*values.size()+4*(values.size()-1)
 var segment_width=(full_width+values.size()-1)/values.size() if panel_choices else width
 var stride=segment_width-1 if panel_choices else width+4
 for index in values.size():
  var value=values[index];var label=str(labels[index]) if not labels.is_empty() else str(value)
  var button=_button(parent,label.to_upper(),Rect2(position+Vector2(index*stride,0),Vector2(segment_width,40 if panel_choices else 34)),"select_"+key+"_"+str(value))
  button.add_theme_font_size_override("font_size",12)
  if button.has_method("configure_segmented"):
   button.configure_segmented(panel_choices);button.size=button.custom_minimum_size
  button.pressed.disconnect(_action.bind("select_"+key+"_"+str(value)));button.pressed.connect(_select.bind(key,value));choices.append({"key":key,"value":value,"button":button})
 _refresh_choices()
func _select(key:String,value:Variant)->void:
 settings[key]=value
 if key=="difficulty":flow.mission.set_difficulty(value)
 if key=="mode":flow.selected_mode=value;_mode_note()
 if key=="fov":flow.mission.player.set_fov(value)
 if key=="view":settings.view=weapon.set_view(value)
 setting_changed.emit(key,value);_refresh_choices();_save()
func _refresh_choices()->void:
 _refresh_setting_outputs()
 for index in range(choices.size()-1,-1,-1):
  var item:Dictionary=choices[index]
  if not is_instance_valid(item.button) or not item.button.is_inside_tree():choices.remove_at(index);continue
  var button:Button=item.button;var selected=(effective_quality if settings.quality=="auto" else settings.quality)==item.value if item.key=="quality" else settings[item.key]==item.value
  if button.has_method("set_selected"):button.set_selected(selected);continue
  button.add_theme_stylebox_override("normal",_style(BONE if selected else Color(.043,.051,.059,.65),BONE if selected else Color(.91,.89,.85,.4)));button.add_theme_color_override("font_color",Color("0b0d0f") if selected else BONE)
  button.add_theme_color_override("font_focus_color",Color("0b0d0f") if selected else BONE)
  if item.key in ["view","mode","difficulty"]:
   for state in ["normal","hover","focus","pressed"]:
    var style=button.get_theme_stylebox(state).duplicate()
    style.content_margin_left=6;style.content_margin_right=6
    button.add_theme_stylebox_override(state,style)
   if item.key=="view":button.size=button.custom_minimum_size

func _save()->void:
 if save_path.is_empty():return
 var file=FileAccess.open(save_path,FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(settings));file.close()

func _build_hud()->void:
 hud=Control.new();hud.modulate.a=0;hud.visible=false;hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(hud)
 navigation_hud=SaltlineNavigationHud.new();hud.add_child(navigation_hud);navigation_hud.setup(flow.mission,flow.camera,weapon)
 status_hud=SaltlineStatusHud.new();hud.add_child(status_hud);status_hud.setup(flow.mission,weapon)
 objective=preload("res://scripts/objective_hud.gd").new();objective.position=Vector2(16,16);objective.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(objective)
 location=preload("res://scripts/location_hud.gd").new();root.add_child(location)
 radio=preload("res://scripts/radio_hud.gd").new();radio.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(radio)
 announcements=preload("res://scripts/announcements_hud.gd").new();announcements.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(announcements)

func _set_veil(value:String)->void:
 veil_screen=value
 if not veil_initialized:
  veil_initialized=true;veil_opacity_transition.reset(1.0 if value!="none" else 0.0)
 else:veil_opacity_transition.set_target(value!="none")
 _update_veil(0.0)
func _update_veil(dt:float)->void:
 var alpha=veil_opacity_transition.advance(dt)
 title_veil.modulate.a=alpha;pause_veil.modulate.a=alpha
 title_veil.visible=veil_screen=="title" and alpha>0
 pause_veil.visible=veil_screen!="title" and alpha>0
 pause_veil.color.a=.35 if veil_screen=="dead" else .62

func _show(value:String)->void:
 if value=="title":
  for i in 3:buttons[["deploy","settings","controls"][i]]=responsive_title.action_buttons[i]
 title_bars.show_title(value=="title")
 if value!=shown_screen:
  panel_open=false;panel.visible=false;shown_screen=value
 _set_veil(value)
 title.visible=value=="title";card.visible=value in ["paused","dead","complete"];menu_root.visible=value!="none" or panel_open
 if not card.visible:return
 for child in card.get_children():card.remove_child(child);child.queue_free()
 var card_view=Control.new();card.add_child(card_view)
 card_scroll=ScrollContainer.new();card_scroll.name="CardScroll";card_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;card_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;card_scroll.follow_focus=true;card_view.add_child(card_scroll);card_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 # Overlay scrolling preserves the original card's full content width.
 card_scrollbar=VScrollBar.new();card_view.add_child(card_scrollbar);card_scrollbar.share(card_scroll.get_v_scroll_bar());card_scrollbar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);card_scrollbar.offset_left=-card_scrollbar.get_combined_minimum_size().x
 card_margin=MarginContainer.new();card_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card_scroll.add_child(card_margin)
 var box=VBoxContainer.new();box.add_theme_constant_override("separation",0);card_margin.add_child(box)
 var content=preload("res://scripts/result_card_content.gd").new();var rows=[];var rating=""
 if value=="dead":
  rows=[["Time survived",_time(flow.mission.run.time)],["Relays cut","%d/%d"%[flow.mission.run.cut,flow.mission.relays.size()]]]
  if flow.mission.run.mode=="holdout":rows=[["Time survived",_time(flow.mission.run.time)],["Waves cleared",str(flow.holdout_result.waves)],["Machines destroyed",str(flow.holdout_result.kills)],["Score",_score_text(flow.holdout_result.score)],["Best",_score_text(flow.holdout_result.best)]]
 elif value=="complete":
  var result=flow.mission.debrief;rating=result.rating;rows=[["Time",_time(result.time)],["Accuracy","—" if result.accuracy==null else "%d%%"%int(round(result.accuracy*100))],["Machines destroyed",str(result.kills)],["Retries",str(result.retries)]]
 if touch_input!=null and touch_input.enabled:content.pause_hint=""
 content.configure(value,rows,rating);box.add_child(content);card_content=content
 var gap=Control.new();box.add_child(gap);card_gap=gap
 var actions_box=VBoxContainer.new();box.add_child(actions_box);card_actions=actions_box
 card.queue_redraw()
 var actions=["resume","settings","controls","restart"] if value=="paused" else ["retry"] if value=="dead" else ["redeploy"]
 for index in actions.size():
  var action:String=actions[index];var button=_button(actions_box,{"resume":"RESUME","settings":"SETTINGS","controls":"CONTROLS","restart":"RESTART MISSION","retry":"RETRY","redeploy":"REDEPLOY"}[action],Rect2(0,0,0,52 if index==0 else 46),action,index==0)
  if index==0:call_deferred("_focus_if_live",button)
 card_window=Vector2.ZERO;_layout_card()

func _layout_card()->void:
 var screen=get_viewport().get_visible_rect().size
 if screen==card_window:return
 card_window=screen;var short=screen.y<=520;var narrow=screen.x<=760
 card_margin.add_theme_constant_override("margin_left",20 if narrow or short else 26);card_margin.add_theme_constant_override("margin_right",20 if narrow or short else 26)
 card_margin.add_theme_constant_override("margin_top",16 if short else 22 if narrow else 26);card_margin.add_theme_constant_override("margin_bottom",16 if short else 20 if narrow else 24)
 card_content.layout(screen);card_gap.custom_minimum_size.y=12 if short else 22;card_actions.add_theme_constant_override("separation",6 if short else 10)
 for i in card_actions.get_child_count():card_actions.get_child(i).custom_minimum_size.y=(44 if i==0 else 40) if short else (52 if i==0 else 46)
 var content_height=card_content.custom_minimum_size.y+card_gap.custom_minimum_size.y+card_margin.get_theme_constant("margin_top")+card_margin.get_theme_constant("margin_bottom")+4
 for button in card_actions.get_children():content_height+=button.custom_minimum_size.y
 content_height+=(card_actions.get_child_count()-1)*card_actions.get_theme_constant("separation")
 card_scrollbar.visible=content_height>screen.y-24
 var width=minf(430,screen.x-32);var height=minf(screen.y-24,content_height)
 card.custom_minimum_size=Vector2(width,0);card.size=Vector2(width,height);_center_card()

func _build_panel()->void:
 panel=PanelContainer.new();var style=_style(Color(.043,.051,.059,.95),Color(BONE,.2));style.set_border_width_all(0);style.border_width_left=1;style.content_margin_left=22;style.content_margin_right=20;style.content_margin_top=18;style.content_margin_bottom=24
 panel.add_theme_stylebox_override("panel",style);root.add_child(panel);panel.visible=false;panel.focus_mode=Control.FOCUS_ALL
 _layout_panel()
func _layout_panel()->void:
 var window_size=Vector2(get_window().size);var logical=get_viewport().get_visible_rect().size
 if window_size.x<=0 or window_size.y<=0:return
 panel.scale=logical/window_size;panel.size=Vector2(minf(440,window_size.x),window_size.y);panel.position=Vector2(logical.x-panel.size.x*panel.scale.x,0)
func open_panel(controls:bool=false)->void:
 if not panel_open:
  var focused=get_viewport().gui_get_focus_owner()
  panel_return_focus=weakref(focused) if focused!=null else null
 setting_outputs.clear();quality_note=null
 panel_tab="controls" if controls else "settings"
 panel_open=true;panel.visible=true;menu_root.visible=true
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",6);panel.add_child(column)
 var header=Control.new();header.custom_minimum_size.y=45;column.add_child(header)
 var separator=ColorRect.new();separator.color=Color(Color("e8e4da"),.2);separator.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(separator);separator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);separator.offset_left=-22;separator.offset_right=20;separator.offset_top=-1;separator.offset_bottom=0
 var tabs=HBoxContainer.new();tabs.add_theme_constant_override("separation",22);header.add_child(tabs)
 for tab_name in ["settings","controls"]:
  var tab=preload("res://scripts/panel_tab.gd").new();tab.text=tab_name.to_upper();tab.configure_tab((tab_name=="controls")==controls);tab.pressed.connect(_action.bind(tab_name+"_tab"));tabs.add_child(tab);buttons[tab_name+"_tab"]=tab
 var close=_button(header,"CLOSE",Rect2(0,5,70,34),"close");close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);close.offset_left=-70;close.offset_right=0;close.offset_top=5;close.offset_bottom=39
 var scroll=ScrollContainer.new();scroll.name="ControlTables" if controls else "SettingsScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;column.add_child(scroll)
 if controls:
  _build_control_tables(scroll);_layout_panel();call_deferred("_focus_if_live",panel);return
 var body=Control.new();body.custom_minimum_size=Vector2(0,785);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
 var width=maxf(220,minf(440,get_window().size.x)-58)
 _label(body,"DIFFICULTY",Vector2(0,9),15);_choices(body,"difficulty",["standard","hard","brutal"],Vector2(0,34),(width-8)/3)
 _label(body,"WEAPON POSITION",Vector2(0,94),15);_choices(body,"view",[1,2,3],Vector2(0,119),(width-8)/3,["Close","Three-quarter","Compact"])
 _label(body,"GRAPHICS QUALITY",Vector2(0,179),15);_choices(body,"quality",["low","medium","high","ultra"],Vector2(0,204),(width-12)/4)
 _label(body,"MOUSE SENSITIVITY",Vector2(0,264),15);_slider(body,"sens",Vector2(0,289),.2,3,.05)
 _label(body,"INVERT Y",Vector2(0,349),13)
 var invert=preload("res://scripts/panel_toggle.gd").new();invert.position=Vector2(0,374);invert.configure(settings.invertY);invert.set_meta("setting_key","invertY");invert.toggled.connect(func(value):_select("invertY",value));body.add_child(invert)
 _label(body,"FIELD OF VIEW",Vector2(0,414),15);_slider(body,"fov",Vector2(0,439),60,95,1)
 _button(body,"EXIT FULLSCREEN" if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else "ENTER FULLSCREEN",Rect2(0,504,260,38),"fullscreen")
 quality_note=_label(body,"",Vector2(0,570),14);quality_note.size=Vector2(width,100);quality_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;quality_note.add_theme_color_override("font_color",STEEL);_refresh_setting_outputs()
 _label(body,"MASTER VOLUME",Vector2(0,690),15);_slider(body,"volume",Vector2(0,715),0,1,.01)
 _layout_panel();call_deferred("_focus_if_live",panel)

func _build_control_tables(body:Control)->void:
 var content=preload("res://scripts/control_content.gd").new();content.name="OriginalControlContent";body.add_child(content)

func _slider(parent:Node,key:String,position:Vector2,minimum:float,maximum:float,step:float)->void:
 var width=maxf(220,minf(440,get_window().size.x)-58)
 var slider=preload("res://scripts/panel_slider.gd").new();slider.set_meta("setting_key",key);slider.position=position;slider.size=Vector2(width-70,28);slider.min_value=minimum;slider.max_value=maximum;slider.step=step;slider.value=settings[key];slider.value_changed.connect(func(value):_select(key,value));parent.add_child(slider)
 var output=_label(parent,"",position+Vector2(width-60,2),13,mono);output.size.x=60;output.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;setting_outputs[key]=output;_refresh_setting_outputs()

func _refresh_setting_outputs()->void:
 for key in setting_outputs:
  if is_instance_valid(setting_outputs[key]):
   if key=="sens":setting_outputs[key].text="%.2f×"%settings.sens
   elif key=="volume":setting_outputs[key].text="%d%%"%int(round(settings.volume*100))
   else:setting_outputs[key].text="%d°"%int(round(settings.fov))
 if is_instance_valid(quality_note):quality_note.text=("Quality was picked for this device (%s). Lower it if the frame rate struggles."%effective_quality if settings.quality=="auto" else "Quality changes apply at once; shadows and reflections may take a moment to rebuild.")+" Difficulty applies to machines that arrive from now on."

func _input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed:
  for button in buttons.values():
   if is_instance_valid(button) and button.has_method("configure_segmented"):button.focus_visible=true;button.queue_redraw()
 if not panel_open or not event is InputEventKey or not event.pressed:return
 if event.keycode==KEY_ESCAPE:close_panel();get_viewport().set_input_as_handled()
 elif event.keycode==KEY_TAB:
  var controls=[];_pad_controls(panel,controls)
  if not controls.is_empty():
   var index=controls.find(get_viewport().gui_get_focus_owner());var direction=-1 if event.shift_pressed else 1
   _focus_control(controls[(controls.size()-1 if direction<0 else 0) if index<0 else posmod(index+direction,controls.size())])
  get_viewport().set_input_as_handled()

func _focus_if_live(control:Control)->void:
 if is_instance_valid(control) and control.is_inside_tree():control.grab_focus()

func _focus_control(control:Control)->void:
 control.grab_focus()
 if control.has_method("show_keyboard_focus"):control.show_keyboard_focus()

func _pad_controls(node:Node,result:Array)->void:
 if node is BaseButton and node.is_visible_in_tree() and not node.disabled:result.append(node)
 elif node is HSlider and node.is_visible_in_tree() and node.editable:result.append(node)
 for child in node.get_children():_pad_controls(child,result)
func pad_nav(direction:int)->void:
 var controls=[];_pad_controls(panel if panel_open else title if flow.menu=="title" else card,controls)
 if controls.is_empty():return
 var index=controls.find(get_viewport().gui_get_focus_owner())
 index=(0 if direction>0 else controls.size()-1) if index<0 else posmod(index+direction,controls.size())
 _focus_control(controls[index])
func pad_adjust(direction:int)->void:
 var focused=get_viewport().gui_get_focus_owner()
 if focused is HSlider and focused.is_visible_in_tree():focused.value=clampf(focused.value+direction*focused.step*(2 if focused.get_meta("setting_key","")=="sens" else 1),focused.min_value,focused.max_value)
 else:pad_nav(direction)
func pad_primary()->void:
 var action={"title":"deploy","paused":"resume","dead":"retry","complete":"redeploy"}.get(flow.menu,"")
 if not action.is_empty() and buttons.has(action):buttons[action].pressed.emit()
func pad_accept()->void:
 var focused=get_viewport().gui_get_focus_owner()
 if focused is BaseButton and focused.is_visible_in_tree():
  if focused.toggle_mode:focused.button_pressed=not focused.button_pressed
  focused.pressed.emit()
 else:pad_primary()
func close_panel()->void:
 panel_open=false;panel.visible=false;menu_root.visible=flow.menu!="none"
 var previous=panel_return_focus.get_ref() if panel_return_focus!=null else null
 if is_instance_valid(previous) and previous.is_visible_in_tree():previous.grab_focus()
 else:
  var action={"title":"deploy","paused":"resume","dead":"retry","complete":"redeploy"}.get(flow.menu,"")
  if buttons.has(action):buttons[action].grab_focus()
func _action(action:String)->void:
 match action:
  "deploy":flow.start()
  "resume":flow.resume()
  "restart","retry":flow.retry()
  "redeploy":flow.redeploy()
  "settings":open_panel()
  "controls":open_panel(true)
  "settings_tab":open_panel();call_deferred("_focus_if_live",buttons.settings_tab)
  "controls_tab":open_panel(true);call_deferred("_focus_if_live",buttons.controls_tab)
  "close":close_panel()
  "fullscreen":DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
func _radio(text:String,duration:float)->void:comms.enqueue(text,duration)
func _clear_radio()->void:comms.clear()
func _reset_hud()->void:
 comms.clear();feedback.reset();announcements.clear()
 objective.set_objective("")
 status_hud.interaction.set_prompt(null)
func _warning(text:String,duration:float)->void:announcements.warn(text,duration)
func _message(text:String,duration:float)->void:announcements.show_message(text,duration)
func _enemy_killed(actor:Variant)->void:feedback.enemy_killed(actor.state.type,Engine.get_process_frames())
func _enemy_hit(_enemy:Variant,part:String,killed:bool,weak:bool)->void:feedback.enemy_hit(killed,weak,part,Engine.get_process_frames())
func _player_hit(_amount:float,from_position:Variant)->void:feedback.player_hit(from_position)
func _score_text(value:float)->String:
 var raw=str(int(round(value)));var out=""
 for i in raw.length():
  if i>0 and (raw.length()-i)%3==0:out+=","
  out+=raw[i]
 return out
func _time(seconds:float)->String:return "%02d:%02d"%[int(seconds)/60,int(seconds)%60]
func update_frame(dt:float,world_time:float=-1)->void:
 preload("res://scripts/motion_preference.gd").refresh(DisplayServer.accessibility_should_reduce_animation())
 if card.visible:_layout_card()
 title_bars.update_frame(dt)
 _update_veil(dt)
 var viewport_size=get_window().size
 responsive_title.update_layout()
 title_legend.update_layout()
 if panel_open:
  _layout_panel()
  if panel_tab=="settings" and is_instance_valid(buttons.get("fullscreen")):
   buttons.fullscreen.text="EXIT FULLSCREEN" if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else "ENTER FULLSCREEN"
 location.update_frame(dt)
 feedback.update(dt,flow.mission.player.pos,flow.mission.player.yaw,flow.state in ["intro","playing"])
 navigation_hud.update_frame(dt);status_hud.update_frame(dt)
 if source_post:
  var values={"uFade":flow.fade,"uSaturation":flow.saturation,"uDamage":clampf(flow.mission.player.hurt_pulse,0,1),"uLowHealth":clampf(flow.mission.player.low_health,0,1),"uAds":clampf(flow.mission.player.ads,0,1),"uTime":world_time if world_time>=0 else flow.world_time}
  for key in values:post.set_shader_parameter(key,values[key])
 else:post.set_shader_parameter("fade",flow.fade);post.set_shader_parameter("saturation",flow.saturation)
 hud_on=flow.state in ["intro","playing"] and not panel_open
 hud_opacity_transition.set_target(hud_on)
 hud.modulate.a=hud_opacity_transition.advance(dt);hud.visible=hud.modulate.a>0
 var tally=""
 if flow.mission.run.mode=="holdout":tally="Wave %d · %s"%[flow.mission.run.wave,_score_text(flow.mission.run.score)] if flow.mission.run.wave>0 else "Stand by"
 if hud_on:objective.update_frame(dt,flow.mission.objective_text(),flow.mission.run.cut,flow.mission.relays.size(),tally)
 comms.update(dt);radio.update_frame(dt,comms.text,comms.visible)
 announcements.update_frame(dt,hud_on)

func dispose()->void:
 status_hud.dispose()
 if flow.mission.manager.combat.enemy_killed.is_connected(_enemy_killed):flow.mission.manager.combat.enemy_killed.disconnect(_enemy_killed)
 if flow.mission.manager.combat.hit_enemy.is_connected(_enemy_hit):flow.mission.manager.combat.hit_enemy.disconnect(_enemy_hit)
 if flow.mission.player.hit.is_connected(_player_hit):flow.mission.player.hit.disconnect(_player_hit)
 if flow.menu_changed.is_connected(_show):flow.menu_changed.disconnect(_show)
 if flow.radio_requested.is_connected(_radio):flow.radio_requested.disconnect(_radio)
 if flow.mission.radio_requested.is_connected(_radio):flow.mission.radio_requested.disconnect(_radio)
 if flow.mission.hud_reset.is_connected(_reset_hud):flow.mission.hud_reset.disconnect(_reset_hud)
 if flow.mission.radio_cleared.is_connected(_clear_radio):flow.mission.radio_cleared.disconnect(_clear_radio)
 if flow.mission.warning.is_connected(_warning):flow.mission.warning.disconnect(_warning)
 if flow.mission.message.is_connected(_message):flow.mission.message.disconnect(_message)

func _mode_note()->void:
 if mode_note!=null:mode_note.text="Cut three relays and reach the boat. About five minutes." if settings.mode=="mission" else "Endless waves that keep growing. Resupply between waves. How long can you hold?"
func _draw_card_edge()->void:
 card.draw_line(Vector2(0,1.5),Vector2(card.size.x,1.5),Color("ff5a40") if flow.menu=="dead" else SIGNAL,3)
func _center_card()->void:card.position=(get_viewport().get_visible_rect().size-card.size)*.5
