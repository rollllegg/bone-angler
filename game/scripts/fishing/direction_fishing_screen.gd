extends Control
## A self-contained playable river vignette, drawn with native Godot vectors.

signal pause_requested

const INK := Color("0b1b24")
const CREAM := Color("f3e6c6")
const MINT := Color("91ddc5")
const MUTED := Color("839da3")
const CORAL := Color("f2a38e")
const GOLD := Color("e8bd83")
const WATER := Rect2(48, 126, 788, 428)
const TIMING_FRAME := Rect2(370, 188, 300, 280)

@onready var qte: DirectionFishing = $DirectionFishing

var _layout: Control
var _discovered_fish: Array[Label] = []
var _fish_attributes: Array[Label] = []
var session: SoulSession
var _cast: Button
var _pause: Button
var _status: Label
var _instruction: Label
var _prompt: Label
var _prompt_note: Label
var _progress: Label
var _mistakes: Label
var _collection: Label
var _hit_label: Label
var _hit_life: float = 0.0
var _last_phase: int = -1
var _clock: float = 0.0
var _fish_position := Vector2(539, 344)
var _line_position := TIMING_FRAME.get_center()
var _rod_tension := Vector2.ZERO
var _pulse: float = 0.0


func _ready() -> void:
	_build_interface()
	qte.state_changed.connect(_refresh)
	qte.pull_judged.connect(_on_judged)
	resized.connect(_resize_layout)
	_resize_layout()
	_refresh()


func bind_session(value: SoulSession) -> void:
	session = value
	session.state_changed.connect(_refresh)
	_refresh()


