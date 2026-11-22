extends Control
## The playable fishing, alchemy and soul reception loop with pixel-art UI.

const UI := preload("res://scripts/demo/demo_ui.gd")
const SoulHUD := preload("res://scripts/demo/soul_status_hud.gd")
const River := preload("res://scripts/demo/pixel_river.gd")
const Shop := preload("res://scripts/demo/pixel_shop.gd")
const Alchemy := preload("res://scripts/demo/alchemy_panel.gd")
const Market := preload("res://scripts/demo/market_panel.gd")
const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const BASE_SIZE := Vector2(1620, 972)
const SAVE_PATH := "user://bone_angler_save.json"
const RIVER_TAB_TEXT := "Q 河岸"
const RIVER_ALERT_COLOR := Color("ff5353")
const BONE_NOTICE_DURATION := 4.0
const FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
const FONT_FALLBACK := preload("res://assets/fonts/NotoSansSC.ttf")
const COVER := preload("res://assets/art/demo/cover.png")
const CATCH_BOX_SIZES := [Vector2(184, 112), Vector2(236, 144), Vector2(288, 176), Vector2(310, 184)]
# Mouth positions measured in each original texture before rotation.
const FISH_MOUTH_PIXELS := {
	"fish_01": Vector2(3, 21),
	"fish_01_variant": Vector2(4, 114),
	"fish_02": Vector2(3, 64),
	"fish_03": Vector2(19, 68),
	"fish_03_condensed": Vector2(17, 39),
	"fish_04": Vector2(5, 54),
	"fish_05": Vector2(11, 56),
	"fish_06": Vector2(6, 52),
	"fish_07": Vector2(4, 37),
	"fish_08": Vector2(4, 107),
	"fish_09": Vector2(4, 71),
	"fish_10": Vector2(4, 27),
	"fish_11": Vector2(4, 46),
}

var session: Session
var qte: Fishing
var river: River
var shop: Shop
var alchemy: Alchemy
var market: Market
var soul_hud: SoulHUD

var started: bool = false
var current_location: String = "River"
var auto_pause_on_focus_loss: bool = true
var persist_save: bool = true
var start_button: Button
var continue_button: Button
var settings_button: Button
var quit_button: Button

var _stage: Control
var _menu: Control
var _menu_pointer: Label
var _menu_buttons: Array[Button] = []
var _menu_cursor := 0
var _settings_backdrop: Button
var _settings_panel: Panel
var _settings_pointer: Label
var _settings_buttons: Array[Button] = []
var _settings_cursor := 0
var _window_mode_btn: Button
var _fullscreen_mode_btn: Button
var _autopause_on_btn: Button
var _autopause_off_btn: Button
var _hud: Control
var _river_ui: Control
var _shop_ui: Control
var _river_image: TextureRect
var _shop_image: TextureRect
var _river_viewport: SubViewport
var _shop_viewport: SubViewport
var _pause_banner: Control
var _summary: Label
var _place_title: Label
var _river_button: Button
var _river_bite_alert: Label
var _river_notice: Panel
var _river_notice_title: Label
var _river_notice_detail: Label
var _bone_notice_remaining := 0.0
var _shop_button: Button
var _alchemy_button: Button
var _market_button: Button
var _pause_button: Button

# Fishing UI
var _catch_fish_rect: TextureRect
var _cast_button: Button
var _river_status: Label
var _river_hint: Label
var _beat_info: Label
var _beat_panel: Panel
var _hit: Label
var _rig: Array[Button] = []
var _rig_value_labels: Array[Label] = []
var _rig_badge_labels: Array[Label] = []
var _rig_durability_bar: Control
var _rig_status: Label
var _rig_hint: Label
var _retract_button: Button

# Custom pixel-art Rig Secondary Selector (the only secondary menu)
var _rig_backdrop: Button
var _rig_popup: Panel
var _rig_popup_title: Label
var _rig_popup_icon: TextureRect
var _rig_popup_scroll: ScrollContainer
var _rig_popup_grid: GridContainer
var _rig_open_slot: int = -1
var _rig_slot_cursor := -1
var _rig_option_cursor := 0
var _rig_option_buttons: Array[Button] = []

# Shop / Reception UI (zero dropdowns)
var _queue_box: HFlowContainer
var _queue_buttons: Array[Button] = []
var _queue_empty: Label
var _guest_state: Label
var _arrival: Label
var _service_fee: Label
var _dialog: Label
var _payout_notice: Label
var _dose_scroll: ScrollContainer
var _dose_list: VBoxContainer
var _dose_buttons: Array[Button] = []
var _dose_empty: Label
var _selected_dose: Variant = null
var _dose_preview: Label
var _serve_button: Button
var _release_button: Button

