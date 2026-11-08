extends RefCounted
## Additive anticipation across each existing eight-bone tail. Runtime only;
## authored action timelines, tail meshes and registered head/eye transforms stay intact.
var active:=false
var age:=0.0
var release_age:=-1.0
var duration:=1.0
var phase:=1
var kind:=""
var triggers:=0
var offsets: Dictionary={}
func clear(skeleton: Skeleton3D) -> void:
	for index in offsets:
		skeleton.set_bone_pose_rotation(index,skeleton.get_bone_pose_rotation(index)*offsets[index].inverse())
	offsets.clear()
func stop(skeleton: Skeleton3D) -> void:
	clear(skeleton);active=false;age=0.0;release_age=-1.0
func begin(skeleton: Skeleton3D,seconds: float,form: int,attack: String) -> void:
	stop(skeleton);duration=maxf(seconds,.1);phase=form;kind=attack;active=true;triggers+=1
func release() -> void:
	if active:release_age=0.0
func advance(delta: float,skeleton: Skeleton3D,bones: Array[int]) -> void:
	if not active:return
	age+=delta
	if release_age>=0:
		release_age+=delta
		if release_age>=.42:active=false;return
	var envelope:=smoothstep(0.0,.14,age)
	if release_age>=0:envelope*=1.0-smoothstep(0.0,.42,release_age)
	var strength: float=[10.0,6.5,4.2][phase-1]
	if kind=="cub_tail_sweep":strength*=.70
	if kind=="p3_spiral":strength*=1.2
	for index in bones:
		var parts:=skeleton.get_bone_name(index).split("_")
		var number:=int(parts[1]);var segment:=int(parts[2])
		var local:=maxf(0,age-(number-1)*.025-segment*.022)
		var wave:=sin(local*TAU*1.35-segment*.42+(number-1)*.32)
		var coil:=sin(minf(age/duration,1.0)*PI*.65)*.28
		var degrees: float=(strength if segment==0 else strength*.18)*envelope*(wave*.8+coil)
		var offset:=Quaternion(Vector3.BACK,deg_to_rad(degrees))
		skeleton.set_bone_pose_rotation(index,skeleton.get_bone_pose_rotation(index)*offset)
		offsets[index]=offset