func _build_interface() -> void:
	_layout = Control.new()
	_layout.name = "Layout"
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	_label("骨灰级钓手  /  阿刻戎河", Rect2(48, 23, 500, 24), 14, MINT)
	_label("逆流而上", Rect2(46, 56, 320, 52), 38, CREAM)
	_label("节奏拉鱼 · 玩法演示", Rect2(272, 76, 410, 24), 15, MUTED)
	_label("01  /  冥河钓点", Rect2(72, 145, 370, 24), 13, MINT)
	_prompt = _label("", Rect2(510, 424, 300, 43), 29, MINT, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_note = _label("", Rect2(492, 472, 320, 25), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_label = _label("", Rect2(0, 0, 144, 30), 19, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label("本次钓况", Rect2(880, 141, 308, 32), 21, CREAM)
	_label("鱼藏在水下，钓起后揭晓", Rect2(880, 178, 308, 24), 14, MUTED)
	for index in 3:
		_discovered_fish.append(_label("", Rect2(898, 224 + index * 62, 280, 27), 17, MUTED))
		for attribute in 3:
			_fish_attributes.append(_label("", Rect2(898 + attribute * 94, 251 + index * 62, 94, 17), 11, SoulSession.ATTRIBUTE_COLORS[attribute]))
	_progress = _label("", Rect2(880, 422, 308, 32), 23, CREAM)
	_mistakes = _label("", Rect2(880, 469, 308, 24), 14, MUTED)
	_collection = _label("", Rect2(880, 510, 308, 22), 13, MINT)
	_status = _label("", Rect2(76, 585, 780, 34), 24, CREAM)
	_instruction = _label("", Rect2(76, 629, 780, 25), 14, MUTED)
	_cast = _button("抛竿 · 空格", Rect2(986, 593, 202, 58), _cast_line)
	_cast.name = "Cast"
	_pause = _button("暂停 · P", Rect2(880, 593, 96, 58), _toggle_pause)
	_pause.name = "Pause"
	_pause.add_theme_font_size_override("font_size", 14)


func _resize_layout() -> void:
	_layout.scale = size / Vector2(1280, 720)
	queue_redraw()


func _process(delta: float) -> void:
	if not qte.paused:
		_clock += delta
	if not qte.paused:
		_pulse = maxf(_pulse - delta * 2.7, 0.0)
		_hit_life = maxf(_hit_life - delta, 0.0)
		if _hit_life <= 0.0:
			_hit_label.text = ""
		var tension := Vector2.ZERO
		var line_target := TIMING_FRAME.get_center() + Vector2(0, sin(_clock * 2.1) * 3)
		if qte.phase == DirectionFishing.Phase.REELING:
			tension = DirectionFishing.VECTORS[qte.fish_direction] * qte.get_travel_ratio()
			line_target = get_water_entry()
		elif qte.phase == DirectionFishing.Phase.FEEDBACK:
			tension = DirectionFishing.VECTORS[qte.fish_direction] * qte.get_travel_ratio() * _pulse
			line_target = TIMING_FRAME.get_center().lerp(get_water_entry(), _pulse)
		elif qte.phase == DirectionFishing.Phase.CAUGHT:
			line_target = Vector2(517, 325)
		var smoothing := 1.0 - exp(-delta * 8.0)
		_rod_tension = _rod_tension.lerp(tension, smoothing)
		_line_position = line_target if qte.phase == DirectionFishing.Phase.REELING else _line_position.lerp(line_target, smoothing)
		_fish_position = _fish_position.lerp(Vector2(539, 326 + sin(_clock * 2.1) * 5), smoothing)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(qte) and qte.is_busy():
		qte.set_paused(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code == KEY_SPACE:
		if qte.paused:
			qte.set_paused(false)
		else:
			_cast_line()
	elif code == KEY_P:
		_toggle_pause()
	elif code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		qte.submit_key(OS.get_keycode_string(code))
	else:
		return
	get_viewport().set_input_as_handled()


func _cast_line() -> void:
	if session != null and session.paused:
		pause_requested.emit()
		return
	if qte.cast():
		_pulse = 0.0


func _toggle_pause() -> void:
	if session != null:
		pause_requested.emit()
	else:
		qte.set_paused(not qte.paused)


func _refresh() -> void:
	if not is_instance_valid(_prompt):
		return
	var busy := qte.is_busy()
	if qte.phase == DirectionFishing.Phase.REELING and _last_phase != qte.phase:
		_pulse = 0.0
		_hit_label.text = ""
	_last_phase = qte.phase
	for index in 3:
		var discovered := qte.caught_counts[index] > 0
		var available: int = session.inventory[index] if session != null else qte.caught_counts[index]
		_discovered_fish[index].text = "%s    %s" % [DirectionFishing.FISH[index]["name"] if discovered else "未知鱼种", "%d 条" % available if discovered else "未发现"]
		_discovered_fish[index].add_theme_color_override("font_color", CREAM if discovered else MUTED)
		var bonus: Vector3i = DirectionFishing.FISH[index]["stats"]
		for attribute in 3:
			_fish_attributes[index * 3 + attribute].text = "%s +%d" % [SoulSession.ATTRIBUTE_NAMES[attribute], bonus[attribute]] if discovered else ""
	_progress.text = "拉回进度    %d 点" % qte.successful_pulls
	_mistakes.text = "完美 %d 次    ·    失误 %d / %d" % [qte.perfect_count, qte.mistakes, qte.mistake_limit]
	_collection.text = "鱼篓    %d 条" % (session.get_inventory_total() if session != null else qte.get_total_caught())
	var paused := session.paused if session != null else qte.paused
	_cast.disabled = busy and not paused
	_pause.disabled = not busy and session == null
	_pause.text = "继续 · P" if paused else "暂停 · P"
	_cast.text = "继续 · 空格" if paused else ("拉鱼中…" if busy else "再抛一竿 · 空格")
	_prompt.text = ""
	_prompt_note.text = ""
	_status.text = ""
	_instruction.text = ""
	match qte.phase:
		DirectionFishing.Phase.READY:
			_status.text = "冥河很静。"
			_instruction.text = "按空格抛竿。"
			_cast.text = "抛竿 · 空格"
		DirectionFishing.Phase.WAITING:
			_status.text = "候鱼中…"
		DirectionFishing.Phase.CAUGHT:
			_prompt.text = "钓到了！"
			_progress.text = "拉回完成    %d / %d" % [qte.successful_pulls, qte.get_required_pulls()]
			_status.text = "%s，收入鱼篓。" % DirectionFishing.FISH[qte.fish_index]["name"]
			_instruction.text = "%d 次拉鱼 · %d 次完美    空格再抛一竿。" % [qte.successful_inputs, qte.perfect_count]
		DirectionFishing.Phase.ESCAPED:
			_prompt.text = "鱼脱钩了。"
			_status.text = "这次溜走了，再试一次。"
			_instruction.text = "按空格重新抛竿。"
	if paused:
		_prompt.text = "已暂停"
		_prompt_note.text = "按 P、空格或点击继续，回到当前这一步。"
		_status.text = "慢慢来，鱼也在等你。"
		_instruction.text = "节奏已暂停。"
	queue_redraw()


func _on_judged(_success: bool, _message: String) -> void:
	_pulse = 1.0
	_hit_life = 0.55
	_line_position = get_water_entry()
	_hit_label.position = _line_position + Vector2(-72, 19)
	_hit_label.text = "完美 +%d" % qte.last_progress_gain if qte.last_judgement == DirectionFishing.Judgement.PERFECT else ("+%d" % qte.last_progress_gain if qte.last_success else "×")
	_hit_label.add_theme_color_override("font_color", GOLD if qte.last_judgement == DirectionFishing.Judgement.PERFECT else (MINT if qte.last_success else CORAL))


func _draw() -> void:
	if not is_instance_valid(qte):
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	draw_rect(Rect2(0, 0, 1280, 720), INK)
	_panel(WATER, Color("102e38"), Color("30505a"), 18)
	_draw_river()
	_panel(Rect2(856, 126, 376, 428), Color("10252e"), Color("29434a"), 18)
	for index in 3:
		_panel(Rect2(880, 220 + index * 62, 308, 50), Color("142d36"), Color("2d4750"), 9)
	_panel(Rect2(48, 574, 1184, 98), Color("10252e"), Color("29434a"), 14)
	draw_set_transform(Vector2.ZERO)


func _draw_river() -> void:
	# Soft current lines, distant reeds, and little drifting soul lights.
	for row in 9:
		var y := 224.0 + row * 22.0
		for segment in 5:
			var x := 78.0 + segment * 153.0 + sin(_clock * 0.5 + row) * 12.0
			draw_line(Vector2(x, y), Vector2(x + 45 + row * 3, y), Color(0.38, 0.68, 0.68, 0.07 + row * 0.005), 1.5, true)
	for index in 14:
		var point := Vector2(91 + fmod(index * 73.0 + _clock * 5.0, 690.0), 248 + sin(index * 2.7 + _clock) * 51 + index * 8)
		draw_circle(point, 1.5 if index % 3 else 2.5, Color(0.6, 0.9, 0.8, 0.20))
	draw_arc(Vector2(624, 303), 114, 0, TAU, 80, Color(0.4, 0.75, 0.7, 0.045), 30, true)
	if qte.phase in [DirectionFishing.Phase.READY, DirectionFishing.Phase.WAITING, DirectionFishing.Phase.REELING, DirectionFishing.Phase.FEEDBACK]:
		_draw_timing_frame()
	_draw_rig()
	if is_fish_revealed():
		_draw_fish(_fish_position, DirectionFishing.FISH[qte.fish_index]["scale"], DirectionFishing.FISH[qte.fish_index]["color"], true)
	if is_pull_arrow_visible():
		_draw_arrow(Vector2(698, 442), get_pull_arrow_direction(), MINT, 44)


func get_water_entry() -> Vector2:
	return TIMING_FRAME.get_center() + DirectionFishing.VECTORS[qte.fish_direction] * TIMING_FRAME.size * 0.5 * qte.get_travel_ratio()


func _draw_timing_frame() -> void:
	var perfect := qte.is_perfect_timing() and not qte.paused
	var color := GOLD if perfect else Color("638589")
	var corners := [TIMING_FRAME.position, TIMING_FRAME.position + Vector2(TIMING_FRAME.size.x, 0), TIMING_FRAME.end, TIMING_FRAME.position + Vector2(0, TIMING_FRAME.size.y)]
	for index in 4:
		draw_dashed_line(corners[index], corners[(index + 1) % 4], color, 2.0, 10.0)
	if qte.phase == DirectionFishing.Phase.REELING:
		var direction: Vector2 = DirectionFishing.VECTORS[qte.fish_direction]
		var edge := TIMING_FRAME.get_center() + direction * TIMING_FRAME.size * 0.5
		var tangent := Vector2(-direction.y, direction.x)
		draw_line(edge - tangent * 24, edge + tangent * 24, GOLD if perfect else CREAM, 5.0 if perfect else 3.0, true)
		if perfect:
			draw_circle(get_water_entry(), 13, Color(0.95, 0.78, 0.42, 0.14))


func is_fish_revealed() -> bool:
	return qte.phase == DirectionFishing.Phase.CAUGHT


func is_pull_arrow_visible() -> bool:
	return qte.phase == DirectionFishing.Phase.REELING and not qte.paused


func get_pull_arrow_direction() -> Vector2:
	return DirectionFishing.VECTORS[qte.get_expected_direction()]


func _draw_rig() -> void:
	# The rod grows out of the bottom of the view. Its arched tip and line
	# both follow the hidden fish; no fish marker or movement arrow is drawn.
	var base := Vector2(397, 553)
	var tip := Vector2(468, 270) + _rod_tension * Vector2(69, 39)
	tip += Vector2(-_pulse * 7, -_pulse * 16) if qte.last_success else Vector2(_pulse * 9, _pulse * 7)
	var control_a := Vector2(421, 432) + Vector2(_rod_tension.x * 16, 0)
	var control_b := Vector2(423, 139) + _rod_tension * Vector2(56, 16)
	var points := PackedVector2Array()
	for index in 41:
		var t := index / 40.0
		var inverse := 1.0 - t
		points.append(inverse * inverse * inverse * base + 3.0 * inverse * inverse * t * control_a + 3.0 * inverse * t * t * control_b + t * t * t * tip)
	draw_polyline(points, CREAM.darkened(0.38), 7, true)
	draw_polyline(points, CREAM, 3, true)
	for index in [0, 8, 16, 24, 32, 40]:
		draw_circle(points[index], 4.0 - index * 0.055, CREAM)
	# Spine-bone grip, partially cropped by the lower edge of the water.
	for index in 4:
		var point := base.lerp(points[7], index / 7.0)
		draw_line(point + Vector2(-6, -1), point + Vector2(6, 1), CREAM.darkened(0.18), 5, true)
	# The visible water entry is evaluated from the same beat clock as the
	# judgement, never smoothed behind the actual hit window.
	var line_end := get_water_entry() if qte.phase == DirectionFishing.Phase.REELING else _line_position
	if is_fish_revealed():
		line_end = _fish_position - Vector2(54, 0) * float(DirectionFishing.FISH[qte.fish_index]["scale"])
	var line_points := PackedVector2Array()
	var slack := 34.0 if qte.phase in [DirectionFishing.Phase.READY, DirectionFishing.Phase.WAITING, DirectionFishing.Phase.ESCAPED] else 3.0
	for index in 21:
		var t := index / 20.0
		line_points.append(tip.lerp(line_end, t) + Vector2(0, sin(t * PI) * slack))
	var line_color := MINT.lightened(0.22)
	if _pulse > 0.0:
		line_color = line_color.lerp(MINT if qte.last_success else CORAL, _pulse)
	draw_polyline(line_points, line_color, 1.5 + _pulse, true)
	if not is_fish_revealed():
		if qte.phase == DirectionFishing.Phase.REELING:
			draw_circle(line_end, 4.5, CREAM)
		var ripple_radius := 15.0 + sin(_clock * 3.0) * 3.0
		draw_set_transform(line_end * (size / Vector2(1280, 720)), 0.0, size / Vector2(1280, 720) * Vector2(1.0, 0.38))
		draw_arc(Vector2.ZERO, ripple_radius, 0, TAU, 48, Color(0.6, 0.87, 0.8, 0.23), 1, true)
		draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
		if qte.phase in [DirectionFishing.Phase.READY, DirectionFishing.Phase.WAITING]:
			draw_line(line_end - Vector2(0, 7), line_end + Vector2(0, 4), CREAM, 2, true)
			draw_circle(line_end, 3, CORAL)


func _draw_fish(center: Vector2, fish_scale: float, color: Color, facing_left: bool) -> void:
	draw_set_transform(center * (size / Vector2(1280, 720)), 0.0, size / Vector2(1280, 720) * Vector2(-fish_scale if facing_left else fish_scale, fish_scale))
	draw_colored_polygon(PackedVector2Array([Vector2(-37, 0), Vector2(-73, -28), Vector2(-65, 0), Vector2(-73, 28)]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -22), Vector2(8, -45), Vector2(21, -21)]), color.darkened(0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 20), Vector2(14, 38), Vector2(25, 17)]), color.darkened(0.30))
	# Rounded silhouette and bone-like ribs make each fish read at a glance.
	var body := PackedVector2Array()
	for index in 49:
		var angle := index * TAU / 48.0
		body.append(Vector2(cos(angle) * 54, sin(angle) * 27))
	draw_colored_polygon(body, color.darkened(0.1))
	draw_line(Vector2(-39, 0), Vector2(18, 0), color.lightened(0.3), 2, true)
	for rib in 5:
		var x := -29.0 + rib * 10
		draw_polyline(PackedVector2Array([Vector2(x - 4, -15), Vector2(x + 3, 0), Vector2(x - 4, 15)]), color.lightened(0.28), 2, true)
	draw_arc(Vector2(23, 0), 15, -PI * 0.5, PI * 0.5, 24, color.darkened(0.35), 2, true)
	draw_circle(Vector2(34, -7), 6, INK)
	draw_circle(Vector2(36, -9), 2, CREAM)
	draw_line(Vector2(46, 8), Vector2(53, 7), INK, 2, true)
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))


