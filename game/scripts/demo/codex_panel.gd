extends Control

signal toggle_requested
signal close_requested

enum NavFocus { GRID, FILTER }

const UI := preload("res://scripts/demo/demo_ui.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")
const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")

const TOP := 104
const DRAWER_SIZE := Vector2(600, 854)
const DRAWER_OPEN_X := 14.0
const DRAWER_CLOSED_X := -620.0
const BOOKMARK_WIDTH := 50.0
const BOOKMARK_SHADE := Color("eadcc8")
const UNKNOWN := "？？？"
const SILHOUETTE := Color(0.08, 0.06, 0.12, 0.85)
const GRID_COLUMNS := 3
const FILTER_NAMES := ["全部", "已炼", "Ⅰ", "Ⅱ", "Ⅲ", "升智", "降智", "升情", "降情", "升意", "降意"]
const FILTER_WIDTHS := [48, 48, 34, 34, 34, 43, 43, 43, 43, 43, 43]
const SHALLOW_COLOR := Color("58c4b8")
const DEEP_COLOR := Color("9c8df2")

var is_open := false
var nav_focus: int = NavFocus.GRID
var _paused := false
var _session: Session
var _audio: Audio
var _shade: ColorRect
var _drawer: Panel
var _bookmark_track: Control
var _bookmark: Button
var _arrow: Label
var _unseen: ColorRect
var _guest: Panel
var _guest_name: Label
var _guest_stats: Array[Label] = []
var _progress: Label
var _prev_page_button: Button
var _next_page_button: Button
var _tabs: Array[Button] = []
var _filters: Control
var _filter_buttons: Array[Button] = []
var _filter_focus_ring: Panel
var _list_surface: Panel
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty_label: Label
var _detail: Panel
var _key_hint: Label
var _recipe_page := false
var _source_page := false
var _page := 0
var _filter := 0
var _base_weights := Vector2i.ZERO
var _max_weights := Vector2i(1, 1)
var _entry_ids: Array[String] = []
var _entry_buttons: Array[Button] = []
var _entry_badges: Array[Label] = []
var _entry_tags: Array[Label] = []
var _selection := -1
var _slide: Tween
var _hover: Tween
var _breathing: Tween
var _list_animation: Tween
var _detail_animation: Tween


func setup(stage_size: Vector2, session: Session, audio: Audio) -> void:
	size = stage_size
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	_session = session
	_audio = audio
	for fish in Data.FISH:
		var shallow: int = fish.water[0]
		var deep: int = fish.water[1]
		_base_weights += Vector2i(shallow, deep)
		_max_weights.x = maxi(_max_weights.x, shallow)
		_max_weights.y = maxi(_max_weights.y, deep)

	_shade = ColorRect.new()
	_shade.position.y = TOP
	_shade.size.y = stage_size.y - TOP
	_shade.color = Color(UI.INK, 0.0)
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	_shade.gui_input.connect(_shade_input)
	add_child(_shade)

	_drawer = UI.panel(self, Rect2(Vector2(DRAWER_CLOSED_X, TOP), DRAWER_SIZE))
	_drawer.name = "Drawer"
	_drawer.focus_mode = FOCUS_ALL
	_drawer.accessibility_name = "图鉴"
	_drawer.mouse_filter = MOUSE_FILTER_STOP
	var backing := ColorRect.new()
	backing.position = Vector2(5, 5)
	backing.size = DRAWER_SIZE - Vector2(10, 10)
	backing.color = Color("1d1928")
	backing.show_behind_parent = true
	backing.mouse_filter = MOUSE_FILTER_IGNORE
	_drawer.add_child(backing)
	_build_drawer()
	_build_bookmark()
	_move_drawer(DRAWER_CLOSED_X)
	_drawer.hide()
	hide()


