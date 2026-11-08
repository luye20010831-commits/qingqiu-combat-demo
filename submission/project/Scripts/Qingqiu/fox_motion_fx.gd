extends Node3D
## Actual landings, P2 pose echoes and P3 footfalls / gold dust. Visual only.
@onready var arena=get_parent()
var marks: Array[Dictionary]=[]
var echoes: Array[Dictionary]=[]
var particles: Array[Dictionary]=[]
var echo_sources: Array[Dictionary]=[]
var previous_point:=Vector3.ZERO
var previous_cycle:=-1.0
var previous_phase:=1
var echo_distance:=0.0
var particle_distance:=0.0
var echo_age:=1.0
var random:=RandomNumberGenerator.new()
var landings:=0
var footsteps:=0
var echoes_emitted:=0
var particles_emitted:=0
func _ready() -> void:
	process_priority=30;random.seed=18217
	var rig=arena.forms.get_child(1).get_node("FoxRig")
	for child in rig.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial:continue
		var material: ShaderMaterial=child.material_override
		if not material.shader.resource_path.ends_with("fox_layer.gdshader"):continue
		var arrays: Array=child.mesh.surface_get_arrays(0)
		echo_sources.append({"source":child,"arrays":arrays,"skin":child.skin,"texture":material.get_shader_parameter("layer_texture")})
	reset()
func reset() -> void:
	for child in get_children():child.queue_free()
	marks.clear();echoes.clear();particles.clear()
	previous_phase=arena.phase;previous_point=arena.boss_position()
	previous_cycle=-1.0;echo_distance=0.0;particle_distance=0.0;echo_age=1.0
func landing(point: Vector3,phase: int) -> void:
	if arena.encounter.state!=arena.encounter.State.RUNNING or phase!=arena.phase:return
	landings+=1
	spawn_mark(point,5.0 if phase==3 else 3.0,.82 if phase==3 else .68,phase,.90)
func spawn_mark(point: Vector3,size: float,life: float,phase: int,alpha: float) -> void:
	if marks.size()>=12:return
	var node:=MeshInstance3D.new();node.name="LandingBlossom" if size>2.0 else "PawBlossom"
	var plane:=PlaneMesh.new();plane.size=Vector2.ONE*size;node.mesh=plane
	node.position=Vector3(point.x,.055,point.z)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/fox_foot_blossom.gdshader")
	material.set_shader_parameter("tint",Color("#ffa400") if phase==3 else Color("#bbcdc5"))
	material.set_shader_parameter("opacity",alpha);node.material_override=material
	add_child(node);marks.append({"node":node,"material":material,"age":0.0,"life":life})
func footfall(rig,far: bool) -> void:
	var bone: int=rig.skeleton.find_bone("front_far_paw" if far else "front_near_paw")
	if bone<0:return
	var point: Vector3=rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(bone).origin)
	spawn_mark(point,1.12,.54,3,.64);footsteps+=1
