extends SceneTree
## Submission recording only. Does not alter saved gameplay resources.
var OUT := "res://artifacts/submission_v41_20261109"
const DT := 1.0 / 30.0
var arena
var chapter := "p1"
var frame_count := 0
var section_start := 0
var events: Array[Dictionary] = []
var layer: CanvasLayer
var title: Label
var detail: Label
var live: Label
var drive_roam := false
var capture_stills := true
var sections: Array[Dictionary] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--chapter="):chapter = argument.trim_prefix("--chapter=")
		if argument.begins_with("--output="):OUT = argument.trim_prefix("--output=")
	ProjectSettings.set_setting("qingqiu/testing/checkpoint_path",OUT+"/capture_saves/"+chapter+"_"+str(Time.get_ticks_usec())+".cfg")
	run.call_deferred()

func build_overlay() -> void:
	layer = CanvasLayer.new();layer.layer = 95;root.add_child(layer)
	var back := ColorRect.new();back.color = Color(0.055,0.065,0.09,0.89)
	back.position = Vector2.ZERO;back.size = Vector2(1920,180);back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(back)
	title = Label.new();title.position = Vector2(52,20);title.add_theme_font_size_override("font_size",34);layer.add_child(title)
	detail = Label.new();detail.position = Vector2(54,72);detail.add_theme_font_size_override("font_size",24)
	detail.modulate = Color("#dce5df");layer.add_child(detail)
	live = Label.new();live.position = Vector2(54,118);live.add_theme_font_size_override("font_size",20)
	live.modulate = Color("#b8c4cb");layer.add_child(live)
	var foot := Label.new();foot.position = Vector2(36,1028);foot.add_theme_font_size_override("font_size",18)
	foot.text = "V4.1 提交快照 · 脚本机制演示 · 安排出招 / 站位与尾血快进 · 非真人通关 · 静音"
	layer.add_child(foot)

func mark(id: String, heading: String, explanation: String) -> void:
	if not sections.is_empty():sections[-1]["end_frame"] = frame_count
	sections.append({"id":id,"title":heading,"detail":explanation,"start_frame":frame_count})
	section_start = frame_count;title.text = heading;detail.text = explanation
	print("CHAPTER ",chapter," ",id," @ ",float(frame_count)/30.0)

func log_event(id: String, values: Dictionary = {}) -> void:
	values["id"] = id;values["frame"] = frame_count
	events.append(values);print("OBSERVATION ",JSON.stringify(values))

func release_movement() -> void:
	for action in ["MoveLeft","MoveRight","MoveUp","MoveDown","Dash"]:Input.action_release(action)

func advance_one() -> void:
	if arena != null:
		var a = arena.attacks
		if drive_roam or a.mode != "idle":a._process(DT)
		else:
			a.clock += DT;a.update_vision(DT)
		live.text = "P%d  生命 %.0f / %.0f  |  命中 %d  |  魅惑 %.1f 秒  |  护魂 %.1f 秒" % [arena.phase,arena.encounter.player_health,arena.encounter.player_max_health,arena.spirit_combat.hit_count,maxf(arena.charm_remaining,a.vision_remaining),arena.spirit_combat.ward_remaining]
	await process_frame
	frame_count += 1
	if capture_stills and frame_count-section_start == 28 and not sections.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"/stills/"+chapter+"_"+str(sections[-1]["id"])+".png")

func wait_seconds(seconds: float) -> void:
	for i in ceili(seconds*30.0):await advance_one()

func prepare(phase: int, point := Vector3(0,0,4), fox := Vector3.ZERO) -> void:
	release_movement();drive_roam = false
	arena.encounter.start_encounter(phase);arena.attacks.set_process(false)
	arena.player.position = point;arena.forms.get_child(phase-1).position = fox
	arena.camera_distance_scale = 0.78
	arena.camera.position = point+arena.CAMERA_OFFSET*0.78
	arena.camera.look_at(point+Vector3(0,.6,0))
	await wait_seconds(.3)

func reset_segment(point := Vector3(0,0,4), fox := Vector3.ZERO) -> void:
	release_movement();drive_roam = false
	arena.attacks.reset();arena.spirit_combat.clear_transients();arena.player_avatar.reset_avatar()
	arena.encounter.clear_hazards();arena.player_burn.reset()
	arena.encounter.player_max_health = float(arena.encounter.balance["player_test_health"])
	arena.encounter.player_health = arena.encounter.player_max_health
	arena.encounter.player_hit_grace = 0.0;arena.encounter.state = arena.encounter.State.RUNNING
	arena.player.position = point;arena.forms.get_child(arena.phase-1).position = fox
	arena.encounter.publish();await wait_seconds(.3)

