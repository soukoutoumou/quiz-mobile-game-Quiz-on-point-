extends Control

const COL_FEE    := "#E53935"   # red
const COL_ACCENT := "#2EC4B6"   # teal
const COL_TEXT   := "#1E3A5F"   # dark blue
const COL_GOLD := "#F2C94C"  # gold-ish
const COL_KEY := "#2EC4B6"

var low_time_music_started := false
var def_time_left = 0.0
@onready var Streak_label : RichTextLabel = $Panel_streak/RichTextLabel

const FEE_START_quiz := 1
var answered_count_quiz := 1

var _tenth_displayed: int = -1
var correct_answer_text: String  # make this a member variable at the top of the script
var correct_panel_index: int = -1
var total_time: float = 15   # total countdown seconds
var time_left: float = total_time

var timer_stop: bool = false
var bettimer_stop: bool = false
@onready var Label_time: Label = $AspectRatioContainer/Panel/Label_time
@onready var Answer1: TextureButton = $VBoxAnswers/Panel_answer1/Answer1
@onready var Answer2: TextureButton = $VBoxAnswers/Panel_answer2/Answer2
@onready var Answer3: TextureButton = $VBoxAnswers/Panel_answer3/Answer3
@onready var Answer4: TextureButton = $VBoxAnswers/Panel_answer4/Answer4
var bet_timer: SceneTreeTimer
signal bet_phase_done
var is_time_over: bool = false
var bet_resolved: bool = false
var bet_time_left := GlobalBetarena.bet_max_time
@onready var Statsoverlay_panel: TextureRect = $VBoxAnswers/Panel_answer1/OverlayPanel
@onready var Statsoverlay_panel2: TextureRect = $VBoxAnswers/Panel_answer2/OverlayPanel
@onready var Statsoverlay_panel3: TextureRect = $VBoxAnswers/Panel_answer3/OverlayPanel
@onready var Statsoverlay_panel4: TextureRect = $VBoxAnswers/Panel_answer4/OverlayPanel
const CORRECT_TEXTURE_PATH = "res://Ui/ThemeWarm/quiz_scene/answer_correct_v2.png"
const WRONG_TEXTURE_PATH   = "res://Ui/ThemeWarm/quiz_scene/answer_incorrect_v2.png"
const NETRUAL_TEXTURE_PATH   = "res://Ui/ThemeWarm/quiz_scene/answer_wait_v2.png"
var default_answer_texture: Texture2D = null

@onready var TimePanel: Panel = $AspectRatioContainer/Panel
@onready var Score:   Label = $PanelContainer/Scorelabel

@onready var answer_panels := [
	$VBoxAnswers/Panel_answer1,
	$VBoxAnswers/Panel_answer2,
	$VBoxAnswers/Panel_answer3,
	$VBoxAnswers/Panel_answer4,
]

var quickfire_timer: float = 0.0 #
var quickfire_accurate : float = 0.0 #
var total_bet : int = 0 #
var bet : int = 0 #
var quicks : int = 0 #
var questions : int = 0 #
var streak: int = 0 #
var score: int = 0 #
var correct_answers: int = 0 #
var normal_time : float = 0 #
var best_streak : int = 0 #
var best_single_score : int = 0 #
var bet_over_3 : int = 0 #
var biggest_bet : int = 0 #
var biggest_win : float = 0.0 #

## Initiation

func _ready() :
	SoundManager.stop_music()
	GlobalBetarena.global_fee = 1
	GlobalBetarena.bet_coins = 30
	$BetCoins.bbcode_enabled = true
	$BetCoins.text = "[color=%s]Bet Coins[/color]\n[color=%s]%d[/color]" \
		% [COL_ACCENT,  COL_GOLD, int(GlobalBetarena.bet_coins)]
	for i in range(1, 5):
		var btn_path := "Panel_answer%d/Answer%d" % [i, i]
		var btn := get_node_or_null(btn_path)
		if btn:
			btn.disabled = true
	$BetPopup.popup_closed.connect(_on_popup_closed)
	### Stats #########
	GlobalBetarena.def_extra_profit = 0
	biggest_win = 0
	biggest_bet = 0
	is_time_over = false
	timer_stop = false
	bettimer_stop = false
	#########################
	GlobalBetarena.profit = 0.0
	GlobalBetarena.streak = 0
	bet_over_3 = 0
	total_bet = 0
	best_single_score = 0
	bet = 0
	quicks = 0
	best_streak = 0
	normal_time = 0
	quickfire_timer = 0
	questions = 0
	streak = 0
	score = 0
	correct_answers = 0
	Score.text = str(score)
	_apply_assist_icon_from_globals()
	Streak_label.text = str(streak)
	if Answer1:
		default_answer_texture = Answer1.texture_normal
	start_betarena()
	
