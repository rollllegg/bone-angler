extends Control
## Admission desk: persistent soul IDs keep a new arrival from changing the
## target of a feed or release. The complete queue is paged, never truncated.

const INK := Color("0b1b24")
const CREAM := Color("f3e6c6")
const MINT := Color("91ddc5")
const MUTED := Color("839da3")
const GOLD := Color("efc875")
const PAGE_SIZE := 6

var session: SoulSession
var selected_id: int = -1
var page: int = 0
var _layout: Control
var _requirements: Array[Label] = []
var _queue_buttons: Array[Button] = []
var _feed_buttons: Array[Button] = []
var _fish_names: Array[Label] = []
var _attributes: Array[Label] = []
var _day_title: Label
var _reward_label: Label
var _day_clock: Label
var _arrival_clock: Label
var _queue_title: Label
var _page_label: Label
var _previous: Button
var _next: Button
var _soul_name: Label
var _soul_note: Label
var _status: Label
var _notice: Label
var _release: Button
var _inventory_title: Label
var _clock: float = 0.0
var _notice_remaining: float = 0.0
var _release_effect: float = 0.0


func _ready() -> void:
	_build_interface()
	resized.connect(_resize_layout)
	_resize_layout()


func bind_session(value: SoulSession) -> void:
	session = value
	session.state_changed.connect(_refresh)
	session.soul_fed.connect(_on_fed)
	session.soul_released.connect(_on_released)
	_refresh()


