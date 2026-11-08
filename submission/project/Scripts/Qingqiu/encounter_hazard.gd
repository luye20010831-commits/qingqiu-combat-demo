extends Node3D
var radius := 1.1
var warning_seconds := 1.35
var active_seconds := 0.75
var damage := 10.0
var palette := 7
var elapsed := 0.0
var material: ShaderMaterial
var fire: Node3D
var activated := false
var flower_material: ShaderMaterial
var white_gold:=false

func _ready() -> void:
	white_gold=get_parent().arena.phase==3
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE*radius*2.2
	ground.mesh = plane
	ground.position.y = 0.065
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = preload("res://Shaders/Qingqiu/white_gold_fire_ground.gdshader") if white_gold else preload("res://Shaders/Qingqiu/attack_flame_scope.gdshader")
	material.set_shader_parameter("uv_extent",1.10)
	material.set_shader_parameter("ink_color",Color("#392f41"))
	material.set_shader_parameter("danger_color",Color("#ffa400") if palette == 4 else Color("#c32136"))
	ground.material_override = material
	add_child(ground)
	ground.visible=false # Attack cues now belong to body motion and floating seals.
	if white_gold:
		fire=preload("res://Scripts/Qingqiu/white_gold_fire.gd").new()
		fire.seed=position.x*.21+position.z*.16
		fire.scale=Vector3.ONE*float(get_parent().phase_config.get("hazard_visual_scale",1.0))
		add_child(fire)
	else:
		fire=preload("res://Scenes/Qingqiu/Effects/GhostFire.tscn").instantiate()
		add_child(fire)
		fire.set_palette(palette)
		fire.scale=Vector3.ONE*.43
		fire.light_energy=.15
		fire.get_node("GroundSpill").visible=false
	fire.visible = false
	get_parent().arena.combat_audio.emit_cue("hazard_warning", {"trigger": "hazard warning begins; overlapping warnings throttled"})

func _process(delta: float) -> void:
	var encounter = get_parent()
	if encounter.state != encounter.State.RUNNING: return
	elapsed += delta
	var danger := elapsed >= warning_seconds and elapsed < warning_seconds+active_seconds
	material.set_shader_parameter("charge",minf(elapsed/warning_seconds,1.0))
	material.set_shader_parameter("effect_time",elapsed)
	material.set_shader_parameter("active",1.0 if danger else 0.0)
	if flower_material!=null:
		flower_material.set_shader_parameter("charge",minf(elapsed/warning_seconds,1.0))
		flower_material.set_shader_parameter("active",1.0 if danger else 0.0)
		flower_material.set_shader_parameter("clock",elapsed)
	fire.visible = elapsed >= warning_seconds
	if white_gold:fire.intensity=smoothstep(0.0,0.14,maxf(0.0,elapsed-warning_seconds))
	if danger:
		if not activated:
			activated = true
			encounter.arena.combat_audio.set_fire_source(self,true)
			encounter.hazards_activated += 1
			encounter.arena.combat_audio.emit_cue("hazard_ignite", {"trigger": "hazard warning crossed", "warning_seconds": warning_seconds, "frame_at_60fps": warning_seconds*60.0})
			if white_gold and encounter.arena.flora!=null:encounter.arena.flora.emit_burst(global_position)
		var player_position: Vector3 = encounter.arena.player.position
		if Vector2(player_position.x-global_position.x,player_position.z-global_position.z).length() <= radius:
			encounter.damage_player(damage)
	var end := warning_seconds+active_seconds
	if elapsed > end:
		var fade := clampf(1.0-(elapsed-end)/0.30,0.0,1.0)
		material.set_shader_parameter("fade",fade)
		if flower_material!=null:flower_material.set_shader_parameter("fade",fade)
		fire.intensity = fade if white_gold else maxf(0.2,fade)
	if elapsed >= end+0.30: queue_free()