func simple_attack(id: String, heading: String, explanation: String, seconds: float, point := Vector3(0,0,5)) -> void:
	await reset_segment(point);mark(id,heading,explanation)
	arena.attacks.begin_attack(id);await wait_seconds(seconds)
	log_event(id,{"casts":arena.attacks.casts,"bullets":arena.attacks.bullets_fired,"player_hp":arena.encounter.player_health})

func phase_one() -> void:
	await prepare(1)
	mark("intro","青丘九尾狐  ·  三阶段战斗机制","读身体与头顶图标 → 判断距离和时机 → 规避后近身反击")
	await wait_seconds(3)
	await reset_segment(Vector3(0,0,2))
	mark("player_skills","玩家工具  ·  挥击 / 横扫 / 护魂 / 重击","四个技能使用真实接触判定与冷却；空格冲刺可中断未命中的出手")
	for skill in [0,1,3]:
		arena.spirit_combat.use_skill(skill);await wait_seconds(1.25)
	arena.spirit_combat.use_skill(2);await wait_seconds(1.25)
	log_event("player_skills",{"hits":arena.spirit_combat.hit_count,"contacts":arena.spirit_combat.melee_contacts})
	await reset_segment(Vector3(0,0,6))
	mark("cub_hop","P1  ·  轻跃追逐","短跃接近后停步；身体前摇和浮印提示即将使用的动物招式")
	drive_roam=true;arena.attacks.cooldown=999.0;await wait_seconds(3);drive_roam=false
	await simple_attack("cub_feint","P1  ·  佯退逗弄","回身后退改变距离；不要把退让当作安全的持续输出时间",2.5,Vector3(0,0,4))
	await simple_attack("cub_swipe","P1  ·  抬爪抓挠","0.72 秒前摇后近身抓挠；拉开或冲刺，避免贪刀",2.8,Vector3(0,0,2))
	await reset_segment(Vector3(0,0,4))
	mark("cub_charge","P1  ·  压身冲撞与有效反制","起手锁定方向；侧向冲刺避开，再用真实重击反击")
	var hp: float=arena.encounter.player_health;var hits: int=arena.spirit_combat.hit_count
	arena.attacks.begin_attack("cub_charge");await wait_seconds(.62)
	Input.action_press("MoveRight");Input.action_press("Dash");await wait_seconds(.20)
	Input.action_release("Dash");await wait_seconds(.18);release_movement();await wait_seconds(.55)
	arena.spirit_combat.use_skill(3);await wait_seconds(1.6)
	log_event("charge_response",{"damage_taken":hp-arena.encounter.player_health,"counter_hits":arena.spirit_combat.hit_count-hits})
	await simple_attack("cub_tail_sweep","P1  ·  单尾横扫","卷尾蓄势后扫过近身并轻推；退到范围外或用冲刺通过",3.2,Vector3(0,0,2))
	await reset_segment(Vector3(0,0,3),Vector3(2,0,-1))
	mark("cub_charm","P1  ·  一颗持续追踪的爱心","青白爱心最多追踪2.5秒；接触后失控朝幼狐走1.2秒，不遮挡视野")
	arena.attacks.begin_attack("cub_charm");await wait_seconds(5)
	log_event("cub_charm",{"charm_hits":arena.attacks.charm_hits,"control_remaining":arena.charm_remaining})
	await reset_segment(Vector3(0,0,3),Vector3(2,0,-1))
	mark("ward_heart","P1  ·  护魂抵消爱心","先等护魂实际成形；爱心接触消失，不触发失控和雾障")
	var charms: int=arena.attacks.charm_hits
	arena.spirit_combat.use_skill(2);await wait_seconds(.45)
	arena.attacks.begin_attack("cub_charm");await wait_seconds(3.6)
	log_event("ward_heart",{"new_charms":arena.attacks.charm_hits-charms,"heart_alive":arena.attacks.has_cub_charm_heart()})

func transition(target: int) -> void:
	await prepare(target-1,Vector3(0,0,3))
	mark("transition","P%d → P%d  ·  实际阶段转场"%[target-1,target],"演示快进至尾血：实际击败 → 火幕／展尾 → 恢复战斗；眼睛特写已删除")
	arena.encounter.boss_health=10.0;arena.encounter.publish()
	arena.player.position=Vector3(0,0,2);arena.spirit_combat.use_skill(0)
	await wait_seconds(9.0 if target==3 else 7.0)
	log_event("transition",{"target":target,"actual_phase":arena.phase,"state":arena.encounter.state,"presentation_busy":arena.presentation.is_busy()})

