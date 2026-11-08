extends Control
## Canvas port of the user's Survivor monster orb, with snapshot-driven fill.
var max_value:=100.0
var value:=100.0
var show_particles:=true
var surface: ColorRect
var motes: ColorRect
var bar_material: ShaderMaterial
var mote_material: ShaderMaterial
var orbit_back: ColorRect
var orbit_clouds: ColorRect
var surface_mist: ColorRect

func _ready() -> void:
	custom_minimum_size=Vector2(172,172)
	size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface=ColorRect.new()
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_material=ShaderMaterial.new()
	bar_material.shader=preload("res://Shaders/Qingqiu/player_health_orb.gdshader")
	bar_material.set_shader_parameter("treatment",1)
	surface.material=bar_material
	motes=ColorRect.new()
	motes.mouse_filter=Control.MOUSE_FILTER_IGNORE
	motes.size=Vector2(110,66)
	add_child(motes)
	mote_material=ShaderMaterial.new()
	mote_material.shader=preload("res://Shaders/Qingqiu/health_tip_motes.gdshader")
	mote_material.set_shader_parameter("tint",Color("#c32136"))
	motes.material=mote_material
	orbit_back=cloud_layer(0.0,0.0)
	orbit_back.name="OrbitCloudsBack"
	move_child(orbit_back,0)
	orbit_clouds=cloud_layer(0.0,1.0)
	orbit_clouds.name="OrbitClouds"
	surface_mist=cloud_layer(1.0)
	surface_mist.name="SurfaceMist"
	resized.connect(refresh)
	refresh()

func cloud_layer(kind: float,pass_index:=1.0) -> ColorRect:
	var node:=ColorRect.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=ShaderMaterial.new()
	shader.shader=preload("res://Shaders/Qingqiu/health_orb_clouds.gdshader")
	shader.set_shader_parameter("mist_layer",kind)
	shader.set_shader_parameter("orbit_pass",pass_index)
	shader.set_shader_parameter("canvas_scale",1.0 if kind>0.5 else 1.30)
	node.material=shader
	add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

func set_health(current: float,maximum: float) -> void:
	max_value=maxf(maximum,1.0)
	value=clampf(current,0.0,max_value)
	refresh()

func refresh() -> void:
	if bar_material==null:return
	var ratio:=clampf(value/max_value,0.0,1.0)
	bar_material.set_shader_parameter("health_ratio",ratio)
	# Preserve the requested rising motes, now along the orb's liquid surface.
	motes.position=Vector2((size.x-motes.size.x)*0.5,size.y*lerpf(0.92,0.08,ratio)-54.0)
	var emitting:=show_particles and ratio>0.0 and ratio<0.999
	mote_material.set_shader_parameter("emitting",1.0 if emitting else 0.0)
	motes.visible=emitting

	for node in [orbit_back,orbit_clouds]:
		if is_instance_valid(node):
			node.offset_left=-26;node.offset_top=-26
			node.offset_right=26;node.offset_bottom=26
			node.material.set_shader_parameter("canvas_scale",(size.x+52.0)/maxf(size.x,1.0))
