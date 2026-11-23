extends Control
## Parchment dialogue panel for special story guests.
## It renders a StoryRuntime and owns the transient typing challenge UI.

const UI := preload("res://scripts/demo/demo_ui.gd")
const TypingChallenge := preload("res://scripts/systems/typing_challenge.gd")
const LetterBubbleRow := preload("res://scripts/demo/letter_bubble_row.gd")

signal advance_requested
signal choice_requested(choice_id: String)
signal finish_requested

var _runtime = null
var _signature := ""
var _backdrop: ColorRect
var _frame: Panel
var _speaker: Label
var _body: Label
var _hint: Label
var _choices_root: Control
var _advance: Button
var _finish: Button
var _buttons: Array = []
var _typing
var _bubbles: LetterBubbleRow
var _callout_prompt: Label
var _callout_timer: Label
var _callout_feedback: Label
var _callout_button: Button
var _cancel_button: Button
var _callout_mode := false
var _callout_limit := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = ColorRect.new()
	_backdrop.color = Color(UI.INK, 0.96)
	_backdrop.position = Vector2.ZERO
	_backdrop.size = Vector2(578, 600)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_frame = UI.panel(self, Rect2(0, 0, 578, 600), "parchment")
	UI.label(self, "特殊来客 · 剧情审查", Rect2(24, 10, 400, 28), 18, UI.GOLD)
	_speaker = UI.label(self, "", Rect2(24, 42, 530, 30), 24, UI.MINT)
	_body = UI.label(self, "", Rect2(24, 78, 530, 160), 21, UI.CREAM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hint = UI.label(self, "", Rect2(24, 242, 530, 24), 15, UI.MUTED)
	_choices_root = Control.new()
	_choices_root.position = Vector2(24, 272)
	_choices_root.size = Vector2(530, 252)
	_choices_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_choices_root)

	_typing = TypingChallenge.new()
	_typing.name = "TypingChallenge"
	_typing.hint_delay = 0.2
	add_child(_typing)
	_typing.set_process(false)
	_typing.state_changed.connect(_on_typing_changed)
	_typing.completed.connect(_on_typing_completed)
	_typing.missed.connect(_on_typing_missed)
	_typing.timed_out.connect(_on_typing_timed_out)

	_bubbles = LetterBubbleRow.new()
	_bubbles.name = "LetterBubbles"
	_bubbles.position = Vector2(24, 276)
	_bubbles.size = Vector2(530, 64)
	_bubbles.visible = false
	add_child(_bubbles)
	_bubbles.setup(56.0, 24)
	_callout_prompt = UI.label(self, "", Rect2(24, 344, 530, 40), 19, UI.CREAM)
	_callout_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_callout_prompt.visible = false
	_callout_timer = UI.label(self, "", Rect2(24, 388, 530, 28), 17, UI.MUTED)
	_callout_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_timer.visible = false
	_callout_feedback = UI.label(self, "", Rect2(24, 420, 530, 28), 17, UI.MUTED)
	_callout_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_feedback.visible = false

	_advance = UI.button(self, "继续", Rect2(24, 540, 250, 42), func() -> void: advance_requested.emit(), true)
	_finish = UI.button(self, "结束接待", Rect2(300, 540, 254, 42), func() -> void: finish_requested.emit(), true)
	_finish.visible = false
	_callout_button = UI.button(self, "叫破（输入真名）", Rect2(24, 540, 530, 42), _on_callout_pressed, true)
	_callout_button.visible = false
	_cancel_button = UI.button(self, "放弃（Esc）", Rect2(24, 540, 530, 42), _on_cancel_pressed, false)
	_cancel_button.visible = false
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)
	visible = false


func render(runtime) -> void:
	if runtime == null:
		reset()
		return
	if _callout_mode:
		if runtime == _runtime:
			return
		cancel_callout()
	var signature: String = runtime.get_signature()
	if runtime == _runtime and signature == _signature:
		return
	_runtime = runtime
	_signature = signature
	visible = true

	var step: Dictionary = runtime.current_step()
	if step.is_empty():
		_speaker.text = ""
		_speaker.add_theme_color_override("font_color", UI.MUTED)
		_body.text = "（你合上了账本。）" if runtime.is_closed() else "……"
	else:
		var speaker := str(step.get("speaker_name", ""))
		_speaker.text = speaker if speaker != "" else "旁白"
		_speaker.add_theme_color_override("font_color", UI.MINT if speaker != "" else UI.MUTED)
		_body.text = str(step.get("text", ""))

	_clear_choices()
	var choices: Array = runtime.visible_choices()
	var closed: bool = runtime.is_closed()
	var height := 360.0 if closed else 600.0
	size.y = height
	_backdrop.size.y = height
	_frame.size.y = height
	_advance.position.y = height - 60.0
	_finish.position.y = height - 60.0
	_callout_button.position.y = height - 60.0
	_cancel_button.position.y = height - 60.0
	_advance.visible = not closed and choices.is_empty()
	_finish.visible = closed
	_callout_button.visible = false
	_cancel_button.visible = false
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var label := "%d. %s" % [index + 1, str(choice.get("text", ""))]
		if bool(choice.get("locked", false)):
			var reason := str(choice.get("reason", ""))
			label += "（%s）" % reason if reason != "" else "（不可选）"
		var button := UI.button(
			_choices_root,
			label,
			Rect2(0, index * 42, 530, 38),
			_on_choice.bind(str(choice.get("id", ""))),
			false
		)
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = bool(choice.get("locked", false))
		_buttons.append(button)

	if not closed and not choices.is_empty() and runtime.can_callout():
		_callout_button.text = runtime.get_callout_button_text()
		_callout_button.visible = true

	if closed:
		_hint.text = "审查结束，按 Shift 或点击结束接待"
		_hint.add_theme_color_override("font_color", UI.MUTED)
	elif runtime.can_feed_potion():
		_hint.text = "左侧选一味药，按 F 请他喝下"
		_hint.add_theme_color_override("font_color", UI.GOLD)
	elif runtime.has_fed_potion():
		_hint.text = "他喝过：%s　火气 %+d" % [runtime.get_dose_label(), runtime.get_dose_score()]
		_hint.add_theme_color_override("font_color", UI.MINT)
	else:
		_hint.text = ""


