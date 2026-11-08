extends Node3D
## Qingqiu visual preview and three-phase encounter.

const PHASE_NAMES := ["壹  ·  单尾幼狐", "贰  ·  双尾迷雾", "叁  ·  九尾金瞳"]
const PHASE_LIGHTING := [
	{"ambient": Color("#3d3b4f"), "moon": Color("#bbcdc5"), "rim": Color("#1685a9"),
	"local": Color("#70f3ff"), "fog": Color("#bbcdc5"), "local_energy": 3.5, "player_energy": 1.4,
	"ambient_energy": 0.26, "moon_energy": 0.55, "rim_energy": 0.22, "fog_density": 0.065},
	{"ambient": Color("#392f41"), "moon": Color("#3d3b4f"), "rim": Color("#003472"),
	"local": Color("#bbcdc5"), "fog": Color("#bbcdc5"), "local_energy": 0.35, "player_energy": 2.5,
	"ambient_energy": 0.035, "moon_energy": 0.06, "rim_energy": 0.04, "fog_density": 0.10},
	{"ambient": Color("#75664d"), "moon": Color("#ffa400"), "rim": Color("#96ce54"),
	"local": Color("#ffa400"), "fog": Color("#bbcdc5"), "local_energy": 3.8, "player_energy": 1.4,
	"ambient_energy": 0.4, "moon_energy": 0.85, "rim_energy": 0.3, "fog_density": 0.065}
]
const ARENA_HALF_SIZE := 19.35
const CAMERA_OFFSET := Vector3(0.0, 18.0, 25.7)
const CAMERA_LOOK_OFFSET := Vector3(0.0, 0.6, 0.0)
const CAMERA_DISTANCE_MIN := 0.65
const CAMERA_DISTANCE_MAX := 1.5
const CAMERA_ZOOM_STEP := 0.1

@onready var player: CharacterBody3D = $Player
@onready var player_sprite: Sprite3D = $Player/Visual
@onready var player_avatar: Node3D = $Player/HunterAvatar
@onready var camera: Camera3D = $Camera3D
@onready var forms: Node3D = $FoxForms
@onready var phase_label: Label = $Presentation/Interface/PhaseName
@onready var clouds: Node3D = $GroundClouds
@onready var mist: FogVolume = $Atmosphere/GroundMist
@onready var fox_light_offset: Vector3=$Atmosphere/FoxSoftLight.position

var phase := 1
var elapsed := 0.0
var dash_remaining := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector3.ZERO
var charm_remaining := 0.0
var presentation
var combat_audio
var spirit_combat
var ghost_fire
var encounter
var player_feedback
var attacks
var flora
var p3_environment
var depth_order
var player_burn
var fox_motion_fx
var developer_test
var camera_distance_scale := 1.0