var _held_keys: Dictionary = {}
var _pending_directions: Array[int] = []
var _requires_release := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage = Control.new()
	_stage.size = BASE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var demo_font := FontVariation.new()
	demo_font.base_font = FONT
	demo_font.fallbacks = [FONT_FALLBACK]
	_stage.theme = Theme.new()
	_stage.theme.default_font = demo_font
	add_child(_stage)

	session = Session.new()
	session.name = "PlaytestSession"
	add_child(session)

	qte = Fishing.new()
	qte.name = "PlaytestFishing"
	qte.session = session
	add_child(qte)

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

	alchemy = Alchemy.new()
	alchemy.name = "Alchemy"
	_stage.add_child(alchemy)
	alchemy.setup(session)

	market = Market.new()
	market.name = "Market"
	_stage.add_child(market)
	market.setup(qte)

	_build_pause()
	_build_river_notice()

	shop.presentation_changed.connect(_refresh_shared)
	session.state_changed.connect(save_progress)
	qte.state_changed.connect(_refresh_river)
	qte.state_changed.connect(_refresh_river_notice)
	qte.bone_recovered.connect(_show_bone_notice)
	qte.state_changed.connect(_refresh_economy)
	qte.state_changed.connect(save_progress)
	resized.connect(_resize)
	_resize()
	_update_activation()
	_refresh_shared()
	_refresh_river()


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
	backdrop.color = Color("1b2a4c")
	_menu.add_child(backdrop)
	var cover := TextureRect.new()
	cover.position = Vector2(0, 61)
	cover.size = Vector2(1620, 911)
	cover.texture = COVER
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(cover)

	# Classic indie-game vertical title menu positioned cleanly below the logo
	var menu_x := 1138.0
	var menu_w := 356.0
	var btn_h := 66.0
	var gap := 18.0
	var start_y := 486.0

	_menu_pointer = UI.label(_menu, "▶", Rect2(menu_x - 42.0, start_y, 34, btn_h), 26, UI.GOLD)
	_menu_pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	start_button = _make_title_button("开始游戏", UI.ICON_ROD, Rect2(menu_x, start_y, menu_w, btn_h), _start_game)
	start_button.name = "StartGame"
	continue_button = _make_title_button("继续游戏", UI.ICON_SOUL, Rect2(menu_x, start_y + (btn_h + gap) * 1.0, menu_w, btn_h), _continue_game)
	continue_button.name = "ContinueGame"
	settings_button = _make_title_button("游戏设置", UI.ICON_WRENCH, Rect2(menu_x, start_y + (btn_h + gap) * 2.0, menu_w, btn_h), _open_settings)
	settings_button.name = "SettingsButton"
	quit_button = _make_title_button("退出游戏", UI.ICON_EXIT, Rect2(menu_x, start_y + (btn_h + gap) * 3.0, menu_w, btn_h), func() -> void: get_tree().quit())
	quit_button.name = "QuitGame"
	UI.label(_menu, "W / S  选择　　空格  确认", Rect2(menu_x, 826, menu_w, 36), 18, UI.CREAM)
	_refresh_continue_button()

	# Pixel-art Settings overlay modal (hidden by default)
	_settings_backdrop = Button.new()
	_settings_backdrop.position = Vector2.ZERO
	_settings_backdrop.size = BASE_SIZE
	_settings_backdrop.focus_mode = Control.FOCUS_NONE
	_settings_backdrop.visible = false
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0.05, 0.04, 0.09, 0.62)
	_settings_backdrop.add_theme_stylebox_override("normal", dim)
	_settings_backdrop.add_theme_stylebox_override("hover", dim)
	_settings_backdrop.add_theme_stylebox_override("pressed", dim)
	_settings_backdrop.pressed.connect(_close_settings)
	_menu.add_child(_settings_backdrop)

	_settings_panel = UI.panel(_menu, Rect2(470, 224, 680, 524), "popup")
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.visible = false
	UI.icon_rect(_settings_panel, UI.ICON_WRENCH, Rect2(26, 22, 34, 34))
	UI.label(_settings_panel, "游戏设置", Rect2(70, 20, 300, 40), 26, UI.GOLD)
	var close_x := UI.button(_settings_panel, "×", Rect2(614, 18, 46, 42), _close_settings, false)
	close_x.add_theme_font_size_override("font_size", 24)

	# Row 1: Display mode
	UI.label(_settings_panel, "显示模式", Rect2(34, 88, 220, 44), 22, UI.CREAM)
	_window_mode_btn = UI.button(_settings_panel, "窗口模式", Rect2(278, 86, 178, 48), _set_display_mode.bind(false), false)
	_fullscreen_mode_btn = UI.button(_settings_panel, "全屏模式", Rect2(468, 86, 178, 48), _set_display_mode.bind(true), false)

	# Row 2: Auto-pause on focus loss
	UI.label(_settings_panel, "切出窗口自动暂停", Rect2(34, 154, 230, 44), 22, UI.CREAM)
	_autopause_on_btn = UI.button(_settings_panel, "开启", Rect2(278, 152, 178, 48), _set_auto_pause.bind(true), false)
	_autopause_off_btn = UI.button(_settings_panel, "关闭", Rect2(468, 152, 178, 48), _set_auto_pause.bind(false), false)

	# Row 3: Keybinds reference box
	UI.panel(_settings_panel, Rect2(34, 224, 612, 198), "slot")
	UI.label(_settings_panel, "操作按键", Rect2(54, 236, 200, 32), 20, UI.MINT)
	var controls_lbl := UI.label(_settings_panel, "Q 河岸　E 接待　R 炼药　T 市场\nWASD 选择／拉鱼　空格 确认／抛竿\nShift 更换部件／放行　C 取消／返回\nX 收竿　P / Esc 暂停或继续", Rect2(54, 274, 572, 134), 19, UI.CREAM)
	controls_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var ok_btn := UI.button(_settings_panel, "确定", Rect2(210, 442, 260, 56), _close_settings, true)
	ok_btn.add_theme_font_size_override("font_size", 23)
	_settings_buttons.assign([_window_mode_btn, _fullscreen_mode_btn, _autopause_on_btn, _autopause_off_btn, ok_btn])
	_settings_pointer = UI.label(_settings_panel, "▶", Rect2(0, 0, 20, 48), 18, UI.GOLD)
	for i in _settings_buttons.size():
		_settings_buttons[i].mouse_entered.connect(_move_settings_pointer.bind(i))
	_refresh_settings_ui()


func _make_title_button(title: String, icon: Texture2D, rect: Rect2, callback: Callable) -> Button:
	var shadow := ColorRect.new()
	shadow.position = rect.position + Vector2(5, 6)
	shadow.size = rect.size
	shadow.color = Color(0.05, 0.04, 0.1, 0.58)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(shadow)

	var index := _menu_buttons.size()
	var btn := UI.button(_menu, title, rect, callback, index == _menu_cursor)
	btn.add_theme_font_size_override("font_size", 25)
	if icon != null:
		UI.icon_rect(btn, icon, Rect2(26, (rect.size.y - 30.0) * 0.5, 30, 30))
	_menu_buttons.append(btn)
	btn.mouse_entered.connect(func() -> void:
		if not btn.disabled:
			_select_title_button(index)
	)
	return btn


func _select_title_button(index: int) -> void:
	if index == _menu_cursor:
		return
	UI.set_button_primary(_menu_buttons[_menu_cursor], false)
	_menu_cursor = index
	UI.set_button_primary(_menu_buttons[index], true)
	_menu_pointer.position.y = _menu_buttons[index].position.y


func _move_settings_pointer(index: int) -> void:
	_settings_cursor = index
	_settings_pointer.position = _settings_buttons[index].position + Vector2(9, 0)


func _refresh_continue_button() -> void:
	if continue_button == null:
		return
	var available := has_save()
	continue_button.disabled = not available
	continue_button.tooltip_text = "继续上次冥河值班进度" if available else "暂无存档记录"
	for child in continue_button.get_children():
		if child is TextureRect:
			child.modulate = Color(1, 1, 1, 1.0 if available else 0.4)


func _open_settings() -> void:
	_refresh_settings_ui()
	_move_settings_pointer(0)
	_settings_backdrop.visible = true
	_settings_panel.visible = true


func _close_settings() -> void:
	_settings_backdrop.visible = false
	_settings_panel.visible = false


func _set_display_mode(fullscreen: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_refresh_settings_ui()


func _set_auto_pause(enabled: bool) -> void:
	auto_pause_on_focus_loss = enabled
	_refresh_settings_ui()


func _refresh_settings_ui() -> void:
	if _window_mode_btn == null:
		return
	var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	UI.set_tab_active(_window_mode_btn, not is_fs)
	UI.set_tab_active(_fullscreen_mode_btn, is_fs)
	UI.set_tab_active(_autopause_on_btn, auto_pause_on_focus_loss)
	UI.set_tab_active(_autopause_off_btn, not auto_pause_on_focus_loss)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_hud)
	UI.panel(_hud, Rect2(24, 18, 1572, 78), "dark_wood")
	_place_title = UI.label(_hud, "阿刻戎河 · 钓鱼", Rect2(48, 32, 276, 48), 26, UI.CREAM)
	_summary = UI.label(_hud, "", Rect2(328, 34, 594, 44), 20, UI.GOLD)
	_river_button = UI.tab_button(_hud, RIVER_TAB_TEXT, Rect2(936, 32, 122, 48), func() -> void: _show_location("River"), true)
	_shop_button = UI.tab_button(_hud, "E 接待", Rect2(1066, 32, 122, 48), func() -> void: _show_location("Shop"), false)
	_alchemy_button = UI.tab_button(_hud, "R 炼药", Rect2(1196, 32, 122, 48), func() -> void: _show_location("Alchemy"), false)
	_market_button = UI.tab_button(_hud, "T 市场", Rect2(1326, 32, 122, 48), func() -> void: _show_location("Market"), false)
	_pause_button = UI.button(_hud, "P 暂停", Rect2(1460, 32, 114, 48), func() -> void: _set_paused(not session.paused), false)
	for b in [_river_button, _shop_button, _alchemy_button, _market_button, _pause_button]:
		b.add_theme_font_size_override("font_size", 24)
	var tab_font_size := _river_button.get_theme_font_size("font_size")
	var tab_font := _river_button.get_theme_font("font")
	var caption_width := tab_font.get_string_size(RIVER_TAB_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_font_size).x
	var shortcut_width := tab_font.get_string_size("Q", HORIZONTAL_ALIGNMENT_LEFT, -1, tab_font_size).x
	var name_offset := tab_font.get_string_size("Q ", HORIZONTAL_ALIGNMENT_LEFT, -1, tab_font_size).x
	var text_left := floorf((_river_button.size.x - caption_width) * 0.5)
	var alert_shift_left := 3.0
	var height := _river_button.size.y
	_river_bite_alert = UI.label(_river_button, "!", Rect2(text_left - alert_shift_left, 0, shortcut_width, height), 24, RIVER_ALERT_COLOR)
	var alert_font := FontVariation.new()
	alert_font.base_font = FONT
	alert_font.variation_transform = Transform2D(Vector2(1.8, 0), Vector2.DOWN, Vector2.ZERO)
	_river_bite_alert.add_theme_font_override("font", alert_font)
	_river_bite_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.label(_river_bite_alert, "河岸", Rect2(name_offset + alert_shift_left, 0, caption_width - name_offset, height), tab_font_size)
	_river_bite_alert.hide()


