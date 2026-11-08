extends Node3D
## Timed close-range spear contacts; original apparition impact feedback retained.
signal skills_changed(snapshot: Dictionary)
@onready var arena = get_parent()
var cooldown := 0.0
var skills: Array=[]
var cooldowns: Array[float]=[]
var active_skill: Dictionary={}
var ward_remaining:=0.0
var ward_surface: MeshInstance3D
var skill_stamp:=""
var melee_contacts:=0
var melee_misses:=0
var shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var hit_count := 0
var shot_count := 0
var last_hit_phase := 0
var mist_mesh: QuadMesh
var sphere_mesh: SphereMesh
var random := RandomNumberGenerator.new()
var arc_texture: Texture2D
var impact_texture: Texture2D
var trail_events:=0
var impact_events:=0
var last_impact_skill:=""

func _ready() -> void:
	skills=JSON.parse_string(FileAccess.get_file_as_string("res://Data/Qingqiu/player_melee.json"))["skills"]
	cooldowns.resize(skills.size())
	cooldowns.fill(0.0)
	arc_texture=load("res://Art/Qingqiu/HunterMeleeV3/spear_arc.png")
	impact_texture=load("res://Art/Qingqiu/HunterMeleeV3/impact_burst.png")
	random.seed = 719
	mist_mesh = QuadMesh.new()
	mist_mesh.size = Vector2.ONE
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		shoot(false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		use_skill(3,false)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		shoot(true)

func shoot(aim_at_fox := true) -> bool:
	return use_skill(0,aim_at_fox)

func use_skill(index: int,aim_at_fox:=true) -> bool:
	if index<0 or index>=skills.size() or arena.encounter==null:return false
	if arena.encounter.combat_input_blocked() or arena.presentation.is_busy():return false
	if cooldowns[index]>0.0 or (index==0 and cooldown>0.0) or not active_skill.is_empty():return false
	if arena.charm_remaining>0.0 or arena.dash_remaining>0.0 or arena.player_avatar.priority>=3:return false
	var target: Vector3=arena.boss_position()
	if not aim_at_fox:
		var mouse:=get_viewport().get_mouse_position()
		var point: Variant=Plane(Vector3.UP,0.0).intersects_ray(arena.camera.project_ray_origin(mouse),arena.camera.project_ray_normal(mouse))
		if point==null:return false
		target=point
	var direction: Vector3=target-arena.player.position
	direction.y=0.0
	if direction.length_squared()<0.01:direction=Vector3.FORWARD
	direction=direction.normalized()
	var profile: Dictionary=skills[index]
	if not arena.player_avatar.play_action(str(profile["clip"]),float(profile["duration"]),1,float(profile["clip_seconds"])/float(profile["duration"])):return false
	arena.player_avatar.face_direction(direction)
	active_skill={"index":index,"age":0.0,"contacted":false,"trailed":false,"direction":direction}
	cooldowns[index]=float(profile["cooldown"])
	cooldown=cooldowns[0]
	shot_count+=1
	if str(profile["id"])=="ward":
		arena.combat_audio.emit_cue("player_ward_cast",{"trigger":"accepted ward windup", "skill":profile["id"]})
	publish_skills(true)
	return true

func skill_snapshot() -> Dictionary:
	var blocked: bool=arena.encounter==null or arena.encounter.state!=arena.encounter.State.RUNNING
	if arena.presentation!=null:blocked=blocked or arena.presentation.is_busy()
	blocked=blocked or not active_skill.is_empty() or arena.dash_remaining>0.0 or arena.charm_remaining>0.0 or arena.player_avatar.priority>=3
	var durations: Array=[]
	for profile in skills:durations.append(float(profile["cooldown"]))
	return {"cooldowns":cooldowns.duplicate(),"durations":durations,"blocked":blocked,"ward":ward_remaining}

func publish_skills(force:=false) -> void:
	var snap:=skill_snapshot()
	var values:=PackedStringArray()
	for value in cooldowns:values.append(str(ceili(value*10)))
	var stamp:="%s:%s:%d" % [":".join(values),snap["blocked"],ceili(ward_remaining*10)]
	if force or stamp!=skill_stamp:
		skill_stamp=stamp
		skills_changed.emit(snap)

func can_contact(profile: Dictionary,direction: Vector3) -> bool:
	if arena.attacks!=null and not arena.attacks.boss_targetable():return false
	var offset: Vector3=arena.boss_position()-arena.player.position
	offset.y=0.0
	if offset.length()>float(profile["reach"]):return false
	if offset.length()>0.1 and direction.dot(offset.normalized())<cos(float(profile["half_angle"])):return false
	# Keep weapons from hitting through tree/rock collision bodies.
	var ray:=PhysicsRayQueryParameters3D.create(arena.player.global_position+Vector3.UP*0.8,arena.boss_position()+Vector3.UP*0.8,1,[arena.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func update_melee(delta: float) -> void:
	if active_skill.is_empty():return
	# Dodge, charm or a real hit interrupts the contact; cooldown is retained.
	if arena.dash_remaining>0.0 or arena.charm_remaining>0.0 or arena.player_avatar.priority>=3:
		active_skill.clear()
		return
	active_skill["age"]+=delta
	var profile: Dictionary=skills[active_skill["index"]]
	if int(active_skill["index"])!=2 and not bool(active_skill.get("trailed",false)) and float(active_skill["age"])>=float(profile.get("trail_start",profile["contact"])):
		active_skill["trailed"]=true
		arena.combat_audio.emit_cue("player_cast" if int(active_skill["index"])==0 else "player_wide_swing",{"trigger":"actual weapon swing", "skill":profile["id"],"skill_seconds":active_skill["age"]})
		spawn_slash(active_skill["direction"],int(active_skill["index"]))
	if not active_skill["contacted"] and float(active_skill["age"])>=float(profile["contact"]):
		active_skill["contacted"]=true
		if int(active_skill["index"])==2:
			ward_remaining=float(profile["ward_seconds"])
			spawn_ward()
		else:
			var direction: Vector3=active_skill["direction"]
			if can_contact(profile,direction):
				var before:=hit_count
				register_hit(arena.boss_position()+Vector3.UP*0.95,-direction,float(profile["damage"]),int(active_skill["index"]))
				if hit_count>before:
					melee_contacts+=1
			else:melee_misses+=1
	if not active_skill.is_empty() and float(active_skill["age"])>=float(profile["duration"]):active_skill.clear()

func spawn_slash(direction: Vector3,index: int) -> void:
	var heavy:=index==3
	var facing_left:=direction.dot(arena.camera.global_basis.x)<0.0
	var quad:=QuadMesh.new()
	quad.size=Vector2(3.5,2.4) if heavy else Vector2(3.4,2.25) if index==1 else Vector2(2.8,2.0)
	var node:=mesh_effect(quad,preload("res://Shaders/Qingqiu/hunter_swing_vfx.gdshader"))
	var height:=1.75 if heavy else 1.6 if index==1 else 1.35
	node.position=arena.player.position+direction*0.95+Vector3.UP*height+arena.camera.global_basis.z*.06
	node.basis=arena.camera.global_basis
	node.rotate_object_local(Vector3.BACK,(.5 if heavy else .25)*(1.0 if facing_left else -1.0))
	node.material_override.set_shader_parameter("effect_texture",arc_texture)
	node.material_override.set_shader_parameter("flip",1.0 if facing_left else -1.0)
	node.material_override.set_shader_parameter("tint",Color("ffe0a5") if heavy else Color.WHITE)
	node.material_override.set_shader_parameter("strength",.52 if arena.presentation.reduced_effects else .95)
	effects.append({"node":node,"time":0.0,"duration":.26 if heavy else .18,"mist":false,"kind":"swing","scale_start":.82,"scale_end":1.07})
	trail_events+=1

func spawn_impact(point: Vector3,heavy: bool) -> void:
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE*(1.45 if heavy else .95)
	var node:=mesh_effect(quad,preload("res://Shaders/Qingqiu/hunter_swing_vfx.gdshader"))
	node.position=point+arena.camera.global_basis.z*.10
	node.basis=arena.camera.global_basis
	node.material_override.set_shader_parameter("effect_texture",impact_texture)
	node.material_override.set_shader_parameter("impact",1.0)
	node.material_override.set_shader_parameter("tint",Color("ffe0a5") if heavy else Color.WHITE)
	node.material_override.set_shader_parameter("strength",.6 if arena.presentation.reduced_effects else 1.0)
	effects.append({"node":node,"time":0.0,"duration":.26 if heavy else .18,"mist":false,"kind":"impact","scale_start":.65,"scale_end":1.3})
	impact_events+=1

func spawn_ward() -> void:
	if is_instance_valid(ward_surface):ward_surface.queue_free()
	ward_surface=mesh_effect(sphere_mesh,preload("res://Shaders/Qingqiu/hunter_ward.gdshader"))
	ward_surface.scale=Vector3(0.72,1.12,0.72)
	ward_surface.position=arena.player.position+Vector3.UP*1.05

func absorb_damage(amount: float) -> float:
	return amount*float(skills[2]["damage_multiplier"]) if ward_remaining>0.0 else amount

func mesh_effect(mesh: Mesh, shader: Shader) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material_override = material
	add_child(node)
	return node

func _process(delta: float) -> void:
	if arena.encounter==null or arena.presentation==null:return
	if arena.presentation.is_busy():
		publish_skills()
		return
	for index in cooldowns.size():cooldowns[index]=maxf(0.0,cooldowns[index]-delta)
	cooldown=maxf(0.0,cooldown-delta)
	ward_remaining=maxf(0.0,ward_remaining-delta)
	if is_instance_valid(ward_surface):
		ward_surface.position=arena.player.position+Vector3.UP*1.05
		ward_surface.material_override.set_shader_parameter("strength",minf(ward_remaining*3.0,1.0))
		if ward_remaining<=0.0:ward_surface.queue_free()
	update_melee(delta)
	publish_skills()
	for index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		effect["time"] += delta
		var age: float = effect["time"] / effect["duration"]
		var node: MeshInstance3D = effect["node"]
		if age >= 1.0:
			node.queue_free()
			effects.remove_at(index)
			continue
		node.material_override.set_shader_parameter("age", age)
		if effect.has("scale_start"):
			node.scale=Vector3.ONE*lerpf(float(effect["scale_start"]),float(effect["scale_end"]),1.0-pow(1.0-age,2))
		if effect["mist"]:
			var velocity: Vector3 = effect["velocity"]
			velocity.y -= delta * 0.55
			effect["velocity"] = velocity
			node.position += velocity * delta
			node.scale = Vector3.ONE * effect["size"] * (0.6 + age * 1.15)
			node.basis = arena.camera.global_basis.scaled(node.scale)

func register_hit(point: Vector3, direction: Vector3,damage: float=10.0,skill_index: int=0) -> void:
	if arena.encounter != null:
		if not arena.encounter.accept_boss_hit(damage): return
	hit_count += 1
	last_hit_phase = arena.phase
	var rig = arena.forms.get_child(arena.phase - 1).get_node("FoxRig")
	var center: Vector3=arena.boss_position()
	var profile: Dictionary=skills[clampi(skill_index,0,skills.size()-1)]
	var heavy:=str(profile["id"])=="heavy"
	spawn_impact(point,heavy)
	last_impact_skill=str(profile["id"])
	arena.player_avatar.hold_impact(float(profile.get("impact_pause",.03)))
	rig.strike_pause=maxf(rig.strike_pause,float(profile.get("boss_pause",.045)))
	if arena.encounter.state==arena.encounter.State.RUNNING:
		rig.apply_weapon_hit(-direction,.13 if heavy else .05)
	# P1 shows the weapon stroke only. Apparition mist belongs to its defeat.
	if arena.phase != 1:
		var echo := mesh_effect(sphere_mesh, preload("res://Shaders/Qingqiu/spirit_shield.gdshader"))
		echo.position = center+Vector3(0, 1.2, 0)
		echo.material_override.set_shader_parameter("hit_point", direction.normalized())
		if arena.phase == 3:
			echo.material_override.set_shader_parameter("spirit_color", Color("#ffa400"))
		effects.append({"node": echo, "time": 0.0, "duration": 0.4, "mist": false})
	if arena.encounter.state != arena.encounter.State.VICTORY:
		arena.combat_audio.emit_cue("player_heavy_hit" if heavy else "boss_hit_p%d" % arena.phase, {"trigger": "accepted melee contact", "skill":profile["id"]})
		arena.combat_audio.emit_cue("boss_effort_p%d" % arena.phase, {"trigger": "accepted melee contact; throttled effort"})
	arena.presentation.add_trauma(float(profile.get("trauma",.28)))

func clear_transients() -> void:
	for shot in shots:
		shot["node"].queue_free()
	shots.clear()
	for effect in effects:
		effect["node"].queue_free()
	effects.clear()
	cooldown = 0.0
	cooldowns.resize(skills.size())
	cooldowns.fill(0.0)
	active_skill.clear()
	ward_remaining=0.0
	if is_instance_valid(ward_surface):ward_surface.queue_free()
	if arena.encounter!=null:publish_skills(true)
	if is_instance_valid(arena.forms):
		for phase in arena.forms.get_children():
			var rig = phase.get_node_or_null("FoxRig")
			if rig:
				rig.clear_spirit_impact()

