extends Node3D
## Native preview of the same offset timelines included in the Spine files.
var phase:=1
var selected:=0
var paused:=false
var slow:=false
var show_bones:=false
var names: Array=[]
var puppet: Node3D
var caption: Label
var actions_label: Label
var bones_overlay: MeshInstance3D
var idle_wait:=0.0
var movement_mode:=false
var camera: Camera3D
var hop_active:=false
var hop_source:=0.0
var hop_target:=0.0
func _ready() -> void:
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("#3d3b4f")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("#f1eee8")
	world.environment.ambient_light_energy=1.0
	world.environment.glow_enabled=true
	add_child(world)
	camera=Camera3D.new()
	add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=6.4
	camera.position=Vector3(0.8,2.5,20)
	camera.look_at(Vector3(0.8,2.5,0))
	camera.current=true
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	var margin:=MarginContainer.new()
	canvas.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,42)
	var column:=VBoxContainer.new()
	margin.add_child(column)
	column.add_child(make_label("九尾狐 · Spine 动作预演",36))
	column.add_child(make_label("同源骨骼与分层 · 1 / 2 / 3 切形态 · Q / E 换动作",22))
	caption=make_label("",27)
	column.add_child(caption)
	var spacer:=Control.new()
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	actions_label=make_label("",21)
	column.add_child(actions_label)
	column.add_child(make_label("M 移动试演：P1 ←/→ 跳跃；P2/P3 行走、Shift 奔跑    空格 暂停    R 重播    T 慢放    G 骨骼",20))
	bones_overlay=MeshInstance3D.new()
	bones_overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bones_overlay)
	load_phase(1)
func make_label(value: String,size: int) -> Label:
	var label:=Label.new()
	label.text=value
	label.add_theme_font_size_override("font_size",size)
	label.modulate=Color("#bbcdc5")
	return label
func load_phase(value: int) -> void:
	phase=value
	hop_active=false
	if is_instance_valid(puppet):puppet.free()
	puppet=load("res://Scenes/Qingqiu/FoxRigV4/FoxPhase%d.tscn"%phase).instantiate()
	add_child(puppet)
	puppet.position=Vector3(-1.3,0.3,0)
	camera.size=[4.8,6.4,8.0][phase-1]
	camera.position.y=[1.4,2.0,2.2][phase-1]
	camera.look_at(Vector3(0.8,camera.position.y,0))
	puppet.set_process(not paused)
	names=puppet.action_player.library.keys()
	selected=0
	replay()
	if movement_mode:
		puppet.reset_locomotion()
		caption.text=movement_hint()
func movement_hint() -> String:
	return "P1  移动试演 · ←/→ 轻跃移动，松开后落地停稳" if phase==1 else "P%d  移动试演 · ←/→ 行走，Shift 奔跑，松开停步"%phase
func replay() -> void:
	puppet.play_action(names[selected],0.35 if slow else 1.0)
	idle_wait=0.0
	var data: Dictionary=puppet.action_player.library[names[selected]]
	caption.text="P%d    %s    /    %s"%[phase,data["label"],names[selected]]
	var labels: Array[String]=[]
	for name in names:labels.append(puppet.action_player.library[name]["label"])
	actions_label.text="动作： "+"  ·  ".join(labels)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_1,KEY_2,KEY_3:load_phase(event.physical_keycode-KEY_1+1)
		KEY_Q,KEY_E:
			movement_mode=false
			selected=posmod(selected+(-1 if event.physical_keycode==KEY_Q else 1),names.size())
			replay()
		KEY_R:replay()
		KEY_SPACE:
			paused=not paused
			puppet.set_process(not paused)
		KEY_T:
			slow=not slow
			puppet.action_player.speed=0.35 if slow else 1.0
		KEY_G:show_bones=not show_bones
		KEY_M:
			movement_mode=not movement_mode
			hop_active=false
			puppet.reset_locomotion()
			if movement_mode:caption.text=movement_hint()
			else:replay()
		KEY_ESCAPE:get_tree().quit()
func _process(delta: float) -> void:
	if puppet==null:return
	if movement_mode and not paused:
		var axis:=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
		var running:=Input.is_physical_key_pressed(KEY_SHIFT)
		var move_speed: float=([2.2,3.0,2.8] if running else [0.8,1.25,1.05])[phase-1]
		var before:=puppet.position.x
		if phase==1:
			if not hop_active and axis!=0.0:
				hop_source=before
				hop_target=clampf(before+axis*1.55,-3.2,2.4)
				puppet.face_velocity(Vector3(axis,0,0))
				puppet.play_action("cub_hop")
				hop_active=true
			if hop_active:
				var hop: Dictionary=puppet.action_player.library["cub_hop"]
				var progress:=smoothstep(float(hop["travel_start"]),float(hop["travel_end"]),puppet.action_player.elapsed)
				puppet.position.x=lerpf(hop_source,hop_target,progress)
				if puppet.action_player.current!="cub_hop":hop_active=false
		else:puppet.position.x=clampf(before+axis*move_speed*delta,-3.2,2.4)
		puppet.set_locomotion(Vector3((puppet.position.x-before)/maxf(delta,0.0001),0,0))
		var gait: String=puppet.action_player.current
		caption.text="P1   %s   ·   ←/→ 轻跃移动，四肢保持整体轮廓"%("跳跃" if hop_active else "站立") if phase==1 else "P%d   %s   %.2f 米/秒   ·   ←/→ 行走，Shift 奔跑，松开停步"%[phase,"奔跑" if gait=="run" else ("行走" if gait=="walk" else "站立"),puppet.movement_speed]
	if not movement_mode and not paused and puppet.action_player.current.is_empty():
		idle_wait+=delta
		if idle_wait>0.65:replay()
	update_bones.call_deferred()
func update_bones() -> void:
	bones_overlay.visible=show_bones
	if not show_bones:return
	var skeleton: Skeleton3D=puppet.get_node("Skeleton3D")
	var mesh:=ImmediateMesh.new()
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("#ffa400")
	material.no_depth_test=true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
	for i in skeleton.get_bone_count():
		var parent:=skeleton.get_bone_parent(i)
		if parent<0:continue
		var a:=puppet.to_global(skeleton.get_bone_global_pose(parent).origin)
		var b:=puppet.to_global(skeleton.get_bone_global_pose(i).origin)
		a.z=0.5
		b.z=0.5
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(b)
	mesh.surface_end()
	bones_overlay.mesh=mesh
