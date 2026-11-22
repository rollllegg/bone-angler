extends Control
## Visual pixel-art alchemy workbench: zero dropdowns, full Feishu fish art,
## and reception-consistent 3-icon attribute previews.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const UI := preload("res://scripts/demo/demo_ui.gd")

var session: Session
var active_tab: int = 0
var selected_fish_id: int = -1
var mix_first: int = -1
var mix_second: int = -1
var selected_medicine: Variant = null
var selected_attribute: int = 0
var selected_adjustment: int = 1

var refine_button: Button
var mix_button: Button
var strengthen_button: Button
var fish_cards: Array[Button] = []
var essence_cards: Array[Button] = []
var medicine_cards: Array[Button] = []

var _tab_buttons: Array[Button] = []
var _tab_views: Array[Control] = []
var _stock_concentrate: Label
var _stock_bones: Label
var _status: Label
var _controls_hint: Label
var _essence_cursor := 0

# Refine view nodes
var _fish_grid: GridContainer
var _fish_empty: Label
var _refine_fish_tex: TextureRect
var _refine_fish_title: Label
var _refine_fish_sub: Label
var _refine_out_title: Label
var _refine_out_bonus: Label
var _refine_stats_box: Control

# Mix view nodes
var _essence_grid: GridContainer
var _essence_empty: Label
var _slot_a_btn: Button
var _slot_b_btn: Button
var _slot_a_tex: TextureRect
var _slot_b_tex: TextureRect
var _slot_a_lbl: Label
var _slot_b_lbl: Label
var _mix_out_title: Label
var _mix_out_note: Label
var _mix_stats_box: Control

# Strengthen view nodes
var _med_grid: GridContainer
var _med_empty: Label
var _str_title: Label
var _str_attr_btns: Array[Button] = []
var _str_adj_btns: Array[Button] = []
var _str_before_box: Control
var _str_after_box: Control


