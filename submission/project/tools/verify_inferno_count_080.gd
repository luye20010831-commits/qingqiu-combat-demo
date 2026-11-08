extends SceneTree
var arena
var checks:=0
var failed:=false
var evidence:="res://artifacts/qingqiu/inferno_count_080"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func make_rain():
	var a=arena.attacks;a.reset();arena.player.position=Vector3(0,0,6.5)
	a.begin_attack("inferno_rain");a._process(1.66)
	var rain=a.inferno;rain.set_process(false)
	for patch in rain.patches:patch.set_process(false)
	return rain
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():evidence=args[0]
	DirAccess.make_dir_recursive_absolute(evidence)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;var e=arena.encounter;var a=arena.attacks
	e.start_encounter(2);e.set_process(false);a.set_process(false);arena.set_physics_process(false)
	check(is_equal_approx(float(e.phase_config["inferno_count_multiplier"]),.8),"Current P2 uses the explicit 0.8 count multiplier")
	var rain=make_rain();var interval: float=e.phase_config["inferno_wave_interval"]
	var counts: Array[int]=[]
	for wave in 4:
		if wave>0:rain._process(interval)
		for patch in rain.patches:patch.set_process(false)
		var count:=0;var aimed:=0;var near_boss:=0;var lane_clear:=true
		var min_x:=INF;var max_x:=-INF;var min_z:=INF;var max_z:=-INF
		for drop in rain.spawn_log:
			if drop["wave"]!=wave:continue
			count+=1;aimed+=int(drop["aimed"])
			var point: Vector3=drop["point"]
			if point.is_equal_approx(arena.boss_position()):near_boss+=1
			min_x=minf(min_x,point.x);max_x=maxf(max_x,point.x);min_z=minf(min_z,point.z);max_z=maxf(max_z,point.z)
			if point.distance_to(Vector3(rain.corridor_x,0,15))<=float(drop["radius"]):lane_clear=false
		counts.append(count)
		check(count==[26,25,26,25][wave],"Wave %d has the correctly rounded drop count"%(wave+1))
		check(aimed==1 and near_boss==1,"Wave %d retains one player-targeted and one boss-side drop"%(wave+1))
		check(min_x<-15 and max_x>15 and min_z<-15 and max_z>15,"Wave %d still distributes fire across the map"%(wave+1))
		check(lane_clear,"Wave %d preserves the existing far movement lane"%(wave+1))
	check(rain.waves_fired==4 and rain.spawn_log.size()==102,"Four actual waves total 102 drops instead of 128")
	var patch=rain.patches[0]
	check(patch.damage==14 and patch.residual_seconds==2.8 and patch.falling_seconds==1.05,"Quantity scaling does not alter impact, residue lifetime or descent")
	check(e.phase_config["inferno_burn_seconds"]==3 and e.phase_config["inferno_burn_damage_per_second"]==2,"V4 attached burn numbers remain unchanged")
	e.phase_config.erase("inferno_count_multiplier")
	var full=make_rain()
	for i in 3:
		full._process(interval)
		for item in full.patches:item.set_process(false)
	check(full.spawn_log.size()==128,"Omitting the multiplier preserves the original full-count profile")
	print("INFERNO_COUNT_080 ",checks," checks; passed=",not failed)
	var f:=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":not failed,"counts":counts,"cycle_drops":102,"previous_cycle_drops":128,"audio_driver":"Dummy","human_full_playthrough":false},"\t"));f.close()
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	await create_timer(.08).timeout
	quit(int(failed))
