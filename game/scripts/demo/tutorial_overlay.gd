extends Control

signal skip_requested
signal finish_requested
signal tip_dismissed

const UI := preload("res://scripts/demo/demo_ui.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")
const CARD_SIZE := Vector2(616, 190)
const FINAL_CARD_HEIGHT := 260.0
const TOTAL_STEPS := 6
const TIP_SIZE := Vector2(636, 108)
const TIP_DURATION := 7.0
const TIP_FADE := 0.65
const TIP_ORIGINS := {
	"River": Vector2(28, 692), "Shop": Vector2(492, 822),
	"Alchemy": Vector2(28, 790), "Market": Vector2(28, 790),
}
const STEP_ICONS := [
	UI.ICON_ROD, UI.ICON_ROD, UI.ICON_ESSENCE,
	UI.ICON_SOUL, UI.ICON_POTION, UI.ICON_COIN,
]

var _guide: Control
var _shade: Array[ColorRect] = []
var _frame: Control
var _opening := Rect2()
var _pulse := 0.0
var _step_number := 1
var _card: Panel
var _card_decor: Control
var _step_icon: TextureRect
var _step: Label
var _heading: Label
var _body_box: Panel
var _instructions: Label
var _skip_button: Button
var _finish_button: Button
var _tip: Panel
var _tip_bar: Control
var _tip_text: Label
var _tip_close_button: Button
var _tip_remaining := 0.0
var _tip_paused := false


func setup(stage_size: Vector2, audio: Audio) -> void:
	size = stage_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_guide = Control.new()
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guide)
	for i in 4:
		var strip := ColorRect.new()
		strip.color = Color(UI.INK, 0.56)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_guide.add_child(strip)
		_shade.append(strip)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	_guide.add_child(_frame)

	_card = UI.panel(_guide, Rect2(Vector2.ZERO, CARD_SIZE), "popup")
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_decor = Control.new()
	_card_decor.size = CARD_SIZE
	_card_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_decor.draw.connect(_draw_card_decor)
	_card.add_child(_card_decor)

	var step_badge := UI.panel(_card, Rect2(20, 14, 34, 34), "wood_inset")
	step_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_icon = UI.icon_rect(step_badge, UI.ICON_ROD, Rect2(5, 5, 24, 24))

	_step = UI.label(_card, "", Rect2(62, 16, 118, 28), 16, UI.MINT)
	_skip_button = UI.button(_card, "跳过教程", Rect2(CARD_SIZE.x - 134.0, 13, 114, 34), skip_requested.emit, false)
	_skip_button.add_theme_font_size_override("font_size", 16)
	_skip_button.pressed.connect(audio.play.bind(Audio.Cue.UI_CLICK))

	_heading = UI.label(_card, "", Rect2(22, 60, CARD_SIZE.x - 44.0, 32), 23, UI.GOLD)
	_body_box = UI.panel(_card, Rect2(20, 96, CARD_SIZE.x - 40.0, 72), "wood_inset")
	_body_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instructions = UI.label(_card, "", Rect2(32, 102, CARD_SIZE.x - 64.0, 62), 18, UI.CREAM)
	_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instructions.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_instructions.add_theme_constant_override("line_spacing", 3)

	_finish_button = UI.button(_card, "Space  开始值班", Rect2(188, 184, 240, 42), finish_requested.emit, true)
	_finish_button.add_theme_font_size_override("font_size", 20)
	_finish_button.pressed.connect(audio.play.bind(Audio.Cue.UI_CONFIRM))

	_tip = UI.panel(self, Rect2(Vector2.ZERO, TIP_SIZE), "popup")
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_badge := UI.panel(_tip, Rect2(16, 16, 44, 44), "wood_inset")
	tip_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.icon_rect(tip_badge, UI.ICON_SOUL, Rect2(8, 8, 28, 28))
	UI.label(_tip, "值班提示", Rect2(70, 12, 140, 24), 16, UI.MINT)
	_tip_text = UI.label(_tip, "", Rect2(70, 36, TIP_SIZE.x - 130.0, 46), 17, UI.CREAM)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tip_text.add_theme_constant_override("line_spacing", 2)
	_tip_close_button = UI.button(_tip, "×", Rect2(TIP_SIZE.x - 50.0, 14, 34, 32), _dismiss_tip, false)
	_tip_close_button.add_theme_font_size_override("font_size", 19)
	_tip_close_button.accessibility_name = "关闭值班提示"
	_tip_close_button.pressed.connect(audio.play.bind(Audio.Cue.UI_CLICK))
	_tip_bar = Control.new()
	_tip_bar.position = Vector2(18, TIP_SIZE.y - 14.0)
	_tip_bar.size = Vector2(TIP_SIZE.x - 36.0, 4.0)
	_tip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_bar.draw.connect(_draw_tip_bar)
	_tip.add_child(_tip_bar)

	_tip.hide()
	_guide.hide()