func _draw_arrow(center: Vector2, direction: Vector2, color: Color, length: float) -> void:
	var end := center + direction * length * 0.5
	var perpendicular := Vector2(-direction.y, direction.x)
	draw_line(center - direction * length * 0.5, end, color, 5, true)
	draw_polyline(PackedVector2Array([end - direction * 14 + perpendicular * 12, end, end - direction * 14 - perpendicular * 12]), color, 5, true)


func _label(text: String, rect: Rect2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_layout.add_child(label)
	return label


func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	_style_button(button, false)
	button.pressed.connect(callback)
	_layout.add_child(button)
	return button


func _style_button(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", _style(Color("25463f") if selected else Color("162e37"), MINT if selected else Color("38535c"), 9))
	button.add_theme_stylebox_override("hover", _style(Color("284b46"), MINT, 9))
	button.add_theme_stylebox_override("pressed", _style(Color("335e51"), MINT, 9))
	button.add_theme_stylebox_override("disabled", _style(Color("1b3439") if selected else Color("112832"), Color("547e71") if selected else Color("263f49"), 9))
	button.add_theme_color_override("font_color", MINT if selected else CREAM)
	button.add_theme_color_override("font_disabled_color", MINT if selected else MUTED)


func _panel(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	draw_style_box(_style(fill, border, radius), rect)


func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
