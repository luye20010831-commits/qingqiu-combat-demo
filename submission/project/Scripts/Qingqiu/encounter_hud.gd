extends CanvasLayer
## HUD subscribes to encounter snapshots; it never polls combat state per frame.
var controller
var boss_bar
var player_bar
var player_label: Label
var root_control: Control
var boss_panel: PanelContainer
var player_panel: PanelContainer
var skill_bar: HBoxContainer

func _ready() -> void:
	layer = 10
	root_control = Control.new()
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_panel = centered_panel(false,632,32)
	boss_panel.name="BossHealthOnly"
	boss_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	boss_bar = preload("res://Scripts/Qingqiu/boss_health_bar.gd").new()
	boss_panel.add_child(boss_bar)
	player_panel = centered_panel(true,220,220)
	player_panel.name="PlayerHealthBottomRight"
	player_panel.anchor_left=1.0
	player_panel.anchor_right=1.0
	player_panel.offset_left=-284.0
	player_panel.offset_right=-64.0
	player_panel.offset_top=-328.0
	player_panel.offset_bottom=-108.0
	player_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var player_column := VBoxContainer.new()
	player_column.add_theme_constant_override("separation",5)
	player_panel.add_child(player_column)
	player_label = label(18)
	player_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	player_column.add_child(player_label)
	player_bar = preload("res://Scripts/Qingqiu/player_health_orb.gd").new()
	player_column.add_child(player_bar)
	skill_bar=preload("res://Scripts/Qingqiu/player_skill_bar.gd").new()
	skill_bar.name="MeleeSkills1234"
	root_control.add_child(skill_bar)
	skill_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skill_bar.offset_left=-181
	skill_bar.offset_right=181
	skill_bar.offset_top=-228
	skill_bar.offset_bottom=-124

func centered_panel(bottom: bool,width: float,height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0 if bottom else 0.0
	panel.anchor_bottom = panel.anchor_top
	panel.offset_left = -width/2.0
	panel.offset_right = width/2.0
	panel.offset_top = -196.0 if bottom else 32.0
	panel.offset_bottom = panel.offset_top+height
	var background := box(Color(0.224,0.184,0.255,0.90),Color("#3d3b4f"))
	background.content_margin_left = 14
	background.content_margin_right = 14
	background.content_margin_top = 10
	background.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",background)
	return panel

func box(color: Color,border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func label(size: int) -> Label:
	var node := Label.new()
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("#bbcdc5"))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func bind(encounter: Node) -> void:
	controller = encounter
	controller.ui_changed.connect(render_snapshot)
	skill_bar.bind(controller.arena.spirit_combat)
	render_snapshot(controller.snapshot())

func render_snapshot(data: Dictionary) -> void:
	boss_bar.set_health(data["boss_health"],data["boss_max_health"])
	boss_bar.fill_color = [Color("#bbcdc5"),Color("#c32136"),Color("#ffa400")][data["phase"]-1]
	player_bar.set_health(data["player_health"],data["player_max_health"])
	player_label.text = "灵息  %d / %d" % [ceili(data["player_health"]),int(data["player_max_health"])]
