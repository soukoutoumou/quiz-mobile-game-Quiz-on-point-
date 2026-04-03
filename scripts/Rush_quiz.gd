extends Control
var _tenth_displayed: int = -1
var time_speed: float = 1.0  # multiplier set from your phase (1..5)
var correct_answer_text: String  # make this a member variable at the top of the script
var correct_panel_index: int = -1
var total_time: float = 30.5   # total countdown seconds
var time_left: float = total_time
var low_time_music_started := false
## Assists ##
var next_3_easy : int = 0
var freeze_time : bool = false
var freeze_timer : float = 0.0
var answers_3_quicked : int = 0
@onready var freeze_symbol := $AspectRatioContainer/Panel/freeze_symbol
@onready var Control_symbol_label := $Panel_question/Label_ctrl_easy
@onready var atk_symbol := $Atk_symbol_texture

@onready var Label_time: Label = $AspectRatioContainer/Panel/Label_time
@onready var Answer1: TextureButton = $VBoxAnswers/Panel_answer1/Answer1
@onready var Answer2: TextureButton = $VBoxAnswers/Panel_answer2/Answer2
@onready var Answer3: TextureButton = $VBoxAnswers/Panel_answer3/Answer3
@onready var Answer4: TextureButton = $VBoxAnswers/Panel_answer4/Answer4
@onready var Score:   Label = $PanelContainer/Scorelabel

@onready var Streak_label : RichTextLabel = $Panel_streak/RichTextLabel
@onready var quickshot := $Label_shout


@onready var Statsoverlay_panel: TextureRect = $VBoxAnswers/Panel_answer1/OverlayPanel
@onready var Statsoverlay_panel2: TextureRect = $VBoxAnswers/Panel_answer2/OverlayPanel
@onready var Statsoverlay_panel3: TextureRect = $VBoxAnswers/Panel_answer3/OverlayPanel
@onready var Statsoverlay_panel4: TextureRect = $VBoxAnswers/Panel_answer4/OverlayPanel
const CORRECT_TEXTURE_PATH = "res://Ui/ThemeWarm/quiz_scene/answer_correct_v2.png"
const WRONG_TEXTURE_PATH   = "res://Ui/ThemeWarm/quiz_scene/answer_incorrect_v2.png"
var default_answer_texture: Texture2D = null

@onready var TimePanel: Panel = $AspectRatioContainer/Panel

const TIME_PHASE_START := Color("#2ECC71")
const TIME_PHASE_END   := Color("#E74C3C")



var _pulse_tween: Tween = null


@onready var answer_panels := [
	$VBoxAnswers/Panel_answer1,
	$VBoxAnswers/Panel_answer2,
	$VBoxAnswers/Panel_answer3,
	$VBoxAnswers/Panel_answer4,
]
var control_pace : int = 1
var quickfire_timer: float = 0


var max_timer_reached : float = 0
var max_extra_time_gain_in_one_question : int = 0

var recovered_10_to_30_flag_pre : bool  = false
var recovered_10_to_30_flag : bool = false

var recovered_5_to_30_flag_pre : bool = false
var recovered_5_to_30_flag : bool = false

var under_10_streak: int = 0
var under_5_streak: int = 0

var finished_questions_5_under10 : bool = false
var finished_questions_5_under5 : bool = false
var quicks : int = 0
var questions_number : int = 0
var streak: int = 0
var score: int = 0
var correct_answers: int = 0
var normal_time : float = 0
var best_streak : int = 0

## Initiation
func _ready() :
	SoundManager.stop_music()
	### assists  ##
	next_3_easy = 0
	freeze_time = false
	freeze_timer = 0.0
	answers_3_quicked = 0
	### Stats #########
	max_timer_reached = 0
	max_extra_time_gain_in_one_question = 0
	recovered_10_to_30_flag_pre = false
	recovered_5_to_30_flag_pre = false
	under_10_streak = 0
	under_5_streak = 0
	#########################
	quicks = 0
	best_streak = 0
	normal_time = 0
	quickfire_timer = 0
