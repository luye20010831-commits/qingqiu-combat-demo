extends Node3D
## Attached P2 burn persists off the scorch; refreshes without stacking damage.
@onready var arena=get_parent()
var remaining:=0.0
var tick_remaining:=1.0
var clock:=0.0
var ticks:=0
var applications:=0
var surfaces: Array[MeshInstance3D]=[]
func _ready() -> void:
	for index in 2:
		var surface:=MeshInstance3D.new();surface.name="AttachedBlackFlame%d"%index
		var quad:=QuadMesh.new();quad.size=Vector2.ONE;surface.mesh=quad
		surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/inferno_flame.gdshader")
		material.set_shader_parameter("seed",float(index)*2.3)
		surface.material_override=material;add_child(surface);surfaces.append(surface)
	visible=false
func apply(seconds: float) -> bool:
	if arena.phase!=2 or arena.encounter.state!=arena.encounter.State.RUNNING or arena.dash_remaining>0.0 or arena.presentation.is_busy():return false
	if remaining<=0.0:tick_remaining=1.0;applications+=1
	remaining=maxf(remaining,seconds);visible=true;update_visual()
	arena.combat_audio.set_fire_source(self,true,true)
	return true
func reset() -> void:
	remaining=0.0;tick_remaining=1.0;visible=false
	if is_instance_valid(arena.combat_audio):arena.combat_audio.set_fire_source(self,false)
func _process(delta: float) -> void:
	if arena.encounter==null:return
	if arena.phase!=2 or arena.encounter.state!=arena.encounter.State.RUNNING:
		reset();return
	if remaining<=0.0:return
	clock+=delta
	var active_step:=minf(delta,remaining)
	remaining=maxf(0.0,remaining-delta);tick_remaining-=active_step
	while tick_remaining<=0.000001:
		tick_remaining+=1.0
		if arena.encounter.damage_player(float(arena.encounter.phase_config.get("inferno_burn_damage_per_second",2.5)),true):ticks+=1
		if arena.encounter.state!=arena.encounter.State.RUNNING:break
	if remaining<=0.0:reset();return
	update_visual()
func update_visual() -> void:
	var camera: Camera3D=arena.camera
	var foot: Vector3=arena.player.global_position
	for index in surfaces.size():
		var surface:=surfaces[index]
		surface.global_basis=camera.global_basis.scaled(Vector3(.36,.50,1.0))
		surface.global_position=foot+camera.global_basis.x*(float(index)*.24-.12)+camera.global_basis.y*.28
		surface.set_instance_shader_parameter("foot_sort_anchor",Vector4(foot.x,foot.y,foot.z,1.0))
		surface.set_instance_shader_parameter("foot_sort_bias",.13)
		surface.material_override.set_shader_parameter("clock",clock+float(index))
		surface.material_override.set_shader_parameter("opacity",.72*minf(remaining/.35,1.0))