func start_betarena() -> void:
	if AdsManager.maybe_show_interstitial():
		AdsManager.interstitial_finished.connect(_on_ad_finished_start, CONNECT_ONE_SHOT)
	else:
		_on_ad_finished_start()


func _on_ad_finished_start() -> void:
	randomize()
	var q = get_random_question()
	display_question(q)

# Load Questions Handlers
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

	# Weighted ratios for each difficulty
	var weights := {
		"Easy":     0.45,
		"Medium":   0.4,
		"Hard":     0.3,
		"Ultimate": 0.2
	}
	# Step 1: pick difficulty based on weights
	var chosen_diff = weighted_pick(weights)
	# Step 2: load questions
	var questions = load_questions(question_paths[chosen_diff])
	if questions.is_empty():
		push_error("❌ No questions found for difficulty: " + chosen_diff)
		return {}
	if GlobalBetarena.def_active:
		if chosen_diff == "Easy":
			if randf() < 0.5:
				chosen_diff = "Medium"
			else:
				chosen_diff = "Hard"
	# Step 3: pick random question from that difficulty
	var random_q = questions[randi() % questions.size()]
	random_q["difficulty"] = chosen_diff
	var diff_idx := 0
	match chosen_diff:
		"Easy":
			diff_idx = 0
		"Medium":
			diff_idx = 1
		"Hard":
			diff_idx = 2
		"Ultimate":
			diff_idx = 3
	if GlobalBetarena.ctrl_active:
		diff_idx = 3 - diff_idx
	GlobalBetarena.current_difficulty = diff_idx
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

## Display Questions
func display_question(q: Dictionary) -> void:
	if GlobalBetarena.bet_coins <= GlobalBetarena.global_fee :
		print ("end")
		if AdsManager.maybe_show_interstitial():
			AdsManager.interstitial_finished.connect(_on_ad_finished_end, CONNECT_ONE_SHOT)
		else:
			_on_ad_finished_end()
		return
	if GlobalBetarena.ctrl_pending:
		GlobalBetarena.ctrl_pending = false
		GlobalBetarena.ctrl_active = true
	if GlobalBetarena.ctrl_active:
		GlobalBetarena.ctrl_left_q -= 1

	Statsoverlay_panel.visible = true
	Statsoverlay_panel2.visible = true
	Statsoverlay_panel3.visible = true
	Statsoverlay_panel4.visible = true
	for btn in [Answer1, Answer2, Answer3, Answer4]:
		if btn:
			btn.texture_normal = null
			btn.texture_pressed = null
			btn.texture_hover = null
	timer_stop = false
	if q.is_empty():
		push_error("❌ display_question: got empty question dictionary.")
		return

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
	questions += 1
	time_left = total_time
	timer_stop = true
	await get_tree().create_timer(0.1).timeout
	for btn in [Answer1, Answer2, Answer3, Answer4]:
		if btn:
			btn.disabled = false
	timer_stop = false
	$Label_shout.visible = false
	$BetCoins_profit.visible = false
	quickfire_timer = 0


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
	color: Color = Color("#F0D9A6"),
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
	color: Color = Color("#E6F3FF"),
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
	quickfire_accurate = quickfire_timer
	timer_stop = true
	bettimer_stop = true
	button_pressed.texture_normal = load(NETRUAL_TEXTURE_PATH)
	if is_correct:
		GlobalBetarena.if_correct = true
		print ("ITS CORRECT")
	start_bet_phase()  ## Starts Bet Phase
	await bet_phase_done
	await get_tree().process_frame 
	if is_correct:
		SoundManager.play_sfx("res://Sounds/correct_answer.mp3")
		if bet > 10 :
			bet_over_3 += 1
		print("✅ Correct")
		button_pressed.texture_normal = load(CORRECT_TEXTURE_PATH)
		GlobalBetarena.streak += 1
		streak += 1
		Streak_label.text = str(streak)
		if streak > best_streak :
			best_streak = streak
		correct_answers += 1
		var add_score = bet
		if add_score > best_single_score :
			best_single_score = add_score
		score += add_score
		Score.text = str(score)
		if quickfire():
			print ("quick")
			$Label_shout.bbcode_enabled = true
			$Label_shout.text = "[color=#A46CFF]QUICK![/color]"
			$Label_shout.visible = true
			quicks += 1
	else:
		SoundManager.play_sfx("res://Sounds/wrong_answer.mp3")
		GlobalBetarena.streak = 0
		streak = 0
		Streak_label.text = str(streak)
		print("❌ Wrong")
		button_pressed.texture_normal = load(WRONG_TEXTURE_PATH)
		var btncor: TextureButton = get("Answer%d" % correct_panel_index)
		btncor.texture_normal = load(CORRECT_TEXTURE_PATH)
	if  GlobalBetarena.atk_active :
		GlobalBetarena.atk_left_correct -= 1
		if GlobalBetarena.atk_left_correct <= 0 :
			GlobalBetarena.atk_active = false
	if GlobalBetarena.ctrl_left_q <= 0:
		GlobalBetarena.ctrl_active = false
	update_betcoins_and_result_labels()
	advance_fee_on_question(quickfire(),is_correct)
	biggest_win = max(biggest_win, GlobalBetarena.profit)
	await get_tree().create_timer(2.0).timeout
	_on_ad_finished_start()


