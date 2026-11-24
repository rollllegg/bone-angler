extends Control
## The buttons keep fixed hit areas while their painted contents animate.

const UI := preload("res://scripts/demo/demo_ui.gd")
const Atmosphere := preload("res://scripts/demo/title_screen_fx.gd")
const RiverFish := preload("res://scripts/demo/title_river_fish.gd")
const PixelLogo := preload("res://scripts/demo/title_pixel_logo.gd")
const ROW_ORIGIN := Vector2(1140, 486)
const ROW_SIZE := Vector2(368, 64)
const ROW_STEP := 78
const INK := Color("161221")
const MINT := Color("7fe8c8")
const GOLD := Color("f5cc66")

var buttons: Array[Button] = []
var pointer: Pointer
var cursor := 0
var _thread_progress := 0.0
var _hints: Panel


func setup(stage_size: Vector2, start: Callable, resume: Callable, settings: Callable, quit: Callable) -> void:
	size = stage_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var atmosphere := Atmosphere.new()
	atmosphere.name = "CoverAtmosphere"
	atmosphere.setup(stage_size)
	add_child(atmosphere)
	var fish := RiverFish.new()
	fish.name = "RiverFish"
	fish.setup(atmosphere)
	add_child(fish)
	var logo := PixelLogo.new()
	logo.name = "PixelLogo"
	logo.setup()
	add_child(logo)
	var scrim := Control.new()
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.draw.connect(_draw_scrim.bind(scrim))
	add_child(scrim)
	var thread := Control.new()
	thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thread.draw.connect(_draw_thread.bind(thread))
	add_child(thread)

	_add_row("StartGame", "开始游戏", UI.ICON_ROD, start)
	_add_row("ContinueGame", "继续游戏", UI.ICON_SOUL, resume)
	_add_row("SettingsButton", "游戏设置", UI.ICON_WRENCH, settings)
	_add_row("QuitGame", "退出游戏", UI.ICON_EXIT, quit)
	(buttons[0] as Row).set_selected(true, false)
	pointer = Pointer.new()
	pointer.position = ROW_ORIGIN + Vector2(-11, 0)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pointer)

	_hints = UI.pixel_panel(self, Rect2(1156, 819, 290, 37), Color(INK, 0.72), Color("494052"), Color(INK, 0.5))
	var primary_width := UI.key_hint(_hints, ["W", "S"], "选择", Vector2(12, 5))
	UI.key_hint(_hints, ["Space"], "确认", Vector2(32 + primary_width, 5))
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if not version.is_empty():
		UI.label(self, "v" + version, Rect2(30, stage_size.y - 44, 280, 24), 12, Color(UI.MUTED, 0.50), false)
	_play_intro(thread)
	for i in buttons.size():
		buttons[i].mouse_entered.connect(select.bind(i))


func select(index: int) -> void:
	if cursor == index or buttons[index].disabled:
		return
	(buttons[cursor] as Row).set_selected(false)
	cursor = index
	(buttons[cursor] as Row).set_selected(true)
	pointer.follow(buttons[cursor].position.y)


func _add_row(node_name: String, caption: String, icon: Texture2D, action: Callable) -> void:
	var index := buttons.size()
	var row := Row.new()
	row.name = node_name
	row.text = caption
	row.icon_art = icon
	row.position = ROW_ORIGIN + Vector2(0, ROW_STEP * index)
	row.size = ROW_SIZE
	row.button_down.connect(row.flash)
	row.pressed.connect(select.bind(index))
	row.pressed.connect(row.flash)
	row.pressed.connect(action)
	buttons.append(row)
	add_child(row)


func _play_intro(thread: Control) -> void:
	var curtain := ColorRect.new()
	curtain.size = size
	curtain.color = INK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	pointer.modulate.a = 0.0
	_hints.modulate.a = 0.0
	var intro := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro.tween_property(curtain, "modulate:a", 0.0, 0.32)
	intro.tween_method(func(progress: float) -> void:
		_thread_progress = progress
		thread.queue_redraw(), 0.0, 1.0, 0.40).set_delay(0.15)
	for i in buttons.size():
		var row := buttons[i] as Row
		intro.tween_property(row, "entrance", 1.0, 0.205).set_delay(0.15 + i * 0.065)
		intro.tween_property(row, "accent", 1.0, 0.30).set_delay(0.50)
	intro.tween_property(pointer, "modulate:a", 1.0, 0.30).set_delay(0.50)
	intro.tween_property(_hints, "modulate:a", 1.0, 0.30).set_delay(0.50)
	intro.chain().tween_callback(curtain.queue_free)


