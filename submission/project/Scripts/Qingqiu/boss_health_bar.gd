extends Control
## Health arrives from snapshots; _process only eases the visual damage echo.
var max_value:=100.0
var value:=100.0
var fill_color:=Color("#bbcdc5"):
	set(v):
		fill_color=v
		refresh()
var bar_material: ShaderMaterial
var surface: ColorRect
var motes: ColorRect
var mote_material: ShaderMaterial
var trail_fill:=1.0
var impact:=0.0
var echo_delay:=0.0
var initialized:=false

func _ready() -> void:
	custom_minimum_size=Vector2(0,32)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface=ColorRect.new()
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_material=ShaderMaterial.new()
	bar_material.shader=preload("res://Shaders/Qingqiu/boss_health_bar.gdshader")
	surface.material=bar_material
	motes=ColorRect.new()
	motes.name="RisingHealthMotes"
	motes.mouse_filter=Control.MOUSE_FILTER_IGNORE
	mote_material=ShaderMaterial.new()
	mote_material.shader=preload("res://Shaders/Qingqiu/boss_health_motes.gdshader")
	motes.material=mote_material
	add_child(motes)
	move_child(motes,0)
	resized.connect(refresh)
	refresh()
	set_process(false)

func set_health(current: float,maximum: float,instant:=false) -> void:
	var old_ratio:=clampf(value/maxf(max_value,1.0),0.0,1.0)
	var changed_max:=not is_equal_approx(max_value,maxf(maximum,1.0))
	max_value=maxf(maximum,1.0)
	value=clampf(current,0.0,max_value)
	var ratio:=value/max_value
	if instant or not initialized or changed_max or ratio>old_ratio:
		trail_fill=ratio
		impact=0.0
		echo_delay=0.0
	elif ratio<old_ratio:
		trail_fill=maxf(trail_fill,old_ratio)
		impact=1.0
		echo_delay=0.18
	initialized=true
	refresh()
	set_process(trail_fill-ratio>0.0001 or impact>0.0)

func _process(delta: float) -> void:
	var ratio:=clampf(value/max_value,0.0,1.0)
	echo_delay=maxf(0.0,echo_delay-delta)
	if echo_delay<=0.0:trail_fill=lerpf(trail_fill,ratio,1.0-exp(-6.0*delta))
	impact=maxf(0.0,impact-delta*3.6)
	if trail_fill-ratio<0.0004:
		trail_fill=ratio
		if impact==0.0:set_process(false)
	refresh()

func refresh() -> void:
	if bar_material==null:return
	bar_material.set_shader_parameter("fill",clampf(value/max_value,0.0,1.0))
	bar_material.set_shader_parameter("trail_fill",trail_fill)
	bar_material.set_shader_parameter("impact",impact)
	bar_material.set_shader_parameter("fill_color",fill_color)
	bar_material.set_shader_parameter("bar_size",Vector2(maxf(size.x,1.0),maxf(size.y,1.0)))

	if mote_material!=null:
		motes.position=Vector2(0,-28)
		motes.size=Vector2(maxf(size.x,1.0),64)
		mote_material.set_shader_parameter("effect_size",motes.size)
		mote_material.set_shader_parameter("fill",clampf(value/max_value,0.0,1.0))
		mote_material.set_shader_parameter("trail_fill",trail_fill)
		mote_material.set_shader_parameter("impact",impact)
		mote_material.set_shader_parameter("tint",fill_color)
		mote_material.set_shader_parameter("emitting",1.0 if value>0.0 or trail_fill>.001 else 0.0)