## Bet Phase Ends  Helper

func _on_popup_closed(bet_value):
	if bet_timer and bet_timer.timeout.is_connected(_on_bet_timeout):
		bet_timer.timeout.disconnect(_on_bet_timeout)
		bet_timer = null
	bet_resolved = true
	bet = bet_value
	bettimer_stop = false
	biggest_bet = max(biggest_bet, bet)
	print ("bet", str(bet))
	total_bet += bet_value
	emit_signal("bet_phase_done")

func _on_bet_timeout() -> void:
	if bet_resolved:
		return 
	$BetPopup.close_popup()


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


## Timer Logic
func _process(delta: float) -> void:
	if time_left <= 0.0:
		time_left = 0.0
		Label_time.text = "0.0"
		Label_time.add_theme_color_override("font_color", Color.RED)
		_on_time_over()
		return

	if not timer_stop  :
		time_left -= delta 
		quickfire_timer += delta
		if GlobalBetarena.def_active :
			def_time_left -= delta
			if def_time_left <= 0 :
				GlobalBetarena.def_active = false
				GlobalBetarena.def_extra_profit = streak
		if time_left <= 5.0 and not low_time_music_started:
			low_time_music_started = true
			SoundManager.play_music("res://Sounds/clock-ticking-down-376897.mp3", true)
	var tenths_int := int(floor(time_left * 10.0))
	if tenths_int != _tenth_displayed and not timer_stop:
		_tenth_displayed = tenths_int
		Label_time.text = "%0.1f" % max(time_left, 0.0)
		if time_left > 5.0:
			Label_time.add_theme_color_override("font_color", Color("#E6F3FF"))
		else:
			Label_time.add_theme_color_override("font_color", Color("#FF4A4A"))
	if timer_stop and  bettimer_stop :
		bet_time_left -= delta
	if timer_stop :
		Label_time.text = str(clamp(round(bet_time_left), 0, 99))
		Label_time.add_theme_color_override("font_color", Color("#4AA3FF"))

func _on_time_over() -> void:
	if is_time_over == true :
		return
	low_time_music_started = false
	SoundManager.stop_music()
	SoundManager.play_sfx("res://Sounds/timer_ended.mp3")
	GlobalBetarena.streak = 0
	if GlobalBetarena.ctrl_left_q <= 0:
		GlobalBetarena.ctrl_active = false
	streak = 0
	Streak_label.text = str(streak)
	is_time_over = true
	GlobalBetarena.bet_coins -= GlobalBetarena.global_fee
	$BetCoins.text = "[color=%s]Bet Coins[/color]\n[color=%s]%d[/color]" \
		% [COL_ACCENT,  COL_GOLD, int(GlobalBetarena.bet_coins)]
	advance_fee_on_question(false, false)
	var btncor: TextureButton = get("Answer%d" % correct_panel_index)
	btncor.texture_normal = load(CORRECT_TEXTURE_PATH)
	for i in range(1, 5):
		var btn_path := "Panel_answer%d/Answer%d" % [i, i]
		var btn := get_node_or_null(btn_path)
		if btn:
			btn.disabled = true
	await get_tree().create_timer(1.5).timeout

	is_time_over = false
	_on_ad_finished_start()



func _on_ad_finished_end() -> void:
	AdsManager.save_ads()
	SoundManager.stop_music()
	var stats = build_betarena_stats()
	GlobalBetarena.last_run_stats = stats
	get_tree().change_scene_to_file("res://Scenes/BetArena/bet_arena_after_quiz.tscn")