func _ready() -> void:
	DisplayServer.window_set_title("青丘 · 三阶段试战")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	spirit_combat = preload("res://Scripts/Qingqiu/spirit_combat.gd").new()
	spirit_combat.name = "SpiritCombat"
	add_child(spirit_combat)
	presentation = preload("res://Scripts/Qingqiu/phase_presentation.gd").new()
	presentation.name = "PhasePresentation"
	add_child(presentation)
	combat_audio = preload("res://Scripts/Qingqiu/combat_audio.gd").new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)
	player_feedback = preload("res://Scripts/Qingqiu/player_hit_feedback.gd").new()
	player_feedback.name = "PlayerHitFeedback"
	add_child(player_feedback)
	ghost_fire = preload("res://Scenes/Qingqiu/Effects/GhostFire.tscn").instantiate()
	ghost_fire.name = "GhostFire"
	ghost_fire.position = Vector3(-2.8,0.0,0.15)
	ghost_fire.scale = Vector3.ONE*0.68
	add_child(ghost_fire)
	$Presentation/Interface/Subtitle.text = "三阶段试战 · 参考节奏 2 / 3 / 3 分钟"
	$Presentation/Interface/Controls.text = "WASD 移动  空格冲刺  左键/J/1 挥击  2 横扫  3 护魂  右键/4 重击  Enter 开始  R 重开"
	$Presentation/Interface/Controls.add_theme_font_size_override("font_size", 20)
	encounter = preload("res://Scripts/Qingqiu/fox_encounter.gd").new()
	encounter.name = "FoxEncounter"
	add_child(encounter)
	player_burn=preload("res://Scripts/Qingqiu/player_burn.gd").new()
	player_burn.name="PlayerBurn";add_child(player_burn)
	player_avatar.bind_encounter(encounter)
	attacks=preload("res://Scripts/Qingqiu/fox_attack_director.gd").new()
	attacks.name="FoxAttacks"
	add_child(attacks)
	flora=preload("res://Scripts/Qingqiu/phase_flora.gd").new()
	flora.name="PhaseFlowers"
	add_child(flora)
	p3_environment=preload("res://Scripts/Qingqiu/p3_ruin_environment.gd").new()
	p3_environment.name="P3RuinEnvironment"
	add_child(p3_environment)
	var fox_glow=preload("res://Scripts/Qingqiu/p2_enchant_light.gd").new()
	fox_glow.name="EnchantLight"
	forms.get_child(1).add_child(fox_glow)
	var p3_rig=forms.get_child(2).get_node("FoxRig")
	var anklet=preload("res://Scripts/Qingqiu/p3_golden_anklet.gd").new()
	anklet.name="GoldenAnklet";p3_rig.add_child(anklet);p3_rig.golden_anklet=anklet
	depth_order=preload("res://Scripts/Qingqiu/arena_depth_order.gd").new()
	depth_order.name="DepthOrder"
	add_child(depth_order)
	fox_motion_fx=preload("res://Scripts/Qingqiu/fox_motion_fx.gd").new()
	fox_motion_fx.name="FoxMotionFX";add_child(fox_motion_fx)
	set_phase(encounter.checkpoint.phase)
	camera.position = player.position + CAMERA_OFFSET
	camera.look_at(player.position + CAMERA_LOOK_OFFSET)
	developer_test=preload("res://Scripts/Qingqiu/developer_phase_test.gd").new()
	developer_test.name="DeveloperPhaseTest";add_child(developer_test)
	encounter.ui_changed.connect(update_checkpoint_hint)
	update_checkpoint_hint(encounter.snapshot())

