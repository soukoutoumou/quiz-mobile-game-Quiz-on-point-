extends Node

## Communication Assists / Achievements

signal achievement_mc_unlocked(id: String)
signal assist_changed(selected: String) 
var mc_achievement_descriptions: Dictionary = {
	"mc_finish_under_240": "Finish the MemoryClash run in under 4 minutes",
	"mc_finish_under_120": "Finish the MemoryClash run in under 2 minutes",
	"mc_wrong_20_or_less": "Finish the run with 20 or fewer wrong answers total",
	"mc_wrong_10_or_less": "Finish the run with 10 or fewer wrong answers total",
	"mc_no_more_than_5_same": "Never miss the same question more than 5 times",
	"mc_no_more_than_3_same": "Never miss the same question more than 3 times",
	"mc_streak_4": "Answer 4 questions correctly in a row",
	"mc_streak_8": "Answer 8 questions correctly in a row"
}


## Global Variables
var mc_ctrl_repeat: bool = false
var mc_def_cumulative: bool = true
var mc_atk_x2: bool = false


var best_time : float = 0.0
var mc_ach_total : int = 0
var	mc_ach_done : int = 0

var total_wrongs : int = 0
var max_wrong_in_1 : int = 0
var average_time : float = 0.0
var fastest_time : float = 0.0
var best_streak : int = 0

var mc_trophy : bool = false

## Stats Holder

class McStats:
	var max_timer: float = 0.0            
	var wrong_answers: int = 0    
	var less_2_every_questions : bool = false
	var less_3_every_questions : bool = false
	var longest_streak: int = 0
	var average_time_per_answer: float = 0.0
	var fastest_question : float = 0.0
	var max_wrongs_in_1 : int = 0
var last_run_stats: McStats = null


var mc_achievements_state: Dictionary = {
	"mc_finish_under_240": false,
	"mc_finish_under_120": false,
	"mc_wrong_20_or_less": false,
	"mc_wrong_10_or_less": false,
	"mc_no_more_than_5_same": false,
	"mc_no_more_than_3_same": false,
	"mc_streak_4": false,
	"mc_streak_8": false,
}

func select_assist(kind: String) -> void:
	# kind: "atk", "def", "ctrl", "none"
	var new_atk := (kind == "atk")
	var new_def := (kind == "def")
	var new_ctrl := (kind == "ctrl")

	# If nothing actually changes, do nothing
	if mc_atk_x2 == new_atk and mc_def_cumulative == new_def and mc_ctrl_repeat == new_ctrl:
		return
	mc_atk_x2 = new_atk
	mc_def_cumulative = new_def
	mc_ctrl_repeat = new_ctrl
	emit_signal("assist_changed", kind)

## Check achievement helpers 

func check_mc_achievements(stats: McStats) -> void:
	# 1) Timer achievements
	if stats.max_timer <= 240.0:
		_try_unlock_achievement("mc_finish_under_240")

	if stats.max_timer <= 120.0:
		_try_unlock_achievement("mc_finish_under_120")

	if stats.wrong_answers <= 20:
		_try_unlock_achievement("mc_wrong_20_or_less")

	if stats.wrong_answers <= 10:
		_try_unlock_achievement("mc_wrong_10_or_less")

	if stats.less_3_every_questions:
		_try_unlock_achievement("mc_no_more_than_5_same")

	if stats.less_2_every_questions:
		_try_unlock_achievement("mc_no_more_than_3_same")

	if stats.longest_streak >= 4:
		_try_unlock_achievement("mc_streak_4")

	if stats.longest_streak >= 8:
		_try_unlock_achievement("mc_streak_8")

	_save_mc_achievements()


func _try_unlock_achievement(id: String) -> void:
	if mc_achievements_state.get(id, false):
		return  # already unlocked
	mc_achievements_state[id] = true
	emit_signal("achievement_mc_unlocked", id)  # 🔔 tell the UI



## Save/Load Memory Clash helpers 

func _save_mc_achievements() -> void:
	var data = SaveManager.get_mode_data("memoryclash")
	data["mc_achievements"] = mc_achievements_state.duplicate(true)
	SaveManager.save_mode("memoryclash")
	pass
func load_mc_from_save() -> void:
	var data = SaveManager.get_mode_data("memoryclash")
	best_time = data.get("mc_best_time", 0)
	total_wrongs = data.get("mc_total_wrongs", 0)
	max_wrong_in_1 = data.get("mc_max_wrong_in_1", 0)
	average_time = data.get("mc_average_time", 0)
	fastest_time = data.get("mc_fastest_time", 0)
	best_streak = data.get("mc_best_streak", 0)
	mc_ctrl_repeat = data.get("save_mc_ctrl_repeat", false)
	mc_def_cumulative = data.get("save_mc_def_cumulative", true)
	mc_atk_x2 = data.get("save_mc_atk_x2", false)

	if data.has("mc_achievements"):
		mc_achievements_state = data["mc_achievements"].duplicate(true)
		

func save_mc_best_stats() -> void:
	var data = SaveManager.get_mode_data("memoryclash")
	data["mc_best_time"] = best_time
	data["mc_total_wrongs"] = total_wrongs
	data["mc_max_wrong_in_1"] = max_wrong_in_1
	data["mc_average_time"] = average_time
	data["mc_fastest_time"] = fastest_time
	data["mc_best_streak"] = best_streak
	data["save_mc_ctrl_repeat"] = mc_ctrl_repeat
	data["save_mc_def_cumulative"] = mc_def_cumulative
	data["save_mc_atk_x2"] = mc_atk_x2
	SaveManager.save_mode("memoryclash")


func reset_mc_data() -> void:
	SaveManager.reset_mode_to_defaults("memoryclash")
	load_mc_from_save()
