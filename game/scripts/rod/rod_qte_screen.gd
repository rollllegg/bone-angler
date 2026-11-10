extends Control
## Prototype workbench. The rod and timing track use Godot's own vector drawing.

const CREAM := Color("f3e6c6")
const MINT := Color("8fdbbd")
const GOLD := Color("f1c76c")
const CORAL := Color("f39a8c")
const MUTED := Color("829b9f")
const INK := Color("0b1b24")
const TRACK := Rect2(100, 510, 1080, 18)
const RESULT_TEXT := ["待判定", "成功", "完美 −1 秒", "失败 +1 秒"]

@onready var qte: RodQTE = $RodQTE

var _layout: Control
var _assemble: Button
var _disassemble: Button
var _action: Button
var _status: Label
var _instruction: Label
var _feedback: Label
var _time: Label
var _formula: Label
var _track_hint: Label
var _joint_labels: Array[Label] = []
var _mode: RodQTE.Mode = RodQTE.Mode.ASSEMBLE
var _feedback_remaining: float = 0.0
var _connection_amount: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	_build_interface()
	qte.state_changed.connect(_refresh)
	qte.checkpoint_judged.connect(_on_judged)
	qte.operation_completed.connect(_on_completed)
	resized.connect(_resize_layout)
	_resize_layout()
	_select_mode(RodQTE.Mode.ASSEMBLE)


