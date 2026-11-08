extends SceneTree
var arena
var failed:=false
var checks:=0
var evidence:="res://artifacts/qingqiu/opening_mist_guest"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func frames(n: int) -> void:
	for i in n:await process_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
	Input.parse_input_event(event);await frames(2)
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false
	Input.parse_input_event(event);await frames(2)
func advance(seconds: float) -> void:
	var steps:=ceili(seconds*60.0)
	for i in steps:
		var delta:=minf(1.0/60.0,seconds-float(i)/60.0)
		arena.presentation._process(delta);arena.encounter._process(delta)
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():evidence=args[0]
	DirAccess.make_dir_recursive_absolute(evidence)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;await frames(2)
	var e=arena.encounter;var p=arena.presentation;var o=p.opening;var a=arena.attacks
	p.set_process(false);e.set_process(false);arena.set_physics_process(false);a.set_process(false)
	check(e.is_preview() and not o.active,"Application still opens in a controllable art preview")
	arena.camera_distance_scale=.65
	await key(KEY_ENTER)
	check(e.state==e.State.OPENING and o.active and p.is_busy(),"Real normal Enter begins the new opening state")
	check(o.age==0 and o.layer.visible and o.banks.size()==2,"Opening owns two ground mist wings and a visible cinematic overlay")
	check(not arena.get_node("Presentation").visible and not e.hud.visible and not arena.developer_test.visible,"Cinematic temporarily hides the existing HUD and developer entry")
	check(arena.combat_audio.music_phase==1,"P1 music is selected under the opening")
	var before: Vector3=arena.player.position
	Input.action_press("MoveRight");Input.action_press("Dash");arena._physics_process(1.0/60.0)
	Input.action_release("MoveRight");Input.action_release("Dash")
	check(arena.player.position.is_equal_approx(before) and arena.dash_remaining==0,"Actual movement and dash are blocked during the opening")
	var blocked:=true
	for index in 4:blocked=blocked and not arena.spirit_combat.use_skill(index)
	check(blocked and e.combat_input_blocked(),"All player skills are gated while the opening is active")
	check(not e.damage_player(50) and not e.accept_boss_hit(50) and e.player_health==120,"Neither side can take combat damage during staging")
	advance(.60)
	check(o.shot=="mist" and o.veil.material.get_shader_parameter("darkness")<.1,"Ink veil opens into the real forest before the leap")
	await screenshot("mist")
	advance(.60)
	check(o.shot=="leap" and a.fox_height>.30 and arena.boss_position().z<0,"Existing cub hop moves through the real 3D scene above the ground")
	check(o.rig.action_player.current=="cub_hop","The opening really plays the current authored hop clip")
	await screenshot("leap")
	advance(.50)
	check(o.landed and o.landing.visible and a.fox_height==0,"Landing triggers one temporary ivory ground blossom")
	check(o.form.position.is_equal_approx(Vector3.ZERO) and o.shot=="gaze","Cub lands at the actual combat origin and turns to its gaze pose")
	check(o.title.modulate.a>.2,"Short title card appears over the landed cub")
	await screenshot("landing")
	advance(.70)
	check(o.shot=="gaze" and o.rig.charm_charge>0,"Current gaze pose has a brief registered-eye highlight")
	check(o.banks[0].position.x<-6.9 and o.banks[1].position.x>6.9,"Ground mist has physically parted to both sides")
	check(e.phase_elapsed==0 and e.total_elapsed==0 and a.casts==0,"Opening consumes neither phase time nor attack grace")
	await screenshot("gaze")
	advance(.60)
	check(o.shot=="return" and o.rig.charm_charge==0,"Gaze releases before the camera returns to gameplay")
	advance(1.60)
	check(not o.active and e.state==e.State.RUNNING and not p.is_busy(),"The 4.6-second opening completes into playable combat")
	check(e.phase_elapsed<.04 and e.total_elapsed<.04,"Encounter timing starts at completion rather than at the opening's first frame")
	check(e.hud.visible and arena.get_node("Presentation").visible and arena.developer_test.visible,"Normal completion restores the previous interface")
	var expected: Vector3=arena.player.position+arena.CAMERA_LOOK_OFFSET+(arena.CAMERA_OFFSET-arena.CAMERA_LOOK_OFFSET)*.65
	check(arena.camera.position.distance_to(expected)<.001 and arena.camera.fov==35 and arena.camera_distance_scale==.65,"Gameplay camera restores the user's wheel distance and FOV exactly")
	check(o.rig.is_processing() and not a.is_processing() and a.fox_height==0,"Opening restores each previously enabled or paused processing route")
	check(o.rig.charm_charge==0 and o.rig.action_player.current.is_empty(),"No gaze/attack pose leaks into the first live frame")
	await frames(2)
	check(arena.find_children("OpeningGroundEffects","Node3D",false,false).is_empty(),"Temporary mist and landing nodes are freed on completion")
	check(arena.spirit_combat.use_skill(0),"Player attack is immediately usable after the cinematic")
	e.stop_to_preview();await key(KEY_ENTER);advance(.8);await key(KEY_ENTER)
	check(not o.active and e.state==e.State.RUNNING,"A second Enter skips the opening instead of restarting it")
	check(arena.spirit_combat.active_skill.is_empty() and e.boss_health==1850,"Skipping does not accidentally trigger a combat action")
	e.start_encounter(1,true);advance(1.2)
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(960,540);Input.parse_input_event(click);await frames(2)
	click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(960,540);Input.parse_input_event(click);await frames(2)
	check(not o.active and e.state==e.State.RUNNING and arena.spirit_combat.active_skill.is_empty(),"Mouse skip is consumed and cannot become a weapon swing")
	e.start_encounter(1,true);advance(.4);await key(KEY_R);advance(5.0)
	check(not o.active and e.state==e.State.RUNNING and arena.phase==1,"R cancels staging and performs a fast clean restart without stale completion")
	e.start_encounter(1,true);advance(1.1);await key(KEY_TAB);advance(5.0)
	check(not o.active and e.is_preview() and not p.is_busy(),"Tab cancels the opening without later resuming combat")
	arena.developer_test.set_enabled(true);e.start_encounter(1,true);advance(.9);await key(KEY_F6)
	check(arena.phase==2 and e.state==e.State.RUNNING and not o.active and arena.developer_test.visible,"Developer P2 jump cancels the opening and stays immediately playable")
	await key(KEY_F7)
	check(arena.phase==3 and e.state==e.State.RUNNING and not o.active,"Developer P3 remains a direct playable start")
	e.start_encounter(1)
	check(e.state==e.State.RUNNING and not o.active,"Existing programmatic / rapid-test entry remains immediate by default")
	arena.developer_test.set_enabled(false);e.start_encounter(1,true);await key(KEY_ESCAPE)
	check(e.state==e.State.RUNNING and not o.active,"Escape skips the current opening without quitting")
	e.stop_to_preview();arena.get_node("Presentation").visible=false;e.hud.visible=false;arena.developer_test.visible=false
	e.start_encounter(1,true);o.finish(true)
	check(not arena.get_node("Presentation").visible and not e.hud.visible and not arena.developer_test.visible,"Completion preserves an intentionally hidden interface")
	arena.get_node("Presentation").visible=true;e.hud.visible=true;arena.developer_test.visible=true
	p.reduced_effects=true;e.start_encounter(1,true)
	check(absf(arena.camera.position.x)<3 and arena.camera.fov==35,"Reduced-effects mode uses gentler camera staging")
	o.finish(true);p.reduced_effects=false
	e.start_encounter(2,true)
	check(arena.phase==2 and e.state==e.State.RUNNING and not o.active,"Opening request does not replace the distinct P2 phase reveal")
	print("OPENING_MIST_GUEST ",checks," checks; passed=",not failed)
	var f:=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":not failed,"duration":4.6,"audio_driver":"Dummy","scripted_input_and_timeline":true,"human_full_playthrough":false},"\t"));f.close()
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	await create_timer(.08).timeout
	quit(int(failed))
