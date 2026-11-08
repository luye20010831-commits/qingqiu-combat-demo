extends Node3D
var direction:=Vector3.FORWARD
var speed:=3.4
var radius:=0.42
var damage:=10.0
var lifetime:=4.6
var curve:=0.0
var palette:=0
var elapsed:=0.0
var motion: Dictionary={}
var current_speed:=0.0
var flame: Node3D
var ground_scope
var ribbon: MeshInstance3D
var orbiting:=false
var orbit_origin:=Vector3.ZERO
var orbit_angle:=0.0
var angular_speed:=-0.24
var radial_speed:=4.0
var filled_fire:=false
@onready var controller=get_parent()
func _ready() -> void:
	if filled_fire:
		flame=preload("res://Scripts/Qingqiu/white_gold_fire.gd").new()
		flame.seed=float(get_instance_id()%97)*.13
		flame.scale=Vector3.ONE*.15
		add_child(flame)
	else:
		flame=preload("res://Scenes/Qingqiu/Effects/GhostFire.tscn").instantiate()
		add_child(flame)
		flame.set_palette(palette)
		flame.scale=Vector3.ONE*.25
		flame.light_energy=0.0
		flame.get_node("GroundSpill").visible=false
		flame.seed=float(get_instance_id()%97)*.13
		flame.update_effect(0.0)
	ground_scope=preload("res://Scripts/Qingqiu/attack_scope.gd").new()
	ground_scope.radius=radius
	ground_scope.active=true
	ground_scope.charge=1.0
	ground_scope.color=Color("#c32136") if palette in [5,7] else Color("#70f3ff")
	add_child(ground_scope)
	ground_scope.visible=false
	current_speed=speed*speed_multiplier(0.0)

func speed_multiplier(time: float) -> float:
	var launch:=float(motion.get("launch_multiplier",0.60))
	var cruise:=float(motion.get("cruise_multiplier",1.90))
	var peak:=float(motion.get("burst_multiplier",3.10))
	var delay:=float(motion.get("burst_delay",0.18))
	var rise:=maxf(float(motion.get("acceleration_seconds",0.14)),0.01)
	var hold:=float(motion.get("burst_seconds",0.26))
	var settle:=maxf(float(motion.get("settle_seconds",0.18)),0.01)
	if time<delay:return launch
	if time<delay+rise:return lerpf(launch,peak,smoothstep(0.0,1.0,(time-delay)/rise))
	if time<delay+rise+hold:return peak
	return lerpf(peak,cruise,smoothstep(0.0,1.0,(time-delay-rise-hold)/settle))

func _process(delta: float) -> void:
	if controller.arena.encounter.state!=controller.arena.encounter.State.RUNNING:
		queue_free()
		return
	var old_elapsed:=elapsed
	elapsed+=delta
	var before:=Vector2(position.x,position.z)
	var movement:=direction.rotated(Vector3.UP,sin(elapsed*2.4)*curve)
	current_speed=speed*speed_multiplier(elapsed)
	if orbiting:
		var angle:=orbit_angle+angular_speed*elapsed
		var spread:=1.3+radial_speed*elapsed
		position=orbit_origin+Vector3(sin(angle),0,cos(angle))*spread
	else:
		position+=movement*(current_speed+speed*speed_multiplier(old_elapsed))*0.5*delta
	var after:=Vector2(position.x,position.z)
	var player: Vector3=controller.arena.player.position
	var nearest:=Geometry2D.get_closest_point_to_segment(Vector2(player.x,player.z),before,after)
	if nearest.distance_to(Vector2(player.x,player.z))<=radius+0.24:
		if controller.arena.encounter.damage_player(damage):
			controller.arena.combat_audio.emit_cue("fireball_contact",{"trigger":"accepted ghost-fire projectile contact"})
		queue_free()
	if elapsed>=lifetime or absf(position.x)>22.0 or absf(position.z)>22.0:queue_free()
