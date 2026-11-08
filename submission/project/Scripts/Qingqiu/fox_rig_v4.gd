extends "res://Scripts/Qingqiu/fox_rig.gd"
## Registered master cutouts: the eye pair shares one head transform and blink.
@export var blink_enabled := true
var eye_bones: Array[int] = []
var ear_bones: Array[int] = []
var eye_layers: Array[MeshInstance3D] = []
var liner_layers: Array[MeshInstance3D] = []
var closed_layers: Array[MeshInstance3D] = []
var action_player
var movement_velocity:=Vector3.ZERO
var movement_speed:=0.0
var original_scale:=Vector3.ONE
var strike_pause:=0.0
var weapon_recoil_offset:=Vector3.ZERO
var weapon_recoil_direction:=Vector3.ZERO
var weapon_recoil_amount:=0.0
var weapon_recoil_age:=1.0
var attack_tail=preload("res://Scripts/Qingqiu/fox_attack_tail_motion.gd").new()
var gait_blend_pose: Dictionary={}
var gait_blend_age:=1.0
var gait_rate_target:=1.0
var golden_anklet

func _ready() -> void:
	super._ready()
	action_player=preload("res://Scripts/Qingqiu/fox_action_player.gd").new(phase)
	original_scale=scale
	if phase in [2,3]:
		for child in get_children():
			if child is MeshInstance3D and child.name.begins_with("tail_"):
				child.material_override.set_shader_parameter("ink_tint_amount",0.0)
				var number:=int(String(child.name).split("_")[1])
				preload("res://Scripts/Qingqiu/fox_tail_style.gd").apply_to(child.material_override,phase,number)
	for side in ["left","right"]:
		eye_bones.append(skeleton.find_bone("eye_"+side))
		ear_bones.append(skeleton.find_bone("ear_"+side))
		eye_layers.append(get_node("p%d_eye_%s" % [phase,side]))
		liner_layers.append(get_node("p%d_eyeliner_%s" % [phase,side]))
		closed_layers.append(get_node("p%d_eye_closed_%s" % [phase,side]))

func _process(delta: float) -> void:
	attack_tail.clear(skeleton)
	position-=weapon_recoil_offset
	weapon_recoil_offset=Vector3.ZERO
	super._process(delta)
	if not is_visible_in_tree():
		attack_tail.stop(skeleton)
		weapon_recoil_age=1.0
		return
	# Keep the authored horizontal eye axis level. Breathing moves the whole
	# puppet; charm never independently rotates or offsets either eye.
	skeleton.set_bone_pose_rotation(2,Quaternion.IDENTITY)
	var blink_time := fmod(elapsed+0.75,5.2)
	var openness := 1.0
	if blink_enabled and blink_time < 0.22:
		openness = clampf(absf(blink_time-0.11)/0.085,0.08,1.0)
	for index in 2:
		var open: bool = openness > 0.45 or (phase==1 and charm_charge>0.05)
		skeleton.set_bone_pose_scale(eye_bones[index],Vector3.ONE)
		eye_layers[index].visible = open
		liner_layers[index].visible = open
		closed_layers[index].visible = not open
		skeleton.set_bone_pose_rotation(ear_bones[index],Quaternion(Vector3.BACK,sin(elapsed*1.7+index*0.8)*0.012))
	strike_pause=maxf(0.0,strike_pause-delta)
	if phase==3 and action_player.current in ["walk","run"]:
		action_player.speed=lerpf(action_player.speed,gait_rate_target,1.0-exp(-10.0*delta))
	if action_player!=null:action_player.advance(delta if impact_pause<=0.0 and strike_pause<=0.0 else 0.0,skeleton)
	apply_gait_blend(delta if impact_pause<=0.0 and strike_pause<=0.0 else 0.0)
	attack_tail.advance(delta if impact_pause<=0.0 and strike_pause<=0.0 else 0.0,skeleton,tail_bones)
	var reveal:=0.0
	if action_player!=null and action_player.current.begins_with("tail_unfurl"):
		reveal=pow(sin(minf(action_player.elapsed/action_player.duration,1.0)*PI),2.0)
	for surface in layer_materials:
		surface.set_shader_parameter("reveal_energy",reveal)
		surface.set_shader_parameter("reveal_color",Color("#70f3ff") if phase==2 else Color("#ffa400"))
	if phase==3:
		for eye_material in eye_materials:eye_material.set_shader_parameter("charm_flash",charm_charge)
	weapon_recoil_age+=delta
	if weapon_recoil_age<.22:
		var weight:=exp(-weapon_recoil_age*16.0)*cos(weapon_recoil_age*20.0)
		weapon_recoil_offset=weapon_recoil_direction*weapon_recoil_amount*weight
		position+=weapon_recoil_offset

