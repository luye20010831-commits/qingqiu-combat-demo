extends SceneTree
## Three supplied MP3s through real encounter transitions and Dummy playback.
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var phase_streams: Dictionary = {}
var arena
var audio
var encounter

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"passed": ok, "label": label})
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func playing_count() -> int:
	var count := 0
	for player in audio.music_players:
		if player.playing: count += 1
	return count

func freeze_gameplay() -> void:
	encounter.set_process(false)
	arena.set_physics_process(false)
	arena.attacks.set_process(false)
	arena.spirit_combat.set_process(false)
	arena.presentation.set_process(false)
	for form in arena.forms.get_children(): form.get_node("FoxRig").set_process(false)

func run() -> void:
	if AudioServer.get_driver_name() != "Dummy":
		push_error("This check requires --audio-driver Dummy")
		quit(2)
		return
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	arena = current_scene
	audio = arena.combat_audio
	encounter = arena.encounter
	freeze_gameplay()
	check(playing_count() == 0 and not audio.music_available, "Preview remains silent with three available tracks")
	audio.audio_enabled = true
	encounter.start_encounter()
	freeze_gameplay()
	for phase in [1, 2, 3]:
		if phase > 1:
			var previous: int = phase - 1
			var accepted: bool = encounter.accept_boss_hit(encounter.boss_health)
			await process_frame
			check(accepted and encounter.state == encounter.State.TRANSITION and audio.music_phase == previous,
				"P%d clear retains its track until curtain commit" % previous)
			var ticks := 0
			# Advance the actual presentation clock, including P1 mist departure.
			# This is scripted fast-forward, not a normal player playthrough.
			while arena.phase != phase and ticks < 480:
				arena.presentation._process(1.0 / 60.0)
				ticks += 1
			check(arena.phase == phase and audio.music_phase == phase and playing_count() == 2,
				"P%d curtain commit starts the real incoming track with the outgoing track still fading" % phase)
			while arena.presentation.is_busy() and ticks < 960:
				arena.presentation._process(1.0 / 60.0)
				ticks += 1
			check(encounter.state == encounter.State.RUNNING, "P%d reveal resumes combat without restarting its music" % phase)
		var path: String = audio.config.music.phases[str(phase)]
		var source = load(path)
		check(source is AudioStreamMP3 and source.get_length() > 0.0, "P%d imports its supplied nonempty MP3" % phase)
		var player: AudioStreamPlayer = audio.music_players[audio.music_slot]
		check(audio.music_phase == phase and player.playing and player.stream.data == source.data,
			"P%d plays the exact configured file bytes" % phase)
		check(player.stream.loop and player.bus == "QingqiuMusic", "P%d loops on the dedicated music bus" % phase)
		await create_timer(0.95).timeout
		check(playing_count() == 1 and absf(player.volume_db - float(audio.config.music.volume_db)) < 0.1,
			"P%d fade settles to one track at -20 dB" % phase)
		player.seek(source.get_length() - 0.15)
		await create_timer(0.5).timeout
		check(player.playing and player.get_playback_position() < 1.5 and playing_count() == 1,
			"P%d crosses its actual MP3 endpoint and keeps looping" % phase)
		var slot: int = audio.music_slot
		var position: float = player.get_playback_position()
		check(audio.set_music_phase(phase) and audio.music_slot == slot and absf(player.get_playback_position() - position) < 0.1,
			"Repeated P%d notification preserves playback position" % phase)
		phase_streams[str(phase)] = {"path": path, "length_seconds": source.get_length()}
		arena.attacks.reset()
	arena.presentation.toggle_mute()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("QingqiuMusic")), "M mutes the actual P3 music bus")
	arena.presentation.toggle_mute()
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("QingqiuMusic")), "M restores the music bus")
	encounter.start_encounter()
	freeze_gameplay()
	check(arena.phase == 1 and audio.music_phase == 1 and playing_count() == 1 and audio.music_players[audio.music_slot].get_playback_position() < 0.2,
		"Restart from P3 replaces all old music with P1 from the start")
	encounter.stop_to_preview()
	check(playing_count() == 0 and not audio.music_available, "Return to preview stops all phase music")
	encounter.start_encounter()
	arena.set_phase(2)
	encounter.damage_player(9999.0)
	check(encounter.state == encounter.State.DEFEAT and playing_count() == 0 and not audio.music_available,
		"Defeat during a P1-to-P2 fade stops both tracks")
	encounter.start_encounter()
	arena.set_phase(3)
	arena.attacks.reset()
	encounter.accept_boss_hit(encounter.boss_health)
	check(encounter.state == encounter.State.VICTORY and playing_count() == 0 and not audio.music_available,
		"Actual P3 victory stops its real music and outgoing fade")
	encounter.start_encounter()
	var chosen_p2: String = audio.config.music.phases["2"]
	audio.config.music.phases["2"] = "res://Art/Audio/Qingqiu/Music/__missing_phase_music_test_only__.ogg"
	arena.set_phase(2)
	check(playing_count() == 0 and not audio.music_available, "Explicit missing fixture falls silent without leaking P1")
	audio.config.music.phases["2"] = chosen_p2
	encounter.start_encounter()
	arena.set_phase(3)
	var music_bus_owned: bool = audio.owns_music_bus
	current_scene.queue_free()
	current_scene = null
	for frame in 4: await process_frame
	# Scripted reveal clocks can outrun Dummy's real audio thread; match the closeup suite teardown.
	OS.delay_msec(80)
	for frame in 4: await process_frame
	check(not music_bus_owned or AudioServer.get_bus_index("QingqiuMusic") == -1, "Scene exit cleans its bus and active crossfade")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"phases": phase_streams, "audio_driver": AudioServer.get_driver_name(), "display_server": DisplayServer.get_name(),
		"human_audition": false, "human_playthrough": false, "scripted_presentation_fast_forward": true,
		"loop_seams_auditioned": false, "beat_aligned_transition": false}
	var mode := "headless" if DisplayServer.get_name() == "headless" else "native"
	var file := FileAccess.open("res://artifacts/qingqiu/phase_music/%s_report.json" % mode, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PHASE_MUSIC_CHECKS %d, FAILURES %d" % [checks.size(), failures.size()])
	quit(int(not failures.is_empty()))