func setup(value: Session) -> void:
	session = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Top workbench strip: inline tabs + resource badges
	UI.panel(self, Rect2(28, 112, 1564, 68), "dark_wood")
	var tab_titles := ["提炼鱼获", "配制复方", "强化成品"]
	for i in 3:
		var btn := UI.tab_button(self, tab_titles[i], Rect2(46 + i * 212, 122, 198, 48), _switch_tab.bind(i), i == 0)
		btn.add_theme_font_size_override("font_size", 21)
		_tab_buttons.append(btn)

	UI.icon_rect(self, UI.ICON_CONCENTRATE, Rect2(1010, 130, 32, 32))
	_stock_concentrate = UI.label(self, "浓缩的灵魂 ×0", Rect2(1048, 124, 210, 44), 20, UI.MINT)
	_stock_bones = UI.label(self, "遗骨 ×0　指骨 ×0", Rect2(1270, 124, 300, 44), 20, UI.GOLD)
	_stock_bones.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_build_refine_tab()
	_build_mix_tab()
	_build_strengthen_tab()

	UI.panel(self, Rect2(28, 906, 1564, 48), "dark_wood")
	_controls_hint = UI.label(self, "", Rect2(48, 912, 946, 36), 18, UI.CREAM)
	_status = UI.label(self, "", Rect2(1002, 912, 570, 36), 18, UI.GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_switch_tab(0)
	refresh()


func _build_refine_tab() -> void:
	var view := Control.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_tab_views.append(view)

	# Left: Visual Fish Basket Grid
	UI.panel(view, Rect2(28, 190, 924, 704), "dark_wood")
	UI.icon_rect(view, UI.ICON_BASKET, Rect2(50, 206, 32, 32))
	UI.label(view, "鱼篓 · WASD 选择鱼获", Rect2(92, 204, 700, 38), 24, UI.GOLD)
	var scroll := UI.create_scroll(view, Rect2(46, 252, 888, 624))
	_fish_grid = GridContainer.new()
	_fish_grid.columns = 3
	_fish_grid.add_theme_constant_override("h_separation", 14)
	_fish_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_fish_grid)
	_fish_empty = UI.label(view, "鱼篓目前空空如也。\n按 Q 前往阿刻戎河垂钓，钓起的鱼会展示在这里。", Rect2(100, 440, 780, 110), 23, UI.MUTED)
	_fish_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fish_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Right: Selected Fish & Output Potion Preview + Confirm Craft
	UI.panel(view, Rect2(970, 190, 622, 704), "dark_wood")
	UI.label(view, "提炼预览", Rect2(996, 204, 300, 38), 24, UI.MINT)

	# Fish showcase frame
	UI.panel(view, Rect2(996, 252, 570, 210), "slot")
	_refine_fish_tex = UI.icon_rect(view, null, Rect2(1026, 266, 510, 134))
	_refine_fish_title = UI.label(view, "未选择鱼获", Rect2(1012, 404, 538, 30), 22, UI.CREAM)
	_refine_fish_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refine_fish_sub = UI.label(view, "请从左侧点击一条钓起的鱼", Rect2(1012, 432, 538, 24), 17, UI.MUTED)
	_refine_fish_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var arrow := UI.label(view, "▼   提炼产出   ▼", Rect2(996, 470, 570, 34), 19, UI.GOLD)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Output potion card with 3 reception icons + numbers
	UI.panel(view, Rect2(996, 510, 570, 272), "hud_wood")
	UI.panel(view, Rect2(1014, 526, 534, 56), "wood_inset")
	UI.icon_rect(view, UI.ICON_ESSENCE, Rect2(1026, 536, 36, 36))
	_refine_out_title = UI.label(view, "—", Rect2(1072, 530, 464, 46), 24, UI.CREAM)
	_refine_out_bonus = UI.label(view, "", Rect2(1016, 588, 530, 30), 18, UI.MINT)
	_refine_out_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_refine_stats_box = Control.new()
	_refine_stats_box.position = Vector2(1014, 624)
	_refine_stats_box.size = Vector2(534, 144)
	_refine_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_refine_stats_box)

	refine_button = UI.button(view, "空格  确认提炼", Rect2(996, 800, 570, 72), _refine, true)
	refine_button.add_theme_font_size_override("font_size", 25)


