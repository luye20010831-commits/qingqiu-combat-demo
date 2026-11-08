extends SceneTree
var arena
var failed:=false
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func heart_at_player(phase: int):
	var a=arena.attacks
	var heart=preload("res://Scripts/Qingqiu/charm_heart_projectile.gd").new()
	heart.source_phase=phase;heart.homing=phase==1;heart.with_beacon=phase==3
	heart.charm_seconds=float(arena.encounter.phase_config["cub_charm_seconds" if phase==1 else "charm_seconds"])
	heart.position=arena.player.position;heart.speed=0.0
	a.add_child(heart);a.projectiles.append(heart);heart.set_process(false)
	heart._process(1.0/60.0)
	return heart
func step(count: int) -> void:
	for i in count:
		await physics_frame
		arena._physics_process(1.0/60.0)
func reset_fight() -> void:
	arena.encounter.start_encounter()
	arena.encounter.set_process(false);arena.attacks.set_process(false)
	arena.spirit_combat.set_process(false);arena.set_physics_process(false)
	arena.presentation.set_process(false)
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;reset_fight()
	var a=arena.attacks;var e=arena.encounter;var s=arena.spirit_combat
	check(is_equal_approx(float(e.phase_config["cub_charm_seconds"]),1.2),"P1 charm duration is configured as 1.2 seconds")
	arena.player.position=Vector3(-1,0,4);arena.forms.get_child(0).position=Vector3(5,0,0)
	check(s.use_skill(3),"A real heavy attack can begin before the charm arrives")
	var cooldown: float=s.cooldowns[3];var hits: int=s.hit_count
	var heart=heart_at_player(1)
	check(heart.resolved and is_equal_approx(arena.charm_remaining,1.2),"Actual unshielded heart contact starts 1.2-second control loss")
	check(e.player_health==e.player_max_health and is_equal_approx(a.vision_remaining,1.2),"Charm adds a matching short veil and no direct HP damage")
	check(s.active_skill.is_empty() and is_equal_approx(s.cooldowns[3],cooldown),"Charm cancels the pending attack and preserves its cooldown")
	s.update_melee(1.0)
	check(s.hit_count==hits,"Interrupted weapon contact cannot land later")
	check(arena.player_avatar.priority==0,"Canceled weapon pose releases to the real movement gait")
	check(s.skill_snapshot()["blocked"],"Skill HUD reports the charm input lock")
	var blocked:=true
	for i in 4:blocked=blocked and not s.use_skill(i)
	check(blocked,"All four player skills are blocked during forced approach")
	Input.action_press("MoveLeft");Input.action_press("Dash")
	var before: Vector3=arena.player.position
	var toward: Vector3=(arena.boss_position()-before).normalized()
	await step(1)
	var move: Vector3=arena.player.position-before
	check(move.length()>.02 and move.normalized().dot(toward)>.98,"Real CharacterBody movement approaches the off-center fox despite opposite input")
	check(is_equal_approx(move.length()*60.0,1.7),"Forced walk uses the restrained 1.7 m/s speed")
	check(arena.dash_remaining==0 and arena.dash_cooldown==0,"Dash input cannot interrupt or consume cooldown during charm")
	Input.action_release("Dash");Input.action_release("MoveLeft")
	arena.forms.get_child(0).position=Vector3(-5,0,0)
	before=arena.player.position;toward=(arena.boss_position()-before).normalized()
	await step(1);move=arena.player.position-before
	check(move.length()>.02 and move.normalized().dot(toward)>.98,"Approach retargets the fox's new live position rather than the arena origin")
	await step(68)
	check(arena.charm_remaining>0 and arena.charm_remaining<.04,"Control loss is still active just before the short timer ends")
	await step(4)
	check(arena.charm_remaining==0,"Control automatically returns within 1.24 seconds")
	a.update_vision(1.3)
	check(a.vision_remaining==0 and not a.vision_rect.visible,"The juvenile veil also clears automatically")
	check(not s.skill_snapshot()["blocked"],"Skill HUD unlocks after charm ends")
	Input.action_press("MoveRight");before=arena.player.position
	var right: Vector3=arena.camera.global_basis.x;right.y=0;right=right.normalized()
	await step(1);move=arena.player.position-before
	check(move.length()>.06 and move.normalized().dot(right)>.98,"Manual movement resumes at normal speed")
	Input.action_press("Dash");await step(1)
	check(arena.dash_remaining>0 and arena.dash_cooldown>0,"Dash becomes usable again after expiry")
	Input.action_release("Dash");Input.action_release("MoveRight")
	arena.dash_remaining=0;arena.player_avatar.reset_avatar()
	check(s.use_skill(0),"Player attacks become usable again after expiry")
	reset_fight();arena.forms.get_child(0).position=Vector3(3,0,2)
	arena.player.position=Vector3(3.5,0,2);heart_at_player(1);before=arena.player.position
	await step(3)
	check(arena.player.position.is_equal_approx(before),"Approach stops near the fox instead of jittering through its center")
	reset_fight()
	check(s.use_skill(2),"Ward starts through the real player skill route")
	s.update_melee(float(s.skills[2]["contact"])+.001)
	check(s.ward_remaining>2.9 and is_instance_valid(s.ward_surface),"Ward protects only after its actual contact/activation frame")
	var ward_left: float=s.ward_remaining;var charm_hits: int=a.charm_hits
	heart=heart_at_player(1)
	check(heart.resolved and heart.is_queued_for_deletion(),"Ward consumes the contacting homing heart")
	check(arena.charm_remaining==0 and a.vision_remaining==0 and a.charm_hits==charm_hits,"Ward prevents control loss, veil and charm-hit registration")
	check(is_equal_approx(s.ward_remaining,ward_left) and e.player_health==e.player_max_health,"Blocking a heart preserves the ward's remaining duration and HP")
	reset_fight();check(s.use_skill(2),"Ward windup begins for the pre-activation case")
	heart_at_player(1)
	check(arena.charm_remaining>0 and s.ward_remaining==0 and s.active_skill.is_empty(),"Casting without an active shield does not provide premature charm immunity")
	reset_fight();s.ward_remaining=.01;s._process(.02);heart_at_player(1)
	check(arena.charm_remaining>0,"An expired shield no longer blocks a heart")
	reset_fight();arena.dash_remaining=.2;heart=heart_at_player(1)
	check(heart.resolved and arena.charm_remaining==0 and a.charm_hits==0,"Existing dash immunity still consumes a heart without charm")
	reset_fight();heart_at_player(1);arena.set_phase(2)
	check(arena.charm_remaining==0 and a.vision_remaining==0,"Phase changes clear the movement lock and veil")
	reset_fight();heart_at_player(1);e.start_encounter()
	check(arena.charm_remaining==0 and a.vision_remaining==0,"Restart clears charm immediately")
	reset_fight();heart_at_player(1);e.stop_to_preview()
	check(arena.charm_remaining==0 and a.vision_remaining==0,"Returning to preview clears charm immediately")
	reset_fight();heart_at_player(1);e.state=e.State.DEFEAT;await step(1)
	check(arena.charm_remaining==0 and arena.player.velocity.is_zero_approx(),"Defeat cannot leave a compelled player moving")
	reset_fight();arena.set_phase(3);s.ward_remaining=1.0
	heart=heart_at_player(3)
	check(heart.resolved and a.vision_remaining==0 and not is_instance_valid(a.beacon),"Ward also cancels a P3 heart before its veil or cleansing pickup spawns")
	s.ward_remaining=0;heart_at_player(3)
	check(is_equal_approx(a.vision_remaining,float(e.phase_config["charm_seconds"])) and arena.charm_remaining==0 and is_instance_valid(a.beacon),"Unshielded P3 retains its separate vision-and-cleansing mechanic")
	print("CHARM_APPROACH ",checks," checks; passed=",not failed)
	var report:=FileAccess.open("res://artifacts/qingqiu/charm_approach/checks.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"passed":not failed,"audio_driver":"Dummy","real_character_body_movement":true,"human_playthrough":false},"\t"));report.close()
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	await create_timer(.08).timeout
	quit(int(failed))
