extends "res://Scripts/Qingqiu/hunter_rig_v2.gd"
## AI-authored Q-body action adapter. Original approved painted parts retained.
var grip_spacing := 42.0
var palm_offset := 16.8
var blend_source_action := "idle"

func _init() -> void:
	art_root = "res://Art/Qingqiu/HunterMasterV4"

func _ready() -> void:
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(art_root + "/registration.json"))
	grip_spacing = float(registration.two_hand_separation_pixels)
	palm_offset = float(registration.two_hand_palm_offset_pixels)
	super._ready()

func play(animation_name: String, restart := true) -> void:
	if not info.has(animation_name) or (animation_name == current and not restart):
		return
	blend_source_action = current
	super.play(animation_name, restart)

func mix_pose(weight: float) -> void:
	super.mix_pose(weight)
	if info[current].get("grip_mode", "two_hand") != "two_hand":
		return
	if weight <= 0 or current in ["ward_cast", "death", "reference_pose"] or blend_source_action in ["ward_cast", "death", "reference_pose"]:
		return
	# Interpolating joint angles alone separates the support hand from the shaft.
	# Project the blended grip to both short arms, then solve the two wrists.
	var inverse := global_transform.affine_inverse()
	var weapon_frame: Transform2D = inverse * bones.weapon.global_transform
	var grip := weapon_frame.origin
	var weapon_angle := weapon_frame.get_rotation()
	var palm := Vector2(0, palm_offset).rotated(weapon_angle)
	var shaft := Vector2(0, -1).rotated(weapon_angle)
	var origins: Dictionary = {}
	var limits: Dictionary = {}
	for side in ["L", "R"]:
		origins[side] = (inverse * bones["arm_"+side].global_transform).origin
		limits[side] = bones["arm_"+side].length + bones["forearm_"+side].length - 1.0
	for iteration in 24:
		for side in ["R", "L"]:
			var center: Vector2 = origins[side] + palm + (shaft * grip_spacing if side == "L" else Vector2.ZERO)
			var delta := grip - center
			if delta.length() > float(limits[side]):
				grip = center + delta.normalized() * float(limits[side])
	for side in ["R", "L"]:
		var wrist := grip - palm - (shaft * grip_spacing if side == "L" else Vector2.ZERO)
		solve_blended_arm(side, wrist, weapon_angle, inverse)

func solve_blended_arm(side: String, target: Vector2, hand_angle: float, inverse: Transform2D) -> void:
	var upper: Bone2D = bones["arm_"+side]
	var lower: Bone2D = bones["forearm_"+side]
	var hand: Bone2D = bones["hand_"+side]
	var origin := (inverse * upper.global_transform).origin
	var delta := target - origin
	var l1: float = upper.length
	var l2: float = lower.length
	var distance := clampf(delta.length(), absf(l1-l2)+0.4, l1+l2-0.4)
	var bend := acos(clampf((l1*l1+distance*distance-l2*l2)/(2*l1*distance), -1, 1))
	var angle := delta.angle() + bend * (1.0 if side == "L" else -1.0)
	var elbow: Vector2 = origin + Vector2.RIGHT.rotated(angle) * l1
	var lower_angle: float = (target-elbow).angle()
	var parent_angle: float = (inverse * upper.get_parent().global_transform).get_rotation()
	upper.rotation = angle - parent_angle
	lower.rotation = lower_angle - angle
	hand.rotation = hand_angle - lower_angle
