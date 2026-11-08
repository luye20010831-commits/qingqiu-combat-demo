extends Node3D
## Melee-tuned HP overrides; target duration × reference DPS is a fallback.
signal ui_changed(snapshot: Dictionary)
enum State { PREVIEW, RUNNING, TRANSITION, VICTORY, DEFEAT, OPENING }
const BALANCE_PATH := "res://Data/Qingqiu/encounter_balance.json"
const CHECKPOINT=preload("res://Scripts/Qingqiu/stage_checkpoint.gd")
@onready var arena = get_parent()
var balance: Dictionary
var state := State.PREVIEW
var boss_health := 0.0
var boss_max_health := 0.0
var player_health := 100.0
var player_max_health := 100.0
var player_hit_grace := 0.0
var phase_elapsed := 0.0
var total_elapsed := 0.0
var phase_hits := 0
var total_hits := 0
var player_hits := 0
var wave_count := 0
var hazards_spawned := 0
var hazards_activated := 0
var wave_remaining := 3.0
var pending_phase := 0
var phase_results: Array[Dictionary] = []
var entry_phase := 1
var checkpoint
var attempt_saves_progress:=false
var hazards: Array[Node3D] = []
var last_clock_second := -1
var phase_config: Dictionary
var hud
var fire_beats: Array[Dictionary]=[]
var fire_clock:=0.0
var fire_beat_log: Array[Dictionary]=[]

func _ready() -> void:
	checkpoint=CHECKPOINT.new(CHECKPOINT.path_for_current_run())
	balance = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	player_max_health = float(balance["player_test_health"])
	player_health = player_max_health
	phase_config = balance["phases"][0]
	hud = preload("res://Scripts/Qingqiu/encounter_hud.gd").new()
	hud.name = "EncounterHUD"
	add_child(hud)
	hud.bind(self)

func health_for_phase(phase: int) -> float:
	var profile: Dictionary = balance["phases"][phase-1]
	if float(profile.get("health_override",0)) > 0: return float(profile["health_override"])
	var reference: Dictionary = balance["reference_attack"]
	return roundf(float(reference["hit_damage"])/float(reference["cooldown_seconds"])*float(profile["expected_damage_uptime"])*float(profile["target_seconds"]))

func on_phase_changed(phase: int) -> void:
	if is_instance_valid(arena.player_burn):arena.player_burn.reset()
	if is_instance_valid(arena.fox_motion_fx):arena.fox_motion_fx.reset()
	arena.combat_audio.reset_combat()
	if state in [State.RUNNING, State.TRANSITION]: arena.combat_audio.set_music_phase(phase)
	arena.player_feedback.reset()
	clear_hazards()
	phase_config = balance["phases"][phase-1]
	if arena.attacks!=null:arena.attacks.reset()
	boss_max_health = health_for_phase(phase)
	boss_health = boss_max_health
	phase_elapsed = 0.0
	phase_hits = 0
	wave_count = 0
	wave_remaining = float(phase_config["opening_grace_seconds"])
	if state == State.TRANSITION:
		player_health = minf(player_max_health,player_health+float(balance["phase_clear_recovery"]))
	publish()

func start_encounter(start_phase: int = 1,with_opening: bool = false,save_progress: bool = false) -> void:
	entry_phase = clampi(start_phase,1,3)
	attempt_saves_progress=save_progress
	arena.combat_audio.stop_music()
	state = State.PREVIEW
	arena.player_feedback.reset()
	arena.presentation.cancel_transition()
	if arena.attacks!=null:arena.attacks.reset(true)
	clear_hazards()
	arena.spirit_combat.clear_transients()
	arena.get_node("FoxCharm").reset()
	arena.charm_remaining = 0.0
	arena.dash_remaining = 0.0
	arena.dash_cooldown = 0.0
	arena.player.position = Vector3(0,0,6.5)
	arena.player.velocity = Vector3.ZERO
	arena.player_avatar.reset_avatar()
	player_max_health = float(balance["player_test_health"])
	player_health = player_max_health
	player_hit_grace = 0.0
	total_elapsed = 0.0
	total_hits = 0
	player_hits = 0
	hazards_spawned = 0
	hazards_activated = 0
	phase_results.clear()
	pending_phase = 0
	last_clock_second = -1
	arena.set_phase(entry_phase)
	state = State.OPENING if with_opening and entry_phase==1 else State.RUNNING
	arena.combat_audio.set_music_phase(entry_phase)
	if state==State.OPENING:arena.presentation.opening.begin()
	publish()

func finish_opening() -> void:
	if state!=State.OPENING:return
	state=State.RUNNING
	publish()

func stop_to_preview() -> void:
	arena.combat_audio.reset_combat()
	arena.combat_audio.stop_music()
	state = State.PREVIEW
	arena.player_feedback.reset()
	arena.presentation.cancel_transition()
	cleanup_transients()
	arena.set_phase(arena.phase)
	publish()

