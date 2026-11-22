extends Control
## Soul-Knight inspired top-left pixel attribute HUD with target range markers
## and semi-transparent potion preview overlays.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const UI := preload("res://scripts/demo/demo_ui.gd")

const MAX_STAT := Session.STAT_MAX

var soul: Dictionary = {}
var preview: Dictionary = {}
var requirements: Array[Vector3i] = [Vector3i.ZERO, Session.STAT_CEILING]

var _bg: Panel
var _name_label: Label
var _state_label: Label
var _bars_canvas: Control
var _bar_labels: Array[Label] = []
var _status_labels: Array[Label] = []
var _legend_label: Label
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg = UI.panel(self, Rect2(Vector2.ZERO, size), "hud_wood")
	var header_bg := UI.panel(self, Rect2(14, 14, size.x - 28, 42), "wood_inset")
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = UI.label(self, "等待来客", Rect2(26, 16, size.x - 154, 38), 20, UI.CREAM)
	_name_label.clip_text = true
	_state_label = UI.label(self, "", Rect2(size.x - 138, 16, 114, 38), 18, UI.GOLD)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_bars_canvas = Control.new()
	_bars_canvas.position = Vector2(14, 62)
	_bars_canvas.size = Vector2(size.x - 28, size.y - 74)
	_bars_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bars_canvas.draw.connect(_draw_bars)
	add_child(_bars_canvas)

	var w := _bars_canvas.size.x
	var row_h := 46.0
	var bar_x := 48.0
	var status_w := 88.0
	var bar_w := w - bar_x - status_w - 8.0
	var bar_h := 34.0

	for index in 3:
		var top := 62.0 + index * row_h + 4.0
		var b_lbl := _outlined_label(Rect2(14.0 + bar_x, top, bar_w, bar_h), 17, Color("ffffff"))
		_bar_labels.append(b_lbl)
		var s_lbl := _outlined_label(Rect2(14.0 + bar_x + bar_w + 8.0, top + 2.0, status_w, bar_h - 4.0), 16, UI.CREAM)
		_status_labels.append(s_lbl)

	_legend_label = _outlined_label(Rect2(26.0, 62.0 + 3 * row_h + 2.0, size.x - 52.0, 24.0), 17, Color("fff3d4"))
	_legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _outlined_label(rect: Rect2, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.position = rect.position
	lbl.size = rect.size
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color("18101c"))
	lbl.add_theme_constant_override("outline_size", 4)
	add_child(lbl)
	return lbl


func set_state(selected_soul: Dictionary, dose_preview: Dictionary, day: int, limits: Array[Vector3i]) -> void:
	soul = selected_soul
	preview = dose_preview
	requirements = limits
	var has_soul := not soul.is_empty()
	var has_preview := has_soul and not preview.is_empty()
	var legend := PackedStringArray(["第 %d 天" % day])

	if not has_soul:
		_name_label.text = "等待来客"
		_state_label.text = "窗口空闲"
		_state_label.add_theme_color_override("font_color", UI.MUTED)
	else:
		_name_label.text = str(soul.name)
		var ready := Session.meets_requirements(soul.stats, requirements)
		if has_preview:
			var will_ready := Session.meets_requirements(preview.after, requirements)
			_state_label.text = "预览·达标" if will_ready else "预览中"
			_state_label.add_theme_color_override("font_color", UI.GOOD if will_ready else UI.GOLD)
		elif ready:
			_state_label.text = "可放行"
			_state_label.add_theme_color_override("font_color", UI.GOOD)
		else:
			_state_label.text = "待调配"
			_state_label.add_theme_color_override("font_color", UI.GOLD)

	for index in 3:
		var lower := requirements[0][index]
		var upper := requirements[1][index]
		var checked := lower > 0 or upper < MAX_STAT
		if lower > 0 and upper < MAX_STAT:
			legend.append("%s %d～%d" % [Data.STAT_NAMES[index], lower, upper])
		elif checked:
			legend.append("%s %s%d" % [Data.STAT_NAMES[index], "≥" if lower > 0 else "≤", lower if lower > 0 else upper])
		if not has_soul:
			_bar_labels[index].text = "%s — / 10" % Data.STAT_NAMES[index]
			_status_labels[index].text = "—"
			_status_labels[index].add_theme_color_override("font_color", UI.MUTED)
			continue
		var curr: int = int(soul.stats[index])
		var after: int = int(preview.after[index]) if has_preview else curr
		var delta_val: int = after - curr
		if has_preview and delta_val != 0:
			var sign_str := "+%d" % delta_val if delta_val > 0 else str(delta_val)
			_bar_labels[index].text = "%s %d → %d (%s)" % [Data.STAT_NAMES[index], curr, after, sign_str]
		elif soul.served and int(soul.before[index]) != curr:
			_bar_labels[index].text = "%s %d → %d / 10" % [Data.STAT_NAMES[index], int(soul.before[index]), curr]
		else:
			_bar_labels[index].text = "%s %d / 10" % [Data.STAT_NAMES[index], curr]

		var check_val := after if has_preview else curr
		if not checked:
			_status_labels[index].text = "免检"
			_status_labels[index].add_theme_color_override("font_color", UI.MUTED)
		elif check_val < lower:
			_status_labels[index].text = "↓ 偏低" if not has_preview else "→ 偏低"
			_status_labels[index].add_theme_color_override("font_color", Color("8ce0ff"))
		elif check_val > upper:
			_status_labels[index].text = "↑ 偏高" if not has_preview else "→ 偏高"
			_status_labels[index].add_theme_color_override("font_color", Color("ff8c7a"))
		else:
			_status_labels[index].text = "✓ 达标" if not has_preview else "→ 达标"
			_status_labels[index].add_theme_color_override("font_color", UI.GOOD)

	_legend_label.text = "　".join(legend)
	_bars_canvas.queue_redraw()


