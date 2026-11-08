extends Node
## Phase visuals plus the user-requested licensed stage/transition cues.
const VOICES := [preload("res://Art/Audio/Qingqiu/fox_p1_cub.wav"), preload("res://Art/Audio/Qingqiu/fox_p2_shrill.wav"), preload("res://Art/Audio/Qingqiu/fox_p3_woman_wail.wav")]
# The old procedural curtain was deleted. Reuse the user's marked CC0 F03.
const FIRE_SOUND := preload("res://Art/Audio/Qingqiu/SelectedSFX_20261108/F03.wav")
const TRANSITION_ATTACK := preload("res://Art/Audio/Qingqiu/PhaseReveal/violoncello_transition_attack.mp3")
const PALETTES := [
	[Color("#392f41"), Color("#1685a9"), Color("#1bd1a5"), Color("#bbcdc5")],
	[Color("#392f41"), Color("#3d3b4f"), Color("#bbcdc5"), Color("#eef0e5")],
	[Color("#75664d"), Color("#ffa400"), Color("#e8d5a5"), Color("#f2f0df")]
]
@onready var arena = get_parent()
var cub_departure_active:=false
var cub_departure_age:=0.0
var cub_departure_duration:=1.45
var cub_departure_next:=2
var cub_mist: Node3D
var cub_origin:=Vector3.ZERO
var transition_active := false
var transition_elapsed := 0.0
var transition_duration := 2.0
var target_phase := 1
var queued_phase := 0
var committed := false
var commit_count := 0
var completed_count := 0
var clock := 0.0
var trauma := 0.0
var reduced_effects := false
var audio_enabled := DisplayServer.get_name() != "headless"
var voice: AudioStreamPlayer
var fire_audio: AudioStreamPlayer
var transition_attack: AudioStreamPlayer
var voice_count := 0
var last_voice_phase := 0
var transition_attack_count := 0
var owns_sfx_bus := false
var curtain: ColorRect
var material: ShaderMaterial
var orbit_intro_active:=false
var orbit_intro_age:=0.0
var orbit_intro_duration:=1.35
var orbit_rect: ColorRect
var orbit_material: ShaderMaterial
var intro_active:=false
var intro_elapsed:=0.0
var intro_duration:=2.3
var intro_pulsed:=false
var focus_weight:=0.0
var reveal_light: Light3D
var reveal_energy:=0.0
var cinematic
var opening

func _ready() -> void:
	var bus := AudioServer.get_bus_index("QingqiuSFX")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "QingqiuSFX")
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(bus, limiter)
		owns_sfx_bus = true
	voice = make_audio("FoxVoice")
	fire_audio = make_audio("FlameWhoosh")
	fire_audio.stream = FIRE_SOUND
	fire_audio.volume_db = -12.0
	transition_attack = make_audio("TransitionAttack")
	transition_attack.stream = TRANSITION_ATTACK
	transition_attack.volume_db = -6.0
	var layer := CanvasLayer.new()
	layer.name = "TransitionOverlay"
	layer.layer = 80
	add_child(layer)
	curtain = ColorRect.new()
	curtain.name = "ProceduralFlames"
	layer.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://Shaders/Qingqiu/phase_spirit_fire.gdshader")
	curtain.material = material
	curtain.visible = false
	var orbit_layer:=CanvasLayer.new();orbit_layer.layer=8;orbit_layer.name="OrbitStaging"
	add_child(orbit_layer)
	orbit_rect=ColorRect.new();orbit_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	orbit_layer.add_child(orbit_rect);orbit_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orbit_material=ShaderMaterial.new();orbit_material.shader=preload("res://Shaders/Qingqiu/orbit_stage.gdshader")
	orbit_rect.material=orbit_material;orbit_rect.visible=false
	cinematic=preload("res://Scripts/Qingqiu/phase_reveal_cinematic.gd").new()
	cinematic.name="PhaseRevealCinematic";add_child(cinematic)
	opening=preload("res://Scripts/Qingqiu/opening_mist_guest.gd").new()
	opening.name="OpeningMistGuest";add_child(opening)

