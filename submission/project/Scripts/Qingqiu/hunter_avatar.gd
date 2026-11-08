extends Node3D
## Render the short chibi hunter with continuous limbs in the lit arena.
## The transparent viewport is visual only; the existing body owns all gameplay.
const Rig=preload("res://Scripts/Qingqiu/hunter_rig_chibi.gd")
const CANVAS_SIZE=Vector2i(1536,1024)
const FOOT_ORIGIN=Vector2(768,875)
const DRAW_SCALE=0.75
const WORLD_PIXEL=0.00275
@onready var body: CharacterBody3D=get_parent()
@onready var arena=body.get_parent()
@onready var surface: Sprite3D=body.get_node("Visual")
var viewport: SubViewport
var puppet: Node2D
var encounter
var motion:=Vector3.ZERO
var desired_gait:="idle"
var locked_for:=0.0
var priority:=0
var dead:=false
var last_state:=-1
var mirrored:=false
var action_events:=0
var impact_pause:=0.0

func _ready() -> void:
	viewport=SubViewport.new()
	viewport.name="HunterRender"
	viewport.size=CANVAS_SIZE
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.gui_disable_input=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	puppet=Rig.new()
	puppet.name="HunterBones"
	viewport.add_child(puppet)
	puppet.position=FOOT_ORIGIN
	puppet.scale=Vector2.ONE*DRAW_SCALE
	puppet.set_process(false)
	puppet.paused=false
	surface.texture=viewport.get_texture()
	surface.region_enabled=false
	surface.flip_h=false
	surface.pixel_size=WORLD_PIXEL
	surface.modulate=Color.WHITE
	surface.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	surface.position.y=(FOOT_ORIGIN.y-CANVAS_SIZE.y*0.5)*WORLD_PIXEL+0.035
	surface.alpha_scissor_threshold=0.42
	reset_avatar()

func bind_encounter(value) -> void:
	encounter=value
	encounter.ui_changed.connect(on_snapshot)
	on_snapshot(encounter.snapshot())

func reset_avatar() -> void:
	dead=false
	locked_for=0.0
	priority=0
	impact_pause=0.0
	motion=Vector3.ZERO
	desired_gait="idle"
	mirrored=false
	puppet.scale=Vector2.ONE*DRAW_SCALE
	puppet.speed_scale=1.0
	puppet.snap_to("idle")
	anchor_pose()

func face_direction(direction: Vector3) -> void:
	var horizontal: float=direction.dot(arena.camera.global_basis.x)
	if absf(horizontal)<0.10:return
	mirrored=horizontal<0.0
	puppet.scale=Vector2(-DRAW_SCALE if mirrored else DRAW_SCALE,DRAW_SCALE)

func set_motion(velocity: Vector3) -> void:
	motion=velocity
	motion.y=0.0
	desired_gait="walk" if motion.length()>0.08 else "idle"
	if priority==0 and not dead:face_direction(motion)

func play_action(name: String,seconds: float,level: int,rate:=1.0) -> bool:
	if dead or (locked_for>0.0 and level<priority):return false
	priority=level
	impact_pause=0.0
	locked_for=seconds
	puppet.speed_scale=rate
	puppet.play(name)
	action_events+=1
	anchor_pose()
	return true

func notify_cast(direction: Vector3) -> void:
	if play_action("light_slash",0.40,1,0.72/0.40):face_direction(direction)

func hold_impact(seconds: float) -> void:
	if dead:return
	impact_pause=maxf(impact_pause,seconds)
	locked_for+=seconds

func notify_dash(direction: Vector3) -> void:
	if play_action("dodge",0.24,2,0.62/0.24):face_direction(direction)

func notify_hit() -> void:
	play_action("hit",0.32,3,0.48/0.32)

func notify_charm() -> void:
	# Let real compelled movement drive the gait; preserve hit/death reactions.
	if dead or priority>=3:return
	locked_for=0.0
	priority=0
	impact_pause=0.0

func on_snapshot(state: Dictionary) -> void:
	var next:=int(state["state"])
	if next==encounter.State.PREVIEW:
		reset_avatar()
	elif next==encounter.State.RUNNING and last_state in [encounter.State.VICTORY,encounter.State.DEFEAT]:
		reset_avatar()
	elif next==encounter.State.DEFEAT and last_state!=next:
		locked_for=0.0
		priority=0
		dead=false
		play_action("death",1.30,4)
		dead=true
	elif next==encounter.State.VICTORY and last_state!=next:
		play_action("victory",1.80,4)
	last_state=next

func anchor_pose() -> void:
	# The workbench dodge includes an authored horizontal slide. World movement
	# belongs to CharacterBody3D, so discard that visual offset in gameplay.
	var root_motion: Bone2D=puppet.bones["motion"]
	root_motion.position.x=puppet.setup["motion"].origin.x

func _process(delta: float) -> void:
	if not is_instance_valid(puppet):return
	if not dead:
		locked_for=maxf(0.0,locked_for-delta)
		if arena.presentation!=null and arena.presentation.is_busy():
			locked_for=0.0
			priority=0
			if puppet.current!="idle":puppet.play("idle")
			puppet.speed_scale=1.0
		elif locked_for<=0.0:
			priority=0
			if puppet.current!=desired_gait:puppet.play(desired_gait)
			puppet.speed_scale=clampf(motion.length()/3.1,0.65,1.65) if desired_gait=="walk" else 1.0
			face_direction(motion)
	var frozen_step:=minf(impact_pause,delta)
	impact_pause=maxf(0.0,impact_pause-delta)
	if delta>frozen_step:puppet._process(delta-frozen_step)
	anchor_pose()
