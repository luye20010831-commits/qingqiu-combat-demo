@tool
extends Node3D
## One self-contained billboard flame, palette light and ground spill.
const Palettes := preload("res://Scripts/Qingqiu/ghost_fire_palettes.gd")
@export_enum("幽碧","花青","松柏","竹青","橙金","绯红","月白","白红","自定义") var palette_variant := 0:
	set(value):
		palette_variant = clampi(value,0,8)
		if is_node_ready(): Palettes.apply_to(self,palette_variant)
@export_range(0.2,2.0) var intensity := 1.0
@export_range(0.1,3.0) var flow_speed := 1.0
@export_range(-1.0,1.0) var wind := 0.0
@export_range(0.0,1.0) var curl_amount := 0.65
@export_range(0.001,0.06) var outline_width := 0.014
@export_range(0.0,0.7) var halo_strength := 0.24
@export_range(0.0,1.0) var ember_amount := 0.75
@export_range(0.0,1.5) var light_energy := 0.65
@export var animate := true
@export var seed := 1.7
@export_range(0.5,2.0) var hover_height := 1.4
@export_group("色卡")
@export var outline_color := Color("#003472")
@export var outer_color := Color("#1685a9")
@export var inner_color := Color("#1bd1a5")
@export var core_color := Color("#70f3ff")
@export var glint_color := Color("#bbcdc5")
var elapsed := 0.0
var flame_material: ShaderMaterial
var pool_material: ShaderMaterial

func _ready() -> void:
	Palettes.apply_to(self,palette_variant)
	flame_material = $Flame.material_override.duplicate()
	flame_material.resource_local_to_scene = true
	$Flame.material_override = flame_material
	pool_material = $GroundSpill.material_override.duplicate()
	pool_material.resource_local_to_scene = true
	$GroundSpill.material_override = pool_material
	update_effect(0.0)

func set_palette(index: int) -> void:
	palette_variant = index
	update_effect(0.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if animate:
		elapsed += delta
	update_effect(delta)

func update_effect(_delta: float) -> void:
	if flame_material == null:
		return
	for parameter in ["intensity","flow_speed","wind","curl_amount","outline_width","halo_strength","ember_amount","seed","outline_color","outer_color","inner_color","core_color","glint_color"]:
		flame_material.set_shader_parameter(parameter,get(parameter))
	flame_material.set_shader_parameter("effect_time",elapsed)
	$Flame.position.y = hover_height + sin(elapsed*flow_speed*1.8+seed)*0.045
	var camera := get_viewport().get_camera_3d()
	if camera:
		# Account for arena instance scale while facing the actual game camera.
		var size := global_basis.get_scale()
		$Flame.global_basis = camera.global_basis.scaled(size)
	var breathing := 0.92 + sin(elapsed*flow_speed*3.2)*0.08
	$GhostLight.light_color = inner_color
	$GhostLight.light_energy = light_energy*intensity*breathing
	pool_material.set_shader_parameter("pool_color",inner_color)
	pool_material.set_shader_parameter("energy",0.18*intensity*breathing)
