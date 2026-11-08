extends SceneTree
var failed := false
var arena
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for frame in count: await process_frame
func wait_for_combat_phase(value: int) -> void:
	for frame in 900:
		if arena.phase==value and arena.encounter.state==arena.encounter.State.RUNNING and not arena.presentation.is_busy():return
		await process_frame
func check(value: bool,label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	failed = failed or not value
func key(code: Key,pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	arena = current_scene
	await frames(5)
	var encounter = arena.encounter
	check(encounter.state == encounter.State.PREVIEW,"Scene opens in preview with the minimal boss health HUD")
	check(encounter.health_for_phase(1) == 1850 and encounter.health_for_phase(2) == 2000 and encounter.health_for_phase(3) == 2000,"V4 close-range HP budgets retain the 2/3/3 target")
	key(KEY_ENTER)
	await frames(2)
	key(KEY_ENTER,false)
	await frames(3)
	check(encounter.state==encounter.State.OPENING and arena.presentation.opening.active,"Normal Enter first stages the opening without starting combat")
	await wait_for_combat_phase(1)
	check(encounter.state == encounter.State.RUNNING and arena.phase == 1,"Enter starts the encounter through the keyboard handler")
	arena.attacks.set_process(false)
	arena.player.position = Vector3(0,0,2.0)
	var before: float = encounter.boss_health
	key(KEY_J)
	await frames(24)
	check(encounter.boss_health == before-10.0,"Actual close-range contact reduces boss HP by reference damage")
	key(KEY_3)
	await frames(3)
	check(arena.phase == 1,"Preview phase shortcuts cannot skip an active fight")
	var charm = arena.get_node("FoxCharm")
	check(charm.projectiles.is_empty() and not arena.ghost_fire.visible,"P1 no longer uses the retired charm or decorative ghost fire")
	encounter.player_hit_grace = 0.0
	var player_before: float = encounter.player_health
	arena.dash_remaining = 0.15
	check(not encounter.damage_player(10) and encounter.player_health == player_before,"Existing dash protects the test player from danger zones")
	arena.dash_remaining = 0.0
	check(encounter.damage_player(10),"A valid danger hit reduces test spirit health")
	check(not encounter.damage_player(10) and encounter.player_health == player_before-10,"Hit grace prevents overlapping flames from stacking instant damage")
	encounter.accept_boss_hit(encounter.boss_health)
	await frames(4)
	check(encounter.state == encounter.State.TRANSITION and arena.presentation.cub_departure_active and not arena.presentation.transition_active,"Empty P1 HP starts its vapor departure before the phase curtain")
	check(not arena.spirit_combat.shoot(),"Attacks stop during automatic transition")
	await wait_for_combat_phase(2)
	check(arena.phase == 2 and encounter.state == encounter.State.RUNNING,"Phase 2 starts only after the curtain clears")
	check(encounter.boss_health == 2000 and encounter.player_health == encounter.player_max_health,"New phase restores its HP budget and the phase-clear spirit recovery")
	var fox_shots_before: int = charm.shots_fired
	arena.attacks.begin_attack("barrage_fan")
	arena.attacks._process(1.2)
	await frames(3)
	check(charm.shots_fired == fox_shots_before and arena.attacks.bullets_fired>=7,"P2 uses its new ghost-fire barrage instead of heart projectiles")
	arena.attacks.reset()
	encounter.clear_hazards()
	encounter.wave_remaining = 100.0
	arena.player.position = Vector3(19.35,0,19.35)
	encounter.spawn_wave()
	check(encounter.hazards[0].position.distance_to(arena.player.position) < encounter.hazards[0].radius,"Aimed fire still covers the arena corner instead of leaving an immune edge")
	encounter.clear_hazards()
	arena.player.position = Vector3(0,0,6.5)
	encounter.player_hit_grace = 0.0
	var hazard = encounter.spawn_hazard(arena.player.position,1.1,1.0,0.7,10.0,7)
	player_before = encounter.player_health
	await frames(45)
	check(encounter.player_health == player_before and not hazard.activated,"Fire warning gives an actual damage-free reaction window")
	await frames(20)
	check(encounter.player_health == player_before-10 and hazard.activated,"Fire hurts only after the warning completes")
	encounter.accept_boss_hit(encounter.boss_health)
	await wait_for_combat_phase(3)
	check(arena.phase == 3 and encounter.boss_health == 2000,"P3 uses the three-minute pressure-adjusted HP budget")
	encounter.clear_hazards()
	encounter.wave_count = 2
	encounter.wave_remaining = 100.0
	encounter.spawn_wave()
	check(encounter.hazards.size() == 9 and encounter.fire_beats.size()==2,"P3 starts nine pillars and schedules two more map-wide beats")
	encounter.accept_boss_hit(encounter.boss_health)
	await frames(3)
	check(encounter.state == encounter.State.VICTORY and encounter.phase_results.size() == 3,"Clearing all three HP pools reaches victory once")
	check(encounter.hazards.is_empty() and arena.spirit_combat.shots.is_empty(),"Victory clears pending attacks and fire zones")
	key(KEY_R)
	await frames(3)
	check(encounter.state == encounter.State.RUNNING and arena.phase == 3 and encounter.player_health == encounter.player_max_health,"R retries the earned P3 checkpoint at full health")
	encounter.damage_player(encounter.player_health)
	await frames(3)
	check(encounter.state == encounter.State.DEFEAT and not arena.spirit_combat.shoot(),"Spirit depletion ends the attempt and gates attacking")
	encounter.start_encounter()
	encounter.accept_boss_hit(encounter.boss_health)
	await frames(10)
	encounter.start_encounter()
	await frames(145)
	check(arena.phase == 1 and encounter.state == encounter.State.RUNNING and not arena.presentation.transition_active,"Restart during a curtain cancels stale phase commits")
	key(KEY_TAB)
	await frames(3)
	check(encounter.state == encounter.State.PREVIEW,"Tab returns to visual preview mode")
	key(KEY_C)
	await frames(2)
	check(not encounter.hud.visible and not arena.get_node("Presentation").visible,"C hides the combat HUD together with the scene interface")
	key(KEY_C)
	await frames(2)
	check(encounter.hud.visible and arena.get_node("Presentation").visible,"C restores both interface layers")
	var bounds: Rect2 = encounter.hud.boss_panel.get_global_rect()
	check(get_root().get_visible_rect().encloses(bounds),"Boss HUD stays inside the current viewport")
	quit(int(failed))
