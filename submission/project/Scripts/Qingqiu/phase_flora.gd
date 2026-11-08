extends Node3D
## Authored asymmetric planting, separate P2 wilted art and P3 opening bloom wave.
var flower_material: ShaderMaterial
var petal_material: ShaderMaterial
var flowers: Array[MeshInstance3D]=[]
var lights: Array[OmniLight3D]=[]
var stage:=1
var particles: MultiMeshInstance3D
var bursts: Array[Dictionary]=[]
var withered: Array[MeshInstance3D]=[]
var layout: Dictionary
var bloom_active:=false
var bloom_clock:=10.0
var bloom_burst_done:=false
func _ready() -> void:
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Qingqiu/flora_layout_v6.json"))
	var random:=RandomNumberGenerator.new()
	random.seed=73519
	flower_material=ShaderMaterial.new()
	flower_material.shader=preload("res://Shaders/Qingqiu/phase_flower.gdshader")
	for entry in layout["flowers"]:
		var flower:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		var height:=float(entry["height"])
		quad.size=Vector2(height*0.92,height)
		flower.mesh=quad
		flower.position=Vector3(float(entry["x"]),height*0.5,float(entry["z"]))
		flower.material_override=flower_material
		flower.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flower.set_meta("p1_visible",bool(entry["p1_visible"]))
		flower.set_meta("bloom_jitter",float(entry["bloom_jitter"]))
		flower.set_meta("base_height",height)
		add_child(flower)
		flowers.append(flower)
	var wilt_info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Art/Qingqiu/FloraV6/manifest.json"))
	var region: Array=wilt_info["uv_region"]
	var wilt_mat:=ShaderMaterial.new()
	wilt_mat.shader=preload("res://Shaders/Qingqiu/withered_flower.gdshader")
	wilt_mat.set_shader_parameter("art_texture",preload("res://Art/Qingqiu/FloraV6/withered_flower_clump.png"))
	wilt_mat.set_shader_parameter("uv_region",Vector4(region[0],region[1],region[2],region[3]))
	for entry in layout["withered"]:
		var plant:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		var height:=float(entry["height"])
		quad.size=Vector2(height*float(wilt_info["display_aspect"]),height)
		plant.mesh=quad
		plant.position=Vector3(entry["x"],height*0.5,entry["z"])
		plant.material_override=wilt_mat
		plant.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plant)
		plant.set_instance_shader_parameter("flip",1.0 if entry["flip"] else 0.0)
		withered.append(plant)
	for index in [15,57,95,130]:
		var light:=OmniLight3D.new()
		light.position=flowers[index].position+Vector3(0,0.35,0)
		light.omni_range=2.8
		add_child(light)
		lights.append(light)
	particles=MultiMeshInstance3D.new()
	var mesh:=MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_3D
	mesh.use_custom_data=true
	mesh.instance_count=512
	var petal:=QuadMesh.new()
	petal.size=Vector2(1,1)
	mesh.mesh=petal
	for i in 512:
		var point: Vector3=flowers[i%flowers.size()].position
		if i%7==0:point=Vector3(random.randf_range(-8,8),random.randf_range(0.2,1.0),random.randf_range(-7,9))
		point+=Vector3(random.randf_range(-0.55,0.55),0,random.randf_range(-0.55,0.55))
		var size:=random.randf_range(0.045,0.11)
		mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),point))
		mesh.set_instance_custom_data(i,Color(random.randf(),random.randf(),random.randf(),random.randf()))
	particles.multimesh=mesh
	particles.custom_aabb=AABB(Vector3(-19,-1,-19),Vector3(38,10,38))
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	petal_material=ShaderMaterial.new()
	petal_material.shader=preload("res://Shaders/Qingqiu/rising_petals.gdshader")
	particles.material_override=petal_material
	add_child(particles)
	set_phase(1)
