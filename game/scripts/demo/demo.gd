extends Control
## Cover -> river -> shop. The existing rule nodes own catches and inventory.

const UI := preload("res://scripts/demo/demo_ui.gd")
const River := preload("res://scripts/demo/pixel_river.gd")
const Shop := preload("res://scripts/demo/pixel_shop.gd")
const BASE_SIZE := Vector2(1620, 972)
const FONT := preload("res://assets/fonts/NotoSansSC.ttf")
const COVER := preload("res://assets/art/demo/cover.png")
const SOUL_LINES := ["我好像忘了很多事……能帮帮我吗？", "那些没说完的话，还留在心里。", "走了很久，终于能歇一会儿了。", "门的另一边，会是什么样子呢？", "我还记得那首歌，只是想不起名字。", "等我准备好了，再往前走。"]

var session: SoulSession
var qte: DirectionFishing
var river
var shop
var started: bool = false
var current_location: String = "River"
var auto_pause_on_focus_loss: bool = true
var start_button: Button
var _stage: Control
var _menu: Control
var _hud: Control
var _river_ui: Control
var _shop_ui: Control
var _river_image: TextureRect
var _shop_image: TextureRect
var _river_viewport: SubViewport
var _shop_viewport: SubViewport
var _pause_overlay: Control
var _help: Label
var _summary: Label
var _place_title: Label
var _river_button: Button
var _shop_button: Button
var _pause_button: Button
var _cast_button: Button
var _river_status: Label
var _river_hint: Label
var _beat_info: Label
var _beat_panel: Panel
var _hit: Label
var _inventory: Array[Label] = []
var _queue: ItemList
var _guest_name: Label
var _attributes: Array[Label] = []
var _guest_state: Label
var _arrival: Label
var _dialog: Label
var _feed_buttons: Array[Button] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage = Control.new()
	_stage.size = BASE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_theme_font_override("font", FONT)
	add_child(_stage)
	session = SoulSession.new()
	session.name = "SoulSession"
	session.active = false
	add_child(session)
	qte = DirectionFishing.new()
	qte.name = "DirectionFishing"
	add_child(qte)
	qte.set_process(false)
	var river_display := _pixel_display(River)
	river = river_display["world"]
	_river_image = river_display["image"]
	_river_viewport = river_display["viewport"]
	river.bind(qte)
	var shop_display := _pixel_display(Shop)
	shop = shop_display["world"]
	_shop_image = shop_display["image"]
	_shop_viewport = shop_display["viewport"]
	shop.bind(session)
	_build_menu()
	_build_hud()
	_build_river_ui()
	_build_shop_ui()
	_build_pause()
	session.state_changed.connect(_refresh_shared)
	shop.presentation_changed.connect(_refresh_shared)
	qte.state_changed.connect(_refresh_river)
	qte.fish_caught.connect(_on_fish_caught)
	resized.connect(_resize)
	_resize()
	_update_activation()
	_refresh_shared()
	_refresh_river()
	print("Integrated demo ready | cover, 4 x ", River.FRAME_DURATION, "s cast, DirectionFishing, SoulSession")


func _pixel_display(world_script: Script) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(405, 243)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_stage.add_child(viewport)
	var world: Node2D = world_script.new()
	viewport.add_child(world)
	var display := TextureRect.new()
	display.size = BASE_SIZE
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(display)
	return {"world": world, "image": display, "viewport": viewport}