func _process(delta: float) -> void:
	player_hit_grace = maxf(0.0,player_hit_grace-delta)
	if state == State.RUNNING or state == State.TRANSITION:
		total_elapsed += delta
	if state == State.RUNNING:
		phase_elapsed += delta
		update_fire_beats(delta)
		if arena.phase >= 2 and arena.attacks==null:
			wave_remaining -= delta
			if wave_remaining <= 0.0:
				spawn_wave()
				var progress := 1.0-boss_health/maxf(boss_max_health,1.0)
				wave_remaining = lerpf(float(phase_config["wave_interval_start"]),float(phase_config["wave_interval_end"]),progress)
	if int(total_elapsed) != last_clock_second:
		last_clock_second = int(total_elapsed)
		publish()
	for index in range(hazards.size()-1,-1,-1):
		if not is_instance_valid(hazards[index]): hazards.remove_at(index)

func accept_boss_hit(damage: float) -> bool:
	if damage <= 0.0: return false
	if state == State.PREVIEW: return true
	if state != State.RUNNING: return false
	if arena.attacks!=null and not arena.attacks.boss_targetable():return false
	boss_health = maxf(0.0,boss_health-damage)
	phase_hits += 1
	total_hits += 1
	if boss_health <= 0.0:
		phase_results.append({"phase":arena.phase,"elapsed_seconds":phase_elapsed,"target_seconds":phase_config["target_seconds"],"hits":phase_hits,"max_health":boss_max_health})
		if attempt_saves_progress:checkpoint.advance_to(mini(arena.phase+1,3))
		if arena.phase < 3:
			state = State.TRANSITION
			pending_phase = arena.phase+1
			advance_phase.call_deferred()
		else:
			state = State.VICTORY
			arena.combat_audio.finish_combat(true)
			cleanup_transients.call_deferred()
	publish()
	return true

func advance_phase() -> void:
	if state == State.TRANSITION and pending_phase > 0:
		clear_hazards()
		if arena.phase==1:arena.presentation.begin_cub_departure(pending_phase)
		else:arena.presentation.request_phase(pending_phase)
		pending_phase = 0

func on_transition_finished() -> void:
	if state == State.TRANSITION:
		state = State.RUNNING
		publish()

func damage_player(amount: float,damage_over_time:=false) -> bool:
	if amount <= 0.0: return false
	if state != State.RUNNING or (player_hit_grace > 0.0 and not damage_over_time) or arena.dash_remaining > 0.0: return false
	if arena.presentation.orbit_intro_active:return false
	amount=arena.spirit_combat.absorb_damage(amount)
	player_health = maxf(0.0,player_health-amount)
	if not damage_over_time:player_hit_grace = float(balance["player_hit_grace_seconds"])
	player_hits += 1
	if not damage_over_time:
		arena.player_feedback.show_hit(amount,player_max_health,balance["player_hit_feedback"])
		arena.combat_audio.emit_cue("player_hurt_p%d" % arena.phase, {"trigger": "damage accepted", "damage": amount})
	if player_health <= 0.0:
		state = State.DEFEAT
		arena.combat_audio.finish_combat(false)
		cleanup_transients.call_deferred()
	publish()
	return true

func charm_cooldown() -> float:
	if state != State.RUNNING or arena.phase != 1: return 5.8
	var progress := 1.0-boss_health/maxf(boss_max_health,1.0)
	return float(phase_config["charm_cooldowns"][mini(2,int(progress*3.0))])

func on_charm_hit() -> void:
	if state == State.RUNNING and arena.phase == 1:
		damage_player(float(phase_config["charm_damage"]))

func combat_input_blocked() -> bool:
	return state in [State.OPENING,State.TRANSITION,State.VICTORY,State.DEFEAT]

func is_preview() -> bool:
	return state == State.PREVIEW

func spawn_wave() -> void:
	wave_count += 1
	if arena.phase==3:
		schedule_map_fire()
		return
	var position: Vector3 = arena.player.position
	var direction: Vector3 = arena.player.velocity
	direction.y = 0.0
	if direction.length_squared() < 0.1: direction = -position
	if direction.length_squared() < 0.1: direction = Vector3.RIGHT
	direction = direction.normalized()
	var side := Vector3(-direction.z,0,direction.x)
	for index in int(phase_config["hazard_count"]):
		var target := position+direction*float(index)*2.0
		if index == 2: target += side*0.8*sin(float(wave_count))
		target.x = clampf(target.x,-19.0,19.0)
		target.z = clampf(target.z,-19.0,19.0)
		if arena.phase==3 and arena.attacks!=null and is_instance_valid(arena.attacks.beacon):
			if target.distance_to(arena.attacks.beacon.position)<2.4:continue
		spawn_hazard(target,float(phase_config["hazard_radius"]),float(phase_config["warning_seconds"]),float(phase_config["active_seconds"]),float(phase_config["hazard_damage"]),int(phase_config["fire_palette"]))
	var ring_every := int(phase_config["ring_every_waves"])
	if ring_every > 0 and wave_count%ring_every == 0:
		var gap := (wave_count/3)%9
		for sector in 9:
			if posmod(sector-gap,9) < int(phase_config["ring_safe_sectors"]): continue
			var angle := TAU*float(sector)/9.0
			var point := Vector3(cos(angle),0,sin(angle))*float(phase_config["ring_radius"])
			if arena.attacks!=null and is_instance_valid(arena.attacks.beacon):
				if point.distance_to(arena.attacks.beacon.position)<2.4:continue
			spawn_hazard(point,1.05,float(phase_config["ring_warning_seconds"]),0.95,float(phase_config["hazard_damage"]),5)

