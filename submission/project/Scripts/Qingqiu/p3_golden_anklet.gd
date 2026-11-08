extends Node3D
## A two-pass ankle bracelet on the camera-near forepaw, not a floor range ring.
## Cast callbacks drive its shader, local light and world-space rising sparks.
var rig
var bone:=-1
var bands: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var sparks: Array[Dictionary]=[]
var light: OmniLight3D
var anchor:=Vector3.ZERO
var clock:=0.0
var casting:=false
var cast_age:=0.0
var cast_duration:=1.0
var charge:=0.0
var flash:=0.0
var energy:=0.0
var pulse_count:=0
var random:=RandomNumberGenerator.new()
func _ready() -> void:
	rig=get_parent();bone=rig.skeleton.find_bone("front_near_paw")
	process_priority=25;random.seed=57163
	for front in [0.0,1.0]:
		var band:=MeshInstance3D.new();band.name="AnkletBack" if front<.5 else "AnkletFront"
		var quad:=QuadMesh.new();quad.size=Vector2(.34,.30);band.mesh=quad
		band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/p3_anklet.gdshader")
		material.set_shader_parameter("front_pass",front);band.material_override=material
		add_child(band);bands.append(band);materials.append(material)
	light=OmniLight3D.new();light.name="AnkletGoldLight";light.light_color=Color("#ffa400")
	light.omni_range=1.1;light.light_cull_mask=8;light.light_energy=0.0;add_child(light)
	refresh_anchor()
func begin_cast(seconds: float) -> void:
	casting=true;cast_age=0.0;cast_duration=maxf(.1,seconds);charge=0.0
func pulse() -> void:
	casting=false;flash=1.0;charge=1.0;pulse_count+=1
	refresh_anchor();emit_sparks()
func reset() -> void:
	casting=false;charge=0.0;flash=0.0;energy=0.0
	for spark in sparks:
		if is_instance_valid(spark.node):spark.node.queue_free()
	sparks.clear()
	for material in materials:material.set_shader_parameter("energy",0.0)
	if light!=null:light.light_energy=0.0
func refresh_anchor() -> void:
	if bone<0:return
	anchor=rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(bone)*Vector3(0,.17,0))
	var camera:=get_viewport().get_camera_3d()
	var foot: Vector3=rig.get_parent().global_position
	for index in bands.size():
		var band: MeshInstance3D=bands[index]
		band.global_position=anchor
		if camera:band.global_basis=camera.global_basis
		band.set_instance_shader_parameter("foot_sort_anchor",Vector4(foot.x,foot.y,foot.z,1.0))
		band.set_instance_shader_parameter("foot_sort_bias",.025 if index==0 else .10)
	if light!=null:light.global_position=anchor
func emit_sparks() -> void:
	for index in 10:
		if sparks.size()>=40:break
		var node:=MeshInstance3D.new();node.name="AnkletGoldSpark"
		var quad:=QuadMesh.new();quad.size=Vector2.ONE;node.mesh=quad
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/p3_anklet_spark.gdshader")
		node.material_override=material;add_child(node);node.top_level=true
		var point:=anchor+Vector3(random.randf_range(-.16,.16),random.randf_range(-.02,.04),random.randf_range(-.10,.10))
		node.global_position=point
		var velocity:=Vector3(random.randf_range(-.16,.16),random.randf_range(.45,.82),random.randf_range(-.12,.12))
		sparks.append({"node":node,"point":point,"velocity":velocity,"age":0.0,"life":random.randf_range(.55,.82),"size":random.randf_range(.045,.085)})
func _process(delta: float) -> void:
	if not rig.is_visible_in_tree():
		reset();return
	clock+=delta
	if casting:
		cast_age+=delta;charge=smoothstep(0.0,1.0,minf(cast_age/cast_duration,1.0))
	else:charge=move_toward(charge,0.0,delta*2.4)
	flash=maxf(0.0,flash-delta/0.80)
	energy=charge*.85+flash*1.3
	refresh_anchor()
	for material in materials:
		material.set_shader_parameter("energy",energy);material.set_shader_parameter("clock",clock)
	light.light_energy=charge*.18+flash*.45
	var camera:=get_viewport().get_camera_3d()
	for index in range(sparks.size()-1,-1,-1):
		var spark: Dictionary=sparks[index];spark.age+=delta
		if spark.age>=spark.life:
			spark.node.queue_free();sparks.remove_at(index);continue
		spark.point+=spark.velocity*delta;spark.velocity.y+=delta*.25
		spark.node.global_position=spark.point
		if camera:spark.node.global_basis=camera.global_basis.scaled(Vector3.ONE*spark.size)
		spark.node.material_override.set_shader_parameter("life",spark.age/spark.life)
