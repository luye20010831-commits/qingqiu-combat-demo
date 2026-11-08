extends Node
## Real-world P1 entrance. Visual-only staging; encounter clocks stay stopped.
const DURATION:=4.6
@onready var presentation=get_parent()
var active:=false
var age:=0.0
var shot:=""
var events: Array[Dictionary]=[]
var landed:=false
var voice_fired := false
var layer: CanvasLayer
var root_control: Control
var veil: ColorRect
var title: VBoxContainer
var skip_hint: Label
var stage: Node3D
var banks: Array[MeshInstance3D]=[]
var landing: MeshInstance3D
var form: Node3D
var rig
var saved: Dictionary={}

func _ready() -> void:
	layer=CanvasLayer.new();layer.name="OpeningOverlay";layer.layer=75;add_child(layer)
	root_control=Control.new();root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil=ColorRect.new();veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;root_control.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://Shaders/Qingqiu/opening_veil.gdshader");veil.material=ink
	title=VBoxContainer.new();title.mouse_filter=Control.MOUSE_FILTER_IGNORE;root_control.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	title.offset_left=120;title.offset_right=720;title.offset_top=-244;title.offset_bottom=-120
	title.add_theme_constant_override("separation",8)
	title.add_child(make_label("青丘 · 雾中来客",42))
	title.add_child(make_label("单尾幼狐",22))
	skip_hint=make_label("Enter / 左键  跳过",18);root_control.add_child(skip_hint)
	skip_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_hint.offset_left=-310;skip_hint.offset_right=-64;skip_hint.offset_top=84;skip_hint.offset_bottom=116
	skip_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	layer.visible=false

func make_label(text: String,size: int) -> Label:
	var label:=Label.new();label.text=text;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",Color("#bbcdc5"))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.85));label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2)
	return label

func begin() -> void:
	voice_fired = false
	cancel()
	var arena=presentation.arena
	form=arena.forms.get_child(0);rig=form.get_node("FoxRig")
	saved={"rig_process":rig.is_processing(),"attacks_process":arena.attacks.is_processing(),"interface":arena.get_node("Presentation").visible,"hud":arena.encounter.hud.visible,"dev":arena.developer_test.visible,"blink":rig.blink_enabled}
	active=true;age=0;shot="";landed=false;events.clear()
	rig.set_process(false);rig.stop_action();rig.blink_enabled=false
	arena.attacks.set_process(false);arena.attacks.fox_height=0
	arena.get_node("Presentation").visible=false;arena.encounter.hud.visible=false;arena.developer_test.visible=false
	presentation.trauma=0;arena.camera.h_offset=0;arena.camera.v_offset=0
	stage=Node3D.new();stage.name="OpeningGroundEffects";arena.add_child(stage)
	for index in 2:
		var bank:=MeshInstance3D.new();bank.name="PartingMist%d"%index
		var plane:=PlaneMesh.new();plane.size=Vector2(10.5,7.0);bank.mesh=plane
		bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/opening_ground_mist.gdshader")
		material.set_shader_parameter("seed",float(index)*2.7);bank.material_override=material
		stage.add_child(bank);banks.append(bank)
	landing=MeshInstance3D.new();landing.name="OpeningLandingBlossom"
	var mark:=PlaneMesh.new();mark.size=Vector2.ONE*3.6;landing.mesh=mark
	landing.position=Vector3(0,.07,0);landing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blossom:=ShaderMaterial.new();blossom.shader=preload("res://Shaders/Qingqiu/fox_foot_blossom.gdshader")
	blossom.set_shader_parameter("tint",Color("#bbcdc5"));blossom.set_shader_parameter("opacity",.72)
	landing.material_override=blossom;stage.add_child(landing);landing.visible=false
	layer.visible=true
	advance(0)

func set_shot(value: String) -> void:
	if shot==value:return
	shot=value;events.append({"shot":shot,"at":age})
	if value=="leap":rig.play_action("cub_hop")
	elif value=="gaze":rig.play_action("cub_charm_windup",.7)
	elif value=="return":rig.stop_action()