func _build_mix_tab() -> void:
	var view := Control.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_tab_views.append(view)

	# Left: Owned Essences Grid (showing source fish + vial)
	UI.panel(view, Rect2(28, 190, 924, 704), "dark_wood")
	UI.icon_rect(view, UI.ICON_ESSENCE, Rect2(50, 206, 32, 32))
	UI.label(view, "原液库存 · 选两份原液配制复方", Rect2(92, 204, 740, 38), 24, UI.GOLD)
	var scroll := UI.create_scroll(view, Rect2(46, 252, 888, 624))
	_essence_grid = GridContainer.new()
	_essence_grid.columns = 3
	_essence_grid.add_theme_constant_override("h_separation", 14)
	_essence_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_essence_grid)
	_essence_empty = UI.label(view, "暂无基础原液。\n请先在「提炼鱼获」中把鱼提炼成原液。", Rect2(100, 440, 780, 110), 23, UI.MUTED)
	_essence_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Right: 2 Recipe Slots + Output Potion 3-Icon Preview + Confirm
	UI.panel(view, Rect2(970, 190, 622, 704), "dark_wood")
	UI.label(view, "复方配制台（点击槽位清空）", Rect2(996, 204, 460, 38), 24, UI.MINT)

	_slot_a_btn = Button.new()
	_slot_a_btn.position = Vector2(996, 254)
	_slot_a_btn.size = Vector2(252, 186)
	UI.style_slot_button(_slot_a_btn, false, false)
	_slot_a_btn.pressed.connect(func() -> void:
		mix_first = -1
		_highlight_essences()
		_update_previews()
	)
	view.add_child(_slot_a_btn)
	_slot_a_tex = UI.icon_rect(_slot_a_btn, null, Rect2(26, 22, 200, 104))
	_slot_a_lbl = UI.label(_slot_a_btn, "原液槽 1", Rect2(10, 134, 232, 38), 20, UI.MUTED)
	_slot_a_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var plus := UI.label(view, "+", Rect2(1254, 318, 54, 54), 34, UI.GOLD)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_slot_b_btn = Button.new()
	_slot_b_btn.position = Vector2(1314, 254)
	_slot_b_btn.size = Vector2(252, 186)
	UI.style_slot_button(_slot_b_btn, false, false)
	_slot_b_btn.pressed.connect(func() -> void:
		mix_second = -1
		_highlight_essences()
		_update_previews()
	)
	view.add_child(_slot_b_btn)
	_slot_b_tex = UI.icon_rect(_slot_b_btn, null, Rect2(26, 22, 200, 104))
	_slot_b_lbl = UI.label(_slot_b_btn, "原液槽 2", Rect2(10, 134, 232, 38), 20, UI.MUTED)
	_slot_b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var arrow := UI.label(view, "▼   复方成品   ▼", Rect2(996, 452, 570, 34), 19, UI.GOLD)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UI.panel(view, Rect2(996, 492, 570, 290), "hud_wood")
	UI.panel(view, Rect2(1014, 508, 534, 56), "wood_inset")
	UI.icon_rect(view, UI.ICON_POTION, Rect2(1026, 518, 36, 36))
	_mix_out_title = UI.label(view, "选择两份原液预览", Rect2(1072, 512, 464, 46), 24, UI.CREAM)
	_mix_out_note = UI.label(view, "", Rect2(1016, 570, 530, 32), 18, UI.GOLD)
	_mix_out_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_mix_stats_box = Control.new()
	_mix_stats_box.position = Vector2(1014, 608)
	_mix_stats_box.size = Vector2(534, 158)
	_mix_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_mix_stats_box)

	mix_button = UI.button(view, "F  确认配制复方", Rect2(996, 800, 570, 72), _mix, true)
	mix_button.add_theme_font_size_override("font_size", 25)