func _build_river_notice() -> void:
	_river_notice = UI.panel(_stage, Rect2(38, 704, 248, 94), "popup")
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(5, 34), Vector2(-12, 48), Vector2(5, 58)])
	tail.color = UI.GOLD
	_river_notice.add_child(tail)
	var badge := UI.panel(_river_notice, Rect2(16, 18, 56, 58), "wood_inset")
	badge.draw.connect(func() -> void:
		badge.draw_rect(Rect2(24, 10, 8, 26), RIVER_ALERT_COLOR)
		badge.draw_rect(Rect2(24, 40, 8, 8), RIVER_ALERT_COLOR)
	)
	_river_notice_title = UI.label(_river_notice, "", Rect2(84, 14, 148, 34), 25, UI.GOLD)
	_river_notice_detail = UI.label(_river_notice, "", Rect2(84, 48, 148, 30), 19)
	_river_notice.hide()


func _build_river_ui() -> void:
	_river_ui = Control.new()
	_river_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_river_ui)

	_catch_fish_rect = TextureRect.new()
	_catch_fish_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_catch_fish_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_catch_fish_rect.rotation = PI / 2.0
	_catch_fish_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catch_fish_rect.visible = false
	_river_ui.add_child(_catch_fish_rect)

	# Stardew / Soul Knight Pixel-Art Fishing Rig Panel (right side)
	UI.panel(_river_ui, Rect2(1240, 112, 352, 514), "dark_wood")
	UI.icon_rect(_river_ui, UI.ICON_ROD, Rect2(1260, 128, 30, 30))
	UI.label(_river_ui, "钓组装备", Rect2(1298, 126, 200, 36), 24, UI.GOLD)
	var swap_tip := UI.label(_river_ui, "Shift 换件", Rect2(1466, 130, 104, 28), 16, UI.MUTED)
	swap_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var rig_slots := ["竿体", "鱼钩", "握柄", "鱼饵"]
	for index in 4:
		var top := 172 + index * 78
		var btn := Button.new()
		btn.position = Vector2(1258, top)
		btn.size = Vector2(316, 70)
		UI.style_slot_button(btn, false, false)
		btn.pressed.connect(_toggle_rig_popup.bind(index))
		_river_ui.add_child(btn)
		_rig.append(btn)

		# Recessed icon frame inside each rig slot
		var icon_frame := UI.panel(btn, Rect2(10, 11, 48, 48), "wood_inset")
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.icon_rect(btn, UI.RIG_ICONS[index], Rect2(18, 19, 32, 32))

		UI.label(btn, rig_slots[index], Rect2(68, 8, 92, 24), 16, UI.GOLD)
		var val_lbl := UI.label(btn, "", Rect2(68, 32, 184, 30), 19, UI.CREAM)
		val_lbl.clip_text = true
		_rig_value_labels.append(val_lbl)

		var badge_lbl := UI.label(btn, "", Rect2(204, 8, 80, 24), 15, UI.MINT)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_rig_badge_labels.append(badge_lbl)

		var caret := UI.label(btn, "▾", Rect2(284, 18, 24, 34), 20, UI.GOLD)
		caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Durability pixel bar + status + hint inside Rig Panel
	_rig_status = UI.label(_river_ui, "", Rect2(1262, 492, 308, 30), 18, UI.CREAM)
	_rig_durability_bar = Control.new()
	_rig_durability_bar.position = Vector2(1262, 526)
	_rig_durability_bar.size = Vector2(308, 22)
	_rig_durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig_durability_bar.draw.connect(_draw_rig_durability_bar)
	_river_ui.add_child(_rig_durability_bar)
	_rig_hint = UI.label(_river_ui, "", Rect2(1262, 554, 308, 56), 17, UI.MUTED)
	_rig_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Beat / QTE info pill at top center
	_beat_panel = UI.panel(_river_ui, Rect2(470, 112, 680, 64), "parchment")
	_beat_info = UI.label(_river_ui, "", Rect2(494, 122, 632, 44), 22, UI.CREAM)
	_beat_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit = UI.label(_river_ui, "", Rect2(1010, 616, 220, 52), 30, UI.GOLD)

	# Bottom left status box
	UI.panel(_river_ui, Rect2(28, 808, 960, 138), "dark_wood")
	_river_status = UI.label(_river_ui, "", Rect2(56, 824, 904, 46), 25, UI.CREAM)
	_river_hint = UI.label(_river_ui, "", Rect2(56, 878, 904, 44), 21, UI.MUTED)

	# Bottom right primary pixel action buttons
	_retract_button = UI.button(_river_ui, "X  收竿", Rect2(1240, 772, 352, 62), _retract, false)
	_cast_button = UI.button(_river_ui, "空格  抛竿", Rect2(1240, 846, 352, 92), _cast_line, true)
	_cast_button.add_theme_font_size_override("font_size", 26)

	# Custom In-Game Pixel-Art Rig Secondary Selector Popup (replaces Godot OptionButton PopupMenu)
	_rig_backdrop = Button.new()
	_rig_backdrop.position = Vector2.ZERO
	_rig_backdrop.size = BASE_SIZE
	_rig_backdrop.flat = true
	_rig_backdrop.focus_mode = Control.FOCUS_NONE
	_rig_backdrop.visible = false
	var empty_sb := StyleBoxEmpty.new()
	_rig_backdrop.add_theme_stylebox_override("normal", empty_sb)
	_rig_backdrop.add_theme_stylebox_override("hover", empty_sb)
	_rig_backdrop.add_theme_stylebox_override("pressed", empty_sb)
	_rig_backdrop.pressed.connect(_close_rig_popup.bind(true))
	_river_ui.add_child(_rig_backdrop)

	_rig_popup = UI.panel(_river_ui, Rect2(760, 112, 468, 514), "popup")
	_rig_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_rig_popup.visible = false
	_rig_popup_icon = UI.icon_rect(_rig_popup, UI.ICON_ROD, Rect2(20, 18, 32, 32))
	_rig_popup_title = UI.label(_rig_popup, "更换部件", Rect2(60, 16, 320, 36), 23, UI.GOLD)
	var close_btn := UI.button(_rig_popup, "×", Rect2(406, 14, 44, 40), _close_rig_popup.bind(true), false)
	close_btn.add_theme_font_size_override("font_size", 24)
	_rig_popup_scroll = UI.create_scroll(_rig_popup, Rect2(18, 66, 432, 430))
	_rig_popup_grid = GridContainer.new()
	_rig_popup_grid.columns = 1
	_rig_popup_grid.add_theme_constant_override("h_separation", 10)
	_rig_popup_grid.add_theme_constant_override("v_separation", 10)
	_rig_popup_scroll.add_child(_rig_popup_grid)


