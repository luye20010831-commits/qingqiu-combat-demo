extends Node2D
const Rig = preload("res://Scripts/Qingqiu/hunter_rig_chibi.gd")
var puppet: Node2D
var names: Array = []
var selected := 0
var mirrored := false
var moving := false
var title_label: Label
var time_label: Label
var buttons: Array[Button] = []
var home := Vector2(1100, 912)
var zoom := 1.05
var live_input := true

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("142825"))
	puppet = Rig.new()
	puppet.name = "Hunter"
	add_child(puppet)
	puppet.position = home
	puppet.scale = Vector2(zoom, zoom)
	names = puppet.info.keys()
	make_interface()
	select_action(0)
	queue_redraw()

func make_label(text: String, point: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func make_interface() -> void:
	make_label("小巫猎 · Q 版动作", Vector2(92, 62), 46, Color("E4DDC8"))
	make_label("原图拆分 / 连续四肢 / 玉矛动作", Vector2(96, 130), 22, Color("A2B6AA"))
	make_label("动作工作台", Vector2(96, 209), 20, Color("81A89A"))
	for index in names.size():
		var button := Button.new()
		button.position = Vector2(92, 251 + index * 49)
		button.size = Vector2(332, 40)
		button.text = "%02d   %s" % [index + 1, puppet.info[names[index]].label]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(select_action.bind(index))
		add_child(button)
		buttons.append(button)
	title_label = make_label("", Vector2(720, 95), 30, Color("E4DDC8"))
	time_label = make_label("", Vector2(720, 143), 18, Color("8FB0A1"))
	make_label("← → 切动作    空格 暂停    R 重播    F 镜像    B 骨骼", Vector2(590, 990), 21, Color("B5C2B5"))
	make_label("WASD 移动 / Shift 奔跑    J 挥击    K 重击    L 护魂    Esc 退出", Vector2(590, 1025), 18, Color("8FA89C"))
	make_label("04 / ORIGINAL", Vector2(1602, 72), 18, Color("6C8C80"))

func select_action(index: int) -> void:
	selected = posmod(index, names.size())
	moving = false
	puppet.position = home
	puppet.paused = false
	puppet.play(names[selected])
	title_label.text = str(puppet.info[names[selected]].label)
	for i in buttons.size():
		buttons[i].modulate = Color("D7D3B9") if i == selected else Color("829B8D")

func _process(delta: float) -> void:
	if not is_instance_valid(puppet):
		return
	if live_input:
		var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if direction.length() > 0:
			var run := Input.is_physical_key_pressed(KEY_SHIFT)
			puppet.play("run" if run else "walk", false)
			moving = true
			puppet.position += direction.normalized() * (220 if run else 120) * delta
			puppet.position = puppet.position.clamp(Vector2(650, 660), Vector2(1600, 930))
			if absf(direction.x) > 0:
				mirrored = direction.x < 0
			puppet.scale = Vector2(-zoom if mirrored else zoom, zoom)
		elif moving:
			moving = false
			puppet.play("idle")
	var duration := float(puppet.info[puppet.current].duration)
	title_label.text = str(puppet.info[puppet.current].label)
	time_label.text = "%s  ·  %.2f / %.2f 秒%s" % [puppet.current, puppet.elapsed, duration,
		"  ·  暂停" if puppet.paused else ""]
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not live_input or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_RIGHT: select_action(selected+1)
		KEY_LEFT: select_action(selected-1)
		KEY_SPACE: puppet.paused = not puppet.paused
		KEY_R: select_action(selected)
		KEY_F:
			mirrored = not mirrored
			puppet.scale = Vector2(-zoom if mirrored else zoom, zoom)
		KEY_B: puppet.show_bones = not puppet.show_bones
		KEY_J: select_action(names.find("light_slash"))
		KEY_K: select_action(names.find("heavy_strike"))
		KEY_L: select_action(names.find("ward_cast"))
		KEY_ESCAPE: get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(62, 43, 396, 913), Color("10211F"))
	draw_line(Vector2(490, 72), Vector2(490, 953), Color("365247"), 1.0)
	draw_line(Vector2(92, 188), Vector2(423, 188), Color("365247"), 1.0)
	for i in 4:
		draw_arc(home + Vector2(0, 7), 135 + i*39, 0.0, TAU, 72, Color(0.28, 0.40, 0.34, 0.13-i*.02), 1.0)
	draw_set_transform(home + Vector2(0, 6), 0, Vector2(1.0, .20))
	draw_circle(Vector2.ZERO, 143, Color(0.02, 0.06, 0.045, .65))
	draw_set_transform(Vector2.ZERO)