func _build_strengthen_tab() -> void:
	var view := Control.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_tab_views.append(view)

	# Left: Unstrengthened Medicine Cards
	UI.panel(view, Rect2(28, 190, 924, 704), "dark_wood")
	UI.icon_rect(view, UI.ICON_CONCENTRATE, Rect2(50, 206, 32, 32))
	UI.label(view, "可强化药剂 · 每剂仅可强化一次", Rect2(92, 204, 740, 38), 24, UI.GOLD)
	var scroll := UI.create_scroll(view, Rect2(46, 252, 888, 624))
	_med_grid = GridContainer.new()
	_med_grid.columns = 2
	_med_grid.add_theme_constant_override("h_separation", 14)
	_med_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_med_grid)
	_med_empty = UI.label(view, "暂无可强化的原液或复方药剂。", Rect2(100, 440, 780, 90), 23, UI.MUTED)
	_med_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Right: Direct Attribute + Sign Toggle Buttons + Preview + Confirm (NO dropdowns!)
	UI.panel(view, Rect2(970, 190, 622, 704), "dark_wood")
	UI.label(view, "强化预览", Rect2(996, 204, 300, 38), 24, UI.MINT)
	UI.panel(view, Rect2(996, 252, 570, 58), "slot")
	_str_title = UI.label(view, "请从左侧选择一剂药", Rect2(1016, 258, 530, 44), 23, UI.CREAM)

	UI.label(view, "选择调整属性", Rect2(996, 326, 280, 30), 19, UI.MUTED)
	for i in 3:
		var btn := Button.new()
		btn.position = Vector2(996 + i * 194, 362)
		btn.size = Vector2(182, 58)
		UI.style_slot_button(btn, i == selected_attribute, false)
		btn.pressed.connect(func() -> void:
			selected_attribute = i
			_update_previews()
		)
		view.add_child(btn)
		UI.icon_rect(btn, UI.STAT_ICONS[i], Rect2(20, 13, 32, 32))
		UI.label(btn, Data.STAT_NAMES[i], Rect2(60, 10, 110, 38), 21, Data.STAT_COLORS[i])
		_str_attr_btns.append(btn)

	UI.label(view, "选择增减方向", Rect2(996, 434, 280, 30), 19, UI.MUTED)
	var adjs := [[1, "+1  提升"], [-1, "-1  降低"]]
	for j in 2:
		var delta_val: int = adjs[j][0]
		var btn := Button.new()
		btn.position = Vector2(996 + j * 292, 470)
		btn.size = Vector2(278, 54)
		UI.style_slot_button(btn, delta_val == selected_adjustment, false)
		btn.pressed.connect(func() -> void:
			selected_adjustment = delta_val
			_update_previews()
		)
		view.add_child(btn)
		var lbl := UI.label(btn, adjs[j][1], Rect2(10, 8, 258, 38), 21, UI.GOOD if delta_val > 0 else UI.WARN)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_str_adj_btns.append(btn)

	UI.panel(view, Rect2(996, 542, 570, 240), "hud_wood")
	UI.label(view, "强化前", Rect2(1018, 554, 160, 30), 18, Color("2b1c1c"), false)
	_str_before_box = Control.new()
	_str_before_box.position = Vector2(1014, 586)
	_str_before_box.size = Vector2(534, 70)
	_str_before_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_str_before_box)

	UI.label(view, "强化后", Rect2(1018, 666, 160, 30), 18, Color("2b1c1c"), false)
	_str_after_box = Control.new()
	_str_after_box.position = Vector2(1014, 698)
	_str_after_box.size = Vector2(534, 70)
	_str_after_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_str_after_box)

	strengthen_button = UI.button(view, "消耗 1 份浓缩的灵魂 · 确认强化", Rect2(996, 800, 570, 72), _strengthen, true)
	strengthen_button.add_theme_font_size_override("font_size", 23)


func _switch_tab(index: int) -> void:
	active_tab = index
	for i in _tab_views.size():
		_tab_views[i].visible = i == active_tab
		UI.set_tab_active(_tab_buttons[i], i == active_tab)
	_controls_hint.text = [
		"WASD 选鱼　空格 提炼　Shift 切换页签　C 返回河岸",
		"WASD 选原液　空格 放入　F 配制　Shift 切换页签　C 撤回／返回",
		"WASD 选药剂　X 切换属性　V 切换增减　空格 强化　Shift 切换页签　C 返回河岸",
	][active_tab]
	_status.text = ""
	_update_previews()


func handle_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_A, KEY_S, KEY_D:
			_move_card(code)
		KEY_SHIFT:
			_switch_tab(posmod(active_tab + 1, _tab_views.size()))
		KEY_SPACE:
			match active_tab:
				0: UI.activate(refine_button)
				1:
					if not essence_cards.is_empty():
						UI.activate(essence_cards[_essence_cursor])
				2: UI.activate(strengthen_button)
		KEY_F:
			if active_tab != 1:
				return false
			UI.activate(mix_button)
		KEY_X, KEY_V:
			if active_tab != 2:
				return false
			if code == KEY_X:
				UI.activate(_str_attr_btns[posmod(selected_attribute + 1, _str_attr_btns.size())])
			else:
				UI.activate(_str_adj_btns[1 if selected_adjustment == 1 else 0])
		KEY_C:
			if active_tab != 1 or (mix_first < 0 and mix_second < 0):
				return false
			UI.activate(_slot_b_btn if mix_second >= 0 else _slot_a_btn)
		_:
			return false
	return true


