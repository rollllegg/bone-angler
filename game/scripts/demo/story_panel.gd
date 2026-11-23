extends Control
## Parchment dialogue panel for special story guests.
## It renders a StoryRuntime and emits player intents; it owns no game rules.

const UI := preload("res://scripts/demo/demo_ui.gd")

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
	_advance = UI.button(self, "继续", Rect2(24, 540, 250, 42), func() -> void: advance_requested.emit(), true)
	_finish = UI.button(self, "结束接待", Rect2(300, 540, 254, 42), func() -> void: finish_requested.emit(), true)
	_finish.visible = false
	visible = false


func render(runtime) -> void:
	if runtime == null:
		reset()
		return
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
	_advance.visible = not closed and choices.is_empty()
	_finish.visible = closed
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
	visible = false
	_runtime = null
	_signature = ""
	_clear_choices()
	_finish.visible = false
	_advance.visible = true


func _on_choice(choice_id: String) -> void:
	choice_requested.emit(choice_id)


func _clear_choices() -> void:
	for child in _choices_root.get_children():
		_choices_root.remove_child(child)
		child.queue_free()
	_buttons.clear()
