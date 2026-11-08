extends Node3D
## Body/seal cues without floor ranges: P1 animals, P2 roaming normals/barrages,
## P3 vision charm plus a staged center jump and eight clockwise spiral waves.
@onready var arena=get_parent()
var mode:="idle"
var attack:=""
var label:=""
var age:=0.0
var cooldown:=2.8
var windup:=1.0
var sequence:=0
var fox_height:=0.0
var source:=Vector3.ZERO
var locked:=Vector3.ZERO
var direction:=Vector3.FORWARD
var telegraph
var projectiles: Array[Node3D]=[]
var delayed_shots:=0
var vision_remaining:=0.0
var vision_amount:=0.0
var vision_strength:=1.0
var vision_layer: CanvasLayer
var vision_rect: ColorRect
var vision_material: ShaderMaterial
var beacon: Node3D
var beacon_orb: MeshInstance3D
var clock:=0.0
var casts:=0
var bullets_fired:=0
var animal_hits:=0
var charm_hits:=0
var cleanses:=0
var ground_probe:=SphereShape3D.new()
var cub_hop_active:=false
var cub_hop_landed:=false
var cub_hop_source:=Vector3.ZERO
var cub_hop_target:=Vector3.ZERO
var strike_applied:=false
var vanish_age:=0.0
var vanish_alpha:=1.0
var vanish_casts:=0
var barrage_waves_fired:=0
var cub_charm_effect: Node3D
var attack_seal: Node3D
var roam_target:=Vector3.ZERO
var roam_remaining:=0.0
var roam_velocity:=Vector3.ZERO
var roam_random:=RandomNumberGenerator.new()
var spiral_round:=0
var spiral_log: Array[Dictionary]=[]
var normal_cast_log: Array[String]=[]
var p2_casts_since_inferno:=0
var inferno

func _ready() -> void:
	roam_random.seed=7391
	vision_layer=CanvasLayer.new()
	vision_layer.layer=6
	add_child(vision_layer)
	vision_rect=ColorRect.new()
	vision_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vision_layer.add_child(vision_rect)
	vision_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vision_material=ShaderMaterial.new()
	vision_material.shader=preload("res://Shaders/Qingqiu/charm_vision.gdshader")
	vision_rect.material=vision_material
	vision_rect.visible=false

func rig():
	return arena.forms.get_child(arena.phase-1).get_node("FoxRig")

func reset(clear_statistics:=false) -> void:
	if arena.presentation!=null:arena.presentation.cancel_orbit_intro()
	arena.charm_remaining=0.0
	roam_remaining=0.0
	roam_velocity=Vector3.ZERO
	spiral_round=0
	p2_casts_since_inferno=0
	inferno=null
	if is_instance_valid(attack_seal):attack_seal.cancel()
	attack_seal=null
	for child in get_children():
		if child is Node3D:child.queue_free()
	for projectile in projectiles:
		if is_instance_valid(projectile):projectile.queue_free()
	projectiles.clear()
	if is_instance_valid(telegraph):telegraph.queue_free()
	telegraph=null
	if is_instance_valid(beacon):beacon.queue_free()
	beacon=null
	vision_remaining=0.0
	vision_amount=0.0
	vision_strength=1.0
	cub_charm_effect=null
	strike_applied=false
	if vision_rect!=null:vision_rect.visible=false
	set_boss_opacity(1.0)
	vanish_age=0.0
	vanish_casts=0
	fox_height=0.0
	cub_hop_active=false
	cub_hop_landed=false
	mode="idle"
	attack=""
	label=""
	age=0.0
	sequence=0
	cooldown=2.8
	if arena.encounter!=null:cooldown=float(arena.encounter.phase_config.get("opening_grace_seconds",2.8))
	for form in arena.forms.get_children():
		form.position.x=0.0
		form.position.z=0.0
		var puppet=form.get_node("FoxRig")
		puppet.reset_locomotion()
		puppet.set_charm_charge(0.0)
	if clear_statistics:
		casts=0
		bullets_fired=0
		animal_hits=0
		charm_hits=0
		cleanses=0
		spiral_log.clear()
		normal_cast_log.clear()

func _process(delta: float) -> void:
	var form: Node3D=arena.forms.get_child(arena.phase-1)
	var before:=form.position
	update_attacks(delta)
	var movement:=form.position-before
	rig().set_locomotion(movement/maxf(delta,0.0001))