func _draw_scrim(layer: Control) -> void:
	# Matching strips at either edge keep the river visible through the falloff.
	var bounds := Rect2(1072, 448, 480, 364)
	for column in 12:
		var offset := column * 6
		var alpha := 0.73 * smoothstep(0.0, 12.0, column + 1)
		_draw_scrim_column(layer, bounds.position + Vector2(offset, 0), 6, bounds.size.y, alpha)
		_draw_scrim_column(layer, Vector2(bounds.end.x - offset - 6, bounds.position.y), 6, bounds.size.y, alpha)
	_draw_scrim_column(layer, bounds.position + Vector2(72, 0), bounds.size.x - 144, bounds.size.y, 0.73)


func _draw_scrim_column(layer: Control, origin: Vector2, width: float, height: float, alpha: float) -> void:
	const SHADE := Color("191526")
	for row in 5:
		var fade := (float(row) + 1.0) / 6.0
		layer.draw_rect(Rect2(origin + Vector2(0, row * 5), Vector2(width, 5)), Color(SHADE, alpha * fade))
		layer.draw_rect(Rect2(origin + Vector2(0, height - 5 - row * 5), Vector2(width, 5)), Color(SHADE, alpha * fade))
	layer.draw_rect(Rect2(origin + Vector2(0, 25), Vector2(width, height - 50)), Color(SHADE, alpha))


func _draw_thread(layer: Control) -> void:
	if _thread_progress <= 0.0:
		return
	var top := Vector2(1117, 470)
	var length := roundf(320.0 * _thread_progress)
	layer.draw_rect(Rect2(top, Vector2(2, length)), Color(MINT, 0.45))
	layer.draw_rect(Rect2(top, Vector2(2, minf(length, 51))), Color(GOLD, 0.53))
	_draw_diamond(layer, top, Color(GOLD, 0.9))
	if _thread_progress > 0.88:
		_draw_diamond(layer, top + Vector2(0, 320), Color(MINT, 0.8 * smoothstep(0.88, 1.0, _thread_progress)))


func _draw_diamond(layer: Control, center: Vector2, tint: Color) -> void:
	layer.draw_rect(Rect2(center - Vector2(0, 5), Vector2(2, 12)), tint)
	layer.draw_rect(Rect2(center - Vector2(3, 2), Vector2(8, 6)), tint)
	layer.draw_rect(Rect2(center, Vector2(2, 2)), Color("fff8dc", tint.a))


