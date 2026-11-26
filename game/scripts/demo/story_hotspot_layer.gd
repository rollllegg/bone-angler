extends Control
## Clickable suspicious parts on a story guest's portrait.
## Story choices carry a 48x64 hotspot; this layer maps it to screen space.

signal choice_made(id: String)

const UI := preload("res://scripts/demo/demo_ui.gd")
const VIEW_SCALE := 4.0
const LABEL_WIDTH := 360.0

var _shop = null
var _entries: Array = []
var _hover := -1
var _label: Label


func setup(shop) -> void:
	_shop = shop
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func _ready() -> void:
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", UI.GOLD)
	_label.add_theme_color_override("font_outline_color", UI.INK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	_label.hide()


func refresh(story) -> void:
	_entries.clear()
	_hover = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if _label != null:
		_label.hide()
	if _shop == null or story == null or not story.is_awaiting_choice():
		hide()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var portrait: Rect2 = _shop.get_story_portrait_rect()
	if portrait.size == Vector2.ZERO:
		hide()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var sprite_scale := portrait.size.x / 48.0
	var stage_scale := sprite_scale * VIEW_SCALE
	var stage_origin := portrait.position * VIEW_SCALE
	var flip: bool = _shop.is_story_sprite_flipped()
	var bounds := Rect2()
	for choice in story.visible_choices():
		var kind := str(choice.get("kind", ""))
		if kind == "accept" or kind == "refuse":
			continue
		var hotspot = choice.get("hotspot", {})
		if typeof(hotspot) != TYPE_DICTIONARY:
			continue
		var raw_rects = hotspot.get("rects", [])
		var variants = hotspot.get("variants", {})
		if typeof(variants) == TYPE_DICTIONARY:
			var variant = variants.get(str(story.get_portrait_id()), null)
			if typeof(variant) == TYPE_ARRAY:
				raw_rects = variant
		if typeof(raw_rects) != TYPE_ARRAY:
			continue
		var entry := {
			"id": str(choice.get("id", "")),
			"text": str(choice.get("text", "")),
			"locked": bool(choice.get("locked", false)),
			"reason": str(choice.get("reason", "")),
			"rects": [],
		}
		for raw in raw_rects:
			if typeof(raw) != TYPE_ARRAY or raw.size() != 4:
				continue
			var x := float(raw[0])
			if flip:
				x = 48.0 - x - float(raw[2])
			var rect := Rect2(
				stage_origin + Vector2(x, float(raw[1])) * stage_scale,
				Vector2(float(raw[2]), float(raw[3])) * stage_scale
			)
			entry.rects.append(rect)
			bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
		if not entry.rects.is_empty():
			_entries.append(entry)
	if _entries.is_empty():
		hide()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	var margin := 10.0
	var origin := bounds.position - Vector2(margin, margin)
	position = origin
	size = bounds.size + Vector2(margin, margin) * 2.0
	for entry in _entries:
		for index in entry.rects.size():
			var rect: Rect2 = entry.rects[index]
			entry.rects[index] = Rect2(rect.position - origin, rect.size)
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	_set_hover(get_local_mouse_position())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_hover(event.position)
		if _hover >= 0 and not bool(_entries[_hover].locked):
			choice_made.emit(str(_entries[_hover].id))
			accept_event()


func _set_hover(point: Vector2) -> void:
	var next := -1
	for index in range(_entries.size() - 1, -1, -1):
		for rect in _entries[index].rects:
			if rect.has_point(point):
				next = index
				break
		if next >= 0:
			break
	if next == _hover:
		return
	_hover = next
	if _hover >= 0:
		var entry: Dictionary = _entries[_hover]
		var text := str(entry.text)
		if bool(entry.locked):
			var reason := str(entry.reason)
			text += "（%s）" % reason if reason != "" else "（已调查）"
		_label.text = text
		_label.size = Vector2(LABEL_WIDTH, 28)
		_label.position = Vector2((size.x - LABEL_WIDTH) * 0.5, size.y + 4.0)
		_label.show()
	else:
		_label.hide()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 and not bool(_entries[_hover].locked) else Control.CURSOR_ARROW
	queue_redraw()


func _draw() -> void:
	for index in _entries.size():
		var entry: Dictionary = _entries[index]
		var color := Color(UI.MUTED, 0.65) if bool(entry.locked) else (UI.GOLD if index == _hover else Color(UI.GOLD, 0.42))
		for rect in entry.rects:
			if index == _hover:
				draw_rect(rect, Color(UI.GOLD, 0.10))
			draw_rect(rect, color, false, 3.0)