func _build_menu() -> void:
	_menu = Control.new()
	_menu.size = BASE_SIZE
	_stage.add_child(_menu)
	var backdrop := ColorRect.new()
	backdrop.size = BASE_SIZE
	backdrop.color = Color("152131")
	_menu.add_child(backdrop)
	var cover := TextureRect.new()
	cover.size = BASE_SIZE
	cover.texture = COVER
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(cover)
	UI.panel(_menu, Rect2(1090, 610, 450, 300), 0.93)
	UI.label(_menu, "冥河值班 · 试玩版", Rect2(1120, 627, 390, 40), 26, UI.MINT)
	start_button = UI.button(_menu, "开始游戏", Rect2(1120, 681, 390, 70), _start_game)
	start_button.name = "StartGame"
	UI.button(_menu, "操作说明", Rect2(1120, 767, 186, 54), func() -> void: _help.visible = not _help.visible)
	UI.button(_menu, "退出", Rect2(1322, 767, 188, 54), func() -> void: get_tree().quit())
	UI.label(_menu, "钓鱼 · 接待 · 放行", Rect2(1120, 837, 390, 42), 22, UI.MUTED)
	var help_panel := UI.panel(_menu, Rect2(42, 823, 1010, 96), 0.88)
	_help = UI.label(_menu, "空格抛竿　WASD 逆向拉鱼，靠近虚线时更佳\nQ 回河岸　E 进店铺　1 / 2 / 3 喂鱼　P 暂停", Rect2(66, 836, 960, 68), 23)
	_help.visible = false
	help_panel.visible = false
	_help.visibility_changed.connect(func() -> void: help_panel.visible = _help.visible)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_hud)
	UI.panel(_hud, Rect2(30, 24, 1560, 72), 0.9)
	_place_title = UI.label(_hud, "阿刻戎河 · 钓鱼", Rect2(54, 38, 314, 43), 28, UI.CREAM)
	_summary = UI.label(_hud, "", Rect2(396, 39, 650, 42), 22, UI.GOLD)
	_river_button = UI.button(_hud, "Q  冥河岸", Rect2(1074, 37, 174, 46), func() -> void: _show_location("River"))
	_shop_button = UI.button(_hud, "E  灵魂店铺", Rect2(1262, 37, 190, 46), func() -> void: _show_location("Shop"))
	_pause_button = UI.button(_hud, "P 暂停", Rect2(1466, 37, 106, 46), func() -> void: _set_paused(not session.paused))
	_pause_button.add_theme_font_size_override("font_size", 20)


func _build_river_ui() -> void:
	_river_ui = Control.new()
	_river_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_river_ui)
	UI.panel(_river_ui, Rect2(1280, 132, 310, 284), 0.88)
	UI.label(_river_ui, "鱼篓", Rect2(1304, 146, 260, 40), 25, UI.MINT)
	for index in 3:
		_inventory.append(UI.label(_river_ui, "", Rect2(1304, 199 + index * 64, 260, 58), 21))
	_beat_panel = UI.panel(_river_ui, Rect2(490, 114, 640, 64), 0.82)
	_beat_info = UI.label(_river_ui, "", Rect2(514, 124, 592, 42), 23, UI.CREAM)
	_hit = UI.label(_river_ui, "", Rect2(1032, 621, 200, 50), 29, UI.GOLD)
	UI.panel(_river_ui, Rect2(30, 812, 748, 132), 0.9)
	_river_status = UI.label(_river_ui, "", Rect2(56, 828, 694, 44), 27)
	_river_hint = UI.label(_river_ui, "", Rect2(56, 879, 694, 42), 22, UI.MUTED)
	_cast_button = UI.button(_river_ui, "空格  抛竿", Rect2(1260, 860, 310, 74), _cast_line)
	UI.label(_river_ui, "W / A / S / D 逆向拉鱼", Rect2(1260, 808, 320, 40), 21, UI.MINT)


func _build_shop_ui() -> void:
	_shop_ui = Control.new()
	_shop_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_shop_ui)
	UI.panel(_shop_ui, Rect2(30, 126, 374, 544), 0.9)
	UI.label(_shop_ui, "门前等候", Rect2(52, 140, 328, 38), 25, UI.MINT)
	_queue = ItemList.new()
	_queue.position = Vector2(52, 188)
	_queue.size = Vector2(330, 144)
	_queue.focus_mode = Control.FOCUS_NONE
	_queue.add_theme_font_size_override("font_size", 20)
	_queue.add_theme_color_override("font_color", UI.CREAM)
	_queue.add_theme_stylebox_override("panel", UI.style(Color("202a39"), Color("485965")))
	_queue.item_selected.connect(_select_guest)
	_shop_ui.add_child(_queue)
	_guest_name = UI.label(_shop_ui, "", Rect2(52, 353, 330, 40), 24)
	for index in 3:
		_attributes.append(UI.label(_shop_ui, "", Rect2(52, 406 + index * 46, 330, 36), 22, SoulSession.ATTRIBUTE_COLORS[index]))
	_guest_state = UI.label(_shop_ui, "", Rect2(52, 555, 330, 40), 21, UI.GOLD)
	_arrival = UI.label(_shop_ui, "", Rect2(52, 611, 330, 34), 19, UI.MUTED)
	UI.panel(_shop_ui, Rect2(455, 148, 598, 114), 0.84)
	_dialog = UI.label(_shop_ui, "", Rect2(479, 159, 550, 88), 24)
	_dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.panel(_shop_ui, Rect2(30, 812, 958, 132), 0.94)
	for index in 3:
		var fish_index := index
		var button := UI.button(_shop_ui, "", Rect2(50 + index * 310, 832, 294, 92), func() -> void: shop.feed(fish_index))
		button.name = "Feed%d" % index
		button.add_theme_font_size_override("font_size", 21)
		_feed_buttons.append(button)
	UI.panel(_shop_ui, Rect2(1200, 818, 390, 126), 0.9)
	UI.label(_shop_ui, "喂鱼补全属性\n达标后自动走向冥府大门", Rect2(1222, 829, 346, 98), 23, UI.MINT)