func _build_drawer() -> void:
	_book_icon(_drawer, Vector2(24, 24), UI.DARK_TEXT)
	UI.label(_drawer, "冥河图鉴", Rect2(58, 14, 152, 40), 28, UI.GOLD)
	_progress = UI.label(_drawer, "", Rect2(236, 17, 290, 34), 19, UI.CREAM)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close := UI.button(_drawer, "×", Rect2(538, 15, 40, 40), func() -> void: close_requested.emit())
	close.name = "Close"
	close.accessibility_name = "收起图鉴"

	_guest = UI.panel(_drawer, Rect2(20, 62, 560, 58), "wood_inset")
	_guest.name = "GuestOverview"
	UI.label(_guest, "当前来客", Rect2(12, 3, 84, 24), 15, UI.GOLD)
	_guest_name = UI.label(_guest, "", Rect2(100, 3, 444, 24), 18)
	_guest_name.clip_text = true
	for axis in 3:
		var x := 12 + axis * 182
		UI.icon_rect(_guest, UI.STAT_ICONS[axis], Rect2(x, 32, 18, 18))
		_guest_stats.append(UI.label(_guest, "", Rect2(x + 23, 27, 155, 28), 15))
	_guest.hide()

	_prev_page_button = UI.button(_drawer, "< Q", Rect2(20, 64, 52, 40), _switch_page.bind(false))
	_prev_page_button.add_theme_font_size_override("font_size", 16)
	_prev_page_button.accessibility_name = "选择鱼类图鉴"
	for page in 3:
		var tab := UI.tab_button(_drawer, ["鱼类", "原液", "成品药"][page], Rect2(78 + page * 150, 64, 142, 40), _set_codex_page.bind(page), page == 0)
		tab.add_theme_font_size_override("font_size", 20)
		_tabs.append(tab)
	_next_page_button = UI.button(_drawer, "E >", Rect2(528, 64, 52, 40), _switch_page.bind(true))
	_next_page_button.add_theme_font_size_override("font_size", 16)
	_next_page_button.accessibility_name = "选择下一页图鉴"

	_filters = Control.new()
	_filters.mouse_filter = MOUSE_FILTER_IGNORE
	_filters.position = Vector2(20, 110)
	_drawer.add_child(_filters)
	var filter_x := 0
	for index in FILTER_NAMES.size():
		var button := UI.button(_filters, FILTER_NAMES[index], Rect2(filter_x, 0, FILTER_WIDTHS[index], 32), _set_filter_from_bar.bind(index))
		button.add_theme_font_size_override("font_size", 15)
		_filter_buttons.append(button)
		filter_x += FILTER_WIDTHS[index] + 5
	_filter_focus_ring = Panel.new()
	_filter_focus_ring.mouse_filter = MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(UI.MINT, 0.0)
	ring_style.border_color = UI.MINT
	ring_style.set_border_width_all(2)
	ring_style.anti_aliasing = false
	_filter_focus_ring.add_theme_stylebox_override("panel", ring_style)
	_filter_focus_ring.hide()
	_filters.add_child(_filter_focus_ring)

	_list_surface = UI.panel(_drawer, Rect2(20, 112, 560, 444), "wood_inset")
	# Only the scroll area moves during a page change, so its wood frame stays aligned.
	_scroll = UI.create_scroll(_list_surface, Rect2(8, 8, 544, 428))
	_scroll.name = "Entries"
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 6)
	_scroll.add_child(_grid)
	_empty_label = UI.label(_list_surface, "当前筛选暂无已发现成品", Rect2(20, 140, 520, 56), 20, UI.MUTED)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.hide()

	_detail = UI.panel(_drawer, Rect2(20, 562, 560, 252), "dark_wood")
	_detail.name = "Detail"
	_key_hint = UI.label(_drawer, "", Rect2(22, 818, 556, 28), 16, UI.MUTED)


func _build_bookmark() -> void:
	_bookmark_track = Control.new()
	_bookmark_track.position = Vector2(-BOOKMARK_WIDTH, 266)
	_bookmark_track.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bookmark_track)
	_bookmark = UI.button(_bookmark_track, "", Rect2(0, 0, BOOKMARK_WIDTH, 168), func() -> void: toggle_requested.emit())
	_bookmark.name = "Bookmark"
	_bookmark.self_modulate = BOOKMARK_SHADE
	var parchment := UI.style(Color("dfba81"), Color("7d5939"))
	parchment.anti_aliasing = false
	parchment.corner_detail = 1
	parchment.corner_radius_top_right = 5
	parchment.corner_radius_bottom_right = 5
	parchment.border_width_bottom = 5
	parchment.shadow_color = UI.INK
	parchment.shadow_size = 2
	_bookmark.add_theme_stylebox_override("normal", parchment)
	_bookmark.add_theme_stylebox_override("hover", parchment)
	var pressed := parchment.duplicate() as StyleBoxFlat
	pressed.bg_color = parchment.bg_color.darkened(0.12)
	_bookmark.add_theme_stylebox_override("pressed", pressed)
	_bookmark.mouse_entered.connect(_set_bookmark_hover.bind(true))
	_bookmark.mouse_exited.connect(_set_bookmark_hover.bind(false))
	_book_icon(_bookmark, Vector2(13, 21), UI.DARK_TEXT)
	for line in 2:
		var glyph := UI.label(_bookmark, "图鉴"[line], Rect2(0, 49 + line * 25, BOOKMARK_WIDTH, 25), 21, UI.DARK_TEXT, false)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keycap := UI.pixel_panel(_bookmark, Rect2(8, 109, 34, 24), Color("ead3a0"), Color("67422d"), Color("946744"))
	var key := UI.label(keycap, "Tab", Rect2(0, 0, 34, 23), 14, UI.DARK_TEXT, false)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow = UI.label(_bookmark, "", Rect2(0, 135, BOOKMARK_WIDTH, 25), 15, UI.DARK_TEXT, false)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unseen = ColorRect.new()
	_unseen.position = Vector2(33, 12)
	_unseen.size = Vector2(7, 7)
	_unseen.color = Color("fff1b0")
	_unseen.mouse_filter = MOUSE_FILTER_IGNORE
	_unseen.hide()
	_bookmark.add_child(_unseen)
	_set_arrow(false)


func _book_icon(parent: Control, origin: Vector2, ink: Color) -> void:
	var icon := Control.new()
	icon.position = origin
	icon.size = Vector2(24, 20)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_rect(Rect2(0, 2, 24, 16), ink)
		icon.draw_rect(Rect2(2, 0, 9, 16), Color("f2d691"))
		icon.draw_rect(Rect2(13, 0, 9, 16), Color("e9c278"))
		for y in [4, 8, 12]:
			icon.draw_rect(Rect2(4, y, 5, 1), ink)
			icon.draw_rect(Rect2(15, y, 5, 1), ink)
	)
	parent.add_child(icon)