func _build_shop_ui() -> void:
	_shop_ui = Control.new()
	_shop_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_shop_ui)

	# 1. Top-Left: Soul Knight Style Attribute HUD (Image 2 inspired, with semi-transparent preview!)
	soul_hud = SoulHUD.new()
	soul_hud.name = "SoulStatusHUD"
	soul_hud.position = Vector2(28, 112)
	soul_hud.size = Vector2(448, 232)
	_shop_ui.add_child(soul_hud)

	# 2. Below Top-Left HUD: Direct Scrollable Potion List (NO dropdown!)
	UI.panel(_shop_ui, Rect2(28, 354, 448, 594), "dark_wood")
	UI.icon_rect(_shop_ui, UI.ICON_POTION, Rect2(48, 370, 30, 30))
	UI.label(_shop_ui, "调配药剂列表", Rect2(86, 368, 220, 34), 22, UI.GOLD)
	var tip := UI.label(_shop_ui, "W / S  选药剂", Rect2(288, 372, 168, 28), 16, UI.MINT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_dose_scroll = UI.create_scroll(_shop_ui, Rect2(44, 412, 416, 404))
	_dose_list = VBoxContainer.new()
	_dose_list.add_theme_constant_override("separation", 8)
	_dose_scroll.add_child(_dose_list)
	_dose_empty = UI.label(_shop_ui, "暂无可用药剂\n按 R 前往炼药台提炼鱼获", Rect2(56, 548, 392, 86), 20, UI.MUTED)
	_dose_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UI.panel(_shop_ui, Rect2(44, 824, 416, 40), "wood_inset")
	_dose_preview = UI.label(_shop_ui, "点击上方药剂查看属性变化预览", Rect2(54, 826, 396, 36), 17, UI.CREAM)
	_dose_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dose_preview.clip_text = true
	_serve_button = UI.button(_shop_ui, "空格  端上所选药剂", Rect2(44, 872, 416, 58), _serve_dose, true)
	_serve_button.add_theme_font_size_override("font_size", 22)

	# 3. Top-Center: Guest Speech Parchment Box (floating above guest, open counter!)
	UI.panel(_shop_ui, Rect2(492, 112, 578, 116), "parchment")
	_dialog = UI.label(_shop_ui, "", Rect2(516, 124, 530, 92), 22, UI.CREAM)
	_dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_payout_notice = UI.label(_shop_ui, "", Rect2(516, 232, 530, 34), 20, UI.GOLD)

	# 4. Top-Right: Compact Waiting Queue in Sky (keeps underworld gate 100% visible!)
	UI.panel(_shop_ui, Rect2(1086, 112, 506, 166), "dark_wood")
	UI.icon_rect(_shop_ui, UI.ICON_SOUL, Rect2(1106, 126, 28, 28))
	UI.label(_shop_ui, "门前等候 · A / D", Rect2(1142, 124, 184, 32), 20, UI.MINT)
	_arrival = UI.label(_shop_ui, "", Rect2(1300, 126, 272, 28), 16, UI.MUTED)
	_arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var q_scroll := UI.create_scroll(_shop_ui, Rect2(1102, 162, 474, 102))
	_queue_box = HFlowContainer.new()
	_queue_box.custom_minimum_size = Vector2(458, 0)
	_queue_box.add_theme_constant_override("h_separation", 8)
	_queue_box.add_theme_constant_override("v_separation", 6)
	q_scroll.add_child(_queue_box)
	_queue_empty = UI.label(_shop_ui, "暂无人排队等候", Rect2(1110, 188, 458, 40), 18, UI.MUTED)
	_queue_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 5. Bottom-Right: Fee, Commission & Release Button
	UI.panel(_shop_ui, Rect2(1148, 728, 444, 220), "dark_wood")
	UI.icon_rect(_shop_ui, UI.ICON_COIN, Rect2(1168, 742, 28, 28))
	_guest_state = UI.label(_shop_ui, "等待用药", Rect2(1204, 740, 220, 32), 21, UI.GOLD)
	_service_fee = UI.label(_shop_ui, "", Rect2(1168, 778, 404, 74), 18, UI.CREAM)
	_service_fee.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_release_button = UI.button(_shop_ui, "Shift  放行", Rect2(1168, 862, 404, 68), func() -> void: shop.begin_departure(), true)
	_release_button.add_theme_font_size_override("font_size", 25)


func _build_pause() -> void:
	_pause_banner = Control.new()
	_pause_banner.position = Vector2(46, 32)
	_pause_banner.size = Vector2(876, 52)
	_pause_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_pause_banner)
	UI.label(_pause_banner, "已暂停　P / Esc / 空格继续", Rect2(4, 0, 580, 48), 22, UI.MINT)
	UI.button(_pause_banner, "C 返回封面", Rect2(666, 0, 196, 48), _return_to_title)


func _resize() -> void:
	_stage.scale = size / BASE_SIZE


func _start_game() -> void:
	if started:
		return
	_close_settings()
	started = true
	session.start_shift()
	_show_location("River")
	if not has_save():
		save_progress()


func _continue_game() -> void:
	if started or not load_progress():
		return
	_close_settings()
	started = true
	session.active = true
	_show_location(current_location)
	save_progress()


func _return_to_title() -> void:
	save_progress()
	get_tree().reload_current_scene()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_progress() -> void:
	if not persist_save or not started or session == null or qte == null:
		return
	var saved_potions: Array = []
	for p in session.potions:
		saved_potions.append({
			"id": int(p.id), "kind": str(p.kind), "name": str(p.name),
			"effect": [p.effect.x, p.effect.y, p.effect.z],
			"attribute": int(p.attribute), "adjustment": int(p.adjustment),
		})
	var saved_souls: Array = []
	for s in session.souls:
		saved_souls.append({
			"id": int(s.id), "case_id": int(s.case_id), "name": str(s.name),
			"stats": [s.stats.x, s.stats.y, s.stats.z],
			"before": [s.before.x, s.before.y, s.before.z],
			"served": bool(s.served), "fee": int(s.fee),
		})
	var payload := {
		"location": current_location,
		"coins": session.coins,
		"released_count": session.released_count,
		"day_schedule": session.save_day(),
		"arrived": session._arrived,
		"next_item_id": session._next_item_id,
		"spawn_remaining": session.spawn_remaining,
		"concentrate": session.concentrate,
		"recovered_bones": session.recovered_bones,
		"finger_bones": session.finger_bones,
		"first_services": session._first_services,
		"catches": session.catches,
		"essences": session.essences,
		"potions": saved_potions,
		"souls": saved_souls,
		"rod": qte.rod,
		"hook": qte.hook,
		"grip": qte.grip,
		"bait": qte.bait,
		"rods_owned": qte.rods_owned,
		"hooks_owned": qte.hooks_owned,
		"grip_durability": qte.grip_durability,
		"charms_owned": qte.charms_owned,
		"bait_stock": qte.bait_stock,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))