func advance(delta: float) -> void:
	if not active:return
	var arena=presentation.arena
	if arena.encounter.state!=arena.encounter.State.OPENING:
		cancel();return
	age=minf(age+delta,DURATION)
	if age>=DURATION-.0001:age=DURATION
	set_shot("mist" if age<.88 else "leap" if age<1.62 else "gaze" if age<2.85 else "return")
	var travel:=smoothstep(1.00,1.45,age)
	form.position=Vector3(-1.6,0,-3.8).lerp(Vector3.ZERO,travel)
	var airborne:=clampf((age-1.0)/.58,0,1)
	arena.attacks.fox_height=sin(airborne*PI)*.55 if age<1.58 else 0.0
	form.position.y=arena.attacks.fox_height
	form.get_node("ContactShadow").position.y=.018-form.position.y
	rig.set_charm_charge(smoothstep(1.85,2.4,age)*(1.0-smoothstep(2.55,2.95,age))*.22)
	rig._process(delta)
	var head: int=rig.skeleton.find_bone("head")
	if head>=0:
		var nod:=sin(smoothstep(1.8,2.8,age)*PI)*deg_to_rad(-3.5)
		rig.skeleton.set_bone_pose_rotation(head,rig.skeleton.get_bone_pose_rotation(head)*Quaternion(Vector3.BACK,nod))
	for material in rig.layer_materials:material.set_shader_parameter("mist_dissolve",1.0-smoothstep(.50,1.15,age))
	if age>=1.58 and not landed:
		landed=true;events.append({"kind":"landing","at":age})
	if age >= 2.0 and not voice_fired:
		voice_fired = true
		presentation.play_voice(1)
		events.append({"kind":"cub_voice", "at":age})
	landing.visible=landed and age<2.40
	landing.material_override.set_shader_parameter("progress",clampf((age-1.58)/.82,0,1))
	var part:=smoothstep(.48,2.1,age)
	var fade:=1.0-smoothstep(2.65,4.1,age)
	for index in banks.size():
		var side: float=-1.0 if index==0 else 1.0
		banks[index].position=Vector3(side*lerpf(1.3,7.2,part),.13+float(index)*.035,-1.3+float(index)*1.1)
		banks[index].material_override.set_shader_parameter("clock",age)
		banks[index].material_override.set_shader_parameter("opacity",fade*(.30 if presentation.reduced_effects else .52))
	veil.material.set_shader_parameter("darkness",1.0-smoothstep(0,.70,age))
	var closing:=1.0-smoothstep(3.15,DURATION,age)
	veil.material.set_shader_parameter("bars",closing)
	veil.material.set_shader_parameter("vignette",.26*closing)
	title.modulate.a=smoothstep(1.45,1.95,age)*(1.0-smoothstep(2.85,3.6,age))
	skip_hint.modulate.a=smoothstep(.25,.7,age)*closing
	apply_camera()
	if age>=DURATION:finish(false)

func apply_camera() -> void:
	if not active:return
	var arena=presentation.arena
	var reduced: bool=presentation.reduced_effects
	var close:=smoothstep(0,1.7,age)
	var start:=Vector3(-5.5,10.5,18.5) if not reduced else Vector3(-2,12.0,21)
	var hero:=Vector3(-2.2,6.8,11.2) if not reduced else Vector3(-1.0,9.5,15.2)
	var point:=start.lerp(hero,close)
	var look:=Vector3(-.25,1.1,-.7).lerp(Vector3(0,1.15,0),close)
	var back:=smoothstep(2.85,DURATION,age)
	var offset: Vector3=arena.CAMERA_LOOK_OFFSET+(arena.CAMERA_OFFSET-arena.CAMERA_LOOK_OFFSET)*arena.camera_distance_scale
	point=point.lerp(arena.player.position+offset,back)
	look=look.lerp(arena.player.position+arena.CAMERA_LOOK_OFFSET,back)
	arena.camera.position=point;arena.camera.look_at(look)
	arena.camera.fov=lerpf(35.0,32.5 if not reduced else 35.0,close*(1.0-back))

func finish(skipped: bool) -> void:
	if not active:return
	events.append({"kind":"skipped" if skipped else "completed","at":age})
	var encounter=presentation.arena.encounter
	reset_staging()
	encounter.finish_opening()

func cancel() -> void:
	if active:reset_staging()

func reset_staging() -> void:
	active=false
	var arena=presentation.arena
	layer.visible=false
	if is_instance_valid(stage):stage.queue_free()
	stage=null;banks.clear();landing=null
	if is_instance_valid(form):
		form.position=Vector3.ZERO;form.get_node("ContactShadow").position.y=.018
	if is_instance_valid(rig):
		for material in rig.layer_materials:material.set_shader_parameter("mist_dissolve",0.0)
		rig.set_charm_charge(0);rig.reset_locomotion();rig.blink_enabled=bool(saved.get("blink",true))
		rig.set_process(bool(saved.get("rig_process",true)))
	if is_instance_valid(arena.attacks):
		arena.attacks.fox_height=0;arena.attacks.set_process(bool(saved.get("attacks_process",true)))
	if is_instance_valid(arena.encounter.hud):arena.encounter.hud.visible=bool(saved.get("hud",true))
	if is_instance_valid(arena.developer_test):arena.developer_test.visible=bool(saved.get("dev",true))
	if is_instance_valid(arena.get_node_or_null("Presentation")):arena.get_node("Presentation").visible=bool(saved.get("interface",true))
	arena.camera.position=arena.player.position+arena.CAMERA_LOOK_OFFSET+(arena.CAMERA_OFFSET-arena.CAMERA_LOOK_OFFSET)*arena.camera_distance_scale
	arena.camera.look_at(arena.player.position+arena.CAMERA_LOOK_OFFSET);arena.camera.fov=35
	presentation.focus_weight=0
	presentation.stop_voice()

func _input(event: InputEvent) -> void:
	if not active:return
	var skip_key: bool=event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER,KEY_ESCAPE]
	var skip_mouse: bool=event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	if skip_key or skip_mouse:
		finish(true);get_viewport().set_input_as_handled()
