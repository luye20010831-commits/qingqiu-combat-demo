extends Node3D
## A filled, cel-painted ivory/gold flame, independent from the P2 ghost-fire.
var intensity:=1.0
var seed:=0.0
var clock:=0.0
var surface: MeshInstance3D
var material: ShaderMaterial
func _ready() -> void:
	surface=MeshInstance3D.new()
	surface.name="FilledFlame"
	var quad:=QuadMesh.new();quad.size=Vector2(2.65,3.8)
	surface.mesh=quad
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new()
	material.shader=preload("res://Shaders/Qingqiu/white_gold_fire.gdshader")
	material.set_shader_parameter("seed",seed)
	surface.material_override=material
	add_child(surface)
func _process(delta: float) -> void:
	clock+=delta
	var camera:=get_viewport().get_camera_3d()
	if camera:
		surface.global_basis=camera.global_basis.scaled(global_basis.get_scale())
		# Keep the bottom of the card rooted at the ground in screen space.
		surface.position=camera.global_basis.y*1.82+Vector3.UP*.04
	material.set_shader_parameter("clock",clock)
	material.set_shader_parameter("strength",intensity)
