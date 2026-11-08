extends SceneTree
var failed:=false
var checks:=0
var arena
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func frames(n: int) -> void:
	for i in n:await process_frame
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed;await frames(3)
	arena=current_scene;var e=arena.encounter;var a=arena.attacks;var burn=arena.player_burn
	e.start_encounter();e.set_process(false);a.set_process(false);burn.set_process(false);arena.set_physics_process(false)
	var motion=arena.get_node("EnvironmentMotion")
	var original: Vector3=motion.mist_nodes[0].size
	check(motion.ground_mist.size==Vector3(62,.46,62),"P1 retains its original low ground mist")
	arena.set_phase(3)
	check(motion.ground_mist.size.x==77.5 and motion.ground_mist.size.y>.46,"P3 base mist footprint and thickness are larger")
	check(is_equal_approx(motion.mist_nodes[0].size.x/original.x,1.4),"Each P3 drifting mist bank is forty percent wider")
	check(motion.mist_nodes[0].size.y/original.y>1.19 and motion.mist_bases[0].y<.55,"Enlarged mist remains close to the ground")
	var large: Vector3=motion.mist_nodes[0].size
	arena.set_phase(2);check(motion.mist_nodes[0].size==original,"P2 mist remains unchanged")
	arena.set_phase(3);check(motion.mist_nodes[0].size==large,"Repeated phase changes do not accumulate mist scale")
	a.begin_attack("vision_charm");var seal=a.attack_seal;seal.charge=.8;seal.advance(.2)
	check(seal.shadow.get_index()<seal.glow.get_index() and seal.glow.get_index()<seal.stamp.get_index(),"Glyph has a distinct shadow and light layer behind the original art")
	check(seal.glow.size.x==184 and seal.shadow.size.x==172,"Glyph light plate has the larger requested soft footprint")
	check(is_equal_approx(seal.shadow.position.x+seal.shadow.size.x*.5,seal.cue_center.x),"Light and shadow stay centered on the same head glyph")
	check(seal.shadow.mouse_filter==Control.MOUSE_FILTER_IGNORE,"New backplate cannot intercept player input")
	arena.set_phase(2);arena.player.position=Vector3(0,0,6.5)
	a.begin_attack("inferno_rain")
	check(a.mode=="windup" and is_equal_approx(a.windup,1.65),"Inferno has a real body and head-glyph anticipation")
	check(a.telegraph==null and a.attack_seal.attack_name=="inferno_rain","New skill has no floor warning or range disc")
	a._process(1.66);var rain=a.inferno;rain.set_process(false)
	for patch in rain.patches:patch.set_process(false)
	check(a.mode=="inferno_channel" and rain.waves_fired==1,"Actual release starts the first descending inferno wave")
	check(rain.patches.size()==26,"Scaled opening wave covers the map with 24 grid flames and two pressure drops")
	var covered:=0;var samples:=0
	for x in range(-18,19,2):
		for z in range(-18,19,2):
			samples+=1
			for patch in rain.patches:
				if patch.contains(Vector3(x,0,z)):covered+=1;break
	check(float(covered)/samples>.55 and float(covered)/samples<.98,"Scaled attack retains broad coverage with real spatial gaps")
	var corridor_clear:=true
	for patch in rain.patches:
		if patch.contains(Vector3(rain.corridor_x,0,15)):corridor_clear=false
	check(corridor_clear,"An open movement lane survives the base barrage")
	var patch=rain.patches[0]
	check(not patch.ground.visible and not patch.landed,"Residual ground fire is absent before landing")
	patch._process(.5)
	check(patch.fire.visible and patch.fire.global_position.y>4.0 and not patch.ground.visible,"Flame is actually descending through space")
	arena.player.position=patch.position;e.player_hit_grace=0
	var health: float=e.player_health;patch._process(.6)
	check(patch.landed and patch.ground.visible,"Landing creates visible persistent scorch")
	check(e.player_health==health-14.0,"Actual impact contact deals damage once")
	check(burn.remaining>float(e.phase_config["inferno_burn_seconds"])-.01 and burn.visible,"Stepping on the residue attaches a visible burn status")
	check(burn.surfaces[0].global_position.distance_to(arena.player.global_position)<1.0,"First burn frame is already attached to the player instead of flashing at the scene origin")
	arena.player.position=Vector3(22,0,22)
	health=e.player_health;var reactions: int=arena.player_avatar.action_events
	burn._process(1.01)
	check(e.player_health==health-float(e.phase_config["inferno_burn_damage_per_second"]) and burn.remaining>0,"Burn persists and ticks after leaving the terrain")
	check(arena.player_avatar.action_events==reactions,"Damage over time does not restart hit stun or cancel rare attack windows")
	check(e.player_hit_grace>.8,"Burn ticks do not consume or extend direct-hit invulnerability")
	for refresh in 20:burn.apply(4.0)
	health=e.player_health;burn._process(1.0)
	check(e.player_health==health-float(e.phase_config["inferno_burn_damage_per_second"]) and burn.remaining<=4.0,"Overlapping fire refreshes duration without stacking or resetting the tick clock")
	burn._process(4.1)
	check(burn.remaining==0 and not burn.visible,"Detached burn expires and clears its body effect")
	health=e.player_health;burn._process(2.0)
	check(e.player_health==health,"Expired burn cannot cause later invisible damage")
	arena.dash_remaining=.2
	check(not burn.apply(4.0),"Dash prevents new burn attachment")
	arena.dash_remaining=0
	patch._process(5.0)
	check(patch.finished and patch.is_queued_for_deletion(),"Residual scorch fades and retires after its configured lifetime")
	rain._process(5.0)
	for effect in rain.patches:effect.set_process(false)
	check(rain.waves_fired==4 and rain.spawn_log.size()==102,"Actual channel emits four waves totaling 102 drops at 0.8 density")
	check(rain.patches.size()<=128,"Live inferno nodes obey a finite effect budget")
	for step in 18:
		rain._process(.75)
		for effect in rain.patches:
			if is_instance_valid(effect) and not effect.finished:effect._process(.75)
	check(rain.finished,"Channel waits until the last residue has disappeared")
	a._process(.01)
	check(a.mode=="recover" and a.inferno==null,"A real close-range recovery opportunity follows the inferno")
	a.reset();arena.player.position=Vector3(0,0,8)
	for normal in ["p2_claw_gale","barrage_fan","p2_tail_crescent"]:
		a.begin_attack(normal);a._process(2.0)
	check(a.p2_casts_since_inferno==3,"P2 counts resolved attacks toward the new special")
	a.vanish_casts=0;a.mode="idle";a.cooldown=0.0;a._process(.01)
	check(a.attack=="inferno_rain","Normal P2 AI actually schedules the inferno")
	burn.apply(4.0);arena.set_phase(3);await frames(3)
	check(burn.remaining==0 and not burn.visible and a.inferno==null,"Phase transition removes burning and all inferno state")
	check(not burn.apply(4.0),"P3 cannot accidentally receive the P2-only burn status")
	arena.set_phase(2);burn.apply(4.0);e.stop_to_preview();await frames(3)
	check(burn.remaining==0 and not burn.visible,"Returning to preview clears all status effects")
	e.start_encounter();arena.set_phase(2);e.player_health=2.0;burn.apply(4.0);burn._process(1.0);await frames(3)
	check(e.state==e.State.DEFEAT and burn.remaining==0,"Lethal burn follows the normal defeat and cleanup route")
	e.start_encounter()
	check(e.player_health==e.player_max_health and burn.remaining==0 and a.p2_casts_since_inferno==0,"Restart restores health and clears new scheduling state")
	print("INFERNO_ATMOSPHERE %d checks; passed=%s"%[checks,not failed])
	arena.queue_free();current_scene=null;await frames(4);quit(int(failed))
