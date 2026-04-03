extends Control
const QUESTIONS_PER_RUN := 30


var question_paths := {
	"Easy":     "res://Questions/Greek/questions_easy.json",
	"Medium":   "res://Questions/Greek/questions_medium.json",
	"Hard":     "res://Questions/Greek/questions_hard.json",
	"Ultimate": "res://Questions/Greek/questions_ultimate.json"
}

var weights := {
	"Easy": 0.45,
	"Medium": 0.4,
	"Hard": 0.3,
	"Ultimate": 0.2
}

@onready var Statsoverlay_panel: TextureRect = $VBoxAnswers/Panel_answer1/OverlayPanel
@onready var Statsoverlay_panel2: TextureRect = $VBoxAnswers/Panel_answer2/OverlayPanel
@onready var Statsoverlay_panel3: TextureRect = $VBoxAnswers/Panel_answer3/OverlayPanel
@onready var Statsoverlay_panel4: TextureRect = $VBoxAnswers/Panel_answer4/OverlayPanel
@onready var Streak_label : RichTextLabel = $Panel_streak/RichTextLabel
var run_questions: Array = []
var run_questions_all: Array = [] 
var current_question: Dictionary = {}
@onready var Label_time: Label = $AspectRatioContainer/Panel/Label_time
@onready var Answer1: TextureButton = $VBoxAnswers/Panel_answer1/Answer1
@onready var Answer2: TextureButton = $VBoxAnswers/Panel_answer2/Answer2
@onready var Answer3: TextureButton = $VBoxAnswers/Panel_answer3/Answer3
@onready var Answer4: TextureButton = $VBoxAnswers/Panel_answer4/Answer4
var time_left: float = 0
const CORRECT_TEXTURE_PATH = "res://Ui/ThemeWarm/quiz_scene/answer_correct_v2.png"
const WRONG_TEXTURE_PATH   = "res://Ui/ThemeWarm/quiz_scene/answer_incorrect_v2.png"
var default_answer_texture: Texture2D = null
var original_stylebox: StyleBox = null
@onready var answer_panels := [
	$VBoxAnswers/Panel_answer1,
	$VBoxAnswers/Panel_answer2,
	$VBoxAnswers/Panel_answer3,
	$VBoxAnswers/Panel_answer4,
]
@onready var assist_x2_label: RichTextLabel = $Assist_x2_label
@onready var Assist_repeat_texture: TextureRect = $Panel_question/Assist_repeat_texture
@onready var Assist_repeat_label: Label = $Panel_question/Assist_repeat_label
@onready var timer_panel: Panel = $AspectRatioContainer/Panel


######## Assist #####
var atk_correct_2 : int = 0
var atk_answers_2 : int = 0

var ctrl_active: bool = false
var ctrl_questions_left: int = 0
var ctrl_pool: Array = []   # will hold Dictionaries
const CTRL_POOL_SIZE := 4
const CTRL_DURATION := 8

var def_cum_quick : bool = false
var def_cum_counter : int = 0
var def_cum_timer : float = 0.0
var _sb_base: StyleBoxFlat
var _sb_shadow: StyleBoxFlat
var _shadow_on := false

const TIMER_BG_BASE := Color("#1F1F1F")    
const TIMER_BG_GLOW := Color("#2A2F3A")      
##############
var correct_answer_text: String  
var correct_panel_index: int = -1
var quickfire_timer : float = 0.0
var total_time : float = 0.0
var less_than_3_every_questions : bool = false
var less_than_2_every_questions : bool = false
var streak : int = 0
var max_streak : int = 0
var total_wrong_answers : int = 0

var total_questions : int = 0
var average_time : float = 0.0
var question_time : float = 0.0
var total_time_answers : float = 0.0
var fastest_correct_answer : float = 0.0
var correct_index : int = 0