func ground_clear(point: Vector3) -> bool:
	ground_probe.radius=0.40 if arena.phase==1 else 0.60
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=ground_probe
	query.transform=Transform3D(Basis.IDENTITY,Vector3(point.x,0.85,point.z))
	query.collision_mask=1
	query.exclude=[arena.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func move_ground(step: Vector3) -> void:
	var form: Node3D=arena.forms.get_child(arena.phase-1)
	var steps:=maxi(1,ceili(step.length()/0.25))
	for index in steps:
		var target:=form.position+Vector3(step.x,0,step.z)/float(steps)
		target.x=clampf(target.x,-18.9,18.9)
		target.z=clampf(target.z,-18.9,18.9)
		if ground_clear(target):form.position=target
		elif ground_clear(Vector3(target.x,form.position.y,form.position.z)):form.position.x=target.x
		elif ground_clear(Vector3(form.position.x,form.position.y,target.z)):form.position.z=target.z

func move_between_attacks(delta: float) -> void:
	if arena.phase==1 and cub_hop_active:
		var action=rig().action_player
		var hop: Dictionary=action.library["cub_hop"]
		var progress:=smoothstep(float(hop["travel_start"]),float(hop["travel_end"]),action.elapsed)
		var target:=cub_hop_source.lerp(cub_hop_target,progress)
		move_ground(target-arena.boss_position())
		if not cub_hop_landed and action.elapsed>=float(hop["travel_end"]):
			cub_hop_landed=true;arena.fox_motion_fx.landing(arena.boss_position(),1)
		if action.current!="cub_hop":cub_hop_active=false
		return
	var offset: Vector3=arena.player.position-arena.boss_position()
	offset.y=0.0
	var distance:=offset.length()
	if distance<0.01:return
	var heading:=offset/distance
	var profile: Dictionary=arena.encounter.phase_config
	if arena.phase==1:
		if distance>2.3:
			cub_hop_source=arena.boss_position()
			cub_hop_target=cub_hop_source+heading*minf(distance-2.3,float(profile.get("hop_distance",1.55)))
			rig().face_velocity(heading)
			rig().play_action("cub_hop")
			cub_hop_active=true
			cub_hop_landed=false
		return
	if bool(profile.get("roam_enabled",true)):
		roam_remaining-=delta
		if roam_remaining<=0.0 or arena.boss_position().distance_to(roam_target)<1.5:
			choose_roam_target()
		var heading_to: Vector3=roam_target-arena.boss_position();heading_to.y=0.0
		var velocity:=heading_to.normalized()*float(profile.get("roam_speed",2.4))
		if distance<3.2:velocity=(velocity-heading*1.4).normalized()*float(profile.get("roam_speed",2.4))
		if arena.phase==3:
			roam_velocity=roam_velocity.lerp(velocity,1.0-exp(-6.0*delta))
			velocity=roam_velocity
		move_ground(velocity*delta)
		return

func choose_roam_target() -> void:
	var profile: Dictionary=arena.encounter.phase_config
	var radius:=float(profile.get("roam_radius",17.5))
	for attempt in 18:
		var point:=Vector3(roam_random.randf_range(-radius,radius),0,roam_random.randf_range(-radius,radius))
		if point.distance_to(arena.boss_position())>7.0 and ground_clear(point):
			roam_target=point;break
	roam_remaining=float(profile.get("roam_target_seconds",5.0))

func update_attacks(delta: float) -> void:
	clock+=delta
	update_vision(delta)
	for i in range(projectiles.size()-1,-1,-1):
		if not is_instance_valid(projectiles[i]):projectiles.remove_at(i)
	if arena.encounter==null or arena.encounter.state!=arena.encounter.State.RUNNING:return
	if mode=="center_jump":
		age+=delta
		update_center_jump()
		return
	if arena.presentation.is_busy():return
	if mode=="inferno_channel":
		if not is_instance_valid(inferno) or inferno.finished:
			if is_instance_valid(inferno):inferno.queue_free()
			inferno=null;finish_attack(float(arena.encounter.phase_config.get("inferno_recovery_seconds",.55)))
		return
	if mode=="vanish":
		update_vanish(delta)
		return
	age+=delta
	if mode=="spiral_charge":
		if is_instance_valid(attack_seal):attack_seal.charge=minf(age/.60,1.0)
		if age>=.60:
			mode="spiral_active";age=0.0;emit_spiral_round()
		return
	if mode=="spiral_active":
		var rounds:=int(arena.encounter.phase_config.get("spiral_rounds",8))
		var interval:=float(arena.encounter.phase_config.get("spiral_interval",.7))
		while spiral_round<rounds and age>=float(spiral_round)*interval:emit_spiral_round()
		if age>=float(rounds-1)*interval+1.0:finish_attack(float(arena.encounter.phase_config.get("spiral_recovery_seconds",1.0)))
		return
	if mode=="idle":
		cooldown-=delta
		move_between_attacks(delta)
		if cooldown<=0.0 and not cub_hop_active:
			sequence+=1
			if arena.phase==1:
				var distance: float=arena.boss_position().distance_to(arena.player.position)
				var profile: Dictionary=arena.encounter.phase_config
				if bool(profile.get("cub_charm_enabled",true)) and sequence%int(profile.get("cub_charm_every_attacks",4))==0 and distance<=float(profile.get("cub_charm_range",7.0)) and not has_cub_charm_heart():
					begin_attack("cub_charm")
				else:
					var physical_index:=int((sequence-1)/2)%3
					if distance<3.2 and bool(profile.get("tail_sweep_enabled",true)) and physical_index==1:begin_attack("cub_tail_sweep")
					else:begin_attack("cub_charge" if physical_index==0 else ("cub_swipe" if distance<3.2 else "cub_feint"))
			elif arena.phase==2:
				var every:=int(arena.encounter.phase_config.get("vanish_every_casts",2))
				if vanish_casts>=every:
					sequence-=1
					begin_vanish()
				elif p2_casts_since_inferno>=int(arena.encounter.phase_config.get("inferno_every_attacks",3)):
					sequence-=1;begin_attack("inferno_rain")
				else:begin_attack(["p2_claw_gale","barrage_fan","p2_tail_crescent","barrage_weave","p2_fox_roar","barrage_ring"][(sequence-1)%6])
			else:
				begin_attack("p3_spiral" if sequence%int(arena.encounter.phase_config.get("spiral_every_casts",5))==0 else "vision_charm")
	elif mode=="windup":
		if is_instance_valid(telegraph):telegraph.charge=minf(age/windup,1.0)
		if is_instance_valid(attack_seal):attack_seal.charge=smoothstep(0.0,1.0,minf(age/windup,1.0))
		if attack=="vision_charm":rig().set_charm_charge(minf(age/windup,1.0))
		if attack=="cub_charm":
			var progress:=smoothstep(0.0,1.0,minf(age/windup,1.0))
			rig().set_charm_charge(progress)
			if is_instance_valid(cub_charm_effect):cub_charm_effect.charge=progress
		if age>=windup:resolve_attack()
	elif mode=="active":
		if attack=="cub_swipe":
			if not strike_applied and age>=float(arena.encounter.phase_config.get("swipe_strike_seconds",0.12)):
				strike_applied=true
				if is_instance_valid(telegraph):
					telegraph.active=true
					var hit: bool=telegraph.contains(arena.player.position,0.15) and arena.encounter.damage_player(float(arena.encounter.phase_config["swipe_damage"]))
					melee_contact(source+direction*1.2,0.0,hit)
			if age>=0.55:finish_attack(0.25)
		elif attack=="cub_tail_sweep":
			update_tail_sweep(delta)
			if age>=0.72:finish_attack(0.35)
		elif attack=="cub_charge":
			var t:=minf(age/float(arena.encounter.phase_config.get("charge_travel_seconds",0.28)),1.0)
			var before: Vector3=arena.boss_position()
			var point:=source.lerp(locked,1.0-pow(1.0-t,2.0))
			move_ground(point-before)
			fox_height=0.0
			var after: Vector3=arena.boss_position()
			var nearest:=Geometry2D.get_closest_point_to_segment(Vector2(arena.player.position.x,arena.player.position.z),Vector2(before.x,before.z),Vector2(after.x,after.z))
			if not strike_applied and nearest.distance_to(Vector2(arena.player.position.x,arena.player.position.z))<=0.92:
				strike_applied=true
				var hit: bool=arena.encounter.damage_player(float(arena.encounter.phase_config.get("charge_damage",10.0)))
				melee_contact(after+direction*0.4,1.0,hit)
				if hit:finish_attack(0.68)
			if mode=="active" and t>=1.0:finish_attack(0.68)
		elif attack=="cub_feint":
			var t:=minf(age/0.45,1.0)
			var point:=source.lerp(locked,t)
			var form: Node3D=arena.forms.get_child(0)
			form.position.x=point.x
			form.position.z=point.z
			fox_height=sin(t*PI)*0.22
			if t>=1.0:
				arena.fox_motion_fx.landing(arena.boss_position(),1)
				finish_attack(0.35)
		elif attack.begins_with("barrage"):
			var interval:=float(arena.encounter.phase_config.get("barrage_wave_interval",0.4))
			var waves:=int(arena.encounter.phase_config.get("barrage_waves",3))
			while delayed_shots<waves-1 and age>=interval*float(delayed_shots+1):
				delayed_shots+=1
				emit_barrage_wave()
			if age>=interval*float(waves-1)+0.45:finish_attack(0.6)
		elif attack.begins_with("p2_"):
			if age>=.85:finish_attack(.55)
		elif attack=="cub_charm":
			if age>=0.65:finish_attack(0.45)
		else:finish_attack(0.6)
	elif mode=="recover" and age>=cooldown:
		mode="idle"
		cooldown=next_cooldown()
		age=0.0
		label=""
		arena.encounter.publish()

func update_tail_sweep(delta: float) -> void:
	if strike_applied:return
	var profile: Dictionary=arena.encounter.phase_config
	var start:=float(profile.get("tail_sweep_start_seconds",0.08))
	var travel:=float(profile.get("tail_sweep_travel_seconds",0.24))
	if age<start or age-delta>start+travel:return
	var before:=clampf((age-delta-start)/travel,0.0,1.0)
	var after:=clampf((age-start)/travel,0.0,1.0)
	var radius:=float(profile.get("tail_sweep_radius",2.0))
	var width:=float(profile.get("tail_sweep_hit_radius",0.65))
	var slices:=maxi(1,ceili((after-before)*30.0))
	var first:=source+direction.rotated(Vector3.UP,lerpf(-1.45,1.45,before))*radius
	var player:=Vector2(arena.player.position.x,arena.player.position.z)
	for index in slices:
		var t:=lerpf(before,after,float(index+1)/float(slices))
		var point:=source+direction.rotated(Vector3.UP,lerpf(-1.45,1.45,t))*radius
		var nearest:=Geometry2D.get_closest_point_to_segment(player,Vector2(first.x,first.z),Vector2(point.x,point.z))
		if nearest.distance_to(player)<=width:
			var ray:=PhysicsRayQueryParameters3D.create(source+Vector3.UP*.7,arena.player.position+Vector3.UP*.7,1,[arena.player.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				var hit: bool=arena.encounter.damage_player(float(profile.get("tail_sweep_damage",14.0)))
				if hit:
					strike_applied=true
					melee_contact(arena.player.position,1.0,true)
					var push: Vector3=(arena.player.position-source).normalized()*.5
					push.y=0.0
					arena.player.move_and_collide(push)
					arena.player.position.x=clampf(arena.player.position.x,-19.35,19.35)
					arena.player.position.z=clampf(arena.player.position.z,-19.35,19.35)
					return
		first=point

func next_cooldown() -> float:
	var profile: Dictionary=arena.encounter.phase_config
	var progress: float=1.0-arena.encounter.boss_health/maxf(arena.encounter.boss_max_health,1.0)
	var values: Array=profile["attack_cooldowns"]
	return lerpf(float(values[0]),float(values[1]),progress)

func begin_attack(name: String) -> void:
	roam_velocity=Vector3.ZERO
	if is_instance_valid(attack_seal):attack_seal.cancel()
	attack_seal=null
	cub_charm_effect=null
	cub_hop_active=false
	strike_applied=false
	rig().set_charm_charge(0.0)
	attack=name
	mode="windup"
	age=0.0
	casts+=1
	source=arena.boss_position()
	source.y=0.0
	locked=arena.player.position
	locked.y=0.0
	locked.x=clampf(locked.x,-18.5,18.5)
	locked.z=clampf(locked.z,-18.5,18.5)
	direction=(locked-source).normalized()
	if direction.length_squared()<0.1:direction=Vector3.BACK
	rig().face_velocity(direction)
	windup=1.0
	if name=="cub_feint":
		label="幼狐佯退 · 留意它回身后的扑击"
		windup=float(arena.encounter.phase_config.get("feint_windup_seconds",0.38))
		locked=source-direction*1.3+Vector3(-direction.z,0,direction.x)*0.7
		play_cub_windup(name)
	elif name=="cub_swipe":
		label="幼狐抬爪 · 即将抓挠，向侧后方躲开"
		windup=float(arena.encounter.phase_config.get("swipe_windup_seconds",0.72))
		play_cub_windup(name)
		telegraph=create_scope(source,2.4,1,Color("#bbcdc5"),1.05)
	elif name=="cub_tail_sweep":
		label="幼狐侧身卷尾 · 即将横扫，退出近身或冲刺"
		windup=float(arena.encounter.phase_config.get("tail_sweep_windup_seconds",0.85))
		play_cub_windup(name)
		telegraph=create_scope(source,2.7,1,Color("#bbcdc5"),1.55)
	elif name=="cub_charge":
		label="幼狐压身 · 即将冲撞，侧向躲开"
		windup=float(arena.encounter.phase_config.get("charge_windup_seconds",0.78))
		var distance: float=source.distance_to(locked)
		locked=source+direction*minf(distance+0.9,7.0)
		play_cub_windup(name)
	elif name=="cub_charm":
		label="幼狐惑心 · 竖尾蓄力，爱心将持续追踪"
		windup=float(arena.encounter.phase_config.get("cub_charm_windup_seconds",1.25))
		play_cub_windup(name)
	elif name=="inferno_rain":
		label="玄焰倾天 · 连续落焰，余焰会附着灼烧"
		windup=float(arena.encounter.phase_config.get("inferno_windup_seconds",1.65))
		rig().play_action("barrage_cast",.65)
	elif name.begins_with("p2_"):
		label={"p2_claw_gale":"抬爪风刃 · 沿面向扫出五道远距爪风","p2_tail_crescent":"双尾月扫 · 留意卷尾后释放的大幅月刃","p2_fox_roar":"远距狐啸 · 头部蓄力后吐出扩张冲击波"}[name]
		var clip: Dictionary=rig().action_player.library[name+"_windup"]
		windup=float(clip["duration"])
		rig().play_action(name+"_windup")
	elif name=="p3_spiral":
		label="九尾蓄跃 · 即将归中施放顺时狐焰"
		windup=.95
		rig().play_action("p3_center_windup")
	elif name.begins_with("barrage"):
		label={"barrage_fan":"尾焰扇幕 · 连续三波","barrage_ring":"回旋花环 · 三波错位缺口","barrage_weave":"交织狐火 · 连发三轮"}[name]
		windup=1.15
		rig().play_action("barrage_cast",0.8)
		telegraph=create_scope(source,14.5 if name=="barrage_ring" else 16.7,0 if name=="barrage_ring" else 1,Color("#1685a9"),0.78)
	else:
		label="四心惑目 · 躲开爱心，光点可解除魅惑"
		windup=1.4
		rig().play_action("charm_cast",0.78)
		spawn_beacon()
	if is_instance_valid(telegraph):telegraph.rotation.y=atan2(direction.x,direction.z)
	# Detection shapes stay invisible in every phase; body/seal cues announce attacks.
	if is_instance_valid(telegraph):telegraph.visible=false
	locked.x=clampf(locked.x,-18.5,18.5)
	locked.z=clampf(locked.z,-18.5,18.5)
	attack_seal=preload("res://Scripts/Qingqiu/fox_attack_seal.gd").new()
	attack_seal.attack_name=name
	attack_seal.name="CubCharmAnticipation" if name=="cub_charm" else "AttackSeal"
	add_child(attack_seal)
	if name=="cub_charm":cub_charm_effect=attack_seal
	rig().begin_attack_tail(windup,name)
	arena.encounter.publish()

func play_cub_windup(name: String) -> void:
	var clip:=name+"_windup"
	var duration: float=rig().action_player.library[clip]["duration"]
	rig().play_action(clip,duration/maxf(windup,0.05))

func melee_contact(point: Vector3,kind: float,hit: bool) -> void:
	var effect=preload("res://Scripts/Qingqiu/fox_melee_fx.gd").new()
	effect.variant=kind
	effect.confirmed=hit
	effect.position=(arena.player.position if hit else point)+Vector3(0,0.85,0)
	add_child(effect)
	if hit:
		animal_hits+=1
		arena.combat_audio.emit_cue("boss_body_contact" if kind>0.5 else "boss_claw_contact", {"trigger": "accepted melee contact", "active_seconds": age, "active_frame_at_60fps": age*60.0})
		rig().strike_pause=0.055 if kind>0.5 else 0.045
		arena.presentation.add_trauma(0.46 if kind>0.5 else 0.30)

func resolve_attack() -> void:
	mode="active"
	age=0.0
	rig().release_attack_tail()
	if is_instance_valid(attack_seal):attack_seal.release_pulse()
	if attack=="inferno_rain":
		p2_casts_since_inferno=0;vanish_casts+=1
		mode="inferno_channel"
		inferno=preload("res://Scripts/Qingqiu/p2_inferno_rain.gd").new()
		inferno.name="InfernoRain";add_child(inferno)
		return
	if attack.begins_with("p2_"):
		rig().play_action(attack)
		vanish_casts+=1
		p2_casts_since_inferno+=1
		normal_cast_log.append(attack)
		emit_adult_normal()
	elif attack=="p3_spiral":
		for projectile in projectiles:
			if is_instance_valid(projectile):projectile.queue_free()
		projectiles.clear()
		arena.encounter.clear_hazards()
		clear_vision(false)
		label="九尾归中 · 跃落后连续八轮顺时狐焰"
		mode="center_jump"
		strike_applied=false
		rig().play_action("p3_center_jump")
		arena.presentation.begin_orbit_intro()
		return
	if attack.begins_with("cub_"):rig().play_action(attack)
	if attack=="cub_tail_sweep":
		var trace=preload("res://Scripts/Qingqiu/fox_tail_sweep_fx.gd").new()
		trace.position=source+Vector3.UP*0.30
		trace.rotation.y=atan2(direction.x,direction.z)
		add_child(trace)
	if attack=="cub_charge":
		var effect=preload("res://Scripts/Qingqiu/fox_melee_fx.gd").new()
		effect.variant=1.0
		effect.position=source+Vector3(0,0.3,0)
		add_child(effect)
	if attack=="cub_charm":
		rig().set_charm_charge(0.0)
		emit_cub_charm_heart()
	elif attack.begins_with("barrage"):
		delayed_shots=0
		vanish_casts+=1
		p2_casts_since_inferno+=1
		emit_barrage_wave()
	elif attack=="vision_charm":
		arena.combat_audio.emit_cue("charm_release", {"trigger": "P3 charm released after windup"})
		rig().set_charm_charge(0.0)
		emit_charm_hearts()
		arena.encounter.spawn_wave()
	if is_instance_valid(telegraph) and not attack.begins_with("cub_"):
		telegraph.active=true

func has_cub_charm_heart() -> bool:
	for projectile in projectiles:
		if is_instance_valid(projectile) and projectile.get_script()==preload("res://Scripts/Qingqiu/charm_heart_projectile.gd") and projectile.homing and not projectile.resolved:return true
	return false

func emit_cub_charm_heart() -> void:
	if has_cub_charm_heart():return
	var profile: Dictionary=arena.encounter.phase_config
	var heart=preload("res://Scripts/Qingqiu/charm_heart_projectile.gd").new()
	heart.name="CubHomingHeart";heart.source_phase=1;heart.homing=true
	heart.direction=direction;heart.position=arena.boss_position()+direction*.65
	heart.speed=float(profile.get("cub_charm_heart_speed",3.6))
	heart.homing_turn_speed=float(profile.get("cub_charm_heart_turn_speed",8.0))
	heart.lifetime=-1.0;heart.charm_seconds=float(profile.get("cub_charm_seconds",1.2))
	heart.charm_strength=float(profile.get("cub_charm_strength",.45));heart.with_beacon=false
	heart.visual_scale=.75;heart.launch_height=1.35
	add_child(heart);projectiles.append(heart);bullets_fired+=1

func emit_charm_hearts() -> void:
	var profile: Dictionary=arena.encounter.phase_config
	var count:=int(profile.get("charm_heart_count",4))
	var spread:=float(profile.get("charm_heart_spread",.48))
	for index in count:
		var angle:=lerpf(-spread*.5,spread*.5,float(index)/float(maxi(count-1,1)))
		var heart=preload("res://Scripts/Qingqiu/charm_heart_projectile.gd").new()
		heart.direction=direction.rotated(Vector3.UP,angle)
		heart.position=source+heart.direction*.8
		heart.speed=float(profile.get("charm_heart_speed",6.0))
		heart.lifetime=float(profile.get("charm_heart_lifetime",6.5))
		heart.charm_seconds=float(profile["charm_seconds"])
		add_child(heart);projectiles.append(heart);bullets_fired+=1

func emit_adult_normal() -> void:
	arena.combat_audio.emit_cue("ghost_volley",{"trigger":"adult directional normal released", "attack":attack})
	if attack=="p2_claw_gale":
		for index in 5:
			spawn_adult_wave(direction.rotated(Vector3.UP,(float(index)-2.0)*.28),14.0,1.45,0.0,0,float(arena.encounter.phase_config.get("claw_gale_damage",14.0)),4.0)
	elif attack=="p2_tail_crescent":
		spawn_adult_wave(direction,10.5,7.0,0.0,1,float(arena.encounter.phase_config.get("tail_crescent_damage",18.0)),5.5)
	else:
		spawn_adult_wave(direction,12.5,1.25,2.0,2,float(arena.encounter.phase_config.get("fox_roar_damage",16.0)),4.8)

func spawn_adult_wave(heading: Vector3,speed: float,width: float,growth: float,variant: int,damage: float,life: float) -> Node3D:
	var wave=preload("res://Scripts/Qingqiu/fox_adult_wave.gd").new()
	wave.position=source+heading*.75
	wave.direction=heading.normalized();wave.speed=speed;wave.width=width
	wave.growth=growth;wave.variant=variant;wave.damage=damage;wave.lifetime=life
	add_child(wave);projectiles.append(wave);bullets_fired+=1
	return wave

func update_center_jump() -> void:
	var t:=clampf(age/1.0,0.0,1.0)
	var form: Node3D=arena.forms.get_child(2)
	var point:=source.lerp(Vector3.ZERO,smoothstep(0.0,1.0,t))
	form.position.x=point.x;form.position.z=point.z
	fox_height=sin(t*PI)*3.6
	if t>=1.0 and not strike_applied:
		strike_applied=true
		arena.presentation.add_trauma(.55)
		arena.fox_motion_fx.landing(arena.boss_position(),3)
	if age>=1.35:
		form.position.x=0.0;form.position.z=0.0;fox_height=0.0
		arena.presentation.cancel_orbit_intro()
		source=Vector3.ZERO;mode="spiral_charge";age=0.0;spiral_round=0
		if is_instance_valid(attack_seal):attack_seal.begin_channel()
		rig().play_action("p3_spiral_cast")

func emit_spiral_round() -> void:
	rig().pulse_attack_tail("p3_spiral")
	var profile: Dictionary=arena.encounter.phase_config
	var count:=int(profile.get("spiral_bullets",18))
	var gap:=int(profile.get("spiral_gap_sectors",2))
	var angle_offset:=float(spiral_round)*float(profile.get("spiral_angle_step",-.18))
	if is_instance_valid(attack_seal):attack_seal.release_pulse()
	arena.combat_audio.emit_cue("ghost_volley",{"trigger":"clockwise spiral round", "round":spiral_round+1})
	var spawned:=0
	for index in count:
		if index<gap:continue
		var angle:=TAU*float(index)/float(count)+angle_offset
		var bullet=preload("res://Scripts/Qingqiu/ghost_fire_projectile.gd").new()
		bullet.orbiting=true;bullet.filled_fire=true
		bullet.orbit_origin=Vector3.ZERO;bullet.orbit_angle=angle
		bullet.angular_speed=float(profile.get("spiral_angular_speed",-.24))
		bullet.radial_speed=float(profile.get("spiral_radial_speed",4.0))
		bullet.position=Vector3(sin(angle),0,cos(angle))*1.3
		bullet.direction=bullet.position.normalized();bullet.radius=.30
		bullet.damage=float(profile.get("spiral_damage",12.0));bullet.lifetime=float(profile.get("spiral_lifetime",8.8))
		add_child(bullet);projectiles.append(bullet);bullets_fired+=1;spawned+=1
	spiral_round+=1
	spiral_log.append({"round":spiral_round,"angle":angle_offset,"time":age,"bullets":spawned})
	if spiral_log.size()>32:spiral_log.pop_front()

func emit_barrage_wave() -> void:
	rig().pulse_attack_tail(attack)
	if delayed_shots>0 and is_instance_valid(attack_seal):attack_seal.release_pulse()
	barrage_waves_fired+=1
	if attack=="barrage_ring":
		# All P2 patterns now launch from the locked facing, including this arc.
		emit_fan(10,2.50,(float(delayed_shots)-1.0)*.13,.12)
	elif attack=="barrage_fan":
		emit_fan(7,1.18,(float(delayed_shots)-1.0)*0.12,0.0)
	else:
		emit_fan(5,0.72,-0.22 if delayed_shots%2==0 else 0.22,-0.25 if delayed_shots%2==0 else 0.25)

func boss_targetable() -> bool:
	return arena.phase!=2 or mode!="vanish"

func set_boss_opacity(alpha: float) -> void:
	vanish_alpha=clampf(alpha,0.0,1.0)
	for form in arena.forms.get_children():
		var opacity:=vanish_alpha if arena.phase==2 and form==arena.forms.get_child(1) else 1.0
		form.get_node("FoxRig").visible=opacity>0.001
		for geometry in form.get_node("FoxRig").find_children("*","GeometryInstance3D",true,false):
			geometry.transparency=1.0-opacity
			if geometry.material_override is ShaderMaterial:geometry.material_override.set_shader_parameter("apparition_visibility",opacity)
		var shadow=form.get_node_or_null("ContactShadow")
		if shadow is GeometryInstance3D:
			shadow.transparency=1.0-opacity
			shadow.visible=opacity>0.001

func begin_vanish() -> void:
	mode="vanish"
	attack=""
	vanish_age=0.0
	vanish_casts=0
	label="狐身隐入雾中 · 等待它重新现形"
	rig().stop_action()
	arena.encounter.publish()

func update_vanish(delta: float) -> void:
	vanish_age+=delta
	var fade:=float(arena.encounter.phase_config.get("vanish_fade_seconds",0.35))
	var hidden:=float(arena.encounter.phase_config.get("vanish_hidden_seconds",1.6))
	var total:=fade*2.0+hidden
	var alpha:=1.0-smoothstep(0.0,fade,vanish_age)
	if vanish_age>=fade+hidden:alpha=smoothstep(fade+hidden,total,vanish_age)
	set_boss_opacity(alpha)
	if vanish_age>=total:
		set_boss_opacity(1.0)
		finish_attack(float(arena.encounter.phase_config.get("vanish_recovery_seconds",1.4)))
		label="狐身重现 · 短暂近战窗口"
		arena.encounter.publish()

func emit_fan(count: int,spread: float,offset: float,curve: float) -> void:
	arena.combat_audio.emit_cue("ghost_volley", {"trigger": "one volley", "volley": delayed_shots, "active_seconds": age})
	for i in count:
		var angle:=offset+spread*(float(i)/maxf(float(count-1),1.0)-0.5)
		spawn_bullet(source,direction.rotated(Vector3.UP,angle),3.6,curve,0 if sequence%2 else 7)

func spawn_bullet(origin: Vector3,heading: Vector3,speed: float,curve: float,palette: int) -> Node3D:
	var bullet=preload("res://Scripts/Qingqiu/ghost_fire_projectile.gd").new()
	bullet.position=origin+heading*0.95
	bullet.direction=heading.normalized()
	bullet.speed=speed
	bullet.curve=curve
	bullet.palette=palette
	bullet.motion=arena.encounter.balance.get("ghost_fire_motion",{}).duplicate(true)
	bullet.damage=float(arena.encounter.balance["phases"][1]["projectile_damage"])
	bullet.lifetime=float(arena.encounter.phase_config.get("projectile_lifetime",4.6))
	add_child(bullet)
	projectiles.append(bullet)
	bullets_fired+=1
	return bullet

func finish_attack(recovery: float) -> void:
	if attack in ["p3_spiral","inferno_rain"]:rig().stop_action()
	if is_instance_valid(attack_seal):attack_seal.finish()
	fox_height=0.0
	mode="recover"
	age=0.0
	cooldown=recovery
	if is_instance_valid(telegraph):telegraph.lifetime=telegraph.elapsed+0.32
	telegraph=null

func create_scope(point: Vector3,radius: float,shape: int,color: Color,angle:=1.0):
	var scope=preload("res://Scripts/Qingqiu/attack_scope.gd").new()
	scope.position=Vector3(point.x,0,point.z)
	scope.radius=radius
	scope.shape=shape
	scope.color=color
	scope.half_angle=angle
	add_child(scope)
	scope.visible=false
	return scope

func spawn_beacon() -> void:
	if is_instance_valid(beacon):return
	var point: Vector3=arena.player.position
	var angle:=float(sequence)*2.15+0.7
	point+=Vector3(cos(angle),0,sin(angle))*3.8
	point.x=clampf(point.x,-16.5,16.5)
	point.z=clampf(point.z,-16.5,16.5)
	point.y=0.0
	beacon=Node3D.new()
	beacon.name="CleansingLumen"
	beacon.position=point
	add_child(beacon)
	beacon_orb=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(1.1,1.1)
	beacon_orb.mesh=quad
	beacon_orb.position.y=0.85
	var surface:=ShaderMaterial.new()
	surface.shader=preload("res://Shaders/Qingqiu/lumen_pickup.gdshader")
	beacon_orb.material_override=surface
	beacon.add_child(beacon_orb)
	var light:=OmniLight3D.new()
	light.light_color=Color("#70f3ff")
	light.light_energy=1.0
	light.omni_range=2.6
	light.position.y=1.0
	beacon.add_child(light)
	var floor_glow:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(1.9,1.9)
	floor_glow.mesh=plane
	floor_glow.position.y=0.04
	floor_glow.material_override=surface
	beacon.add_child(floor_glow)

func apply_vision_charm(seconds: float,strength:=1.0,with_beacon:=true) -> void:
	arena.combat_audio.emit_cue("charm_afflict", {"trigger": "vision charm actually applied"})
	vision_remaining=maxf(vision_remaining,seconds)
	vision_strength=clampf(strength,0.0,1.0)
	charm_hits+=1
	label="视线被魅惑 · 靠近蔚蓝光点解除" if with_beacon else "幼狐魅惑 · 短暂失控走向幼狐"
	if with_beacon and not is_instance_valid(beacon):spawn_beacon()
	arena.encounter.publish()

func clear_vision(picked:=false) -> void:
	vision_remaining=0.0
	if picked:
		cleanses+=1
		arena.combat_audio.emit_cue("cleanse", {"trigger": "cleansing lumen picked"})
		var burst=create_scope(beacon.position,1.2,0,Color("#70f3ff"))
		burst.active=true
		burst.lifetime=0.7
	if is_instance_valid(beacon):beacon.queue_free()
	beacon=null
	label="清心光点 · 魅惑已解除" if picked else ""
	arena.encounter.publish()

func update_vision(delta: float) -> void:
	if arena.encounter==null:return
	var running: bool=arena.encounter.state==arena.encounter.State.RUNNING
	if running and vision_remaining>0.0:
		vision_remaining=maxf(0.0,vision_remaining-delta)
		if vision_remaining<=0.0:clear_vision()
	if running and is_instance_valid(beacon):
		var offset: Vector3=arena.player.position-beacon.position
		offset.y=0.0
		if offset.length()<0.95 and vision_remaining>0.0:clear_vision(true)
	vision_amount=move_toward(vision_amount,vision_strength if vision_remaining>0.0 else 0.0,delta*4.0)
	vision_rect.visible=vision_amount>0.001
	var size:=get_viewport().get_visible_rect().size
	vision_material.set_shader_parameter("amount",vision_amount)
	vision_material.set_shader_parameter("clock",clock)
	vision_material.set_shader_parameter("aspect",size.x/maxf(size.y,1.0))
	vision_material.set_shader_parameter("player_uv",arena.camera.unproject_position(arena.player.position+Vector3(0,0.8,0))/size)
	vision_material.set_shader_parameter("beacon_active",1.0 if is_instance_valid(beacon) else 0.0)
	if is_instance_valid(beacon):
		vision_material.set_shader_parameter("beacon_uv",arena.camera.unproject_position(beacon.position+Vector3(0,0.85,0))/size)
		beacon_orb.basis=arena.camera.global_basis
		beacon_orb.material_override.set_shader_parameter("clock",clock)
