extends Node3D
var radius:=1.5
var shape:=0
var half_angle:=0.95
var color:=Color("#1685a9")
var lifetime:=0.0
var elapsed:=0.0
var material: ShaderMaterial
var charge:=0.0
var active:=false
func _ready() -> void:
	var surface:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2.ONE*radius*2.5
	surface.mesh=plane
	surface.position.y=0.045
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new()
	material.shader=preload("res://Shaders/Qingqiu/attack_flame_scope.gdshader")
	material.set_shader_parameter("danger_color",color)
	material.set_shader_parameter("ink_color",Color("#392f41"))
	material.set_shader_parameter("scope_shape",shape)
	material.set_shader_parameter("half_angle",half_angle)
	surface.material_override=material
	add_child(surface)
func _process(delta: float) -> void:
	elapsed+=delta
	material.set_shader_parameter("effect_time",elapsed)
	material.set_shader_parameter("charge",charge)
	material.set_shader_parameter("active",1.0 if active else 0.0)
	if lifetime>0.0:
		material.set_shader_parameter("fade",clampf((lifetime-elapsed)/0.3,0.0,1.0))
		if elapsed>=lifetime:queue_free()
func contains(world_position: Vector3,extra_radius:=0.0) -> bool:
	var p:=to_local(world_position)
	if Vector2(p.x,p.z).length()>radius+extra_radius:return false
	return shape==0 or absf(atan2(p.x,p.z))<=half_angle