# Initiation ##
func _ready() :
	SoundManager.stop_music()
	### Assists #########
	atk_correct_2 = 2
	atk_answers_2 = 0
	quickfire_timer = 0
	correct_index = 0
	update_remaining_questions(correct_index, QUESTIONS_PER_RUN)
	fastest_correct_answer = 1000.0
	total_time_answers = 0.0
	total_time = 0.0
	less_than_3_every_questions = false
	less_than_2_every_questions = false
	streak = 0
	max_streak = 0
	total_wrong_answers = 0
	total_questions  = 0
	average_time = 0.0
	question_time = 0.0
	_apply_assist_icon_from_globals()
	if original_stylebox == null:
		original_stylebox = answer_panels[0].get_theme_stylebox("panel").duplicate()
	_sb_base = timer_panel.get_theme_stylebox("panel").duplicate()
	_sb_base.shadow_size = 0
	_sb_shadow = _sb_base.duplicate()
	_sb_shadow.shadow_color = Color("#4A6BFF", 0.45) # bluish, subtle
	_sb_shadow.shadow_size = 10
	_sb_shadow.shadow_offset = Vector2(0, 0)

	timer_panel.add_theme_stylebox_override("panel", _sb_base)
	_shadow_on = false
	if Answer1:
		default_answer_texture = Answer1.texture_normal
	Streak_label.text = "[outline_color=#1A1827][outline_size=2][color=#E4C77A]x" + str(streak) + "[/color]"
	start_mc()
	
func start_mc() -> void:
	if AdsManager.maybe_show_interstitial():
		AdsManager.interstitial_finished.connect(_on_ad_finished_start, CONNECT_ONE_SHOT)
	else:
		_on_ad_finished_start()


func _on_ad_finished_start() -> void:
	randomize()  # ensures different random question each run
	prepare_run_questions()
	current_question = get_random_question()
	display_question(current_question)


# Questions Handlers ##