func present(paused: bool, expanded: bool) -> void:
	if _paused == paused and is_open == expanded:
		return
	var was_open := is_open
	_paused = paused
	is_open = expanded
	if _slide:
		_slide.kill()
	show()
	_bookmark.disabled = not paused
	_shade.mouse_filter = MOUSE_FILTER_STOP if expanded else MOUSE_FILTER_IGNORE
	_drawer.mouse_behavior_recursive = MOUSE_BEHAVIOR_INHERITED if expanded else MOUSE_BEHAVIOR_DISABLED
	if expanded:
		_drawer.show()
		_selection = -1
		_rebuild_list()
		nav_focus = NavFocus.FILTER if (_recipe_page and _entry_ids.is_empty()) else NavFocus.GRID
		_refresh_focus_visuals()
		_drawer.grab_focus()
	else:
		nav_focus = NavFocus.GRID
		_drawer.release_focus()
	if not paused:
		_set_bookmark_hover(false)
	if was_open != expanded:
		_audio.play(Audio.Cue.UI_CLICK)
	_refresh_unseen()

	var drawer_moving := _drawer.visible
	var duration := 0.14
	var transition := Tween.TRANS_CUBIC
	var easing := Tween.EASE_IN
	if expanded:
		duration = 0.22
		easing = Tween.EASE_OUT
	elif drawer_moving:
		duration = 0.16
	elif paused:
		duration = 0.20
		transition = Tween.TRANS_BACK
		easing = Tween.EASE_OUT
	var bookmark_x := DRAWER_OPEN_X + DRAWER_SIZE.x if expanded else (0.0 if paused else -BOOKMARK_WIDTH)
	_slide = create_tween().set_parallel().set_trans(transition).set_ease(easing)
	_slide.tween_method(_move_bookmark, _bookmark_track.position.x, bookmark_x, duration)
	if drawer_moving:
		_slide.tween_method(_move_drawer, _drawer.position.x, DRAWER_OPEN_X if expanded else DRAWER_CLOSED_X, duration)
		_slide.tween_property(_shade, "color:a", 0.45 if expanded else 0.0, duration)
	_slide.chain().tween_callback(_finish_slide)


func _move_bookmark(x: float) -> void:
	_bookmark_track.position.x = roundf(x)


func _move_drawer(x: float) -> void:
	_drawer.position.x = roundf(x)
	_shade.position.x = maxf(0.0, _drawer.position.x + DRAWER_SIZE.x)
	_shade.size.x = size.x - _shade.position.x


func _finish_slide() -> void:
	_set_arrow(is_open)
	if not is_open:
		_drawer.hide()
	if not _paused:
		hide()


func _set_arrow(expanded: bool) -> void:
	_arrow.text = "◀" if expanded else "▶"
	_bookmark.accessibility_name = "收起图鉴" if expanded else "展开图鉴"
	_bookmark.tooltip_text = "%s（Tab）" % _bookmark.accessibility_name


func _set_bookmark_hover(hovered: bool) -> void:
	if _hover:
		_hover.kill()
	var active := hovered and _paused
	if active:
		_audio.play(Audio.Cue.RIG_SELECT)
	_hover = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover.tween_method(func(x: float) -> void: _bookmark.position.x = roundf(x), _bookmark.position.x, 6.0 if active else 0.0, 0.10)
	_hover.tween_property(_bookmark, "self_modulate", Color.WHITE if active else BOOKMARK_SHADE, 0.10)


func _shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shade.accept_event()
		close_requested.emit()


func _refresh_unseen() -> void:
	var show_unseen := _paused and _session.has_unseen_codex()
	if show_unseen == _unseen.visible:
		return
	_unseen.visible = show_unseen
	if _breathing:
		_breathing.kill()
	if show_unseen:
		_unseen.modulate.a = 1.0
		_breathing = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breathing.tween_property(_unseen, "modulate:a", 0.45, 1.2)
		_breathing.tween_property(_unseen, "modulate:a", 1.0, 1.2)


func set_guest(soul: Dictionary, requirements: Array[Vector3i]) -> void:
	var show_guest := not soul.is_empty()
	var layout_changed := show_guest != _guest.visible
	_guest.visible = show_guest
	if show_guest:
		_guest_name.text = str(soul.name)
		for axis in 3:
			var value: int = soul.stats[axis]
			var lower := requirements[0][axis]
			var upper := requirements[1][axis]
			var color := Color("8ce0ff") if value < lower else (UI.WARN if value > upper else UI.GOOD)
			_guest_stats[axis].text = "%s %d [%d–%d]" % [Data.STAT_NAMES[axis], value, lower, upper]
			_guest_stats[axis].add_theme_color_override("font_color", color)
	if layout_changed:
		_layout_list()
		if is_open and not _recipe_page:
			var saved_sel := _selection
			_rebuild_list()
			if saved_sel > 0 and saved_sel < _entry_ids.size():
				_select_entry(saved_sel, false, false)


func handle_key(code: Key) -> bool:
	if code == KEY_Q:
		_switch_page(false)
		return true
	if code == KEY_E:
		_switch_page(true)
		return true
	match nav_focus:
		NavFocus.GRID:
			match code:
				KEY_W, KEY_UP:
					if _recipe_page and _selection < GRID_COLUMNS:
						_audio.play(Audio.Cue.RIG_SELECT)
						_set_nav_focus(NavFocus.FILTER)
					else:
						_move_grid(code)
					return true
				KEY_S, KEY_DOWN, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT:
					_move_grid(code)
					return true
				KEY_SHIFT:
					if not _recipe_page:
						return false
					_set_view(true, posmod(_filter + 1, FILTER_NAMES.size()))
					_set_nav_focus(NavFocus.FILTER if _entry_ids.is_empty() else NavFocus.GRID)
					return true
				_:
					return false
		NavFocus.FILTER:
			match code:
				KEY_A, KEY_LEFT:
					_set_filter_from_bar(posmod(_filter - 1, FILTER_NAMES.size()))
					return true
				KEY_D, KEY_RIGHT:
					_set_filter_from_bar(posmod(_filter + 1, FILTER_NAMES.size()))
					return true
				KEY_S, KEY_DOWN, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
					if not _entry_ids.is_empty():
						_audio.play(Audio.Cue.RIG_SELECT)
						_set_nav_focus(NavFocus.GRID)
					return true
				_:
					return false
	return false