func _build_interface() -> void:
	_layout = Control.new()
	_layout.name = "Layout"
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	_label("骨灰级钓手  /  冥府值班室", Rect2(48, 23, 540, 24), 14, MINT)
	_label("让灵魂完整地离开。", Rect2(46, 57, 620, 52), 34, CREAM)
	_day_title = _label("", Rect2(72, 137, 280, 29), 20, CREAM)
	_day_clock = _label("", Rect2(72, 170, 290, 18), 12, MUTED)
	for index in 3:
		_requirements.append(_label("", Rect2(386 + index * 196, 145, 180, 32), 22, SoulSession.ATTRIBUTE_COLORS[index]))
	_reward_label = _label("", Rect2(1020, 145, 190, 32), 19, GOLD)
	_queue_title = _label("", Rect2(72, 226, 282, 30), 21, CREAM)
	_arrival_clock = _label("", Rect2(72, 259, 282, 20), 13, MUTED)
	for index in PAGE_SIZE:
		var button := _button("", Rect2(72, 293 + index * 46, 282, 38), func() -> void: _select_row(index))
		button.name = "SoulRow%d" % index
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		_queue_buttons.append(button)
	_previous = _button("上一页", Rect2(72, 602, 82, 30), func() -> void: _change_page(-1))
	_previous.add_theme_font_size_override("font_size", 13)
	_page_label = _label("", Rect2(154, 603, 118, 28), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_next = _button("下一页", Rect2(272, 602, 82, 30), func() -> void: _change_page(1))
	_next.add_theme_font_size_override("font_size", 13)
	_label("灵魂档案", Rect2(418, 226, 240, 27), 15, MINT)
	_soul_name = _label("", Rect2(418, 268, 288, 32), 22, CREAM)
	_soul_note = _label("", Rect2(418, 308, 288, 23), 13, MUTED)
	for index in 3:
		_attributes.append(_label("", Rect2(418, 350 + index * 57, 388, 28), 18, SoulSession.ATTRIBUTE_COLORS[index]))
	_status = _label("", Rect2(418, 529, 388, 25), 15, MUTED)
	_notice = _label("", Rect2(418, 559, 388, 25), 14, GOLD)
	_release = _button("等待灵魂", Rect2(418, 596, 390, 38), _release_selected)
	_release.name = "Release"
	_inventory_title = _label("", Rect2(872, 226, 336, 30), 21, CREAM)
	_label("先选灵魂，再选择一条鱼喂食", Rect2(872, 264, 336, 23), 14, MUTED)
	for fish_index in 3:
		var top := 307.0 + fish_index * 94
		_fish_names.append(_label("", Rect2(890, top + 5, 206, 28), 16, CREAM))
		var data: Dictionary = DirectionFishing.FISH[fish_index]
		var bonus: Vector3i = data["stats"]
		for attribute in 3:
			_label("%s +%d" % [SoulSession.ATTRIBUTE_NAMES[attribute], bonus[attribute]], Rect2(890 + attribute * 100, top + 42, 100, 22), 13, SoulSession.ATTRIBUTE_COLORS[attribute])
		var button := _button("喂食 · %d" % (fish_index + 1), Rect2(1096, top + 5, 96, 30), func() -> void: _feed(fish_index))
		button.add_theme_font_size_override("font_size", 14)
		button.name = "Feed%d" % fish_index
		_feed_buttons.append(button)
	_label("1 / 2 / 3 喂鱼    ·    空格放行", Rect2(872, 607, 336, 24), 13, MUTED)


func _resize_layout() -> void:
	_layout.scale = size / Vector2(1280, 720)
	queue_redraw()


func _process(delta: float) -> void:
	if session == null:
		return
	if not session.paused:
		_clock += delta
		_release_effect = maxf(_release_effect - delta * 1.5, 0.0)
		_notice_remaining = maxf(_notice_remaining - delta, 0.0)
	if _notice_remaining <= 0.0:
		_notice.text = ""
	_day_clock.text = "距下一天 %d 秒 · 每天重新审定标准" % ceili(session.day_remaining)
	_arrival_clock.text = "%.1f 秒后有新灵魂到来" % session.spawn_remaining
	if session.paused:
		_arrival_clock.text = "已暂停 · 按 P 或空格继续"
	queue_redraw()


func _refresh() -> void:
	if session == null:
		return
	var required := session.get_requirements()
	_day_title.text = "第 %d 天 · 今日入门标准" % session.day
	_reward_label.text = "放行  +%d 金币" % session.release_reward
	for index in 3:
		_requirements[index].text = "%s ≥ %d" % [SoulSession.ATTRIBUTE_NAMES[index], required[index]]
	_queue_title.text = "门前等候    %d 魂" % session.souls.size()
	var last_page := maxi(0, ceili(session.souls.size() / float(PAGE_SIZE)) - 1)
	page = clampi(page, 0, last_page)
	var selected := session.get_soul(selected_id)
	if selected.is_empty() and not session.souls.is_empty():
		selected_id = session.souls[mini(page * PAGE_SIZE, session.souls.size() - 1)]["id"]
		selected = session.get_soul(selected_id)
	if session.souls.is_empty():
		selected_id = -1
	_page_label.text = "%d / %d 页" % [page + 1, last_page + 1]
	_previous.disabled = page == 0
	_next.disabled = page == last_page
	for row in PAGE_SIZE:
		var index := page * PAGE_SIZE + row
		var button := _queue_buttons[row]
		button.visible = index < session.souls.size()
		if not button.visible:
			continue
		var soul: Dictionary = session.souls[index]
		var missing := session.get_missing(soul["id"])
		var deficient_count := int(missing.x > 0) + int(missing.y > 0) + int(missing.z > 0)
		button.text = "  #%03d %s · %s" % [soul["id"], soul["name"], "可放行" if deficient_count == 0 else "缺%d项" % deficient_count]
		_style_button(button, soul["id"] == selected_id)
	_soul_name.text = "等待来客" if selected.is_empty() else "#%03d  %s" % [selected["id"], selected["name"]]
	_soul_note.text = session.get_arrival_description() if selected.is_empty() else "到来时：第 %d 天" % selected["arrival_day"]
	for index in 3:
		if selected.is_empty():
			_attributes[index].text = "%s    — / %d" % [SoulSession.ATTRIBUTE_NAMES[index], required[index]]
		else:
			var stats: Vector3i = selected["stats"]
			var deficit := maxi(required[index] - stats[index], 0)
			_attributes[index].text = "%s    %d / %d     %s" % [SoulSession.ATTRIBUTE_NAMES[index], stats[index], required[index], "已达标" if deficit == 0 else "还缺 %d" % deficit]
	var ready := session.can_release(selected_id)
	_status.text = "三项都达标了，可以进入冥府。" if ready else "用鱼补全属性，再放行灵魂。"
	if selected.is_empty():
		_status.text = "可以先去冥河岸钓鱼。"
	_release.disabled = not ready or session.paused
	_release.text = "放行灵魂 · +%d 金币" % session.release_reward if ready else ("等待灵魂" if selected.is_empty() else "属性未达标")
	_inventory_title.text = "鱼篓    %d 条" % session.get_inventory_total()
	for index in 3:
		_fish_names[index].text = "%s  ×%d" % [DirectionFishing.FISH[index]["name"], session.inventory[index]]
		_feed_buttons[index].disabled = not session.can_feed(selected_id, index)
	queue_redraw()


func _select_row(row: int) -> void:
	var index := page * PAGE_SIZE + row
	if index >= session.souls.size():
		return
	selected_id = session.souls[index]["id"]
	_refresh()


func _change_page(amount: int) -> void:
	page += amount
	_refresh()


func _feed(fish_index: int) -> void:
	if session != null:
		session.feed_fish(selected_id, fish_index)


func _release_selected() -> void:
	if session != null:
		session.release_soul(selected_id)


func _on_fed(_soul_id: int, fish_index: int) -> void:
	_notice.text = "%s已喂食，属性已补充。" % DirectionFishing.FISH[fish_index]["name"]
	_notice_remaining = 2.0


func _on_released(_soul_id: int, reward: int) -> void:
	_notice.text = "+%d 金币 · 灵魂已进入冥府" % reward
	_notice_remaining = 2.5
	_release_effect = 1.0


func _unhandled_key_input(event: InputEvent) -> void:
	if session == null or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code in [KEY_1, KEY_2, KEY_3]:
		_feed(code - KEY_1)
	elif code == KEY_SPACE:
		_release_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	draw_rect(Rect2(0, 0, 1280, 720), INK)
	_panel(Rect2(48, 126, 1184, 68), Color("152d35"), Color("385459"), 14)
	for rect in [Rect2(48, 210, 330, 442), Rect2(394, 210, 438, 442), Rect2(848, 210, 384, 442)]:
		_panel(rect, Color("10252e"), Color("29434a"), 16)
	for index in 3:
		_panel(Rect2(872, 307 + index * 94, 336, 78), Color("162f38"), Color("314b54"), 10)
	if session != null:
		_draw_soul_desk()
	draw_set_transform(Vector2.ZERO)


func _draw_soul_desk() -> void:
	# A stone doorway and soul figure anchor the desk to the underworld scene.
	_panel(Rect2(723, 241, 70, 85), Color("09202a"), Color("466069"), 26)
	draw_line(Vector2(758, 257), Vector2(758, 320), Color("3e625e"), 2, true)
	draw_circle(Vector2(749, 288), 2, GOLD)
	var selected := session.get_soul(selected_id)
	if not selected.is_empty():
		_draw_ghost(Vector2(701, 289 + sin(_clock * 2) * 3), MINT, 1.0)
		var stats: Vector3i = selected["stats"]
		var required := session.get_requirements()
		for index in 3:
			var ratio := clampf(float(stats[index]) / required[index], 0.0, 1.0)
			_panel(Rect2(418, 382 + index * 57, 388, 5), Color("29424b"), Color.TRANSPARENT, 2)
			if ratio > 0.0:
				_panel(Rect2(418, 382 + index * 57, 388 * ratio, 5), SoulSession.ATTRIBUTE_COLORS[index], Color.TRANSPARENT, 2)
	if _release_effect > 0.0:
		_draw_ghost(Vector2(705, 289).lerp(Vector2(758, 276), 1.0 - _release_effect), GOLD, _release_effect)


func _draw_ghost(center: Vector2, color: Color, opacity: float) -> void:
	var points := PackedVector2Array()
	for index in 21:
		var angle := PI + index * PI / 20.0
		points.append(center + Vector2(cos(angle) * 22, sin(angle) * 24))
	for offset in [Vector2(22, 27), Vector2(11, 19), Vector2(0, 28), Vector2(-11, 19), Vector2(-22, 27)]:
		points.append(center + offset)
	draw_colored_polygon(points, Color(color, opacity * 0.8))
	for x in [-7, 7]:
		draw_circle(center + Vector2(x, 0), 3, Color(INK, opacity))
	draw_arc(center + Vector2(0, 5), 5, 0.2, PI - 0.2, 12, Color(INK, opacity), 1.5, true)


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
	button.add_theme_stylebox_override("normal", _style(Color("25463f") if selected else Color("1a3540"), MINT if selected else Color("3c5863"), 8))
	button.add_theme_stylebox_override("hover", _style(Color("284b46"), MINT, 8))
	button.add_theme_stylebox_override("pressed", _style(Color("335e51"), MINT, 8))
	button.add_theme_stylebox_override("disabled", _style(Color("132a33"), Color("2c434c"), 8))
	button.add_theme_color_override("font_color", MINT if selected else CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)


func _panel(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	draw_style_box(_style(fill, border, radius), rect)


func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
