extends Node3D
## Transparent glyphs fixed above the actual head. Backlight and channel halo
## are separate procedural layers; no paper tile or horizontal HUD dodge.
const CELLS: Dictionary={
	"cub_swipe":Vector2(0,0),"cub_charge":Vector2(1,0),"cub_feint":Vector2(2,0),
	"cub_tail_sweep":Vector2(3,0),"cub_charm":Vector2(0,1),
	"barrage_fan":Vector2(1,1),"barrage_ring":Vector2(2,1),"barrage_weave":Vector2(3,1),
	"p2_claw_gale":Vector2(0,2),"p2_tail_crescent":Vector2(1,2),"p2_fox_roar":Vector2(2,2),
	"vision_charm":Vector2(3,2),"p3_spiral":Vector2(0,3),"inferno_rain":Vector2(3,1)
}
const SIZE:=96.0
const HALO_SIZE:=292.0
var attack_name:="cub_charm"
var charge:=0.0
var discharging:=false
var fading:=false
var channeling:=false
var channel_clock:=0.0
var clock:=0.0
var release_age:=10.0
var fade_age:=0.0
var pulses:=0
var phase:=1
var canvas: CanvasLayer
var stamp: ColorRect
var glow: ColorRect
var shadow: ColorRect
var halo: ColorRect
var material: ShaderMaterial
var glow_material: ShaderMaterial
var shadow_material: ShaderMaterial
var halo_material: ShaderMaterial
var skeleton: Skeleton3D
var head_bone:=-1
var head_anchor:=Vector3.ZERO
var projected_head:=Vector2.ZERO
var cue_center:=Vector2.ZERO
var arena
func _ready() -> void:
	process_priority=20
	arena=get_parent().arena;phase=arena.phase
	var puppet=get_parent().rig();skeleton=puppet.skeleton
	head_bone=skeleton.find_bone("head")
	var head: MeshInstance3D=puppet.get_node("p%d_head"%phase)
	var bounds:=head.get_aabb()
	for side in ["left","right"]:bounds=bounds.merge(puppet.get_node("p%d_ear_%s"%[phase,side]).get_aabb())
	var top:=Vector3(head.get_aabb().get_center().x,bounds.end.y+.10,0)
	head_anchor=skeleton.get_bone_global_rest(head_bone).affine_inverse()*top
	canvas=CanvasLayer.new();canvas.layer=7;add_child(canvas)
	halo=make_layer("BarrageFlameHalo",HALO_SIZE)
	halo_material=ShaderMaterial.new();halo_material.shader=preload("res://Shaders/Qingqiu/fox_barrage_halo.gdshader")
	halo.material=halo_material;halo.visible=false
	shadow=make_layer("GlyphSoftShadow",172)
	shadow_material=ShaderMaterial.new();shadow_material.shader=preload("res://Shaders/Qingqiu/attack_glyph_shadow.gdshader")
	shadow.material=shadow_material
	glow=make_layer("GlyphBacklight",184)
	glow_material=ShaderMaterial.new();glow_material.shader=preload("res://Shaders/Qingqiu/attack_glyph_glow.gdshader")
	glow_material.set_shader_parameter("tint",[Color("#1685a9"),Color("#a780ba"),Color("#ffa400")][phase-1])
	glow.material=glow_material
	stamp=make_layer("FloatingAttackGlyph",SIZE)
	material=ShaderMaterial.new();material.shader=preload("res://Shaders/Qingqiu/fox_attack_seal.gdshader")
	material.set_shader_parameter("seal_atlas",preload("res://Art/Qingqiu/AttackGlyphsV3/glyphs_atlas.png"))
	material.set_shader_parameter("atlas_grid",Vector2(4,4));material.set_shader_parameter("cell",CELLS[attack_name])
	stamp.material=material;advance(0.0)
func make_layer(label: String,extent: float) -> ColorRect:
	var rect:=ColorRect.new();rect.name=label;rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rect.size=Vector2.ONE*extent;rect.pivot_offset=rect.size*.5;canvas.add_child(rect);return rect
func release_pulse() -> void:
	discharging=true;charge=1.0;release_age=0.0;pulses+=1
func begin_channel() -> void:
	channeling=true;channel_clock=0.0;halo.visible=true
func finish() -> void:fading=true;fade_age=0.0
func cancel() -> void:
	if is_instance_valid(canvas):canvas.visible=false
	queue_free()
func _process(delta: float) -> void:advance(delta)
func advance(delta: float) -> void:
	if arena.phase!=phase or arena.encounter.state!=arena.encounter.State.RUNNING:cancel();return
	clock+=delta;release_age+=delta
	if channeling:channel_clock+=delta
	if fading:fade_age+=delta
	if fade_age>=.32:cancel();return
	var top: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(head_bone)*head_anchor)
	projected_head=arena.camera.unproject_position(top)
	var view_size:=get_viewport().get_visible_rect().size
	canvas.visible=not arena.camera.is_position_behind(top) and Rect2(Vector2.ZERO,view_size).grow(96).has_point(projected_head)
	# Keep x exactly on the head, including zoom and mirrored poses.
	var diameter:=HALO_SIZE
	if channeling:
		var top_safe:=12.0
		var hud=arena.encounter.hud
		if hud.visible and hud.boss_panel.is_visible_in_tree():top_safe=hud.boss_panel.get_global_rect().end.y+12
		diameter=clampf((projected_head.y-top_safe-12)/.86,144,HALO_SIZE)
	cue_center=projected_head-Vector2(0,diameter*.43+12 if channeling else SIZE*.5+8)
	stamp.position=cue_center-stamp.size*.5
	glow.position=cue_center-glow.size*.5
	shadow.position=cue_center-shadow.size*.5+Vector2(0,4)
	halo.size=Vector2.ONE*diameter;halo.pivot_offset=halo.size*.5;halo.position=cue_center-halo.size*.5
	var pop:=lerpf(.82,1.0,smoothstep(0,.16,clock));var pulse:=maxf(0,1.0-release_age/.20)
	stamp.scale=Vector2.ONE*(pop+pulse*.045+(0.10 if channeling else 0.0))
	glow.scale=Vector2.ONE*(1.2 if channeling else 1.0)
	var opacity:=smoothstep(0,.075,clock);var fade:=fade_age/.32
	for surface in [material,glow_material,halo_material,shadow_material]:
		surface.set_shader_parameter("clock",channel_clock if surface==halo_material else clock)
		surface.set_shader_parameter("opacity",opacity);surface.set_shader_parameter("pulse",pulse);surface.set_shader_parameter("fade",fade)
	material.set_shader_parameter("charge",charge);material.set_shader_parameter("channeling",1.0 if channeling else 0.0)
	glow_material.set_shader_parameter("charge",charge)
	shadow_material.set_shader_parameter("charge",charge)
	halo_material.set_shader_parameter("reduced",1.0 if arena.presentation.reduced_effects else 0.0)