func _build_pause() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.size = BASE_SIZE
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_pause_overlay)
	var shade := ColorRect.new()
	shade.size = BASE_SIZE
	shade.color = Color(0.04, 0.05, 0.09, 0.7)
	_pause_overlay.add_child(shade)
	UI.panel(_pause_overlay, Rect2(570, 298, 480, 360), 0.99)
	UI.label(_pause_overlay, "已暂停", Rect2(606, 323, 408, 60), 36, UI.MINT)
	UI.label(_pause_overlay, "鱼和来客都会等你。", Rect2(606, 398, 408, 40), 24, UI.MUTED)
	UI.button(_pause_overlay, "继续游戏 · P / 空格", Rect2(606, 467, 408, 62), func() -> void: _set_paused(false))
	UI.button(_pause_overlay, "返回封面", Rect2(606, 552, 408, 62), func() -> void: get_tree().reload_current_scene())


func _resize() -> void:
	_stage.scale = size / BASE_SIZE


func _start_game() -> void:
	if started:
		return
	started = true
	session.active = true
	_show_location("River")


func _show_location(value: String) -> void:
	if not started or value not in ["River", "Shop"]:
		return
	current_location = value
	_update_activation()
	_refresh_shared()
	_refresh_river()


func _update_activation() -> void:
	_menu.visible = not started
	_hud.visible = started
	_river_image.visible = started and current_location == "River"
	_shop_image.visible = started and current_location == "Shop"
	_river_ui.visible = _river_image.visible
	_shop_ui.visible = _shop_image.visible
	river.active = _river_image.visible
	river.paused = session.paused
	shop.active = _shop_image.visible
	qte.set_process(river.active and not session.paused)
	_river_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if river.active else SubViewport.UPDATE_DISABLED
	_shop_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shop.active else SubViewport.UPDATE_DISABLED
	_pause_overlay.visible = started and session.paused
	_river_button.disabled = current_location == "River"
	_shop_button.disabled = current_location == "Shop"
	_pause_button.text = "P 继续" if session.paused else "P 暂停"
	_place_title.text = "阿刻戎河 · 钓鱼" if current_location == "River" else "灵魂店铺 · 接待"


func _cast_line() -> void:
	if started and current_location == "River" and not session.paused:
		river.start_cast()
		_refresh_river()


func _on_fish_caught(index: int, _total: int) -> void:
	session.add_fish(index)


