extends RefCounted
## Small shared controls; the art itself is rendered at its native pixel grid.

const INK := Color("18202d")
const CREAM := Color("f3e6c6")
const MINT := Color("91ddc5")
const MUTED := Color("bac0ce")
const GOLD := Color("efc875")


static func panel(parent: Node, rect: Rect2, opacity: float = 0.88) -> Panel:
	var control := Panel.new()
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_stylebox_override("panel", style(Color(INK, opacity), Color("64707d")))
	parent.add_child(control)
	return control


static func label(parent: Node, text: String, rect: Rect2, font_size: int = 22, color: Color = CREAM) -> Label:
	var control := Label.new()
	control.text = text
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(control)
	return control


static func button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.position = rect.position
	control.size = rect.size
	control.focus_mode = Control.FOCUS_NONE
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_size_override("font_size", 23)
	control.add_theme_color_override("font_color", CREAM)
	control.add_theme_color_override("font_disabled_color", Color("8a8d99"))
	control.add_theme_stylebox_override("normal", style(Color("263e49"), Color("7eaaa8")))
	control.add_theme_stylebox_override("hover", style(Color("3b5c61"), MINT))
	control.add_theme_stylebox_override("pressed", style(Color("486b69"), GOLD))
	control.add_theme_stylebox_override("disabled", style(Color("252c38"), Color("535a65")))
	control.pressed.connect(callback)
	parent.add_child(control)
	return control


static func style(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(2)
	result.set_content_margin_all(12)
	return result
