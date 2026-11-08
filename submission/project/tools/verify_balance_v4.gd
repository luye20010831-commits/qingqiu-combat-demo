extends SceneTree
var arena
var failed:=false
var checks:=0
var evidence:="res://artifacts/qingqiu/balance_v4"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func fresh(phase: int) -> void:
	arena.encounter.start_encounter(phase)
	arena.encounter.set_process(false);arena.attacks.set_process(false)
	arena.spirit_combat.set_process(false);arena.player_avatar.set_process(false)
	arena.set_physics_process(false);arena.presentation.set_process(false)
	arena.player_burn.set_process(false)
	arena.player.position=Vector3(0,0,2)
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():evidence=args[0]
	DirAccess.make_dir_recursive_absolute(evidence)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;await process_frame;await physics_frame;fresh(1)
	var e=arena.encounter;var a=arena.attacks;var s=arena.spirit_combat
	check(e.health_for_phase(1)==1850 and e.health_for_phase(2)==2000 and e.health_for_phase(3)==2000,"Current stage HP budgets are 1850 / 2000 / 2000")
	check(e.player_health==120 and e.player_max_health==120,"Actual start uses the new 120 HP player pool")
	check(e.balance["phases"][0]["target_seconds"]==120 and e.balance["phases"][1]["target_seconds"]==180 and e.balance["phases"][2]["target_seconds"]==180,"Two / three / three minute targets are retained")
	e.player_health=50;e.state=e.State.TRANSITION;arena.set_phase(2)
	check(e.player_health==75,"Clearing a phase restores 25 HP without forced full healing")
	e.player_health=119;arena.set_phase(3)
	check(e.player_health==120,"Phase recovery caps at the real maximum health")
	fresh(1)
	check(e.phase_config["swipe_damage"]==12 and e.phase_config["charge_damage"]==20 and e.phase_config["tail_sweep_damage"]==14,"P1's requested doubled animal attacks retain their damage")
	check(e.phase_config["cub_charm_every_attacks"]==2 and e.phase_config["cub_charm_seconds"]==1.2,"P1's frequent short tracking-heart challenge is retained")
	check(s.skills[0]["damage"]==10 and s.skills[0]["cooldown"]==.4,"Basic attack damage and timing remain stable")
	check(s.skills[1]["damage"]==24 and s.skills[3]["damage"]==42,"Committed sweep and heavy receive real damage rewards")
	check(s.use_skill(2),"Ward still starts through the real player skill API")
	check(is_equal_approx(s.cooldowns[2],7.0),"Accepted ward now spends a seven-second cooldown")
	s.update_melee(.321)
	check(s.ward_remaining==3.0 and s.absorb_damage(20)==10,"Ward keeps its real activation and 50 percent mitigation")
	fresh(2)
	await screenshot("p2_start_120hp")
	check(e.phase_config["barrage_waves"]==3 and e.phase_config["inferno_waves"]==4,"P2 keeps its three-wave bullets and four-wave dense inferno")
	check(e.phase_config["projectile_damage"]==10 and e.phase_config["inferno_impact_damage"]==14,"P2 retains direct-hit threat instead of removing the attack challenge")
	check(float(e.phase_config["roam_speed"])==2.0,"P2 roaming is slower than the player's 4.2 m/s approach")
	a.begin_vanish();a._process(float(e.phase_config["vanish_fade_seconds"])*2+float(e.phase_config["vanish_hidden_seconds"])+.001)
	check(a.mode=="recover" and a.boss_targetable() and is_equal_approx(a.cooldown,1.4),"Reappearance provides a real targetable 1.4-second stationary recovery")
	var boss_before: Vector3=arena.boss_position();var hp: float=e.boss_health
	s.use_skill(3)
	for frame in 70:
		s._process(1.0/60.0);arena.player_avatar._process(1.0/60.0);a._process(1.0/60.0)
	check(e.boss_health==hp-42,"A properly timed heavy really lands during the reappearance window")
	check(arena.boss_position().is_equal_approx(boss_before) and a.mode=="recover","Fox does not flee while the advertised reappearance recovery is active")
	await screenshot("p2_reappearance_counter")
	fresh(2);a.begin_attack("inferno_rain");a._process(1.66)
	var rain=a.inferno;rain.set_process(false)
	for patch in rain.patches:patch.set_process(false)
	check(rain.patches.size()==26,"P2 inferno starts with its current 0.8-count opening wave")
	var patch=rain.patches[0];arena.player.position=patch.position
	patch._process(patch.delay+patch.falling_seconds+.001)
	check(e.player_health==106 and arena.player_burn.remaining==3.0,"Real inferno impact costs 14 HP and attaches only three seconds of burn")
	arena.player.position=Vector3(22,0,22)
	arena.player_burn._process(3.01)
	check(e.player_health==100 and arena.player_burn.remaining==0,"Leaving one impact allows its three burn ticks to end at a total cost of 20 HP")
	check(is_equal_approx(patch.residual_seconds,2.8),"Terrain residue retires after the shorter 2.8-second linger")
	rain.finished=true;a._process(.01)
	check(a.mode=="recover" and is_equal_approx(a.cooldown,2.4),"Cleared inferno grants 2.4 seconds of stationary melee recovery")
	arena.player.position=Vector3(0,0,2);s.clear_transients();arena.player_avatar.reset_avatar();hp=e.boss_health;boss_before=arena.boss_position()
	for frame in 132:
		s._process(1.0/60.0);arena.player_avatar._process(1.0/60.0);a._process(1.0/60.0)
		if s.active_skill.is_empty():s.use_skill(3 if s.cooldowns[3]<=0 else 0)
	check(e.boss_health<=hp-62,"Inferno punishment window permits a heavy plus follow-up hits at melee range")
	check(arena.boss_position().is_equal_approx(boss_before) and a.mode=="recover","Inferno recovery remains stationary rather than turning into immediate escape")
	fresh(3)
	await screenshot("p3_start_120hp")
	check(e.phase_config["hazard_count"]==9 and e.phase_config["fire_beats"]==3 and e.phase_config["hazard_radius"]==1.725,"P3 retains all 27 pillars and the requested 1.5x attack radius")
	check(e.phase_config["spiral_rounds"]==8 and e.phase_config["spiral_bullets"]-e.phase_config["spiral_gap_sectors"]==16,"P3 retains eight clockwise rounds and 128 bullets")
	e.spawn_wave();var count: int=e.hazards_spawned
	e.update_fire_beats(.89)
	check(e.hazards_spawned==count,"Second pillar beat waits beyond the old overlapping 0.72-second interval")
	e.update_fire_beats(.02)
	check(e.hazards_spawned==count+9 and float(e.phase_config["fire_beat_interval"])>float(e.phase_config["active_seconds"]),"Pillar beats are spaced at 0.9 seconds with a brief temporal gap")
	a.apply_vision_charm(float(e.phase_config["charm_seconds"]));a.update_vision(4.99)
	check(a.vision_remaining>0 and a.vision_remaining<.02,"P3 vision obstruction lasts five seconds if the light is ignored")
	a.update_vision(.3)
	check(a.vision_remaining==0 and not a.vision_rect.visible,"P3 veil clears by itself after the shorter duration")
	a.reset();a.attack="p3_spiral";a.mode="spiral_active";a.spiral_round=8;a.age=5.89;a._process(.02)
	check(a.mode=="recover" and is_equal_approx(a.cooldown,2.0),"Surviving the eight-round barrage grants two seconds of recovery")
	print("BALANCE_V4 ",checks," checks; passed=",not failed)
	var f:=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":not failed,"audio_driver":"Dummy","controlled_contact_checks":true,"human_full_playthrough":false},"\t"));f.close()
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	await create_timer(.08).timeout
	quit(int(failed))
