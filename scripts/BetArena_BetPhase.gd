extends Control

@onready var line  : ColorRect = $Line
@onready var panel : Control   = $Panel
@onready var line2 : ColorRect = $Line2   # <- second line

var warning_tween: Tween

### Variables profits 
const RANGE_EASY     := Vector2(0.20, 0.35)
const RANGE_MEDIUM   := Vector2(0.30, 0.50)
const RANGE_HARD     := Vector2(0.40, 0.80)
const RANGE_ULTIMATE := Vector2(0.80, 1.30)
# Start state (neutral)
var m_bs: float = 0.0      # bank-based modifier  [-0.30 .. +0.30]
var m_lb: float = 0.0      # last-bet modifier    [-0.10 .. +0.10]
var m_depth: float = 0.0   # run-depth modifier   [-0.30 .. 0.00]
var m_safety: float = 0.0  # emergency boost      [0.00 or +0.30]

const START_BANK := 30.0

# last bet starts at 15 so r_lb = 15/30 = 0.5 (neutral)
var last_bet: float = 15.0

# fee system
var answered_count: int = 0


var net3 := [0.0, 0.0, 0.0]
var net3_i := 0
var profit_actual_percentage := 0.0
var net_change := 0.0
const COL_FEE    := "#E53935"   # red
const COL_ACCENT := "#2EC4B6"   # teal
const COL_TEXT   := "#1E3A5F"   # dark blue
const COL_KEY := "#2EC4B6"
const COL_GOLD := "#F2C94C" 
@onready var label_fee : RichTextLabel = $Panel/Label_fee

@onready var panel_bet_show : Label = $Panel/Panel_display/Label
@onready var texture1 : TextureRect = $Panel/Panel/OverlayPanel
@onready var texture5 : TextureRect = $Panel/Panel2/OverlayPanel
@onready var texture10 : TextureRect = $Panel/Panel3/OverlayPanel
@onready var textureclear : TextureRect = $Panel/Panel4/OverlayPanel
@onready var textureconfirm : TextureRect = $Panel/Panel5/OverlayPanel

var is_minimized: bool = false

@onready var label_betcoins : RichTextLabel = $Panel/Label
@onready var label_toomany : RichTextLabel = $Label_toomany

@onready var button1 : Button = $Panel/Panel/Button
@onready var button5 : Button = $Panel/Panel2/Button5
@onready var button10 : Button = $Panel/Panel3/Button10
@onready var buttonclear : Button = $Panel/Panel4/Buttonclear
@onready var buttonConfirm : Button = $Panel/Panel5/ButtonConfirm

signal popup_closed(bet_value)
var current_bet: int = 1

func _ready() -> void:
	button1.pressed.connect(_on_button_pressed.bind(button1))
	button5.pressed.connect(_on_button_pressed.bind(button5))
	button10.pressed.connect(_on_button_pressed.bind(button10))
	buttonclear.pressed.connect(_on_button_pressed.bind(buttonclear))
	buttonConfirm.pressed.connect(_on_button_pressed.bind(buttonConfirm))