func _set_nav_focus(next_focus: int) -> void:
	nav_focus = next_focus
	_refresh_focus_visuals()


func _switch_page(forward: bool) -> void:
	_set_codex_page(posmod(_page + (1 if forward else -1), 3))


func _set_filter_from_bar(index: int) -> void:
	_filter = index
	_set_codex_page(2)
	_rebuild_list()
	_set_nav_focus(NavFocus.FILTER)


func _refresh_focus_visuals() -> void:
	for index in _filter_buttons.size():
		var btn := _filter_buttons[index]
		if index == _filter:
			UI.set_button_primary(btn, true)
		else:
			UI.style_slot_button(btn, false)

	var active_filter_btn := _filter_buttons[_filter]
	_filter_focus_ring.visible = _recipe_page and nav_focus == NavFocus.FILTER
	_filter_focus_ring.position = active_filter_btn.position - Vector2(2, 2)
	_filter_focus_ring.size = active_filter_btn.size + Vector2(4, 4)

	for index in _entry_buttons.size():
		var is_sel := index == _selection
		if is_sel and nav_focus == NavFocus.GRID:
			UI.style_slot_button(_entry_buttons[index], true)
		elif is_sel:
			UI.style_slot_button(_entry_buttons[index], false)
			_entry_buttons[index].add_theme_stylebox_override("normal", UI.box(UI.SLOT_HOVER, 12.0, 8.0, 6.0))
		else:
			UI.style_slot_button(_entry_buttons[index], false)

	match nav_focus:
		NavFocus.GRID:
			_key_hint.text = "Q / E 切图鉴　WASD 选成品　首行 W 筛选　Tab 收起" if _recipe_page else "Q / E 切图鉴　WASD 选择条目　Tab 收起"
			_key_hint.add_theme_color_override("font_color", UI.MUTED)
		NavFocus.FILTER:
			_key_hint.text = "A / D 选分类　S / 空格 回成品列表　Q / E 切图鉴"
			_key_hint.add_theme_color_override("font_color", UI.MINT)


func _move_grid(code: Key) -> void:
	var count := _entry_ids.size()
	if count == 0:
		return
	var current := maxi(0, _selection)
	var next := current
	match code:
		KEY_A, KEY_LEFT:
			next = posmod(current - 1, count)
		KEY_D, KEY_RIGHT:
			next = posmod(current + 1, count)
		KEY_W, KEY_UP:
			if current - GRID_COLUMNS >= 0:
				next = current - GRID_COLUMNS
			else:
				var col := current % GRID_COLUMNS
				var last_row_start := ((count - 1) / GRID_COLUMNS) * GRID_COLUMNS
				next = mini(last_row_start + col, count - 1)
		KEY_S, KEY_DOWN:
			if current + GRID_COLUMNS < count:
				next = current + GRID_COLUMNS
			else:
				next = mini(current % GRID_COLUMNS, count - 1)
	if _selection < 0 or next != _selection:
		_select_entry(next, true, true)


func _set_page(recipe_page: bool) -> void:
	_set_view(recipe_page, _filter)


func _set_filter(index: int) -> void:
	_set_view(true, index)


func _set_view(recipe_page: bool, filter_index: int) -> void:
	_filter = filter_index
	_set_codex_page(2 if recipe_page else 0)
	_rebuild_list()


func _layout_list() -> void:
	var tabs_y := 64.0 + (62.0 if _guest.visible else 0.0)
	_prev_page_button.position.y = tabs_y
	_next_page_button.position.y = tabs_y
	for tab in _tabs:
		tab.position.y = tabs_y
	_filters.position.y = tabs_y + 46.0
	_filters.visible = _recipe_page
	_list_surface.position.y = tabs_y + (84.0 if _recipe_page else 48.0)
	_list_surface.size.y = 556.0 - _list_surface.position.y
	_scroll.size.y = _list_surface.size.y - 16.0
	_empty_label.position.y = maxf(24.0, (_list_surface.size.y - 56.0) * 0.5)
	_refresh_focus_visuals()