#	time_left = total_time
	control_pace = 0
	questions_number = 0
	streak = 0
	score = 0
	Score.text = str(score)
	correct_answers = 0
	quickshot.visible = true
	Control_symbol_label.visible = false
	_apply_assist_icon_from_globals()
	Streak_label.text = "[outline_color=#2E2E2E][outline_size=2][color=#FFE1B0]x" + str(streak) + "[/color]"
	if Answer1:
		default_answer_texture = Answer1.texture_normal
	start_rush()


func start_rush() -> void:
	if AdsManager.maybe_show_interstitial():
		AdsManager.interstitial_finished.connect(_on_ad_finished_start, CONNECT_ONE_SHOT)
	else:
		_on_ad_finished_start()


func _on_ad_finished_start() -> void:
	randomize()
	var q = get_random_question()
	display_question(q)
	time_left = total_time


## Load Question

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


func get_random_question() -> Dictionary:
	var question_paths := {
		"Easy":     "res://Questions/Greek/questions_easy.json",
		"Medium":   "res://Questions/Greek/questions_medium.json",
		"Hard":     "res://Questions/Greek/questions_hard.json",
		"Ultimate": "res://Questions/Greek/questions_ultimate.json"
	}
	var weights := {
			"Easy": 0.4,
			"Medium": 0.3,
			"Hard": 0.15,
			"Ultimate": 0.1
		}
	# Weighted ratios for each difficulty
	if next_3_easy > 1 :
		weights = {
			"Easy": 1,
			"Medium": 0,
			"Hard": 0,
			"Ultimate": 0
		}
		next_3_easy -= 1
		
	# Step 1: pick difficulty based on weights
	var chosen_diff = weighted_pick(weights)
	
	# Step 2: load questions
	var questions = load_questions(question_paths[chosen_diff])
	if questions.is_empty():
		push_error("❌ No questions found for difficulty: " + chosen_diff)
		return {}
	# Step 3: pick random question from that difficulty
	var random_q = questions[randi() % questions.size()]
	random_q["difficulty"] = chosen_diff
	return random_q


# ------------------------------------------
# Weighted random helper
# ------------------------------------------
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

## Display Questions-Answers

func display_question(q: Dictionary) -> void:
	Statsoverlay_panel.visible = true
	Statsoverlay_panel2.visible = true
	Statsoverlay_panel3.visible = true
	Statsoverlay_panel4.visible = true
	for btn in [Answer1, Answer2, Answer3, Answer4]:
		if btn:
			btn.texture_normal = null
			btn.texture_pressed = null
			btn.texture_hover = null
			btn.disabled = false
	if q.is_empty():
		push_error("❌ display_question: got empty question dictionary.")
		return
	quickfire_timer = 0
	questions_number += 1
	quickshot.visible = false
	# --- Question text ---
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

	if next_3_easy >=  1 :
		Control_symbol_label.visible = true
		Control_symbol_label.text = "Easy:" + str(next_3_easy)
		if next_3_easy == 1 :
			next_3_easy -= 1
	else : 
		Control_symbol_label.visible = false
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
		
		# ✅ Track which panel holds the correct answer
		if text == correct_answer_text:
			correct_panel_index = i + 1
	if time_left < 10 :
		under_10_streak += 1
		print (under_10_streak)
		if under_10_streak >= 5 :
			finished_questions_5_under10 = true
	if time_left < 5 :
		under_5_streak += 1
		if under_5_streak >= 5 :
			finished_questions_5_under5 = true


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
	color: Color = Color("#FFE1B0"),
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
	color: Color = Color("#E8E8E8"),
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
	if font != null:
		ls.font = font
	label.label_settings = ls

## Check Answers