func show_bet_popup() -> void:
	## Calculate Mood - Initiation
	visible = true
	m_bs = house_modifier_from_bet_size(GlobalBetarena.bet_coins)
	var r_lb = calc_r_lb(last_bet, GlobalBetarena.bet_coins) 
	m_lb = house_modifier_from_last_bet(r_lb)
	m_depth = house_modifier_from_depth(GlobalBetarena.global_fee)
	m_safety = house_modifier_from_safety()
	set_quick_result()
	update_possible_profit_label()
	print (m_bs, "m_bs")
	print (m_lb, "m_lb")
	print (m_depth, "m_depth")
	# reset bet for this round if you want
	current_bet = 0
	GlobalBetarena.bet_coins -= GlobalBetarena.global_fee

	line.size.x = 0
	line2.size.x = 0
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0

	label_betcoins.modulate.a = 1.0
	label_betcoins.text = "[color=#E6F3FF]Place your [/color][color=#F0D9A6]%d[/color][color=#E6F3FF] Bet Coins![/color]" \
		% GlobalBetarena.bet_coins
	panel_bet_show.text = str(current_bet)
	
	## Some Graphics opening of Bet Phase 
	var tween = get_tree().create_tween()
	tween.tween_property(line, "size:x", 276.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func ():
		var t2 = get_tree().create_tween()
		t2.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property(panel, "modulate:a", 1.0, 0.20)
		t2.tween_callback(func ():
			var t3 = get_tree().create_tween()
			t3.tween_property(line2, "size:x", 1300.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t3.tween_callback(func ():
				show_action_buttons()
			)
		)
	)
	

func show_action_buttons() -> void:
	var delay := 0.0
	for child in $Panel.get_children():
		if child is Control:
			# ATK assist visibility gate
			if child.name == "Atk_assist_rect" and not GlobalBetarena.atk_active:
				child.visible = false
				continue
			if child.name == "Ctrl_assist_rect2" and not GlobalBetarena.ctrl_active:
				child.visible = false
				continue
			child.visible = true
			child.modulate.a = 0.0
			var t := get_tree().create_tween()
			t.tween_property(child, "modulate:a", 1.0, 0.2).set_delay(delay)
			delay += 0.1

		
		

func close_popup():
	emit_signal("popup_closed", current_bet)
	last_bet = current_bet
	if GlobalBetarena.if_correct :
		net_change = profit_actual_percentage * current_bet - GlobalBetarena.global_fee
		GlobalBetarena.profit = profit_actual_percentage * current_bet
		GlobalBetarena.bet_coins += GlobalBetarena.profit + current_bet
	else :
		net_change = - current_bet - GlobalBetarena.global_fee
		GlobalBetarena.profit = 0
	GlobalBetarena.if_correct = false
	push_net3(net_change) 
	if is_minimized :
		toggle_minimize()
	visible = false
	for child in $Panel.get_children():
		if child is Control :
			child.visible = false
		

## Betting 
func _on_button_pressed(button: BaseButton) -> void:
	# Disable during animation
	button.disabled = true

	if button == button1:
		if  GlobalBetarena.bet_coins >= 1 :
			current_bet += 1
			GlobalBetarena.bet_coins -= 1
			label_betcoins.text = "[color=#E6F3FF]Place your [/color][color=#F0D9A6]%d[/color][color=#E6F3FF] Bet Coins![/color]" \
			% GlobalBetarena.bet_coins
			label_toomany.visible = false
		else : 
			show_toomany_warning()
		await get_tree().create_timer(0.05).timeout
		texture1.visible = true

	elif button == button5:
		if  GlobalBetarena.bet_coins >= 5 :
			current_bet += 5
			GlobalBetarena.bet_coins -= 5
			label_betcoins.text = "[color=#E6F3FF]Place your [/color][color=#F0D9A6]%d[/color][color=#E6F3FF] Bet Coins![/color]" \
			% GlobalBetarena.bet_coins
			label_toomany.visible = false
		else : 
			show_toomany_warning()
		await get_tree().create_timer(0.05).timeout
		
		texture5.visible = true

	elif button == button10:
		if  GlobalBetarena.bet_coins >= 10 :
			current_bet += 10
			GlobalBetarena.bet_coins -= 10
			label_betcoins.text = "[color=#E6F3FF]Place your [/color][color=#F0D9A6]%d[/color][color=#E6F3FF] Bet Coins![/color]" \
			% GlobalBetarena.bet_coins
			label_toomany.visible = false
		else : 
			show_toomany_warning()
		await get_tree().create_timer(0.05).timeout
		
		texture10.visible = true
	elif button == buttonclear:
		GlobalBetarena.bet_coins += current_bet 
		current_bet = 0
		label_betcoins.text = "[color=#E6F3FF]Place your [/color][color=#F0D9A6]%d[/color][color=#E6F3FF] Bet Coins![/color]" \
		% GlobalBetarena.bet_coins
		label_toomany.visible = false
		await get_tree().create_timer(0.05).timeout
		
		textureclear.visible = true
	panel_bet_show.text = str(current_bet)
	button.disabled = false


func show_toomany_warning() -> void:
	# If an older tween is running, kill it immediately
	if warning_tween and warning_tween.is_running():
		warning_tween.kill()
	
	# Make visible instantly
	label_toomany.visible = true

	# Create a new tween that hides it after 1 second
	warning_tween = get_tree().create_tween()
	warning_tween.tween_interval(1.0)  # wait 1 sec
	warning_tween.tween_callback(func():
		label_toomany.visible = false
	)

func _on_button_confirm_pressed() -> void:
	# user chose current_bet → send it to quiz
	close_popup()

## Minimize Bet - popup 

func _on_minimize_button_pressed() -> void:
	toggle_minimize()
	
func toggle_minimize() -> void:
	var tween := get_tree().create_tween()
	if not is_minimized:
		# → minimize: shrink and move to, say, bottom-right
		is_minimized = true
		line.visible = false
		line2.visible = false
		# example target position (adjust to your layout)
		var target_pos := Vector2(
			0,
			get_viewport_rect().size.y - get_viewport_rect().size.y/2
		)
		tween.tween_property(panel, "position", target_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(panel, "scale", Vector2(0.35, 0.35), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# optional: fade out inner controls except the minimize button
		for child in panel.get_children():
			if child is Control and child != $Panel/Panel6:
				child.visible = false
	else:
		line.visible = true
		line2.visible = true
		is_minimized = false
		var center_pos := (get_viewport_rect().size * 0.5) - (panel.size * 0.5)
		tween.tween_property(panel, "position", center_pos, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for child in panel.get_children():
			if child is Control and child != $Panel/Panel6:
				child.visible = true


func house_modifier_from_bet_size(r_bs: float) -> float:
	var neutral := 30.0
	var max_shift := 0.30
	var m := max_shift * (neutral - r_bs) / neutral
	return clamp(m, -max_shift, max_shift)


func calc_r_lb(last_bet: float, bank_now: float) -> float:
	if bank_now <= 0.0:
		return 0.0
	return clamp(last_bet / bank_now, 0.0, 1.0)


func house_modifier_from_last_bet(r_lb: float) -> float:
	var pivot := 0.5
	var max_shift := 0.10
	var m := max_shift * (r_lb - pivot) / pivot
	return clamp(m, -max_shift, max_shift)


func house_modifier_from_depth(fee_level: int) -> float:
	var step := 0.03        # +3% per step (tightening)
	var max_shift := 0.30   # cap at -30%
	var m := -step * float(fee_level)
	return clamp(m, -max_shift, 0.0)
	

func house_modifier_from_safety() -> float:
	var net_last3 := net_last3_sum()
	if net_last3 < -15.0:
		# consume safety
		net3 = [0.0, 0.0, 0.0]
		net3_i = 0
		return 0.30
	return 0.0

func push_net3(net_change: float) -> void:
	net3[net3_i] = net_change
	net3_i = (net3_i + 1) % 3

func net_last3_sum() -> float:
	return net3[0] + net3[1] + net3[2]
	
func get_base_range(diff: int) -> Vector2:
	match diff:
		0: return RANGE_EASY
		1: return RANGE_MEDIUM
		2: return RANGE_HARD
		3: return RANGE_ULTIMATE
		_: return RANGE_MEDIUM
		

	
func set_quick_result() -> void:
	update_fee_label()
	update_mood_and_payout_preview()

func update_fee_label() -> void:
	if label_fee == null:
		return
	label_fee.bbcode_enabled = true
	label_fee.text = "[color=%s]Fee:[/color] [color=%s]%d[/color]" \
		% [COL_ACCENT, COL_FEE, GlobalBetarena.global_fee]


func update_possible_profit_label() -> void:
	# base range by difficulty
	var base := get_base_range(GlobalBetarena.current_difficulty)
	var low := base.x
	var high := base.y
	# total house mood modifier
	var m_total := m_bs + m_lb - m_depth + m_safety
	m_total = clamp(m_total, -0.40, 0.30)
	# apply house mood
	low *= (1.0 + m_total)
	high *= (1.0 + m_total)

	# streak bonus (shown separately)
	var streak_bonus := GlobalBetarena.streak * 0.05
	streak_bonus = max(streak_bonus, 0.0)

	var base_roll := randf_range(low, high)

	var atk_mult := 1.0
	if GlobalBetarena.atk_active:
		atk_mult = 2.0
	var def_extra := GlobalBetarena.def_extra_profit * 0.05
	# actual rolled profit
	profit_actual_percentage = (base_roll * atk_mult) + streak_bonus + def_extra
	GlobalBetarena.profit_actual_percentage_quiz = profit_actual_percentage

	# displayed range (same logic)
	var low_show := low * atk_mult
	var high_show := high * atk_mult
	var low_pct := int(round(low_show * 100.0))
	var high_pct := int(round(high_show * 100.0))
	var streak_pct: int = int(round(float(GlobalBetarena.streak) * 5.0))
	var locked_pct: int = int(round(float(GlobalBetarena.def_extra_profit) * 5.0))
	$Panel/Label_possible_profits.bbcode_enabled = true

	var text := "[color=%s]Total Payout:[/color] [color=%s]+%d–%d%%[/color]" \
		% [COL_ACCENT, COL_GOLD, low_pct, high_pct]

	if streak_pct > 0:
		text += "\n[color=%s]Streak Bonus:[/color] [color=%s]%d%%[/color]" \
			% [COL_ACCENT, COL_GOLD, streak_pct]

	if locked_pct > 0:
		text += "\n[color=%s]Locked Bonus:[/color] [color=%s]%d%%[/color]" \
			% [COL_ACCENT, COL_GOLD, locked_pct]

	$Panel/Label_possible_profits.text = text


func update_mood_and_payout_preview() -> void:
	# --- modifiers (assumes you already updated: m_bs, m_lb, m_depth, m_safety) ---
	var m_total := m_bs + m_lb + m_depth + m_safety
	m_total = clamp(m_total, -0.40, 0.30)

	# --- mood label (safety overrides) ---
	var mood_text := "Calm"
	var mood_symbol := "⚖️"
	if m_safety > 0.0:
		mood_text = "Generous"
		mood_symbol = "💎"
	elif m_total <= -0.20:
		mood_text = "Tight"
		mood_symbol = "🔒"
	elif m_total <= -0.07:
		mood_text = "Alert"
		mood_symbol = "⚠️"
	elif m_total >= 0.12:
		mood_text = "Calm"
		mood_symbol = "🌿"
	else:
		mood_text = "Neutral"

	# --- show mood ---
	$Panel/House_Mood.bbcode_enabled = true
	$Panel/House_Mood.text = "[color=%s]House Mood:[/color] [color=%s]%s %s[/color]" \
		% [COL_ACCENT, COL_KEY, mood_symbol, mood_text]