func _move_card(code: Key) -> void:
	var cards: Array[Button] = [fish_cards, essence_cards, medicine_cards][active_tab]
	if cards.is_empty():
		return
	var grid: GridContainer = [_fish_grid, _essence_grid, _med_grid][active_tab]
	var index := _essence_cursor if active_tab == 1 else 0
	if active_tab != 1:
		var selected: Variant = selected_fish_id if active_tab == 0 else selected_medicine
		for i in cards.size():
			if cards[i].get_meta("item") == selected:
				index = i
				break
	var last := cards.size() - 1
	match code:
		KEY_W: index = index - grid.columns if index >= grid.columns else index
		KEY_S: index = mini(index + grid.columns, last) if index - index % grid.columns + grid.columns <= last else index
		KEY_A: index = index - 1 if index % grid.columns > 0 else index
		KEY_D: index = index + 1 if index < last and index % grid.columns < grid.columns - 1 else index
	if active_tab == 1:
		_essence_cursor = index
		_highlight_essences()
	else:
		UI.activate(cards[index])
	UI.reveal(grid.get_parent() as ScrollContainer, cards[index])


static func medicine_rows(session_value: Session, only_unstrengthened: bool = false) -> Array:
	var rows: Array = []
	for species in session_value.essences.size():
		if session_value.essences[species] > 0:
			rows.append(["%s ×%d" % [Data.FISH[species]["essence"], session_value.essences[species]], [true, species]])
	for potion in session_value.potions:
		if not only_unstrengthened or potion.attribute < 0:
			var title: String = potion.name
			if potion.attribute >= 0:
				title += "（%s %s%d）" % [Data.STAT_NAMES[potion.attribute], "+" if potion.adjustment > 0 else "", potion.adjustment]
			rows.append([title, [false, potion.id]])
	return rows


func refresh() -> void:
	if session == null:
		return
	var essence_total := 0
	for count in session.essences:
		essence_total += count
	var med_rows := medicine_rows(session, true)
	_tab_buttons[0].text = "提炼鱼获 (%d)" % session.catches.size()
	_tab_buttons[1].text = "配制复方 (%d)" % essence_total
	_tab_buttons[2].text = "强化成品 (%d)" % med_rows.size()
	_stock_concentrate.text = "浓缩的灵魂 ×%d" % session.concentrate
	_stock_bones.text = "遗骨 ×%d　指骨 ×%d" % [session.recovered_bones, session.finger_bones]

	# Validate selections
	var fish_found := false
	for catch in session.catches:
		if int(catch.id) == selected_fish_id:
			fish_found = true
			break
	if not fish_found:
		selected_fish_id = int(session.catches[0].id) if not session.catches.is_empty() else -1

	if mix_first >= 0 and session.essences[mix_first] <= 0:
		mix_first = -1
	if mix_second >= 0 and session.essences[mix_second] <= 0:
		mix_second = -1
	if mix_first >= 0 and mix_first == mix_second and session.essences[mix_first] < 2:
		mix_second = -1

	var med_valid := false
	if selected_medicine != null:
		for row in med_rows:
			if row[1] == selected_medicine:
				med_valid = true
				break
	if not med_valid:
		selected_medicine = med_rows[0][1] if not med_rows.is_empty() else null

	_rebuild_fish_grid()
	_rebuild_essence_grid()
	_rebuild_medicine_grid(med_rows)
	_update_previews()


