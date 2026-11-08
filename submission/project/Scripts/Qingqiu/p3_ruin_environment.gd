extends Node3D
## Visual-only P3 levitating ink-rock fragments; ambient ground fires removed.
const ROCK_TEXTURES: Array[Texture2D]=[
	preload("res://Art/Qingqiu/RuinMaterialsV5/sources/floating_rock_chunk_v5.png"),
	preload("res://Art/Qingqiu/RuinMaterialsV5/sources/floating_rock_splinter_v5.png")]
const ROCK_GROUPS:=[
	Vector2(-8.1,-6.0),Vector2(-3.8,-7.3),Vector2(4.3,-6.4),
	Vector2(8.1,-3.3),Vector2(-7.5,-1.4),Vector2(-7.8,5.7),
	Vector2(7.8,3.2),Vector2(5.4,8.6),Vector2(-4.8,10.0),
	Vector2(1.8,10.8),Vector2(11.8,1.5),Vector2(-11.3,7.3)]
var stones: Array[MeshInstance3D]=[]
var stone_bases: Array[Vector3]=[]
var shadows: Array[MeshInstance3D]=[]
var rock_materials: Array[ShaderMaterial]=[]
var clock:=0.0

func _ready() -> void:
	visible=false
	var random:=RandomNumberGenerator.new()
	random.seed=37019
	# Preserve the accepted rock scatter after removing the old fire draws.
	random.state=5975943966533738589
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Art/Qingqiu/RuinMaterialsV5/manifest.json"))
	var aspects: Array[float]=[]
	for id in ["floating_rock_chunk_v5","floating_rock_splinter_v5"]:
		for record in manifest["assets"]:
			if record["id"]!=id:continue
			var material:=ShaderMaterial.new()
			material.shader=preload("res://Shaders/Qingqiu/floating_rock.gdshader")
			material.set_shader_parameter("rock_texture",ROCK_TEXTURES[rock_materials.size()])
			var uv: Array=record["uv_rect"]
			material.set_shader_parameter("sprite_rect",Vector4(uv[0],uv[1],uv[2],uv[3]))
			rock_materials.append(material)
			aspects.append(float(record["display_aspect"]))
	var shadow_material:=ShaderMaterial.new()
	shadow_material.shader=preload("res://Shaders/Qingqiu/contact_shadow.gdshader")
	for index in ROCK_GROUPS.size():
		for fragment in 2:
			var stone:=MeshInstance3D.new()
			stone.name="FloatingStone%02d_%d"%[index+1,fragment+1]
			var size:=random.randf_range(0.32,0.78)
			var variant:=posmod(index+fragment,2)
			var quad:=QuadMesh.new()
			quad.size=Vector2(size,size/aspects[variant])
			stone.mesh=quad
			stone.material_override=rock_materials[variant]
			stone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var point:=Vector3(ROCK_GROUPS[index].x+random.randf_range(-0.55,0.55),random.randf_range(0.90,2.25),ROCK_GROUPS[index].y+random.randf_range(-0.45,0.45))
			stone.position=point
			add_child(stone)
			stones.append(stone)
			stone_bases.append(point)
			var shadow:=MeshInstance3D.new()
			var plane:=PlaneMesh.new()
			plane.size=Vector2(size*0.95,size*0.65)
			shadow.mesh=plane
			shadow.position=Vector3(point.x,0.016,point.z)
			shadow.material_override=shadow_material
			shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(shadow)
			shadows.append(shadow)
	set_phase(1)

func set_phase(phase: int) -> void:
	visible=phase==3
	process_mode=Node.PROCESS_MODE_INHERIT if phase==3 else Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	clock+=delta
	var camera: Camera3D=get_parent().camera
	for index in stones.size():
		var phase:=float(index)*1.37
		var drift:=Vector3(sin(clock*0.35+phase)*0.10,sin(clock*0.85+phase)*0.18,cos(clock*0.42+phase)*0.07)
		stones[index].position=stone_bases[index]+drift
		stones[index].global_basis=camera.global_basis.rotated(camera.global_basis.z,sin(clock*0.48+phase)*0.13)
		shadows[index].position=Vector3(stones[index].position.x,0.016,stones[index].position.z)