func skinned_snapshot(entry: Dictionary,rig) -> Mesh:
	var original: Array=entry.arrays
	if original[Mesh.ARRAY_BONES]==null or entry.skin==null:return entry.source.mesh
	var vertices: PackedVector3Array=original[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array=original[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array=original[Mesh.ARRAY_BONES]
	if weights.is_empty():return entry.source.mesh
	var skin: Skin=entry.skin
	var transforms: Array[Transform3D]=[]
	var into_mesh: Transform3D=entry.source.global_transform.affine_inverse()*rig.skeleton.global_transform
	for bind in skin.get_bind_count():
		var bone:=skin.get_bind_bone(bind)
		if bone<0:bone=rig.skeleton.find_bone(skin.get_bind_name(bind))
		transforms.append(into_mesh*rig.skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind))
	var posed:=PackedVector3Array();posed.resize(vertices.size())
	var stride:=int(weights.size()/vertices.size())
	for index in vertices.size():
		var point:=Vector3.ZERO
		for slot in stride:
			var at:=index*stride+slot
			if weights[at]>.00001:point+=(transforms[indices[at]]*vertices[index])*weights[at]
		posed[index]=point
	var arrays: Array=original.duplicate()
	arrays[Mesh.ARRAY_VERTEX]=posed;arrays[Mesh.ARRAY_BONES]=null;arrays[Mesh.ARRAY_WEIGHTS]=null
	arrays[Mesh.ARRAY_NORMAL]=null;arrays[Mesh.ARRAY_TANGENT]=null
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
func emit_echo(rig) -> void:
	if echoes.size()>=3:return
	var root:=Node3D.new();root.name="P2MovementEcho";add_child(root)
	var materials: Array[ShaderMaterial]=[]
	var foot: Vector3=arena.boss_position()
	for entry in echo_sources:
		var source: MeshInstance3D=entry.source
		if not source.is_visible_in_tree():continue
		var part:=MeshInstance3D.new();part.mesh=skinned_snapshot(entry,rig)
		part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/fox_motion_echo.gdshader")
		material.set_shader_parameter("layer_texture",entry.texture);material.set_shader_parameter("opacity",.18);part.material_override=material
		root.add_child(part);part.global_transform=source.global_transform
		part.set_instance_shader_parameter("foot_sort_anchor",Vector4(foot.x,0,foot.z,1.0))
		part.set_instance_shader_parameter("foot_sort_bias",.012+float(source.get_index())*.001)
		materials.append(material)
	echoes.append({"node":root,"materials":materials,"age":0.0,"life":.44});echoes_emitted+=1
func emit_dust(point: Vector3,heading: Vector3) -> void:
	for index in 2:
		if particles.size()>=40:return
		var node:=MeshInstance3D.new();node.name="P3WalkingGoldDust"
		var quad:=QuadMesh.new();quad.size=Vector2.ONE;node.mesh=quad
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/p3_anklet_spark.gdshader")
		node.material_override=material;add_child(node)
		var spawn_point: Vector3=point-heading*.60+Vector3(random.randf_range(-.28,.28),random.randf_range(.22,.78),random.randf_range(-.22,.22))
		var velocity: Vector3=-heading*random.randf_range(.15,.32)+Vector3(0,random.randf_range(.28,.54),0)
		var size:=random.randf_range(.07,.15)
		node.global_position=spawn_point;node.global_basis=arena.camera.global_basis.scaled(Vector3.ONE*size)
		particles.append({"node":node,"point":spawn_point,"velocity":velocity,"age":0.0,"life":random.randf_range(.65,.95),"size":size})
		particles_emitted+=1
func animate_effects(delta: float) -> void:
	for index in range(marks.size()-1,-1,-1):
		var item: Dictionary=marks[index];item.age+=delta
		item.material.set_shader_parameter("progress",minf(1.0,item.age/item.life))
		if item.age>=item.life:item.node.queue_free();marks.remove_at(index)
	for index in range(echoes.size()-1,-1,-1):
		var item: Dictionary=echoes[index];item.age+=delta
		for material in item.materials:material.set_shader_parameter("opacity",.18*(1.0-smoothstep(0.0,item.life,item.age)))
		if item.age>=item.life:item.node.queue_free();echoes.remove_at(index)
	for index in range(particles.size()-1,-1,-1):
		var item: Dictionary=particles[index];item.age+=delta
		if item.age>=item.life:item.node.queue_free();particles.remove_at(index);continue
		item.point+=item.velocity*delta
		item.node.global_position=item.point
		item.node.global_basis=arena.camera.global_basis.scaled(Vector3.ONE*item.size)
		item.node.material_override.set_shader_parameter("life",item.age/item.life)
func _process(delta: float) -> void:
	if previous_phase!=arena.phase or arena.encounter.state!=arena.encounter.State.RUNNING:
		reset();return
	if arena.phase==2 and not arena.attacks.boss_targetable():reset();return
	animate_effects(delta);echo_age+=delta
	var point: Vector3=arena.boss_position();var step:=point-previous_point;previous_point=point
	step.y=0.0
	var rig=arena.forms.get_child(arena.phase-1).get_node("FoxRig")
	var moving: bool=step.length()>.001 and step.length()<2.0 and rig.movement_speed>.12 and rig.action_player.current in ["walk","run"] and not arena.presentation.is_busy()
	if not moving:previous_cycle=-1.0;echo_distance=0;particle_distance=0;return
	if arena.phase==2:
		echo_distance+=step.length()
		if echo_distance>=.48 and echo_age>=.12:emit_echo(rig);echo_distance=0;echo_age=0
	elif arena.phase==3:
		particle_distance+=step.length()
		if particle_distance>=.22:emit_dust(point,step.normalized());particle_distance=0
		var cycle: float=rig.action_player.elapsed/maxf(rig.action_player.duration,.01)
		if previous_cycle<0.0:footfall(rig,cycle>=.5)
		elif cycle<previous_cycle:footfall(rig,false)
		elif previous_cycle<.5 and cycle>=.5:footfall(rig,true)
		previous_cycle=cycle