func _rebuild_list() -> void:
	_layout_list()
	for index in _tabs.size():
		UI.set_tab_active(_tabs[index], index == _page)
	var entries := _session.codex_recipes if _recipe_page else _session.codex_fish
	var discovered := entries.size()
	if _source_page:
		discovered = 0
		for source in Data.essence_indices():
			discovered += int(_source_unlocked(source))
	_progress.text = "%s %d / %d" % [["鱼类", "原液", "成品"][_page], discovered, 11 if _page > 0 else Data.FISH.size()]
	UI.clear_cards(_grid)
	_entry_ids.clear()
	_entry_buttons.clear()
	_entry_badges.clear()
	_entry_tags.clear()
	_scroll.scroll_vertical = 0
	if _recipe_page:
		var ordinal := 0
		for id in Data.POTIONS:
			ordinal += 1
			if _matches_filter(id):
				_add_recipe_tile(id, ordinal, Data.POTIONS[id], entries.get(id, {}))
	elif _source_page:
		for source in Data.essence_indices():
			var data: Dictionary = Data.source_data(source)
			var unlocked := _source_unlocked(source)
			var card := UI.button(_grid, "", Rect2(0, 0, 172, 94), _click_entry.bind(_entry_ids.size()))
			card.custom_minimum_size = Vector2(172, 94)
			UI.icon_rect(card, UI.ICON_ESSENCE, Rect2(12, 10, 34, 34))
			UI.label(card, data.essence if unlocked else UNKNOWN, Rect2(52, 8, 114, 30), 17, UI.CREAM)
			UI.label(card, "%d级 · 库存 %d" % [data.tier, _session.essences[source]] if unlocked else "尚未获得", Rect2(12, 54, 154, 28), 15, UI.MUTED)
			_entry_ids.append("source:%d" % source)
			_entry_buttons.append(card)
			var badge := Label.new()
			card.add_child(badge)
			_entry_badges.append(badge)
			_entry_tags.append(null)
	else:
		for species in Data.FISH.size():
			var fish: Dictionary = Data.FISH[species]
			_add_fish_tile(fish.id, species, fish, entries.get(fish.id, {}))
	_empty_label.visible = _entry_ids.is_empty()
	_selection = -1
	if not _entry_ids.is_empty():
		_select_entry(0, false, false)
	else:
		_render_detail(false)
	_refresh_focus_visuals()
	_animate_list()


func _matches_filter(id: String) -> bool:
	if _filter == 0:
		return true
	if not _session.codex_recipes.has(id):
		return false
	if _filter == 1:
		return true
	var potion: Dictionary = Data.POTIONS[id]
	if _filter <= 4:
		return potion.tier == _filter - 1
	var axis := (_filter - 5) >> 1
	var direction := 1 if _filter % 2 == 1 else -1
	var primary := 0
	for index in range(1, 3):
		if absi(potion.effect[index]) > absi(potion.effect[primary]):
			primary = index
	return primary == axis and potion.effect[axis] * direction > 0


func _add_fish_tile(id: String, species: int, data: Dictionary, progress: Dictionary) -> void:
	var unlocked := not progress.is_empty()
	var is_new := bool(progress.get("is_new", false))
	var title: String = data.name if unlocked else UNKNOWN
	var tile_h := 84.0 if _guest.visible else 98.0
	var tile_size := Vector2(172, tile_h)
	var button := UI.button(_grid, "", Rect2(Vector2.ZERO, tile_size), _click_entry.bind(_entry_ids.size()))
	button.custom_minimum_size = tile_size
	button.accessibility_name = title
	UI.style_slot_button(button)

	var code_lbl := UI.label(button, "#%02d" % (species + 1), Rect2(8, 3, 36, 18), 12, Color(UI.MUTED, 0.72), false)
	code_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var icon_h := 44.0 if _guest.visible else 54.0
	var icon := UI.icon_rect(button, Data.fish_texture(species), Rect2(14, 11, 144, icon_h))
	if not unlocked:
		icon.modulate = SILHOUETTE

	var name_y := 55.0 if _guest.visible else 66.0
	var name_lbl := UI.label(button, title, Rect2(6, name_y, 160, 26), 17, UI.CREAM if unlocked else UI.MUTED)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true

	var hab := _habitat_short(species)
	var tag := UI.label(button, hab[0], Rect2(114, 3, 50, 18), 12, hab[1], false)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tag.visible = unlocked and not is_new

	var badge := UI.label(button, "NEW", Rect2(118, 2, 48, 20), 13, UI.GOLD)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	badge.visible = is_new

	_entry_ids.append(id)
	_entry_buttons.append(button)
	_entry_badges.append(badge)
	_entry_tags.append(tag)


func _add_recipe_tile(id: String, ordinal: int, data: Dictionary, progress: Dictionary) -> void:
	var unlocked := not progress.is_empty()
	var title: String = data.name if unlocked else UNKNOWN
	var tile_size := Vector2(172, 64)
	var button := UI.button(_grid, "", Rect2(Vector2.ZERO, tile_size), _click_entry.bind(_entry_ids.size()))
	button.custom_minimum_size = tile_size
	button.accessibility_name = title
	UI.style_slot_button(button)

	var icon_box := UI.panel(button, Rect2(8, 10, 42, 44), "wood_inset")
	icon_box.mouse_filter = MOUSE_FILTER_IGNORE
	var icon := UI.icon_rect(icon_box, UI.ICON_POTION, Rect2(5, 5, 32, 34))
	if not unlocked:
		icon.modulate = SILHOUETTE

	var name_lbl := UI.label(button, title, Rect2(56, 8, 108, 24), 17, UI.GOLD if (unlocked and not str(data.reaction).is_empty()) else (UI.CREAM if unlocked else UI.MUTED))
	name_lbl.clip_text = true

	var sub_text := "#%02d" % ordinal
	var sub_color := Color(UI.MUTED, 0.72)
	if unlocked:
		if not str(data.reaction).is_empty():
			sub_text = "★ 特殊中和"
			sub_color = UI.MINT
		else:
			sub_text = _compact_effect_text(data.effect)
			sub_color = UI.MINT
	var sub_lbl := UI.label(button, sub_text, Rect2(56, 34, 108, 22), 13, sub_color, false)
	sub_lbl.clip_text = true

	var badge := UI.label(button, "NEW", Rect2(122, 2, 44, 18), 12, UI.GOLD)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	badge.visible = bool(progress.get("is_new", false))

	_entry_ids.append(id)
	_entry_buttons.append(button)
	_entry_badges.append(badge)
	_entry_tags.append(null)


