extends Node3D
## Four dense descending waves, a persistent escape lane, then a melee window.
var arena
var elapsed:=0.0
var waves_fired:=0
var impacts_fired:=0
var corridor_x:=0.0
var finished:=false
var patches: Array[Node3D]=[]
var spawn_log: Array[Dictionary]=[]
var profile: Dictionary
func _ready() -> void:
	arena=get_parent().arena;profile=arena.encounter.phase_config.duplicate(true)
	var best:=INF
	for column in [1,2,3,4]:
		var x:=lerpf(-16.0,16.0,float(column)/5.0)
		var distance:=absf(x-arena.player.position.x)
		if distance<best:best=distance;corridor_x=x
	emit_wave()
func emit_wave() -> void:
	var index:=waves_fired;waves_fired+=1
	get_parent().rig().play_action("barrage_cast",1.2)
	get_parent().rig().pulse_attack_tail("inferno_rain")
	if is_instance_valid(get_parent().attack_seal):get_parent().attack_seal.release_pulse()
	var count_scale:=clampf(float(profile.get("inferno_count_multiplier",1.0)),0.0,1.0)
	# Round cumulative totals so 0.8 means 102 drops over four waves, rather
	# than rounding each 25.6-drop wave upward and producing 104.
	var budget:=roundi(32.0*count_scale*float(index+1))-roundi(32.0*count_scale*float(index))
	var pressure_count:=mini(2,budget)
	var grid: Array[Dictionary]=[]
	for row in 6:
		for column in 6:
			var x:=lerpf(-16.0,16.0,float(column)/5.0)
			if absf(x-corridor_x)<1.0:continue
			var z:=lerpf(-16.0,16.0,float(row)/5.0)
			var point:=Vector3(x+sin(float(index)*1.7+float(row))*.12,0,z)
			grid.append({"point":point,"delay":float(row)*.035+float(column)*.01})
	var grid_count:=clampi(budget-pressure_count,0,grid.size())
	for slot in grid_count:
		# Distribute omissions across the map; rotate them between waves.
		var selected:=posmod(floori((float(slot)+.5)*float(grid.size())/float(grid_count))+index*7,grid.size())
		spawn_patch(grid[selected]["point"],grid[selected]["delay"],index,false)
	# The near-boss scorch discourages standing under it. A delayed aimed drop
	# forces movement along the open lane instead of an invulnerable camp spot.
	if pressure_count>1:spawn_patch(arena.boss_position(),.18,index,false)
	if pressure_count>0:spawn_patch(Vector3(clampf(arena.player.position.x,-18,18),0,clampf(arena.player.position.z,-18,18)),.25,index,true)
func spawn_patch(point: Vector3,delay: float,wave: int,aimed: bool) -> void:
	if patches.size()>=128:return
	var patch=preload("res://Scripts/Qingqiu/inferno_patch.gd").new()
	patch.position=point;patch.delay=delay
	patch.radius=float(profile.get("inferno_radius",4.2)) if not aimed else float(profile.get("inferno_aimed_radius",2.8))
	patch.falling_seconds=float(profile.get("inferno_falling_seconds",1.05))
	patch.residual_seconds=float(profile.get("inferno_residual_seconds",4.0))
	patch.damage=float(profile.get("inferno_impact_damage",14.0));patch.seed=float(wave)*2.7+point.x*.37+point.z*.19
	add_child(patch);patches.append(patch)
	spawn_log.append({"wave":wave,"point":point,"radius":patch.radius,"aimed":aimed})
func _process(delta: float) -> void:
	if arena.phase!=2 or arena.encounter.state!=arena.encounter.State.RUNNING:
		finished=true;queue_free();return
	elapsed+=delta
	for index in range(patches.size()-1,-1,-1):
		if not is_instance_valid(patches[index]) or patches[index].is_queued_for_deletion():patches.remove_at(index)
	var interval:=float(profile.get("inferno_wave_interval",1.65))
	var count:=int(profile.get("inferno_waves",4))
	while waves_fired<count and elapsed>=float(waves_fired)*interval:emit_wave()
	while impacts_fired<waves_fired and elapsed>=float(impacts_fired)*interval+float(profile.get("inferno_falling_seconds",1.05))+.12:
		impacts_fired+=1;arena.presentation.add_trauma(.15)
		arena.combat_audio.emit_cue("inferno_impact",{"trigger":"P2 inferno wave landed","wave":impacts_fired})
	if waves_fired>=count and patches.is_empty():finished=true
