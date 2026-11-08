extends Node3D
## P1: one persistent homing heart. P3: four locked-direction hearts.
## Swept contact: ward cancels either heart; P1 briefly compels approach.
var source_phase:=3
var homing:=false
var homing_turn_speed:=8.0
var charm_strength:=1.0
var with_beacon:=true
var visual_scale:=1.0
var launch_height:=2.15
var direction:=Vector3.FORWARD
var speed:=6.0
var radius:=.34
var lifetime:=6.5
var charm_seconds:=8.0
var elapsed:=0.0
var resolved:=false
var surface: MeshInstance3D
var material: ShaderMaterial
var aura: MeshInstance3D
var aura_material: ShaderMaterial
@onready var controller=get_parent()
func _ready() -> void:
	surface=MeshInstance3D.new();surface.name="CharmHeart"
	var quad:=QuadMesh.new();quad.size=Vector2(1.20,1.40);surface.mesh=quad
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/charm_heart_projectile.gdshader")
	surface.material_override=material;add_child(surface)
	aura=MeshInstance3D.new();aura.name="HeartAura"
	var glow_quad:=QuadMesh.new();glow_quad.size=Vector2(2.0,2.2);aura.mesh=glow_quad
	aura.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura_material=ShaderMaterial.new();aura_material.shader=preload("res://Shaders/Qingqiu/charm_heart_aura.gdshader")
	aura_material.render_priority=-1;aura.material_override=aura_material;add_child(aura)
	update_visual()
func _process(delta: float) -> void:
	if resolved:return
	var arena=controller.arena
	if arena.encounter.state!=arena.encounter.State.RUNNING or arena.phase!=source_phase:
		resolved=true;queue_free();return
	elapsed+=delta
	var before:=Vector2(position.x,position.z)
	var player: Vector3=arena.player.position
	if homing:
		var target:=Vector3(player.x-position.x,0,player.z-position.z)
		if target.length_squared()>.0001:
			var yaw:=lerp_angle(atan2(direction.x,direction.z),atan2(target.x,target.z),1.0-exp(-homing_turn_speed*delta))
			direction=Vector3(sin(yaw),0,cos(yaw))
	position+=direction*speed*delta
	var nearest:=Geometry2D.get_closest_point_to_segment(Vector2(player.x,player.z),before,Vector2(position.x,position.z))
	if nearest.distance_to(Vector2(player.x,player.z))<=radius+.24:
		if arena.dash_remaining<=0 and not arena.presentation.is_busy() and arena.spirit_combat.ward_remaining<=0.0:
			if source_phase==1:arena.apply_charm(charm_seconds)
			controller.apply_vision_charm(charm_seconds,charm_strength,with_beacon)
		resolved=true;queue_free();return
	update_visual()
	if (lifetime>0 and elapsed>=lifetime) or (not homing and (absf(position.x)>23 or absf(position.z)>23)):resolved=true;queue_free()

func update_visual() -> void:
	var arena=controller.arena
	var pulse: float=(1.0+.025*sin(elapsed*3.2))*visual_scale
	surface.global_basis=arena.camera.global_basis.scaled(Vector3.ONE*pulse)
	surface.position.y=lerpf(launch_height,1.0,smoothstep(0,.40,elapsed))
	aura.global_basis=surface.global_basis
	aura.global_position=surface.global_position-arena.camera.global_basis.z*.015
	var alpha:=smoothstep(0,.08,elapsed)*(1.0-smoothstep(lifetime-.3,lifetime,elapsed) if lifetime>0 else 1.0)
	for shader in [material,aura_material]:
		shader.set_shader_parameter("clock",elapsed);shader.set_shader_parameter("fade",alpha)