func set_phase(phase: int) -> void:
	for burst in bursts:
		if is_instance_valid(burst["node"]):burst["node"].queue_free()
	bursts.clear()
	stage=phase
	bloom_active=false
	bloom_clock=10.0
	bloom_burst_done=false
	if flower_material==null:return
	flower_material.set_shader_parameter("phase",phase)
	flower_material.set_shader_parameter("bloom_clock",bloom_clock)
	petal_material.set_shader_parameter("phase",phase)
	for flower in flowers:
		flower.visible=phase==3 or (phase==1 and flower.get_meta("p1_visible"))
		var size:=1.23 if phase==3 else 1.0
		flower.scale=Vector3.ONE*size
		flower.position.y=float(flower.get_meta("base_height"))*0.5*size
	for plant in withered:plant.visible=phase==2
	var palettes: Array=[
		["#1685a9","#003472","#70f3ff","#21a675","#1685a9","#70f3ff"],
		["#392f41","#3d3b4f","#392f41","#392f41","#392f41","#bbcdc5"],
		["#ffa400","#4c221b","#c32136","#75664d","#ffa400","#bbcdc5"]]
	var colors: Array=palettes[phase-1]
	for i in 4:flower_material.set_shader_parameter(["petal_color","outline_color","core_color","stem_color"][i],Color(colors[i]))
	petal_material.set_shader_parameter("petal_tint",Color(colors[4]))
	petal_material.set_shader_parameter("star_tint",Color(colors[5]))
	for light in lights:
		light.light_color=Color("#70f3ff") if phase==1 else Color("#ffa400")
		light.light_energy=0.0 if phase==2 else 0.22
func prepare_bloom(center: Vector3) -> void:
	if stage!=3:return
	bloom_active=false
	bloom_clock=-0.1
	bloom_burst_done=false
	flower_material.set_shader_parameter("bloom_clock",bloom_clock)
	for flower in flowers:
		var delay:=clampf((Vector2(flower.position.x-center.x,flower.position.z-center.z).length()-4.0)*0.105,0.0,1.55)+float(flower.get_meta("bloom_jitter"))
		flower.set_instance_shader_parameter("bloom_delay",delay)
	for light in lights:light.light_energy=0.0
func begin_bloom() -> void:
	if stage!=3:return
	bloom_clock=0.0
	bloom_active=true
func finish_bloom() -> void:
	bloom_active=false
	bloom_clock=10.0
	if flower_material!=null:flower_material.set_shader_parameter("bloom_clock",bloom_clock)
	if stage==3:
		for light in lights:light.light_energy=0.22

func emit_burst(point: Vector3) -> void:
	var node:=MultiMeshInstance3D.new()
	var mesh:=MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_3D
	mesh.use_custom_data=true
	mesh.instance_count=36
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	mesh.mesh=quad
	for i in 36:
		mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.07+float(i%4)*0.02)),Vector3(0,0.12,0)))
		mesh.set_instance_custom_data(i,Color(float(i)/36.0,float(i%7)/7.0,float(i%5)/5.0,float(i%11)/11.0))
	node.multimesh=mesh
	node.position=point
	node.custom_aabb=AABB(Vector3(-3,-1,-3),Vector3(6,6,6))
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface: ShaderMaterial=petal_material.duplicate()
	surface.set_shader_parameter("burst",true)
	node.material_override=surface
	add_child(node)
	bursts.append({"node":node,"time":0.0,"material":surface})

func _process(delta: float) -> void:
	if bloom_active:
		bloom_clock+=delta
		flower_material.set_shader_parameter("bloom_clock",bloom_clock)
		for light in lights:light.light_energy=smoothstep(0.2,1.8,bloom_clock)*0.22
		if bloom_clock>1.1 and not bloom_burst_done:
			bloom_burst_done=true
			for index in [4,48,70,104,130,155]:emit_burst(flowers[index].position)
		if bloom_clock>=2.35:finish_bloom()
	for i in range(bursts.size()-1,-1,-1):
		var burst: Dictionary=bursts[i]
		burst["time"]+=delta
		burst["material"].set_shader_parameter("burst_clock",burst["time"])
		if burst["time"]>=1.25:
			burst["node"].queue_free()
			bursts.remove_at(i)
