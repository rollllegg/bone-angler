extends Control
## Octopath Traveler 2 inspired pixel-art shop:
## Left category filter rail | Center sorted ware list with category icons |
## Top-right Ferryman Coin wallet + Selected ware checkout + Current rig status.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const UI := preload("res://scripts/demo/demo_ui.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")

enum Filter { ALL, ROD, HOOK, CHARM, BAIT, REPAIR }

const FILTER_META := [
	{"id": Filter.ALL, "label": "全部", "watermark": "ALL", "title": "全部商品", "icon": null},
	{"id": Filter.ROD, "label": "竿体", "watermark": "RODS", "title": "竿体", "icon": UI.ICON_ROD},
	{"id": Filter.HOOK, "label": "鱼钩", "watermark": "HOOKS", "title": "鱼钩", "icon": UI.ICON_HOOK},
	{"id": Filter.CHARM, "label": "挂件", "watermark": "CHARMS", "title": "钓具挂件", "icon": UI.ICON_CONCENTRATE},
	{"id": Filter.BAIT, "label": "鱼饵", "watermark": "BAITS", "title": "鱼饵补给", "icon": UI.ICON_BAIT},
	{"id": Filter.REPAIR, "label": "维修", "watermark": "REPAIR", "title": "钓组维修", "icon": UI.ICON_WRENCH},
]
const DEVICE_DESCS := [
	"浅水区基础骨竿 · 1 个指骨挂槽",
	"深水长杆 · 2 个指骨挂槽，可钓深水鱼与异变种",
	"偏向钓起小型鱼获",
	"偏向钓起正常体型鱼获",
	"偏向钓起大型鱼获",
	"每件扩大拉鱼判定窗口 10%，按竿体槽位自动装配。",
]
const QUANTITIES := [1, 5, 10]

var fishing: Fishing
var active_filter: int = Filter.ALL
var selected_key: String = "device:1"
var selected_quantity: int = 1
var browsing_wares := false

var filter_buttons: Array[Button] = []
var ware_buttons: Array[Button] = []
var action_button: Button

var _filter_pointer: Label
var _list_title: Label
var _list_watermark: Label
var _ware_scroll: ScrollContainer
var _ware_list: VBoxContainer
var _wallet_value: Label

# Right detail / checkout nodes
var _detail_icon: TextureRect
var _detail_cat: Label
var _detail_name: Label
var _detail_desc: Label
var _detail_meta: Label
var _qty_row: Control
var _qty_buttons: Array[Button] = []
var _durability_box: Control
var _durability_bar: Control
var _cost_value: Label

# Right current rig summary nodes (like Octopath party column)
var _rig_lines: Array[Label] = []
var _rig_mini_bar: Control

var _status: Label
var _controls_hint: Label
var _catalog: Array[Dictionary] = []
var _audio: Audio


