extends Node


# --- CONFIG ----------------------------------------------------

# One file per mode: user://save_classic.json, user://save_rush.json, etc.
const SAVE_PATH_TEMPLATE := "user://save_%s.json"
# Default data per mode. Change/add as you like.
var DEFAULT_DATA: Dictionary = {
	"general" :{
		"save_questions_since_last_ad" : 0,
		"save_ad_pending" : false
	},
	
	"rush": {
		"rush_best_score" : 0,
		"rush_correct_perc" : 0,
		"rush_total_normal_time" : 0,
		"rush_best_streak" : 0,
		"rush_best_single_time" : 0,
		"rush_total_quicks" : 0,
		"save_rush_atk_quick" : false,
		"save_rush_def_freeze": true,
		"save_rush_ctrl_easy" : false,
		"achievements" : {
			"rush_time_60": false,
			"rush_time_120": false,
			"rush_score_100": false,
			"rush_score_200": false,
			"rush_recover_10_to_30": false,
			"rush_recover_5_to_30": false,
			"rush_extra_6": false,
			"rush_extra_10": false,
			"under_10_5_questions" : false,
			"under_5_5_questions" : false
		}
	},


 "memoryclash": {
		"mc_best_time" : 10000,
		"mc_total_wrongs" : 0,
		"mc_max_wrong_in_1" : 0,
		"mc_average_time" : 0.0,
		"mc_fastest_time" : 0.0,
		"mc_best_streak" : 0,
		"save_mc_ctrl_repeat" : false,
		"save_mc_def_cumulative" : true,
		"save_mc_atk_x2" : false,
		"mc_achievements" : {
			"mc_finish_under_240": false,
			"mc_finish_under_120": false,
			"mc_wrong_20_or_less": false,
			"mc_wrong_10_or_less": false,
			"mc_no_more_than_5_same": false,
			"mc_no_more_than_3_same": false,
			"mc_streak_4": false,
			"mc_streak_8": false,
		}
	},
	

"betarena": {
	"ba_save_total_points"  : 0,
	"ba_save_total_bet" : 0,
	"ba_save_best_profit" : 0,
	"ba_save_best_bet" : 0,
	"ba_save_max_fee" : 0,
	"ba_save_longest_streak" : 0,
	"ba_save_atk_double" : false,
	"ba_save_def_profit" : true,
	"ba_save_ctrl_reverse" : false,
		"ba_achievements": {
			"ba_total_bet_100": false,
			"ba_total_bet_200": false,

			"ba_win_5_over_10": false,
			"ba_win_10_over_10": false,

			"ba_end_100_points": false,
			"ba_end_200_points": false,

			"ba_single_30_profit": false,
			"ba_single_60_profit": false
		}
	}
}
# --- RUNTIME DATA (IN MEMORY) ----------------------------------
var _saves: Dictionary = {} # mode_name -> Dictionary with data
func _ready() -> void:
	# Initialize all known modes with defaults, then try to load from disk.
	for mode_name in DEFAULT_DATA.keys():
		_saves[mode_name] = DEFAULT_DATA[mode_name].duplicate(true)
		_load_mode_internal(mode_name)


# --- PUBLIC HELPERS YOU’LL USE FROM ANYWHERE -------------------

# Get full data dictionary for a mode (e.g. "classic").
func get_mode_data(mode: String) -> Dictionary:
	mode = mode.to_lower()
	if not _saves.has(mode):
		# If new mode appears, start with empty dictionary.
		_saves[mode] = {}
	return _saves[mode]


# Get a single value from a mode (e.g. high_score of "classic").
func get_mode_value(mode: String, key: String, default: Variant = null) -> Variant:
	mode = mode.to_lower()
	if not _saves.has(mode):
		return default
	if not _saves[mode].has(key):
		return default
	return _saves[mode][key]


# Set a value in a mode (this only changes memory, not file).
func set_mode_value(mode: String, key: String, value: Variant) -> void:
	mode = mode.to_lower()
	if not _saves.has(mode):
		_saves[mode] = {}
	_saves[mode][key] = value


# Save only one mode to its own file.
func save_mode(mode: String) -> void:
	mode = mode.to_lower()
	if not _saves.has(mode):
		push_warning("SaveManager: Trying to save unknown mode: %s" % mode)
		return
	
	var path := _get_mode_path(mode)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Could not open file for writing: %s" % path)
		return
	
	var json_text := JSON.stringify(_saves[mode])
	file.store_string(json_text)
	file.close()


# Load only one mode from its file (overwrites current data for that mode).
func load_mode(mode: String) -> void:
	mode = mode.to_lower()
	_load_mode_internal(mode)


# Save ALL modes that exist in memory.
func save_all() -> void:
	for mode in _saves.keys():
		save_mode(mode)


# Reload ALL known modes from disk (keeping defaults if file doesn’t exist).
func load_all() -> void:
	for mode in DEFAULT_DATA.keys():
		_load_mode_internal(mode)


# --- INTERNAL HELPERS ------------------------------------------
func _get_mode_path(mode: String) -> String:
	return SAVE_PATH_TEMPLATE % mode.to_lower()


func _load_mode_internal(mode: String) -> void:
	var path := _get_mode_path(mode)
	
	if not FileAccess.file_exists(path):
		# No file yet → keep defaults if we have them, else empty.
		if DEFAULT_DATA.has(mode):
			_saves[mode] = DEFAULT_DATA[mode].duplicate(true)
		elif not _saves.has(mode):
			_saves[mode] = {}
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Could not open file for reading: %s" % path)
		return
	var json_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_saves[mode] = parsed
	else:
		push_warning("SaveManager: Invalid JSON in %s, using defaults." % path)
		if DEFAULT_DATA.has(mode):
			_saves[mode] = DEFAULT_DATA[mode].duplicate(true)
		else:
			_saves[mode] = {}

func get_default_mode_data(mode: String) -> Dictionary:
	if DEFAULT_DATA.has(mode):
		return DEFAULT_DATA[mode].duplicate(true)
	return {}
	

func reset_mode_to_defaults(mode: String) -> void:
	_saves[mode] = get_default_mode_data(mode)
	save_mode(mode)