func load_progress() -> bool:
	if not has_save():
		return false
	var raw := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed
	session.coins = int(data.get("coins", Data.STARTING_COINS))
	session.released_count = int(data.get("released_count", 0))
	session._arrived = int(data.get("arrived", 0))
	session._next_item_id = int(data.get("next_item_id", 1))
	session.spawn_remaining = float(data.get("spawn_remaining", Data.ARRIVAL_MIN))
	session.concentrate = int(data.get("concentrate", 0))
	session.recovered_bones = int(data.get("recovered_bones", 0))
	session.finger_bones = int(data.get("finger_bones", 0))
	session._first_services = {}
	for k in data.get("first_services", {}).keys():
		session._first_services[int(k)] = true
	session.catches.clear()
	for c in data.get("catches", []):
		if c is Dictionary:
			session.catches.append({
				"id": int(c.get("id", 0)), "species": int(c.get("species", 0)),
				"size": int(c.get("size", 1)), "cm": float(c.get("cm", 10.0)),
				"finger_bones": int(c.get("finger_bones", 0)),
			})
	var ess: Array = data.get("essences", [])
	for i in mini(ess.size(), session.essences.size()):
		session.essences[i] = int(ess[i])
	session.potions.clear()
	for p in data.get("potions", []):
		if p is Dictionary:
			var e: Array = p.get("effect", [0, 0, 0])
			session.potions.append({
				"id": int(p.get("id", 0)), "kind": str(p.get("kind", "")), "name": str(p.get("name", "")),
				"effect": Vector3i(int(e[0]), int(e[1]), int(e[2])),
				"attribute": int(p.get("attribute", -1)), "adjustment": int(p.get("adjustment", 0)),
			})
	session.souls.clear()
	for s in data.get("souls", []):
		if s is Dictionary:
			var st: Array = s.get("stats", [8, 8, 8])
			var bf: Array = s.get("before", st)
			session.souls.append({
				"id": int(s.get("id", 0)), "case_id": int(s.get("case_id", 0)), "name": str(s.get("name", "")),
				"stats": Vector3i(int(st[0]), int(st[1]), int(st[2])),
				"before": Vector3i(int(bf[0]), int(bf[1]), int(bf[2])),
				"served": bool(s.get("served", false)), "fee": int(s.get("fee", 40)),
			})
	session.restore_day(data.get("day_schedule", {}))
	var ro: Array = data.get("rods_owned", [true, false])
	for i in mini(ro.size(), qte.rods_owned.size()):
		qte.rods_owned[i] = bool(ro[i])
	var ho: Array = data.get("hooks_owned", [true, false, false])
	for i in mini(ho.size(), qte.hooks_owned.size()):
		qte.hooks_owned[i] = bool(ho[i])
	var gd: Array = data.get("grip_durability", [Data.GRIP_CAPACITY])
	qte.grip_durability.clear()
	for d in gd:
		qte.grip_durability.append(int(d))
	if qte.grip_durability.is_empty():
		qte.grip_durability.append(Data.GRIP_CAPACITY)
	qte.charms_owned = int(data.get("charms_owned", 1))
	qte.restore_bait_inventory(data.get("bait_stock", []), int(data.get("bait", 0)))
	qte.rod = clampi(int(data.get("rod", 0)), 0, qte.rods_owned.size() - 1)
	qte.hook = clampi(int(data.get("hook", 0)), 0, qte.hooks_owned.size() - 1)
	qte.grip = clampi(int(data.get("grip", 0)), 0, qte.grip_durability.size() - 1)
	var loc := str(data.get("location", "River"))
	current_location = loc if loc in ["River", "Shop", "Alchemy", "Market"] else "River"
	session.state_changed.emit()
	qte.state_changed.emit()
	return true


func _show_location(value: String) -> void:
	if not started or session.paused or value not in ["River", "Shop", "Alchemy", "Market"]:
		return
	_close_rig_popup()
	_clear_pull_input()
	current_location = value
	if value == "Market" and is_instance_valid(market):
		market.reset_to_all()
	_update_activation()
	_refresh_shared()
	_refresh_river()


func _update_activation() -> void:
	_menu.visible = not started
	_hud.visible = started
	_river_image.visible = started and current_location == "River"
	_shop_image.visible = started and current_location != "River"
	_river_ui.visible = _river_image.visible
	_shop_ui.visible = started and current_location == "Shop"
	alchemy.visible = started and current_location == "Alchemy"
	market.visible = started and current_location == "Market"
	river.active = _river_image.visible
	river.paused = session.is_time_suspended()
	shop.active = _shop_ui.visible
	qte.set_at_river(river.active)
	_river_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if river.active else SubViewport.UPDATE_DISABLED
	_shop_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _shop_image.visible else SubViewport.UPDATE_DISABLED
	_pause_banner.visible = started and session.paused
	_place_title.visible = not session.paused
	_summary.visible = not session.paused
	_river_button.disabled = session.paused or current_location == "River"
	_shop_button.disabled = session.paused or current_location == "Shop"
	_alchemy_button.disabled = session.paused or current_location == "Alchemy"
	_market_button.disabled = session.paused or current_location == "Market"
	UI.set_tab_active(_river_button, current_location == "River")
	UI.set_tab_active(_shop_button, current_location == "Shop")
	UI.set_tab_active(_alchemy_button, current_location == "Alchemy")
	UI.set_tab_active(_market_button, current_location == "Market")
	_pause_button.text = "P 继续" if session.paused else "P 暂停"
	_place_title.text = {"River": "阿刻戎河 · 钓鱼", "Shop": "灵魂店铺 · 接待", "Alchemy": "炼药台 · 收纳", "Market": "市场 · 钓组整备"}[current_location]
	_refresh_river_notice()


func _cast_line() -> void:
	if started and current_location == "River" and _rig_slot_cursor < 0 and not session.is_time_suspended():
		river.start_cast()
		_refresh_river()


func _retract() -> void:
	if river.casting:
		river.cancel_cast()
	else:
		qte.retract()
	_refresh_river()


func _toggle_rig_popup(slot: int) -> void:
	if river.casting or qte.is_busy() or session.paused:
		return
	if _rig_open_slot == slot:
		_close_rig_popup(true)
		return
	_open_rig_popup(slot)


func _open_rig_popup(slot: int) -> void:
	_rig_slot_cursor = slot
	_rig_open_slot = slot
	_rig_backdrop.visible = true
	_rig_popup.visible = true
	var is_bait := slot == 3
	var popup_w := 516.0 if is_bait else 388.0
	var popup_h := 514.0 if is_bait else 330.0
	_rig_popup.position = Vector2(1228.0 - popup_w, 112.0)
	_rig_popup.size = Vector2(popup_w, popup_h)
	_rig_popup_scroll.size = Vector2(popup_w - 36.0, popup_h - 84.0)
	for child in _rig_popup.get_children():
		if child is Button and child.text == "×":
			child.position.x = popup_w - 64.0
	var titles := ["更换竿体", "更换鱼钩", "更换握柄", "选择鱼饵"]
	_rig_popup_icon.texture = UI.RIG_ICONS[slot]
	_rig_popup_title.text = titles[slot]
	_populate_rig_popup(slot)
	_rig_option_cursor = [qte.rod, qte.hook, qte.grip, qte.bait][slot]
	_highlight_rig_option()
	_refresh_river()


func _close_rig_popup(return_to_slots: bool = false) -> void:
	if _rig_slot_cursor < 0:
		return
	_rig_open_slot = -1
	if not return_to_slots:
		_rig_slot_cursor = -1
	_rig_backdrop.visible = false
	_rig_popup.visible = false
	_refresh_river()


func _populate_rig_popup(slot: int) -> void:
	UI.clear_cards(_rig_popup_grid)
	_rig_option_buttons.clear()
	_rig_popup_grid.columns = 2 if slot == 3 else 1

	if slot == 0:
		for i in Data.RODS.size():
			var owned: bool = qte.rods_owned[i]
			_add_rig_option(UI.ICON_ROD, Data.RODS[i], Data.ROD_DESCS[i], "已装备" if qte.rod == i else ("未拥有" if not owned else "可装配"), qte.rod == i, not owned, Vector2(342, 68), func() -> void:
				qte.set_rig(i, qte.hook, qte.grip, qte.bait)
				_close_rig_popup()
			)
	elif slot == 1:
		for i in Data.HOOKS.size():
			var owned: bool = qte.hooks_owned[i]
			_add_rig_option(UI.ICON_HOOK, Data.HOOKS[i], Data.HOOK_DESCS[i], "已装备" if qte.hook == i else ("未拥有" if not owned else "可装配"), qte.hook == i, not owned, Vector2(342, 68), func() -> void:
				qte.set_rig(qte.rod, i, qte.grip, qte.bait)
				_close_rig_popup()
			)
	elif slot == 2:
		for i in qte.grip_durability.size():
			var dur: int = qte.grip_durability[i]
			_add_rig_option(UI.ICON_GRIP, "基础握柄 %d" % (i + 1), "耐久 %d / %d" % [dur, Data.GRIP_CAPACITY], "已装备" if qte.grip == i else "可装配", qte.grip == i, false, Vector2(342, 68), func() -> void:
				qte.set_rig(qte.rod, qte.hook, i, qte.bait)
				_close_rig_popup()
			)
	elif slot == 3:
		for i in Data.BAITS.size():
			var count: int = qte.bait_stock[i]
			_add_rig_option(UI.ICON_BAIT, Data.BAITS[i], Data.bait_hint(i), "×%d" % count, qte.bait == i, false, Vector2(228, 74), func() -> void:
				qte.set_rig(qte.rod, qte.hook, qte.grip, i)
				_close_rig_popup()
			)


