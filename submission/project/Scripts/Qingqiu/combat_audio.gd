extends Node
## Selected third-party combat cues only. Deleted procedural files stay absent.
signal cue_triggered(event_name: String, detail: Dictionary)
const CONFIG_PATH := "res://Data/Qingqiu/combat_audio.json"
@onready var arena = get_parent()
var config: Dictionary
var audio_enabled := DisplayServer.get_name() != "headless"
var clock := 0.0
var pool: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_event: Dictionary = {}
var variations: Dictionary = {}
var event_counts: Dictionary = {}
var trace: Array[Dictionary] = []
var dropped := 0
var step_distance := 0.0
var previous_player_frame := -1
var music_players: Array[AudioStreamPlayer] = []
var music_slot := 0
var music_phase := 0
var music_available := false
var music_tween: Tween
var owns_music_bus := false
var fire_loop_player: AudioStreamPlayer
var fire_sources: Dictionary = {}
var random := RandomNumberGenerator.new()

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	random.seed = 1108
	for event in config["events"]:
		for path in config["events"][event]["streams"]:
			if not streams.has(path): streams[path] = load(path)
	for index in int(config["pool_size"]):
		var player := AudioStreamPlayer.new()
		player.name = "CombatCue%d" % index
		player.bus = "QingqiuSFX"
		add_child(player)
		pool.append(player)
	fire_loop_player = AudioStreamPlayer.new()
	fire_loop_player.name = "ResidualFireLoop"
	fire_loop_player.bus = "QingqiuSFX"
	add_child(fire_loop_player)
	var burn_stream: AudioStreamWAV = load(config["fire_ambience"]["stream"]).duplicate()
	burn_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	burn_stream.loop_end = roundi(burn_stream.get_length() * burn_stream.mix_rate)
	fire_loop_player.stream = burn_stream
	fire_loop_player.volume_db = -80.0
	var music_bus := AudioServer.get_bus_index("QingqiuMusic")
	if music_bus < 0:
		AudioServer.add_bus()
		music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus, "QingqiuMusic")
		owns_music_bus = true
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "PhaseMusic%d" % index
		player.bus = "QingqiuMusic"
		add_child(player)
		music_players.append(player)
	for index in arena.forms.get_child_count():
		var puppet = arena.forms.get_child(index).get_node("FoxRig")
		puppet.action_player.audio_marker.connect(on_animation_marker.bind(index + 1))
	arena.tree_exiting.connect(stop_music)

func _process(delta: float) -> void:
	clock += delta
	update_fire_ambience(delta)

func set_fire_source(source: Node3D, burning: bool, attached := false) -> void:
	if not is_instance_valid(source): return
	var key := source.get_instance_id()
	if burning:
		fire_sources[key] = {"source": weakref(source), "attached": attached}
	else:
		fire_sources.erase(key)

func update_fire_ambience(delta: float) -> void:
	var strength := 0.0
	var profile: Dictionary = config["fire_ambience"]
	for key in fire_sources.keys():
		var source: Node3D = fire_sources[key]["source"].get_ref()
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree():
			fire_sources.erase(key)
			continue
		var distance: float = 0.0 if fire_sources[key]["attached"] else source.global_position.distance_to(arena.player.global_position)
		if distance < float(profile["max_distance_meters"]):
			strength = maxf(strength, 1.0 / (1.0 + pow(distance / float(profile["falloff_meters"]), 2.0)))
	if not audio_enabled or arena.encounter == null or arena.encounter.state != arena.encounter.State.RUNNING or arena.phase < 2 or arena.presentation.is_busy():
		fire_loop_player.stop()
		fire_loop_player.volume_db = -80.0
		return
	var target: float = float(profile["volume_db"]) + linear_to_db(strength) if strength > 0.001 else -80.0
	fire_loop_player.volume_db = lerpf(fire_loop_player.volume_db, target, 1.0 - exp(-18.0 * delta))
	if strength > 0.001 and not fire_loop_player.playing:
		fire_loop_player.play()
	elif strength <= 0.001 and fire_loop_player.volume_db < -65.0:
		fire_loop_player.stop()

func on_animation_marker(event: String, clip: String, seconds: float, phase: int) -> void:
	if phase != arena.phase: return
	if arena.encounter == null: return
	if arena.encounter.state != arena.encounter.State.RUNNING and not arena.presentation.is_busy(): return
	# Walking in place against an obstacle must not make footsteps.
	if event == "boss_step" and arena.forms.get_child(phase-1).get_node("FoxRig").movement_speed < 0.04: return
	emit_cue(event, {"clip": clip, "clip_seconds": seconds, "frame_at_60fps": seconds*60.0, "phase": phase})