func phase_two() -> void:
	await prepare(2,Vector3(0,0,8))
	mark("roam","P2  ·  双尾迷雾与游走","成年狐在招式间换位；起手后锁定面向，身体和浮印替代地面范围")
	drive_roam=true;arena.attacks.cooldown=999;await wait_seconds(3.5);drive_roam=false
	await simple_attack("p2_claw_gale","P2  ·  抬爪风刃","五道远距爪风；读抬爪方向，横向离开锁定路径",3.8)
	await simple_attack("barrage_fan","P2  ·  三波扇幕","连续三波，不能躲过第一波就立刻贪刀；鬼火先慢后突进",4.5)
	await simple_attack("p2_tail_crescent","P2  ·  双尾月扫","宽幅定向月刃；从起手方向判断侧移或冲刺时机",3.8)
	await simple_attack("barrage_weave","P2  ·  三波交织","左右交错和弯曲弹道；穿过间隙后继续观察后续波次",4.5)
	await simple_attack("p2_fox_roar","P2  ·  远距狐啸","冲击波向外扩宽；越远越不能只做小幅横移",3.8)
	await simple_attack("barrage_ring","P2  ·  三波错位弧幕","宽弧错位连发；保留缺口，实际飞弹沿当前锁定方向生成",4.5)
	await reset_segment(Vector3(0,0,2))
	mark("vanish","P2  ·  隐身与再现形","隐身期间近战无法命中；现形后的短窗口可接重击")
	var hits: int=arena.spirit_combat.hit_count
	arena.attacks.begin_vanish();await wait_seconds(.6);arena.spirit_combat.use_skill(0);await wait_seconds(1.8)
	var hidden_hits: int=arena.spirit_combat.hit_count-hits
	arena.spirit_combat.use_skill(3);await wait_seconds(1.6)
	log_event("vanish",{"hidden_hits":hidden_hits,"total_hits":arena.spirit_combat.hit_count-hits})
	await reset_segment(Vector3(0,0,7))
	mark("inferno_rain","P2  ·  玄焰倾天与移动通道","V4.1 四波共 102 处落焰；玩家使用正式 120 生命，余焰 2.8 秒")
	arena.encounter.publish()
	arena.camera_distance_scale=1.45;arena.attacks.begin_attack("inferno_rain")
	await wait_seconds(3.8)
	var rain=arena.attacks.inferno
	await wait_seconds(4.0)
	var observed_waves: int=rain.waves_fired if is_instance_valid(rain) else -1
	var observed_patches: int=rain.spawn_log.size() if is_instance_valid(rain) else -1
	mark("burn","P2  ·  离开余焰仍有附着灼烧","真实落焰与伤害；脚本站位移出火地，观察身体黑焰及持续扣血")
	arena.player.position=Vector3(0,0,18.8)
	await wait_seconds(5.5)
	log_event("inferno_rain",{"waves":observed_waves,"patch_count":observed_patches,"burn_applications":arena.player_burn.applications,"burn_ticks":arena.player_burn.ticks,"hp":arena.encounter.player_health})

func move_to(point: Vector3, seconds: float) -> void:
	for i in ceili(seconds*30):
		var offset: Vector3=point-arena.player.position;offset.y=0
		if offset.length()<.50:break
		var right: Vector3=arena.camera.global_basis.x;right.y=0;right=right.normalized()
		var forward: Vector3=arena.camera.global_basis.z;forward.y=0;forward=forward.normalized()
		var dx:=offset.normalized().dot(right);var dy:=offset.normalized().dot(forward)
		release_movement()
		if dx>0:Input.action_press("MoveRight",absf(dx))
		else:Input.action_press("MoveLeft",absf(dx))
		if dy>0:Input.action_press("MoveDown",absf(dy))
		else:Input.action_press("MoveUp",absf(dy))
		await advance_one()
	release_movement()

