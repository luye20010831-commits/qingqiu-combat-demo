extends HBoxContainer
## Four views over SpiritCombat's actual cooldown/lock/ward state.
var combat
var buttons: Array[Button]=[]
var masks: Array[ColorRect]=[]
var counters: Array[Label]=[]
var icons: Array[TextureRect]=[]
var last_snapshot: Dictionary={}
const IDS=["thrust","sweep","ward","heavy"]
const NAMES=["挥击","横扫","护魂","重击"]
const TIPS=["1 / 左键 / J · 大幅挥击","2 · 近战横扫","3 · 护魂，成形后可抵消爱心","4 / 右键 · 蓄势重劈"]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",14)
	for index in IDS.size():
		var slot:=Control.new()
		slot.custom_minimum_size=Vector2(80,104)
		slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var button:=Button.new()
		button.size=Vector2(80,78)
		button.focus_mode=Control.FOCUS_NONE
		button.tooltip_text=TIPS[index]
		for state in ["normal","hover","pressed","disabled"]:
			var box:=StyleBoxFlat.new()
			box.bg_color=Color(0.224,0.184,0.255,0.90)
			box.border_color=Color("#bbcdc5") if state=="hover" else Color("#789262")
			box.set_border_width_all(2 if state=="pressed" else 1)
			box.set_corner_radius_all(7)
			button.add_theme_stylebox_override(state,box)
		slot.add_child(button)
		buttons.append(button)
		button.pressed.connect(func():
			if combat:combat.use_skill(index))
		var icon:=TextureRect.new()
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.texture=load("res://Art/Qingqiu/SkillIcons/"+IDS[index]+".svg")
		icon.position=Vector2(6,3)
		icon.size=Vector2(68,68)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		icons.append(icon)
		var mask:=ColorRect.new()
		mask.color=Color(0.224,0.184,0.255,0.78)
		mask.mouse_filter=Control.MOUSE_FILTER_IGNORE
		mask.position=Vector2(2,2)
		mask.size=Vector2(76,0)
		button.add_child(mask)
		masks.append(mask)
		var counter:=Label.new()
		counter.size=Vector2(80,78)
		counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		counter.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		counter.add_theme_font_size_override("font_size",25)
		counter.add_theme_color_override("font_color",Color("#bbcdc5"))
		counter.add_theme_color_override("font_outline_color",Color("#392f41"))
		counter.add_theme_constant_override("outline_size",5)
		counter.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(counter)
		counters.append(counter)
		var name_label:=Label.new()
		name_label.text="%d  %s" % [index+1,NAMES[index]]
		name_label.position=Vector2(0,80)
		name_label.size=Vector2(80,24)
		name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size",18)
		name_label.add_theme_color_override("font_color",Color("#bbcdc5"))
		name_label.add_theme_color_override("font_outline_color",Color("#392f41"))
		name_label.add_theme_constant_override("outline_size",3)
		name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.add_child(name_label)

func bind(owner: Node) -> void:
	combat=owner
	for index in IDS.size():
		var profile: Dictionary=combat.skills[index]
		if str(profile["id"])=="ward":
			buttons[index].tooltip_text=TIPS[index]+"\n%.2f 秒成形 · 持续 %.1f 秒 · 所受伤害 ×%.2f · 冷却 %.1f 秒" % [profile["contact"],profile["ward_seconds"],profile["damage_multiplier"],profile["cooldown"]]
		else:
			buttons[index].tooltip_text=TIPS[index]+"\n%.1f 米 · %.0f 伤害 · %.2f 秒接触 · 冷却 %.1f 秒" % [profile["reach"],profile["damage"],profile["contact"],profile["cooldown"]]
	combat.skills_changed.connect(render_snapshot)
	render_snapshot(combat.skill_snapshot())

func render_snapshot(data: Dictionary) -> void:
	last_snapshot=data
	for index in IDS.size():
		var remaining:=float(data["cooldowns"][index])
		var ratio:=clampf(remaining/float(data["durations"][index]),0.0,1.0)
		buttons[index].disabled=data["blocked"] or remaining>0.0
		icons[index].modulate=Color(1,1,1,0.48 if data["blocked"] else 1.0)
		masks[index].size.y=74.0*ratio
		counters[index].text=str(ceili(remaining)) if remaining>0.0 else ""
		if index==2 and float(data["ward"])>0.0:
			counters[index].text="护"
			counters[index].modulate=Color("#96ce54")
		else:counters[index].modulate=Color.WHITE