func make_audio(label: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = "QingqiuSFX"
	add_child(player)
	return player

func request_phase(value: int) -> void:
	value = clampi(value, 1, 3)
	if is_busy():
		queued_phase = value
		return
	if value == arena.phase:
		return
	target_phase = value
	transition_elapsed = 0.0
	transition_duration = 2.2 if value == 3 else 1.9
	committed = false
	transition_active = true
	curtain.visible = true
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("intensity", 0.2 if reduced_effects else 1.0)
	var palette: Array = PALETTES[value - 1]
	for index in 4:
		material.set_shader_parameter(["ink_color", "flame_color", "edge_color", "core_color"][index], palette[index])
	arena.combat_audio.reset_combat()
	stop_voice()
	transition_attack_count += 1
	if audio_enabled:
		fire_audio.play()
		transition_attack.play()
	arena.charm_remaining = 0.0
	arena.player_feedback.reset()
	arena.get_node("FoxCharm").reset()
	arena.get_node("SpiritCombat").clear_transients()
	if arena.attacks!=null:arena.attacks.reset()

func is_busy() -> bool:
	return transition_active or intro_active or cub_departure_active or orbit_intro_active or (is_instance_valid(opening) and opening.active)

func begin_orbit_intro() -> void:
	if is_busy():return
	orbit_intro_active=true;orbit_intro_age=0.0
	orbit_rect.visible=true
	orbit_material.set_shader_parameter("progress",0.0)
	arena.spirit_combat.clear_transients()

func cancel_orbit_intro() -> void:
	if not orbit_intro_active and (orbit_rect==null or not orbit_rect.visible):return
	orbit_intro_active=false;orbit_intro_age=0.0
	if orbit_rect!=null:orbit_rect.visible=false
	focus_weight=0.0;arena.camera.fov=35.0

func update_orbit_intro(delta: float) -> void:
	orbit_intro_age+=delta
	var t:=clampf(orbit_intro_age/orbit_intro_duration,0.0,1.0)
	var zoom:=sin(t*PI)
	focus_weight=zoom*(.30 if reduced_effects else .85)
	arena.camera.fov=lerpf(35.0,31.0 if reduced_effects else 27.0,zoom)
	orbit_material.set_shader_parameter("progress",t)
	orbit_material.set_shader_parameter("reduced",1.0 if reduced_effects else 0.0)
	if t>=1.0:cancel_orbit_intro()

func begin_cub_departure(next_phase: int) -> void:
	if is_busy():return
	cub_origin=arena.boss_position()
	arena.attacks.reset()
	arena.spirit_combat.clear_transients()
	arena.player_feedback.reset()
	var form: Node3D=arena.forms.get_child(0)
	form.position.x=cub_origin.x;form.position.z=cub_origin.z
	form.get_node("FoxRig").clear_spirit_impact()
	cub_departure_active=true
	cub_departure_age=0.0
	cub_departure_next=next_phase
	cub_mist=preload("res://Scripts/Qingqiu/cub_departure_mist.gd").new()
	cub_mist.name="CubDefeatMist"
	cub_mist.position=cub_origin
	arena.add_child(cub_mist)
	cub_mist.set_process(false)
	arena.encounter.publish()

func update_cub_departure(delta: float) -> void:
	cub_departure_age+=delta
	var t:=clampf(cub_departure_age/cub_departure_duration,0.0,1.0)
	var form: Node3D=arena.forms.get_child(0)
	for part in form.get_node("FoxRig").layer_materials:
		part.set_shader_parameter("mist_dissolve",smoothstep(.06,.78,t))
	var shadow: GeometryInstance3D=form.get_node("ContactShadow")
	shadow.transparency=smoothstep(.05,.68,t)
	shadow.visible=t<.72
	if t>=.82:form.get_node("FoxRig").visible=false
	if t>=1.0:
		cub_departure_active=false
		request_phase(cub_departure_next)
		# request_phase resets attacks/visibility. Keep the defeated cub hidden
		# until the opaque curtain commits P2, so it cannot pop back into view.
		form.visible=false
		arena.encounter.publish()

func reset_cub_departure() -> void:
	cub_departure_active=false
	cub_departure_age=0.0
	if is_instance_valid(cub_mist):cub_mist.queue_free()
	cub_mist=null
	if not is_instance_valid(arena.forms):return
	var form: Node3D=arena.forms.get_child(0)
	form.visible=arena.phase==1
	form.get_node("FoxRig").visible=true
	for part in form.get_node("FoxRig").layer_materials:part.set_shader_parameter("mist_dissolve",0.0)
	var shadow: GeometryInstance3D=form.get_node("ContactShadow")
	shadow.transparency=0.0;shadow.visible=true

func begin_intro() -> void:
	if arena.phase==1:
		finish_reveal()
		return
	intro_active=true
	intro_elapsed=0.0
	intro_pulsed=false
	if arena.phase==3:
		cinematic.begin(3)
		intro_duration=cinematic.duration
	else:
		cinematic.stop()
		intro_duration=1.8
	if arena.phase==3 and arena.flora!=null:arena.flora.begin_bloom()
	var puppet=arena.forms.get_child(arena.phase-1).get_node("FoxRig")
	puppet.play_action("tail_unfurl_p%d"%arena.phase)
	reveal_light=arena.get_node("FoxForms/Phase2/BacklitMist/IvoryBacklight") if arena.phase==2 else arena.get_node("Atmosphere/FoxSoftLight")
	reveal_energy=reveal_light.light_energy

func finish_reveal() -> void:
	if is_instance_valid(cinematic):cinematic.stop()
	if arena.phase==3 and arena.flora!=null:arena.flora.finish_bloom()
	intro_active=false
	focus_weight=0.0
	arena.camera.fov=35.0
	if is_instance_valid(reveal_light):reveal_light.light_energy=reveal_energy
	reveal_light=null
	if arena.encounter!=null:arena.encounter.on_transition_finished()
	var next:=queued_phase
	queued_phase=0
	if next>0 and next!=arena.phase:request_phase(next)

func _process(delta: float) -> void:
	clock += delta
	if opening.active:
		opening.advance(delta)
		return
	trauma = maxf(0.0, trauma - delta * 1.8)
	var shake := trauma * trauma * (0.0 if reduced_effects else 1.0)
	arena.camera.h_offset = sin(clock * 53.0) * 0.18 * shake
	arena.camera.v_offset = sin(clock * 41.0 + 1.7) * 0.12 * shake
	if orbit_intro_active:update_orbit_intro(delta)
	if is_instance_valid(cub_mist):cub_mist.advance(delta)
	if cub_departure_active:
		update_cub_departure(delta)
		return
	if transition_active:
		transition_elapsed += delta
		material.set_shader_parameter("intensity", 0.2 if reduced_effects else 1.0)
		var progress := minf(1.0, transition_elapsed / transition_duration)
		material.set_shader_parameter("progress", progress)
		material.set_shader_parameter("clock", transition_elapsed)
		if not committed and progress >= 0.5:
			committed = true
			arena.set_phase(target_phase)
			reset_cub_departure()
			if target_phase==3 and arena.flora!=null:arena.flora.prepare_bloom(arena.boss_position())
			commit_count += 1
			if target_phase != 2: play_voice(target_phase)
			add_trauma(0.72)
		if progress >= 1.0:
			transition_active = false
			curtain.visible = false
			completed_count += 1
			begin_intro()
	if intro_active:
		intro_elapsed+=delta
		cinematic.advance(delta)
		var t:=minf(intro_elapsed/intro_duration,1.0)
		var zoom:=smoothstep(0.0,0.26,t)*(1.0-smoothstep(0.62,1.0,t))
		focus_weight=zoom*(0.25 if reduced_effects else 0.92)
		if not cinematic.active:arena.camera.fov=lerpf(35.0,31.0 if reduced_effects else 25.0,zoom)
		if is_instance_valid(reveal_light):reveal_light.light_energy=reveal_energy*(1.0+1.15*exp(-pow((t-0.34)/0.12,2.0)))
		if t>=0.33 and not intro_pulsed:
			intro_pulsed=true
			add_trauma(0.72)
			if arena.attacks!=null:
				var pulse=arena.attacks.create_scope(arena.boss_position(),4.3 if arena.phase==3 else 3.3,0,Color("#ffa400") if arena.phase==3 else Color("#bbcdc5"))
				pulse.active=true
				pulse.charge=1.0
				pulse.lifetime=1.15
		if t>=1.0:finish_reveal()

func play_voice(phase: int) -> void:
	phase = clampi(phase, 1, 3)
	voice.stream = VOICES[phase - 1]
	voice.volume_db = [-5.0, -1.0, -10.0][phase - 1]
	voice.pitch_scale = 1.0
	if audio_enabled: voice.play()
	voice_count += 1
	last_voice_phase = phase

func stop_voice() -> void:
	if is_instance_valid(voice): voice.stop()

func stop_sounds() -> void:
	for player in [voice, fire_audio, transition_attack]:
		if is_instance_valid(player): player.stop()
	if is_instance_valid(cinematic): cinematic.stop_audio()

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func toggle_mute() -> void:
	var bus := AudioServer.get_bus_index("QingqiuMusic")
	var muted := not AudioServer.is_bus_mute(bus) if bus >= 0 else true
	if bus >= 0: arena.combat_audio.set_music_muted(muted)
	var sfx_bus := AudioServer.get_bus_index("QingqiuSFX")
	if sfx_bus >= 0: AudioServer.set_bus_mute(sfx_bus, muted)

func cancel_transition() -> void:
	stop_sounds()
	if is_instance_valid(opening):opening.cancel()
	if is_instance_valid(cinematic):cinematic.stop()
	cancel_orbit_intro()
	reset_cub_departure()
	if arena.combat_audio != null: arena.combat_audio.reset_combat()
	if arena.flora!=null:arena.flora.finish_bloom()
	intro_active=false
	focus_weight=0.0
	arena.camera.fov=35.0
	if is_instance_valid(reveal_light):reveal_light.light_energy=reveal_energy
	reveal_light=null
	transition_active = false
	curtain.visible = false
	queued_phase = 0
	transition_elapsed = 0.0
	committed = false
	trauma = 0.0

func _exit_tree() -> void:
	stop_sounds()
	for player in [voice, fire_audio, transition_attack]:
		if is_instance_valid(player): player.stream = null
	if owns_sfx_bus:
		var bus := AudioServer.get_bus_index("QingqiuSFX")
		if bus > 0: AudioServer.remove_bus(bus)
	if is_instance_valid(arena.camera):
		arena.camera.h_offset = 0.0
		arena.camera.v_offset = 0.0
