extends Node
## Foot-based occlusion shared by scenery and registered character cutouts.
## World positions, collisions, authored art and skeletal transforms stay intact.
var entries: Array[Dictionary]=[]
var enabled:=true
@onready var arena=get_parent()
func _ready() -> void:
	process_priority=15
	for group in ["Trees","JadeRocks","GrassAndFlowers"]:
		for sprite in arena.get_node(group).find_children("*","Sprite3D",true,false):
			if sprite.material_override is ShaderMaterial and sprite.material_override.shader.resource_path.ends_with("ink_prop.gdshader"):
				register(sprite,sprite.get_parent(),.02)
	for form in arena.forms.get_children():
		for part in form.get_node("FoxRig").get_children():
			if part is MeshInstance3D:register(part,form,.04+float(part.get_index())*.001)
	for flower in arena.flora.flowers:
		register(flower,null,.015,Vector3(flower.position.x,0,flower.position.z))
	for flower in arena.flora.withered:
		register(flower,null,.015,Vector3(flower.position.x,0,flower.position.z))
	var player_material:=ShaderMaterial.new()
	player_material.shader=preload("res://Shaders/Qingqiu/hunter_depth_card.gdshader")
	player_material.set_shader_parameter("sprite_texture",arena.player_sprite.texture)
	arena.player_sprite.material_override=player_material
	register(arena.player_sprite,arena.player,.045)
	refresh()
func register(mesh: GeometryInstance3D,anchor: Node3D,bias: float,static_point:=Vector3.ZERO) -> void:
	entries.append({"mesh":mesh,"anchor":anchor,"bias":bias,"point":static_point})
func refresh() -> void:
	for entry in entries:
		var mesh: GeometryInstance3D=entry.mesh
		var point: Vector3=entry.anchor.global_position if is_instance_valid(entry.anchor) else entry.point
		mesh.set_instance_shader_parameter("foot_sort_anchor",Vector4(point.x,point.y,point.z,1.0 if enabled else 0.0))
		mesh.set_instance_shader_parameter("foot_sort_bias",entry.bias)
func _process(_delta: float) -> void:refresh()
