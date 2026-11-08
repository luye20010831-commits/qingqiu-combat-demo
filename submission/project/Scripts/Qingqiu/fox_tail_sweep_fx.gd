extends Node3D
## A moving gust behind the actual stroke, never a warning ring.
var age:=0.0
var material: ShaderMaterial
func _ready() -> void:
	var surface:=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=Vector2.ONE*5.4
	surface.mesh=plane
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/tail_sweep.gdshader")
	surface.material_override=material;add_child(surface)
func _process(delta: float) -> void:
	age+=delta
	material.set_shader_parameter("progress",age)
	if age>=.50:queue_free()
