extends SceneTree
var failed:=false
var checks:=0
var arena
var e
var a
var p
func _initialize() -> void:run.call_deferred()
func frames(n: int) -> void:
	for i in n:await process_frame
func check(ok: bool,text: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+text)
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed;await frames(4)
	arena=current_scene;e=arena.encounter;a=arena.attacks;p=arena.presentation
	e.start_encounter();arena.set_physics_process(false);a.set_process(false);p.set_process(false);e.set_process(false)
	arena.spirit_combat.set_process(false)
	var orb=e.hud.player_bar
	check(orb.orbit_back.get_index()<orb.surface.get_index() and orb.orbit_clouds.get_index()>orb.surface.get_index(),"Orb clouds draw behind and in front of the health surface")
	check(orb.orbit_back.material.get_shader_parameter("orbit_pass")==0 and orb.orbit_clouds.material.get_shader_parameter("orbit_pass")==1,"Two synchronized orbit passes create real front/back occlusion")
	check(orb.orbit_clouds.offset_left<0 and orb.orbit_clouds.offset_right>0,"Orb clouds have extra outer space instead of being cut at the blood edge")
	orb.set_health(37,100)
	check(orb.bar_material.get_shader_parameter("health_ratio")==.37 and orb.motes.visible,"Cloud layout leaves true liquid fill and upward health motes intact")
	check(orb.orbit_back.mouse_filter==Control.MOUSE_FILTER_IGNORE and orb.orbit_clouds.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Cloud orbit cannot block game input")
	arena.set_phase(2)
	for name in ["p2_claw_gale","p2_tail_crescent","p2_fox_roar"]:
		a.reset();arena.player.position=Vector3(0,0,15);e.player_hit_grace=0;e.player_health=100
		a.begin_attack(name)
		check(a.rig().action_player.current==name+"_windup" and is_instance_valid(a.attack_seal),name+" uses actual body anticipation and a floating seal")
		check(a.telegraph==null,name+" has no floor range mesh")
		var locked: Vector3=a.direction
		arena.player.position=Vector3(12,0,9)
		a._process(a.windup-.01)
		check(a.projectiles.is_empty(),name+" cannot deal early projectile damage during windup")
		a._process(.02)
		var expected:=5 if name=="p2_claw_gale" else 1
		check(a.projectiles.size()==expected and a.direction==locked,name+" releases its locked facing without tracking a last-second sidestep")
		check(a.projectiles[0].get_script()==load("res://Scripts/Qingqiu/fox_adult_wave.gd"),name+" launches a visible directional attack wave")
		var wave=a.projectiles[0];wave.set_process(false)
		if name=="p2_fox_roar":
			check(wave.speed*wave.lifetime>=55.0 and wave.growth>0,"Fox roar can cross the map and grows to a wide distant strike")
		if name=="p2_tail_crescent":check(wave.width>=7.0,"Double-tail crescent covers a large front without an invisible all-map hit")
	a.reset();arena.player.position=Vector3(19,0,0);a.source=Vector3(-18,0,0)
	var shot=a.spawn_adult_wave(Vector3.RIGHT,12.5,1.25,2.0,2,16,4.8);shot.set_process(false)
	e.player_health=100;e.player_hit_grace=0
	shot._process(3.0)
	check(e.player_health==84,"A distant roar crossing the player in one update deals real swept damage")
	a.reset();var phases: Array[String]=[]
	for index in 6:
		a.sequence=index;a.vanish_casts=0;a.mode="idle";a.cooldown=0;arena.player.position=Vector3(0,0,9);a._process(.01)
		phases.append(a.attack)
	check(phases==["p2_claw_gale","barrage_fan","p2_tail_crescent","barrage_weave","p2_fox_roar","barrage_ring"],"P2 live rotation includes all three new normals and all three old barrages")
	a.reset();a.vanish_casts=2;a.cooldown=0;a._process(.01)
	check(a.mode=="vanish","The expanded rotation retains two-cast P2 invisibility")
	a.reset();arena.player.position=Vector3(0,0,10);a.roam_target=Vector3(15,0,-13);a.roam_remaining=5
	var before: Vector3=arena.boss_position()
	a.move_between_attacks(.6)
	check(arena.boss_position().distance_to(before)>1.0,"Adult fox actually roams through the arena between attacks")
	check(absf(arena.boss_position().x)<=18.9 and absf(arena.boss_position().z)<=18.9,"Roaming respects square field bounds and scenery movement")
	a.reset();a.begin_attack("barrage_fan")
	check(not a.telegraph.visible,"P2's former triangular warning remains hidden")
	a._process(1.2)
	check(not a.projectiles[0].ground_scope.visible and not a.projectiles[0].flame.get_node("GroundSpill").visible,"Ghost fire has no danger-circle/shadow overlay after the icon-only correction")
	a.reset();a.begin_attack("barrage_ring");a._process(1.2)
	var front_only:=true
	for bullet in a.projectiles:front_only=front_only and bullet.direction.dot(a.direction)>0
	check(front_only,"P2's arc barrage also fires in the locked facing rather than behind the fox")
	arena.set_phase(3);a.set_process(false);arena.forms.get_child(2).position=Vector3(12,0,9);arena.player.position=Vector3(-12,0,10)
	a.sequence=4;a.cooldown=0;a._process(.01)
	check(a.attack=="p3_spiral" and a.rig().action_player.current=="p3_center_windup","P3 schedules its center special after four normal skill casts")
	check(a.telegraph==null and is_instance_valid(a.attack_seal),"P3 special is announced by body and floating seal")
	var hp: float=e.boss_health;var commits: int=p.commit_count
	a._process(1.0)
	check(a.mode=="center_jump" and p.orbit_intro_active and p.is_busy(),"Special release starts a separate short jump staging")
	check(not e.damage_player(12),"No leftover hazard can hurt a player during the locked jump staging")
	a._process(.5);p._process(.5)
	check(a.fox_height>3.0 and arena.boss_position().length()<12.0 and arena.boss_position().length()>1.0,"The fox physically arcs from its current place toward center")
	a._process(.86);p._process(.86)
	check(arena.boss_position().length()<.001 and a.fox_height==0 and a.mode=="spiral_charge","The jump lands exactly at map center before firing")
	check(not p.is_busy() and e.boss_health==hp and p.commit_count==commits and arena.phase==3,"Intra-phase staging restores control without a phase commit or HP reset")
	check(a.projectiles.is_empty(),"Post-landing charge gives a readable reaction beat")
	a._process(.61)
	check(a.spiral_round==1 and a.projectiles.size()==16,"The first spiral round has eighteen sectors with a two-sector gap")
	var orb_bullet=a.projectiles[0];orb_bullet.set_process(false)
	check(orb_bullet.orbiting and orb_bullet.filled_fire and orb_bullet.angular_speed<0,"P3 uses filled white/gold fire moving clockwise on expanding orbits")
	orb_bullet.flame._process(.01)
	check(is_equal_approx(orb_bullet.flame.surface.global_basis.get_scale().x,.15),"Spiral fire respects its small projectile scale")
	var angle_before:=atan2(orb_bullet.position.x,orb_bullet.position.z)
	orb_bullet._process(.1)
	var angle_after:=atan2(orb_bullet.position.x,orb_bullet.position.z)
	check(angle_after<angle_before and orb_bullet.position.length()>1.6,"Actual projectile position rotates clockwise and expands outward")
	a._process(.69);check(a.spiral_round==1,"Consecutive rounds obey their cadence")
	a._process(.02);check(a.spiral_round==2,"Second round releases after 0.70 s")
	a._process(4.3)
	check(a.spiral_round==8 and a.spiral_log.size()==8,"Large frame steps still release exactly eight rounds")
	var count:=0;var clockwise:=true
	for index in a.spiral_log.size():
		count+=int(a.spiral_log[index]["bullets"])
		if index>0:clockwise=clockwise and float(a.spiral_log[index]["angle"])<float(a.spiral_log[index-1]["angle"])
	check(count==128 and clockwise,"Eight rounds produce 128 flames with clockwise wave offsets")
	a._process(1.0);check(a.mode=="recover" and a.rig().action_player.current=="","Spiral loop stops into recovery instead of leaving a stuck cast")
	var hazard=e.spawn_hazard(Vector3(8,0,8),1.15,1,.8,12,4)
	check(not hazard.get_child(0).visible,"Map fire warnings also omit the old ground range")
	a.reset();a.begin_attack("p3_spiral");a._process(1.0);a._process(.3)
	e.start_encounter()
	check(not p.orbit_intro_active and not p.orbit_rect.visible and a.projectiles.is_empty() and a.fox_height==0,"Restart mid-jump clears cinema, flight height and all attack waves")
	check(Engine.time_scale==1,"Hardcore changes do not alter global simulation speed")
	print("HARDCORE_EXPANSION %d checks; passed=%s"%[checks,not failed])
	arena.queue_free();current_scene=null;await frames(4);quit(int(failed))