## Build Stats to Global
func build_betarena_stats() -> GlobalBetarena.BetArenaStats:
	var stats := GlobalBetarena.BetArenaStats.new()
	stats.total_points =  score                   # (your final score)
	stats.max_points_single =   best_single_score             # (most points earned in one question)
	stats.total_quick_answers =   quicks           # (how many quick/bet-quick answers)
	stats.total_bet_spent =  total_bet                # (sum of all bet coins spent)
	stats.total_questions =  questions                # (correct + wrong)
	stats.total_correct =   correct_answers                 # (correct only)
	stats.longest_streak =  best_streak               # (highest streak reached)
	stats.correct_over_3 = bet_over_3
	stats.max_fee = GlobalBetarena.global_fee
	stats.best_single_bet = biggest_bet
	stats.best_win_profit = biggest_win
	return stats


## Start Bet Phase Helper
func start_bet_phase() -> void:
	# cancel old timer if exists
	if bet_timer and bet_timer.timeout.is_connected(_on_bet_timeout):
		bet_timer.timeout.disconnect(_on_bet_timeout)
		bet_timer = null
	low_time_music_started = false
	SoundManager.stop_music()
	bet_resolved = false
	bet_time_left = GlobalBetarena.bet_max_time
	bet_timer = get_tree().create_timer(bet_time_left)
	bet_timer.timeout.connect(_on_bet_timeout, CONNECT_ONE_SHOT)
	GlobalBetarena.last_answer_was_quick = quickfire()
	$BetPopup.show_bet_popup()
func quickfire() -> bool:
	return quickfire_accurate < 6.0

func update_betcoins_and_result_labels() -> void:
	# 1) Always show current bet coins
	$BetCoins.bbcode_enabled = true
	$BetCoins.text = "[color=%s]Bet Coins[/color]\n[color=%s]%d[/color]" \
		% [COL_ACCENT,  COL_GOLD, int(GlobalBetarena.bet_coins)]

	# 2) Show last result (profit or loss) excluding fee (you handle fee elsewhere)
	$BetCoins_profit.bbcode_enabled = true

	# GlobalBetarena.profit == 0 means wrong (your rule)
	if float(GlobalBetarena.profit) == 0.0:
		$BetCoins_profit.text = "[color=%s]Lost:[/color] [color=%s]-%d[/color]" \
			% [COL_TEXT, COL_FEE, int(bet)]
	else:
		var pct := int(round(float(GlobalBetarena.profit_actual_percentage_quiz) * 100.0))
		$BetCoins_profit.text = \
			"[color=%s]Won profit![/color] [color=%s]Total Payout:[/color] [color=%s]+%d%%[/color]" \
			% [COL_KEY, COL_ACCENT, COL_GOLD, pct]
	$BetCoins_profit.visible = true
	

func advance_fee_on_question(is_quick: bool, if_correct: bool) -> void:
	# Quick + Correct answers do not advance fee progression
	if is_quick and if_correct:
		return
	answered_count_quiz += 1
	# Increase fee every 5 answered questions
	var new_fee := FEE_START_quiz + int(floor(answered_count_quiz / 3))
	GlobalBetarena.global_fee = max(GlobalBetarena.global_fee, new_fee)

## Assists Ui - Activation Helpers
func _on_texture_button_assist_pressed() -> void:
	if GlobalBetarena.ba_atk_double:
		GlobalBetarena.atk_active = true
		GlobalBetarena.atk_left_correct = 3
	elif GlobalBetarena.ba_def_profit: 
		GlobalBetarena.def_active = true
		def_time_left = 30.0
	elif GlobalBetarena.ba_ctrl_reverse:
		GlobalBetarena.ctrl_pending = true
		GlobalBetarena.ctrl_left_q = 5
	$TextureButton_Assist.disabled = true


func _apply_assist_icon_from_globals() -> void:
	if GlobalBetarena.ba_atk_double:
		_apply_assist_icon("atk")
	elif GlobalBetarena.ba_def_profit:
		_apply_assist_icon("def")
	elif GlobalBetarena.ba_ctrl_reverse:
		_apply_assist_icon("ctrl")
	else:
		_apply_assist_icon("none")


func _apply_assist_icon(kind: String) -> void:
	match kind:
		"atk":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/BetArena/Atk/assist_atk_active.png")   # TODO fill
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/BetArena/Atk/assist_atk.png")   # TODO fill
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/BetArena/Atk/assist_atk_beveled.png")   # TODO fill
		"def":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/BetArena/Def/assist_def_active.png")   # TODO fill
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/BetArena/Def/assist_def.png") 
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/BetArena/Def/assist_def_beveled.png") 
		"ctrl":
			$TextureButton_Assist.texture_normal = load("res://Ui/Assists/BetArena/Ctrl/assist_ctrl_active.png")
			$TextureButton_Assist.texture_pressed = load("res://Ui/Assists/BetArena/Ctrl/assist_ctrl.png")
			$TextureButton_Assist.texture_disabled = load("res://Ui/Assists/BetArena/Ctrl/assist_ctrl_beveled.png")
