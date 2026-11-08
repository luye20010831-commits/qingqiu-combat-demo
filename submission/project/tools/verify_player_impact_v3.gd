extends SceneTree
var checks:=0
var failures:=0
var arena
var e
var m
var avatar
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func reset_case(distance:=2.0) -> void:
	m.clear_transients()
	avatar.reset_avatar()
	arena.player.position=Vector3(0,0,distance)
	arena.dash_remaining=0
	arena.charm_remaining=0
	arena.presentation.trauma=0
	e.player_hit_grace=0
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	arena=current_scene;e=arena.encounter;m=arena.spirit_combat;avatar=arena.player_avatar
	e.start_encounter()
	arena.attacks.set_process(false)
	arena.set_physics_process(false)
	m.set_process(false);avatar.set_process(false);e.set_process(false)
	check(m.skills.size()==4 and m.skills[3].id=="heavy","heavy is an additional fourth skill")
	check(m.arc_texture!=null and m.impact_texture!=null,"both generated transparent VFX textures load")
	reset_case()
	var hp: float=e.boss_health
	var trails: int=m.trail_events
	var impacts: int=m.impact_events
	var rig=arena.attacks.rig()
	var original_rig_position: Vector3=rig.position
	var original_boss_position: Vector3=arena.boss_position()
	check(m.use_skill(0) and avatar.puppet.current=="light_slash","normal input selects the large swing")
	m._process(.08)
	check(m.trail_events==trails and e.boss_health==hp,"normal preparation has no early trail or damage")
	m._process(.02)
	check(m.trail_events==trails+1 and e.boss_health==hp,"weapon trail starts during release before contact")
	m._process(.05)
	check(e.boss_health==hp-10 and m.impact_events==impacts+1,"normal contact applies damage and exactly one impact burst")
	check(avatar.impact_pause>0 and arena.attacks.rig().strike_pause>0,"confirmed normal hit holds both visual poses")
	check(rig.weapon_recoil_offset.length()>.049 and arena.boss_position()==original_boss_position,"normal hit recoils only the visible fox, not its attack/collision origin")
	rig._process(.25)
	check(rig.weapon_recoil_offset==Vector3.ZERO and rig.position.distance_to(original_rig_position)<.0001,"visual recoil settles back without transform drift")
	check(arena.presentation.trauma>0 and Engine.time_scale==1,"normal hit shakes camera without freezing simulation")
	var normal_pause: float=avatar.impact_pause
	var clip_time: float=avatar.puppet.elapsed
	avatar._process(.01)
	check(is_equal_approx(avatar.puppet.elapsed,clip_time),"local impact pause holds the rendered weapon pose")
	avatar._process(.04)
	check(avatar.puppet.elapsed>clip_time and avatar.impact_pause==0,"local pause releases and animation resumes")
	m._process(.10)
	check(e.boss_health==hp-10 and m.impact_events==impacts+1,"one contact cannot repeat damage or impact feedback")
	reset_case(7.0);hp=e.boss_health;impacts=m.impact_events;trails=m.trail_events
	m.use_skill(0);m._process(.2)
	check(e.boss_health==hp and m.trail_events==trails+1,"an out-of-range attack still shows a weapon swing")
	check(m.impact_events==impacts and avatar.impact_pause==0 and arena.presentation.trauma==0,"a miss has no false contact spark, stop or shake")
	reset_case(2.9);hp=e.boss_health;impacts=m.impact_events
	check(m.use_skill(3) and avatar.puppet.current=="heavy_strike","heavy input selects its distinct overhead clip")
	m._process(.41)
	check(e.boss_health==hp and m.impact_events==impacts,"heavy anticipation gives no early damage")
	m._process(.10)
	check(e.boss_health==hp and m.active_skill.trailed,"heavy slash is visible before the hit frame")
	m._process(.02)
	check(e.boss_health==hp-42 and m.last_impact_skill=="heavy","heavy makes one 42-damage contact at 0.52 seconds")
	check(avatar.impact_pause>normal_pause and arena.attacks.rig().strike_pause>=.099,"heavy has a stronger local impact hold")
	check(arena.attacks.rig().weapon_recoil_offset.length()>.129,"heavy produces a larger visible recoil")
	check(arena.presentation.trauma>=.57,"heavy has a stronger camera impulse")
	check(m.cooldowns[3]>1.6 and not m.use_skill(3),"heavy recovery/cooldown prevents immediate repeat")
	m._process(.2)
	check(e.boss_health==hp-42,"heavy cannot multi-hit during the active window")
	reset_case();hp=e.boss_health
	m.use_skill(3);arena.dash_remaining=.1;m._process(.55)
	check(e.boss_health==hp and m.active_skill.is_empty() and m.cooldowns[3]>0,"dodge interrupts heavy before contact and retains cooldown")
	reset_case();hp=e.boss_health
	m.use_skill(3);avatar.notify_hit();m._process(.55)
	check(e.boss_health==hp and m.active_skill.is_empty(),"taking damage interrupts an unfinished heavy")
	reset_case()
	var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_4
	arena._unhandled_key_input(key)
	check(int(m.active_skill.get("index",-1))==3,"key 4 invokes the real heavy action")
	reset_case()
	var mouse:=InputEventMouseButton.new();mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_RIGHT
	m._unhandled_input(mouse)
	check(int(m.active_skill.get("index",-1))==3,"right mouse invokes the heavy action through its input handler")
	reset_case();m.publish_skills(true)
	var bar=e.hud.skill_bar
	check(bar.buttons.size()==4 and bar.icons[3].texture!=null,"fourth HUD button has its own loaded icon")
	bar.buttons[3].pressed.emit()
	check(int(m.active_skill.get("index",-1))==3 and bar.buttons[3].disabled,"heavy HUD button invokes the skill and reads its cooldown")
	check(bar.masks[3].size.y>70 and bar.counters[3].text=="3","heavy cooldown mask and countdown are real state")
	e.start_encounter()
	check(m.effects.is_empty() and m.active_skill.is_empty() and avatar.impact_pause==0 and m.cooldowns[3]==0 and arena.attacks.rig().weapon_recoil_offset==Vector3.ZERO,"restart clears VFX, action, impact hold, recoil and heavy cooldown")
	check(Engine.time_scale==1,"all feedback preserves the global simulation clock")
	rig=avatar.puppet
	for entry in [["light_slash",130.0],["spear_sweep",145.0],["heavy_strike",170.0]]:
		rig.snap_to(entry[0])
		var lo:=INF;var hi:=-INF
		for frame in 241:
			rig.seek(float(rig.info[entry[0]].duration)*frame/240.0)
			var angle: float=rig.bones.weapon.global_rotation_degrees
			lo=minf(lo,angle);hi=maxf(hi,angle)
		check(hi-lo>=float(entry[1]),"%s weapon arc is visibly large: %.1f degrees"%[entry[0],hi-lo])
	DirAccess.make_dir_recursive_absolute("res://artifacts/qingqiu/hunter_melee_v3")
	var file:=FileAccess.open("res://artifacts/qingqiu/hunter_melee_v3/impact_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"failures":failures,"scripted":true,"human_playthrough":false}))
	file.close()
	print("PLAYER IMPACT V3: %d checks, %d failures"%[checks,failures])
	arena.queue_free();current_scene=null
	for frame in 4:await process_frame
	quit(1 if failures else 0)
