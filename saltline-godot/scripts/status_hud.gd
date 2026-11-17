class_name SaltlineStatusHud
extends Control

const BONE=Color("e8e4da")
const SIGNAL=Color("ffb347")
const ALARM=Color("ff5a40")
var mission:SaltlineMission
var weapon:SaltlineWeapon
var display:Font
var label_font:Font
var mono:Font
var status:Dictionary={}
var interaction
var input_device="kbm"
var clock=0.0
var urgent_time=0.0
var health_opacity=0.0
var health_opacity_transition=preload("res://scripts/css_opacity_transition.gd").new(.6)
var touch_layout=false
var health_from=0.0
var health_target=false
var health_elapsed=0.0

static func snapshot(data:Dictionary)->Dictionary:
 var raw_mag=int(data.mag);var magazine=clampi(raw_mag if raw_mag!=0 else 30,1,60);var ammo=maxi(0,int(data.ammo));var reserve=9999 if is_inf(data.reserve) else maxi(0,int(data.reserve))
 var low=ammo<=int(ceil(magazine*.27));var cue=""
 if data.state=="reloading":cue="Reloading"
 elif data.state!="switching":
  if ammo==0:
   var device=str(data.get("device","mouse"));var touch=bool(data.get("touch",false))
   if reserve>0:cue="Reload" if touch else "X — Reload" if device=="pad" else "R — Reload"
   elif data.get("has_alt",true):cue="Empty — Y swaps" if device=="pad" else "Empty — swap" if touch else "Empty — Q swaps"
   else:cue="Empty"
  elif low:cue="Low ammo"
 var hp=maxi(0,int(ceil(data.health)));var segments=int(ceil(float(hp)/data.max_health*10))
 return {"mag":magazine,"ammo":ammo,"reserve":reserve,"ammo_text":"%02d"%ammo,"reserve_text":"∞" if reserve>=9999 else "%03d"%reserve,"low":low,"cue":cue,"urgent":ammo==0 and data.state!="reloading","health":hp,"segments":segments,"hurt":data.health<data.max_health-.5,"critical":segments<=3}

func setup(core:SaltlineMission,gun:SaltlineWeapon)->void:
 mission=core;weapon=gun;mouse_filter=Control.MOUSE_FILTER_IGNORE
 display=load("res://assets/fonts/big-shoulders-display-700.ttf");label_font=load("res://assets/fonts/barlow-condensed-600.ttf");mono=load("res://assets/fonts/ibm-plex-mono-500.ttf")
 interaction=preload("res://scripts/interaction_hud.gd").new();interaction.mouse_filter=Control.MOUSE_FILTER_IGNORE;interaction.visible=false;add_child(interaction)
 mission.prompt_changed.connect(_prompt_changed)

func _prompt_changed(value:Variant,amount:float)->void:interaction.set_prompt(value,amount,"USE" if touch_layout else "X" if input_device=="pad" else "E")
func dispose()->void:
 if mission.prompt_changed.is_connected(_prompt_changed):mission.prompt_changed.disconnect(_prompt_changed)

func update_frame(dt:float)->void:
 clock+=dt;size=get_viewport().get_visible_rect().size
 var slot:Dictionary=weapon.slots[weapon.current]
 var previous_urgent=bool(status.get("urgent",false))
 status=snapshot({"mag":slot.mag_size,"ammo":slot.ammo,"reserve":slot.reserve,"state":weapon.state,"health":mission.player.health,"max_health":mission.player.max_health,"device":input_device,"touch":touch_layout})
 if status.urgent:urgent_time=urgent_time+dt if previous_urgent else 0
 else:urgent_time=0
 if status.hurt!=health_target:health_from=health_opacity;health_elapsed=0;health_target=status.hurt;health_opacity_transition.set_target(health_target,.12 if health_target else .6)
 health_elapsed+=dt
 health_opacity=health_opacity_transition.advance(dt)
 interaction.update_frame(dt)
 queue_redraw()

