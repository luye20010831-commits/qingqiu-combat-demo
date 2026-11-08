extends CanvasLayer
## Explicit opt-in test entry. Starts real encounters; no fake phase clears.
@onready var arena=get_parent()
var developer_enabled:=false
var selected_phase:=1
var root_control: Control
var panel: PanelContainer
var launcher: Button
var status: Label
var phase_buttons: Array[Button]=[]

func _ready() -> void:
	layer=30
	root_control=Control.new();root_control.name="DeveloperControls"
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	launcher=make_button("F8  开发测试",toggle_mode)
	root_control.add_child(launcher)
	launcher.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	launcher.offset_left=24;launcher.offset_right=214;launcher.offset_top=-66;launcher.offset_bottom=-24
	launcher.tooltip_text="打开开发测试：可从 P2 / P3 直接开始游玩"
	panel=PanelContainer.new();panel.name="PhaseStartPanel"
	root_control.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left=24;panel.offset_right=420;panel.offset_top=-354;panel.offset_bottom=-82
	var background:=style(Color(0.224,0.184,0.255,.96),Color("#75664d"))
	background.content_margin_left=16;background.content_margin_right=16
	background.content_margin_top=12;background.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",background)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",7);panel.add_child(column)
	var title:=make_label("开发测试 · 阶段起点",21);column.add_child(title)
	status=make_label("",17);column.add_child(status)
	for index in 3:
		var phase:=index+1
		var text: String=["从 P1 开始 · 单尾幼狐","从 P2 开始 · 双尾迷雾   F6","从 P3 开始 · 九尾金瞳   F7"][index]
		var button:=make_button(text,start_phase.bind(phase))
		column.add_child(button);phase_buttons.append(button)
	for index in phase_buttons.size():
		phase_buttons[index].focus_neighbor_top=phase_buttons[posmod(index-1,3)].get_path()
		phase_buttons[index].focus_neighbor_bottom=phase_buttons[(index+1)%3].get_path()
	column.add_child(make_label("R 重开测试起点 · F8 / Esc 收起\n阶段直达不覆盖存档；不暂停战斗",16))
	panel.visible=false
	arena.encounter.ui_changed.connect(render_snapshot)
	render_snapshot(arena.encounter.snapshot())

func style(fill: Color,edge: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=fill;box.border_color=edge
	box.set_border_width_all(1);box.set_corner_radius_all(5)
	box.content_margin_left=10;box.content_margin_right=10
	box.content_margin_top=5;box.content_margin_bottom=5
	return box

func make_button(text: String,callback: Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=38
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",Color("#bbcdc5"))
	button.add_theme_stylebox_override("normal",style(Color("#392f41"),Color("#75664d")))
	button.add_theme_stylebox_override("hover",style(Color("#3d3b4f"),Color("#bbcdc5")))
	button.add_theme_stylebox_override("pressed",style(Color("#4c221b"),Color("#ffa400")))
	button.add_theme_stylebox_override("focus",style(Color(0,0,0,0),Color("#ffa400")))
	button.pressed.connect(callback)
	return button

func make_label(text: String,size: int) -> Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("#bbcdc5"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func toggle_mode() -> void:set_enabled(not developer_enabled)

func set_enabled(value: bool) -> void:
	developer_enabled=value;panel.visible=value
	launcher.text="F8  收起开发测试" if value else "F8  开发测试"
	if value:phase_buttons[1].grab_focus()
	else:release_menu_focus()
	render_snapshot(arena.encounter.snapshot())

func release_menu_focus() -> void:
	var focused:=get_viewport().gui_get_focus_owner()
	if focused!=null and root_control.is_ancestor_of(focused):focused.release_focus()

func start_phase(phase: int) -> void:
	if not developer_enabled:return
	selected_phase=clampi(phase,1,3)
	release_menu_focus()
	arena.encounter.start_encounter(selected_phase)

func render_snapshot(data: Dictionary) -> void:
	status.text="当前 P%d · 起点 P%d · 存档 P%d" % [int(data["phase"]),selected_phase,int(data["checkpoint_phase"])]
	for index in phase_buttons.size():
		phase_buttons[index].modulate=Color.WHITE if index+1!=selected_phase else Color("#ffa400")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_F8:
		toggle_mode();get_viewport().set_input_as_handled()
	elif developer_enabled:
		match event.physical_keycode:
			KEY_F6:start_phase(2);get_viewport().set_input_as_handled()
			KEY_F7:start_phase(3);get_viewport().set_input_as_handled()
			KEY_ESCAPE:set_enabled(false);get_viewport().set_input_as_handled()
