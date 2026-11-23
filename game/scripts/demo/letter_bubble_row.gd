extends HBoxContainer
## Reusable circular letter bubbles for a sequential typing challenge.
## Untyped letters stay hidden; only letters the player has typed are shown.

const MINT := Color("8fdbbd")
const HIDDEN := Color("496167")
const DONE_BG := Color("123c39")
const TODO_BG := Color("14292f")
const TODO_BORDER := Color("2c454a")

var target: String = ""
var typed_count: int = 0
var bubble_size: float = 56.0
var font_size: int = 24


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(size_value: float, font_value: int) -> void:
	bubble_size = maxf(size_value, 24.0)
	font_size = maxi(font_value, 12)
	_rebuild()


func render(value: String, typed: int) -> void:
	if value != target:
		target = value
		_rebuild()
	typed_count = typed
	_update()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for index in target.length():
		var bubble := PanelContainer.new()
		bubble.custom_minimum_size = Vector2(bubble_size, bubble_size)
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var letter := Label.new()
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
		letter.add_theme_font_size_override("font_size", font_size)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(letter)
		add_child(bubble)
	_update()


func _update() -> void:
	for index in get_child_count():
		var bubble := get_child(index) as PanelContainer
		if bubble == null:
			continue
		var letter := bubble.get_child(0) as Label
		if letter == null:
			continue
		var done := index < typed_count
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(bubble_size * 0.5))
		style.set_border_width_all(2)
		style.bg_color = DONE_BG if done else TODO_BG
		style.border_color = MINT if done else TODO_BORDER
		bubble.add_theme_stylebox_override("panel", style)
		letter.text = target.substr(index, 1) if done else "·"
		letter.add_theme_color_override("font_color", MINT if done else HIDDEN)