func setup(value: Fishing, audio: Audio) -> void:
	fishing = value
	_audio = audio
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_build_left_rail()
	_build_center_list()
	_build_right_column()

	# Bottom Octopath-style slim hint bar
	var bot_bar := Panel.new()
	bot_bar.position = Vector2(28, 906)
	bot_bar.size = Vector2(1564, 48)
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_bar.add_theme_stylebox_override("panel", _translucent_box(Color("12101e", 0.92), Color("9a7750")))
	add_child(bot_bar)
	_controls_hint = UI.label(self, "", Rect2(50, 912, 720, 36), 18, UI.CREAM)
	_status = UI.label(self, "", Rect2(780, 912, 790, 36), 18, UI.GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	reset_to_all()


func reset_to_all() -> void:
	active_filter = Filter.ALL
	selected_key = "device:1"
	selected_quantity = 1
	browsing_wares = false
	_ware_scroll.scroll_vertical = 0
	_status.text = ""
	refresh()


func handle_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_S:
			var step := 1 if code == KEY_S else -1
			if browsing_wares:
				var items := _filtered_catalog()
				for i in items.size():
					if items[i]["key"] == selected_key:
						var next := posmod(i + step, items.size())
						if next != i:
							_audio.play(Audio.Cue.UI_CLICK)
						selected_key = items[next]["key"]
						refresh()
						break
			else:
				select_filter(posmod(active_filter + step, FILTER_META.size()))
		KEY_SPACE:
			if browsing_wares:
				UI.activate(action_button)
			else:
				_audio.play(Audio.Cue.UI_CLICK)
				browsing_wares = true
				refresh()
		KEY_A, KEY_D:
			if not browsing_wares or not _qty_row.visible:
				return false
			var step := 1 if code == KEY_D else -1
			var index := posmod(QUANTITIES.find(selected_quantity) + step, QUANTITIES.size())
			UI.activate(_qty_buttons[index])
		KEY_C:
			if not browsing_wares:
				return false
			_audio.play(Audio.Cue.UI_CLICK)
			browsing_wares = false
			refresh()
		_:
			return false
	return true


func select_filter(filter_id: int) -> void:
	if filter_id != active_filter or browsing_wares:
		_audio.play(Audio.Cue.UI_CLICK)
	active_filter = filter_id
	browsing_wares = false
	_ware_scroll.scroll_vertical = 0
	refresh()


func select_device(index: int) -> void:
	selected_key = "device:%d" % clampi(index, 0, Data.DEVICES.size() - 1)
	if active_filter != Filter.ALL:
		active_filter = _device_filter(index)
	refresh()


func select_bait(index: int) -> void:
	selected_key = "bait:%d" % clampi(index, 0, Data.BAITS.size() - 1)
	if active_filter != Filter.ALL and active_filter != Filter.BAIT:
		active_filter = Filter.BAIT
	refresh()


func select_repair(full: bool = true) -> void:
	selected_key = "repair:full" if full else "repair:quick"
	if active_filter != Filter.ALL and active_filter != Filter.REPAIR:
		active_filter = Filter.REPAIR
	refresh()


func _translucent_box(bg: Color, border: Color, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(8)
	return sb


func _build_left_rail() -> void:
	var rail := Panel.new()
	rail.position = Vector2(28, 112)
	rail.size = Vector2(126, 782)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_theme_stylebox_override("panel", _translucent_box(Color("110f1d", 0.90), Color("8f6a46")))
	add_child(rail)

	_filter_pointer = UI.label(self, "▶", Rect2(32, 134, 24, 72), 20, UI.GOLD)
	_filter_pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for i in FILTER_META.size():
		var meta: Dictionary = FILTER_META[i]
		var top := 130.0 + i * 96.0
		var btn := Button.new()
		btn.position = Vector2(54, top)
		btn.size = Vector2(88, 82)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(select_filter.bind(int(meta["id"])))
		add_child(btn)
		filter_buttons.append(btn)

		if meta["icon"] == null:
			var all_lbl := UI.label(btn, "ALL", Rect2(4, 10, 80, 34), 22, UI.GOLD)
			all_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			UI.icon_rect(btn, meta["icon"], Rect2(26, 10, 36, 36))
		var sub := UI.label(btn, str(meta["label"]), Rect2(4, 48, 80, 26), 16, UI.CREAM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_center_list() -> void:
	var list_panel := Panel.new()
	list_panel.position = Vector2(162, 112)
	list_panel.size = Vector2(906, 782)
	list_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_panel.add_theme_stylebox_override("panel", _translucent_box(Color("141222", 0.86), Color("a67c52")))
	add_child(list_panel)

	# Octopath-style subtle watermark + category heading
	_list_watermark = UI.label(self, "ALL", Rect2(780, 118, 268, 56), 40, Color(UI.CREAM, 0.14), false)
	_list_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_list_title = UI.label(self, "全部商品", Rect2(188, 124, 420, 42), 25, UI.GOLD)

	# Column header row + crisp thin separator
	UI.label(self, "商品名称", Rect2(228, 174, 420, 28), 16, UI.MUTED)
	var h_stock := UI.label(self, "持有 / 状态", Rect2(686, 174, 146, 28), 16, UI.MUTED)
	h_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var h_price := UI.label(self, "价格", Rect2(860, 174, 172, 28), 16, UI.MUTED)
	h_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var line := ColorRect.new()
	line.position = Vector2(182, 206)
	line.size = Vector2(866, 2)
	line.color = Color("99744d", 0.75)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	_ware_scroll = UI.create_scroll(self, Rect2(176, 214, 880, 666))
	_ware_list = VBoxContainer.new()
	_ware_list.add_theme_constant_override("separation", 4)
	_ware_scroll.add_child(_ware_list)


func _build_right_column() -> void:
	# 1. Top-Right Wallet (Octopath style + User's Ferryman Coin icon!)
	UI.panel(self, Rect2(1082, 112, 510, 96), "dark_wood")
	UI.icon_rect(self, UI.ICON_COIN, Rect2(1106, 128, 64, 64))
	UI.label(self, "渡魂币", Rect2(1184, 124, 140, 28), 17, UI.MUTED)
	_wallet_value = UI.label(self, "40", Rect2(1184, 148, 382, 46), 34, UI.GOLD)
	_wallet_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 2. Middle-Right Selected Ware Detail & Checkout
	UI.panel(self, Rect2(1082, 218, 510, 428), "dark_wood")
	UI.panel(self, Rect2(1104, 236, 466, 134), "slot")
	_detail_icon = UI.icon_rect(self, UI.ICON_ROD, Rect2(1122, 250, 128, 104))
	_detail_cat = UI.label(self, "竿体", Rect2(1264, 250, 286, 26), 16, UI.MINT)
	_detail_name = UI.label(self, "", Rect2(1264, 278, 286, 38), 24, UI.GOLD)
	_detail_name.clip_text = true
	_detail_meta = UI.label(self, "", Rect2(1264, 320, 286, 32), 17, UI.CREAM)
	_detail_meta.clip_text = true

	_detail_desc = UI.label(self, "", Rect2(1108, 382, 458, 56), 18, UI.CREAM)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

	# Quantity selector row (visible when selecting a bait)
	_qty_row = Control.new()
	_qty_row.position = Vector2(1104, 448)
	_qty_row.size = Vector2(466, 56)
	_qty_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_qty_row)
	UI.label(_qty_row, "数量", Rect2(4, 8, 66, 40), 19, UI.MUTED)
	for i in QUANTITIES.size():
		var qty: int = QUANTITIES[i]
		var qbtn := Button.new()
		qbtn.position = Vector2(76 + i * 132, 2)
		qbtn.size = Vector2(122, 50)
		qbtn.text = "×%d" % qty
		qbtn.add_theme_font_size_override("font_size", 20)
		qbtn.add_theme_color_override("font_color", UI.CREAM)
		UI.style_slot_button(qbtn, qty == selected_quantity, false)
		qbtn.pressed.connect(func() -> void:
			if qty != selected_quantity:
				_audio.play(Audio.Cue.UI_CLICK)
			selected_quantity = qty
			refresh()
		)
		_qty_row.add_child(qbtn)
		_qty_buttons.append(qbtn)

	# Durability bar (visible when selecting a repair item)
	_durability_box = Control.new()
	_durability_box.position = Vector2(1104, 448)
	_durability_box.size = Vector2(466, 56)
	_durability_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_durability_box)
	UI.label(_durability_box, "当前握柄耐久", Rect2(4, 0, 200, 24), 16, UI.MUTED)
	_durability_bar = Control.new()
	_durability_bar.position = Vector2(4, 28)
	_durability_bar.size = Vector2(458, 24)
	_durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_durability_bar.draw.connect(_draw_durability_bar.bind(_durability_bar))
	_durability_box.add_child(_durability_bar)

	# Total cost bar with Ferryman Coin icon + Primary buy button
	UI.panel(self, Rect2(1104, 514, 466, 44), "wood_inset")
	UI.label(self, "合计费用", Rect2(1120, 518, 160, 36), 18, UI.MUTED)
	UI.icon_rect(self, UI.ICON_COIN, Rect2(1414, 520, 32, 32))
	_cost_value = UI.label(self, "0", Rect2(1450, 518, 106, 36), 23, UI.GOLD)
	_cost_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	action_button = UI.button(self, "确认购买", Rect2(1104, 568, 466, 62), _execute_selected, true)
	action_button.add_theme_font_size_override("font_size", 23)

	# 3. Bottom-Right Current Rig Status (mirrors Octopath's party overview!)
	UI.panel(self, Rect2(1082, 656, 510, 238), "dark_wood")
	UI.label(self, "当前钓组状态", Rect2(1106, 670, 260, 32), 20, UI.MINT)
	var icons := [UI.ICON_ROD, UI.ICON_HOOK, UI.ICON_GRIP, UI.ICON_BAIT]
	for i in 4:
		var y := 708.0 + i * 42.0
		UI.icon_rect(self, icons[i], Rect2(1108, y + 6, 26, 26))
		var lbl := UI.label(self, "", Rect2(1144, y + 2, 424, 34), 18, UI.CREAM)
		lbl.clip_text = true
		_rig_lines.append(lbl)
	_rig_mini_bar = Control.new()
	_rig_mini_bar.position = Vector2(1378, 800)
	_rig_mini_bar.size = Vector2(188, 18)
	_rig_mini_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig_mini_bar.draw.connect(_draw_durability_bar.bind(_rig_mini_bar))
	add_child(_rig_mini_bar)


func _device_filter(index: int) -> int:
	match index:
		0, 1:
			return Filter.ROD
		2, 3, 4:
			return Filter.HOOK
		_:
			return Filter.CHARM


func _device_icon(index: int) -> Texture2D:
	match index:
		0, 1:
			return UI.ICON_ROD
		2, 3, 4:
			return UI.ICON_HOOK
		_:
			return UI.ICON_CONCENTRATE


func _bait_icon(index: int) -> Texture2D:
	if Data.ATTRIBUTE_BAITS.has(index):
		var rule: Vector2i = Data.ATTRIBUTE_BAITS[index]
		return UI.STAT_ICONS[rule.x]
	return UI.ICON_BAIT


func _rebuild_catalog() -> void:
	_catalog.clear()
	if fishing == null:
		return
	for i in Data.DEVICES.size():
		var cat := _device_filter(i)
		var available := fishing.can_buy_device(i)
		var stock_text := "未拥有" if available else "已拥有"
		if i == Data.STEADY_CHARM:
			stock_text = "已拥有 %d / %d" % [fishing.charms_owned, Data.CHARM_LIMIT]
		_catalog.append({
			"key": "device:%d" % i,
			"kind": "device",
			"index": i,
			"filter": cat,
			"category_name": FILTER_META[cat]["label"],
			"icon": _device_icon(i),
			"preview_icon": _device_icon(i),
			"name": str(Data.DEVICES[i][0]),
			"desc": DEVICE_DESCS[i],
			"stock_text": stock_text,
			"unit_price": int(Data.DEVICES[i][1]),
			"available": available,
		})
	for i in Data.BAITS.size():
		var icon := _bait_icon(i)
		_catalog.append({
			"key": "bait:%d" % i,
			"kind": "bait",
			"index": i,
			"filter": Filter.BAIT,
			"category_name": "鱼饵",
			"icon": icon,
			"preview_icon": Data.fish_texture(Data.VARIANT, 3) if i == Data.VARIANT_BAIT else icon,
			"name": Data.BAITS[i],
			"desc": Data.bait_hint(i, true),
			"stock_text": "×%d" % fishing.bait_stock[i],
			"unit_price": int(Data.BAIT_PRICES[i]),
			"available": i != Data.VARIANT_BAIT or fishing.variant_craft_unlocked,
		})
	_catalog.append({"key": "craft:variant", "kind": "craft", "filter": Filter.BAIT, "category_name": "异刺工艺", "icon": UI.ICON_WRENCH, "preview_icon": Data.fish_texture(Data.VARIANT, 3), "name": "异刺工艺", "desc": "一次性解锁异刺拟饵购买。需拥有深水长杆，无其他工艺前置。", "stock_text": "已解锁" if fishing.variant_craft_unlocked else "需深水长杆", "unit_price": Data.VARIANT_CRAFT_COST, "available": fishing.can_unlock_variant_craft()})
	var durability_text := "%d / %d" % [fishing.durability(), Data.GRIP_CAPACITY]
	_catalog.append({
		"key": "repair:quick",
		"kind": "repair",
		"full": false,
		"filter": Filter.REPAIR,
		"category_name": "钓组维修",
		"icon": UI.ICON_WRENCH,
		"preview_icon": UI.ICON_WRENCH,
		"name": "临修",
		"desc": "耐久归零时可修至 %d / %d，消耗一次临修机会。" % [Data.GRIP_QUICK_REPAIR_DURABILITY, Data.GRIP_CAPACITY],
		"stock_text": durability_text,
		"unit_price": Data.GRIP_QUICK_REPAIR_COST,
		"available": fishing.can_repair(false),
	})
	_catalog.append({
		"key": "repair:full",
		"kind": "repair",
		"full": true,
		"filter": Filter.REPAIR,
		"category_name": "钓组维修",
		"icon": UI.ICON_WRENCH,
		"preview_icon": UI.ICON_WRENCH,
		"name": "整修",
		"desc": "耐久归零时可修至 %d / %d，并恢复一次临修机会。" % [Data.GRIP_CAPACITY, Data.GRIP_CAPACITY],
		"stock_text": durability_text,
		"unit_price": Data.GRIP_FULL_REPAIR_COST,
		"available": fishing.can_repair(true),
	})


func _filtered_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sold_out: Array[Dictionary] = []
	for item in _catalog:
		if active_filter != Filter.ALL and int(item["filter"]) != active_filter:
			continue
		if item["kind"] == "device" and not item["available"]:
			sold_out.append(item)
		else:
			result.append(item)
	result.append_array(sold_out)
	return result


func _find_selected(items: Array[Dictionary]) -> Dictionary:
	for item in items:
		if str(item["key"]) == selected_key:
			return item
	if not items.is_empty():
		selected_key = str(items[0]["key"])
		return items[0]
	return {}


func refresh() -> void:
	if fishing == null:
		return
	_rebuild_catalog()
	var money := fishing.session.coins
	var paused := fishing.session.paused

	# Update top-right wallet
	_wallet_value.text = str(money)

	# Update left rail filter tabs
	_filter_pointer.visible = not browsing_wares
	for i in FILTER_META.size():
		var meta: Dictionary = FILTER_META[i]
		var is_active := int(meta["id"]) == active_filter
		UI.style_slot_button(filter_buttons[i], is_active, false)
		if is_active:
			_filter_pointer.position.y = filter_buttons[i].position.y + 4.0
			_list_title.text = str(meta["title"])
			_list_watermark.text = str(meta["watermark"])

	# Rebuild center ware rows
	var items := _filtered_catalog()
	var selected := _find_selected(items)
	UI.clear_cards(_ware_list)
	ware_buttons.clear()

	for item in items:
		var key := str(item["key"])
		var is_sel := key == selected_key
		var price: int = int(item["unit_price"])
		var available: bool = bool(item["available"])
		var affordable := available and money >= price

		var row := Button.new()
		row.custom_minimum_size = Vector2(860, 48)
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bg_col := Color("433754", 0.92) if is_sel else Color("1c192d", 0.42)
		var bd_col := UI.GOLD if is_sel else Color("4a3f57", 0.35)
		row.add_theme_stylebox_override("normal", _translucent_box(bg_col, bd_col, 2 if is_sel else 1))
		row.add_theme_stylebox_override("hover", _translucent_box(Color("35314a", 0.85), UI.MINT, 2))
		row.add_theme_stylebox_override("pressed", _translucent_box(Color("4a3d5c", 0.95), UI.GOLD, 2))
		row.pressed.connect(func() -> void:
			if key != selected_key or not browsing_wares:
				_audio.play(Audio.Cue.UI_CLICK)
			selected_key = key
			browsing_wares = true
			refresh()
		)
		_ware_list.add_child(row)
		ware_buttons.append(row)

		if is_sel and browsing_wares:
			UI.label(row, "▶", Rect2(8, 8, 22, 32), 16, UI.GOLD)
			if visible:
				UI.reveal(_ware_scroll, row)

		# Small category pixel icon on every row!
		var icon_rect := UI.icon_rect(row, item["icon"], Rect2(32, 10, 28, 28))
		if not affordable:
			icon_rect.modulate = Color(1, 1, 1, 0.52)

		var name_col := UI.GOLD if is_sel else (UI.CREAM if affordable else Color(UI.MUTED, 0.58))
		var name_lbl := UI.label(row, str(item["name"]), Rect2(70, 6, 430, 36), 20, name_col)
		name_lbl.clip_text = true

		var stock_col := UI.GOOD if str(item["stock_text"]) == "已拥有" else (UI.MINT if str(item["stock_text"]).begins_with("×") and str(item["stock_text"]) != "×0" else UI.MUTED)
		var stock_lbl := UI.label(row, str(item["stock_text"]), Rect2(512, 6, 146, 36), 18, stock_col)
		stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		# Price with Ferryman Coin icon (dimmed if unaffordable / owned, like Octopath!)
		var price_col := UI.GOLD if affordable else Color(UI.MUTED, 0.48)
		var coin_ic := UI.icon_rect(row, UI.ICON_COIN, Rect2(724, 11, 26, 26))
		if not affordable:
			coin_ic.modulate = Color(1, 1, 1, 0.45)
		var price_txt := str(price) if available or item["kind"] == "repair" else "—"
		var price_lbl := UI.label(row, price_txt, Rect2(756, 6, 86, 36), 20, price_col)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Update Right Checkout Panel
	for i in QUANTITIES.size():
		UI.style_slot_button(_qty_buttons[i], QUANTITIES[i] == selected_quantity, false)

	if not selected.is_empty():
		var kind := str(selected["kind"])
		_detail_icon.texture = selected["preview_icon"]
		_detail_cat.text = str(selected["category_name"])
		_detail_name.text = str(selected["name"])
		_detail_desc.text = str(selected["desc"])
		_qty_row.visible = kind == "bait"
		_durability_box.visible = kind == "repair"

		var total_cost: int = int(selected["unit_price"]) * (selected_quantity if kind == "bait" else 1)
		var can_act: bool = not paused and bool(selected["available"]) and money >= total_cost
		_cost_value.text = str(total_cost) if bool(selected["available"]) or kind == "repair" else "—"
		_cost_value.add_theme_color_override("font_color", UI.GOLD if can_act else UI.WARN)

		if kind == "bait":
			_detail_meta.text = "当前库存 %s　｜　单价 %d" % [selected["stock_text"], int(selected["unit_price"])]
			action_button.text = "确认购买 ×%d" % selected_quantity
		elif kind == "craft":
			_detail_meta.text = str(selected["stock_text"])
			action_button.text = "解锁异刺工艺" if bool(selected["available"]) else str(selected["stock_text"])
		elif kind == "device":
			_detail_meta.text = "状态：%s" % selected["stock_text"]
			action_button.text = "确认购买钓具" if bool(selected["available"]) else "已拥有该钓具"
			if int(selected["index"]) == Data.STEADY_CHARM:
				action_button.text = "购买 1 件稳魂指骨" if bool(selected["available"]) else "稳魂指骨已购满"
		else:
			var quick_repairs := int(fishing.quick_repair_available)
			_detail_meta.text = "基础握柄 · 临修剩余 %d 次" % quick_repairs
			if fishing.is_busy():
				action_button.text = "请先回河岸收竿"
			elif fishing.durability() > 0:
				action_button.text = "耐久归零后可维修"
			elif not bool(selected["available"]):
				action_button.text = "临修机会耗尽，请选择整修"
			elif money < total_cost:
				action_button.text = "渡魂币不足"
			else:
				action_button.text = "确认维修"
		action_button.disabled = not can_act
	else:
		action_button.disabled = true
	_controls_hint.text = "W / S 选类别　空格 确认　C 返回河岸"
	if browsing_wares:
		_controls_hint.text = "W / S 选商品　空格 购买／维修　C 返回类别"
		if _qty_row.visible:
			_controls_hint.text += "　A / D 数量"

	# Update Right-Bottom Current Rig Summary
	_rig_lines[0].text = "竿体：%s" % Data.RODS[fishing.rod]
	_rig_lines[1].text = "鱼钩：%s" % Data.HOOKS[fishing.hook]
	_rig_lines[2].text = "基础握柄：%d/%d" % [fishing.durability(), Data.GRIP_CAPACITY]
	_rig_lines[2].add_theme_color_override("font_color", UI.WARN if fishing.durability() == 0 else UI.CREAM)
	_rig_lines[3].text = "鱼饵：%s ×%d" % [Data.BAITS[fishing.bait], fishing.bait_stock[fishing.bait]]
	_rig_lines[3].add_theme_color_override("font_color", UI.WARN if fishing.bait_stock[fishing.bait] == 0 else UI.MINT)

	_durability_bar.queue_redraw()
	_rig_mini_bar.queue_redraw()


func _draw_durability_bar(target: Control) -> void:
	if fishing == null:
		return
	var rect := Rect2(Vector2.ZERO, target.size)
	target.draw_rect(rect.grow(2.0), UI.INK)
	target.draw_rect(rect, Color("29202e"))
	var ratio := clampf(float(fishing.durability()) / float(Data.GRIP_CAPACITY), 0.0, 1.0)
	var fill_col := UI.GOOD if ratio > 0.4 else UI.WARN
	var fill_w := rect.size.x * ratio
	if fill_w > 0.5:
		target.draw_rect(Rect2(0, 0, fill_w, rect.size.y), fill_col)
		target.draw_rect(Rect2(0, 2, fill_w, 4), fill_col.lightened(0.32))
		target.draw_rect(Rect2(0, rect.size.y - 4, fill_w, 4), fill_col.darkened(0.28))
	for i in range(1, Data.GRIP_CAPACITY):
		var tx := rect.size.x * (float(i) / float(Data.GRIP_CAPACITY))
		target.draw_line(Vector2(tx, 0), Vector2(tx, rect.size.y), Color(UI.INK, 0.5), 1.5)


func _execute_selected() -> void:
	var items := _filtered_catalog()
	var selected := _find_selected(items)
	if selected.is_empty():
		return
	var kind := str(selected["kind"])
	if kind == "device":
		var idx: int = int(selected["index"])
		if fishing.buy_device(idx):
			_audio.play(Audio.Cue.PURCHASE)
			if idx == Data.STEADY_CHARM:
				_status.text = "已购入稳魂指骨，按竿体槽位自动装配。"
			else:
				_status.text = "已购入「%s」，按 E 返回河岸即可在钓组中装备。" % Data.DEVICES[idx][0]
	elif kind == "bait":
		var idx: int = int(selected["index"])
		var was_empty := fishing.bait_stock[fishing.bait] == 0 and not fishing.is_busy()
		if fishing.buy_bait(idx, selected_quantity):
			_audio.play(Audio.Cue.PURCHASE)
			if was_empty and fishing.bait == idx:
				_status.text = "购入 %s ×%d，已自动装配到当前钓组。" % [Data.BAITS[idx], selected_quantity]
			else:
				_status.text = "购入 %s ×%d（可在河岸右侧「鱼饵」槽切换）。" % [Data.BAITS[idx], selected_quantity]
	elif kind == "craft":
		if fishing.unlock_variant_craft():
			_audio.play(Audio.Cue.PURCHASE)
			_status.text = "异刺工艺已解锁，可购买异刺拟饵。"
	elif kind == "repair":
		if fishing.repair(bool(selected["full"])):
			_audio.play(Audio.Cue.PURCHASE)
			_status.text = "%s完成，基础握柄当前耐久 %d / %d。" % [selected["name"], fishing.durability(), Data.GRIP_CAPACITY]