func reset() -> void:
	if _callout_mode:
		cancel_callout()
	visible = false
	_runtime = null
	_signature = ""
	_clear_choices()
	_hide_callout_ui()
	_callout_button.visible = false
	_cancel_button.visible = false
	_finish.visible = false
	_advance.visible = true


func submit_letter(letter: String) -> void:
	if not _callout_mode:
		return
	_typing.submit_character(letter)


func is_typing() -> bool:
	return _callout_mode


func cancel_callout() -> void:
	if not _callout_mode:
		return
	_callout_mode = false
	set_process(false)
	_typing.stop()
	_hide_callout_ui()
	if _runtime != null:
		_runtime.cancel_callout()


func _on_callout_pressed() -> void:
	if _runtime == null or _callout_mode or _runtime.is_closed():
		return
	_callout_mode = true
	var config: Dictionary = _runtime.start_callout()
	if config.is_empty():
		_callout_mode = false
		return
	_callout_limit = float(config.get("time_limit", 0.0))
	var answer := str(config.get("answer", ""))
	_typing.start(answer, _callout_limit)
	var bubble_size := 56.0
	if answer.length() > 8:
		bubble_size = clampf(530.0 / maxf(float(answer.length()), 1.0) - 6.0, 36.0, 56.0)
	_bubbles.setup(bubble_size, int(bubble_size * 0.42))
	_bubbles.render(_typing.target, _typing.typed_count, _typing.revealed_count)
	_bubbles.visible = true
	_callout_prompt.text = str(config.get("prompt_text", ""))
	if _callout_prompt.text == "":
		_callout_prompt.text = "输入他的名字"
	_callout_prompt.visible = true
	_callout_timer.visible = true
	_callout_feedback.text = "按顺序输入，输错会从头开始"
	_callout_feedback.add_theme_color_override("font_color", UI.MUTED)
	_callout_feedback.visible = true
	_callout_button.visible = false
	_cancel_button.visible = true
	_advance.visible = false
	_finish.visible = false
	_clear_choices()
	_hint.visible = false
	_update_callout_timer()
	set_process(true)


func _on_cancel_pressed() -> void:
	cancel_callout()


func _on_visibility_changed() -> void:
	if not visible and _callout_mode:
		cancel_callout()


func _process(delta: float) -> void:
	if not _callout_mode:
		return
	_typing.tick(delta)
	_update_callout_timer()


func _on_typing_changed() -> void:
	if not _callout_mode:
		return
	_bubbles.render(_typing.target, _typing.typed_count, _typing.revealed_count)
	if _typing.active and _typing.typed_count > 0:
		_callout_feedback.text = "继续输入……"
		_callout_feedback.add_theme_color_override("font_color", UI.MUTED)
	_update_callout_timer()


func _on_typing_completed(_target: String) -> void:
	_finish_callout(true)


func _on_typing_missed(_received: String, _expected: String) -> void:
	if not _callout_mode:
		return
	_callout_feedback.text = "输错了，从头来。"
	_callout_feedback.add_theme_color_override("font_color", UI.WARN)


func _on_typing_timed_out() -> void:
	_finish_callout(false)


func _finish_callout(success: bool) -> void:
	if not _callout_mode:
		return
	_callout_mode = false
	set_process(false)
	_typing.stop()
	_hide_callout_ui()
	if _runtime != null:
		_runtime.resolve_callout(success)


func _hide_callout_ui() -> void:
	_bubbles.visible = false
	_callout_prompt.visible = false
	_callout_timer.visible = false
	_callout_feedback.visible = false
	_cancel_button.visible = false
	_hint.visible = true


func _update_callout_timer() -> void:
	if _callout_limit > 0.0:
		_callout_timer.text = "剩余 %.1f 秒" % _typing.time_left
		_callout_timer.add_theme_color_override("font_color", UI.WARN if _typing.time_left <= 5.0 else UI.MUTED)
	else:
		_callout_timer.text = "按顺序输入"
		_callout_timer.add_theme_color_override("font_color", UI.MUTED)


func _on_choice(choice_id: String) -> void:
	choice_requested.emit(choice_id)


func _clear_choices() -> void:
	for child in _choices_root.get_children():
		_choices_root.remove_child(child)
		child.queue_free()
	_buttons.clear()
