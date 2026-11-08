extends RefCounted
## Same sampled offset timelines are exported as Spine 4.2 animations.
signal audio_marker(event: String, clip: String, seconds: float)
var audio_markers: Dictionary = {}
var library: Dictionary
var current := ""
var elapsed := 0.0
var duration := 1.0
var looping := false
var speed := 1.0
var blend_age := 0.0
var last_bones: Array = []
var release_pose: Dictionary = {}
var release_elapsed := 0.0
func _init(phase: int) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Qingqiu/fox_action_library.json"))
	library=data["phases"][str(phase)]
	var audio: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Qingqiu/combat_audio.json"))
	audio_markers=audio["animation_markers"].get(str(phase),{})
func play(name: String,rate := 1.0) -> bool:
	if not library.has(name):return false
	current=name
	elapsed=0.0
	blend_age=0.0
	speed=rate
	duration=float(library[name]["duration"])
	looping=bool(library[name]["loop"])
	for marker in audio_markers.get(name,[]):
		if float(marker["seconds"])==0.0:audio_marker.emit(marker["event"],name,0.0)
	return true

func advance_audio(before: float,after: float) -> void:
	for marker in audio_markers.get(current,[]):
		var local_time:=float(marker["seconds"])
		var first_loop:=maxi(0,int(floor((before-local_time)/duration))+1) if looping else 0
		var end_loop:=maxi(0,int(floor((after-local_time)/duration))) if looping else 0
		for cycle in range(first_loop,end_loop+1):
			var crossing:=local_time+float(cycle)*duration
			if crossing>before and crossing<=after:audio_marker.emit(marker["event"],current,local_time)
func reset(skeleton: Skeleton3D) -> void:
	var names: Array=last_bones.duplicate()
	for bone_name in release_pose:
		if not names.has(bone_name):names.append(bone_name)
	for bone_name in names:
		var index:=skeleton.find_bone(bone_name)
		if index<0:continue
		var rest:=skeleton.get_bone_rest(index)
		skeleton.set_bone_pose_position(index,rest.origin)
		skeleton.set_bone_pose_rotation(index,rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index,Vector3.ONE)
	last_bones.clear()
	release_pose.clear()
	current=""

func release_to_idle(skeleton: Skeleton3D) -> void:
	var poses: Dictionary={}
	for name in last_bones:
		var index:=skeleton.find_bone(name)
		if index<0:continue
		poses[name]=[skeleton.get_bone_pose_position(index),skeleton.get_bone_pose_rotation(index),skeleton.get_bone_pose_scale(index)]
	reset(skeleton)
	release_pose=poses
	release_elapsed=0.0
func sample(keys: Array,time: float,kind: String) -> Vector3:
	var a: Dictionary=keys[0]
	var b: Dictionary=keys[-1]
	for key in keys:
		if float(key["time"])<=time:a=key
		if float(key["time"])>=time:
			b=key
			break
	var weight:=clampf((time-float(a["time"]))/maxf(float(b["time"])-float(a["time"]),0.0001),0.0,1.0)
	weight=weight*weight*(3.0-2.0*weight)
	if kind=="rotate":return Vector3(0,0,lerpf(float(a["value"]),float(b["value"]),weight))
	return Vector3(lerpf(float(a.get("x",1 if kind=="scale" else 0)),float(b.get("x",1 if kind=="scale" else 0)),weight),
		lerpf(float(a.get("y",1 if kind=="scale" else 0)),float(b.get("y",1 if kind=="scale" else 0)),weight),0)
func advance(delta: float,skeleton: Skeleton3D) -> void:
	if current.is_empty():
		if not release_pose.is_empty():
			release_elapsed+=delta
			var blend:=smoothstep(0.0,1.0,clampf(release_elapsed/0.12,0.0,1.0))
			for name in release_pose:
				var index:=skeleton.find_bone(name)
				var rest:=skeleton.get_bone_rest(index)
				var pose: Array=release_pose[name]
				skeleton.set_bone_pose_position(index,pose[0].lerp(rest.origin,blend))
				skeleton.set_bone_pose_rotation(index,pose[1].slerp(rest.basis.get_rotation_quaternion(),blend))
				skeleton.set_bone_pose_scale(index,pose[2].lerp(Vector3.ONE,blend))
			if blend>=1.0:release_pose.clear()
		return
	var before:=elapsed
	elapsed+=delta*speed
	advance_audio(before,elapsed if looping else minf(elapsed,duration))
	blend_age+=delta
	if elapsed>duration:
		if looping:elapsed=fmod(elapsed,duration)
		elif bool(library[current].get("hold_last",false)):elapsed=duration
		else:
			reset(skeleton)
			return
	var timelines: Dictionary=library[current]["bones"]
	var blend:=smoothstep(0.0,1.0,clampf(blend_age/maxf(float(library[current].get("blend_in",0.001)),0.001),0.0,1.0))
	last_bones=timelines.keys()
	for bone_name in timelines:
		var index:=skeleton.find_bone(bone_name)
		if index<0:continue
		var rest:=skeleton.get_bone_rest(index)
		var channels: Dictionary=timelines[bone_name]
		if channels.has("rotate"):
			var value:=sample(channels["rotate"],elapsed,"rotate")
			skeleton.set_bone_pose_rotation(index,rest.basis.get_rotation_quaternion()*Quaternion(Vector3.BACK,deg_to_rad(value.z)*blend))
		if channels.has("translate"):
			var value:=sample(channels["translate"],elapsed,"translate")
			skeleton.set_bone_pose_position(index,rest.origin+Vector3(value.x,value.y,0)/80.0*blend)
		if channels.has("scale"):
			var value:=sample(channels["scale"],elapsed,"scale")
			skeleton.set_bone_pose_scale(index,Vector3.ONE.lerp(Vector3(value.x,value.y,1),blend))