func phase_three() -> void:
	await prepare(3,Vector3(0,0,4))
	mark("p3_intro","P3  ·  九尾金瞳与美丽危险","金花、毁林浮石、脚环金粒；场景变化服务于更高的观察压力")
	await wait_seconds(3)
	mark("vision_charm","P3  ·  四心惑目与光点解魅","深玫红四心最多飞行2.5秒；接触才有粉紫雾，P3可移动／取蓝光解除")
	var charms: int=arena.attacks.charm_hits;var cleanses: int=arena.attacks.cleanses
	arena.attacks.begin_attack("vision_charm");await wait_seconds(2.7)
	if is_instance_valid(arena.attacks.beacon):await move_to(arena.attacks.beacon.position,2.5)
	await wait_seconds(1.3)
	log_event("p3_cleanse",{"new_charms":arena.attacks.charm_hits-charms,"new_cleanses":arena.attacks.cleanses-cleanses})
	await reset_segment(Vector3(0,0,6))
	mark("p3_ward","P3  ·  护魂也能抵消四心","提前准备已成形的护魂，可避免爱心施加魅惑；盾有冷却")
	charms=arena.attacks.charm_hits
	arena.spirit_combat.use_skill(2);await wait_seconds(.4)
	arena.attacks.begin_attack("vision_charm");await wait_seconds(3)
	log_event("p3_ward",{"new_charms":arena.attacks.charm_hits-charms})
	await reset_segment(Vector3(0,0,7))
	mark("map_fire","P3  ·  九柱三拍与地图轮换","每拍九根、三拍扫场，下一轮横纵轮换；当前没有地面预警圆")
	arena.camera_distance_scale=1.6
	arena.encounter.spawn_wave();await wait_seconds(3.5)
	arena.encounter.spawn_wave();await wait_seconds(3.5)
	log_event("map_fire",{"beats":arena.encounter.fire_beat_log.size(),"hazards_spawned":arena.encounter.hazards_spawned})
	await reset_segment(Vector3(0,0,9),Vector3(10,0,-6))
	mark("p3_spiral","P3  ·  归中跃落与八轮顺时狐焰","先蓄跃与短镜头，再回中心；八轮各 16 枚，留两个相邻扇区缺口")
	arena.camera_distance_scale=1.45;arena.attacks.begin_attack("p3_spiral")
	await wait_seconds(17.5)
	log_event("p3_spiral",{"rounds":arena.attacks.spiral_log.size(),"round_trace":arena.attacks.spiral_log,"state":arena.encounter.state})

func flow() -> void:
	await prepare(3,Vector3(0,0,2))
	mark("victory","完整尝试流程  ·  击败与胜利","V4.1 演示快进至 42 尾血，再由实际重击完成最后一击；不是完整通关时长")
	arena.encounter.boss_health=42;arena.encounter.publish();arena.spirit_combat.use_skill(3)
	await wait_seconds(3);log_event("victory",{"state":arena.encounter.state})
	await prepare(1,Vector3(0,0,2))
	mark("defeat","完整尝试流程  ·  受伤与失败","演示设置 12 剩余生命，真实抓挠导致失败；按 R 可以快速重试")
	arena.encounter.player_health=12;arena.encounter.publish();arena.attacks.begin_attack("cub_swipe")
	await wait_seconds(2.5);log_event("defeat",{"state":arena.encounter.state})
	mark("retry","完整尝试流程  ·  R 重试 / 开发阶段直达","普通重试从正式存档点；开发模式可选 P2、P3，且不覆盖存档")
	var key:=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true;arena._unhandled_key_input(key)
	await wait_seconds(1.5)
	arena.developer_test.toggle_mode();arena.developer_test.start_phase(2);await wait_seconds(1.8)
	arena.developer_test.start_phase(3);await wait_seconds(1.8)
	log_event("retry",{"phase":arena.phase,"state":arena.encounter.state,"entry_phase":arena.encounter.entry_phase})

func action_workbench() -> void:
	change_scene_to_file("res://Scenes/Qingqiu/FoxRigV4/FoxActionWorkbench.tscn");await scene_changed
	var work=current_scene
	for child in work.get_children():
		if child is CanvasLayer:child.visible=false
	live.text="28 个制作动作 · 含待机 / 眨眼共 34 段 · 尚未在 Spine Editor 实导保存"
	for phase in [1,2,3]:
		work.load_phase(phase)
		for index in work.names.size():
			work.selected=index;work.replay()
			var name: String=work.names[index]
			mark("p%d_%s"%[phase,name],"P%d  ·  %s"%[phase,work.puppet.action_player.library[name]["label"]],"同源骨骼关键帧预演；运行时尾动 / 镜头 / 碰撞 / Shader 未烘焙到 Spine")
			work.actions_label.text="Spine 4.2 交换数据已提供；尚未在 Spine Editor 实导保存"
			await wait_seconds(maxf(1.4,work.puppet.action_player.duration+.35))
			log_event("action",{"phase":phase,"name":name,"duration":work.puppet.action_player.duration})

