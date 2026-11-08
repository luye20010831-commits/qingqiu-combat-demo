extends RefCounted
## One material setup shared by live tails and static transparent exports.
static func apply_to(material: ShaderMaterial,phase: int,number:=1) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Qingqiu/fox_tail_finish.json"))
	var points:=PackedVector2Array()
	for point in data["path_uv"]:points.append(Vector2(float(point[0]),float(point[1])))
	material.set_shader_parameter("tail_finish",1 if phase==2 else (2 if phase==3 else 0))
	material.set_shader_parameter("tail_path_uv",points)
	material.set_shader_parameter("tail_tip_start",float(data["tip_start"]))
	material.set_shader_parameter("tail_tip_softness",float(data["tip_softness"]))
	material.set_shader_parameter("tail_foil_seed",float(number-1)*float(data["foil_seed_step"]))
	for role in ["black_color","gold_color","gold_shade","gold_highlight"]:
		material.set_shader_parameter("tail_"+role,Color(data[role]))