func _click_entry(index: int) -> void:
	_set_nav_focus(NavFocus.GRID)
	_select_entry(index, true, true)


func _select_entry(index: int, play_sound: bool = true, animate_detail: bool = true) -> void:
	if index < 0 or index >= _entry_ids.size():
		return
	var entries := _session.codex_recipes if _recipe_page else _session.codex_fish
	var id := _entry_ids[index]
	var changed := index != _selection
	_selection = index
	_refresh_focus_visuals()
	if entries.has(id) and bool(entries[id].get("is_new", false)):
		entries[id].is_new = false
		_entry_badges[index].hide()
		if _entry_tags[index] != null:
			_entry_tags[index].show()
		_refresh_unseen()
	if play_sound and changed:
		_audio.play(Audio.Cue.RIG_SELECT)
	_render_detail(animate_detail and changed)
	UI.reveal(_scroll, _entry_buttons[index])


func _render_detail(animate: bool) -> void:
	if _detail_animation:
		_detail_animation.kill()
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_detail.modulate.a = 0.45 if animate else 1.0
	if _selection < 0 or _selection >= _entry_ids.size():
		var empty_box := UI.pixel_panel(_detail, Rect2(16, 16, 528, 220), Color("181423"), Color("4a3f57"), UI.INK)
		var prompt := UI.label(empty_box, "当前筛选暂无已解锁记录", Rect2(12, 0, 504, 220), 20, UI.MUTED)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif _source_page:
		_show_source(int(_entry_ids[_selection].get_slice(":", 1)))
	elif _recipe_page:
		_show_recipe(_entry_ids[_selection])
	else:
		_show_fish(_entry_ids[_selection])
	if animate:
		_detail_animation = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_detail_animation.tween_property(_detail, "modulate:a", 1.0, 0.14)


func _show_fish(id: String) -> void:
	var species := Data.fish_index(id)
	var fish: Dictionary = Data.FISH[species]
	var progress: Dictionary = _session.codex_fish.get(id, {})
	var unlocked := not progress.is_empty()
	if not unlocked:
		_show_locked_fish(species)
		return

	# Specimen showcase frame (top-left)
	var frame := UI.panel(_detail, Rect2(14, 14, 150, 96), "wood_inset")
	var picture := UI.icon_rect(frame, Data.fish_texture(species), Rect2(12, 12, 126, 72))
	picture.name = "SpecimenIcon"
	UI.label(frame, "#%02d" % (species + 1), Rect2(8, 3, 40, 18), 12, Color(UI.MUTED, 0.78), false)

	# Title + Habitat pill
	UI.label(_detail, fish.name, Rect2(176, 11, 248, 34), 24, UI.GOLD)
	var hab := _habitat_pill_meta(species)
	var hab_pill := UI.pixel_panel(_detail, Rect2(432, 15, 114, 28), hab[2], hab[1], UI.INK)
	var hab_lbl := UI.label(hab_pill, hab[0], Rect2(0, 0, 114, 26), 14, hab[1], false)
	hab_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Catch count & max length pills
	var length := "%.1f cm" % progress.max_cm if progress.max_cm > 0.0 else "—"
	var count_pill := UI.pixel_panel(_detail, Rect2(176, 49, 178, 28), Color("241e33"), Color("5a4b63"), UI.INK)
	var count_lbl := UI.label(count_pill, "累计捕获 %d 次" % progress.caught, Rect2(10, 0, 158, 26), 15, UI.CREAM)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var len_pill := UI.pixel_panel(_detail, Rect2(362, 49, 184, 28), Color("241e33"), Color("5a4b63"), UI.INK)
	var len_lbl := UI.label(len_pill, "最大体长 %s" % length, Rect2(10, 0, 164, 26), 15, UI.MINT)
	len_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Matching attribute bait strip
	var bait_bar := UI.pixel_panel(_detail, Rect2(176, 83, 370, 27), Color("1b1628"), Color("564652"), UI.INK)
	UI.icon_rect(bait_bar, UI.ICON_BAIT, Rect2(8, 3, 20, 20))
	var bait_lbl := UI.label(bait_bar, _bait_text(species), Rect2(34, 0, 328, 25), 15, UI.CREAM)
	bait_lbl.clip_text = true

	# Middle habitat & weight visualization row
	if species == Data.VARIANT:
		var var_card := UI.pixel_panel(_detail, Rect2(14, 118, 532, 48), Color("2b2030"), Color("c99652"), UI.INK)
		UI.label(var_card, "深水 + %s（%.0f%% 触发）" % [Data.BAITS[Data.VARIANT_BAIT], Data.VARIANT_CHANCE * 100.0], Rect2(14, 0, 404, 46), 17, UI.GOLD)
		var tag_pill := UI.pixel_panel(var_card, Rect2(424, 10, 96, 26), Color("1f3538"), UI.MINT, UI.INK)
		var tag_lbl := UI.label(tag_pill, "真名捕获", Rect2(0, 0, 96, 24), 14, UI.MINT, false)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_add_water_card(14, 118, "浅水", int(fish.water[0]), _base_weights.x, _max_weights.x, SHALLOW_COLOR)
		_add_water_card(286, 118, "深水", int(fish.water[1]), _base_weights.y, _max_weights.y, DEEP_COLOR)

	var source := Data.essence_source(species)
	var data: Dictionary = Data.source_data(source)
	var button := UI.button(_detail, "查看 %s · %d级材料 →" % [data.essence, data.tier], Rect2(14, 176, 532, 38), _open_source.bind(source))
	button.add_theme_font_size_override("font_size", 18)
	UI.label(_detail, "小／中／大：2／3／4份；巨刺3份。捕获即入库。", Rect2(16, 216, 530, 26), 15, UI.MUTED)