func _build_interface() -> void:
	_layout = Control.new()
	_layout.name = "Layout"
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	_label("骨灰级钓手   /   骨质钓组工作台", Rect2(56, 28, 700, 28), 15, MINT)
	_label("每一节，都接稳。", Rect2(56, 70, 800, 58), 40, CREAM)
	_label("盯住游标，在绿色区域按 Shift；命中金色中心，回收再快一秒。", Rect2(58, 134, 1100, 30), 17, MUTED)
	_assemble = _button("组装鱼竿", Rect2(56, 181, 136, 40), func() -> void: _select_mode(RodQTE.Mode.ASSEMBLE))
	_assemble.name = "Assemble"
	_disassemble = _button("拆解鱼竿", Rect2(202, 181, 136, 40), func() -> void: _select_mode(RodQTE.Mode.DISASSEMBLE))
	_disassemble.name = "Disassemble"
	_label("三处连接 · 一次扫条 · 每点判定一次", Rect2(362, 186, 610, 30), 16, MUTED)
	_label("预计回收", Rect2(1000, 167, 96, 24), 14, MUTED)
	_time = _label("3.0 秒", Rect2(1090, 161, 134, 36), 28, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	_formula = _label("3 − 0 完美 + 0 失败", Rect2(950, 201, 274, 24), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("灵魂丝为固定配件", Rect2(80, 252, 330, 24), 13, MUTED)
	_feedback = _label("", Rect2(420, 250, 780, 30), 17, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	for index in 3:
		var center: float = TRACK.position.x + TRACK.size.x * RodQTE.CHECKPOINTS[index]
		var label := _label("", Rect2(center - 180, 548, 360, 28), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_joint_labels.append(label)
	_label("判定轨道", Rect2(80, 471, 400, 24), 13, MUTED)
	_track_hint = _label("绿色：成功    金色：完美", Rect2(680, 471, 520, 24), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("SHIFT", Rect2(58, 617, 78, 38), 17, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_status = _label("", Rect2(158, 602, 840, 38), 26, CREAM)
	_instruction = _label("", Rect2(158, 648, 840, 27), 15, MUTED)
	_action = _button("开始组装", Rect2(1014, 611, 210, 58), _start)
	_action.name = "Start"
	_label("正常成功不改变时间；提前按下或漏按 +1 秒。长按只判定一次。", Rect2(58, 689, 1150, 22), 12, MUTED)


func _resize_layout() -> void:
	_layout.scale = size / Vector2(1280, 720)
	queue_redraw()


func _process(delta: float) -> void:
	_feedback_remaining = maxf(_feedback_remaining - delta, 0.0)
	if _feedback_remaining <= 0.0:
		_feedback.text = ""
	for joint in 3:
		var amount := 0.0 if _mode == RodQTE.Mode.ASSEMBLE else 1.0
		for index in 3:
			if qte.get_joint_index(index) == joint and qte.results[index] in [RodQTE.Result.GOOD, RodQTE.Result.PERFECT]:
				amount = 1.0 - amount
		# Failed connections are finished during recovery; their cost is time.
		if qte.phase in [RodQTE.Phase.RECOVERY, RodQTE.Phase.COMPLETE]:
			amount = 1.0 if _mode == RodQTE.Mode.ASSEMBLE else 0.0
		_connection_amount[joint] = move_toward(_connection_amount[joint], amount, delta * 4.0)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if key.keycode != KEY_SHIFT and key.physical_keycode != KEY_SHIFT:
		return
	if qte.phase in [RodQTE.Phase.IDLE, RodQTE.Phase.COMPLETE]:
		_start()
	elif qte.phase == RodQTE.Phase.SWEEP:
		qte.submit()
	get_viewport().set_input_as_handled()


func _select_mode(next_mode: RodQTE.Mode) -> void:
	if qte.phase in [RodQTE.Phase.SWEEP, RodQTE.Phase.RECOVERY]:
		return
	_mode = next_mode
	_feedback_remaining = 0.0
	_feedback.text = ""
	_connection_amount.fill(0.0 if _mode == RodQTE.Mode.ASSEMBLE else 1.0)
	qte.reset(_mode)


func _start() -> void:
	if qte.phase in [RodQTE.Phase.SWEEP, RodQTE.Phase.RECOVERY]:
		return
	_connection_amount.fill(0.0 if _mode == RodQTE.Mode.ASSEMBLE else 1.0)
	_feedback.text = ""
	_feedback_remaining = 0.0
	qte.start(_mode)


func _refresh() -> void:
	var busy := qte.phase in [RodQTE.Phase.SWEEP, RodQTE.Phase.RECOVERY]
	_assemble.disabled = busy
	_disassemble.disabled = busy
	_style_button(_assemble, _mode == RodQTE.Mode.ASSEMBLE)
	_style_button(_disassemble, _mode == RodQTE.Mode.DISASSEMBLE)
	_action.disabled = busy
	var verb := "组装" if _mode == RodQTE.Mode.ASSEMBLE else "拆解"
	_time.text = "%.1f 秒" % (qte.recovery_remaining if qte.phase == RodQTE.Phase.RECOVERY else qte.get_recovery_total())
	_time.add_theme_color_override("font_color", GOLD if qte.perfect_count > qte.miss_count else CREAM)
	_formula.text = "3 − %d 完美 + %d 失败" % [qte.perfect_count, qte.miss_count]
	for index in 3:
		var result := qte.results[index]
		_joint_labels[index].text = "%02d  %s · %s" % [index + 1, qte.get_joint_name(index), RESULT_TEXT[result]]
		_joint_labels[index].add_theme_color_override("font_color", _result_color(result))
	match qte.phase:
		RodQTE.Phase.IDLE:
			_status.text = "准备%s鱼竿" % verb
			_instruction.text = "按 Shift 或点击开始。游标从左向右，依次完成三处连接。"
			_action.text = "开始" + verb
		RodQTE.Phase.SWEEP:
			_status.text = "%02d / 03   %s" % [qte.current_index + 1, qte.get_joint_name(qte.current_index)]
			_instruction.text = "进入绿色区域按 Shift，金色中心为完美。"
			_action.text = "判定中…"
		RodQTE.Phase.RECOVERY:
			_status.text = "回收中 · %.1f 秒" % qte.recovery_remaining
			_instruction.text = "完美 %d 次，成功 %d 次，失败 %d 次。回收结束后完成%s。" % [qte.perfect_count, qte.good_count, qte.miss_count, verb]
			_action.text = "回收中…"
		RodQTE.Phase.COMPLETE:
			_status.text = "%s完成%s" % [verb, " · 零秒回收！" if qte.recovery_duration <= 0.0 else ""]
			_instruction.text = "完美 %d 次 · 成功 %d 次 · 失败 %d 次 · 本次回收 %.1f 秒" % [qte.perfect_count, qte.good_count, qte.miss_count, qte.recovery_duration]
			_action.text = "再练一次"
	_track_hint.text = "绿色：成功    金色：完美" if qte.phase != RodQTE.Phase.RECOVERY else "等待回收结束，即可完成操作"
	queue_redraw()


func _on_judged(index: int, result: int) -> void:
	_feedback_remaining = 1.2
	_feedback.text = "%s   %s" % [qte.get_joint_name(index), RESULT_TEXT[result]]
	_feedback.add_theme_color_override("font_color", _result_color(result))


func _on_completed(_completed_mode: int, _summary: Dictionary) -> void:
	_refresh()


func _draw() -> void:
	if not is_instance_valid(qte):
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	draw_rect(Rect2(0, 0, 1280, 720), INK)
	draw_circle(Vector2(1120, 335), 260, Color("10272e"))
	_panel(Rect2(56, 238, 1168, 204), Color("10272f"), Color("29434a"), 16)
	for x in range(80, 1220, 32):
		draw_line(Vector2(x, 286), Vector2(x, 423), Color(0.3, 0.5, 0.5, 0.06), 1.0)
	_draw_rod()
	_panel(Rect2(56, 458, 1168, 128), Color("0d222b"), Color("29434a"), 14)
	_draw_track()
	_panel(Rect2(58, 617, 78, 38), Color("1a343d"), Color("52676b"), 6)
	draw_set_transform(Vector2.ZERO)


func _draw_rod() -> void:
	# Each detached joint adds a visible gap to the downstream component.
	var body_gap := (1.0 - _connection_amount[0]) * 30.0
	var line_gap := (1.0 - _connection_amount[1]) * 26.0
	var hook_gap := (1.0 - _connection_amount[2]) * 24.0
	var root_point := Vector2(160, 350)
	var body_start := Vector2(300 + body_gap, 350)
	var tip := Vector2(750 + body_gap, 322)
	var line_start := tip + Vector2(line_gap, -line_gap * 0.4)
	var line_end := Vector2(1038 + line_gap, 334)
	var hook_eye := line_end + Vector2(hook_gap, 0)
	# Spine grip.
	draw_line(root_point, Vector2(300, 350), CREAM.darkened(0.45), 14, true)
	for index in 7:
		var center := root_point + Vector2(index * 20, 0)
		draw_style_box(_style(CREAM.darkened(0.18), CREAM, 5), Rect2(center - Vector2(6, 13), Vector2(13, 26)))
	# Arm-bone rod, with rounded joints and a tapered silhouette.
	draw_line(body_start, tip, CREAM.darkened(0.4), 11, true)
	draw_line(body_start + Vector2(0, -3), tip + Vector2(0, -2), CREAM, 4, true)
	for index in 5:
		var point := body_start.lerp(tip, index / 4.0)
		draw_circle(point, 7.0 - index * 0.7, CREAM.darkened(0.08))
		draw_circle(point + Vector2(-2, -2), 2.0, Color("fff4d8"))
	# Soul thread and rib-bone hook, with a small finger-bone lure in its bend.
	var thread := PackedVector2Array([line_start, line_start.lerp(line_end, 0.32) + Vector2(0, 28), line_start.lerp(line_end, 0.68) + Vector2(0, 28), line_end])
	draw_polyline(thread, Color(0.56, 0.86, 0.74, 0.10), 9, true)
	draw_polyline(thread, MINT, 2, true)
	draw_arc(hook_eye, 5, 0, TAU, 24, CREAM, 2, true)
	draw_line(hook_eye + Vector2(0, 5), hook_eye + Vector2(0, 35), CREAM, 5, true)
	draw_arc(hook_eye + Vector2(-17, 35), 17, 0, PI, 24, CREAM, 5, true)
	draw_line(hook_eye + Vector2(-34, 35), hook_eye + Vector2(-30, 19), CREAM, 4, true)
	draw_colored_polygon(PackedVector2Array([hook_eye + Vector2(-30, 17), hook_eye + Vector2(-25, 28), hook_eye + Vector2(-35, 25)]), CREAM)
	draw_line(hook_eye + Vector2(-17, 43), hook_eye + Vector2(-10, 34), GOLD, 5, true)
	for index in 3:
		var point := [Vector2(302, 350), tip, line_end][index] as Vector2
		var active := qte.phase == RodQTE.Phase.SWEEP and qte.get_joint_index(qte.current_index) == index
		draw_arc(point, 18 if active else 12, 0, TAU, 36, GOLD if active else Color("3f6266"), 2, true)
	var font := get_theme_font("font")
	for entry in [["骨节握把", 167], ["手臂骨竿体", 480], ["灵魂丝鱼线", 825], ["骨钩与拟饵", 1050]]:
		draw_string(font, Vector2(entry[1], 411), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)


func _draw_track() -> void:
	_panel(TRACK, Color("1e363f"), Color("304b53"), 5)
	if qte.phase == RodQTE.Phase.RECOVERY:
		var ratio := 1.0 - qte.recovery_remaining / maxf(qte.recovery_duration, 0.001)
		_panel(Rect2(TRACK.position, Vector2(TRACK.size.x * ratio, TRACK.size.y)), MINT.darkened(0.35), Color.TRANSPARENT, 5)
	for index in 3:
		var center: float = TRACK.position.x + TRACK.size.x * RodQTE.CHECKPOINTS[index]
		var half := TRACK.size.x * qte.get_success_half_width()
		var perfect_half := TRACK.size.x * qte.get_perfect_half_width()
		var result := qte.results[index]
		var active := qte.phase == RodQTE.Phase.SWEEP and index == qte.current_index
		var green := Color("49927b") if result == RodQTE.Result.PENDING else _result_color(result).darkened(0.6)
		if qte.phase != RodQTE.Phase.RECOVERY:
			draw_rect(Rect2(center - half, TRACK.position.y, half * 2, TRACK.size.y), green)
			draw_rect(Rect2(center - perfect_half, TRACK.position.y, perfect_half * 2, TRACK.size.y), GOLD if result == RodQTE.Result.PENDING else _result_color(result))
		if active:
			draw_rect(Rect2(center - half - 3, TRACK.position.y - 4, half * 2 + 6, TRACK.size.y + 8), CREAM, false, 1)
		if result != RodQTE.Result.PENDING:
			draw_circle(Vector2(center, 536), 3, _result_color(result))
	if qte.phase in [RodQTE.Phase.IDLE, RodQTE.Phase.SWEEP]:
		var cursor_x := TRACK.position.x + qte.get_progress() * TRACK.size.x
		draw_line(Vector2(cursor_x, 502), Vector2(cursor_x, 534), CREAM, 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(cursor_x - 6, 497), Vector2(cursor_x + 6, 497), Vector2(cursor_x, 504)]), CREAM)


func _result_color(result: int) -> Color:
	return [MUTED, MINT, GOLD, CORAL][result]


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
	button.add_theme_stylebox_override("normal", _style(Color("25463f") if selected else Color("162e37"), MINT if selected else Color("38535c"), 8))
	button.add_theme_stylebox_override("hover", _style(Color("284b46"), MINT, 8))
	button.add_theme_stylebox_override("pressed", _style(Color("335e51"), MINT, 8))
	button.add_theme_stylebox_override("disabled", _style(Color("1b3238"), Color("304b4d"), 8))
	button.add_theme_color_override("font_color", MINT if selected else CREAM)
	button.add_theme_color_override("font_disabled_color", MINT.darkened(0.3) if selected else MUTED)


func _panel(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	draw_style_box(_style(fill, border, radius), rect)


func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