func opening_demo() -> void:
	mark("opening","雾中来客  ·  当前普通开场","正常 Enter 路线：分雾、幼狐跃入、落地花纹、凝视，再返回操作")
	arena.restart_playtest(true)
	await wait_seconds(4.9)
	Input.action_press("MoveLeft");await wait_seconds(.8);release_movement()
	log_event("opening",{"state":arena.encounter.state,"active":arena.presentation.opening.active,"phase_time":arena.encounter.phase_elapsed})

func checkpoint_demo() -> void:
	await prepare(1,Vector3(0,0,2))
	mark("save_p2","阶段存档  ·  P1 通关后从 P2 继续","演示尾血快进；真实近战击败后写入独立测试存档，不使用玩家正式存档")
	arena.encounter.start_encounter(1,false,true)
	arena.player.position=Vector3(0,0,2);arena.encounter.boss_health=10;arena.encounter.publish()
	arena.spirit_combat.use_skill(0);await wait_seconds(.6)
	var store=arena.encounter.checkpoint
	log_event("saved_p2",{"saved_phase":store.phase,"file_exists":FileAccess.file_exists(store.file_path)})
	arena.encounter.stop_to_preview();arena.restart_playtest(false);await wait_seconds(2)
	mark("save_p3","阶段存档  ·  P2 通关后从 P3 继续","重新读取磁盘记录，满血 / 清冷却从保存阶段开始；开发跳阶段不覆盖它")
	arena.player.position=Vector3(0,0,2);arena.encounter.boss_health=10;arena.encounter.publish()
	arena.spirit_combat.use_skill(0);await wait_seconds(.6)
	log_event("saved_p3",{"saved_phase":store.phase,"file_exists":FileAccess.file_exists(store.file_path)})
	arena.encounter.stop_to_preview()
	arena.encounter.checkpoint=preload("res://Scripts/Qingqiu/stage_checkpoint.gd").new(store.file_path)
	arena.restart_playtest(false);await wait_seconds(2)
	log_event("loaded_p3",{"loaded_checkpoint":arena.encounter.checkpoint.phase,"phase":arena.phase,"hp":arena.encounter.player_health,"state":arena.encounter.state})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"/stills"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"/capture_saves"))
	build_overlay()
	if chapter=="actions":await action_workbench()
	else:
		change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
		arena=current_scene
		arena.set_process_unhandled_key_input(false);arena.spirit_combat.set_process_unhandled_input(false)
		arena.presentation.audio_enabled=false;arena.combat_audio.audio_enabled=false
		arena.get_node("Presentation/Interface").visible=false
		# Recording captions occupy the original top HUD area.
		arena.encounter.hud.boss_panel.offset_top=196
		arena.encounter.hud.boss_panel.offset_bottom=228
		arena.developer_test.visible=false
		log_event("current_build",{"player_max_hp":arena.encounter.player_max_health,"sweep_tooltip":arena.encounter.hud.skill_bar.buttons[1].tooltip_text,"heavy_tooltip":arena.encounter.hud.skill_bar.buttons[3].tooltip_text,"ward_tooltip":arena.encounter.hud.skill_bar.buttons[2].tooltip_text})
		match chapter:
			"opening":await opening_demo()
			"checkpoint":await checkpoint_demo()
			"p1":await phase_one()
			"transition2":await transition(2)
			"p2":await phase_two()
			"transition3":await transition(3)
			"p3":await phase_three()
			"flow":await flow()
	if not sections.is_empty():sections[-1]["end_frame"]=frame_count
	var report={"chapter":chapter,"fps":30,"frames":frame_count,"seconds":float(frame_count)/30.0,"sections":sections,"observations":events,"scripted":true,"positions_and_attacks_arranged":true,"human_full_playthrough":false,"audio_driver":"Dummy","source_gameplay_modified":false,"version":"V4.1-current","player_max_hp":120,"production_save_used":false}
	var file:=FileAccess.open(OUT+"/"+chapter+"_capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SUBMISSION_CAPTURE_FINISHED ",chapter," frames=",frame_count)
	release_movement()
	if arena!=null:arena.combat_audio.stop_music()
	if current_scene!=null:current_scene.queue_free();current_scene=null
	layer.queue_free()
	for i in 5:await process_frame
	await create_timer(.08).timeout
	quit()