func _set_paused(value: bool) -> void:
	if not started:
		return
	session.set_paused(value)
	qte.set_paused(value)
	_update_activation()
	_refresh_river()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and auto_pause_on_focus_loss and started:
		_set_paused(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if not started:
		if code in [KEY_ENTER, KEY_KP_ENTER]:
			_start_game()
		else:
			return
	elif code == KEY_Q:
		_show_location("River")
	elif code == KEY_E:
		_show_location("Shop")
	elif code in [KEY_P, KEY_ESCAPE] or (session.paused and code == KEY_SPACE):
		_set_paused(not session.paused)
	elif session.paused:
		return
	elif current_location == "River":
		if code == KEY_SPACE:
			_cast_line()
		elif code in [KEY_W, KEY_A, KEY_S, KEY_D] and not river.casting:
			qte.submit_key(OS.get_keycode_string(code))
		else:
			return
	elif current_location == "Shop" and code in [KEY_1, KEY_2, KEY_3]:
		shop.feed(code - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()


func _select_guest(row: int) -> void:
	shop.select_guest(int(_queue.get_item_metadata(row)))


func _refresh_shared() -> void:
	if not is_instance_valid(_queue):
		return
	_summary.text = "第 %d 天　鱼篓 %d　等候 %d　已放行 %d　金币 %d" % [session.day, session.get_inventory_total(), session.souls.size(), session.released_count, session.coins]
	_queue.clear()
	for soul in session.souls:
		var row := _queue.item_count
		_queue.add_item("#%03d  %s" % [soul["id"], soul["name"]])
		_queue.set_item_metadata(row, soul["id"])
		_queue.set_item_disabled(row, shop.departing or session.paused)
		if soul["id"] == shop.selected_id:
			_queue.select(row)
	var selected: Dictionary = shop.departure_soul if shop.departing else session.get_soul(shop.selected_id)
	_guest_name.text = "等待来客" if selected.is_empty() else str(selected["name"])
	var required := session.get_requirements()
	for index in 3:
		var current: String = "—" if selected.is_empty() else str(selected["stats"][index])
		_attributes[index].text = "%s　%s / %d" % [SoulSession.ATTRIBUTE_NAMES[index], current, required[index]]
	_guest_state.text = "正在前往冥府…" if shop.departing else ("已补全，准备放行" if session.can_release(shop.selected_id) else "用鱼补全三项属性")
	if shop.departing:
		_dialog.text = "谢谢，我准备好继续走了。\n放行奖金 +%d" % session.release_reward
	elif selected.is_empty():
		_dialog.text = "窗口暂时没有来客。\n先去冥河钓几条鱼吧。"
	else:
		_dialog.text = SOUL_LINES[(int(selected["id"]) - 1) % SOUL_LINES.size()]
		if shop.fed_flash > 0.0:
			_dialog.text = "谢谢你，感觉好些了。"
	for index in 3:
		var fish: Dictionary = DirectionFishing.FISH[index]
		var stats: Vector3i = fish["stats"]
		_feed_buttons[index].text = "%d  %s ×%d\n智慧 +%d　情感 +%d　意志 +%d" % [index + 1, fish["name"], session.inventory[index], stats.x, stats.y, stats.z]
		_feed_buttons[index].disabled = shop.departing or not session.can_feed(shop.selected_id, index)
		_inventory[index].text = "%s ×%d\n智慧%d  情感%d  意志%d" % [fish["name"], session.inventory[index], stats.x, stats.y, stats.z] if qte.caught_counts[index] > 0 else "未知鱼种　未发现"


func _refresh_river() -> void:
	if not is_instance_valid(_cast_button):
		return
	_cast_button.disabled = river.casting or qte.is_busy() or session.paused
	_cast_button.text = "抛竿中…" if river.casting else ("候鱼 / 拉鱼中…" if qte.is_busy() else "空格  抛竿")
	_beat_panel.visible = qte.is_busy() and not river.casting
	_beat_info.visible = _beat_panel.visible
	_beat_info.text = "拉回 %d / %d　完美 %d　失误 %d / %d" % [qte.successful_pulls, qte.get_required_pulls(), qte.perfect_count, qte.mistakes, qte.mistake_limit]
	_hit.text = ""
	if river.pulse > 0.0 and not river.casting:
		_hit.text = "完美 +%d" % qte.last_progress_gain if qte.last_judgement == DirectionFishing.Judgement.PERFECT else ("+%d" % qte.last_progress_gain if qte.last_success else "失误")
	if river.casting:
		_river_status.text = "抛竿中　%d / 4" % (river.get_cast_frame() + 1)
		_river_hint.text = "每帧 %s 秒，抛出后等待咬钩。" % String.num(River.FRAME_DURATION, 2)
		return
	match qte.phase:
		DirectionFishing.Phase.READY:
			_river_status.text = "冥河很静。"
			_river_hint.text = "空格抛竿；钓起的鱼可带到店铺。"
		DirectionFishing.Phase.WAITING:
			_river_status.text = "候鱼中…"
			_river_hint.text = "留意鱼线的动静。"
		DirectionFishing.Phase.REELING, DirectionFishing.Phase.FEEDBACK:
			_river_status.text = "鱼上钩了。"
			_river_hint.text = "按箭头方向拉鱼，入水点靠近虚线时效果更佳。"
		DirectionFishing.Phase.CAUGHT:
			_river_status.text = "%s，收入鱼篓。" % DirectionFishing.FISH[qte.fish_index]["name"]
			_river_hint.text = "E 去店铺喂鱼，或空格再抛一竿。"
		DirectionFishing.Phase.ESCAPED:
			_river_status.text = "鱼脱钩了。"
			_river_hint.text = "空格再试一次，靠近虚线时逆向拉鱼。"


func _process(_delta: float) -> void:
	if not started:
		return
	_refresh_river()
	_arrival.text = "%.0f 秒后有新来客" % ceilf(session.spawn_remaining)