class Row extends Button:
	const IDLE := Color("e4dac2")
	const LIT := Color("fff8dc")
	const DISABLED := Color("8d96b2")
	const SOUL := Color("46f2e2")

	var selected := false
	var icon_art: Texture2D
	var entrance := 0.0:
		set(value):
			entrance = value
			queue_redraw()
	var accent := 0.0:
		set(value):
			accent = value
			queue_redraw()
	var _focus := 0.0
	var _sweep := 1.0
	var _press := 0.0
	var _selection_tween: Tween
	var _press_tween: Tween
	var _lettering: FontVariation

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var blank := StyleBoxEmpty.new()
		for type in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(type, blank)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
			add_theme_color_override(color_name, Color.TRANSPARENT)
		_lettering = FontVariation.new()
		_lettering.base_font = get_theme_font("font")
		_lettering.spacing_glyph = 2

	func set_selected(value: bool, animate: bool = true) -> void:
		selected = value
		if _selection_tween:
			_selection_tween.kill()
		_sweep = 0.0 if value and animate else 1.0
		var target := 1.0 if value else 0.0
		if not animate:
			_focus = target
			queue_redraw()
			return
		_selection_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_selection_tween.tween_method(_set_focus, _focus, target, 0.13)
		if value:
			_selection_tween.tween_method(_set_sweep, 0.0, 1.0, 0.14).set_trans(Tween.TRANS_LINEAR)

	func flash() -> void:
		if _press_tween:
			_press_tween.kill()
		_set_press(1.0)
		_press_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_press_tween.tween_method(_set_press, 1.0, 0.0, 0.13)

	func _set_focus(value: float) -> void:
		_focus = value
		queue_redraw()

	func _set_sweep(value: float) -> void:
		_sweep = value
		queue_redraw()

	func _set_press(value: float) -> void:
		_press = value
		queue_redraw()

	func _draw() -> void:
		if _lettering == null or entrance <= 0.0:
			return
		var strength := 0.0 if disabled else _focus
		var entrance_x := roundf(26.0 * (1.0 - entrance))
		_draw_highlight(entrance_x, strength * accent * entrance)
		var press_y := roundf(2.0 * maxf(_press, float(is_pressed())))
		var content := Vector2(entrance_x + roundf(14.0 * strength), press_y)
		var icon_offset := -roundf(3.0 * sin(PI * strength))
		var icon_tint := Color("a0b8b5").lerp(Color.WHITE, strength) if not disabled else Color("82869c")
		var text_tint := IDLE.lerp(LIT, strength).lerp(Color.WHITE, _press * 0.75) if not disabled else DISABLED
		draw_texture_rect(icon_art, Rect2(content + Vector2(19, 16 + icon_offset), Vector2(32, 32)), false, Color(icon_tint, entrance * (0.56 if disabled else 1.0)))
		var baseline := content + Vector2(67, 40)
		draw_string(_lettering, baseline + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(INK, entrance * 0.95))
		draw_string(_lettering, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(text_tint, entrance))
		if disabled:
			draw_string(_lettering, Vector2(218 + entrance_x, 35), "无存档", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.MUTED, entrance * 0.8))

	func _draw_highlight(x: float, alpha: float) -> void:
		if alpha <= 0.0:
			return
		for strip in 23:
			var fade := pow(1.0 - float(strip) / 23.0, 1.7)
			var left := x + strip * 16
			draw_rect(Rect2(left, 3, 16, 58), Color(Color("ff9d3b"), alpha * fade * 0.34))
			draw_rect(Rect2(left, 3, 16, 1), Color(GOLD, alpha * fade * 0.82))
			draw_rect(Rect2(left, 60, 16, 1), Color(GOLD, alpha * fade * 0.25))
		draw_rect(Rect2(x, 4, 4, 56), Color(SOUL, alpha * 0.76))
		draw_rect(Rect2(x, 4, 4, 10), Color(GOLD, alpha))
		if _sweep < 1.0:
			var sweep_x := x + floorf(_sweep * 348.0)
			var glow := alpha * sin(_sweep * PI)
			draw_rect(Rect2(sweep_x, 4, 14, 56), Color(GOLD, glow * 0.16))
			draw_rect(Rect2(sweep_x + 14, 4, 2, 56), Color(LIT, glow * 0.32))


class Pointer extends Control:
	var _offset := 0.0
	var _time := 0.0
	var _follow_tween: Tween

	func follow(y: float) -> void:
		if _follow_tween:
			_follow_tween.kill()
		_offset += position.y - y
		position.y = y
		_follow_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_follow_tween.tween_property(self, "_offset", 0.0, 0.14)

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_time += delta
			queue_redraw()

	func _draw() -> void:
		const HOOK := ["  ### ", "  # # ", "  ### ", "   #  ", "   #  ", "#  #  ", "#  #  ", " ##   "]
		var origin := Vector2(-7 + roundf(sin(_time * 3.4) * 3.0), 24 + roundf(_offset))
		var glimmer := 0.76 + 0.24 * sin(_time * 3.4)
		for y in HOOK.size():
			for x in HOOK[y].length():
				if HOOK[y][x] == "#":
					var dot := origin + Vector2(x, y) * 2.0
					draw_rect(Rect2(dot + Vector2(1, 2), Vector2(2, 2)), INK)
					draw_rect(Rect2(dot, Vector2(2, 2)), Color(GOLD.lerp(MINT, float(y) / 13.0), glimmer))
