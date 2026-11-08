extends SceneTree
var arena
var failed:=false
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func launch():
	var a=arena.attacks;a.reset();arena.player.position=Vector3(0,0,8);arena.dash_remaining=0
	a.begin_attack("cub_charm");a._process(1.26)
	var heart=a.projectiles[0];heart.set_process(false);return heart
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;var e=arena.encounter;var a=arena.attacks
	e.start_encounter();e.set_process(false);a.set_process(false);arena.set_physics_process(false);arena.presentation.set_process(false)
	var rig=a.rig();rig.set_process(false)
	arena.player.position=Vector3(0,0,5);a.begin_attack("cub_charm");a._process(1.24)
	check(a.projectiles.is_empty() and a.vision_remaining==0,"P1 cannot fire or charm before its 1.25-second anticipation")
	check(rig.action_player.current=="cub_charm_windup" and is_instance_valid(a.attack_seal),"Existing body anticipation and head glyph remain")
	check(not is_instance_valid(a.telegraph),"P1 charm no longer uses a hidden or visible sector for damage")
	a._process(.02)
	check(a.projectiles.size()==1 and a.vision_remaining==0,"Release creates exactly one heart without instant charm")
	var heart=a.projectiles[0];heart.set_process(false)
	check(heart.homing and heart.source_phase==1 and not heart.with_beacon,"The P1 heart uses homing with the juvenile effect profile")
	check(heart.material.shader.resource_path.ends_with("charm_heart_projectile.gdshader") and heart.aura_material.shader.resource_path.ends_with("charm_heart_aura.gdshader"),"Existing heart core and independent shader aura are reused")
	check(is_equal_approx(heart.surface.global_basis.x.length(),.75) and heart.surface.position.y>1.3,"Heart has the correct small scale and launch height from its first frame")
	var before: Vector3=heart.position;heart._process(.2)
	check(heart.position.distance_to(before)>.6 and not heart.resolved,"The launched heart really moves toward the player")
	arena.player.position=Vector3(8,0,4);heart._process(.4)
	check(heart.direction.x>.5,"Moving the target right bends the existing heart right")
	arena.player.position=Vector3(-8,0,4);heart._process(.4)
	check(heart.direction.x<-.5,"The same heart can reverse course when the player changes sides")
	check(a.vision_remaining==0 and e.player_health==e.player_max_health,"Merely being tracked does not charm or damage the player")
	# The latest rule replaces the old endless homing lifetime.
	heart=launch()
	for frame in 140:
		var angle:=float(frame)/60.0*.28
		arena.player.position=Vector3(cos(angle)*15,0,sin(angle)*15)
		heart._process(1.0/60.0)
	check(not heart.resolved and heart.elapsed<2.5,"P1 heart remains active before the 2.5-second limit")
	check(heart.material.get_shader_parameter("fade")<1.0,"Expiring heart visibly fades near its lifetime limit")
	check(a.has_cub_charm_heart(),"The director recognizes the live tracking heart")
	a.emit_cub_charm_heart()
	check(a.projectiles.size()==1,"Repeated release cannot stack additional persistent hearts")
	arena.player.position=Vector3(0,0,2);a.sequence=1;a.cooldown=0;a.mode="idle";a.cub_hop_active=false;a._process(.01)
	check(a.attack!="cub_charm" and a.mode=="windup","Fox continues its animal attacks while one heart is pursuing")
	heart=launch();arena.player.position=heart.position+heart.direction*1.0
	heart._process(.5)
	check(heart.resolved and heart.is_queued_for_deletion() and a.charm_hits>0,"Swept contact consumes the heart and applies charm exactly on hit")
	check(is_zero_approx(a.vision_remaining) and not a.vision_rect.visible,"P1 contact does not create pink fog or vision obstruction")
	check(e.player_health==e.player_max_health and is_equal_approx(arena.charm_remaining,1.2) and not is_instance_valid(a.beacon),"P1 contact compels approach without HP damage or the P3 cleansing pickup")
	var hits: int=a.charm_hits;heart._process(.1)
	check(a.charm_hits==hits,"Resolved heart cannot charm more than once")
	a.update_vision(1.3)
	check(a.vision_remaining==0,"Juvenile charm still expires automatically")
	heart=launch();arena.player.position=heart.position+heart.direction*.8;arena.dash_remaining=.2;heart._process(.4)
	check(heart.resolved and a.vision_remaining==0,"Dashing through actual contact consumes the heart without charm")
	arena.dash_remaining=0;heart=launch();a.finish_attack(.45)
	check(not heart.resolved and a.has_cub_charm_heart(),"Finishing the casting animation does not delete the pursuing heart")
	arena.set_phase(2);await process_frame
	check(not is_instance_valid(heart) and a.projectiles.is_empty(),"Phase change removes the pursuing P1 heart")
	e.start_encounter();a.set_process(false);heart=launch();e.stop_to_preview();await process_frame
	check(not is_instance_valid(heart) and a.projectiles.is_empty(),"Returning to preview cleans the tracking heart")
	e.start_encounter();a.set_process(false);heart=launch();e.start_encounter();await process_frame
	check(not is_instance_valid(heart) and a.projectiles.is_empty(),"Restart cannot retain a stale homing target")
	e.start_encounter();a.set_process(false);arena.set_phase(3);a.begin_attack("vision_charm");a._process(1.41)
	var p3_ok: bool=a.projectiles.size()==4
	for p3_heart in a.projectiles:p3_ok=p3_ok and not p3_heart.homing and p3_heart.source_phase==3 and p3_heart.with_beacon and is_equal_approx(p3_heart.lifetime,2.5)
	check(p3_ok,"P3 retains four straight-flying hearts and its own lifetime and cleansing profile")
	print("P1_HOMING_HEART ",checks," checks; passed=",not failed)
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	quit(int(failed))