func _physics_process(delta: float) -> void:
	elapsed += delta
	charm_remaining = maxf(0.0, charm_remaining - delta)
	if encounter != null and encounter.state != encounter.State.RUNNING:
		charm_remaining = 0.0
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	var axis := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	var right := camera.global_basis.x
	var forward := camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	var direction := (right.normalized() * axis.x + forward.normalized() * axis.y).normalized()
	if charm_remaining > 0.0:
		var toward_fox := boss_position() - player.position
		toward_fox.y = 0.0
		direction = toward_fox.normalized() if toward_fox.length() > 0.9 else Vector3.ZERO
	if presentation.is_busy():
		direction = Vector3.ZERO
		dash_remaining = 0.0
	if encounter != null and encounter.state == encounter.State.DEFEAT:
		direction = Vector3.ZERO
		dash_remaining = 0.0
	if Input.is_action_just_pressed("Dash") and dash_cooldown <= 0.0 and direction != Vector3.ZERO and charm_remaining <= 0.0 and not presentation.is_busy():
		dash_direction = direction
		dash_remaining = 0.18
		dash_cooldown = 0.65
		combat_audio.emit_cue("player_dash", {"frame_at_60fps": 0, "trigger": "accepted dash input"})
		player_avatar.notify_dash(dash_direction)
	dash_remaining = maxf(0.0, dash_remaining - delta)
	var motion := dash_direction * 10.0 if dash_remaining > 0.0 else direction * 4.2
	if charm_remaining > 0.0:
		motion = direction * 1.7
	player.velocity = motion
	var before_motion := player.position
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -ARENA_HALF_SIZE, ARENA_HALF_SIZE)
	player.position.z = clampf(player.position.z, -ARENA_HALF_SIZE, ARENA_HALF_SIZE)
	player_avatar.set_motion((player.position-before_motion)/maxf(delta,0.0001))
	combat_audio.update_player_motion(before_motion, player.position, dash_remaining > 0.0, int(elapsed * 9.0) % 2)
	var active_form := forms.get_child(phase - 1) as Node3D
	active_form.position.y = sin(elapsed * 1.5) * 0.025+(attacks.fox_height if attacks!=null else 0.0)
	active_form.get_node("ContactShadow").position.y=0.018-active_form.position.y
	$Atmosphere/FoxSoftLight.position=boss_position()+fox_light_offset
	var focus: Vector3=player.position.lerp(boss_position(),presentation.focus_weight)
	# Dolly along the original viewing ray; phase reveals retain their own FOV.
	var offset := CAMERA_LOOK_OFFSET + (CAMERA_OFFSET - CAMERA_LOOK_OFFSET) * camera_distance_scale
	if presentation.opening.active:
		presentation.opening.apply_camera()
	elif presentation.cinematic.active:
		presentation.cinematic.apply_game_camera()
	else:
		camera.position = camera.position.lerp(focus + offset, 1.0 - exp(-6.0 * delta))
		camera.look_at(focus + CAMERA_LOOK_OFFSET)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var direction := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1.0
	else:
		return
	camera_distance_scale = clampf(camera_distance_scale + direction * CAMERA_ZOOM_STEP * event.factor, CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)
	get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			if encounter.is_preview(): presentation.request_phase(1)
			else:spirit_combat.use_skill(0)
		KEY_2:
			if encounter.is_preview(): presentation.request_phase(2)
			else:spirit_combat.use_skill(1)
		KEY_3:
			if encounter.is_preview(): presentation.request_phase(3)
			else:spirit_combat.use_skill(2)
		KEY_4:
			if not encounter.is_preview():spirit_combat.use_skill(3)
		KEY_ENTER:
			if encounter.state in [encounter.State.PREVIEW,encounter.State.VICTORY,encounter.State.DEFEAT]: restart_playtest(true)
		KEY_TAB: encounter.stop_to_preview()
		KEY_V: presentation.play_voice(phase)
		KEY_M: presentation.toggle_mute()
		KEY_B: presentation.reduced_effects = not presentation.reduced_effects
		KEY_G:
			if phase!=1:ghost_fire.visible = not ghost_fire.visible
		KEY_H: ghost_fire.set_palette((ghost_fire.palette_variant+1)%8)
		KEY_N: $EnvironmentMotion.animate = not $EnvironmentMotion.animate
		KEY_C:
			$Presentation.visible = not $Presentation.visible
			encounter.hud.visible = $Presentation.visible
		KEY_F:
			mist.visible = not mist.visible
			$Atmosphere/MistBanks.visible = mist.visible
		KEY_R:
			if not encounter.is_preview() or encounter.checkpoint.phase>1 or (is_instance_valid(developer_test) and developer_test.developer_enabled):
				restart_playtest()
				return
			charm_remaining = 0.0
			$FoxCharm.reset()
			spirit_combat.clear_transients()
			player.position = Vector3(0.0, 0.0, 6.5)
		KEY_ESCAPE: get_tree().quit()

func restart_playtest(with_opening:=false) -> void:
	var testing: bool=is_instance_valid(developer_test) and developer_test.developer_enabled
	var start_phase: int=developer_test.selected_phase if testing else encounter.checkpoint.phase
	encounter.start_encounter(start_phase,with_opening and not testing,not testing)