func _add_rig_option(icon: Texture2D, title: String, subtitle: String, badge: String, selected: bool, locked: bool, card_size: Vector2, callback: Callable) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = card_size
	btn.disabled = locked
	UI.style_slot_button(btn, selected, locked)
	btn.pressed.connect(callback)
	_rig_popup_grid.add_child(btn)
	_rig_option_buttons.append(btn)

	UI.icon_rect(btn, icon, Rect2(12, (card_size.y - 30.0) * 0.5, 30, 30))
	var title_w := card_size.x - 116.0
	var t_lbl := UI.label(btn, title, Rect2(50, 8, title_w, 28), 18, UI.GOLD if selected else (UI.MUTED if locked else UI.CREAM))
	t_lbl.clip_text = true
	var s_lbl := UI.label(btn, subtitle, Rect2(50, 36, card_size.x - 62.0, 24), 14, UI.MUTED)
	s_lbl.clip_text = true
	var b_lbl := UI.label(btn, badge, Rect2(card_size.x - 74.0, 10, 62, 24), 15, UI.GOOD if selected else (UI.WARN if locked or badge == "×0" else UI.MINT))
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _highlight_rig_option() -> void:
	for i in _rig_option_buttons.size():
		var btn := _rig_option_buttons[i]
		UI.style_slot_button(btn, i == _rig_option_cursor, btn.disabled)
	UI.reveal(_rig_popup_scroll, _rig_option_buttons[_rig_option_cursor])


func _begin_rig_selection() -> void:
	if river.casting or qte.is_busy():
		return
	_clear_pull_input()
	_rig_slot_cursor = 0
	_refresh_river()


func _rig_key(code: Key) -> bool:
	match code:
		KEY_C:
			_close_rig_popup(_rig_open_slot >= 0)
		KEY_ESCAPE:
			_close_rig_popup()
		KEY_W, KEY_A, KEY_S, KEY_D:
			if _rig_open_slot >= 0 and _rig_popup_grid.columns > 1:
				_move_rig_grid_cursor(code)
			elif code in [KEY_W, KEY_S]:
				var step := 1 if code == KEY_S else -1
				if _rig_open_slot >= 0:
					_rig_option_cursor = UI.next_button(_rig_option_buttons, _rig_option_cursor, step)
					_highlight_rig_option()
				else:
					_rig_slot_cursor = UI.next_button(_rig, _rig_slot_cursor, step)
					_refresh_rig_slots()
		KEY_SPACE:
			if _rig_open_slot >= 0:
				UI.activate(_rig_option_buttons[_rig_option_cursor])
			else:
				_open_rig_popup(_rig_slot_cursor)
		_:
			return false
	return true


func _move_rig_grid_cursor(code: Key) -> void:
	var columns := _rig_popup_grid.columns
	var index := _rig_option_cursor
	var column := index % columns
	var last := _rig_option_buttons.size() - 1
	match code:
		KEY_W: index = maxi(index - columns, column)
		KEY_S:
			if index - column + columns <= last:
				index = mini(index + columns, last)
		KEY_A: index = maxi(index - 1, index - column)
		KEY_D: index = mini(index + 1, mini(index - column + columns - 1, last))
	if index != _rig_option_cursor:
		_rig_option_cursor = index
		_highlight_rig_option()