func _width(font:Font,value:String,font_size:int,tracking:float=0)->float:
 return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+maxi(0,value.length()-1)*tracking
func _text(font:Font,value:String,point:Vector2,font_size:int,color:Color,tracking:float=0)->void:
 var x=point.x
 for index in value.length():
  var letter=value[index]
  draw_string(font,Vector2(x,point.y+1),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,color.a*.65))
  draw_string(font,Vector2(x,point.y),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
  var before=font.get_string_size(value.left(index),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  var after=font.get_string_size(value.left(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  x+=after-before+tracking
func _right(font:Font,value:String,right:float,y:float,font_size:int,color:Color,tracking:float=0)->void:
 _text(font,value,Vector2(right-_width(font,value,font_size,tracking),y),font_size,color,tracking)

func _draw()->void:
 if status.is_empty():return
 var right=size.x-16;var base=size.y-20
 var narrow=size.x<=760;var ammo_pixels=44 if touch_layout else 56 if narrow else 76
 var ammo_offset=14 if touch_layout and narrow else 0;var health_offset=22 if touch_layout and narrow else 0
 var color=SIGNAL if status.low else BONE
 var current:Dictionary=weapon.slots[weapon.current]
 var alternate="pistol" if weapon.current=="rifle" else "rifle";var alt:Dictionary=weapon.slots[alternate]
 var alt_name=str(weapon.rigs[alternate].get("name",alternate)).to_upper()
 var alt_text=("" if touch_layout else ("Y" if input_device=="pad" else "Q")+"  ")+"%s %02d / %s"%[alt_name,alt.ammo,"∞" if is_inf(alt.reserve) else str(int(alt.reserve))]
 _right(mono,alt_text,right,162.2+ammo_offset if touch_layout else base,11,Color(BONE,.64),.66)
 _right(label_font,str(weapon.rigs[weapon.current].get("name",weapon.current)).to_upper(),right,144.2+ammo_offset if touch_layout else base-18,11,Color(BONE,.82),3.08)
 for index in status.mag:
  draw_rect(Rect2(right-(status.mag-index)*(4 if touch_layout else 5)+2,121.2+ammo_offset if touch_layout else base-47,2 if touch_layout else 3,7 if touch_layout else 11),color if index<status.ammo else Color(BONE,.24))
 var reserve="/ "+status.reserve_text;var reserve_width=_width(mono,reserve,15)
 _right(mono,reserve,right,112.2+ammo_offset if touch_layout else base-59,15,BONE)
 _right(display,status.ammo_text,right-reserve_width-8,80+ammo_offset+(35.2-display.get_height(44))*.5+display.get_ascent(44) if touch_layout else base-56,ammo_pixels,color,ammo_pixels*.01)
 if not status.cue.is_empty():
  var opacity=1.0 if preload("res://scripts/motion_preference.gd").reduced or not status.urgent or fmod(urgent_time,.7)<.35 else .35
  _right(label_font,status.cue.to_upper(),right,76+ammo_offset if touch_layout else base-126+(76-ammo_pixels)*.8,12,Color(ALARM if status.urgent else SIGNAL,opacity),3.12)
 if health_opacity>0:
  var hp_color=Color(ALARM if status.critical else BONE,health_opacity)
  _text(label_font,"VITALS",Vector2(16,139+health_offset if touch_layout else size.y-65),11,Color(BONE,health_opacity*.64),2.42)
  _text(display,str(status.health),Vector2(16,172.88+health_offset if touch_layout else size.y-22),34,hp_color,.68)
  for index in 10:
   var rect=Rect2(16+34*1.6+10+index*18,165.88+health_offset if touch_layout else size.y-29,15,5)
   if index<status.segments:draw_rect(rect,hp_color)
   else:draw_rect(rect,Color(BONE,health_opacity*.24),false,1)
