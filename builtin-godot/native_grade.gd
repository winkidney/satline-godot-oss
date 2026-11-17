extends RefCounted

static func create_texture(mode: int = 1) -> ImageTexture3D:
	assert(mode in [1, 2], "Unknown source grade LUT")
	var size := 65 if mode == 1 else 128
	var slice_bytes := size * size * 8
	var filename := "source-grade-65.rgba16f" if mode == 1 else "source-grade-agx-128.rgba16f"
	var bytes := FileAccess.get_file_as_bytes("res://assets/" + filename)
	assert(bytes.size() == size * slice_bytes, "Missing or invalid source grade LUT")
	var slices: Array[Image] = []
	for z in size:
		slices.append(Image.create_from_data(size, size, false, Image.FORMAT_RGBAH, bytes.slice(z * slice_bytes, (z + 1) * slice_bytes)))
	var texture := ImageTexture3D.new()
	assert(texture.create(Image.FORMAT_RGBAH, size, size, size, false, slices) == OK, "Cannot create native grade LUT")
	return texture