func emit_cue(event: String, detail: Dictionary = {}) -> bool:
	if arena.encounter != null and arena.encounter.state in [arena.encounter.State.VICTORY, arena.encounter.State.DEFEAT] and event not in ["victory", "defeat"]: return false
	if not config["events"].has(event): return false
	var preset: Dictionary = config["events"][event]
	if clock-float(last_event.get(event, -999.0)) < float(preset["cooldown_seconds"]): return false
	var choice: AudioStreamPlayer
	var voices := 0
	for player in pool:
		if player.playing and player.get_meta("event", "") == event: voices += 1
		if not player.playing and choice == null: choice = player
	if voices >= int(preset["max_voices"]):
		dropped += 1
		return false
	if choice == null:
		# Only steal a lower priority voice; footfalls cannot interrupt hit/cleanse/death.
		for player in pool:
			if int(player.get_meta("priority", 0)) < int(preset["priority"]):
				if choice == null or int(player.get_meta("priority", 0)) < int(choice.get_meta("priority", 0)):
					choice = player
	if choice == null:
		dropped += 1
		return false
	var paths: Array = preset["streams"]
	if paths.is_empty(): return false
	var variation := int(variations.get(event, 0)) % paths.size()
	variations[event] = variation + 1
	choice.stop()
	choice.stream = streams[paths[variation]]
	choice.volume_db = float(preset["volume_db"])
	choice.pitch_scale = random.randf_range(float(preset["pitch_range"][0]), float(preset["pitch_range"][1]))
	choice.set_meta("event", event)
	choice.set_meta("priority", int(preset["priority"]))
	if audio_enabled: choice.play()
	last_event[event] = clock
	event_counts[event] = int(event_counts.get(event, 0)) + 1
	var record := detail.duplicate(true)
	record.merge({"event": event, "clock": clock, "path": paths[variation], "phase": arena.phase}, true)
	trace.append(record)
	if trace.size() > 256: trace.pop_front()
	cue_triggered.emit(event, record)
	return true

func update_player_motion(before: Vector3, after: Vector3, dashing: bool, sprite_frame: int) -> void:
	var distance := Vector2(after.x-before.x, after.z-before.z).length()
	if dashing or arena.presentation.is_busy() or arena.encounter.state in [arena.encounter.State.DEFEAT, arena.encounter.State.VICTORY]:
		step_distance = 0.0
		previous_player_frame = -1
		return
	if distance < 0.0001:
		step_distance = 0.0
		previous_player_frame = -1
		return
	step_distance += distance
	if sprite_frame != previous_player_frame and step_distance >= float(config["player_step_distance_meters"]):
		emit_cue("player_step", {"sprite_frame": sprite_frame, "trigger": "actual travel + visible texture contact"})
		step_distance = 0.0
	previous_player_frame = sprite_frame

func reset_combat() -> void:
	for player in pool: player.stop()
	fire_sources.clear()
	if is_instance_valid(fire_loop_player):
		fire_loop_player.stop()
		fire_loop_player.volume_db = -80.0
	last_event.clear()
	step_distance = 0.0
	previous_player_frame = -1

func finish_combat(won: bool) -> void:
	reset_combat()
	stop_music()
	arena.presentation.stop_sounds()
	emit_cue("victory" if won else "defeat", {"trigger": "terminal combat state"})

func set_music_phase(phase: int) -> bool:
	var path: String = config["music"]["phases"].get(str(phase), "")
	if path.is_empty() or not ResourceLoader.exists(path):
		stop_music()
		return false
	if music_phase == phase and music_available: return true
	var music = load(path).duplicate()
	if music is AudioStreamOggVorbis or music is AudioStreamMP3: music.loop = true
	elif music is AudioStreamWAV:
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.loop_begin = 0
		music.loop_end = roundi(music.get_length()*music.mix_rate)
	else: return false
	if is_instance_valid(music_tween): music_tween.kill()
	var old := music_players[music_slot]
	music_slot = 1 - music_slot
	var next := music_players[music_slot]
	next.stop()
	next.stream = music
	next.volume_db = -80.0
	if audio_enabled: next.play()
	music_phase = phase
	music_available = true
	music_tween = create_tween().set_parallel(true)
	var duration := float(config["music"]["crossfade_seconds"])
	music_tween.tween_property(old, "volume_db", -80.0, duration)
	music_tween.tween_property(next, "volume_db", float(config["music"]["volume_db"]), duration)
	music_tween.chain().tween_callback(old.stop)
	return true

func stop_music() -> void:
	if is_instance_valid(music_tween): music_tween.kill()
	for player in music_players: player.stop()
	music_phase = 0
	music_available = false

func set_music_muted(muted: bool) -> void:
	var bus := AudioServer.get_bus_index("QingqiuMusic")
	if bus >= 0: AudioServer.set_bus_mute(bus, muted)

func _exit_tree() -> void:
	reset_combat()
	if is_instance_valid(fire_loop_player):fire_loop_player.stream = null
	stop_music()
	if owns_music_bus:
		var bus := AudioServer.get_bus_index("QingqiuMusic")
		if bus > 0: AudioServer.remove_bus(bus)
