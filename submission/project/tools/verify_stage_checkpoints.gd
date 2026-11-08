extends SceneTree
const STORE=preload("res://Scripts/Qingqiu/stage_checkpoint.gd")
var arena
var failed:=false
var checks:=0
var evidence:="res://artifacts/qingqiu/stage_checkpoints"
var isolated_path: String
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func frames(count: int) -> void:
	for i in count:await process_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
	Input.parse_input_event(event);await frames(2)
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false
	Input.parse_input_event(event);await frames(2)
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))
func load_scene() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	arena=current_scene;await frames(2)
	arena.encounter.set_process(false);arena.attacks.set_process(false);arena.presentation.set_process(false)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():evidence=args[0]
	DirAccess.make_dir_recursive_absolute(evidence)
	isolated_path=ProjectSettings.globalize_path(evidence).path_join("checkpoint_"+str(Time.get_ticks_usec())+".cfg")
	ProjectSettings.set_setting("qingqiu/testing/checkpoint_path",isolated_path)
	check(STORE.path_for_current_run()==isolated_path,"Automated run uses only its explicitly isolated checkpoint file")
	var store=STORE.new(isolated_path)
	check(store.phase==1 and store.last_error==OK and not FileAccess.file_exists(isolated_path),"Missing checkpoint starts at P1 without creating a player save")
	check(store.advance_to(2)==OK and FileAccess.file_exists(isolated_path),"P2 checkpoint writes a real config file")
	check(FileAccess.file_exists(isolated_path+".bak") and not FileAccess.file_exists(isolated_path+".tmp"),"Successful save keeps a backup and removes its temporary file")
	check(STORE.new(isolated_path).phase==2,"A new store object reloads P2 from disk")
	check(store.advance_to(3)==OK and STORE.new(isolated_path).phase==3,"Atomic replacement upgrades an existing P2 file to P3")
	var bytes:=FileAccess.get_file_as_bytes(isolated_path)
	check(store.advance_to(2)==OK and FileAccess.get_file_as_bytes(isolated_path)==bytes,"Older clears cannot move a P3 checkpoint backward or rewrite it")
	var corrupt:=FileAccess.open(isolated_path,FileAccess.WRITE);corrupt.store_string("[progress]\nversion=1\nnext_phase=99\n");corrupt.close()
	var recovered=STORE.new(isolated_path)
	check(recovered.phase==3 and recovered.recovered_from_backup,"Corrupt primary recovers the latest P3 checkpoint from its backup")
	check(recovered.advance_to(3)==OK and STORE.new(isolated_path).primary_valid,"The next successful commit repairs the primary without downgrading progress")
	var blocked_parent:=isolated_path+"_parent_file"
	var blocker:=FileAccess.open(blocked_parent,FileAccess.WRITE);blocker.store_string("block");blocker.close()
	var unwritable=STORE.new(blocked_parent.path_join("save.cfg"))
	check(unwritable.advance_to(2)!=OK and unwritable.phase==2,"Failed storage is reported while the earned point remains usable in this session")
	var retry=STORE.new(isolated_path+"_retry.cfg");retry.advance_to(2)
	var retry_path: String=retry.file_path;retry.file_path=blocked_parent.path_join("retry.cfg")
	check(retry.advance_to(3)!=OK and retry.phase==3,"An already valid checkpoint can retain a newly earned point during a later write failure")
	retry.file_path=retry_path
	check(retry.advance_to(3)==OK and STORE.new(retry_path).phase==3,"The same earned point is retried to disk once storage becomes writable")
	# Main-flow integration gets a separate empty slot; never use the player slot.
	isolated_path+="_flow.cfg"
	ProjectSettings.set_setting("qingqiu/testing/checkpoint_path",isolated_path)
	await load_scene()
	var e=arena.encounter;var d=arena.developer_test
	if e.checkpoint.file_path!=isolated_path:
		check(false,"Unsafe checkpoint path mismatch; no battle mutation attempted");quit(2);return
	check(arena.phase==1 and e.is_preview() and e.checkpoint.phase==1,"A fresh main-scene session opens at P1")
	await key(KEY_ENTER)
	check(e.state==e.State.OPENING and e.attempt_saves_progress,"Normal Enter opts into real checkpoint progress and P1 opening")
	arena.presentation.opening.finish(true)
	check(not FileAccess.file_exists(isolated_path),"Merely starting or skipping the opening does not create a checkpoint")
	e.accept_boss_hit(e.boss_health)
	check(e.checkpoint.phase==2 and STORE.new(isolated_path).phase==2,"P1 defeat persists P2 synchronously before any transition frame")
	check(arena.get_node("Presentation/Interface/Subtitle").text.contains("P2"),"The existing scene hint confirms the newly saved P2 point")
	await key(KEY_R)
	check(arena.phase==2 and e.state==e.State.RUNNING and e.player_health==120,"R during P1 departure resumes the saved P2 with full health")
	check(e.attempt_saves_progress and not arena.presentation.is_busy() and e.phase_elapsed==0,"Checkpoint retry is official, clean and directly playable")
	await screenshot("p2_checkpoint_retry")
	# Reinstantiate the whole arena to exercise startup and the new store instance.
	arena.queue_free();current_scene=null;await frames(4)
	await load_scene();e=arena.encounter;d=arena.developer_test
	check(e.is_preview() and arena.phase==2 and e.checkpoint.phase==2,"Reopening the complete scene loads the P2 preview from disk")
	check(arena.get_node("Presentation/Interface/Subtitle").text.contains("P2"),"Startup labels the saved stage before the player continues")
	await screenshot("continue_p2")
	await key(KEY_ENTER)
	check(arena.phase==2 and e.state==e.State.RUNNING and not arena.presentation.opening.active,"Enter continues P2 without replaying the P1 opening")
	e.player_health=44;e.player_hit_grace=0;e.damage_player(44);await frames(3)
	check(e.state==e.State.DEFEAT and STORE.new(isolated_path).phase==2,"Losing within P2 retains the earned P2 checkpoint")
	await key(KEY_ENTER)
	check(arena.phase==2 and e.player_health==120 and not arena.player_avatar.dead,"Enter after defeat restarts P2 as a fresh full-health attempt")
	e.accept_boss_hit(e.boss_health)
	check(STORE.new(isolated_path).phase==3 and e.checkpoint.phase==3,"P2 defeat immediately replaces the checkpoint with P3")
	await key(KEY_TAB)
	check(e.is_preview() and e.checkpoint.phase==3,"Leaving during the transition keeps the new P3 point")
	arena.queue_free();current_scene=null;await frames(4)
	await load_scene();e=arena.encounter;d=arena.developer_test
	check(e.is_preview() and arena.phase==3,"A later scene load opens at the saved P3")
	await key(KEY_ENTER)
	check(arena.phase==3 and e.state==e.State.RUNNING and e.boss_health==2000 and e.player_health==120,"P3 continuation uses current full phase and player HP")
	await screenshot("continue_p3")
	e.accept_boss_hit(e.boss_health);await frames(3)
	check(e.state==e.State.VICTORY and STORE.new(isolated_path).phase==3,"Final victory keeps P3 available instead of clearing progress")
	await key(KEY_R)
	check(arena.phase==3 and e.state==e.State.RUNNING,"Normal R after victory retries the saved P3")
	var hash_before:=FileAccess.get_file_as_bytes(isolated_path)
	await key(KEY_F8);await key(KEY_F6)
	check(arena.phase==2 and not e.attempt_saves_progress,"Developer direct entry is explicitly a non-saving attempt")
	e.accept_boss_hit(e.boss_health)
	check(FileAccess.get_file_as_bytes(isolated_path)==hash_before,"Developer P2 clear cannot overwrite the official checkpoint file")
	await key(KEY_R)
	check(arena.phase==2 and not e.attempt_saves_progress,"Developer R continues to retry its chosen test origin")
	await key(KEY_F8);await key(KEY_R)
	check(arena.phase==3 and e.attempt_saves_progress,"Closing developer mode returns R to the official saved point")
	# A developer P2 clear must not unlock P3 for a fresh P1 player either.
	ProjectSettings.set_setting("qingqiu/testing/checkpoint_path",isolated_path+"_fresh.cfg")
	arena.queue_free();current_scene=null;await frames(4);await load_scene();e=arena.encounter;d=arena.developer_test
	await key(KEY_F8);await key(KEY_F6);e.accept_boss_hit(e.boss_health)
	check(e.checkpoint.phase==1 and not FileAccess.file_exists(e.checkpoint.file_path),"Fresh player's developer clear cannot unlock or create official progress")
	print("STAGE_CHECKPOINTS ",checks," checks; passed=",not failed)
	var f:=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":not failed,"isolated_checkpoint":isolated_path,"production_path_read_only_reference":ProjectSettings.globalize_path(STORE.DEFAULT_PATH),"audio_driver":"Dummy","scripted_phase_clears":true,"human_full_playthrough":false,"production_save_used":false},"\t"));f.close()
	arena.queue_free();current_scene=null
	for i in 4:await process_frame
	await create_timer(.08).timeout
	quit(int(failed))
