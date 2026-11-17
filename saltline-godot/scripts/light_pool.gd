class_name SaltlineLightPool
extends Node3D

const CAPACITY=6
var slots:Array=[]
var emitted=0
var updates=0

func _ready()->void:
 for i in CAPACITY:
  var light=OmniLight3D.new();light.light_energy=0;light.omni_range=12;light.omni_attenuation=2;light.light_cull_mask=7;light.shadow_enabled=false;add_child(light)
  light.set_meta("source_light_role","pool");light.set_meta("source_pool_index",i);light.set_meta("source_intensity",0.0)
  slots.append({"source_intensity":0.0,"light":light,"busy":false,"ttl":0.0,"duration":0.0,"peak":0.0,"persistent":false})

func flash(position:Vector3,color:int=0xffc880,energy:float=30,radius:float=10,duration:float=.06)->void:
 var selected:Dictionary={}
 for slot in slots:
  if not slot.busy:selected=slot;break
 if selected.is_empty():
  for slot in slots:
   if not slot.persistent and (selected.is_empty() or slot.ttl<selected.ttl):selected=slot
 if selected.is_empty():return
 selected.light.global_position=position;selected.light.light_color=Color.hex((color<<8)|255);set_energy(selected,energy);selected.light.omni_range=radius
 selected.merge({"busy":true,"ttl":duration,"duration":duration,"peak":energy,"persistent":false},true);emitted+=1

func acquire()->Dictionary:
 for slot in slots:
  if not slot.busy:
   slot.busy=true;slot.persistent=true;set_energy(slot,0.0);return slot
 return {}

func release(slot:Dictionary)->void:
 slot.busy=false;slot.persistent=false;set_energy(slot,0.0)

func set_energy(slot:Dictionary,source_intensity:float)->void:
 slot.source_intensity=source_intensity;slot.light.set_meta("source_intensity",source_intensity);slot.light.light_energy=source_intensity/PI

func update(dt:float)->void:
 updates+=1
 for slot in slots:
  if not slot.busy or slot.persistent:continue
  slot.ttl-=dt
  if slot.ttl<=0:slot.busy=false;set_energy(slot,0.0)
  else:set_energy(slot,slot.peak*slot.ttl/slot.duration)
