extends Node3D
## Defeat-only vapor: independent puffs spread away from the dissolving cub.
var age:=0.0
var duration:=1.45
var puffs: Array[Dictionary]=[]
func _ready() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=808
	for index in 18:
		var node:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE
		node.mesh=quad;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat:=ShaderMaterial.new();mat.shader=preload("res://Shaders/Qingqiu/cub_departure_mist.gdshader")
		mat.set_shader_parameter("seed",float(index)*1.41);mat.set_shader_parameter("opacity",rng.randf_range(.18,.30))
		node.material_override=mat;add_child(node)
		var start:=Vector3(rng.randf_range(-.75,.75),rng.randf_range(.35,1.7),rng.randf_range(-.3,.3))
		puffs.append({"node":node,"start":start,"velocity":Vector3(rng.randf_range(-.7,.9),rng.randf_range(.16,.50),rng.randf_range(-.55,.3)),"born":float(index%3)*.13,"size":rng.randf_range(1.1,1.7)})
	update_visuals()
func advance(delta: float) -> void:
	age+=delta;update_visuals()
func _process(delta: float) -> void:advance(delta)
func update_visuals() -> void:
	var camera:=get_viewport().get_camera_3d()
	for puff in puffs:
		var t:=maxf(0.0,age-float(puff["born"]));var life:=clampf(t/1.35,0.0,1.0)
		var node: MeshInstance3D=puff["node"]
		node.visible=age>=float(puff["born"]) and life<1.0
		node.position=puff["start"]+puff["velocity"]*t
		if camera:node.global_basis=camera.global_basis.scaled(Vector3.ONE*float(puff["size"])*(.65+life*.85))
		node.material_override.set_shader_parameter("age",life)
