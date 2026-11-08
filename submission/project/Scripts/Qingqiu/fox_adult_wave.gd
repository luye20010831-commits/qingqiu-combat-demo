extends Node3D
## Visible directional melee-magic wave, with swept wide contact and no floor decal.
var direction:=Vector3.FORWARD
var speed:=12.0
var damage:=14.0
var width:=1.5
var growth:=0.0
var max_width:=8.0
var variant:=0
var lifetime:=4.5
var elapsed:=0.0
var surface: MeshInstance3D
var material: ShaderMaterial
@onready var controller=get_parent()
func _ready() -> void:
	surface=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE
	surface.mesh=quad;surface.position.y=1.0;surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/fox_adult_wave.gdshader")
	material.set_shader_parameter("variant",float(variant));surface.material_override=material;add_child(surface)
func _process(delta: float) -> void:
	if controller.arena.encounter.state!=controller.arena.encounter.State.RUNNING:queue_free();return
	elapsed+=delta
	var before:=position
	position+=direction*speed*delta
	var span:=minf(width+growth*elapsed,max_width)
	var side:=Vector3(-direction.z,0,direction.x)
	var player: Vector3=controller.arena.player.position
	var nearest:=Geometry2D.get_closest_point_to_segment(Vector2(player.x,player.z),Vector2(before.x,before.z),Vector2(position.x,position.z))
	var offset:=Vector3(player.x-nearest.x,0,player.z-nearest.y)
	if absf(offset.dot(side))<=span*.5+.22 and absf(offset.dot(direction))<=.48:
		if controller.arena.encounter.damage_player(damage):
			controller.arena.combat_audio.emit_cue("fireball_contact",{"trigger":"accepted adult magic-wave contact"})
		queue_free()
	var camera: Camera3D=controller.arena.camera
	var back:=camera.global_basis.z
	var right: Vector3=side-back*side.dot(back)
	if right.length_squared()<.01:right=camera.global_basis.x
	right=right.normalized()
	surface.global_basis=Basis(right,back.cross(right).normalized(),back).scaled(Vector3(span,1.65,1.0))
	material.set_shader_parameter("clock",elapsed)
	material.set_shader_parameter("fade",smoothstep(0.0,.09,elapsed)*(1.0-smoothstep(lifetime-.3,lifetime,elapsed)))
	if elapsed>=lifetime or absf(position.x)>23.0 or absf(position.z)>23.0:queue_free()
