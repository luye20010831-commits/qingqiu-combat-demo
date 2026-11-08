extends SceneTree
var failed:=false
func _initialize() -> void:run.call_deferred()
func frames(count: int) -> void:
	for frame in count:await process_frame
func check(value: bool,label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	failed=failed or not value
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await frames(5)
	var arena=current_scene
	var a=arena.attacks
	var e=arena.encounter
	e.start_encounter()
	for phase in [1,2,3]:
		arena.set_phase(phase)
		a.cooldown=999.0
		a.set_process(true)
		var actor: Node3D=arena.forms.get_child(phase-1)
		var puppet=actor.get_node("FoxRig")
		var skeleton: Skeleton3D=puppet.skeleton
		var start:=actor.position
		await frames(35)
		check(actor.position.distance_to(start)>0.2,"P%d actually changes ground position between attacks"%phase)
		if phase==1:
			check(puppet.action_player.current=="cub_hop","P1 moves with a complete hop instead of a stepping cycle")
			check(not puppet.action_player.library.has("walk") and not puppet.action_player.library.has("run") and not puppet.action_player.library.has("cub_stalk"),"P1 no longer contains walk, run or stalk clips")
		else:check(puppet.action_player.current in ["walk","run"] and puppet.movement_speed>0.1,"P%d plays a locomotion cycle from actual movement speed"%phase)
		var limb_count:=0
		for leg in ["front_far","front_near","hind_far","hind_near"]:
			for part in ["upper","lower","paw"]:
				if puppet.has_node("p%d_%s_%s"%[phase,leg,part]):limb_count+=1
		check(limb_count==12,"P%d keeps all twelve independently bound leg and paw cutouts"%phase)
		a.set_process(false)
		if phase==1:
			puppet.play_action("cub_hop")
			puppet.action_player.advance(0.33,skeleton)
			var root_bone:=skeleton.find_bone("root")
			check(skeleton.get_bone_pose_position(root_bone).y>0.4,"P1 raises the entire registered silhouette during its hop")
			var intact:=true
			for leg in ["front_far","front_near","hind_far","hind_near"]:
				for part in ["upper","lower","paw"]:
					var bone:=skeleton.find_bone(leg+"_"+part)
					intact=intact and skeleton.get_bone_pose_rotation(bone).is_equal_approx(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
			check(intact,"P1 hop keeps all leg joints at their registered rest pose")
			puppet.set_locomotion(Vector3.ZERO)
			check(puppet.action_player.current=="cub_hop","Zero horizontal speed does not cancel an airborne P1 hop")
			puppet.action_player.advance(0.5,skeleton)
			check(puppet.action_player.current.is_empty() and skeleton.get_bone_pose_position(root_bone).is_equal_approx(skeleton.get_bone_rest(root_bone).origin),"P1 lands and restores the whole silhouette")
		for gait in ([] if phase==1 else ["walk","run"]):
			puppet.play_action(gait)
			puppet.action_player.advance(0.20,skeleton)
			var changing:=0
			for leg in ["front_far","front_near","hind_far","hind_near"]:
				var index:=skeleton.find_bone(leg+"_lower")
				if skeleton.get_bone_pose_rotation(index).angle_to(skeleton.get_bone_rest(index).basis.get_rotation_quaternion())>0.02:changing+=1
			check(changing==4,"P%d %s articulates four independent knee chains"%[phase,gait])
			skeleton.force_update_all_bone_transforms()
			var level:=true
			for leg in ["front_far","front_near","hind_far","hind_near"]:
				var paw:=skeleton.find_bone(leg+"_paw")
				var x:=skeleton.get_bone_global_pose(paw).basis.x.normalized()
				level=level and absf(x.y)<0.025
			check(level,"P%d %s keeps the separated paws level during stepping"%[phase,gait])
		puppet.set_locomotion(Vector3.ZERO)
		check(puppet.action_player.current.is_empty() and puppet.movement_speed==0.0,"P%d stops its leg cycle when ground movement stops"%phase)
		if phase!=1:
			puppet.set_locomotion(Vector3(0.8,0,0))
			check(puppet.scale.x<0.0 and puppet.action_player.current=="walk","P%d faces and walks toward screen right"%phase)
			puppet.set_locomotion(Vector3(-2.4,0,0))
			check(puppet.scale.x>0.0 and puppet.action_player.current=="run","P%d faces and runs toward screen left"%phase)
		var cast: String=["cub_swipe","barrage_cast","charm_cast"][phase-1]
		puppet.play_action(cast)
		puppet.set_locomotion(Vector3(2,0,0))
		check(puppet.action_player.current==cast,"P%d attack animation takes priority over locomotion"%phase)
		a.begin_attack(["cub_swipe","barrage_fan","vision_charm"][phase-1])
		start=actor.position
		a._process(0.10)
		check(actor.position.is_equal_approx(start),"P%d holds its position during locked attack windup"%phase)
		a.reset()
		check(puppet.scale.x>0 and puppet.movement_speed==0,"P%d restart restores its facing and clears movement"%phase)
	# A real body in the path blocks the ground probe; the fox cannot walk
	# through it even though its presentation root is a Node3D.
	arena.set_phase(2)
	var obstacle:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(2,2,2)
	collision.shape=box
	obstacle.add_child(collision)
	arena.add_child(obstacle)
	obstacle.position=Vector3(2,0.8,0)
	await physics_frame
	await physics_frame
	check(not a.ground_clear(Vector3(2,0,0)),"Real scenery collision blocks the ground movement probe")
	a.move_ground(Vector3(2,0,0))
	check(arena.boss_position().distance_to(Vector3(2,0,0))>1.0,"Blocked movement cannot place the fox inside a solid prop")
	obstacle.queue_free()
	e.start_encounter()
	await frames(2)
	check(arena.phase==1 and not arena.ghost_fire.visible,"Restart retains single-tail P1 and its no-ghost-fire rule")
	quit(int(failed))
