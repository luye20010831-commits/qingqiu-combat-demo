extends SceneTree
var arena
var checks:=0
var failed:=false
var evidence:="res://artifacts/qingqiu/developer_phase_start"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func frames(count: int) -> void:
	for i in count:await process_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
	Input.parse_input_event(event);await frames(2)
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false
	Input.parse_input_event(event);await frames(2)
func click(button: Button) -> void:
	var event:=InputEventMouseButton.new();event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	Input.parse_input_event(event);await frames(2)
	event=InputEventMouseButton.new();event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
	Input.parse_input_event(event);await frames(2)
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))
func finish_transition() -> void:
	for i in 900:
		if arena.encounter.state==arena.encounter.State.RUNNING and not arena.presentation.is_busy():return
		await process_frame
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():evidence=args[0]
	DirAccess.make_dir_recursive_absolute(evidence)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;await frames(3)
	var d=arena.developer_test;var e=arena.encounter;var a=arena.attacks;var s=arena.spirit_combat
	e.set_process(false);a.set_process(false)
	check(not d.developer_enabled and not d.panel.visible and d.launcher.visible,"Developer mode starts disabled with a discoverable entry")
	await key(KEY_F6)
	check(e.state==e.State.PREVIEW and arena.phase==1,"P2 shortcut cannot skip stages while developer mode is off")
	await key(KEY_F7)
	check(e.state==e.State.PREVIEW and arena.phase==1,"P3 shortcut is also gated by developer mode")
	await click(d.launcher)
	check(d.developer_enabled and d.panel.visible,"Real launcher click opens developer testing")
	check(root.gui_get_focus_owner()==d.phase_buttons[1],"Opening focuses the P2 entry for keyboard navigation")
	check(root.get_visible_rect().encloses(d.panel.get_global_rect()),"Developer panel stays inside the logical viewport")
	check(root.get_visible_rect().encloses(d.launcher.get_global_rect()),"Collapsed entry respects viewport margins")
	await screenshot("panel_entry")
	await click(d.phase_buttons[1])
	check(arena.phase==2 and e.state==e.State.RUNNING and e.entry_phase==2,"Real P2 button starts a running P2 encounter directly")
	check(e.boss_health==e.health_for_phase(2) and e.player_health==e.player_max_health,"P2 start uses the actual phase HP budget and full player health")
	await screenshot("direct_p2")
	check(not arena.presentation.is_busy() and not arena.presentation.cinematic.active,"Direct start skips prior fights and cinematic input locks")
	check(e.phase_results.is_empty() and e.total_hits==0 and e.total_elapsed==0,"Direct entry does not fabricate earlier phase victories or elapsed time")
	check(arena.combat_audio.music_phase==2,"Direct P2 start selects P2 music state")
	check(root.gui_get_focus_owner()==null,"Starting releases menu focus so Enter does not replay its button")
	check(s.use_skill(0),"The fresh P2 start immediately accepts real player attacks")
	a.begin_attack("barrage_fan");a._process(1.2)
	check(a.bullets_fired>0,"P2 uses its actual attack director after direct entry")
	e.player_health=23;s.ward_remaining=2;s.cooldowns.fill(4.0)
	arena.player_burn.apply(4.0)
	arena.charm_remaining=1.0;arena.dash_remaining=.15;arena.dash_cooldown=.6
	arena.player_avatar.notify_hit()
	e.spawn_hazard(arena.player.position,1.1,.8,.7,10,2)
	a.apply_vision_charm(1.0,.45,false)
	await key(KEY_F7)
	check(arena.phase==3 and e.state==e.State.RUNNING and d.selected_phase==3,"F7 starts a fresh P3 encounter during an active P2 attempt")
	check(e.boss_health==e.health_for_phase(3) and e.player_health==e.player_max_health and e.player_hit_grace==0,"P3 begins with full phase and player HP")
	check(a.projectiles.is_empty() and e.hazards.is_empty() and e.fire_beats.is_empty(),"Jumping clears old projectiles, hazards and scheduled fire beats")
	check(arena.charm_remaining==0 and a.vision_remaining==0 and arena.player_burn.remaining==0,"Jumping clears control loss, veil and burn")
	check(s.active_skill.is_empty() and s.ward_remaining==0 and s.cooldowns.all(func(t):return t==0),"Jumping resets player attacks, shield and all skill cooldowns")
	check(arena.dash_remaining==0 and arena.dash_cooldown==0 and not arena.player_avatar.dead and arena.player_avatar.priority==0,"Jumping resets dash and hurt/death pose locks")
	check(arena.player.position.is_equal_approx(Vector3(0,0,6.5)),"New attempt restores the player starting position")
	check(arena.forms.get_child(2).visible and not arena.forms.get_child(1).visible and arena.combat_audio.music_phase==3,"P3 form, environment and music are selected together")
	await screenshot("direct_p3")
	a.begin_attack("vision_charm");a._process(1.41)
	check(a.projectiles.size()==4,"P3 can actually release its four-heart skill after direct start")
	e.player_health=10
	await key(KEY_R)
	check(arena.phase==3 and e.entry_phase==3 and e.player_health==e.player_max_health,"Developer R restarts the selected P3 with full health")
	e.damage_player(e.player_health);await frames(3)
	check(e.state==e.State.DEFEAT and arena.player_avatar.dead,"Direct P3 has real defeat behavior")
	await key(KEY_ENTER)
	check(arena.phase==3 and e.state==e.State.RUNNING and not arena.player_avatar.dead,"Enter after defeat restarts the selected test stage")
	await key(KEY_F6)
	check(arena.phase==2 and d.selected_phase==2,"F6 can switch back to a fresh P2")
	e.accept_boss_hit(e.boss_health);await frames(2)
	check(e.state==e.State.TRANSITION,"Clearing a direct P2 still uses normal progression")
	await finish_transition()
	check(arena.phase==3 and e.state==e.State.RUNNING and e.phase_results.size()==1,"P2-start play naturally advances to P3 without inventing a P1 result")
	await key(KEY_R)
	check(arena.phase==2 and e.entry_phase==2 and e.phase_results.is_empty(),"After progressing to P3, R still restarts the chosen P2 origin")
	e.accept_boss_hit(e.boss_health);await frames(6)
	await key(KEY_F7);await frames(180)
	check(arena.phase==3 and e.state==e.State.RUNNING and not arena.presentation.is_busy(),"Jumping during a transition cancels its delayed phase commit and camera lock")
	await key(KEY_TAB)
	check(e.state==e.State.PREVIEW,"Tab still returns to art preview")
	await key(KEY_R)
	check(arena.phase==3 and e.state==e.State.RUNNING,"Developer R also starts the selected stage from preview")
	await key(KEY_F8)
	check(not d.developer_enabled and not d.panel.visible,"F8 closes and disables developer controls")
	await key(KEY_R)
	check(arena.phase==1 and e.entry_phase==1,"With developer mode disabled R restores the normal P1 run")
	await key(KEY_F7)
	check(arena.phase==1,"Disabled developer hotkeys cannot interrupt normal combat")
	await key(KEY_F8);await key(KEY_ESCAPE)
	check(not d.developer_enabled and not d.panel.visible,"Escape closes the developer panel instead of quitting the game")
	print("DEVELOPER_PHASE_START ",checks," checks; passed=",not failed)
	var file:=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":not failed,"audio_driver":"Dummy","scripted_keyboard_and_mouse":true,"human_full_playthrough":false},"\t"));file.close()
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	await create_timer(.08).timeout
	quit(int(failed))
