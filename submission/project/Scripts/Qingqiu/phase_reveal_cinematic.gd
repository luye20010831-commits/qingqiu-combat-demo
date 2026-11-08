extends Node
## Full-frame shots of the current registered puppet in an isolated render world.
## The encounter stays blocked by the existing intro state; gameplay is never moved.
var presentation
var active:=false
var phase:=3
var shot:=""
var age:=0.0
var duration:=5.5
var last_step:=-1
var events: Array[Dictionary]=[]
var layer: CanvasLayer
var panel: Control
var backdrop: ColorRect
var composite: TextureRect
var halo_back: ColorRect
var halo_front: ColorRect
var view: SubViewport
var camera: Camera3D
var stage: Node3D
var rig
var anklet
var tail_bounds:=AABB()
var body_bounds:=AABB()
var game_start:=Transform3D.IDENTITY
var game_start_look:=Vector3.ZERO
var rush_overlay: ColorRect
var camera_snap_fired:=false

func _ready() -> void:
	presentation=get_parent()
	layer=CanvasLayer.new();layer.name="PhaseCloseups";layer.layer=75;add_child(layer)
	panel=Control.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop=ColorRect.new();backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=ShaderMaterial.new();background.shader=preload("res://Shaders/Qingqiu/phase_reveal_backdrop.gdshader");backdrop.material=background
	halo_back=make_halo("BodyHaloBack")
	view=SubViewport.new();view.name="RegisteredFoxCloseup";view.size=Vector2i(1920,1080)
	view.own_world_3d=true;view.transparent_bg=true;view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(view)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("#bbcdc5");environment.environment.ambient_light_energy=.85
	environment.environment.glow_enabled=true;environment.environment.glow_intensity=.45
	view.add_child(environment)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.01
	view.add_child(camera);camera.current=true
	stage=Node3D.new();stage.name="CloseupStage";view.add_child(stage)
	composite=TextureRect.new();composite.name="LiveFoxImage";composite.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(composite);composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	composite.texture=view.get_texture();composite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;composite.stretch_mode=TextureRect.STRETCH_SCALE
	var paint:=ShaderMaterial.new();paint.shader=preload("res://Shaders/Qingqiu/phase_reveal_composite.gdshader");composite.material=paint
	halo_front=make_halo("BodyHaloFront")
	rush_overlay=ColorRect.new();rush_overlay.name="EntranceRush";rush_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(rush_overlay);rush_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rush:=ShaderMaterial.new();rush.shader=preload("res://Shaders/Qingqiu/phase_entrance_rush.gdshader");rush_overlay.material=rush
	layer.visible=false

func make_halo(label: String) -> ColorRect:
	var rect:=ColorRect.new();rect.name=label;rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(rect)
	var material:=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/fox_barrage_halo.gdshader")
	rect.material=material;rect.visible=false;return rect

func begin(value: int) -> void:
	stop();events.clear();shot=""
	if value!=3:return
	phase=3;active=true;age=0.0;last_step=-1;camera_snap_fired=false
	game_start=presentation.arena.camera.global_transform
	game_start_look=presentation.arena.player.position+Vector3(0,.6,0)
	duration=5.5
	rig=load("res://Scenes/Qingqiu/FoxRigV4/FoxPhase%d.tscn"%phase).instantiate()
	stage.add_child(rig);rig.set_process(false);rig.blink_enabled=false
	for part in rig.get_children():
		if part is MeshInstance3D:part.set_instance_shader_parameter("foot_sort_anchor",Vector4.ZERO)
	var first_body:=true;var first_tail:=true
	for part in rig.get_children():
		if not part is MeshInstance3D:continue
		var bounds: AABB=part.get_aabb()
		body_bounds=bounds if first_body else body_bounds.merge(bounds);first_body=false
		if str(part.name).begins_with("tail_"):
			tail_bounds=bounds if first_tail else tail_bounds.merge(bounds);first_tail=false
	if phase==3:
		anklet=preload("res://Scripts/Qingqiu/p3_golden_anklet.gd").new()
		anklet.name="CloseupAnklet";rig.add_child(anklet);rig.golden_anklet=anklet;anklet.set_process(false)
	else:anklet=null
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;layer.visible=true;panel.modulate.a=0
	advance(0.0)