func _set_paused(value: bool) -> void:
	if not started or session.paused == value:
		return
	session.paused = value
	if value:
		_close_rig_popup()
	_clear_pull_input()
	_update_activation()
	_refresh_shared()
	_refresh_river()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and auto_pause_on_focus_loss and started:
		_set_paused(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if not key.pressed:
		_held_keys.erase(code)
		if _held_keys.is_empty():
			_requires_release = false
		return
	if key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var handled := true
	if not started:
		handled = _title_key(code)
	elif code == KEY_P:
		_set_paused(not session.paused)
	elif _rig_slot_cursor >= 0:
		handled = _rig_key(code)
	elif code == KEY_ESCAPE or (session.paused and code == KEY_SPACE):
		_set_paused(not session.paused)
	elif session.paused:
		if code != KEY_C:
			return
		_return_to_title()
	elif code == KEY_Q:
		_show_location("River")
	elif code == KEY_E:
		_show_location("Shop")
	elif code == KEY_R:
		_show_location("Alchemy")
	elif code == KEY_T:
		_show_location("Market")
	else:
		match current_location:
			"River": handled = _river_key(code)
			"Shop": handled = _reception_key(code)
			"Alchemy": handled = alchemy.handle_key(code)
			"Market": handled = market.handle_key(code)
		if not handled and code == KEY_C and current_location != "River":
			_show_location("River")
			handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _title_key(code: Key) -> bool:
	var in_settings := _settings_panel.visible
	var buttons := _settings_buttons if in_settings else _menu_buttons
	var cursor := _settings_cursor if in_settings else _menu_cursor
	match code:
		KEY_W, KEY_S:
			cursor = UI.next_button(buttons, cursor, 1 if code == KEY_S else -1)
			if in_settings:
				_move_settings_pointer(cursor)
			else:
				_select_title_button(cursor)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			UI.activate(buttons[cursor])
		KEY_C, KEY_ESCAPE:
			if not in_settings:
				return false
			_close_settings()
		_:
			return false
	return true


func _river_key(code: Key) -> bool:
	if code == KEY_X:
		_retract()
	elif code == KEY_SPACE:
		_cast_line()
	elif code == KEY_SHIFT:
		_begin_rig_selection()
	elif qte.phase == Fishing.Phase.TRUE_NAME and code >= KEY_A and code <= KEY_Z:
		qte.submit_letter(OS.get_keycode_string(code))
	else:
		var direction := Fishing.DIRECTION_KEYS.find(code)
		if direction < 0:
			direction = Fishing.ARROW_KEYS.find(code)
		if direction < 0:
			return false
		_queue_pull(code, direction)
	return true


func _reception_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_S:
			_move_dose(1 if code == KEY_S else -1)
		KEY_A, KEY_D:
			for i in session.souls.size():
				if session.souls[i].id == shop.selected_id:
					var index := posmod(i + (1 if code == KEY_D else -1), session.souls.size())
					shop.select_guest(session.souls[index].id)
					UI.reveal(_queue_box.get_parent() as ScrollContainer, _queue_buttons[index])
					break
		KEY_SPACE:
			UI.activate(_serve_button)
		KEY_SHIFT:
			UI.activate(_release_button)
		KEY_C:
			if _selected_dose == null:
				return false
			_select_dose(_selected_dose)
		_:
			return false
	return true


func _queue_pull(code: int, direction: int) -> void:
	_held_keys[code] = true
	if river.casting or qte.phase != Fishing.Phase.REELING or _requires_release:
		_requires_release = true
		return
	if _pending_directions.is_empty():
		_submit_pending_pull.call_deferred()
	_pending_directions.append(direction)


func _submit_pending_pull() -> void:
	if _pending_directions.is_empty():
		return
	var direction := _pending_directions[0] if _pending_directions.size() == 1 else -1
	_pending_directions.clear()
	_requires_release = not _held_keys.is_empty()
	qte.submit_direction(direction)


func _clear_pull_input() -> void:
	_pending_directions.clear()
	_held_keys.clear()
	_requires_release = false


func _refresh_summary() -> void:
	_summary.text = "第 %d 天　鱼篓 %d　等候 %d　放行 %d / %d　渡魂币 %d" % [session.day, session.catches.size(), session.souls.size(), session.released_count, session.total_guests(), session.coins]


func _show_bone_notice() -> void:
	_bone_notice_remaining = BONE_NOTICE_DURATION
	_refresh_river_notice()


func _refresh_river_notice() -> void:
	var fish_hooked := started and current_location != "River" and qte.phase == Fishing.Phase.AWAITING_RETURN
	_river_bite_alert.visible = fish_hooked
	_river_button.text = "" if fish_hooked else RIVER_TAB_TEXT
	_river_button.accessibility_name = "有鱼上钩了，返回河岸" if fish_hooked else ""
	_river_notice.visible = started and (fish_hooked or _bone_notice_remaining > 0.0)
	if _river_notice.visible:
		_river_notice_title.text = "有鱼上钩了！" if fish_hooked else "钓到了遗骨！"
		_river_notice_detail.text = "按 Q 返回河岸" if fish_hooked else "已回收遗骨 ×1"


func _refresh_economy() -> void:
	_refresh_summary()
	market.refresh()


func _refresh_shared() -> void:
	if not is_instance_valid(market):
		return
	_refresh_economy()
	_rebuild_queue()
	_rebuild_dose_list()

	var selected := session.get_soul(shop.selected_id)
	var ready := session.can_release(shop.selected_id)
	_guest_state.text = "达到要求 · 可以放行" if ready else ("窗口空闲" if selected.is_empty() else "等待调配药剂")
	_guest_state.add_theme_color_override("font_color", UI.GOOD if ready else UI.GOLD)
	_release_button.disabled = session.paused or not ready

	_service_fee.text = ""
	if not selected.is_empty():
		_service_fee.text = "基础服务费 %d 枚" % selected.fee
		if session.first_service(selected):
			_service_fee.text += "　首次 +%d 枚" % int(selected.fee * 0.20)
		if selected.case_id == 2 and session.requirements[1].z >= 9:
			_service_fee.text += "\n特殊委托：意志达到 9　+%d 枚" % int(selected.fee * 0.20)

	_payout_notice.text = "放行成功　渡魂币 +%d" % session.last_payout if not shop.departure_times.is_empty() else ""
	if session.is_complete():
		_dialog.text = "五天的灵魂都已放行。"
	elif selected.is_empty():
		_dialog.text = "还没有来客，可以先去冥河备料。"
	elif selected.served:
		_dialog.text = "饮药后感觉变化明显：\n%s" % Data.effect_text(selected.stats - selected.before)
	else:
		_dialog.text = "请帮我补全灵魂，让我能通过冥府之门。"

	_refresh_dose()
	alchemy.refresh()


func _rebuild_queue() -> void:
	UI.clear_cards(_queue_box)
	_queue_buttons.clear()
	_queue_empty.visible = session.souls.is_empty()
	for soul in session.souls:
		var sid: int = int(soul["id"])
		var is_sel := sid == shop.selected_id
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(224, 30)
		btn.disabled = session.paused
		UI.style_slot_button(btn, is_sel, false)
		btn.pressed.connect(func() -> void: shop.select_guest(sid))
		_queue_box.add_child(btn)
		_queue_buttons.append(btn)
		var eligible := session.is_eligible(soul.stats)
		var dot_col := UI.GOOD if eligible else UI.GOLD
		var lbl := UI.label(btn, ("● " if eligible else "") + str(soul.name), Rect2(10, 2, 204, 26), 15, dot_col if is_sel else UI.CREAM)
		lbl.clip_text = true


func _rebuild_dose_list() -> void:
	var rows := Alchemy.medicine_rows(session)
	var still_valid := false
	if _selected_dose != null:
		for row in rows:
			if row[1] == _selected_dose:
				still_valid = true
				break
	if not still_valid:
		_selected_dose = null

	UI.clear_cards(_dose_list)
	_dose_buttons.clear()
	_dose_empty.visible = rows.is_empty()

	for row in rows:
		var key: Array = row[1]
		var dose := session.dose(key[0], key[1])
		if dose.is_empty():
			continue
		var is_sel: bool = _selected_dose != null and _selected_dose == key
		var card := Button.new()
		card.custom_minimum_size = Vector2(398, 78)
		card.disabled = session.paused
		UI.style_slot_button(card, is_sel, false)
		card.pressed.connect(_select_dose.bind(key))
		_dose_list.add_child(card)
		_dose_buttons.append(card)

		UI.icon_rect(card, UI.ICON_ESSENCE if key[0] else UI.ICON_POTION, Rect2(12, 20, 34, 34))
		var name_lbl := UI.label(card, str(row[0]), Rect2(54, 8, 330, 28), 18, UI.GOLD if is_sel else UI.CREAM)
		name_lbl.clip_text = true
		var eff_row := UI.make_effect_row(dose.effect, 20, 17, false)
		eff_row.position = Vector2(54, 42)
		card.add_child(eff_row)


func _select_dose(key: Array) -> void:
	if session.paused:
		return
	if _selected_dose != null and _selected_dose == key:
		_selected_dose = null
	else:
		_selected_dose = key
	_rebuild_dose_list()
	_refresh_dose()


func _move_dose(step: int) -> void:
	var rows := Alchemy.medicine_rows(session)
	if rows.is_empty():
		return
	var current := -1 if step > 0 else 0
	for i in rows.size():
		if rows[i][1] == _selected_dose:
			current = i
			break
	var next := posmod(current + step, rows.size())
	if rows[next][1] != _selected_dose:
		_select_dose(rows[next][1])
	UI.reveal(_dose_scroll, _dose_buttons[next])


func _refresh_dose() -> void:
	var selected := session.get_soul(shop.selected_id)
	var preview := {}
	if _selected_dose != null:
		preview = session.preview(shop.selected_id, _selected_dose[0], _selected_dose[1])
	soul_hud.set_state(selected, preview, session.day, session.requirements)
	_serve_button.disabled = session.paused or preview.is_empty()
	if preview.is_empty():
		_dose_preview.text = "按 W / S 选择药剂，预览属性变化"
		_dose_preview.add_theme_color_override("font_color", UI.MUTED)
	else:
		var after: Vector3i = preview.after
		var ok := session.is_eligible(after)
		_dose_preview.text = "预览饮后：%d / %d / %d　%s" % [after.x, after.y, after.z, "✓ 全部达标" if ok else "仍需继续调整"]
		_dose_preview.add_theme_color_override("font_color", UI.GOOD if ok else UI.GOLD)


func _serve_dose() -> void:
	if not _serve_button.disabled:
		var chosen: Array = _selected_dose
		_selected_dose = null
		session.serve(shop.selected_id, chosen[0], chosen[1])


func _refresh_rig_slots() -> void:
	var busy := river.casting or qte.is_busy()
	var values := [
		Data.RODS[qte.rod],
		Data.HOOKS[qte.hook],
		"基础握柄 %d" % (qte.grip + 1),
		Data.BAITS[qte.bait],
	]
	var badges := [
		"深水" if qte.rod == 1 else "浅水",
		"偏大" if qte.hook == 2 else ("正常" if qte.hook == 1 else "偏小"),
		"%d/%d" % [qte.durability(), Data.GRIP_CAPACITY],
		"×%d" % qte.bait_stock[qte.bait],
	]
	for i in 4:
		_rig[i].disabled = busy or session.paused
		UI.style_slot_button(_rig[i], _rig_open_slot == i or _rig_slot_cursor == i, false)
		_rig_value_labels[i].text = values[i]
		_rig_badge_labels[i].text = badges[i]
		var depleted := (i == 2 and qte.durability() == 0) or (i == 3 and qte.bait_stock[qte.bait] == 0)
		_rig_badge_labels[i].add_theme_color_override("font_color", UI.WARN if depleted else UI.MINT)
	_rig_durability_bar.queue_redraw()


func _draw_rig_durability_bar() -> void:
	if qte == null:
		return
	var rect := Rect2(Vector2.ZERO, _rig_durability_bar.size)
	_rig_durability_bar.draw_rect(rect.grow(2.0), UI.INK)
	_rig_durability_bar.draw_rect(rect, Color("29202e"))
	var ratio := clampf(float(qte.durability()) / float(Data.GRIP_CAPACITY), 0.0, 1.0)
	var col := UI.GOOD if ratio > 0.4 else UI.WARN
	var w := rect.size.x * ratio
	if w > 0.5:
		_rig_durability_bar.draw_rect(Rect2(0, 0, w, rect.size.y), col)
		_rig_durability_bar.draw_rect(Rect2(0, 2, w, 4), col.lightened(0.35))
		_rig_durability_bar.draw_rect(Rect2(0, rect.size.y - 4, w, 4), col.darkened(0.28))
	for i in range(1, Data.GRIP_CAPACITY):
		var tx := rect.size.x * (float(i) / float(Data.GRIP_CAPACITY))
		_rig_durability_bar.draw_line(Vector2(tx, 0), Vector2(tx, rect.size.y), Color(UI.INK, 0.55), 2.0)


func _refresh_river() -> void:
	if not is_instance_valid(_cast_button):
		return
	var busy := river.casting or qte.is_busy()
	if busy and _rig_slot_cursor >= 0:
		_close_rig_popup()
		return

	var show_fish := not river.casting and qte.phase == Fishing.Phase.CAUGHT and qte.locked.has("species")
	_catch_fish_rect.visible = show_fish
	if show_fish:
		var fish_size: int = qte.locked.size
		var texture := Data.fish_texture(qte.locked.species, fish_size)
		var texture_size := texture.get_size()
		var box: Vector2 = CATCH_BOX_SIZES[fish_size]
		var fit := minf(box.x / texture_size.x, box.y / texture_size.y)
		var mouth: Vector2 = FISH_MOUTH_PIXELS[texture.resource_path.get_file().get_basename()]
		var anchor := River.CATCH_LINE_END * (BASE_SIZE / Vector2(_river_viewport.size))
		_catch_fish_rect.texture = texture
		_catch_fish_rect.size = texture_size * fit
		_catch_fish_rect.pivot_offset = mouth * fit
		_catch_fish_rect.position = anchor - _catch_fish_rect.pivot_offset

	_cast_button.disabled = busy or _rig_slot_cursor >= 0 or not qte.can_cast()
	if river.casting:
		_cast_button.text = "抛竿中…"
	elif busy:
		_cast_button.text = "钓鱼中…"
	elif qte.durability() == 0 and qte.bait_stock[qte.bait] == 0:
		_cast_button.text = "耐久与鱼饵耗尽"
	elif qte.durability() == 0:
		_cast_button.text = "握柄耐久已耗尽"
	elif qte.bait_stock[qte.bait] == 0:
		_cast_button.text = "当前鱼饵 ×0"
	else:
		_cast_button.text = "空格  抛竿"
	_retract_button.disabled = not busy or session.paused

	_refresh_rig_slots()
	_rig_status.text = "握柄耐久 %d / %d　　鱼饵 ×%d" % [qte.durability(), Data.GRIP_CAPACITY, qte.bait_stock[qte.bait]]
	_rig_hint.text = "稳魂指骨自动装配 %d / %d" % [qte.equipped_charms(), qte.rod + 1]
	_rig_hint.add_theme_color_override("font_color", UI.MUTED)
	if qte.bait == Data.VARIANT_BAIT and qte.rod == 0:
		_rig_hint.text = "提示：巨刺入口仅在深水开放。"
		_rig_hint.add_theme_color_override("font_color", UI.WARN)

	_beat_panel.visible = qte.phase in [Fishing.Phase.REELING, Fishing.Phase.FEEDBACK, Fishing.Phase.TRUE_NAME] and not river.casting
	_beat_info.visible = _beat_panel.visible
	_beat_info.text = "进度 %d / %d　失误 %d / %d　剩余 %.1f 秒" % [qte.progress, qte.target, qte.mistakes, Data.MISTAKE_LIMIT, qte.get_capture_time()]
	if qte.phase == Fishing.Phase.TRUE_NAME:
		_beat_info.text = "%s　　%.1f 秒" % [qte.true_name_hint(), qte.remaining]
	_hit.text = ""
	if river.hit_timer > 0.0 and not river.casting and qte.phase in [Fishing.Phase.REELING, Fishing.Phase.FEEDBACK, Fishing.Phase.CAUGHT, Fishing.Phase.ESCAPED]:
		_hit.text = "完美 +%d" % qte.last_progress_gain if qte.last_judgement == Fishing.Judgement.PERFECT else ("+%d" % qte.last_progress_gain if qte.last_success else "失误")
	if _rig_slot_cursor >= 0:
		_river_status.text = "更换钓组部件"
		if _rig_open_slot >= 0:
			var keys := "WASD" if _rig_popup_grid.columns > 1 else "W / S"
			_river_hint.text = "%s 选择　空格 确认更换　C 返回槽位" % keys
		else:
			_river_hint.text = "W / S 选槽位　空格 查看可选部件　C 结束换件"
		return
	if river.casting:
		_river_status.text = "抛竿中　%d / 4" % (river.get_cast_frame() + 1)
		_river_hint.text = "浮漂入水后开始候鱼。"
		return
	match qte.phase:
		Fishing.Phase.READY:
			_river_status.text = "冥河很静。" if qte.last_message.is_empty() else qte.last_message
			_river_hint.text = "空格抛竿，钓获可带去提炼。"
		Fishing.Phase.WAITING:
			_river_status.text = "候鱼中…"
			_river_hint.text = "按 X 收竿。离开河岸后看到上钩气泡，请在 3 秒内按 Q 返回。"
		Fishing.Phase.PREPARING, Fishing.Phase.REELING, Fishing.Phase.FEEDBACK:
			_river_status.text = "有鱼上钩了！"
			_river_hint.text = "入水点靠近虚线时，按箭头对应的 WASD 或方向键。"
			if qte.phase == Fishing.Phase.FEEDBACK and not qte.last_message.is_empty():
				_river_hint.text = "%s，进度 %d。" % [qte.last_message, qte.last_progress_gain] if qte.last_progress_gain < 0 else "%s，进度已为 0。" % qte.last_message
		Fishing.Phase.TRUE_NAME:
			_river_status.text = "神秘鱼影 · 真名捕获"
			_river_hint.text = "依次输入出现的字母，输错后从头开始。"
		Fishing.Phase.CAUGHT:
			_river_status.text = qte.last_message
			_river_hint.text = "空格抛竿，继续钓鱼。" if qte.locked.has("bone") else "按 R 前往炼药台查看鱼获并提炼，或再抛一竿。"
		Fishing.Phase.ESCAPED:
			_river_status.text = qte.last_message
			_river_hint.text = "可以再次抛竿。"
	if not busy and not qte.can_cast() and not session.paused:
		if qte.durability() == 0 and qte.bait_stock[qte.bait] == 0:
			_river_hint.text = "握柄耐久与当前鱼饵均已耗尽，按 T 去市场维修并补充鱼饵。"
		elif qte.durability() == 0:
			_river_hint.text = "当前握柄耐久已耗尽，按 T 去市场维修，或按 Shift 更换备用握柄。"
		elif qte.has_any_bait():
			_river_hint.text = "当前「%s」已耗尽，按 Shift 换饵，或按 T 购买。" % Data.BAITS[qte.bait]
		else:
			_river_hint.text = "当前「%s」已耗尽，按 T 去市场补充鱼饵。" % Data.BAITS[qte.bait]


func _process(delta: float) -> void:
	if not started:
		return
	if _bone_notice_remaining > 0.0 and not session.paused:
		_bone_notice_remaining = maxf(_bone_notice_remaining - delta, 0.0)
		if _bone_notice_remaining == 0.0:
			_refresh_river_notice()
	_refresh_river()
	_arrival.text = "本班来客已全部到达" if not session.has_more_arrivals() else "%.0f 秒后有新来客" % ceilf(session.spawn_remaining)
