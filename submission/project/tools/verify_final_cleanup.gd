extends SceneTree
## Exercises actual timers, contacts and encounter transitions. Test saves are isolated.
var arena
var failed:=false
var checks:=0
var evidence:="res://artifacts/final_cleanup_20261109"
var observations: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func freeze() -> void:
	arena.set_physics_process(false);arena.encounter.set_process(false)
	arena.attacks.set_process(false);arena.spirit_combat.set_process(false)
	arena.presentation.set_process(false);arena.player_burn.set_process(false)
func fresh(phase: int) -> void:
	arena.encounter.start_encounter(phase);freeze()
	arena.player.position=Vector3(18,0,18);arena.dash_remaining=0
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))
func contact(phase: int):
	var heart=preload("res://Scripts/Qingqiu/charm_heart_projectile.gd").new()
	heart.source_phase=phase;heart.homing=phase==1;heart.with_beacon=phase==3
	heart.charm_seconds=1.2 if phase==1 else 5.0
	heart.position=arena.player.position;heart.speed=0
	arena.attacks.add_child(heart);arena.attacks.projectiles.append(heart);heart.set_process(false)
	heart._process(1.0/60.0);return heart
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():evidence=args[0]
	DirAccess.make_dir_recursive_absolute(evidence)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;await process_frame;freeze()
	var e=arena.encounter;var a=arena.attacks;var p=arena.presentation;var s=arena.spirit_combat
	var clean:=true
	for node in arena.find_children("*","Label",true,false):
		for hint in ["V 狐鸣","M 静音","B 减弱特效","G 鬼火","H 换色","N 场景风"]:
			clean=clean and hint not in node.text
	check(clean,"The screenshot's auxiliary hint row is absent from the live UI")
	check(arena.get_node("Presentation/Interface/Controls").text.contains("WASD"),"Main combat controls remain visible")
	check(e.checkpoint.file_path.is_empty(),"This integration run does not use the player's real save")
	await snap("clean_hud")
	fresh(1);a.direction=Vector3.FORWARD;a.emit_cub_charm_heart()
	var heart=a.projectiles[0];heart.set_process(false)
	check(is_equal_approx(heart.lifetime,2.5),"P1 homing heart receives the 2.5-second lifetime")
	var p1_color: Color=heart.material.get_shader_parameter("fill_color")
	check(p1_color.b>p1_color.r,"P1 uses a visibly distinct cyan-white heart palette")
	heart._process(2.49)
	check(not heart.resolved,"P1 heart may travel until just before 2.5 seconds")
	heart._process(.02)
	check(heart.resolved and heart.is_queued_for_deletion(),"P1 expires at the deadline without requiring a hit")
	await process_frame
	check(not is_instance_valid(heart),"Expired P1 visual and aura nodes are actually freed")
	fresh(1);arena.player.position=Vector3(0,0,3)
	var before: int=a.charm_hits
	heart=contact(1);a.update_vision(.1)
	check(heart.resolved and a.charm_hits==before+1,"P1 contact consumes one heart and registers exactly one charm")
	check(is_equal_approx(arena.charm_remaining,1.2),"P1 retains its short forced-approach gameplay effect")
	check(a.vision_remaining==0 and not a.vision_rect.visible and not is_instance_valid(a.beacon),"P1 contact creates no pink fog, vision obstruction or cleansing pickup")
	await snap("p1_contact_no_fog")
	fresh(1);s.ward_remaining=1;before=a.charm_hits;heart=contact(1)
	check(heart.resolved and arena.charm_remaining==0 and a.charm_hits==before,"An active ward still consumes P1 hearts before charm")
	fresh(3);a.direction=Vector3.FORWARD;a.emit_charm_hearts()
	var p3_hearts: Array=a.projectiles.duplicate();var capped:=p3_hearts.size()==4
	var p3_color: Color=p3_hearts[0].material.get_shader_parameter("fill_color")
	check(p3_color.r>p3_color.g*3 and p3_color.s>.7,"P3 hearts use a deeper saturated rose distinct from P1")
	for h in p3_hearts:
		h.set_process(false);capped=capped and is_equal_approx(h.lifetime,2.5);h._process(2.51)
		capped=capped and h.resolved and h.is_queued_for_deletion()
	check(capped,"All four P3 hearts independently expire by 2.5 seconds")
	fresh(3);arena.player.position=Vector3(0,0,3);heart=contact(3);a.update_vision(.35)
	check(a.vision_remaining>0 and a.vision_rect.visible,"P3 heart contact retains pink-purple fog")
	check(arena.charm_remaining==0 and is_instance_valid(a.beacon),"P3 retains free movement and its cleansing light")
	await snap("p3_contact_with_fog")
	var cleanses: int=a.cleanses;arena.player.position=a.beacon.position;a.update_vision(.02);a.update_vision(.4)
	check(a.vision_remaining==0 and not a.vision_rect.visible and a.cleanses==cleanses+1,"Taking the real light pickup removes P3 fog")
	fresh(1);e.boss_health=1;s.register_hit(arena.boss_position(),Vector3.FORWARD,10.0,0)
	await process_frame
	check(e.state==e.State.TRANSITION and p.cub_departure_active,"Lethal P1 weapon contact starts the real mist departure")
	var p2_no_eye:=true
	for i in 70:
		p._process(.1);p2_no_eye=p2_no_eye and not p.cinematic.active and not p.cinematic.layer.visible
		if not p.is_busy():break
	check(arena.phase==2 and e.state==e.State.RUNNING and not p.is_busy(),"P1-to-P2 completes fire and tail reveal and restores combat")
	check(p2_no_eye and p.cinematic.get_node_or_null("RevealLaugh")==null,"P2 has no eye insert or orphaned eye-specific laugh")
	await snap("p2_after_transition")
	e.boss_health=1;s.register_hit(arena.boss_position(),Vector3.FORWARD,10.0,0)
	await process_frame
	var shots: Array[String]=[]
	for i in 95:
		p._process(.1)
		if p.cinematic.active and p.cinematic.shot not in shots:
			shots.append(p.cinematic.shot)
			if p.cinematic.shot=="tails":await snap("p3_tail_without_eye_insert")
		if not p.is_busy():break
	check(arena.phase==3 and e.state==e.State.RUNNING and not p.is_busy(),"P2-to-P3 resumes battle after its shortened reveal")
	check("anklet" in shots and "tails" in shots and "body" in shots and "eyes" not in shots,"P3 retains anklet, tails and body while skipping every eye shot")
	check(is_equal_approx(p.cinematic.duration,5.5),"P3 no longer reserves the deleted eye segment's time")
	check(not p.cinematic.layer.visible and p.cinematic.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Completed P3 reveal releases its overlay and offscreen rendering")
	observations.append({"p3_shots":shots})
	fresh(1);p.request_phase(3);p._process(2.21);p._process(2.0);e.start_encounter(1)
	check(not p.is_busy() and not p.cinematic.active and not p.cinematic.layer.visible,"Restart during P3 reveal clears camera and overlay state")
	fresh(1);p.request_phase(2);p._process(1.91);e.stop_to_preview()
	check(e.is_preview() and not p.is_busy(),"Returning to preview during the shorter P2 reveal releases input locks")
	var report={"checks":checks,"passed":not failed,"observations":observations,"audio_driver":"Dummy","human_playthrough":false,"production_save_used":false}
	var f=FileAccess.open(evidence.path_join("final_cleanup_checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("FINAL_CLEANUP ",checks," checks; passed=",not failed)
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	OS.delay_msec(80)
	for i in 4:await process_frame
	quit(int(failed))
