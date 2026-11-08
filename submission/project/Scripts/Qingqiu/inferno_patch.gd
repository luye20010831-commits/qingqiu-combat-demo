extends Node3D
## Falling flame -> impact -> visible residual scorch. No warning/range mesh.
var radius:=4.2
var falling_seconds:=1.05
var residual_seconds:=4.0
var delay:=0.0
var damage:=14.0
var seed:=0.0
var elapsed:=0.0
var landed:=false
var finished:=false
var fire: MeshInstance3D
var ground: MeshInstance3D
var material: ShaderMaterial
var ground_material: ShaderMaterial
var arena
func _ready() -> void:
	arena=get_parent().arena
	fire=MeshInstance3D.new();fire.name="FallingBlackFlame"
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;fire.mesh=quad
	fire.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/inferno_flame.gdshader")
	material.set_shader_parameter("seed",seed);fire.material_override=material;add_child(fire)
	ground=MeshInstance3D.new();ground.name="ResidualScorch"
	var plane:=PlaneMesh.new();plane.size=Vector2.ONE*radius*2.3;ground.mesh=plane
	ground.position.y=.075;ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_material=ShaderMaterial.new();ground_material.shader=preload("res://Shaders/Qingqiu/inferno_scorch.gdshader")
	ground_material.set_shader_parameter("seed",seed);ground.material_override=ground_material
	add_child(ground);ground.visible=false;fire.visible=false
func contains(point: Vector3) -> bool:
	return Vector2(point.x-global_position.x,point.z-global_position.z).length()<=radius
func _process(delta: float) -> void:
	if finished:return
	if arena.phase!=2 or arena.encounter.state!=arena.encounter.State.RUNNING:
		finished=true;queue_free();return
	elapsed+=delta
	var age:=elapsed-delay
	if age<0.0:return
	fire.visible=true
	var falling:=age<falling_seconds
	var after:=maxf(0.0,age-falling_seconds)
	if not falling and not landed:
		landed=true;ground.visible=true
		arena.combat_audio.set_fire_source(self,true)
		if contains(arena.player.position):arena.encounter.damage_player(damage)
	if landed and after<=residual_seconds and contains(arena.player.position):
		arena.player_burn.apply(float(arena.encounter.phase_config.get("inferno_burn_seconds",4.0)))
	var fade:=1.0-smoothstep(residual_seconds,residual_seconds+.50,after)
	var impact:=1.0-smoothstep(0.0,.42,after)
	var width:=3.7 if falling else lerpf(radius*1.65,radius*1.25,smoothstep(0.0,.55,after))
	var height:=7.0 if falling else lerpf(6.5,2.0,smoothstep(0.0,.75,after))
	var altitude:=12.0*(1.0-pow(clampf(age/falling_seconds,0.0,1.0),1.8)) if falling else 0.0
	fire.global_basis=arena.camera.global_basis.scaled(Vector3(width,height,1.0))
	fire.global_position=global_position+Vector3.UP*altitude+arena.camera.global_basis.y*height*.5
	material.set_shader_parameter("clock",age*1.15);material.set_shader_parameter("opacity",fade)
	material.set_shader_parameter("impact",0.0 if falling else impact)
	ground_material.set_shader_parameter("clock",after);ground_material.set_shader_parameter("opacity",fade)
	ground_material.set_shader_parameter("impact",impact)
	if fade<=0.0:finished=true;queue_free()
