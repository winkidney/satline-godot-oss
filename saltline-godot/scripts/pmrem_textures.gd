class_name SaltlinePmremTextures
extends RefCounted
var textures={}
var records={}
func load_source()->void:
 var directory="res://assets/export/environment/pmrem-gpu/";var manifest=JSON.parse_string(FileAccess.get_file_as_string(directory+"manifest.json"))
 for record in manifest.records:
  var bytes=FileAccess.get_file_as_bytes(directory+record.file);var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
  if context.finish().hex_encode()!=record.sha256:push_error("PMREM HDR checksum mismatch: "+record.id);continue
  var image=Image.create_from_data(int(record.width),int(record.height),false,Image.FORMAT_RGBAF,bytes);image.convert(Image.FORMAT_RGBAH)
  textures[record.id]=ImageTexture.create_from_image(image);records[record.id]=record