func load_questions(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("❌ File not found: " + path)
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()

	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_ARRAY:
		push_error("❌ JSON is not an array in: " + path)
		return []
	return parsed
	

func prepare_run_questions() -> void:
	run_questions.clear()
	run_questions_all.clear()

	var questions_by_diff: Dictionary = {}
	for diff in question_paths.keys():
		var arr: Array = load_questions(question_paths[diff])
		if arr.is_empty():
			push_warning("No questions found for difficulty: " + diff)
		questions_by_diff[diff] = arr.duplicate()

	for i in range(QUESTIONS_PER_RUN):
		var chosen_diff := weighted_pick(weights)
		var pool := questions_by_diff.get(chosen_diff, []) as Array

		if pool.is_empty():
			var diffs_with_questions: Array = []
			for d in questions_by_diff.keys():
				if (questions_by_diff[d] as Array).size() > 0:
					diffs_with_questions.append(d)

			if diffs_with_questions.is_empty():
				push_warning("Not enough questions to fill the pool.")
				break

			chosen_diff = diffs_with_questions[randi() % diffs_with_questions.size()]
			pool = questions_by_diff[chosen_diff]

		var idx := randi() % pool.size()
		var q: Dictionary = pool[idx]
		pool.remove_at(idx)
		questions_by_diff[chosen_diff] = pool

		q["difficulty"] = chosen_diff
		q["wrong_count"] = 0   # 🔹 track mistakes per question

		run_questions.append(q)
		run_questions_all.append(q)  # 🔹 save for achievement checks later
func get_random_question() -> Dictionary:
	if run_questions.is_empty():
		push_warning("No more questions left in run_questions.")
		return {}

	# CONTROL OVERRIDE
	if ctrl_active:
		# If duration expired or pool empty -> fall back to normal
		if ctrl_questions_left <= 0 or ctrl_pool.is_empty():
			ctrl_active = false
			Assist_repeat_label.visible = false
			Assist_repeat_texture.visible = false
		else:
			Assist_repeat_texture.visible = true
			Assist_repeat_label.text = str(ctrl_questions_left)
			Assist_repeat_label.visible = true
			ctrl_questions_left -= 1
			var idx := randi() % ctrl_pool.size()
			return ctrl_pool[idx]

	# NORMAL BEHAVIOR
	var idx := randi() % run_questions.size()
	return run_questions[idx]
	
func weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for w in weights.values():
		total += w

	var r := randf() * total

	for key in weights.keys():
		r -= weights[key]
		if r <= 0:
			return key
	
	# fallback (should never happen)
	return weights.keys()[0]
func remove_question_from_pool(question: Dictionary) -> void:
	# Call this when the user answers correctly
	run_questions.erase(question)
	


# Display Logic
func display_question(q: Dictionary) -> void:
	$Label_shout.visible = false
	Statsoverlay_panel.visible = true
	Statsoverlay_panel2.visible = true
	Statsoverlay_panel3.visible = true
	Statsoverlay_panel4.visible = true
	quickfire_timer = 0.0
	question_time = 0.0
	total_questions += 1

	for btn in [Answer1, Answer2, Answer3, Answer4]:
		if btn:
			btn.texture_normal = null
			btn.texture_pressed = null
			btn.texture_hover = null
			btn.disabled = false
	if q.is_empty():
		push_error("❌ display_question: got empty question dictionary.")
		return
	var question_text: String = str(q.get("question", ""))
	var panel_q := get_node_or_null("Panel_question")
	if panel_q:
		var label_q: Label = panel_q.get_node_or_null("Label")
		if label_q:
			style_question(label_q, question_text)
	# --- Answers ---
	var options: Array = q.get("options", []).duplicate()
	correct_answer_text = str(q.get("correct_answer", ""))
	options.shuffle()  # ✅ randomize answer order
	for i in range(answer_panels.size()):
		var panel = answer_panels[i]
		if panel == null:
			continue
		var label_a: Label = panel.get_node_or_null("Label")
		if not label_a:
			continue
		var text := ""
		if i < options.size():
			text = str(options[i])
		style_answer(label_a, text)
		panel.visible = text != ""
		if text == correct_answer_text:
			correct_panel_index = i + 1


func _set_panel_label(panel_path: String, text: String) -> void:
	var panel := get_node_or_null(panel_path)
	if panel == null:
		push_warning("⚠️ Missing node: " + panel_path)
		return
	var label: Label = panel.get_node_or_null("Label")
	if label == null:
		push_warning("⚠️ Missing Label child under: " + panel_path)
		return
	label.text = text
	panel.visible = text != ""

func _apply_common_label_layout(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text            = false
	label.size_flags_vertical  = Control.SIZE_EXPAND_FILL


func style_question(
	label: Label,
	text: String,
	max_chars: int = 80,     # threshold for shrinking
	base_size: int = 64,     # normal size
	shrink: int = 18,        # how much we can shrink across the full overflow
	min_size: int = 26,      # lower clamp
	color: Color = Color("#E4C77A"),
	font: Font = null
) -> void:
	label.text = text
	_apply_common_label_layout(label)

	var length: int = text.length()
	# your original vibe: size = clamp(base - (length/max_chars)*shrink, min, base)
	var size_f: float = float(base_size) - (float(length) / float(max_chars)) * float(shrink)
	var font_size: int = int(clamp(size_f, float(min_size), float(base_size)))

	var ls := LabelSettings.new()
	ls.font_color = color
	ls.font_size  = font_size
	if font != null:
		ls.font = font
	label.label_settings = ls

func style_answer(
	label: Label,
	text: String,
	max_chars: int = 80,
	base_size: int = 46,
	shrink: int = 12,
	min_size: int = 22,
	color: Color = Color("#D4D0FF"),
	font: Font = null
) -> void:
	label.text = text
	_apply_common_label_layout(label)

	var length: int = text.length()
	var size_f: float = float(base_size) - (float(length) / float(max_chars)) * float(shrink)
	var font_size: int = int(clamp(size_f, float(min_size), float(base_size)))

	var ls := LabelSettings.new()
	ls.font_color = color
	ls.font_size  = font_size
#	ls.outline_size = 2               # thickness of the outline
#	ls.outline_color = Color.BLACK    # outline color
	if font != null:
		ls.font = font
	label.label_settings = ls


# Check Answer Logic

func check_answer(button_pressed: TextureButton) -> void:
	AdsManager.register_question_answered()
	for i in range(answer_panels.size()):
		var panel = answer_panels[i]
		if panel == null:
			continue

		var btn = panel.get_node_or_null("Answer%d" % (i + 1))
		if btn:
			btn.disabled = true
	var idx := _index_from_button(button_pressed)
	if idx == -1:
		push_warning("⚠️ Could not map pressed button to index.")
		return

	var is_correct := (idx == correct_panel_index)
	total_time_answers += question_time
	if is_correct:
		SoundManager.play_sfx("res://Sounds/correct_answer.mp3")
		correct_index += 1
		update_remaining_questions(correct_index, QUESTIONS_PER_RUN)
		if quickfire():
			if def_cum_quick :
				$Label_shout.text = "[color=#A46CFF]×%d QUICK[/color]" % def_cum_counter
				time_left -= def_cum_counter
				def_cum_counter += 1
				$Label_shout.visible = true
			else :
				$Label_shout.text = "[color=#A46CFF]QUICK![/color]"
				$Label_shout.visible = true
				time_left -= 1.0
		if question_time < fastest_correct_answer :
			fastest_correct_answer = question_time
		streak += 1
		Streak_label.text = "[outline_color=#1A1827][outline_size=2][color=#E4C77A]x" + str(streak) + "[/color]"
		if streak > max_streak :
			max_streak = streak
		remove_question_from_pool(current_question)
		ctrl_remove_from_pool(current_question)
		print("✅ Correct")
		button_pressed.texture_normal = load(CORRECT_TEXTURE_PATH)
		if atk_answers_2 > 0 :
			atk_correct_2 -= 1
			show_x2_assist(atk_correct_2)
			if atk_correct_2 == 0 :
				streak *= 2
				Streak_label.text = "[outline_color=#1A1827][outline_size=2][color=#E4C77A]x" + str(streak) + "[/color]"
				_trigger_x2_pulse()
				atk_correct_2 = 2
		if run_questions.is_empty():  ##  Finish ?
			if AdsManager.maybe_show_interstitial():
				AdsManager.interstitial_finished.connect(_on_ad_finished_end, CONNECT_ONE_SHOT)
			else:
				_on_ad_finished_end()
			return
	else:
		SoundManager.play_sfx("res://Sounds/wrong_answer.mp3")
		streak = 0
		Streak_label.text = "[outline_color=#1A1827][outline_size=2][color=#E4C77A]x" + str(streak) + "[/color]"
		var btncor: TextureButton = get("Answer%d" % correct_panel_index)
		btncor.texture_normal = load(CORRECT_TEXTURE_PATH)
		print("❌ Wrong")
		button_pressed.texture_normal = load(WRONG_TEXTURE_PATH)
		var current_wrong := int(current_question.get("wrong_count", 0))
		current_question["wrong_count"] = current_wrong + 1
		total_wrong_answers += 1
	await get_tree().create_timer(1.0).timeout	
	randomize()  # ensures different random question each run
	if atk_answers_2 >= 0 :
		atk_answers_2 -= 1
		if atk_answers_2 == 0 :
			show_x2_assist(atk_answers_2)
	current_question = get_random_question()
	display_question(current_question)

func update_remaining_questions(current: int, total: int) -> void:
	var label := $Label_remain_questions
	label.clear()  # remove previous content
	var active_color = "#a477ff"      # purple-teal highlight (ACTIVE)
	var passive_color = "#6f7a8a"     # soft desaturated grey-teal (PASSIVE)
	var remain_questions = total - current
	label.append_text("[b][color=" + active_color + "]" + str(remain_questions) + "[/color][/b]")
	#label.append_text("[color=" + passive_color + "] /[/color]")
	#label.append_text("[color=" + passive_color + "]" +  str(total) + "[/color]")

func _on_ad_finished_end() -> void:
	AdsManager.save_ads()
	_check_per_question_wrong_achievements()
	total_time = time_left
	var stats = build_mc_stats()
	GlobalMc.last_run_stats = stats 
	get_tree().change_scene_to_file("res://Scenes/MemoryClash/after_mc_quiz.tscn")


func _index_from_button(btn: TextureButton) -> int:
	var buttons = [Answer1, Answer2, Answer3, Answer4]
	for i in range(buttons.size()):
		if buttons[i] == btn:
			return i + 1
	return -1



func _on_answer_1_pressed() -> void:
	check_answer(Answer1)


func _on_answer_2_pressed() -> void:
	check_answer(Answer2)



func _on_answer_3_pressed() -> void:
	check_answer(Answer3)


func _on_answer_4_pressed() -> void:
	check_answer(Answer4)
	
	

# Timer Logic

func _process(delta: float) -> void:
	var slowtime = (streak * 0.05) * delta
	slowtime = clamp(slowtime, 0.0, delta * 0.90)
	time_left += delta - slowtime
	Label_time.text = "%0.1f" % max(time_left, 0.0)
	question_time += delta
	quickfire_timer += delta

	if def_cum_quick:
		def_cum_timer -= delta
		_set_timer_shadow(true)

		if def_cum_timer <= 0.0:
			def_cum_quick = false
			_set_timer_shadow(false)
	else:
		_set_timer_shadow(false)
	
func quickfire() -> bool:
	return quickfire_timer < 6.0

# Get Stats to Global
func build_mc_stats() -> GlobalMc.McStats:
	var stats := GlobalMc.McStats.new()

	stats.wrong_answers = total_wrong_answers
	stats.max_timer = total_time
	stats.less_2_every_questions = less_than_2_every_questions
	stats.less_3_every_questions = less_than_3_every_questions
	
	stats.longest_streak = max_streak
	
	average_time = total_time_answers/total_questions
	stats.average_time_per_answer = average_time
	stats.fastest_question = fastest_correct_answer
	var max_wrong_for_any_question := 0
	for q in run_questions_all:
		var wc := int(q.get("wrong_count", 0))
		if wc > max_wrong_for_any_question:
			max_wrong_for_any_question = wc
	stats.max_wrongs_in_1 = max_wrong_for_any_question
	return stats
func _check_per_question_wrong_achievements() -> void:
	var max_wrong_for_any_question := 0

	for q in run_questions_all:
		var wc := int(q.get("wrong_count", 0))
		if wc > max_wrong_for_any_question:
			max_wrong_for_any_question = wc
	print (max_wrong_for_any_question)
	# Now evaluate achievements:
	# "Never miss the same question more than 3 times"
	if max_wrong_for_any_question <= 5:
		print ('asdf')
		less_than_3_every_questions = true

		# "Never miss the same question more than 2 times"
	if max_wrong_for_any_question <= 3:
		less_than_2_every_questions = true





func _on_button_back_pressed() -> void:
	AdsManager.save_ads()
	SoundManager.play_sfx("res://Sounds/buttonclick.mp3")
	get_tree().change_scene_to_file("res://Scenes/MemoryClash/memory_clash_scene.tscn")


func _on_texture_button_assist_pressed() -> void:
	if GlobalMc.mc_atk_x2 :
		atk_answers_2 = 2
		show_x2_assist(2)
	if GlobalMc.mc_ctrl_repeat :
		activate_control_pool()
		
	if GlobalMc.mc_def_cumulative :
		def_cum_quick = true
		def_cum_timer = 15.0
		def_cum_counter = 1
	$TextureButton_Assist.disabled = true
	
	
func _apply_assist_icon_from_globals() -> void:
	if GlobalMc.mc_atk_x2:
		_apply_assist_icon("atk")
	elif GlobalMc.mc_def_cumulative:
		_apply_assist_icon("def")
	elif GlobalMc.mc_ctrl_repeat:
		_apply_assist_icon("ctrl")
	else:
		_apply_assist_icon("none")
func _apply_assist_icon(kind: String) -> void:
	match kind:
		"atk":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/Attack/atk_x2/atk_streak_x2_active.png")   # TODO fill
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/Attack/atk_x2/atk_streak_x2.png")   # TODO fill
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/Attack/atk_x2/atk_streak_x2_beveled.png")   # TODO fill
		"def":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/Defense/cummulative/def_cumulative_active.png")   # TODO fill
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/Defense/cummulative/def_cumulative.png") 
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/Defense/cummulative/def_cumulative_beveled.png") 
		"ctrl":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/Control/repeat/assist_repeat_3_active.png")
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/Control/repeat/assist_repeat_3.png")
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/Control/repeat/assist_repeat_3_beveled.png")

func show_x2_assist(count: int) -> void:
	match count:
		2:
			assist_x2_label.text = "[center][color=#FF6B6B]Ⅱ[/color][/center]"
		1:
			assist_x2_label.text = "[center][color=#FF6B6B]Ⅰ[/color][/center]"
		_:
			assist_x2_label.text = ""

	assist_x2_label.visible = count > 0

func _trigger_x2_pulse() -> void:
	var tw := get_tree().create_tween()
	tw.tween_property(Streak_label, "scale", Vector2(1.2, 1.2), 0.08)
	tw.tween_property(Streak_label, "scale", Vector2.ONE, 0.12)
func activate_control_pool() -> void:
	ctrl_active = true
	ctrl_questions_left = CTRL_DURATION
	ctrl_pool.clear()

	# Safety
	if run_questions.is_empty():
		ctrl_active = false
		return

	# Pick unique questions for the pool (up to CTRL_POOL_SIZE)
	var temp := run_questions.duplicate()
	temp.shuffle()

	var take: int = min(CTRL_POOL_SIZE, temp.size())
	for i in range(take):
		ctrl_pool.append(temp[i])

	# If for any reason we failed
	if ctrl_pool.is_empty():
		ctrl_active = false
func ctrl_remove_from_pool(q: Dictionary) -> void:
	if not ctrl_active:
		return
	for i in range(ctrl_pool.size() - 1, -1, -1):
		if ctrl_pool[i] == q:
			ctrl_pool.remove_at(i)
func _set_timer_shadow(enabled: bool) -> void:
	if enabled == _shadow_on:
		return

	_shadow_on = enabled
	timer_panel.add_theme_stylebox_override(
		"panel",
		_sb_shadow if enabled else _sb_base
	)