func check_answer(button_pressed: TextureButton) -> void:
	AdsManager.register_question_answered()
	if time_left < 10 :
		recovered_10_to_30_flag_pre = true
	if time_left < 5 :
		recovered_5_to_30_flag_pre = true
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
	if is_correct:
		SoundManager.play_sfx("res://Sounds/correct_answer.mp3")
		if time_left < 10 :
			control_pace -= 1
			if control_pace < 0 :
				control_pace = 0
		print("✅ Correct")
		button_pressed.texture_normal = load(CORRECT_TEXTURE_PATH)
		streak += 1
		Streak_label.text = "[outline_color=#2E2E2E][outline_size=2][color=#FFE1B0]x" + str(streak) + "[/color]"
		if streak > best_streak :
			best_streak = streak
		correct_answers += 1
		var extra_time2 = streak
		if quickfire():
			quickshot.visible = true
			quicks += 1
			extra_time2 *=2
		if max_extra_time_gain_in_one_question < extra_time2 :
			max_extra_time_gain_in_one_question = extra_time2
		time_left += extra_time2
		if recovered_10_to_30_flag_pre == true and time_left > 30 :
			recovered_10_to_30_flag = true
		if recovered_5_to_30_flag_pre == true and time_left > 30 :
			recovered_5_to_30_flag = true
		if max_timer_reached < time_left :
			max_timer_reached = time_left
		show_extra_time(extra_time2)
		score += extra_time2
		Score.text = str(score)
	else:
		SoundManager.play_sfx("res://Sounds/wrong_answer.mp3")
		if quickfire():
			pass
		streak = 0
		Streak_label.text = "[outline_color=#2E2E2E][outline_size=2][color=#FFE1B0]x" + str(streak) + "[/color]"
		print("❌ Wrong")
		button_pressed.texture_normal = load(WRONG_TEXTURE_PATH)
		var btncor: TextureButton = get("Answer%d" % correct_panel_index)
		btncor.texture_normal = load(CORRECT_TEXTURE_PATH)
	if time_left > 5 :
		under_5_streak = 0
	if time_left > 10 :
		under_10_streak = 0
	control_pace += 1
	await get_tree().create_timer(0.5).timeout	
	randomize()  # ensures different random question each run
	var q = get_random_question()
	display_question(q)


func show_extra_time(extra: int) -> void:
	var lbl: RichTextLabel = $Label_extra_time
	var base_size: int = 34
	var capped_extra: int = min(extra, 16)
	var target_size: int = base_size + 2*capped_extra
	lbl.bbcode_enabled = true
	lbl.set("theme_override_font_sizes/normal_font_size", target_size)
	lbl.text = "[color=green]+%ds[/color]" % extra
	lbl.visible = true
	await get_tree().create_timer(0.5).timeout
	lbl.visible = false
	lbl.set("theme_override_font_sizes/normal_font_size", base_size)


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


func _process(delta: float) -> void:
	if time_left <= 0.0:
		time_left = 0.0
		Label_time.text = "0.0"
		Label_time.add_theme_color_override("font_color", Color.RED)
		_on_time_over()
		return
	if time_left <= 10.0 and not low_time_music_started:
		low_time_music_started = true
		SoundManager.play_music("res://Sounds/clock-ticking-down-376897.mp3", true)
	elif time_left > 10.0 and low_time_music_started :
		low_time_music_started = false
		SoundManager.stop_music()
	time_speed = 1 + control_pace*4/100
	if not freeze_time :
		time_left -= delta * time_speed
	else : 
		freeze_timer -= delta
		if freeze_timer < 0.1 :
			freeze_time = false
			freeze_symbol.visible = false
	normal_time += delta * time_speed
	quickfire_timer += delta
	var tenths_int := int(floor(time_left * 10.0))
	if tenths_int != _tenth_displayed:
		_tenth_displayed = tenths_int
		Label_time.text = "%0.1f" % max(time_left, 0.0)
		if time_left > 10.0:
			Label_time.add_theme_color_override("font_color", Color.GREEN)
		else:
			Label_time.add_theme_color_override("font_color", Color.RED)


func _on_time_over() -> void:
	if AdsManager.maybe_show_interstitial():
		AdsManager.interstitial_finished.connect(_on_ad_finished_end, CONNECT_ONE_SHOT)
	else:
		_on_ad_finished_end()


