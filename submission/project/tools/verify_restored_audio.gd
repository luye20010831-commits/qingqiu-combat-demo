extends SceneTree
var arena
var audio
var e
var s
var a
var failed := false
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"passed":ok,"label":label});failed=failed or not ok
	print(("PASS " if ok else "FAIL ")+label)
func count(event: String) -> int: return int(audio.event_counts.get(event,0))
func last_path(event: String) -> String:
	for i in range(audio.trace.size()-1,-1,-1):
		if audio.trace[i].event==event:return audio.trace[i].path
	return ""
func reset(phase := 1) -> void:
	e.start_encounter();arena.set_phase(phase)
	e.set_process(false);a.set_process(false);s.set_process(false);audio.set_process(false)
	arena.set_physics_process(false);arena.presentation.set_process(false)
	arena.player_burn.set_process(false)
	a.reset();audio.reset_combat();audio.event_counts.clear();audio.trace.clear()
	arena.player.position=Vector3(16,0,16)
func run() -> void:
	if AudioServer.get_driver_name()!="Dummy":quit(2);return
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;audio=arena.combat_audio;e=arena.encounter;s=arena.spirit_combat;a=arena.attacks
	audio.audio_enabled=true;reset()
	var resources_ok:=true
	for id in ["A01","A02","B01","B02","B03","F01","F02","F03","F05"]:
		var stream=load("res://Art/Audio/Qingqiu/SelectedSFX_20261108/%s.wav"%id)
		resources_ok=resources_ok and stream is AudioStreamWAV and stream.get_length()>0
	check(resources_ok,"All nine user-approved files import as nonempty WAV resources")
	check(s.use_skill(0,true) and count("player_cast")==0,"Accepted light windup waits for the actual swing")
	s.update_melee(.08);check(count("player_cast")==0,"Light swing does not play before its 0.09-second marker")
	s.update_melee(.02);check(count("player_cast")==1 and last_path("player_cast").ends_with("A01.wav"),"Light swing crosses its marker and plays A01 once")
	s.update_melee(.3);check(count("player_cast")==1,"Continuing the same swing does not replay its sound")
	reset();s.use_skill(1,true);s.update_melee(.20)
	check(count("player_wide_swing")==1 and count("player_cast")==0 and last_path("player_wide_swing").ends_with("A02.wav"),"Sweep uses A02 at its own swing marker")
	reset();s.use_skill(3,true);s.update_melee(.43);s.update_melee(.10)
	check(count("player_wide_swing")==1 and count("player_heavy_hit")==0,"A heavy whiff keeps its whoosh but has no fake hit")
	reset();s.use_skill(2,true)
	check(count("player_ward_cast")==0 and count("player_cast")==0,"Unselected procedural ward audio stays removed")
	reset();s.use_skill(0,true);arena.dash_remaining=1.0;s.update_melee(.2)
	check(count("player_cast")==0 and count("player_wide_swing")==0,"Interrupting before the marker cancels the swing sound")
	reset();s.register_hit(arena.boss_position(),Vector3.FORWARD,10.0,0)
	check(count("boss_hit_p1")==1 and last_path("boss_hit_p1").ends_with("B01.wav"),"Accepted normal contact plays B01")
	reset();s.register_hit(arena.boss_position(),Vector3.FORWARD,10.0,3)
	check(count("player_heavy_hit")==1 and count("boss_hit_p1")==0 and last_path("player_heavy_hit").ends_with("B02.wav"),"Accepted heavy contact plays B02 without doubling the normal hit")
	reset();a.melee_contact(arena.player.position,1.0,true)
	check(last_path("boss_body_contact").ends_with("B03.wav"),"Confirmed body contact routes to B03")
	reset(2);a.emit_fan(1,.4,0,0)
	check(count("ghost_volley")==1 and last_path("ghost_volley").ends_with("F01.wav"),"One actual volley uses F01 once")
	reset(2)
	var bullet=a.spawn_bullet(arena.player.position-Vector3.FORWARD*.95,Vector3.FORWARD,0.0,0.0,0)
	bullet.set_process(false);bullet._process(.01)
	check(count("fireball_contact")==1 and last_path("fireball_contact").ends_with("F02.wav"),"Accepted fireball contact plays F02")
	reset(2);arena.dash_remaining=1.0
	bullet=a.spawn_bullet(arena.player.position-Vector3.FORWARD*.95,Vector3.FORWARD,0.0,0.0,0)
	bullet.set_process(false);bullet._process(.01)
	check(count("fireball_contact")==0,"A dodged fireball has no fake contact sound")
	reset(2)
	var rain=load("res://Scripts/Qingqiu/p2_inferno_rain.gd").new();a.add_child(rain);rain.set_process(false)
	for patch in rain.patches:patch.set_process(false)
	rain._process(1.3)
	check(count("inferno_impact")==1 and count("hazard_ignite")==0 and last_path("inferno_impact").ends_with("F02.wav"),"A whole black-flame wave lands with one F02 cue")
	rain.patches[0]._process(1.3)
	check(not audio.fire_sources.is_empty(),"Actual residual black flame registers a burning source")
	rain.queue_free()
	reset(3)
	var hazard=e.spawn_hazard(arena.player.position+Vector3(5,0,0),1.0,.1,.5,5.0,4)
	hazard.set_process(false);hazard._process(.11)
	check(count("hazard_ignite")==1 and last_path("hazard_ignite").ends_with("F03.wav"),"Actual fire-pillar ignition uses F03")
	check(not audio.fire_sources.is_empty(),"The active fire pillar registers its burning source")
	reset(2)
	var owners: Array[Node3D]=[]
	for i in 128:
		var owner:=Node3D.new();arena.add_child(owner);owner.global_position=arena.player.global_position
		owners.append(owner);audio.set_fire_source(owner,true);audio.set_fire_source(owner,true)
	audio.update_fire_ambience(.4)
	check(audio.fire_sources.size()==128 and audio.fire_loop_player.playing,"128 flames share one playing F05 voice without duplicate source entries")
	check(audio.fire_loop_player.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and audio.fire_loop_player.bus=="QingqiuSFX","F05 loops on the existing mute-controlled SFX bus")
	audio.fire_loop_player.seek(audio.fire_loop_player.stream.get_length()-.08)
	await create_timer(.25).timeout
	check(audio.fire_loop_player.playing and audio.fire_loop_player.get_playback_position()<.6,"F05 crosses its real WAV endpoint and continues looping")
	check(audio.fire_loop_player.volume_db<=float(audio.config.fire_ambience.volume_db)+.01,"Adding many fires cannot exceed the configured ambience level")
	arena.presentation.toggle_mute()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("QingqiuSFX")),"M mutes approved one-shots and the burning loop")
	arena.presentation.toggle_mute()
	for owner in owners:owner.queue_free()
	audio.update_fire_ambience(.4)
	check(audio.fire_sources.is_empty() and not audio.fire_loop_player.playing,"Deleted residual fires expire and the aggregate loop stops")
	var far:=Node3D.new();arena.add_child(far);far.position=Vector3(200,0,200);audio.set_fire_source(far,true)
	audio.update_fire_ambience(.4)
	check(not audio.fire_loop_player.playing,"Distant fire outside the audible radius remains silent")
	far.queue_free();audio.update_fire_ambience(.4)
	check(arena.player_burn.apply(1.0),"The actual attached-burn status is accepted")
	audio.update_fire_ambience(.4)
	check(audio.fire_loop_player.playing,"Attached burn plays F05 at the player even away from scene origin")
	arena.player_burn.reset();audio.update_fire_ambience(.4)
	check(not audio.fire_loop_player.playing,"Extinguishing the attached burn stops its loop")
	arena.player_burn.apply(2.0);audio.update_fire_ambience(.4);e.start_encounter()
	check(not audio.fire_loop_player.playing and audio.fire_sources.is_empty(),"Restart clears approved fire ambience and stale sources")
	reset(2);arena.player_burn.apply(2.0);audio.update_fire_ambience(.4);e.player_health=1.0;e.damage_player(10.0)
	check(e.state==e.State.DEFEAT and not audio.fire_loop_player.playing and audio.fire_sources.is_empty(),"Actual defeat stops persistent burning audio")
	reset(2);arena.player_burn.apply(2.0);audio.update_fire_ambience(.4);arena.set_phase(3)
	check(not audio.fire_loop_player.playing and audio.fire_sources.is_empty(),"Phase commit clears the preceding phase burning loop")
	# New request: restore only the screenshot cues and the same nine selected files.
	var p=arena.presentation
	p.audio_enabled=true
	check(audio.config.events.size()==13 and audio.streams.size()==8,"Only 13 selected combat routes and eight one-shot sources are loaded; F05 is separate")
	var removed_stay_off:=true
	for cue in ["player_hurt_p1","player_hurt_p2","player_hurt_p3","tail_reveal","tail_rustle","ghost_charge","charm_charge","player_ward_cast","victory","defeat"]:
		removed_stay_off=removed_stay_off and not audio.emit_cue(cue)
	check(removed_stay_off,"Unrequested and deleted cues stay absent")
	for phase in [1,2,3]:
		p.play_voice(phase)
		check(p.voice.playing and p.last_voice_phase==phase and p.voice.stream.get_length()>1.0,"P%d licensed stage voice is playable on SFX bus"%phase)
	reset()
	e.start_encounter(1,true)
	var voice_before: int=p.voice_count
	p.opening.advance(2.1)
	check(p.voice_count==voice_before+1 and p.last_voice_phase==1 and p.voice.playing,"P1 current opening actually triggers the cub voice")
	p.opening.advance(.1)
	check(p.voice_count==voice_before+1,"P1 opening voice fires once")
	p.opening.finish(true)
	check(not p.voice.playing and e.state==e.State.RUNNING,"Skipping opening stops the voice and returns control")
	reset()
	var attack_before: int=p.transition_attack_count
	p.request_phase(2)
	check(p.fire_audio.playing and p.fire_audio.stream.resource_path.ends_with("F03.wav") and p.transition_attack.playing,"P2 curtain starts selected CC0 F03 and supplied cello")
	p.request_phase(2)
	check(p.transition_attack_count==attack_before+1,"Repeated request during one curtain does not duplicate cello")
	voice_before=p.voice_count
	p._process(1.0)
	check(arena.phase==2 and p.transition_attack.playing,"Phase commit does not cut the independent cello layer")
	check(p.voice_count==voice_before,"Normal P2 commit suppresses old shrill audition voice")
	p._process(.91)
	check(p.cinematic.laugh_fired and p.cinematic.laugh.playing,"P2 eye closeup triggers the licensed evil laugh")
	p._process(.2)
	var laugh_events:=0
	for item in p.cinematic.events:
		if item.kind=="laugh":laugh_events+=1
	check(laugh_events==1,"P2 eye closeup plays exactly one laugh")
	p._process(4.0)
	check(not p.is_busy() and not p.cinematic.laugh.playing,"P2 reveal completes and clears laugh")
	p.request_phase(3);p._process(1.11)
	check(arena.phase==3 and p.voice.playing and p.last_voice_phase==3,"P3 commit restores licensed woman wail")
	check(p.transition_attack_count==attack_before+2,"P3 curtain adds one more cello attack")
	p._process(1.11);p._process(7.0)
	check(not p.is_busy() and e.state==e.State.RUNNING,"P3 complete animation still resumes combat")
	p.toggle_mute()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("QingqiuSFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("QingqiuMusic")),"M mutes restored effects and phase music together")
	p.toggle_mute()
	p.play_voice(2);p.fire_audio.play();p.transition_attack.play()
	p.cinematic.begin(2);p.cinematic.advance(.6)
	p.cancel_transition()
	check(not p.voice.playing and not p.fire_audio.playing and not p.transition_attack.playing and not p.cinematic.laugh.playing,"Cancel stops every restored presentation layer")
	reset(2);p.play_voice(2);p.fire_audio.play();p.transition_attack.play();arena.player_burn.apply(2.0);audio.update_fire_ambience(.4)
	e.player_hit_grace=0;e.player_health=1;e.damage_player(10.0)
	check(e.state==e.State.DEFEAT and not p.voice.playing and not p.fire_audio.playing and not p.transition_attack.playing and not audio.fire_loop_player.playing,"Defeat stops cues, fire loop and all presentation layers")
	check(e.checkpoint.file_path.is_empty(),"Script integration checks use an in-memory checkpoint")
	var report={"passed":not failed,"checks":checks,"audio_driver":AudioServer.get_driver_name(),"human_playthrough":false,"human_audition":false}
	var mode:="headless" if DisplayServer.get_name()=="headless" else "native"
	var args:=OS.get_cmdline_user_args()
	var report_path: String=args[0] if not args.is_empty() else "res://artifacts/qingqiu/restore_selected_audio_20261109/%s_report.json"%mode
	var file=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	OS.delay_msec(80)
	for i in 4:await process_frame
	print("RESTORED_AUDIO_CHECKS ",checks.size()," passed=",not failed);quit(int(failed))