func update_checkpoint_hint(data: Dictionary) -> void:
	var subtitle: Label=$Presentation/Interface/Subtitle
	if int(data["checkpoint_error"])!=OK:
		subtitle.text="自动存档暂不可用 · 当前进度可继续游玩"
	elif data["state"]==encounter.State.TRANSITION and encounter.attempt_saves_progress:
		subtitle.text="已保存 · 下次从 P%d 开始" % int(data["checkpoint_phase"])
	elif data["state"] in [encounter.State.PREVIEW,encounter.State.VICTORY,encounter.State.DEFEAT] and int(data["checkpoint_phase"])>1:
		subtitle.text="存档点 P%d · Enter 继续 · R 重试" % int(data["checkpoint_phase"])
	else:
		subtitle.text="三阶段试战 · 参考节奏 2 / 3 / 3 分钟"

func set_phase(value: int) -> void:
	if is_instance_valid(spirit_combat):
		spirit_combat.clear_transients()
	phase = clampi(value, 1, 3)
	ghost_fire.visible=false
	charm_remaining = 0.0
	$FoxCharm.reset()
	for index in forms.get_child_count():
		forms.get_child(index).visible = index == phase - 1
	phase_label.text = PHASE_NAMES[phase - 1]
	for cloud in clouds.get_children():
		var material := (cloud as MeshInstance3D).material_override as ShaderMaterial
		material.set_shader_parameter("gold_amount", 1.0 if phase == 3 else 0.0)
		material.set_shader_parameter("emission_strength", 0.0 if phase == 2 else 0.025)
	apply_environment()
	$EnvironmentMotion.apply_phase(phase)
	if encounter != null: encounter.on_phase_changed(phase)
	if flora!=null:flora.set_phase(phase)
	if p3_environment!=null:p3_environment.set_phase(phase)
	var ground_surface: ShaderMaterial=$SquareGround/AzuriteFloor.material_override
	ground_surface.set_shader_parameter("fracture_strength",[0.24,0.18,0.62][phase-1])

func boss_position() -> Vector3:
	var point: Vector3=forms.get_child(phase-1).position
	point.y=0.0
	return point

func apply_environment() -> void:
	var profile: Dictionary = PHASE_LIGHTING[phase - 1]
	var environment: Environment = $Atmosphere/WorldEnvironment.environment
	environment.ambient_light_color = profile["ambient"]
	environment.ambient_light_energy = profile["ambient_energy"]
	environment.adjustment_enabled = false
	environment.adjustment_saturation = 1.0
	environment.adjustment_color_correction = null
	$Atmosphere/Moonlight.light_color = profile["moon"]
	$Atmosphere/Moonlight.light_energy = profile["moon_energy"]
	$Atmosphere/JadeRim.light_color = profile["rim"]
	$Atmosphere/JadeRim.light_energy = profile["rim_energy"]
	$Atmosphere/FoxSoftLight.light_color = profile["local"]
	$Atmosphere/FoxSoftLight.light_energy = 1.4 if phase != 2 else 0.06
	$Player/PlayerFill.light_color = profile["local"]
	$Player/PlayerFill.light_energy = profile["player_energy"]
	for lamp in $JadeRocks.get_children():
		if lamp is OmniLight3D:
			lamp.light_color = profile["local"]
			lamp.light_energy = profile["local_energy"]
	mist.material.set_shader_parameter("base_color", profile["fog"])
	mist.material.set_shader_parameter("base_density", profile["fog_density"] * 0.12)
	for bank in $Atmosphere/MistBanks.get_children():
		var surface: ShaderMaterial = bank.material
		surface.set_shader_parameter("base_color", profile["fog"])
		surface.set_shader_parameter("base_density", profile["fog_density"] * bank.get_meta("density_scale", 1.0))

func apply_charm(duration: float) -> void:
	charm_remaining = duration
	dash_remaining = 0.0
	spirit_combat.active_skill.clear()
	player_avatar.notify_charm()
	spirit_combat.publish_skills(true)
	if encounter != null: encounter.on_charm_hit()