func set_step(number: int, title: String, instructions: String, target: Rect2, card_origin: Vector2) -> void:
	_step_number = clampi(number, 1, TOTAL_STEPS)
	_step.text = "引导 %d / %d" % [_step_number, TOTAL_STEPS]
	_step_icon.texture = STEP_ICONS[_step_number - 1]
	_heading.text = title
	_instructions.text = instructions

	var is_final := _step_number == TOTAL_STEPS
	var card_height := FINAL_CARD_HEIGHT if is_final else CARD_SIZE.y
	_card.size = Vector2(CARD_SIZE.x, card_height)
	_card_decor.size = _card.size
	_body_box.size.y = 100.0 if is_final else 76.0
	_instructions.size.y = 90.0 if is_final else 66.0
	_finish_button.position.y = card_height - 56.0
	_finish_button.visible = is_final
	_skip_button.visible = not is_final

	var margin := 16.0
	_card.position = Vector2(
		clampf(card_origin.x, margin, size.x - _card.size.x - margin),
		clampf(card_origin.y, margin, size.y - _card.size.y - margin)
	)
	_opening = target.grow(8.0).intersection(Rect2(Vector2.ZERO, size)) if target.has_area() else Rect2()
	_layout_shade()
	_card_decor.queue_redraw()
	_frame.queue_redraw()
	_guide.show()


func hide_guide() -> void:
	_guide.hide()


func handle_key(code: Key) -> bool:
	if _guide.visible and _finish_button.visible and code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		UI.activate(_finish_button)
		return true
	return false


func show_tip(message: String) -> void:
	_tip_text.text = message
	_tip_remaining = TIP_DURATION
	_tip.modulate.a = 1.0
	_tip.visible = not _tip_paused
	_tip_bar.queue_redraw()


func set_tip_context(location: String, paused: bool) -> void:
	_tip_paused = paused
	_tip.position = TIP_ORIGINS[location]
	_tip.visible = _tip_remaining > 0.0 and not paused


func clear_tip() -> void:
	_tip_remaining = 0.0
	_tip.hide()


func _dismiss_tip() -> void:
	clear_tip()
	tip_dismissed.emit()


func _process(delta: float) -> void:
	if _guide.visible and _opening.has_area():
		_pulse += delta * 4.0
		_frame.queue_redraw()
	if not _tip_paused and _tip_remaining > 0.0:
		_tip_remaining = maxf(0.0, _tip_remaining - delta)
		_tip.modulate.a = minf(1.0, _tip_remaining / TIP_FADE)
		_tip_bar.queue_redraw()
		if _tip_remaining == 0.0:
			_dismiss_tip()


func _layout_shade() -> void:
	var edge := _opening.end
	var strips := [
		Rect2(0, 0, size.x, _opening.position.y),
		Rect2(0, edge.y, size.x, size.y - edge.y),
		Rect2(0, _opening.position.y, _opening.position.x, _opening.size.y),
		Rect2(edge.x, _opening.position.y, size.x - edge.x, _opening.size.y),
	]
	for i in _shade.size():
		_shade[i].position = strips[i].position
		_shade[i].size = strips[i].size
		_shade[i].visible = _opening.has_area()


