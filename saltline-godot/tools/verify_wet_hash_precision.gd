extends SceneTree
## Diagnostic only: local RD, original hash arithmetic vs CPU float32 stages.

const OUTPUT := "res://evidence/wet-hash-precision-verification.json"

func _initialize() -> void:
	call_deferred("run")

func kernel(mode: String, staged: bool) -> String:
	var declaration := "precise " if mode == "precise" else ""
	var first := "R3(p*.3183099)" if mode in ["first_guard", "full_guard"] else "p*.3183099"
	var affine := first + "+vec3(.71,.113,.419)"
	var hash_code := "vec3 q=fract(%s);q*=17.;return fract(q.x*q.y*q.z*(q.x+q.y+q.z));" % affine
	if mode == "precise":
		hash_code = "precise vec3 q=p*.3183099+vec3(.71,.113,.419);q=fract(q);q*=17.;precise float h=q.x*q.y*q.z*(q.x+q.y+q.z);return fract(h);"
	if mode == "full_guard":
		hash_code = "vec3 q=R3(R3(p*.3183099)+vec3(.71,.113,.419));q=R3(fract(q));q=R3(q*17.);float xy=R(q.x*q.y);float xyz=R(xy*q.z);float sx=R(q.x+q.y);float s=R(sx+q.z);return fract(R(xyz*s));"
	var body := "output_bits[k]=floatBitsToUint(H(p));"
	if staged:
		body = """
%svec3 a=p*.3183099;
%svec3 b=%s;
%svec3 f=fract(b);
%svec3 q=f*17.;
%sfloat xy=q.x*q.y;
%sfloat xyz=xy*q.z;
%sfloat sx=q.x+q.y;
%sfloat s=sx+q.z;
%sfloat v=xyz*s;
float h=fract(v);
float values[18]=float[18](a.x,a.y,a.z,b.x,b.y,b.z,f.x,f.y,f.z,q.x,q.y,q.z,xy,xyz,sx,s,v,h);
for(uint j=0u;j<18u;j++) output_bits[k*18u+j]=floatBitsToUint(values[j]);
""" % [declaration,declaration,affine,declaration,declaration,declaration,declaration,declaration,declaration,declaration]
		if mode == "full_guard":
			for pair in [["b="+affine, "b=R3("+affine+")"], ["q=f*17.","q=R3(f*17.)"], ["xy=q.x*q.y","xy=R(q.x*q.y)"], ["xyz=xy*q.z","xyz=R(xy*q.z)"], ["sx=q.x+q.y","sx=R(q.x+q.y)"], ["s=sx+q.z","s=R(sx+q.z)"], ["v=xyz*s","v=R(xyz*s)"]]:
				body=body.replace(pair[0],pair[1])
	return """#version 450
layout(local_size_x=64,local_size_y=1,local_size_z=1) in;
layout(set=0,binding=0,std430) readonly buffer Input { vec4 points[]; };
layout(set=0,binding=1,std430) writeonly buffer Output { uint output_bits[]; };
layout(set=0,binding=2,std140) uniform Control { uvec4 control; };
float R(float v){return uintBitsToFloat(floatBitsToUint(v)+control.x);}
vec3 R3(vec3 v){return uintBitsToFloat(floatBitsToUint(v)+uvec3(control.x));}
float H(vec3 p){%s}
void main(){uint k=gl_GlobalInvocationID.x;if(k>=control.y)return;vec3 p=points[k].xyz;%s}
""" % [hash_code, body]

func uniform_buffer(type: int, binding: int, rid: RID) -> RDUniform:
	var result := RDUniform.new()
	result.uniform_type=type
	result.binding=binding
	result.add_id(rid)
	return result

func run() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/wet-hash-diagnostic-input.json"))
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("Vulkan local RD unavailable; run with a real rendering driver")
		quit(2)
		return
	var count: int=source.cases.size()
	var input := PackedFloat32Array()
	for item in source.cases:
		input.append_array(PackedFloat32Array([item.cell[0],item.cell[1],item.cell[2],0]))
	var input_rid := rd.storage_buffer_create(input.size()*4,input.to_byte_array())
	var control := PackedByteArray()
	control.resize(16)
	control.encode_u32(0,0)
	control.encode_u32(4,count)
	var control_rid := rd.uniform_buffer_create(16,control)
	var reports := []
	for mode in ["plain","first_guard","full_guard","precise"]:
		for staged in [false,true]:
			var glsl := kernel(mode,staged)
			var shader_source := RDShaderSource.new()
			shader_source.source_compute=glsl
			var spirv := rd.shader_compile_spirv_from_source(shader_source)
			if not spirv.compile_error_compute.is_empty():
				push_error(spirv.compile_error_compute)
				quit(3)
				return
			var suffix: String=mode+("-staged" if staged else "-final")
			FileAccess.open("/tmp/saltline-wet-"+suffix+".spv",FileAccess.WRITE).store_buffer(spirv.bytecode_compute)
			FileAccess.open("/tmp/saltline-wet-"+suffix+".glsl",FileAccess.WRITE).store_string(glsl)
			var shader := rd.shader_create_from_spirv(spirv)
			var pipeline := rd.compute_pipeline_create(shader)
			var stride := 18 if staged else 1
			var output := rd.storage_buffer_create(count*stride*4)
			var uniforms := [uniform_buffer(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,0,input_rid),uniform_buffer(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,1,output),uniform_buffer(RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,2,control_rid)]
			var set_rid := rd.uniform_set_create(uniforms,shader,0)
			var list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(list,pipeline)
			rd.compute_list_bind_uniform_set(list,set_rid,0)
			rd.compute_list_dispatch(list,ceili(count/64.0),1,1)
			rd.compute_list_end()
			rd.submit()
			rd.sync()
			var data := rd.buffer_get_data(output)
			FileAccess.open("/tmp/saltline-wet-"+suffix+".bin",FileAccess.WRITE).store_buffer(data)
			var stage_failures := PackedInt32Array()
			stage_failures.resize(stride)
			var failures := []
			var mismatch := 0
			for i in count:
				for j in stride:
					var slot := j if staged else 17
					var actual := data.decode_u32((i*stride+j)*4)
					var expected: int=source.cases[i].expected_bits[slot]
					if actual != expected:
						mismatch+=1
						stage_failures[j]+=1
						if failures.size()<12:
							failures.append({"cell":source.cases[i].cell,"stage":source.stages[slot],"expected_bits":expected,"actual_bits":actual,"actual_float":data.decode_float((i*stride+j)*4)})
			var report := {"mode":mode,"staged":staged,"mismatches":mismatch,"stage_failures":Array(stage_failures),"first_corner_bits":Array(data.slice(0,stride*4).to_int32_array()),"first_corner_floats":Array(data.slice(0,stride*4).to_float32_array()),"failures":failures}
			reports.append(report)
			print(JSON.stringify({"mode":mode,"staged":staged,"mismatches":mismatch,"stage_failures":Array(stage_failures),"corner_hash":data.decode_float((stride-1)*4)}))
			for rid in [set_rid,output,pipeline,shader]:
				rd.free_rid(rid)
	for rid in [input_rid,control_rid]:
		rd.free_rid(rid)
	rd.free()
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify({"scope":"Independent local RD diagnostics vs CPU separated-float32 stages, not original GPU reference","cells":count,"stages":source.stages,"reports":reports},"  "))
	quit()