func _show_locked_fish(species: int) -> void:
	var frame := UI.panel(_detail, Rect2(14, 14, 150, 128), "wood_inset")
	var picture := UI.icon_rect(frame, Data.fish_texture(species), Rect2(12, 24, 126, 80))
	picture.name = "SpecimenIcon"
	picture.modulate = SILHOUETTE
	UI.label(frame, "#%02d" % (species + 1), Rect2(8, 4, 40, 18), 12, Color(UI.MUTED, 0.72), false)

	UI.label(_detail, UNKNOWN, Rect2(178, 16, 220, 34), 26, UI.GOLD)
	var lock_pill := UI.pixel_panel(_detail, Rect2(448, 19, 98, 28), Color("252034"), Color("5c526e"), UI.INK)
	var lock_lbl := UI.label(lock_pill, "未捕获", Rect2(0, 0, 98, 26), 14, UI.MUTED, false)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_divider(_detail, Rect2(178, 56, 368, 2), Color("473d57"))
	UI.label(_detail, "尚未在冥河捕获该鱼种", Rect2(178, 66, 368, 28), 18, UI.CREAM)
	var tip := UI.label(_detail, "捕获后解锁水域、药材等级与原液入口。", Rect2(178, 96, 368, 42), 15, UI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var titles := ["水域与权重", "适配鱼饵", "药材等级"]
	for i in 3:
		var slot := UI.pixel_panel(_detail, Rect2(14 + i * 181, 154, 170, 82), Color("191526"), Color("4a3f57"), UI.INK)
		var t_lbl := UI.label(slot, titles[i], Rect2(8, 8, 154, 22), 14, Color(UI.GOLD, 0.75), false)
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_divider(slot, Rect2(16, 34, 138, 1), Color("3a3147"))
		var v_lbl := UI.label(slot, UNKNOWN, Rect2(8, 42, 154, 30), 20, UI.MUTED)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _add_water_card(x: float, y: float, name: String, weight: int, total: int, peak: int, color: Color) -> void:
	var active := weight > 0
	var card := UI.pixel_panel(_detail, Rect2(x, y, 260, 48), Color("221c30") if active else Color("191525"), color.darkened(0.32) if active else Color("433952"), UI.INK)
	var text := "%s 权重 %d（%.1f%%）" % [name, weight, 100.0 * weight / total] if active else name + " 不出"
	var lbl := UI.label(card, text, Rect2(10, 4, 240, 22), 15, color if active else Color(UI.MUTED, 0.72), active)
	lbl.clip_text = true
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(10, 30)
	bar_bg.size = Vector2(240, 8)
	bar_bg.color = Color("130f1c")
	bar_bg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(bar_bg)
	if active and peak > 0:
		var fill_w := maxf(8.0, roundf(240.0 * clampf(float(weight) / float(peak), 0.0, 1.0)))
		var bar_fill := ColorRect.new()
		bar_fill.position = Vector2(10, 30)
		bar_fill.size = Vector2(fill_w, 8)
		bar_fill.color = color
		bar_fill.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(bar_fill)
		var bar_hi := ColorRect.new()
		bar_hi.position = Vector2(10, 30)
		bar_hi.size = Vector2(fill_w, 2)
		bar_hi.color = color.lightened(0.32)
		bar_hi.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(bar_hi)


func _show_recipe(id: String) -> void:
	var potion: Dictionary = Data.POTIONS[id]
	if not _session.codex_recipes.has(id):
		_show_locked_recipe(_recipe_ordinal(id))
		return
	UI.icon_rect(_detail, UI.ICON_POTION, Rect2(18, 16, 48, 48))
	UI.label(_detail, "%s · %d级" % [potion.name, potion.tier], Rect2(82, 12, 460, 36), 24, UI.GOLD)
	UI.label(_detail, potion.category + " · 以下为未经强化的固定药效", Rect2(82, 52, 460, 28), 15, UI.MUTED)
	var effects := UI.make_effect_row(potion.effect, 30, 22, false)
	effects.position = Vector2(24, 92)
	_detail.add_child(effects)
	var index := 0
	for source in Data.essence_indices():
		for outcome in Data.source_data(source).outcomes:
			if outcome[0] == id:
				var button := UI.button(_detail, Data.FISH[source].essence + " →", Rect2(14 + (index % 3) * 181, 152 + (index / 3) * 42, 170, 34), _open_source.bind(source))
				button.add_theme_font_size_override("font_size", 15)
				index += 1


func _show_locked_recipe(ordinal: int) -> void:
	UI.icon_rect(_detail, UI.ICON_POTION, Rect2(24, 24, 62, 62)).modulate = SILHOUETTE
	UI.label(_detail, "未发现成品 #%02d" % ordinal, Rect2(110, 24, 422, 42), 24, UI.GOLD)
	UI.label(_detail, "在炼药台消耗三份同种原液炼制。\n首次炼出后解锁固定药效与原液入口。", Rect2(24, 112, 510, 90), 19, UI.MUTED)


func _add_ingredient_chip(rect: Rect2, species: int) -> void:
	var chip := UI.pixel_panel(_detail, rect, Color("231c31"), Color("6c584e"), UI.INK)
	UI.icon_rect(chip, Data.fish_texture(species), Rect2(8, 10, 54, 34))
	var ess_lbl := UI.label(chip, Data.FISH[species].essence, Rect2(68, 6, rect.size.x - 76.0, 24), 16, UI.CREAM)
	ess_lbl.clip_text = true
	var fish_lbl := UI.label(chip, Data.FISH[species].name, Rect2(68, 29, rect.size.x - 76.0, 18), 13, UI.MUTED, false)
	fish_lbl.clip_text = true


func _divider(parent: Control, rect: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	line.position = rect.position
	line.size = rect.size
	line.color = color
	line.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _stat_border(axis: int, value: int) -> Color:
	if value > 0:
		return Data.STAT_COLORS[axis].darkened(0.35)
	if value < 0:
		return UI.WARN.darkened(0.35)
	return Color("433952")


func _habitat_short(species: int) -> Array:
	if species == Data.VARIANT:
		return ["异变", UI.GOLD]
	var s: int = Data.FISH[species].water[0]
	var d: int = Data.FISH[species].water[1]
	if s > 0 and d > 0:
		return ["浅·深", UI.MINT]
	if s > 0:
		return ["浅水", SHALLOW_COLOR]
	return ["深水", DEEP_COLOR]


func _habitat_pill_meta(species: int) -> Array:
	if species == Data.VARIANT:
		return ["深水异变", UI.GOLD, Color("38292b")]
	var s: int = Data.FISH[species].water[0]
	var d: int = Data.FISH[species].water[1]
	if s > 0 and d > 0:
		return ["浅·深双域", UI.MINT, Color("1d3236")]
	if s > 0:
		return ["浅水专属", SHALLOW_COLOR, Color("193137")]
	return ["深水专属", DEEP_COLOR, Color("25203c")]


func _bait_text(species: int) -> String:
	if species == Data.VARIANT:
		return "限定饵：%s" % Data.BAITS[Data.VARIANT_BAIT]
	var names := PackedStringArray()
	for bait in Data.ATTRIBUTE_BAITS:
		if Data.bait_matches_fish(bait, species):
			names.append(Data.BAITS[bait])
	if names.is_empty():
		return "适配属性饵：无（通用 %s）" % Data.BAITS[Data.Bait.DEFAULT]
	return "属性饵 ×%d：%s" % [int(Data.ATTRIBUTE_BAIT_MULTIPLIER), "、".join(names)]


func _compact_effect_text(effect: Vector3i) -> String:
	var tags := PackedStringArray()
	var short_names := ["智", "情", "意"]
	for i in 3:
		if effect[i] != 0:
			tags.append("%s%+d" % [short_names[i], effect[i]])
	return " ".join(tags) if not tags.is_empty() else "平衡"


func _recipe_ordinal(id: String) -> int:
	var idx := 1
	for key in Data.POTIONS:
		if key == id:
			return idx
		idx += 1
	return 1


func _animate_list() -> void:
	if _list_animation:
		_list_animation.kill()
	_scroll.modulate.a = 0.35
	_scroll.position.y = 16.0
	_list_animation = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_list_animation.tween_property(_scroll, "modulate:a", 1.0, 0.14)
	_list_animation.tween_method(func(y: float) -> void: _scroll.position.y = roundf(y), 16.0, 8.0, 0.14)


func _set_codex_page(page: int) -> void:
	_page = clampi(page, 0, 2)
	_recipe_page = _page == 2
	_source_page = _page == 1
	_audio.play(Audio.Cue.UI_CLICK)
	_rebuild_list()
	_set_nav_focus(NavFocus.GRID)


func _source_unlocked(source: int) -> bool:
	return _session.essences[source] > 0 or _session.codex_fish.has(Data.FISH[source].id) or (source == 7 and _session.codex_fish.has(Data.FISH[Data.STILLFIN].id)) or _session.codex_sources.has(Data.FISH[source].id)


func _open_source(source: int) -> void:
	_set_codex_page(1)
	var index := _entry_ids.find("source:%d" % source)
	_select_entry(index, false, false)


func _show_source(source: int) -> void:
	var data: Dictionary = Data.source_data(source)
	if not _source_unlocked(source):
		UI.label(_detail, "尚未获得该原液", Rect2(24, 30, 510, 40), 24, UI.GOLD)
		UI.label(_detail, "捕获对应鱼种后，原液自动入库。", Rect2(24, 110, 510, 44), 19, UI.MUTED)
		return
	UI.icon_rect(_detail, UI.ICON_ESSENCE, Rect2(18, 16, 42, 42))
	UI.label(_detail, "%s · %d级" % [data.essence, data.tier], Rect2(76, 12, 470, 36), 24, UI.GOLD)
	var names := PackedStringArray()
	for species in Data.FISH.size():
		if Data.essence_source(species) == source:
			names.append(Data.FISH[species].name)
	UI.label(_detail, "来源：" + "、".join(names), Rect2(18, 62, 526, 28), 16, UI.CREAM)
	UI.label(_detail, "每炉3份 → 1剂；尾料与成品跨日保留。", Rect2(18, 94, 526, 28), 16, UI.MUTED)
	var row := 0
	for outcome in data.outcomes:
		var known: bool = _session.codex_sources.get(Data.FISH[source].id, {}).get(outcome[0], false)
		var title: String = Data.POTIONS[outcome[0]].name if known else UNKNOWN
		UI.label(_detail, "%s　%s" % [title, "%d%%" % outcome[1] if known else "概率待发现"], Rect2(24, 136 + row * 46, 510, 40), 21, UI.MINT if known else UI.MUTED)
		row += 1