func _draw_card_decor() -> void:
	var w := _card_decor.size.x
	# Header divider line
	_card_decor.draw_rect(Rect2(20, 52, w - 40.0, 2), Color("5b483d", 0.9))
	_card_decor.draw_rect(Rect2(20, 54, w - 40.0, 1), Color(UI.MINT, 0.30))
	# Six pixel progress pips next to "引导 X / 6"
	var pip_x := 182.0
	var pip_y := 26.0
	for index in TOTAL_STEPS:
		var step_idx := index + 1
		var pip_w := 20.0 if step_idx == _step_number else 12.0
		var rect := Rect2(pip_x, pip_y, pip_w, 8.0)
		_card_decor.draw_rect(rect.grow(1.0), UI.INK)
		var fill := UI.GOOD if step_idx < _step_number else (UI.GOLD if step_idx == _step_number else Color("433c54"))
		_card_decor.draw_rect(rect, fill)
		if step_idx <= _step_number:
			_card_decor.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 2.0), Color("fff8dc", 0.55))
		pip_x += pip_w + 6.0


func _draw_tip_bar() -> void:
	var rect := Rect2(Vector2.ZERO, _tip_bar.size)
	_tip_bar.draw_rect(rect, Color(UI.INK, 0.8))
	var ratio := clampf(_tip_remaining / TIP_DURATION, 0.0, 1.0)
	var fill_w := floorf(rect.size.x * ratio)
	if fill_w > 0.0:
		_tip_bar.draw_rect(Rect2(0, 0, fill_w, rect.size.y), Color(UI.MINT, 0.85))
		_tip_bar.draw_rect(Rect2(0, 0, fill_w, 1.0), Color("fff8dc", 0.55))


func _draw_frame() -> void:
	if not _opening.has_area():
		return
	var wave := (sin(_pulse) + 1.0) * 0.5
	var tint := Color(UI.GOLD, 0.72 + 0.28 * wave)
	var border := _opening.grow(2.0)
	_frame.draw_rect(border.grow(2.0), Color(UI.INK, 0.85), false, 2.0)
	_frame.draw_rect(border, tint, false, 2.0)

	# Crisp pixel corner brackets
	var corner := 14.0
	var thick := 3.0
	var glow := Color("fff8dc", 0.75 + 0.25 * wave)
	var corners := [
		[border.position, Vector2(1, 1)],
		[Vector2(border.end.x, border.position.y), Vector2(-1, 1)],
		[Vector2(border.position.x, border.end.y), Vector2(1, -1)],
		[border.end, Vector2(-1, -1)],
	]
	for item in corners:
		var pt: Vector2 = item[0]
		var dir: Vector2 = item[1]
		var h_rect := Rect2(pt.x if dir.x > 0 else pt.x - corner, pt.y if dir.y > 0 else pt.y - thick, corner, thick)
		var v_rect := Rect2(pt.x if dir.x > 0 else pt.x - thick, pt.y if dir.y > 0 else pt.y - corner, thick, corner)
		_frame.draw_rect(h_rect, glow)
		_frame.draw_rect(v_rect, glow)

	# Outlined pixel directional arrow
	var center := _opening.get_center()
	var above := _opening.position.y >= 124.0 and _card.position.y < _opening.end.y
	var direction := 1.0 if above else -1.0
	var edge_y := _opening.position.y if above else _opening.end.y
	var offset := 20.0 + roundf(sin(_pulse) * 3.0)
	var origin := Vector2(roundf(center.x), edge_y - direction * offset)
	var sideways := _card.get_rect().grow(8.0).has_point(origin)
	if sideways:
		direction = 1.0
		origin = Vector2(_opening.position.x - offset, roundf(center.y))
	for row in 5:
		var width := 20 - row * 4
		var rect := Rect2(-width * 0.5, row * 3 * direction, width, 3)
		if sideways:
			rect = Rect2(rect.position.y, rect.position.x, rect.size.y, rect.size.x)
		rect.position += origin
		_frame.draw_rect(rect.grow(1.0), UI.INK)
		_frame.draw_rect(rect, tint)
		if row == 1:
			_frame.draw_rect(Rect2(rect.position + Vector2(2, 0), Vector2(maxf(2.0, rect.size.x - 4.0), 1.0)), Color("fff8dc", 0.8))
