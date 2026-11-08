extends Node
## Real damage only: P1 full-screen red, P2 black border fire, P3 red/white fire.
@onready var arena=get_parent()
var material: ShaderMaterial
var screen: ColorRect
var remaining:=0.0
var duration:=0.0
var peak:=0.0
var flash_count:=0
var heavy_hit_count:=0
var last_tier:=0
var last_fraction:=0.0
var last_shake:=0.0
var hit_phase:=1
func _ready() -> void:
	var layer:=CanvasLayer.new()
	layer.name="PhaseDamageOverlay"
	layer.layer=40
	add_child(layer)
	screen=ColorRect.new()
	screen.name="PhaseDamageFire"
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=ShaderMaterial.new()
	material.shader=preload("res://Shaders/Qingqiu/player_phase_hit.gdshader")
	screen.material=material
	screen.visible=false
func show_hit(amount: float,max_health: float,config: Dictionary) -> void:
	if amount<=0.0 or max_health<=0.0:return
	arena.player_avatar.notify_hit()
	last_fraction=amount/max_health
	var heavy_threshold:=float(config["heavy_damage_fraction"])
	var extreme_threshold:=float(config["extreme_damage_fraction"])
	last_tier=2 if last_fraction+0.000001>=extreme_threshold else (1 if last_fraction+0.000001>=heavy_threshold else 0)
	hit_phase=arena.phase
	var times: Array=config.get("phase_screen_seconds",[0.40,0.90,1.0])
	duration=float(times[hit_phase-1])+last_tier*0.08
	remaining=duration
	peak=[0.72,0.88,1.0][last_tier]
	material.set_shader_parameter("hit_color",Color(config["red_color"]))
	material.set_shader_parameter("phase_index",hit_phase)
	material.set_shader_parameter("age",0.0)
	material.set_shader_parameter("strength",peak)
	material.set_shader_parameter("reduced",1.0 if arena.presentation.reduced_effects else 0.0)
	screen.visible=true
	flash_count+=1
	last_shake=0.0
	if last_tier>0:
		var intensity:=clampf((last_fraction-heavy_threshold)/maxf(extreme_threshold-heavy_threshold,0.001),0.0,1.0)
		last_shake=lerpf(float(config["heavy_shake_trauma"]),float(config["extreme_shake_trauma"]),intensity)
		arena.presentation.add_trauma(last_shake)
		heavy_hit_count+=1
func _process(delta: float) -> void:
	if remaining<=0.0:return
	remaining=maxf(0.0,remaining-delta)
	if remaining<=0.0:
		reset()
		return
	var progress:=1.0-remaining/duration
	var fade:=1.0-smoothstep(0.12,1.0,progress)
	material.set_shader_parameter("strength",peak*fade)
	material.set_shader_parameter("age",duration-remaining)
	material.set_shader_parameter("reduced",1.0 if arena.presentation.reduced_effects else 0.0)
func reset() -> void:
	remaining=0.0
	if is_instance_valid(material):material.set_shader_parameter("strength",0.0)
	if is_instance_valid(screen):screen.visible=false
