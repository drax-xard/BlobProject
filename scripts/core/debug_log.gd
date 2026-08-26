extends Node
class_name DebugLog

const LOG_DIR := "user://logs"
const LOG_FILE := "debug.log"

static var _file: FileAccess = null
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var path := LOG_DIR.path_join(LOG_FILE)
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file:
		_file.store_line("=== BlobProject Debug Log ===")
		_file.store_line("Session started: %s" % Time.get_datetime_string_from_system())
		_file.store_line("")

static func info(message: String) -> void:
	_ensure_initialized()
	var formatted := "[INFO] %s" % message
	_write(formatted)
	print(formatted)

static func warn(message: String) -> void:
	_ensure_initialized()
	var formatted := "[WARN] %s" % message
	_write(formatted)
	push_warning(formatted)

static func error(message: String) -> void:
	_ensure_initialized()
	var formatted := "[ERROR] %s" % message
	_write(formatted)
	push_error(formatted)

static func data_issue(record_id: String, field: String, expected: String, got: String) -> void:
	_ensure_initialized()
	var formatted := "[DATA] Record '%s' — field '%s': expected %s, got %s" % [record_id, field, expected, got]
	_write(formatted)
	push_warning(formatted)

static func _write(text: String) -> void:
	if _file:
		_file.store_line(text)
		_file.flush()
