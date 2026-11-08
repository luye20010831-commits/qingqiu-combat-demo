extends RefCounted
## A stage checkpoint only: fresh HP/cooldowns are owned by start_encounter.
const DEFAULT_PATH:="user://qingqiu_checkpoint.cfg"
const FORMAT_VERSION:=1
var file_path: String
var phase:=1
var last_error: Error=OK
var backup_error: Error=OK
var recovered_from_backup:=false
var primary_valid:=false

static func path_for_current_run() -> String:
	# External test scripts never read/write the player's real progress. Tests
	# that exercise disk persistence explicitly inject their own isolated file.
	var args:=OS.get_cmdline_args()
	if args.has("--script") or args.has("-s"):
		return str(ProjectSettings.get_setting("qingqiu/testing/checkpoint_path",""))
	return DEFAULT_PATH

func _init(path: String="") -> void:
	file_path=path
	load_progress()

func read_record(path: String) -> Dictionary:
	var cfg:=ConfigFile.new()
	var error:=cfg.load(path)
	if error!=OK:return {"error":error}
	var version: Variant=cfg.get_value("progress","version",null)
	var saved_phase: Variant=cfg.get_value("progress","next_phase",null)
	if typeof(version)!=TYPE_INT or version!=FORMAT_VERSION or typeof(saved_phase)!=TYPE_INT:
		return {"error":ERR_FILE_CORRUPT}
	if int(saved_phase)<1 or int(saved_phase)>3:return {"error":ERR_FILE_CORRUPT}
	return {"error":OK,"phase":int(saved_phase)}

func load_progress() -> void:
	phase=1;last_error=OK;backup_error=OK;recovered_from_backup=false;primary_valid=false
	if file_path.is_empty():return
	var primary:=read_record(file_path)
	if primary["error"]==OK:
		phase=primary["phase"];primary_valid=true;return
	var backup:=read_record(file_path+".bak")
	if backup["error"]==OK:
		phase=backup["phase"];recovered_from_backup=true;return
	if primary["error"]!=ERR_FILE_NOT_FOUND:last_error=primary["error"]
	elif backup["error"]!=ERR_FILE_NOT_FOUND:last_error=backup["error"]

func write_record(path: String,cfg: ConfigFile) -> Error:
	var absolute:=ProjectSettings.globalize_path(path)
	var error:=DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error!=OK:return error
	var temporary:=absolute+".tmp"
	error=cfg.save(temporary)
	if error!=OK:return error
	error=DirAccess.rename_absolute(temporary,absolute)
	if error!=OK:DirAccess.remove_absolute(temporary)
	return error

func advance_to(next_phase: int) -> Error:
	var target:=maxi(phase,clampi(next_phase,1,3))
	if target==phase and primary_valid and last_error==OK:return OK
	# Keep the earned checkpoint within this session even if storage fails.
	phase=target
	if file_path.is_empty():last_error=OK;return OK
	var cfg:=ConfigFile.new()
	cfg.set_value("progress","version",FORMAT_VERSION)
	cfg.set_value("progress","next_phase",phase)
	last_error=write_record(file_path,cfg)
	if last_error!=OK:return last_error
	primary_valid=true;recovered_from_backup=false
	backup_error=write_record(file_path+".bak",cfg)
	return OK