func _process(delta: float) -> void:
	if not preview.is_empty():
		_pulse += delta * 4.5
		_bars_canvas.queue_redraw()


func _draw_bars() -> void:
	var w := _bars_canvas.size.x
	var row_h := 46.0
	var has_soul := not soul.is_empty()
	var has_preview := has_soul and not preview.is_empty()
	var bar_x := 48.0
	var status_w := 88.0
	var bar_w := w - bar_x - status_w - 8.0
	var bar_h := 34.0
	var pulse_alpha := 0.45 + 0.12 * sin(_pulse)

	for index in 3:
		var top := index * row_h + 4.0
		var icon_rect := Rect2(2, top + (bar_h - 32.0) * 0.5, 32.0, 32.0)
		_bars_canvas.draw_texture_rect(UI.STAT_ICONS[index], icon_rect, false)

		var bar_rect := Rect2(bar_x, top, bar_w, bar_h)
		_bars_canvas.draw_rect(bar_rect.grow(2.0), Color("241518"))
		_bars_canvas.draw_rect(bar_rect, Color("2e2028"))
		_bars_canvas.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x, 3)), Color("1d141a"))

		var lower := requirements[0][index]
		var upper := requirements[1][index]
		var low_x := bar_rect.position.x + bar_rect.size.x * (float(lower) / MAX_STAT)
		var high_x := bar_rect.position.x + bar_rect.size.x * (float(upper) / MAX_STAT)
		if lower > 0 or upper < MAX_STAT:
			_bars_canvas.draw_rect(Rect2(low_x, bar_rect.position.y + 1, high_x - low_x, bar_rect.size.y - 2), Color(UI.GOOD, 0.16))

		var base_col: Color = Data.STAT_COLORS[index]
		if has_soul:
			var curr: int = int(soul.stats[index])
			var after: int = int(preview.after[index]) if has_preview else curr
			var delta_val: int = after - curr
			var curr_w := bar_rect.size.x * clampf(float(curr) / MAX_STAT, 0.0, 1.0)
			var after_w := bar_rect.size.x * clampf(float(after) / MAX_STAT, 0.0, 1.0)

			if not has_preview or delta_val == 0:
				_draw_glossy_segment(bar_rect.position.x, bar_rect.position.y, curr_w, bar_rect.size.y, base_col, 1.0)
			elif delta_val > 0:
				_draw_glossy_segment(bar_rect.position.x, bar_rect.position.y, curr_w, bar_rect.size.y, base_col, 1.0)
				var gain_rect := Rect2(bar_rect.position.x + curr_w, bar_rect.position.y, after_w - curr_w, bar_rect.size.y)
				_bars_canvas.draw_rect(gain_rect, Color(base_col.lightened(0.22), pulse_alpha))
				_bars_canvas.draw_rect(Rect2(gain_rect.position, Vector2(gain_rect.size.x, 5.0)), Color(1, 1, 1, pulse_alpha * 0.65))
				_bars_canvas.draw_rect(gain_rect, Color(Color("ffffff"), 0.78), false, 2.0)
			else:
				_draw_glossy_segment(bar_rect.position.x, bar_rect.position.y, after_w, bar_rect.size.y, base_col, 1.0)
				var loss_rect := Rect2(bar_rect.position.x + after_w, bar_rect.position.y, curr_w - after_w, bar_rect.size.y)
				_bars_canvas.draw_rect(loss_rect, Color(base_col.darkened(0.15), 0.34))
				var cut_x := bar_rect.position.x + after_w
				_bars_canvas.draw_line(Vector2(cut_x, bar_rect.position.y), Vector2(cut_x, bar_rect.end.y), Color(1, 1, 1, 0.9), 2.0)
				_bars_canvas.draw_rect(loss_rect, Color(UI.WARN, 0.72), false, 2.0)

			for tick in range(1, 10):
				if tick == lower or tick == upper:
					continue
				var tx := bar_rect.position.x + bar_rect.size.x * (float(tick) / MAX_STAT)
				_bars_canvas.draw_line(Vector2(tx, bar_rect.end.y - 5), Vector2(tx, bar_rect.end.y), Color(0, 0, 0, 0.35), 1.0)

		if lower > 0:
			_bars_canvas.draw_line(Vector2(low_x, bar_rect.position.y - 2), Vector2(low_x, bar_rect.end.y + 2), Color(UI.GOOD, 0.95), 2.0)
		if upper < MAX_STAT:
			_bars_canvas.draw_line(Vector2(high_x, bar_rect.position.y - 2), Vector2(high_x, bar_rect.end.y + 2), Color(UI.GOOD, 0.95), 2.0)

		var badge_rect := Rect2(bar_rect.end.x + 8.0, top + 2.0, status_w, bar_h - 4.0)
		_bars_canvas.draw_rect(badge_rect.grow(1.0), Color("241518"))
		_bars_canvas.draw_rect(badge_rect, Color("2e2028"))


func _draw_glossy_segment(x: float, y: float, width: float, height: float, color: Color, alpha: float) -> void:
	if width <= 0.5:
		return
	_bars_canvas.draw_rect(Rect2(x, y, width, height), Color(color, alpha))
	_bars_canvas.draw_rect(Rect2(x, y + 2.0, width, 5.0), Color(color.lightened(0.35), alpha * 0.85))
	_bars_canvas.draw_rect(Rect2(x, y + height - 5.0, width, 5.0), Color(color.darkened(0.28), alpha * 0.85))
