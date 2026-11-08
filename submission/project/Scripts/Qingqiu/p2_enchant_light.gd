extends Node3D
## Real rose/violet lights confined to P2 fox art, with a quiet breathing pulse.
const FOX_LIGHT_LAYER=8
var rose: OmniLight3D
var violet: OmniLight3D
var clock:=0.0
@onready var arena=get_parent().get_parent().get_parent()
func _ready() -> void:
	for part in get_parent().get_node("FoxRig").find_children("*","GeometryInstance3D",true,false):
		part.layers|=FOX_LIGHT_LAYER
	rose=make_light("RoseFoxGlow",Color("#dca5be"),Vector3(.4,2.5,2.3),1.45)
	violet=make_light("VioletFoxGlow",Color("#a780ba"),Vector3(-1.7,1.7,.8),1.30)
func make_light(label: String,color: Color,point: Vector3,energy: float) -> OmniLight3D:
	var light:=OmniLight3D.new();light.name=label;light.light_color=color
	light.position=point;light.light_energy=energy;light.omni_range=4.8
	light.omni_attenuation=1.4;light.light_cull_mask=FOX_LIGHT_LAYER
	light.light_volumetric_fog_energy=0.0;light.shadow_enabled=false
	add_child(light);return light
func _process(delta: float) -> void:
	clock+=delta
	var opacity:=1.0
	if arena.attacks!=null and arena.phase==2:opacity=arena.attacks.vanish_alpha
	rose.light_energy=1.45*(.94+.06*sin(clock*1.6))*opacity
	violet.light_energy=1.30*(.94+.06*sin(clock*1.3+1.7))*opacity
