extends Control

signal tab_changed
## Visual pixel-art alchemy workbench: zero dropdowns, full Feishu fish art,
## and reception-consistent 3-icon attribute previews.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const UI := preload("res://scripts/demo/demo_ui.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")

var session: Session
var active_tab: int = 0
var selected_medicine: Variant = null
var selected_attribute: int = 0
var selected_adjustment: int = 1

var mix_button: Button
var strengthen_button: Button
var essence_cards: Array[Button] = []
var medicine_cards: Array[Button] = []

var _tab_buttons: Array[Button] = []
var _tab_views: Array[Control] = []
var _stock_concentrate: Label
var _stock_bones: Label
var _status: Label
var _controls_hint: Label
var _audio: Audio
var selected_source := 1
var _outcomes: Control
var _source_title: Label
var _source_note: Label
var _source_indices: Array[int] = []

# Brewing view nodes
var _essence_grid: GridContainer

# Strengthen view nodes
var _med_grid: GridContainer
var _med_empty: Label
var _str_title: Label
var _str_attr_btns: Array[Button] = []
var _str_adj_btns: Array[Button] = []
var _str_before_box: Control
var _str_after_box: Control


func setup(value: Session, audio: Audio) -> void:
	session = value
	_audio = audio
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Top workbench strip: inline tabs + resource badges
	UI.panel(self, Rect2(28, 112, 1564, 68), "dark_wood")
	var tab_titles := ["纯炼制药", "强化成品"]
	for i in 2:
		var btn := UI.tab_button(self, tab_titles[i], Rect2(46 + i * 212, 122, 198, 48), _switch_tab.bind(i), i == 0)
		btn.add_theme_font_size_override("font_size", 21)
		_tab_buttons.append(btn)

	UI.icon_rect(self, UI.ICON_CONCENTRATE, Rect2(1010, 130, 32, 32))
	_stock_concentrate = UI.label(self, "浓缩的灵魂 ×0", Rect2(1048, 124, 210, 44), 20, UI.MINT)
	_stock_bones = UI.label(self, "每炉 3 份 → 1 剂", Rect2(1270, 124, 300, 44), 20, UI.GOLD)
	_stock_bones.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_build_brew_tab()
	_build_strengthen_tab()

	UI.panel(self, Rect2(28, 906, 1564, 48), "dark_wood")
	_controls_hint = UI.label(self, "", Rect2(48, 912, 946, 36), 18, UI.CREAM)
	_status = UI.label(self, "", Rect2(1002, 912, 570, 36), 18, UI.GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_switch_tab(0)
	refresh()


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
	_med_empty = UI.label(view, "暂无可强化的成品药。", Rect2(100, 440, 780, 90), 23, UI.MUTED)
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
	if index != active_tab:
		_audio.play(Audio.Cue.PAGE_TURN)
	active_tab = clampi(index, 0, 1)
	for i in _tab_views.size():
		_tab_views[i].visible = i == active_tab
		UI.set_tab_active(_tab_buttons[i], i == active_tab)
	_controls_hint.text = "WASD 选原液　空格／F 炼制　Shift 切换页签　C 返回河岸" if active_tab == 0 else "WASD 选药　X 切属性　V 切增减　空格 强化　Shift 切换页签　C 返回"
	_status.text = ""
	_update_previews()
	tab_changed.emit()


func handle_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_A, KEY_S, KEY_D:
			_move_card(code)
		KEY_SHIFT:
			_switch_tab(1 - active_tab)
		KEY_SPACE, KEY_F:
			UI.activate(mix_button if active_tab == 0 else strengthen_button)
		KEY_X:
			if active_tab != 1:
				return false
			selected_attribute = (selected_attribute + 1) % 3
			_update_previews()
		KEY_V:
			if active_tab != 1:
				return false
			selected_adjustment *= -1
			_update_previews()
		_:
			return false
	return true


func _move_card(code: Key) -> void:
	var cards: Array[Button] = essence_cards if active_tab == 0 else medicine_cards
	var grid: GridContainer = _essence_grid if active_tab == 0 else _med_grid
	if cards.is_empty():
		return
	var index := 0
	for i in cards.size():
		if cards[i].get_meta("item") == (selected_source if active_tab == 0 else selected_medicine):
			index = i
	var next := index
	match code:
		KEY_W: next = maxi(0, index - grid.columns)
		KEY_S: next = mini(cards.size() - 1, index + grid.columns)
		KEY_A: next = maxi(0, index - 1)
		KEY_D: next = mini(cards.size() - 1, index + 1)
	UI.activate(cards[next])
	UI.reveal(grid.get_parent() as ScrollContainer, cards[next])


static func medicine_rows(session_value: Session, only_unstrengthened: bool = false) -> Array:
	var rows: Array = []
	for potion in session_value.potions:
		if only_unstrengthened and potion.attribute >= 0:
			continue
		var title: String = potion.name
		if potion.attribute >= 0:
			title += "（%s %+d）" % [Data.STAT_NAMES[potion.attribute], potion.adjustment]
		rows.append([title, [false, potion.id]])
	return rows


func refresh() -> void:
	if session == null:
		return
	_stock_concentrate.text = "浓缩的灵魂 ×%d" % session.concentrate
	var total := 0
	for count in session.essences:
		total += count
	_stock_bones.text = "原液 %d 份　成品 %d 剂" % [total, session.potions.size()]
	var rows := medicine_rows(session, true)
	var valid := false
	for row in rows:
		valid = valid or row[1] == selected_medicine
	if not valid:
		selected_medicine = rows[0][1] if not rows.is_empty() else null
	UI.clear_cards(_essence_grid)
	essence_cards.clear()
	_source_indices = Data.essence_indices()
	for source in _source_indices:
		var data: Dictionary = Data.source_data(source)
		var card := UI.button(_essence_grid, "", Rect2(0, 0, 280, 166), _select_source.bind(source))
		card.custom_minimum_size = Vector2(280, 166)
		card.set_meta("item", source)
		UI.style_slot_button(card, source == selected_source, false)
		var specimen: int = Data.STILLFIN if source == 7 else source
		UI.icon_rect(card, Data.fish_texture(specimen), Rect2(60, 8, 160, 76))
		UI.label(card, "%s ×%d" % [data.essence, session.essences[source]], Rect2(14, 86, 254, 32), 20, UI.CREAM)
		UI.label(card, "%d级材料 · 可炼 %d 剂" % [data.tier, session.essences[source] / 3], Rect2(14, 124, 254, 24), 17, UI.GOLD)
		essence_cards.append(card)
	_rebuild_medicine_grid(rows)
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
			_audio.play(Audio.Cue.ESSENCE_SELECT if key[0] else Audio.Cue.MEDICINE_SELECT)
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
	if _source_title == null:
		return
	var source: Dictionary = Data.source_data(selected_source)
	_source_title.text = "%s · %d级材料" % [source.essence, source.tier]
	_source_note.text = "消耗同种原液 3 份，每炉必得一剂成品。\n库存 %d 份，可炼 %d 剂，尾料 %d 份。" % [session.essences[selected_source], session.essences[selected_source] / 3, session.essences[selected_source] % 3]
	for child in _outcomes.get_children():
		_outcomes.remove_child(child)
		child.queue_free()
	var row := 0
	for outcome in source.outcomes:
		var potion: Dictionary = Data.POTIONS[outcome[0]]
		var known: bool = session.codex_sources.get(Data.FISH[selected_source].id, {}).get(potion.id, false)
		var card := UI.panel(_outcomes, Rect2(0, row * 170, 570, 154), "hud_wood")
		UI.icon_rect(card, UI.ICON_POTION, Rect2(16, 18, 42, 42))
		UI.label(card, "%s · %d级" % [potion.name, potion.tier], Rect2(72, 12, 300, 40), 24, UI.GOLD)
		UI.label(card, "%d%%" % outcome[1] if known else "概率待发现", Rect2(380, 16, 174, 32), 18, UI.MINT)
		var effects := UI.make_effect_row(potion.effect, 28, 21, false)
		effects.position = Vector2(24, 86)
		card.add_child(effects)
		row += 1
	mix_button.disabled = session.paused or not session.can_brew(selected_source)
	for i in 3:
		UI.style_slot_button(_str_attr_btns[i], i == selected_attribute, false)
	UI.style_slot_button(_str_adj_btns[0], selected_adjustment == 1, false)
	UI.style_slot_button(_str_adj_btns[1], selected_adjustment == -1, false)
	var medicine: Dictionary = {} if selected_medicine == null else session.dose(false, selected_medicine[1])
	_str_title.text = str(medicine.get("name", "暂无可强化成品"))
	_populate_big_stat_cards(_str_before_box, medicine.get("effect"), -1, true)
	var after: Variant = medicine.get("effect")
	if after != null:
		after[selected_attribute] += selected_adjustment
	_populate_big_stat_cards(_str_after_box, after, selected_attribute, true)
	strengthen_button.disabled = session.paused or medicine.is_empty() or session.concentrate <= 0


func _strengthen() -> void:
	if selected_medicine != null and session.strengthen(selected_medicine[0], selected_medicine[1], selected_attribute, selected_adjustment):
		_audio.play(Audio.Cue.STRENGTHEN)
		_status.text = "强化完成，已更新一剂药效。"


func _build_brew_tab() -> void:
	var view := Control.new()
	view.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(view)
	_tab_views.append(view)
	UI.panel(view, Rect2(28, 190, 924, 704), "dark_wood")
	UI.label(view, "原液库存 · 鱼获捕获后自动入库", Rect2(50, 204, 880, 38), 24, UI.GOLD)
	var scroll := UI.create_scroll(view, Rect2(46, 252, 888, 624))
	_essence_grid = GridContainer.new()
	_essence_grid.columns = 3
	_essence_grid.add_theme_constant_override("h_separation", 14)
	_essence_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_essence_grid)
	UI.panel(view, Rect2(970, 190, 622, 704), "dark_wood")
	_source_title = UI.label(view, "", Rect2(996, 206, 570, 42), 26, UI.MINT)
	_source_note = UI.label(view, "", Rect2(996, 268, 570, 86), 20, UI.CREAM)
	UI.label(view, "可能产物 · 药效固定", Rect2(996, 378, 570, 36), 22, UI.GOLD)
	_outcomes = Control.new()
	_outcomes.position = Vector2(996, 430)
	view.add_child(_outcomes)
	mix_button = UI.button(view, "空格 / F  消耗 3 份原液炼制", Rect2(996, 800, 570, 72), _brew, true)
	mix_button.add_theme_font_size_override("font_size", 24)


func _select_source(source: int) -> void:
	selected_source = source
	_audio.play(Audio.Cue.ESSENCE_SELECT)
	for card in essence_cards:
		UI.style_slot_button(card, card.get_meta("item") == source, false)
	_update_previews()


func _brew() -> void:
	if session.brew(selected_source):
		_audio.play(Audio.Cue.BREW)
		_status.text = "炼制完成：%s ×1" % session.potions[-1].name
