extends SceneTree
const Selection=preload("res://scripts/catalog_selection.gd")
var maximum=0.0
var checks=0
var failures=[]
func compare(actual:Array,expected:Array,label:String)->void:
 if actual.size()!=expected.size():failures.append(label+" size");return
 for i in actual.size():
  checks+=1;var error=absf(float(actual[i])-float(expected[i]));maximum=maxf(maximum,error)
  if error>.00001:failures.append(label+" "+str(i))
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/catalog-selection-reference.json"))
 var props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog/props/catalog.json"));var mats=JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog/materials-full/catalog.json"));var sizes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog/prop-definitions.json"))
 for sample in reference.cases:
  var data=Selection.props(props,Array(sample.query.split(",")),sizes) if sample.kind=="props" else Selection.materials(mats,Array(sample.query.split(",",false)))
  if data.has("error"):failures.append(data.error);continue
  compare(data.selection_camera.position,sample.camera.position,sample.query+" camera");compare(data.selection_camera.target,sample.camera.target,sample.query+" target")
  var nodes=data.nodes.slice(0,data.nodes.size()-1)
  if nodes.size()!=sample.nodes.size():failures.append(sample.query+" node count");continue
  var geometry={}
  for record in data.geometries:geometry[record.id]=record
  for i in nodes.size():
   compare(nodes[i].matrix,sample.nodes[i].matrix,sample.query+" node "+str(i))
   var record=geometry[nodes[i].geometry]
   if record.attributes.position.size()/3!=sample.nodes[i].vertices:failures.append(sample.query+" vertex count "+str(i))
   if nodes[i].name!=sample.nodes[i].material:failures.append(sample.query+" material "+str(i))
 var report={"checks":checks,"maximum_error":maximum,"cases":reference.cases.size(),"failures":failures,"scope":reference.scope}
 FileAccess.open("res://evidence/catalog-selection-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