func _rebuild_fish_grid() -> void:
	UI.clear_cards(_fish_grid)
	fish_cards.clear()
	_fish_empty.visible = session.catches.is_empty()
	for catch in session.catches:
		var cid: int = int(catch.id)
		var species: int = int(catch.species)
		var fish_size: int = int(catch.size)
		var card := Button.new()
		card.custom_minimum_size = Vector2(282, 184)
		card.set_meta("item", cid)
		UI.style_slot_button(card, cid == selected_fish_id, false)
		card.pressed.connect(func() -> void:
			selected_fish_id = cid
			for fish_card in fish_cards:
				UI.style_slot_button(fish_card, fish_card == card, false)
			_update_previews()
		)
		_fish_grid.add_child(card)
		fish_cards.append(card)

		# Crisp water-backdrop fish portrait using Feishu fish art!
		var art_bg := ColorRect.new()
		art_bg.position = Vector2(14, 14)
		art_bg.size = Vector2(254, 102)
		art_bg.color = Color("182633")
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art_bg)
		UI.icon_rect(card, Data.fish_texture(species, fish_size), Rect2(22, 18, 238, 94))

		# Yield badge in top-right corner
		var yield_count := Session.yield_for(catch)
		var badge_text := "×%d" % yield_count
		if species == Data.LANTERN and fish_size == 0:
			badge_text += "+魂"
		var badge := UI.label(card, badge_text, Rect2(180, 14, 84, 26), 16, UI.GOLD)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var name_lbl := UI.label(card, Data.fish_name(species, fish_size), Rect2(14, 120, 254, 28), 20, UI.CREAM)
		name_lbl.clip_text = true
		var size_lbl := UI.label(card, Data.size_label(catch), Rect2(14, 148, 254, 24), 16, UI.MINT)
		size_lbl.clip_text = true


func _rebuild_essence_grid() -> void:
	UI.clear_cards(_essence_grid)
	essence_cards.clear()
	for species in session.essences.size():
		var count := session.essences[species]
		if count <= 0:
			continue
		var fish: Dictionary = Data.FISH[species]
		var card := Button.new()
		card.custom_minimum_size = Vector2(282, 152)
		card.set_meta("item", species)
		var index := essence_cards.size()
		card.pressed.connect(func() -> void:
			_essence_cursor = index
			_pick_essence(species)
		)
		_essence_grid.add_child(card)
		essence_cards.append(card)

		UI.icon_rect(card, Data.fish_texture(species, 1), Rect2(16, 16, 124, 62))
		UI.icon_rect(card, UI.ICON_ESSENCE, Rect2(146, 20, 28, 28))
		var title := UI.label(card, str(fish.essence), Rect2(178, 16, 94, 34), 19, UI.CREAM)
		title.clip_text = true
		var stock_lbl := UI.label(card, "库存 ×%d" % count, Rect2(146, 52, 124, 26), 17, UI.GOLD)
		stock_lbl.clip_text = true
		var eff := UI.make_effect_row(fish.effect, 22, 18, false)
		eff.position = Vector2(18, 96)
		card.add_child(eff)
		var pointer := UI.label(card, "▶", Rect2(250, 112, 22, 28), 18, UI.GOLD)
		pointer.name = "SelectionPointer"
	_essence_empty.visible = essence_cards.is_empty()
	_essence_cursor = clampi(_essence_cursor, 0, maxi(essence_cards.size() - 1, 0))
	_highlight_essences()


func _highlight_essences() -> void:
	for i in essence_cards.size():
		var card := essence_cards[i]
		var species: int = card.get_meta("item")
		UI.style_slot_button(card, species == mix_first or species == mix_second, false)
		card.get_node("SelectionPointer").visible = i == _essence_cursor


func _pick_essence(species: int) -> void:
	if mix_first < 0:
		mix_first = species
	elif mix_second < 0:
		if species == mix_first and session.essences[species] < 2:
			_status.text = "同种原液配制需要至少 2 份库存。"
			return
		mix_second = species
	else:
		mix_first = mix_second
		if species == mix_first and session.essences[species] < 2:
			mix_second = -1
			_status.text = "同种原液配制需要至少 2 份库存。"
		else:
			mix_second = species
	_highlight_essences()
	_update_previews()


