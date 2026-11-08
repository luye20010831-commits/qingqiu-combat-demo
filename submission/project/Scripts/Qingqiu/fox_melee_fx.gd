extends Node3D
## Brief camera-facing claw streak or contact burst, never an attack-range decal.
var variant:=0.0
var confirmed:=false
var age:=0.0
var duration:=0.27
var surface: MeshInstance3D
var material: ShaderMaterial
func _ready() -> void:
	surface=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(1.5,1.2) if variant<0.5 else Vector2(1.8,1.8)
	surface.mesh=quad
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new()
	material.shader=preload("res://Shaders/Qingqiu/fox_melee.gdshader")
	material.set_shader_parameter("variant",variant)
	material.set_shader_parameter("confirmed",1.0 if confirmed else 0.0)
	surface.material_override=material
	add_child(surface)
func _process(delta: float) -> void:
	age+=delta
	var camera:=get_viewport().get_camera_3d()
	if camera:surface.global_basis=camera.global_basis
	material.set_shader_parameter("progress",minf(age/duration,1.0))
	if age>=duration:queue_free()