func set_shot(value: String) -> void:
	if shot==value:return
	shot=value;events.append({"kind":"shot","shot":shot,"at":age})
	if shot=="anklet":rig.play_action("walk")
	elif shot=="tails":rig.play_action("tail_unfurl_p3")
	else:rig.stop_action()
	for part in rig.get_children():
		if part is MeshInstance3D:part.visible=true
	for eye in rig.eye_materials:
		eye.set_shader_parameter("glow_strength",.5 if phase==3 else .10)

func advance(delta: float) -> void:
	if not active:return
	age+=delta
	var size:=get_viewport().get_visible_rect().size
	if view.size!=Vector2i(size):view.size=Vector2i(size)
	var aspect:=size.x/maxf(1,size.y)
	var next_shot:="approach"
	if age>=.48:next_shot="anklet" if age<1.8 else "tails" if age<3.5 else "body"
	set_shot(next_shot)
	rig._process(delta);rig.skeleton.force_update_all_bone_transforms()
	if is_instance_valid(anklet):
		anklet._process(delta)
		if shot=="anklet" and int((age-.48)/.52)!=last_step:
			last_step=int((age-.48)/.52);anklet.pulse()
	if age>=.48 and not camera_snap_fired:
		camera_snap_fired=true;events.append({"kind":"camera_impact","at":age})
		presentation.add_trauma(.25)
	var center:=body_bounds.get_center()
	var extent:=maxf(body_bounds.size.y,body_bounds.size.x/aspect)*1.48
	if shot=="anklet":
		var drive:=1.0-pow(1.0-clampf((age-.48)/.24,0,1),3)
		center=anklet.anchor+Vector3(-.10,.13,0);extent=lerpf(2.2,1.02,drive)
	elif shot=="tails":
		center=tail_bounds.get_center()+Vector3(tail_bounds.size.x*.12+sin((age-1.8)*1.2)*.12,0,0)
		extent=maxf(tail_bounds.size.y,tail_bounds.size.x/aspect)*lerpf(1.3,.78,1.0-pow(1.0-clampf((age-1.8)/.32,0,1),3))
	elif shot=="body":
		center=body_bounds.get_center();extent=maxf(body_bounds.size.y,body_bounds.size.x/aspect)*1.48
	camera.size=extent;camera.position=center+Vector3(0,0,10);camera.look_at(center)
	backdrop.material.set_shader_parameter("clock",age)
	backdrop.material.set_shader_parameter("golden",1.0 if phase==3 else 0.0)
	backdrop.material.set_shader_parameter("shot",0.0 if shot=="anklet" else 1.0)
	var cut:=1.0
	if phase==3:
		for boundary in [1.8,3.5]:cut=minf(cut,smoothstep(0,.065,absf(age-boundary)))
	var insert:=smoothstep(.40,.50,age)*(1.0-smoothstep(3.5-.04,3.5+.12,age))
	backdrop.modulate.a=insert
	composite.material.set_shader_parameter("opacity",cut*insert)
	composite.material.set_shader_parameter("glow",.6 if phase==3 else .2)
	composite.material.set_shader_parameter("tint",Color("#ffa400") if phase==3 else Color("#bbcdc5"))
	composite.material.set_shader_parameter("eye_shot",0.0)
	composite.material.set_shader_parameter("clock",age)
	composite.material.set_shader_parameter("fire_outer",Color("#ffa400") if phase==3 else Color("#1685a9"))
	composite.material.set_shader_parameter("fire_core",Color("#f2f0df") if phase==3 else Color("#bbcdc5"))
	composite.material.set_shader_parameter("reduced",1.0 if presentation.reduced_effects else 0.0)
	var body_power:=smoothstep(3.5,3.9,age) if phase==3 else 0.0
	apply_game_camera()
	var real_rig=presentation.arena.forms.get_child(phase-1).get_node("FoxRig")
	var projected_body: Vector2=presentation.arena.camera.unproject_position(real_rig.to_global(body_bounds.get_center()))
	for index in 2:
		var halo: ColorRect=halo_back if index==0 else halo_front
		halo.visible=phase==3 and shot=="body"
		halo.size=Vector2.ONE*minf(size.y*1.52,size.x*.92)
		halo.position=projected_body-halo.size*.5
		halo.material.set_shader_parameter("clock",age-3.5)
		halo.material.set_shader_parameter("opacity",body_power*(.95 if index==0 else .18)*cut)
		halo.material.set_shader_parameter("pulse",exp(-maxf(0,age-3.5)*3))
		halo.material.set_shader_parameter("reduced",1.0 if presentation.reduced_effects else 0.0)
	panel.modulate.a=1.0-smoothstep(duration-.38,duration,age)
	var rush_power:=sin(clampf(age/.52,0,1)*PI)
	if shot=="tails":rush_power=maxf(rush_power,.65*(1.0-smoothstep(0,.25,age-1.8)))
	rush_overlay.material.set_shader_parameter("power",rush_power)
	rush_overlay.material.set_shader_parameter("clock",age)
	rush_overlay.material.set_shader_parameter("reduced",1.0 if presentation.reduced_effects else 0.0)
	rush_overlay.material.set_shader_parameter("tint",Color("#ffa400") if phase==3 else Color("#bbcdc5"))

