extends Control
## Anubis' scale. The player enters how many soul coins to put on the right
## pan; the beam always settles level before the result is applied.

signal submitted(amount: int)

const UI := preload("res://scripts/demo/demo_ui.gd")
const PANEL_SIZE := Vector2(700, 220)
const ANIM_TIME := 0.8

var _story = null
var _max := 0
var _value := 0
var _animating := false
var _anim_time := 0.0
var _tilt := 0.0
var _start_tilt := 0.0
var _prompt: Label
var _amount: Label
var _range: Label
var _input: LineEdit
var _zero: Button
var _all: Button
var _confirm: Button
var _scale: ScaleView


class ScaleView extends Control:
	const TEXTURE := preload("res://assets/art/story/props/scale.png")
	var tilt := 0.0
	var ratio := 0.0

	func _draw() -> void:
		var art_size := Vector2(204, 204)
		var pivot := Vector2(170, 112)
		draw_set_transform(pivot, tilt, Vector2.ONE)
		draw_texture_rect(TEXTURE, Rect2(-art_size * 0.5, art_size), false)
		draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = PANEL_SIZE
	var background := UI.panel(self, Rect2(Vector2.ZERO, PANEL_SIZE), "dark_wood")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scale = ScaleView.new()
	_scale.position = Vector2(12, 0)
	_scale.size = Vector2(330, 220)
	_scale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scale)
	UI.label(self, "称心", Rect2(350, 18, 340, 34), 28, UI.GOLD)
	_prompt = UI.label(self, "", Rect2(350, 54, 340, 36), 16, UI.MUTED)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(self, "放入渡魂币", Rect2(350, 90, 170, 20), 16, UI.CREAM)
	UI.panel(self, Rect2(350, 110, 170, 40), "wood_inset")
	_input = LineEdit.new()
	_input.position = Vector2(350, 110)
	_input.size = Vector2(170, 40)
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.add_theme_font_size_override("font_size", 24)
	_input.add_theme_color_override("font_color", UI.CREAM)
	_input.add_theme_color_override("font_selected_color", UI.INK)
	_input.add_theme_color_override("selection_color", UI.GOLD)
	_input.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_input.text_changed.connect(_on_text_changed)
	_input.text_submitted.connect(func(_text: String) -> void: _submit())
	add_child(_input)
	_zero = UI.button(self, "0", Rect2(528, 110, 58, 40), func() -> void: _set_value(0))
	_all = UI.button(self, "全部", Rect2(594, 110, 96, 40), func() -> void: _set_value(_max))
	_all.add_theme_font_size_override("font_size", 16)
	_range = UI.label(self, "", Rect2(350, 152, 340, 20), 14, UI.MUTED)
	_amount = UI.label(self, "", Rect2(350, 152, 340, 20), 14, UI.GOLD)
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_confirm = UI.button(self, "放上天平", Rect2(350, 176, 340, 40), _submit, true)
	_confirm.add_theme_font_size_override("font_size", 22)
	hide()
	set_process(false)


func is_active() -> bool:
	return visible and _story != null


func open(story, max_value: int) -> void:
	if _story != null:
		return
	_story = story
	_max = maxi(0, max_value)
	var config: Dictionary = story.start_judgment(_max)
	if config.is_empty():
		_story = null
		return
	_max = int(config.get("max", _max))
	_prompt.text = str(config.get("prompt_text", ""))
	_range.text = "可放 0 ～ %d 枚" % _max
	_value = 0
	_input.text = str(_value)
	_amount.text = "放入 %d 枚" % _value
	_tilt = _tilt_for(_value)
	_animating = false
	_input.editable = true
	_zero.disabled = false
	_all.disabled = false
	_confirm.disabled = false
	show()
	set_process(false)
	_scale.ratio = _ratio()
	_scale.tilt = _tilt
	_scale.queue_redraw()
	_input.grab_focus()


func close() -> void:
	_story = null
	_animating = false
	hide()
	set_process(false)


func _ratio() -> float:
	return 0.0 if _max <= 0 else clampf(float(_value) / float(_max), 0.0, 1.0)


func _tilt_for(value: int) -> float:
	var ratio := 0.0 if _max <= 0 else clampf(float(value) / float(_max), 0.0, 1.0)
	return (0.5 - ratio) * 0.32


func _set_value(value: int) -> void:
	if _story == null or _animating:
		return
	_value = clampi(value, 0, _max)
	_input.text = str(_value)
	_input.caret_column = _input.text.length()
	_scale.ratio = _ratio()
	_scale.tilt = _tilt_for(_value)
	_scale.queue_redraw()
	_amount.text = "放入 %d 枚" % _value


func _on_text_changed(text: String) -> void:
	if _story == null or _animating:
		return
	var clean := text.strip_edges()
	if clean.is_valid_int():
		_value = clampi(int(clean), 0, _max)
	else:
		_value = 0
	_scale.ratio = _ratio()
	_scale.tilt = _tilt_for(_value)
	_scale.queue_redraw()
	_amount.text = "放入 %d 枚" % _value


func _submit() -> void:
	if _story == null or _animating:
		return
	_value = clampi(_value, 0, _max)
	_input.text = str(_value)
	_animating = true
	_anim_time = 0.0
	_start_tilt = _tilt_for(_value)
	_input.editable = false
	_zero.disabled = true
	_all.disabled = true
	_confirm.disabled = true
	set_process(true)


func _process(delta: float) -> void:
	if not _animating:
		return
	_anim_time += delta
	var t := clampf(_anim_time / ANIM_TIME, 0.0, 1.0)
	_tilt = lerpf(_start_tilt, 0.0, ease(t, 0.4))
	_scale.tilt = _tilt
	_scale.queue_redraw()
	if t < 1.0:
		return
	_animating = false
	set_process(false)
	var story = _story
	var amount := _value
	hide()
	_story = null
	if story != null:
		submitted.emit(amount)


func finish_animation() -> void:
	if _animating:
		_process(ANIM_TIME)