func _rebuild_medicine_grid(med_rows: Array) -> void:
	UI.clear_cards(_med_grid)
	medicine_cards.clear()
	_med_empty.visible = med_rows.is_empty()
	for row in med_rows:
		var key: Array = row[1]
		var dose := session.dose(key[0], key[1])
		if dose.is_empty():
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(430, 102)
		card.set_meta("item", key)
		UI.style_slot_button(card, selected_medicine == key, false)
		card.pressed.connect(func() -> void:
			selected_medicine = key
			for medicine_card in medicine_cards:
				UI.style_slot_button(medicine_card, medicine_card == card, false)
			_update_previews()
		)
		_med_grid.add_child(card)
		medicine_cards.append(card)
		UI.icon_rect(card, UI.ICON_ESSENCE if key[0] else UI.ICON_POTION, Rect2(16, 18, 36, 36))
		var lbl := UI.label(card, str(row[0]), Rect2(60, 16, 354, 34), 20, UI.CREAM)
		lbl.clip_text = true
		var eff := UI.make_effect_row(dose.effect, 22, 18, false)
		eff.position = Vector2(60, 56)
		card.add_child(eff)


func _populate_big_stat_cards(container: Control, effect: Variant, highlight_stat: int = -1, compact: bool = false) -> void:
	for child in container.get_children():
		child.queue_free()
	var card_w := 168.0
	var card_h := 66.0 if compact else 128.0
	var gap := 15.0
	for i in 3:
		var x := i * (card_w + gap)
		var slot_variant := "slot_selected" if highlight_stat == i else "wood_inset"
		var box := UI.panel(container, Rect2(x, 0, card_w, card_h), slot_variant)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if compact:
			UI.icon_rect(box, UI.STAT_ICONS[i], Rect2(14, 15, 34, 34))
			var txt := "—"
			var col := UI.MUTED
			if effect is Vector3i:
				var val: int = effect[i]
				txt = "+%d" % val if val > 0 else str(val)
				col = Data.STAT_COLORS[i] if val > 0 else (UI.WARN if val < 0 else Color(UI.MUTED, 0.7))
				if highlight_stat == i:
					col = UI.GOLD
			var val_lbl := UI.label(box, txt, Rect2(54, 12, 100, 40), 26, col)
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			UI.icon_rect(box, UI.STAT_ICONS[i], Rect2((card_w - 42.0) * 0.5, 14, 42, 42))
			var name_lbl := UI.label(box, Data.STAT_NAMES[i], Rect2(8, 58, card_w - 16, 24), 17, UI.MUTED)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var txt := "—"
			var col := UI.MUTED
			if effect is Vector3i:
				var val: int = effect[i]
				txt = "+%d" % val if val > 0 else str(val)
				col = Data.STAT_COLORS[i] if val > 0 else (UI.WARN if val < 0 else Color(UI.MUTED, 0.65))
			var val_lbl := UI.label(box, txt, Rect2(8, 82, card_w - 16, 38), 28, col)
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _update_previews() -> void:
	# 1. Refine preview
	var selected_catch: Dictionary = {}
	for catch in session.catches:
		if int(catch.id) == selected_fish_id:
			selected_catch = catch
			break
	if selected_catch.is_empty():
		_refine_fish_tex.texture = null
		_refine_fish_title.text = "未选择鱼获"
		_refine_fish_sub.text = "点击左侧鱼篓中的鱼预览药效"
		_refine_out_title.text = "等待选择鱼获"
		_refine_out_bonus.text = ""
		_populate_big_stat_cards(_refine_stats_box, null)
	else:
		var species: int = int(selected_catch.species)
		var fsize: int = int(selected_catch.size)
		var fish: Dictionary = Data.FISH[species]
		_refine_fish_tex.texture = Data.fish_texture(species, fsize)
		_refine_fish_title.text = Data.fish_name(species, fsize)
		_refine_fish_sub.text = Data.size_label(selected_catch)
		_refine_out_title.text = "%s ×%d" % [fish.essence, Session.yield_for(selected_catch)]
		_refine_out_bonus.text = "额外产出：浓缩的灵魂 ×1" if species == Data.LANTERN and fsize == 0 else "每份药剂数值预览"
		_populate_big_stat_cards(_refine_stats_box, fish.effect)
	refine_button.disabled = session.paused or selected_catch.is_empty()

	# 2. Mix preview
	if mix_first >= 0:
		_slot_a_tex.texture = Data.fish_texture(mix_first, 1)
		_slot_a_lbl.text = str(Data.FISH[mix_first]["essence"])
		_slot_a_lbl.add_theme_color_override("font_color", UI.CREAM)
		UI.style_slot_button(_slot_a_btn, true, false)
	else:
		_slot_a_tex.texture = null
		_slot_a_lbl.text = "原液槽 1"
		_slot_a_lbl.add_theme_color_override("font_color", UI.MUTED)
		UI.style_slot_button(_slot_a_btn, false, false)

	if mix_second >= 0:
		_slot_b_tex.texture = Data.fish_texture(mix_second, 1)
		_slot_b_lbl.text = str(Data.FISH[mix_second]["essence"])
		_slot_b_lbl.add_theme_color_override("font_color", UI.CREAM)
		UI.style_slot_button(_slot_b_btn, true, false)
	else:
		_slot_b_tex.texture = null
		_slot_b_lbl.text = "原液槽 2"
		_slot_b_lbl.add_theme_color_override("font_color", UI.MUTED)
		UI.style_slot_button(_slot_b_btn, false, false)

	var recipe := Data.recipe(mix_first, mix_second) if mix_first >= 0 and mix_second >= 0 else {}
	if recipe.is_empty():
		_mix_out_title.text = "请放入两份原液"
		_mix_out_note.text = "按空格将选中的原液放入槽位"
		_populate_big_stat_cards(_mix_stats_box, null)
	else:
		_mix_out_title.text = "%s ×1" % recipe.name
		_mix_out_note.text = ("特殊反应：" + str(recipe.reaction)) if not str(recipe.reaction).is_empty() else "复方成品数值预览"
		_populate_big_stat_cards(_mix_stats_box, recipe.effect)
	mix_button.disabled = session.paused or recipe.is_empty() or not session.can_mix(mix_first, mix_second)

	# 3. Strengthen preview
	for i in 3:
		UI.style_slot_button(_str_attr_btns[i], i == selected_attribute, false)
	UI.style_slot_button(_str_adj_btns[0], selected_adjustment == 1, false)
	UI.style_slot_button(_str_adj_btns[1], selected_adjustment == -1, false)

	if selected_medicine == null:
		_str_title.text = "暂无可强化的药剂"
		_populate_big_stat_cards(_str_before_box, null, -1, true)
		_populate_big_stat_cards(_str_after_box, null, -1, true)
	else:
		var dose := session.dose(selected_medicine[0], selected_medicine[1])
		if dose.is_empty():
			_str_title.text = "暂无可强化的药剂"
			_populate_big_stat_cards(_str_before_box, null, -1, true)
			_populate_big_stat_cards(_str_after_box, null, -1, true)
		else:
			var after_eff: Vector3i = dose.effect
			after_eff[selected_attribute] += selected_adjustment
			_str_title.text = str(dose.name)
			_populate_big_stat_cards(_str_before_box, dose.effect, -1, true)
			_populate_big_stat_cards(_str_after_box, after_eff, selected_attribute, true)
	strengthen_button.disabled = session.paused or selected_medicine == null or session.concentrate == 0


func _refine() -> void:
	if selected_fish_id >= 0 and session.refine(selected_fish_id):
		_status.text = "提炼完成，原液已入库。"


func _mix() -> void:
	if not mix_button.disabled:
		var recipe := Data.recipe(mix_first, mix_second)
		if not session.mix(mix_first, mix_second):
			return
		_status.text = "配制完成，获得 %s ×1。" % recipe.name


func _strengthen() -> void:
	if selected_medicine != null and session.strengthen(selected_medicine[0], selected_medicine[1], selected_attribute, selected_adjustment):
		_status.text = "强化完成，已更新一剂药效。"