func apply_game_camera() -> void:
	if not active:return
	var arena=presentation.arena
	var main: Camera3D=arena.camera
	var actual=arena.forms.get_child(phase-1).get_node("FoxRig")
	var head: Vector3=actual.to_global(body_bounds.get_center()+Vector3(0,body_bounds.size.y*.12,0))
	var body: Vector3=actual.to_global(body_bounds.get_center())
	var close:=head+Vector3(0,1.0,7.0)
	var hero:=body+Vector3(.65,1.9,11.8)
	if presentation.reduced_effects:close=close.lerp(hero,.45)
	var look:=head
	if age<.48:
		var drive:=smoothstep(0,.48,age) if presentation.reduced_effects else 1.0-pow(1.0-clampf(age/.48,0,1),4)
		main.position=game_start.origin.lerp(close,drive)
		look=game_start_look.lerp(head,drive)
	else:
		var body_start:=3.5
		var pull:=smoothstep(body_start-.12,body_start+.42,age)
		main.position=close.lerp(hero,pull);look=head.lerp(body,pull)
	var resume:=smoothstep(duration-.38,duration,age)
	var offset: Vector3=arena.CAMERA_LOOK_OFFSET+(arena.CAMERA_OFFSET-arena.CAMERA_LOOK_OFFSET)*arena.camera_distance_scale
	main.position=main.position.lerp(arena.player.position+offset,resume)
	look=look.lerp(arena.player.position+arena.CAMERA_LOOK_OFFSET,resume)
	main.look_at(look)
	main.fov=lerpf(31.0 if presentation.reduced_effects else 28.0,35.0,resume)

func stop() -> void:
	stop_audio()
	var was_active:=active
	active=false
	if is_instance_valid(layer):layer.visible=false
	if is_instance_valid(view):view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(rig):rig.visible=false;rig.queue_free()
	rig=null;anklet=null
	if was_active and is_instance_valid(presentation.arena.camera):
		var arena=presentation.arena
		arena.camera.position=arena.player.position+arena.CAMERA_LOOK_OFFSET+(arena.CAMERA_OFFSET-arena.CAMERA_LOOK_OFFSET)*arena.camera_distance_scale
		arena.camera.look_at(arena.player.position+arena.CAMERA_LOOK_OFFSET);arena.camera.fov=35

func stop_audio() -> void:
	pass

func _exit_tree() -> void:
	stop()
	if is_instance_valid(composite):composite.texture=null
