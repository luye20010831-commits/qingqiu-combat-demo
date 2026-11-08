extends Node3D
## Native Godot weighted-bone preview generated from the accompanying Spine JSON.
@export_range(1, 3) var phase := 1
@export var tail_cycle_seconds := 3.2
@export var tail_root_sway_degrees := 2.2
@export var tail_followthrough_degrees := 0.34
@export var tail_fan_angles: PackedFloat32Array
# Used only by the inspection scene; the actual arena leaves this at zero.
var isolated_tail := 0
@onready var skeleton: Skeleton3D = $Skeleton3D
var elapsed := 0.0
var charm_charge := 0.0
var tail_bones: Array[int] = []
var eye_materials: Array[ShaderMaterial] = []
var layer_materials: Array[ShaderMaterial] = []
var impact_remaining := 0.0
var impact_pause := 0.0

func _ready() -> void:
	for index in skeleton.get_bone_count():
		if skeleton.get_bone_name(index).begins_with("tail_"):
			tail_bones.append(index)
	for child in get_children():
		if child is MeshInstance3D:
			layer_materials.append(child.material_override)
		if child is MeshInstance3D and ("_eye_" in child.name or "_eyeliner_" in child.name):
			eye_materials.append(child.material_override)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	impact_pause = maxf(0.0, impact_pause - delta)
	if impact_pause <= 0.0:
		elapsed += delta
	impact_remaining = maxf(0.0, impact_remaining - delta)
	for material in layer_materials:
		material.set_shader_parameter("spirit_hit", pow(impact_remaining / 0.42, 1.5))
	for index in tail_bones:
		var parts := skeleton.get_bone_name(index).split("_")
		var number := int(parts[1])
		var segment := int(parts[2])
		var angle := sin(elapsed * TAU / tail_cycle_seconds + number * 0.28 - segment * 0.2)
		angle *= deg_to_rad(tail_root_sway_degrees + segment * tail_followthrough_degrees)
		var rest_rotation := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		if isolated_tail == number and segment == 0:
			rest_rotation *= Quaternion(Vector3.BACK, -deg_to_rad(tail_fan_angles[number - 1]))
		skeleton.set_bone_pose_rotation(index, rest_rotation * Quaternion(Vector3.BACK, angle))
	skeleton.set_bone_pose_position(1, Vector3(0, sin(elapsed * 1.8) * 0.012, 0))
	skeleton.set_bone_pose_rotation(2, Quaternion(Vector3.BACK, sin(elapsed * 0.9) * 0.012 + charm_charge * 0.08))
	for material in eye_materials:
		material.set_shader_parameter("charm_flash", charm_charge if phase == 1 else 0.0)

func set_charm_charge(amount: float) -> void:
	charm_charge = clampf(amount, 0.0, 1.0)

func apply_spirit_impact() -> void:
	impact_remaining = 0.42
	impact_pause = 0.035

func clear_spirit_impact() -> void:
	impact_remaining = 0.0
	impact_pause = 0.0
	for material in layer_materials:
		material.set_shader_parameter("spirit_hit", 0.0)