func schedule_map_fire() -> void:
	# Nine pillars per beat versus the old three, across three map-wide rows.
	var beats:=int(phase_config.get("fire_beats",3))
	for beat in beats:
		fire_beats.append({"at":fire_clock+float(beat)*float(phase_config.get("fire_beat_interval",0.72)),"beat":beat,"cycle":wave_count})
	update_fire_beats(0.0)

func update_fire_beats(delta: float) -> void:
	if arena.phase!=3:return
	fire_clock+=delta
	while not fire_beats.is_empty() and float(fire_beats[0]["at"])<=fire_clock+0.0001:
		var entry: Dictionary=fire_beats.pop_front()
		emit_map_fire_beat(int(entry["beat"]),int(entry["cycle"]))

func emit_map_fire_beat(beat: int,cycle: int) -> void:
	var points: Array[Vector3]=[]
	var count:=int(phase_config["hazard_count"])
	var z: float=[-14.0,0.0,14.0][beat%3]
	for index in count:
		var x:=lerpf(-18.0,18.0,float(index)/float(maxi(1,count-1)))
		var point:=Vector3(x,0,z)
		if cycle%2==0:point=Vector3(z,0,x)
		if arena.attacks!=null and is_instance_valid(arena.attacks.beacon) and point.distance_to(arena.attacks.beacon.position)<2.4:
			for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
				var candidate: Vector3=point+axis*3.4
				if absf(candidate.x)<=19.0 and absf(candidate.z)<=19.0 and candidate.distance_to(arena.attacks.beacon.position)>=2.4:
					point=candidate
					break
		points.append(point)
		spawn_hazard(point,float(phase_config["hazard_radius"]),float(phase_config["warning_seconds"]),float(phase_config["active_seconds"]),float(phase_config["hazard_damage"]),int(phase_config["fire_palette"]))
	fire_beat_log.append({"beat":beat,"cycle":cycle,"time":fire_clock,"points":points})
	if fire_beat_log.size()>30:fire_beat_log.pop_front()

func spawn_hazard(position: Vector3,radius: float,warning: float,duration: float,damage: float,palette: int) -> Node3D:
	var hazard = preload("res://Scripts/Qingqiu/encounter_hazard.gd").new()
	hazard.position = Vector3(position.x,0,position.z)
	hazard.radius = radius
	hazard.warning_seconds = warning
	hazard.active_seconds = duration
	hazard.damage = damage
	hazard.palette = palette
	add_child(hazard)
	hazards.append(hazard)
	hazards_spawned += 1
	return hazard

func clear_hazards() -> void:
	fire_beats.clear()
	fire_clock=0.0
	for hazard in hazards:
		if is_instance_valid(hazard): hazard.queue_free()
	hazards.clear()

func cleanup_transients() -> void:
	if is_instance_valid(arena.player_burn):arena.player_burn.reset()
	if is_instance_valid(arena.fox_motion_fx):arena.fox_motion_fx.reset()
	if arena.attacks!=null:arena.attacks.reset()
	clear_hazards()
	arena.charm_remaining = 0.0
	arena.get_node("FoxCharm").reset()
	arena.spirit_combat.clear_transients()

func snapshot() -> Dictionary:
	var combat_hint: String=arena.attacks.label if arena.attacks!=null and not arena.attacks.label.is_empty() else "阶段自动推进 · R 重开 · Tab 返回预览"
	if arena.attacks!=null and arena.attacks.vision_remaining>0.0:
		combat_hint="幼狐魅惑 · 短暂失控走向幼狐" if arena.phase==1 else "视线被魅惑 · 靠近蔚蓝光点解除"
	return {"state":state,"phase":arena.phase,"entry_phase":entry_phase,"checkpoint_phase":checkpoint.phase,"checkpoint_error":checkpoint.last_error,"attempt_saves_progress":attempt_saves_progress,"phase_name":phase_config.get("name",""),"boss_health":boss_health,"boss_max_health":boss_max_health,"player_health":player_health,"player_max_health":player_max_health,"phase_elapsed":phase_elapsed,"total_elapsed":total_elapsed,"target_seconds":phase_config.get("target_seconds",120.0),"hits":total_hits,"player_hits":player_hits,"combat_hint":combat_hint,"cub_departure":arena.presentation.cub_departure_active}

func publish() -> void:
	ui_changed.emit(snapshot())
