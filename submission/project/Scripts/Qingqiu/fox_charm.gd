extends Node3D
## P1 charm prototype. A locked-direction heart can be avoided by movement or dash.
const HEART := preload("res://Art/Qingqiu/FoxRig/vfx/charm_heart.png")
const GAZE := preload("res://Art/Qingqiu/FoxRig/vfx/charm_gaze.png")
@onready var arena = get_parent()
var cooldown := 2.8
var charge_remaining := 0.0
var locked_direction := Vector3.FORWARD
var projectiles: Array[Dictionary] = []
var gaze: Sprite3D
var status: Sprite3D
var shots_fired := 0
var charm_hits := 0

func _ready() -> void:
	gaze = make_sprite(GAZE, 1.0)
	status = make_sprite(HEART, 0.42)
	gaze.visible = false
	status.visible = false

func make_sprite(texture: Texture2D, width: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = width / texture.get_width()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://Shaders/Qingqiu/fox_layer.gdshader")
	surface.set_shader_parameter("layer_texture", texture)
	surface.set_shader_parameter("glow_strength", 0.65)
	surface.set_shader_parameter("glow_color", Color("#d5a1a6"))
	sprite.material_override = surface
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	# Legacy heart projectile is retained for old art previews. The current
	# encounter uses animal P1 attacks and the P3 vision charm director.
	if arena.attacks!=null:return
	if arena.encounter != null and arena.encounter.state in [arena.encounter.State.VICTORY,arena.encounter.State.DEFEAT]: return
	if arena.presentation != null and arena.presentation.transition_active:
		return
	if arena.phase != 1:
		reset()
		return
	status.visible = arena.charm_remaining > 0.0
	status.position = arena.player.position + Vector3(0, 1.9, 0.2)
	var rig = arena.forms.get_child(0).get_node("FoxRig")
	if charge_remaining > 0.0:
		charge_remaining = maxf(0.0, charge_remaining - delta)
		var progress := 1.0 - charge_remaining / 1.15
		if progress < 0.55:
			locked_direction = Vector3(arena.player.position.x, 0, arena.player.position.z).normalized()
		gaze.visible = true
		gaze.position = Vector3(0, 2.55, 0.2)
		gaze.scale = Vector3.ONE * (0.7 + progress * 0.5)
		rig.set_charm_charge(progress)
		if charge_remaining <= 0.0:
			fire()
			gaze.visible = false
			rig.set_charm_charge(0.0)
	else:
		cooldown -= delta
		var activation_range := 11.0
		if arena.encounter != null and arena.encounter.state == arena.encounter.State.RUNNING:
			activation_range = float(arena.encounter.phase_config.get("charm_range",11.0))
		if cooldown <= 0.0 and arena.player.position.length() < activation_range:
			charge_remaining = 1.15
			cooldown = arena.encounter.charm_cooldown() if arena.encounter != null else 5.8
	update_projectiles(delta)

func fire() -> void:
	var projectile := make_sprite(HEART, 0.65)
	projectile.position = Vector3(0, 0.9, 0.25)
	var lifetime := 3.0
	if arena.encounter != null and arena.encounter.state == arena.encounter.State.RUNNING:
		lifetime = float(arena.encounter.phase_config.get("charm_projectile_lifetime",3.0))
	projectiles.append({"node": projectile, "direction": locked_direction, "life": lifetime})
	shots_fired += 1

func update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var node: Sprite3D = shot["node"]
		node.position += shot["direction"] * 4.0 * delta
		shot["life"] -= delta
		var distance := Vector2(node.position.x - arena.player.position.x, node.position.z - arena.player.position.z).length()
		var hit := distance < 0.55
		if hit and arena.dash_remaining <= 0.0:
			arena.apply_charm(1.35)
			charm_hits += 1
		if hit or shot["life"] <= 0.0:
			node.queue_free()
			projectiles.remove_at(index)

func reset() -> void:
	cooldown = 2.8
	charge_remaining = 0.0
	for shot in projectiles:
		shot["node"].queue_free()
	projectiles.clear()
	if is_instance_valid(gaze):
		gaze.visible = false
		status.visible = false
	var rig = arena.forms.get_child(0).get_node_or_null("FoxRig")
	if rig:
		rig.set_charm_charge(0.0)