func apply_weapon_hit(world_direction: Vector3,amount: float) -> void:
	clear_weapon_hit()
	world_direction.y=0.0
	weapon_recoil_direction=get_parent().global_basis.inverse()*world_direction.normalized()
	weapon_recoil_amount=amount
	weapon_recoil_age=0.0
	weapon_recoil_offset=weapon_recoil_direction*amount
	position+=weapon_recoil_offset

func clear_weapon_hit() -> void:
	position-=weapon_recoil_offset
	weapon_recoil_offset=Vector3.ZERO
	weapon_recoil_age=1.0

func clear_spirit_impact() -> void:
	super.clear_spirit_impact()
	clear_weapon_hit()

func play_action(name: String,rate := 1.0) -> bool:
	gait_blend_pose.clear()
	attack_tail.clear(skeleton)
	action_player.reset(skeleton)
	var played: bool=action_player.play(name,rate)
	if played and bool(action_player.library[name].get("immediate_pose",false)):
		action_player.blend_age=1.0
		action_player.advance(0.0,skeleton)
	return played

func stop_action() -> void:
	gait_blend_pose.clear()
	attack_tail.stop(skeleton)
	if is_instance_valid(golden_anklet):golden_anklet.reset()
	if action_player!=null:action_player.reset(skeleton)

func begin_attack_tail(seconds: float,attack: String) -> void:
	attack_tail.begin(skeleton,seconds,phase,attack)
	if is_instance_valid(golden_anklet):golden_anklet.begin_cast(seconds)

func release_attack_tail() -> void:
	attack_tail.release()
	if is_instance_valid(golden_anklet):golden_anklet.pulse()

func pulse_attack_tail(attack: String) -> void:
	attack_tail.begin(skeleton,.22,phase,attack)
	attack_tail.release()
	if is_instance_valid(golden_anklet):golden_anklet.pulse()

func face_velocity(velocity: Vector3) -> void:
	var camera:=get_viewport().get_camera_3d()
	var horizontal: float=velocity.dot(camera.global_basis.x) if camera else velocity.x
	if absf(horizontal)>0.18:scale.x=absf(original_scale.x)*(-1.0 if horizontal>0.0 else 1.0)

func set_locomotion(velocity: Vector3) -> void:
	movement_velocity=Vector3(velocity.x,0,velocity.z)
	movement_speed=movement_velocity.length()
	var current: String=action_player.current
	if phase==1:
		# Complete each hop through landing; zero ground speed during its
		# anticipation and landing must not release the airborne silhouette.
		return
	if movement_speed<0.04:
		gait_blend_pose.clear()
		if current in ["walk","run","cub_stalk"]:action_player.release_to_idle(skeleton)
		return
	# Locked attack and reveal clips retain priority over locomotion.
	if not current.is_empty() and current not in ["walk","run","cub_stalk"]:return
	face_velocity(movement_velocity)
	var gait: String="run" if movement_speed>1.85 else "walk"
	if phase==3:gait="run" if movement_speed>(1.00 if current=="run" else 1.15) else "walk"
	if current!=gait:
		if phase==3:begin_gait_blend(gait,current in ["walk","run"])
		else:play_action(gait)
	var reference: float=action_player.library[gait]["reference_speed"]
	var rate:=clampf(movement_speed/reference,0.45,1.75)
	if phase==3:gait_rate_target=rate
	else:action_player.speed=rate

func begin_gait_blend(gait: String,keep_phase: bool) -> void:
	var fraction: float=action_player.elapsed/maxf(action_player.duration,.01) if keep_phase else 0.0
	var before: Dictionary={}
	for bone_name in action_player.library[gait]["bones"]:
		var index:=skeleton.find_bone(bone_name)
		before[index]=[skeleton.get_bone_pose_position(index),skeleton.get_bone_pose_rotation(index),skeleton.get_bone_pose_scale(index)]
	play_action(gait)
	action_player.elapsed=fraction*action_player.duration
	action_player.blend_age=1.0
	action_player.advance(0.0,skeleton)
	gait_blend_pose=before;gait_blend_age=0.0
	apply_gait_blend(0.0)

func apply_gait_blend(delta: float) -> void:
	if gait_blend_pose.is_empty():return
	gait_blend_age+=delta
	var weight:=smoothstep(0.0,1.0,clampf(gait_blend_age/.18,0.0,1.0))
	for index in gait_blend_pose:
		var before: Array=gait_blend_pose[index]
		skeleton.set_bone_pose_position(index,before[0].lerp(skeleton.get_bone_pose_position(index),weight))
		skeleton.set_bone_pose_rotation(index,before[1].slerp(skeleton.get_bone_pose_rotation(index),weight))
		skeleton.set_bone_pose_scale(index,before[2].lerp(skeleton.get_bone_pose_scale(index),weight))
	if weight>=1.0:gait_blend_pose.clear()

func reset_locomotion() -> void:
	clear_weapon_hit()
	strike_pause=0.0
	movement_velocity=Vector3.ZERO
	movement_speed=0.0
	scale=original_scale
	stop_action()