func _on_ad_finished_end() -> void:
	AdsManager.save_ads()
	SoundManager.stop_music()
	var stats = build_rush_stats()
	GlobalRush.last_run_stats = stats
	get_tree().change_scene_to_file("res://Scenes/Rush/after_rush_quiz.tscn")

## Sme Ui Effects

func apply_time_phase(level: int) -> void:
	level = clamp(level, 1, 20)

	# Stop any previous pulse
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
		
	# Duplicate stylebox
	var sb := TimePanel.get_theme_stylebox("panel")
	if sb == null:
		return
	var flat := sb.duplicate() as StyleBoxFlat
	if flat == null:
		return
		
	# --- COLOR: smoothly interpolate across levels 1..20 ---
	var t := float(level - 1) / 19.0  # 0..1
	var base_color: Color = TIME_PHASE_START.lerp(TIME_PHASE_END, t)

	# Steady (full alpha)
	var steady := base_color
	steady.a = 1.0
	flat.shadow_color = steady
	TimePanel.add_theme_stylebox_override("panel", flat)

	# --- PULSE: all levels 1..20 ---
	# Speed: slow at lvl1 -> fast at lvl20
	var pulse_speed: float = lerp(1.6, 0.25, t)

	# Dim alpha: subtle at lvl1 -> stronger at lvl20
	var dim_alpha: float   = lerp(0.85, 0.10, t)

	var dim := base_color
	dim.a = dim_alpha

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(flat, "shadow_color", dim, pulse_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(flat, "shadow_color", steady, pulse_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func quickfire() -> bool:
	var quickfire_limit = 6.0
	if answers_3_quicked > 0 :
		quickfire_limit = 1000
		answers_3_quicked -= 1
		if answers_3_quicked < 1:
			atk_symbol.visible = false
	return quickfire_timer < quickfire_limit

## Build Stats

func build_rush_stats() -> GlobalRush.RushStats:
	var stats := GlobalRush.RushStats.new()
	stats.final_score = score
	stats.max_timer = max_timer_reached ## Done
	stats.max_extra_time_single = max_extra_time_gain_in_one_question
	stats.dropped_below_10_and_back_to_30 = recovered_10_to_30_flag
	stats.dropped_below_5_and_back_to_30 = recovered_5_to_30_flag
	
	stats.questions5_under_10 = finished_questions_5_under10
	stats.questions5_under_5 = finished_questions_5_under5
	
	stats.total_questions = questions_number
	stats.total_correct = correct_answers
	stats.longest_streak = best_streak
	stats.total_time_passed = normal_time
	stats.quick_times = quicks
	return stats


## Assists Ui + Activation

func _on_texture_button_pressed() -> void:
	if GlobalRush.rush_ctrl_easy :
		next_3_easy = 4
	if GlobalRush.rush_def_freeze :
		freeze_time = true
		freeze_timer = 10.0
		freeze_symbol.visible = true
	if GlobalRush.rush_atk_quick :
		answers_3_quicked = 4
		atk_symbol.visible = true
	$TextureButton_Assist.disabled = true
	
func _apply_assist_icon_from_globals() -> void:
	if GlobalRush.rush_atk_quick:
		_apply_assist_icon("atk")
	elif GlobalRush.rush_def_freeze:
		_apply_assist_icon("def")
	elif GlobalRush.rush_ctrl_easy:
		_apply_assist_icon("ctrl")
	else:
		_apply_assist_icon("none")
func _apply_assist_icon(kind: String) -> void:
	match kind:
		"atk":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/Attack/atk_bolt_active.png")   # TODO fill
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/Attack/atk_bolt.png")   # TODO fill
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/Attack/atk_bolt_beveled.png")   # TODO fill
		"def":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/Defense/freeze/assist_freeze_active.png")   # TODO fill
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/Defense/freeze/assist_freeze.png") 
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/Defense/freeze/assist_freeze_beveled.png") 
		"ctrl":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/Control/control_question_mark_active.png")
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/Control/control_question_mark.png")
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/Control/control_question_mark_beveled.png")
