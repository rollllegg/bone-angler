extends Control
## The playable fishing, alchemy and soul reception loop with pixel-art UI.

const UI := preload("res://scripts/demo/demo_ui.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")
const TitleMenu := preload("res://scripts/demo/title_menu.gd")
const TitleSettings := preload("res://scripts/demo/title_settings.gd")
const StartMode := preload("res://scripts/demo/start_mode_modal.gd")
const TutorialOverlay := preload("res://scripts/demo/tutorial_overlay.gd")
const SoulHUD := preload("res://scripts/demo/soul_status_hud.gd")
const River := preload("res://scripts/demo/pixel_river.gd")
const Shop := preload("res://scripts/demo/pixel_shop.gd")
const Alchemy := preload("res://scripts/demo/alchemy_panel.gd")
const Market := preload("res://scripts/demo/market_panel.gd")
const StoryPanel := preload("res://scripts/demo/story_panel.gd")
const StoryLab := preload("res://scripts/demo/story_lab.gd")
const StoryHotspotLayer := preload("res://scripts/demo/story_hotspot_layer.gd")
const JudgmentPanel := preload("res://scripts/demo/judgment_panel.gd")
const EndingScreen := preload("res://scripts/demo/ending_screen.gd")
const DayReportPanel := preload("res://scripts/demo/day_report_panel.gd")
const CodexPanel := preload("res://scripts/demo/codex_panel.gd")
const SaveMenu := preload("res://scripts/demo/save_menu.gd")
const SaveSlots := preload("res://scripts/demo/save_slots.gd")
const StoryStage := preload("res://scripts/story/story_stage.gd")
const StoryDirector := preload("res://scripts/story/story_director.gd")
const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const BASE_SIZE := Vector2(1620, 972)
const STORY_LAB_ARG := "--story-lab"
const LEGACY_DUPLICATE_GRIP_PRICE := 30
const LOCATION_ORDER := ["River", "Shop", "Alchemy", "Market"]
const RIVER_ALERT_COLOR := Color("ff5353")
const PAUSE_ICON := preload("res://assets/art/ui/icon_pause.png")
const RESUME_ICON := preload("res://assets/art/ui/icon_resume.png")
const BONE_NOTICE_DURATION := 4.0
const BOBBER_WAIT_INTERVAL := 1.8
const FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
const FONT_FALLBACK := preload("res://assets/fonts/NotoSansSC.ttf")
const CATCH_BOX_SIZES := [Vector2(184, 112), Vector2(236, 144), Vector2(288, 176), Vector2(310, 184)]
const TUTORIAL_TIPS := {
	"tip_mix": "捕获鱼后原液自动入库。在炼药台选一种原液，消耗三份炼成一剂固定药效的成品。",
	"tip_off_river_bite": "离开河岸也会继续候鱼。看到红色 ! 后，3 秒内按 Q 返回河岸开拉。",
	"tip_day2_upper": "今日要求有属性上限。超标时可用静鳍鳅、泪纹鲦或墨眼鳉炼出的负向药剂调回区间。",
	"tip_market_supply": "按 Q / E 前往市场补饵或升级钓组。握柄耐久归零后，可在市场临修或整修。",
	"tip_concentrate": "获得了「浓缩的灵魂」。到炼药台的「强化成品」，可将一剂药的任一属性微调 ±1。",
	"tip_story_guest": "特殊来客没有常规属性判定。留意对话，可端药或点击右侧按钮呼唤真名，再决定放行或拒绝。",
	"tip_codex": "按 Tab 暂停并打开「冥河图鉴」，可查鱼种分布、原液产物概率与已发现的成品药。",
}
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
var story_panel: StoryPanel
var story_hotspots: StoryHotspotLayer
var judgment_panel: JudgmentPanel
var _ending_screen: EndingScreen
var story_stage: StoryStage
var story_director: StoryDirector
var day_report: DayReportPanel

var started: bool = false
var story_lab := false
var current_location: String = "River"
var auto_pause_on_focus_loss: bool = true
var persist_save: bool = true
var save_directory := "user://"
var tutorial_active := false
var tutorial_completed := false
var tutorial_step := 1
var seen_tips: Array[String] = []
var start_button: Button
var continue_button: Button
var settings_button: Button
var quit_button: Button

var _stage: Control
var _audio: Audio
var _bobber_sound_in := BOBBER_WAIT_INTERVAL
var _menu: TitleMenu
var _menu_pointer: Control
var _menu_buttons: Array[Button] = []
var _start_mode_modal: StartMode
var _tutorial_overlay: TutorialOverlay
var _tutorial_tips_enabled := false
var _pending_tips: Array[String] = []
var _current_tip := ""
var _settings_modal: TitleSettings
var _settings_panel: Panel
var _title_transition: ColorRect
var _hud: Control
var _river_ui: Control
var _shop_ui: Control
var _river_image: TextureRect
var _shop_image: TextureRect
var _river_viewport: SubViewport
var _shop_viewport: SubViewport
var _story_screen: Control
var _story_cue_key := ""
var _story_last_soul_id := -1
var _story_last_text := ""
var _pause_banner: Control
var _pause_buttons: Array[Button] = []
var _pause_button_animation: Tween
var _pause_bar_animation: Tween
var _codex: CodexPanel
var _paused_from_codex := false
var _save_menu: SaveMenu
var _summary: Label
var _river_button: Button
var _river_bite_alert: Label
var _river_notice: Panel
var _river_notice_title: Label
var _river_notice_detail: Label
var _bone_notice_remaining := 0.0
var _shop_button: Button
var _alchemy_button: Button
var _market_button: Button
var _previous_location_button: Button
var _next_location_button: Button
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
var _dialog_speaker: Label
var _dialog_hint: Label
var _payout_notice: Label
var _dose_scroll: ScrollContainer
var _dose_list: VBoxContainer
var _dose_buttons: Array[Button] = []
var _dose_empty: Label
var _selected_dose: Variant = null
var _dose_preview: Label
var _serve_button: Button
var _release_button: Button
var _story_action_button: Button

var _held_keys: Dictionary = {}
var _pending_directions: Array[int] = []
var _requires_release := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_audio = Audio.new()
	_audio.name = "DemoAudio"
	add_child(_audio)
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
	river.cast_finished.connect(_audio.play.bind(Audio.Cue.BOBBER_SPLASH))

	var shop_display := _pixel_display(Shop)
	shop = shop_display["world"]
	_shop_image = shop_display["image"]
	_shop_viewport = shop_display["viewport"]
	shop.bind(session)
	shop.walk_started.connect(_audio.play.bind(Audio.Cue.FOOTSTEPS))

	_story_screen = Control.new()
	_story_screen.size = BASE_SIZE
	_story_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_story_screen)
	story_stage = StoryStage.new()
	story_stage.name = "StoryStage"
	_stage.add_child(story_stage)
	story_stage.bind(shop, _story_screen)
	story_director = StoryDirector.new()
	story_director.set_stage(story_stage)


	_build_menu()
	_build_hud()
	_build_river_ui()
	_build_shop_ui()


	alchemy = Alchemy.new()
	alchemy.name = "Alchemy"
	_stage.add_child(alchemy)
	alchemy.setup(session, _audio)
	alchemy.tab_changed.connect(_refresh_tutorial)

	market = Market.new()
	market.name = "Market"
	_stage.add_child(market)
	market.setup(qte, _audio)

	_build_pause()
	_build_river_notice()
	_tutorial_overlay = TutorialOverlay.new()
	_tutorial_overlay.name = "TutorialOverlay"
	_stage.add_child(_tutorial_overlay)
	_tutorial_overlay.setup(BASE_SIZE, _audio)
	_tutorial_overlay.skip_requested.connect(_finish_tutorial)
	_tutorial_overlay.finish_requested.connect(_finish_tutorial)
	_tutorial_overlay.tip_dismissed.connect(_advance_tutorial_tip)

	_codex = CodexPanel.new()
	_codex.name = "Codex"
	_stage.add_child(_codex)
	_codex.setup(BASE_SIZE, session, _audio)
	_codex.toggle_requested.connect(_toggle_codex_bookmark)
	_codex.close_requested.connect(_set_codex_open.bind(false))

	day_report = DayReportPanel.new()
	day_report.name = "DayReport"
	_stage.add_child(day_report)
	day_report.closed.connect(_close_day_report)

	_save_menu = SaveMenu.new()
	_stage.add_child(_save_menu)
	_save_menu.setup(BASE_SIZE, _audio)
	_save_menu.slot_selected.connect(_select_save_slot)
	_save_menu.overwrite_confirmed.connect(_save_to_slot)
	_save_menu.delete_confirmed.connect(_delete_save_slot)

	_build_title_modals()
	_title_transition = ColorRect.new()
	_title_transition.size = BASE_SIZE
	_title_transition.color = UI.INK
	_title_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_transition.hide()
	_stage.add_child(_title_transition)

	shop.presentation_changed.connect(_refresh_shared)
	story_stage.view_changed.connect(_on_story_view_changed)
	qte.state_changed.connect(_refresh_river)
	qte.state_changed.connect(_refresh_river_notice)
	qte.bone_recovered.connect(_show_bone_notice)
	qte.state_changed.connect(_refresh_economy)
	qte.state_changed.connect(_refresh_tutorial)
	resized.connect(_resize)
	_resize()
	_update_activation()
	_refresh_shared()
	_refresh_river()
	if STORY_LAB_ARG in OS.get_cmdline_user_args():
		_start_story_lab.call_deferred()


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
	_menu = TitleMenu.new()
	_stage.add_child(_menu)
	_menu.setup(BASE_SIZE, _open_start_mode, _open_save_slots.bind(false), _open_settings, _quit_from_title, _audio)
	_menu_buttons = _menu.buttons
	_menu_pointer = _menu.pointer
	start_button = _menu_buttons[0]
	continue_button = _menu_buttons[1]
	settings_button = _menu_buttons[2]
	quit_button = _menu_buttons[3]
	_refresh_continue_button()


func _build_title_modals() -> void:
	_start_mode_modal = StartMode.new()
	_stage.add_child(_start_mode_modal)
	_start_mode_modal.setup(BASE_SIZE, _audio)
	_start_mode_modal.mode_selected.connect(_start_game)
	_settings_modal = TitleSettings.new()
	_stage.add_child(_settings_modal)
	_settings_modal.setup(BASE_SIZE, _set_display_mode, _set_auto_pause, _audio)
	_settings_panel = _settings_modal.panel
	_refresh_settings_ui()


func _open_start_mode() -> void:
	_start_mode_modal.open()


func _select_title_button(index: int) -> void:
	if index != _menu.cursor and not _menu_buttons[index].disabled:
		_audio.play(Audio.Cue.UI_CLICK)
	_menu.select(index)


func _refresh_continue_button() -> void:
	var available := has_save()
	continue_button.disabled = not available
	continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	if not available and _menu_buttons[_menu.cursor] == continue_button:
		_menu.select(0)


func _open_settings() -> void:
	_refresh_settings_ui()
	_settings_modal.open()


func _close_settings() -> void:
	_settings_modal.dismiss()


func _set_display_mode(fullscreen: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_refresh_settings_ui()


func _set_auto_pause(enabled: bool) -> void:
	auto_pause_on_focus_loss = enabled
	_refresh_settings_ui()


func _refresh_settings_ui() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_settings_modal.sync_options(fullscreen, auto_pause_on_focus_loss)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_hud)
	UI.panel(_hud, Rect2(24, 18, 1572, 78), "dark_wood")
	_summary = UI.label(_hud, "", Rect2(103, 34, 874, 44), 20, UI.GOLD)
	_previous_location_button = UI.button(_hud, "< Q", Rect2(1012, 32, 54, 48), _cycle_location.bind(-1))
	_previous_location_button.accessibility_name = "上一个地点"
	_next_location_button = UI.button(_hud, "E >", Rect2(1522, 32, 54, 48), _cycle_location.bind(1))
	_next_location_button.accessibility_name = "下一个地点"
	_next_location_button.tooltip_text = "下一个地点（E）"
	_river_button = UI.tab_button(_hud, "河岸", Rect2(1074, 32, 104, 48), _show_location.bind("River", true), true)
	_shop_button = UI.tab_button(_hud, "接待", Rect2(1186, 32, 104, 48), _show_location.bind("Shop", true))
	_alchemy_button = UI.tab_button(_hud, "炼药", Rect2(1298, 32, 104, 48), _show_location.bind("Alchemy", true))
	_market_button = UI.tab_button(_hud, "市场", Rect2(1410, 32, 104, 48), _show_location.bind("Market", true))
	for b in [_river_button, _shop_button, _alchemy_button, _market_button]:
		b.add_theme_font_size_override("font_size", 24)
	_river_bite_alert = UI.label(_river_button, "!", Rect2(8, 0, 18, 48), 24, RIVER_ALERT_COLOR)
	var alert_font := FontVariation.new()
	alert_font.base_font = FONT
	alert_font.variation_transform = Transform2D(Vector2(1.8, 0), Vector2.DOWN, Vector2.ZERO)
	_river_bite_alert.add_theme_font_override("font", alert_font)
	_river_bite_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_river_bite_alert.hide()
	_pause_button = UI.button(_hud, "", Rect2(36, 29, 54, 54), func() -> void: _set_paused(not session.paused))
	_pause_button.pressed.connect(_audio.play.bind(Audio.Cue.UI_CLICK))
	_pause_button.pivot_offset = _pause_button.size * 0.5
	var icon_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed"]:
		_pause_button.add_theme_stylebox_override(state, icon_style)
	var focus_style := UI.style(Color.TRANSPARENT, UI.MINT.darkened(0.35))
	focus_style.draw_center = false
	focus_style.set_border_width_all(2)
	focus_style.anti_aliasing = false
	_pause_button.add_theme_stylebox_override("focus", focus_style)
	_pause_button.add_theme_color_override("icon_focus_color", UI.MINT)
	_pause_button.add_theme_color_override("icon_hover_color", UI.GOLD)
	_pause_button.add_theme_color_override("icon_pressed_color", UI.GOLD.darkened(0.22))


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
	_shop_ui.size = BASE_SIZE
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
	_dose_empty = UI.label(_shop_ui, "暂无成品药\n按 E 前往炼药台，用三份原液炼药", Rect2(56, 548, 392, 86), 20, UI.MUTED)
	_dose_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UI.panel(_shop_ui, Rect2(44, 824, 416, 40), "wood_inset")
	_dose_preview = UI.label(_shop_ui, "点击上方药剂查看属性变化预览", Rect2(54, 826, 396, 36), 17, UI.CREAM)
	_dose_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dose_preview.clip_text = true
	_serve_button = UI.button(_shop_ui, "空格  端上所选药剂", Rect2(44, 872, 416, 58), _serve_dose, true)
	_serve_button.add_theme_font_size_override("font_size", 22)

	# 3. Top-Center: Guest Speech Parchment Box (floating above guest, open counter!)
	UI.panel(_shop_ui, Rect2(492, 112, 578, 116), "parchment")
	_dialog_speaker = UI.label(_shop_ui, "", Rect2(516, 122, 380, 22), 16, Color("eef2f8"))
	_dialog_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_speaker.hide()
	_dialog = UI.label(_shop_ui, "", Rect2(516, 146, 530, 50), 21, UI.CREAM)
	_dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialog.gui_input.connect(_on_dialog_input)
	_dialog_hint = UI.label(_shop_ui, "F 继续", Rect2(954, 192, 92, 18), 15, UI.GOLD)
	_dialog_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dialog_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_hint.hide()
	_payout_notice = UI.label(_shop_ui, "", Rect2(516, 232, 530, 34), 20, UI.GOLD)

	# 4. Top-Right: Compact Waiting Queue in Sky (keeps underworld gate 100% visible!)
	UI.panel(_shop_ui, Rect2(1086, 112, 506, 166), "dark_wood")
	UI.icon_rect(_shop_ui, UI.ICON_SOUL, Rect2(1106, 126, 28, 28))
	UI.label(_shop_ui, "门前等候 · A / D", Rect2(1142, 124, 184, 32), 20, UI.MINT)
	_arrival = UI.label(_shop_ui, "", Rect2(1300, 126, 272, 28), 16, UI.MUTED)
	_arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrival.gui_input.connect(_on_story_lab_reset_input)

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
	_release_button = UI.button(_shop_ui, "Shift  放行", Rect2(1168, 862, 404, 68), _release_guest, true)
	_release_button.add_theme_font_size_override("font_size", 25)
	_story_action_button = UI.button(_shop_ui, "", Rect2(1376, 862, 196, 68), _story_action)
	_story_action_button.add_theme_font_size_override("font_size", 22)

	story_panel = StoryPanel.new()
	story_panel.name = "TrueNameChallenge"
	story_panel.position = Vector2(500, 232)
	story_panel.size = Vector2(562, 104)
	_shop_ui.add_child(story_panel)

	judgment_panel = JudgmentPanel.new()
	judgment_panel.name = "JudgmentPanel"
	judgment_panel.position = Vector2(400, 300)
	_shop_ui.add_child(judgment_panel)
	judgment_panel.submitted.connect(_on_judgment_submitted)

	story_hotspots = StoryHotspotLayer.new()
	story_hotspots.name = "StoryHotspots"
	story_hotspots.setup(shop)
	_shop_ui.add_child(story_hotspots)
	story_hotspots.choice_made.connect(_on_story_hotspot)

	_ending_screen = EndingScreen.new()
	_ending_screen.name = "EndingScreen"
	_ending_screen.finished.connect(_return_to_title)
	_stage.add_child(_ending_screen)


func _build_pause() -> void:
	_pause_banner = Control.new()
	_pause_banner.position = Vector2(100, 32)
	_pause_banner.size = Vector2(900, 52)
	_pause_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_pause_banner)
	UI.label(_pause_banner, "已暂停", Rect2(4, 0, 88, 48), 22, UI.MINT)
	var labels := ["F  保存游戏", "R  读取存档", "T  返回封面", "G  设置"]
	var actions := [_open_save_slots.bind(true), _open_save_slots.bind(false), _return_to_title, _open_settings]
	for index in labels.size():
		var button := UI.button(_pause_banner, labels[index], Rect2(96 + index * 141, 0, 132, 48), actions[index])
		button.add_theme_font_size_override("font_size", 20)
		if actions[index] != _return_to_title:
			button.pressed.connect(_audio.play.bind(Audio.Cue.UI_CLICK))
		_pause_buttons.append(button)
	UI.label(_pause_banner, "Esc 继续　Tab 图鉴", Rect2(667, 0, 222, 48), 17, UI.CREAM)


func _resize() -> void:
	_stage.scale = size / BASE_SIZE


func _start_game(with_tutorial: bool = false) -> void:
	if started:
		return
	_close_settings()
	_start_mode_modal.dismiss()
	tutorial_active = with_tutorial
	_tutorial_tips_enabled = with_tutorial
	started = true
	if with_tutorial:
		qte.enable_tutorial_catch(Data.RIVER_CARP, 1)
	session.start_shift(with_tutorial)
	_show_location("River")
	_title_transition.modulate.a = 1.0
	_title_transition.show()
	var fade := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade.tween_property(_title_transition, "modulate:a", 0.0, 0.26)
	fade.tween_callback(_title_transition.hide)


func _restore_tutorial(saved: Dictionary, fishing: Dictionary) -> void:
	tutorial_completed = bool(saved.get("completed", saved.is_empty()))
	tutorial_active = bool(saved.get("active", false)) and not tutorial_completed
	_tutorial_tips_enabled = bool(saved.get("tips_enabled", not saved.is_empty()))
	tutorial_step = clampi(int(saved.get("step", 1)), 1, 6)
	seen_tips.clear()
	for tip in saved.get("seen_tips", []):
		if tip is String and not seen_tips.has(tip):
			seen_tips.append(tip)
	_pending_tips.clear()
	_current_tip = ""
	_tutorial_overlay.clear_tip()
	session.tutorial_pause_arrivals = tutorial_active
	if not tutorial_active:
		return
	if session.released_count > 0 or session.day > 1:
		tutorial_active = false
		tutorial_completed = true
		tutorial_step = 6
		session.resume_tutorial_arrivals()
	elif bool(fishing.get("tutorial_catch", false)) or (not qte.is_busy() and not session.codex_fish.has(Data.FISH[Data.RIVER_CARP].id)):
		qte.enable_tutorial_catch(Data.RIVER_CARP, 1)


func _finish_tutorial() -> void:
	if not tutorial_active:
		return
	tutorial_active = false
	tutorial_completed = true
	qte.clear_tutorial_catch()
	session.resume_tutorial_arrivals()
	_refresh_river()
	_refresh_tutorial()


func _refresh_tutorial() -> void:
	if not started:
		return
	var suspended := session.is_time_suspended()
	_tutorial_overlay.set_tip_context(current_location, suspended or qte.phase == Fishing.Phase.TRUE_NAME)
	if tutorial_active and not suspended:
		_show_tutorial_step()
	else:
		_tutorial_overlay.hide_guide()
	if tutorial_completed and _tutorial_tips_enabled and not suspended:
		_check_tutorial_tips()


func _show_tutorial_step() -> void:
	if session.released_count > 0:
		tutorial_step = 6
		_tutorial_overlay.set_step(6, "引导完成 · 自由值班", "钓鱼获得原液，三份同种原液炼一剂药。\n按 Q / E 切换地点，Tab 暂停查图鉴。", Rect2(), Vector2(507, 643))
		return
	var caught := session.codex_fish.has(Data.FISH[Data.RIVER_CARP].id)
	if not caught:
		_show_tutorial_fishing()
		return
	var usable := false
	for potion in session.potions:
		var preview := session.preview(Session.TUTORIAL_GUEST_ID, false, potion.id)
		usable = usable or (not preview.is_empty() and session.is_eligible(preview.after))
	if usable or session.can_release(Session.TUTORIAL_GUEST_ID):
		_show_tutorial_reception(session.can_release(Session.TUTORIAL_GUEST_ID))
		return
	tutorial_step = 3
	if current_location != "Alchemy":
		_show_tutorial_target("去炼药台", "鱼获已自动转换为原液。\n点击顶部「炼药」，或从接待窗口按 E。", _alchemy_button, Vector2(982, 120))
	elif alchemy.active_tab != 0:
		_show_tutorial_target("切到纯炼制药", "按 Shift 或点击「纯炼制药」。", alchemy._tab_buttons[0], Vector2(46, 192))
	elif alchemy.selected_source != Data.RIVER_CARP:
		_show_tutorial_target("选择冥河原液", "选中左侧的冥河原液。三份同种原液可炼一剂。", alchemy.essence_cards[1], Vector2(350, 550))
	else:
		_show_tutorial_target("炼制成品药", "消耗三份冥河原液炼药。\n暖心药与升阶的通情药都能完成这位邮差的需求。", alchemy.mix_button, Vector2(350, 681))


func _show_tutorial_fishing() -> void:
	var pulling := qte.phase in [Fishing.Phase.PREPARING, Fishing.Phase.REELING, Fishing.Phase.HOLDING, Fishing.Phase.RELEASE_WAIT, Fishing.Phase.FEEDBACK]
	tutorial_step = 2 if pulling else 1
	if current_location != "River":
		var message := "点击顶部「河岸」，回到水边抛竿。" if not qte.is_busy() else "点击顶部「河岸」，回到水边继续钓鱼。"
		if qte.phase == Fishing.Phase.AWAITING_RETURN:
			message = "鱼已上钩！看到红色 ! 后，3 秒内按 Q 返回河岸。"
		_show_tutorial_target("回到河岸", message, _river_button, Vector2(982, 120))
	elif pulling:
		var prompts := [
			"入水点到达虚线边界时，照右侧箭头点按一次，与鱼的拉扯方向相反。",
			"入水点到达边界时，照右侧箭头按住方向键。\n等框下的拖拽条耗尽再松手。",
			"到达边界时照右侧箭头按住方向键。\n等金环亮起、鱼线变金时，立刻松手！",
		]
		var message: String = prompts[qte.round_action]
		if qte.needs_rehold:
			message = qte.get_action_prompt() + "\n重新按住后，从这一拍继续。"
		elif qte.phase == Fishing.Phase.RELEASE_WAIT:
			message = qte.get_action_prompt() + "\n金环已经亮起，鱼线变金。现在松手！"
		elif qte.last_judgement == Fishing.Judgement.MISS and qte.phase in [Fishing.Phase.REELING, Fishing.Phase.FEEDBACK]:
			message += "\n" + qte.last_message + "，松开按键后重练本拍。"
		var scale_to_stage := Transform2D(0.0, BASE_SIZE / Vector2(_river_viewport.size), 0.0, Vector2.ZERO)
		var timing := scale_to_stage * River.TIMING_FRAME.grow(12).merge(Rect2(270, 120, 24, 26))
		var title: String = ["点拉", "持续绷线", "猛冲时松手"][qte.round_action]
		_tutorial_overlay.set_step(2, title, message, timing.merge(_tutorial_rect(_beat_panel)), Vector2(530, 796))
	elif river.casting or qte.phase == Fishing.Phase.WAITING:
		_show_tutorial_target("等鱼上钩", "浮漂入水后稍等片刻。\n鱼咬钩后，留意河面判定框和右侧的方向箭头。", _river_status, Vector2(82, 610))
	elif not qte.can_cast():
		_show_tutorial_target("补齐钓鱼用品", "握柄没有耐久或当前鱼饵用尽时，可到市场维修或补饵。\n准备好后回河岸继续。", _market_button, Vector2(982, 120))
	else:
		_show_tutorial_target("在河岸抛竿", "你是冥河的骷髅引渡者，要钓鱼炼药，为来客补全灵魂。\n按 Space 或点击「抛竿」。", _cast_button, Vector2(978, 620))


func _show_tutorial_reception(ready_to_release: bool) -> void:
	var selected := _selected_dose != null and not _serve_button.disabled
	tutorial_step = 5 if ready_to_release or (current_location == "Shop" and selected) else 4
	if current_location != "Shop":
		var message := "点击顶部「接待」，或从炼药台按 Q 返回接待窗口。\n邮差已在窗口等候。"
		_show_tutorial_target("去接待窗口", message, _shop_button, Vector2(982, 120))
	elif ready_to_release:
		_show_tutorial_target("放行来客", "按 Shift 或点击「放行」。一剂达标可拿全额奖金，\n从第二剂起，每多用一剂，奖金减半。", _release_button, Vector2(518, 670))
	elif selected:
		var preview := session.preview(shop.selected_id, _selected_dose[0], _selected_dose[1])
		var message := "核对左上角的药效预览，再按 Space 或点击端药。\n给邮差选择能补充情感的成品药，达到当天要求即可。"
		if not session.is_eligible(preview.after):
			message = "预览显示这剂药还不能达标。可按 C 取消，\n重新选药，或端药后继续补足没达标的属性。"
		_show_tutorial_target("端上药剂", message, _serve_button, Vector2(500, 690))
	else:
		var medicine := "选中暖心药或通情药"
		var message := "按 W / S 或点击%s。绿色区间是当日达标线。\n左上角的半透明预览会显示饮药后是否「→ 达标」。" % medicine
		_tutorial_overlay.set_step(4, "查看区间与药效", message, _tutorial_rect(soul_hud).merge(_tutorial_rect(_dose_scroll)), Vector2(500, 358))


func _tutorial_rect(control: Control) -> Rect2:
	var relative := _stage.get_global_transform().affine_inverse() * control.get_global_transform()
	return relative * Rect2(Vector2.ZERO, control.size)


func _show_tutorial_target(title: String, message: String, target: Control, card_origin: Vector2) -> void:
	_tutorial_overlay.set_step(tutorial_step, title, message, _tutorial_rect(target), card_origin)


func _check_tutorial_tips() -> void:
	var upper := session.requirements[1]
	var conditions := {
		"tip_mix": current_location == "Alchemy" and session.essences.reduce(func(total: int, count: int) -> int: return total + count, 0) >= 3,
		"tip_off_river_bite": qte.phase == Fishing.Phase.AWAITING_RETURN,
		"tip_day2_upper": session.day >= 2 and mini(upper.x, mini(upper.y, upper.z)) < Session.STAT_MAX,
		"tip_market_supply": not river.casting and not qte.is_busy() and (qte.durability() <= 2 or qte.bait_stock[qte.bait] == 0),
		"tip_concentrate": session.concentrate > 0,
		"tip_story_guest": current_location == "Shop" and session.has_story_case(shop.selected_id),
		"tip_codex": _can_show_codex_tip() and session.has_unseen_codex(),
	}
	for tip: String in conditions:
		if conditions[tip] and not seen_tips.has(tip) and not _pending_tips.has(tip):
			if tip == "tip_off_river_bite":
				_pending_tips.push_front(tip)
				_current_tip = ""
			else:
				_pending_tips.append(tip)
	_show_next_tutorial_tip()


func _can_show_codex_tip() -> bool:
	return not qte.is_line_action() and qte.phase not in [Fishing.Phase.PREPARING, Fishing.Phase.FEEDBACK, Fishing.Phase.TRUE_NAME] and not story_panel.is_typing()


func _advance_tutorial_tip() -> void:
	_current_tip = ""
	_show_next_tutorial_tip()


func _show_next_tutorial_tip() -> void:
	if not _current_tip.is_empty() or session.is_time_suspended() or qte.phase == Fishing.Phase.TRUE_NAME:
		return
	for i in _pending_tips.size():
		var tip := _pending_tips[i]
		if tip == "tip_codex" and not _can_show_codex_tip():
			continue
		_pending_tips.remove_at(i)
		_current_tip = tip
		seen_tips.append(tip)
		_tutorial_overlay.show_tip(TUTORIAL_TIPS[tip])
		return


func _start_story_lab() -> void:
	if started:
		return
	story_lab = true
	persist_save = false
	started = true
	_arrival.mouse_filter = Control.MOUSE_FILTER_STOP
	_arrival.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reset_story_lab()


func _reset_story_lab() -> void:
	if not story_lab:
		return
	story_panel.cancel_callout()
	judgment_panel.close()
	_ending_screen.close()
	story_director.cancel()
	story_stage.reset()
	shop.clear_departures()
	shop.clear_story_sprite()
	shop.selected_id = -1
	shop.fed_flash = 0.0
	_story_last_soul_id = -1
	_story_last_text = ""
	_selected_dose = null
	StoryLab.populate(session)
	_story_lab_select_guest()
	_show_location("Shop")
	session.state_changed.emit()
	_refresh_shared()
	print("Story lab: day %d, %d special guest(s), %d potion(s); N restarts" % [session.day, session.souls.size(), session.potions.size()])


func _on_story_lab_reset_input(event: InputEvent) -> void:
	if story_lab and not session.paused and not story_panel.is_typing() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_reset_story_lab()
		_arrival.accept_event()


func _story_lab_select_guest() -> void:
	if session.souls.is_empty():
		return
	for soul in session.souls:
		if soul.has("story_case"):
			shop.select_guest(int(soul.id))
			return
	for soul in session.souls:
		if int(soul.case_id) == Data.DROWNED_LYRE_PLAYER:
			shop.select_guest(int(soul.id))
			return
	shop.select_guest(int(session.souls[0].id))



func _return_to_title() -> void:
	_audio.play(Audio.Cue.UI_CLICK, true)
	# Keep the current viewport attached until the button input finishes dispatching.
	get_tree().reload_current_scene.call_deferred()


func _quit_from_title() -> void:
	# Let the title confirmation finish before closing the audio device.
	_menu.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	set_process_unhandled_key_input(false)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func has_save() -> bool:
	if persist_save:
		for slot in SaveSlots.COUNT:
			if not SaveSlots.existing_path(save_directory, slot).is_empty():
				return true
	return false


func _open_save_slots(for_save: bool) -> void:
	_save_menu.open(for_save, _save_slot_entries())


func _save_slot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for slot in SaveSlots.COUNT:
		var path := SaveSlots.existing_path(save_directory, slot) if persist_save else ""
		var data := SaveSlots.read(path)
		var summary := "空位" if path.is_empty() else "存档无法读取"
		if not data.is_empty():
			var day: Dictionary = data.get("day_schedule", {})
			var day_number := int(day.get("number", mini(Session.DAY_COUNT, 1 + floori(float(data.released_count) / Session.GUESTS_PER_DAY))))
			summary = "第 %d 天　渡魂币 %d" % [day_number, int(data.coins)]
			if data.has("saved_at"):
				summary += "　%s" % data.saved_at
		entries.append({"summary": summary, "occupied": not path.is_empty()})
	return entries


func _select_save_slot(slot: int) -> void:
	if not _save_menu.saving:
		if load_progress(slot):
			_audio.play(Audio.Cue.UI_CONFIRM)
		else:
			_save_menu.update_slots(_save_slot_entries())
			_save_menu.show_status("读取失败，请选择其他存档。", true)
		return
	if persist_save and not SaveSlots.existing_path(save_directory, slot).is_empty():
		_audio.play(Audio.Cue.UI_CLICK)
		_save_menu.ask_overwrite(slot)
		return
	_save_to_slot(slot)


func _save_to_slot(slot: int) -> void:
	if not save_progress(slot):
		_save_menu.show_status("保存失败，请重试。", true)
		return
	_audio.play(Audio.Cue.UI_CONFIRM)
	_save_menu.update_slots(_save_slot_entries())
	_save_menu.show_status("已保存到存档 %d。" % (slot + 1))
	_refresh_continue_button()
	_pause_buttons[1].disabled = false


func _delete_save_slot(slot: int) -> void:
	var removed := persist_save and SaveSlots.remove(save_directory, slot)
	_save_menu.update_slots(_save_slot_entries())
	_refresh_continue_button()
	_pause_buttons[1].disabled = continue_button.disabled
	if removed:
		_audio.play(Audio.Cue.UI_CONFIRM)
		_save_menu.show_status("已删除存档 %d。" % (slot + 1))
	else:
		_save_menu.show_status("删除失败，请重试。", true)


func save_progress(slot: int) -> bool:
	if not persist_save or not started or slot < 0 or slot >= SaveSlots.COUNT:
		return false
	var saved_potions: Array = []
	for p in session.potions:
		saved_potions.append({
			"id": int(p.id), "kind": str(p.kind), "name": str(p.name),
			"effect": [p.effect.x, p.effect.y, p.effect.z],
			"attribute": int(p.attribute), "adjustment": int(p.adjustment),
		})
	var saved_souls: Array = []
	for s in session.souls:
		var entry := {
			"id": int(s.id), "case_id": int(s.case_id), "name": str(s.name),
			"stats": [s.stats.x, s.stats.y, s.stats.z],
			"before": [s.before.x, s.before.y, s.before.z],
			"served": bool(s.served), "doses_used": Session.doses_used(s), "fee": int(s.fee),
		}
		if s.has("story_case"):
			entry["story_case"] = str(s.story_case)
			entry["story_state"] = s.get("story_state", {})
			entry["story_outcome"] = str(s.get("story_outcome", ""))
		if str(s.get("story_echo", "")) != "":
			entry["story_echo"] = str(s.story_echo)
		saved_souls.append(entry)
	var payload := {
		"rules_version": Data.RULES_VERSION,
		"alchemy_rules": session.save_rules(),
		"codex_sources": session.codex_sources,
		"variant_craft_unlocked": qte.variant_craft_unlocked,
		"saved_at": Time.get_datetime_string_from_system(false, true).substr(0, 16),
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
		"codex_fish": session.codex_fish,
		"codex_recipes": session.codex_recipes,
		"souls": saved_souls,
		"rod": qte.rod,
		"hook": qte.hook,
		"bait": qte.bait,
		"rods_owned": qte.rods_owned,
		"hooks_owned": qte.hooks_owned,
		"grip_durability": qte.grip_durability,
		"quick_repair_available": qte.quick_repair_available,
		"charms_owned": qte.charms_owned,
		"bait_stock": qte.bait_stock,
		"story": session.story_state.snapshot(),
		"day_report": {
			"entries": session.day_story_entries,
			"pending": session.pending_day_report,
			"awaiting": session.awaiting_day_report,
		},
		"rejected_count": session.rejected_count,
		"tutorial": {
			"active": tutorial_active, "completed": tutorial_completed,
			"step": tutorial_step, "seen_tips": seen_tips,
			"tips_enabled": _tutorial_tips_enabled,
		},
		"fishing": qte.save_pending(),
		"casting": river.casting,
		"cast_elapsed": river.cast_elapsed,
	}
	return SaveSlots.write(save_directory, slot, payload)


func load_progress(slot: int) -> bool:
	if not persist_save or slot < 0 or slot >= SaveSlots.COUNT:
		return false
	var data := SaveSlots.read(SaveSlots.existing_path(save_directory, slot))
	if data.is_empty():
		return false
	_save_menu.dismiss()
	_close_settings()
	_start_mode_modal.dismiss()
	_close_rig_popup()
	_clear_pull_input()
	_audio.stop(Audio.Cue.FERRY)
	_audio.stop(Audio.Cue.FOOTSTEPS)
	_audio.stop(Audio.Cue.BOBBER_WAIT)
	_bobber_sound_in = BOBBER_WAIT_INTERVAL
	session.active = false
	session.paused = false
	_paused_from_codex = false
	_codex.present(false, false)
	session.last_payout = 0
	session.last_story_outcome = ""
	shop.selected_id = -1
	shop.departure_times.clear()
	shop.fed_flash = 0.0
	_selected_dose = null
	_bone_notice_remaining = 0.0
	session.coins = int(data.get("coins", Data.STARTING_COINS))
	session.released_count = int(data.get("released_count", 0))
	session.rejected_count = int(data.get("rejected_count", data.get("failed_count", 0)))
	session._arrived = int(data.get("arrived", 0))
	session._next_item_id = int(data.get("next_item_id", 1))
	session.spawn_remaining = float(data.get("spawn_remaining", Data.ARRIVAL_MIN))
	session.concentrate = int(data.get("concentrate", 0))
	session.recovered_bones = int(data.get("recovered_bones", 0))
	session.finger_bones = int(data.get("finger_bones", 0))
	session.restore_story(data.get("story", {}))
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
	for i in session.essences.size():
		session.essences[i] = int(ess[i]) if i < ess.size() else 0
	session.potions.clear()
	for p in data.get("potions", []):
		if p is Dictionary:
			var e: Array = p.get("effect", [0, 0, 0])
			session.potions.append({
				"id": int(p.get("id", 0)), "kind": str(p.get("kind", "")), "name": str(p.get("name", "")),
				"effect": Vector3i(int(e[0]), int(e[1]), int(e[2])),
				"attribute": int(p.get("attribute", -1)), "adjustment": int(p.get("adjustment", 0)),
			})
	var legacy_alchemy := int(data.get("rules_version", 0)) < Data.RULES_VERSION
	if legacy_alchemy:
		session.migrate_legacy_inventory()
	session.restore_codex(data)
	session.souls.clear()
	var fees_to_recalculate: Array[Dictionary] = []
	var from_v15 := int(data.get("rules_version", 0)) == 15
	for s in data.get("souls", []):
		if s is Dictionary:
			var st: Array = s.get("stats", [8, 8, 8])
			var bf: Array = s.get("before", st)
			var soul := {
				"id": int(s.get("id", 0)), "case_id": int(s.get("case_id", 0)), "name": str(s.get("name", "")),
				"stats": Vector3i(int(st[0]), int(st[1]), int(st[2])),
				"before": Vector3i(int(bf[0]), int(bf[1]), int(bf[2])),
				"served": bool(s.get("served", false)), "doses_used": Session.doses_used(s), "fee": int(s.get("fee", 40)),
			}
			if str(s.get("story_case", "")) != "":
				soul["story_case"] = str(s.story_case)
				soul["story_state"] = s.get("story_state", {})
				soul["story_outcome"] = str(s.get("story_outcome", ""))
			if str(s.get("story_echo", "")) != "":
				soul["story_echo"] = str(s.story_echo)
			# Retire the old observer flags and restore ordinary service pricing.
			var legacy_observer := bool(s.get("anubis_disguise", false)) or bool(s.get("fixed_stats", false))
			if str(s.get("story_case", "")) == "" and (legacy_observer or from_v15 or not s.has("doses_used") or not s.has("fee")):
				fees_to_recalculate.append(soul)
			session.souls.append(soul)
	var schedule: Dictionary = data.get("day_schedule", {})
	session.restore_day(schedule)
	if legacy_alchemy:
		for soul in session.souls:
			if not soul.has("story_case"):
				fees_to_recalculate.append(soul)
	for soul in fees_to_recalculate:
		soul.fee = session.service_fee(soul.before)
	session.story_state.run["run.day"] = session.day
	var saved_report = data.get("day_report", {})
	session.day_story_entries.clear()
	if saved_report is Dictionary:
		for entry in saved_report.get("entries", []):
			if entry is Dictionary:
				session.day_story_entries.append(entry)
		var pending = saved_report.get("pending", {})
		session.pending_day_report = pending if pending is Dictionary else {}
		session.awaiting_day_report = bool(saved_report.get("awaiting", false))
	if from_v15 and schedule.get("awaiting_next_day", false) and session.day < Session.DAY_COUNT and session.souls.is_empty() and not session.awaiting_day_report:
		session._open_day(session.day + 1)
		session.spawn_remaining = Data.ARRIVAL_MIN
	session.story_state.run["run.released"] = session.released_count
	session.story_state.run["run.rejected"] = session.rejected_count
	var ro: Array = data.get("rods_owned", [true, false])
	for i in qte.rods_owned.size():
		qte.rods_owned[i] = bool(ro[i]) if i < ro.size() else i == 0
	var ho: Array = data.get("hooks_owned", [true, false, false])
	for i in qte.hooks_owned.size():
		qte.hooks_owned[i] = bool(ho[i]) if i < ho.size() else i == 0
	_restore_grip(data)
	qte.charms_owned = clampi(int(data.get("charms_owned", 0)), 0, Data.CHARM_LIMIT)
	var stock: Array = data.get("bait_stock", [])
	var equipped_bait := int(data.get("bait", 0))
	if from_v15 and stock.size() == 8:
		# The three retired size baits occupy the old attribute-bait slots.
		for index in range(4, 7):
			stock[0] = int(stock[0]) + int(stock[index])
			stock[index] = 0
		if equipped_bait in [4, 5, 6]:
			equipped_bait = Data.Bait.DEFAULT
	qte.restore_bait_inventory(stock, equipped_bait)
	qte.variant_craft_unlocked = bool(data.get("variant_craft_unlocked", legacy_alchemy and qte.bait_stock[Data.VARIANT_BAIT] > 0))
	qte.rod = clampi(int(data.get("rod", 0)), 0, qte.rods_owned.size() - 1)
	qte.hook = clampi(int(data.get("hook", 0)), 0, qte.hooks_owned.size() - 1)
	var saved_fishing: Dictionary = data.get("fishing", {})
	if from_v15 and saved_fishing.get("snapshot") is Dictionary:
		saved_fishing.snapshot.bait = qte.bait
	if not from_v15 and stock.size() != Data.BAITS.size() and saved_fishing.get("snapshot") is Dictionary:
		var mapping: Array = Data.LEGACY_BAIT_MAPS.get(stock.size(), [])
		if not mapping.is_empty():
			var old_bait := int(saved_fishing.snapshot.get("bait", 0))
			saved_fishing.snapshot.bait = mapping[clampi(old_bait, 0, mapping.size() - 1)]
	qte.clear_tutorial_catch()
	qte.restore_pending(saved_fishing)
	session.restore_rules(data.get("alchemy_rules", {}), legacy_alchemy)
	_restore_tutorial(data.get("tutorial", {}), saved_fishing)
	river.casting = bool(data.get("casting", false)) and not qte.is_busy()
	river.cast_elapsed = float(data.get("cast_elapsed", 0.0))
	river.tension = Vector2.ZERO
	river.hit_timer = 0.0
	river.pulse = 0.0
	var loc := str(data.get("location", "River"))
	current_location = loc if loc in LOCATION_ORDER else "River"
	started = true
	session.active = true
	_show_location(current_location)
	session.state_changed.emit()
	qte.state_changed.emit()
	return true


func _restore_grip(data: Dictionary) -> void:
	var remaining := Data.GRIP_CAPACITY - int(data.get("shared_wear", 0))
	var saved: Variant = data.get("grip_durability", remaining)
	qte.quick_repair_available = bool(data.get("quick_repair_available", true))
	if saved is Array:
		if saved.is_empty():
			saved = Data.GRIP_CAPACITY
		else:
			var equipped := clampi(int(data.get("grip", 0)), 0, saved.size() - 1)
			session.coins += (saved.size() - 1) * LEGACY_DUPLICATE_GRIP_PRICE
			saved = saved[equipped]
	qte.grip_durability = clampi(int(saved), 0, Data.GRIP_CAPACITY)


func _cycle_location(step: int) -> void:
	if step < 0 and qte.phase == Fishing.Phase.AWAITING_RETURN:
		_show_location("River", true)
		return
	var index := posmod(LOCATION_ORDER.find(current_location) + step, LOCATION_ORDER.size())
	_show_location(LOCATION_ORDER[index], true)


func _show_location(value: String, from_input: bool = false) -> void:
	if not started or session.paused or value not in LOCATION_ORDER:
		return
	if judgment_panel != null and judgment_panel.is_active():
		return
	if from_input and current_location != value:
		_audio.play(Audio.Cue.MARKET_OPEN if value == "Market" else Audio.Cue.PAGE_TURN)
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
	_summary.visible = not session.paused
	_previous_location_button.disabled = session.paused
	_next_location_button.disabled = session.paused
	_river_button.disabled = session.paused or current_location == "River"
	_shop_button.disabled = session.paused or current_location == "Shop"
	_alchemy_button.disabled = session.paused or current_location == "Alchemy"
	_market_button.disabled = session.paused or current_location == "Market"
	UI.set_tab_active(_river_button, current_location == "River")
	UI.set_tab_active(_shop_button, current_location == "Shop")
	UI.set_tab_active(_alchemy_button, current_location == "Alchemy")
	UI.set_tab_active(_market_button, current_location == "Market")
	_pause_button.icon = RESUME_ICON if session.paused else PAUSE_ICON
	_pause_button.focus_mode = Control.FOCUS_ALL if session.paused else Control.FOCUS_NONE
	_pause_button.accessibility_name = "继续游戏" if session.paused else "暂停游戏"
	_pause_button.tooltip_text = "%s（Esc）" % _pause_button.accessibility_name
	_pause_button.add_theme_color_override("icon_normal_color", UI.MINT if session.paused else UI.CREAM)
	_refresh_river_notice()
	_update_scene_audio(0.0)


func _cast_line() -> void:
	if started and current_location == "River" and _rig_slot_cursor < 0 and not session.is_time_suspended():
		if river.start_cast():
			_audio.play(Audio.Cue.CAST)
		_refresh_river()
		_refresh_tutorial()


func _retract() -> void:
	if river.casting:
		river.cancel_cast()
	else:
		qte.retract()
	_refresh_river()
	_refresh_tutorial()


func _toggle_rig_popup(slot: int) -> void:
	if river.casting or qte.is_busy() or session.paused:
		return
	if _rig_open_slot == slot:
		_close_rig_popup(true)
		return
	_open_rig_popup(slot)


func _open_rig_popup(slot: int) -> void:
	_audio.play(Audio.Cue.RIG_SELECT)
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
	var titles := ["更换竿体", "更换鱼钩", "握柄状态", "选择鱼饵"]
	_rig_popup_icon.texture = UI.RIG_ICONS[slot]
	_rig_popup_title.text = titles[slot]
	_populate_rig_popup(slot)
	_rig_option_cursor = [qte.rod, qte.hook, 0, qte.bait][slot]
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
				_equip_rig(i, qte.hook, qte.bait)
			)
	elif slot == 1:
		for i in Data.HOOKS.size():
			var owned: bool = qte.hooks_owned[i]
			_add_rig_option(UI.ICON_HOOK, Data.HOOKS[i], Data.HOOK_DESCS[i], "已装备" if qte.hook == i else ("未拥有" if not owned else "可装配"), qte.hook == i, not owned, Vector2(342, 68), func() -> void:
				_equip_rig(qte.rod, i, qte.bait)
			)
	elif slot == 2:
		var status := "耐久 %d / %d · 归零后可到市场维修" % [qte.durability(), Data.GRIP_CAPACITY]
		_add_rig_option(UI.ICON_GRIP, "基础握柄", status, "已装备", true, false, Vector2(342, 68), _close_rig_popup)
	elif slot == 3:
		for i in Data.BAITS.size():
			var count: int = qte.bait_stock[i]
			_add_rig_option(UI.ICON_BAIT, Data.BAITS[i], Data.bait_hint(i), "×%d" % count, qte.bait == i, false, Vector2(228, 74), func() -> void:
				_equip_rig(qte.rod, qte.hook, i)
			)


func _equip_rig(rod_index: int, hook_index: int, bait_index: int) -> void:
	if qte.set_rig(rod_index, hook_index, bait_index):
		_audio.play(Audio.Cue.RIG_EQUIP)
	_close_rig_popup()


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
	_audio.play(Audio.Cue.RIG_SELECT)
	_refresh_river()


func _rig_key(code: Key) -> bool:
	match code:
		KEY_C:
			_close_rig_popup(_rig_open_slot >= 0)
		KEY_W, KEY_A, KEY_S, KEY_D:
			if _rig_open_slot >= 0 and _rig_popup_grid.columns > 1:
				_move_rig_grid_cursor(code)
			elif code in [KEY_W, KEY_S]:
				var step := 1 if code == KEY_S else -1
				if _rig_open_slot >= 0:
					var option := UI.next_button(_rig_option_buttons, _rig_option_cursor, step)
					if option != _rig_option_cursor:
						_audio.play(Audio.Cue.RIG_SELECT)
					_rig_option_cursor = option
					_highlight_rig_option()
				else:
					var slot := UI.next_button(_rig, _rig_slot_cursor, step)
					if slot != _rig_slot_cursor:
						_audio.play(Audio.Cue.RIG_SELECT)
					_rig_slot_cursor = slot
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
		_audio.play(Audio.Cue.RIG_SELECT)
		_rig_option_cursor = index
		_highlight_rig_option()


func _set_paused(value: bool, open_codex: bool = false) -> void:
	if not started or session.paused == value:
		return
	session.paused = value
	_paused_from_codex = value and open_codex
	if value:
		_close_rig_popup()
		_pause_buttons[0].disabled = not persist_save
		_pause_buttons[1].disabled = not has_save()
	else:
		_save_menu.dismiss()
		_close_settings()
	_clear_pull_input()
	_update_activation()
	_refresh_shared()
	_refresh_river()
	_set_codex_open(value and open_codex)
	_animate_pause_bar()


func _animate_pause_bar() -> void:
	if _pause_button_animation:
		_pause_button_animation.kill()
	if _pause_bar_animation:
		_pause_bar_animation.kill()
	_pause_button.scale = Vector2.ONE
	_pause_button_animation = create_tween().set_trans(Tween.TRANS_QUAD)
	_pause_button_animation.tween_property(_pause_button, "scale", Vector2.ONE * 0.90, 0.05).set_ease(Tween.EASE_IN)
	_pause_button_animation.tween_property(_pause_button, "scale", Vector2.ONE, 0.09).set_ease(Tween.EASE_OUT)
	_summary.modulate.a = 1.0
	_pause_banner.modulate.a = 1.0
	var incoming: Control = _pause_banner if session.paused else _summary
	incoming.modulate.a = 0.0
	_pause_bar_animation = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pause_bar_animation.tween_property(incoming, "modulate:a", 1.0, 0.12)


func _can_open_codex() -> bool:
	return started and not day_report.visible and not _save_menu.is_open and not story_panel.is_typing() and qte.phase != Fishing.Phase.TRUE_NAME


func _set_codex_open(expanded: bool) -> void:
	if expanded:
		_refresh_codex_guest()
	_codex.present(session.paused, expanded)
	if session.paused and not expanded:
		_pause_button.grab_focus()


func _refresh_codex_guest() -> void:
	var guest := session.get_soul(shop.selected_id) if current_location == "Shop" else {}
	_codex.set_guest(guest, session.requirements)


func _toggle_codex_bookmark() -> void:
	if session.paused and (_codex.is_open or _can_open_codex()):
		_set_codex_open(not _codex.is_open)


func _codex_tab() -> void:
	if not _can_open_codex():
		return
	if not session.paused:
		_set_paused(true, true)
	elif _codex.is_open and _paused_from_codex:
		_set_paused(false)
	else:
		_set_codex_open(not _codex.is_open)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and auto_pause_on_focus_loss and started:
		_set_paused(true)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	# Reserve modal shortcuts before Godot routes confirmation or Tab to a focused button.
	if key.pressed and (_settings_modal.is_open or _start_mode_modal.is_open):
		get_viewport().set_input_as_handled()
		if not key.echo:
			_handle_game_key(code)
	elif code == KEY_TAB:
		get_viewport().set_input_as_handled()
		if key.pressed and not key.echo:
			_codex_tab()
	elif started and session.paused and key.pressed:
		# While paused, the active menu owns keyboard confirmation instead of the focused Button.
		get_viewport().set_input_as_handled()
		if not key.echo:
			_handle_game_key(code)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if not key.pressed:
		if _held_keys.erase(code) and started and current_location == "River":
			var direction := Fishing.DIRECTION_KEYS.find(code)
			if direction < 0:
				direction = Fishing.ARROW_KEYS.find(code)
			if direction >= 0 and not _is_direction_held(direction):
				qte.release_direction(direction)
		if _held_keys.is_empty():
			_requires_release = false
		return
	if key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if _handle_game_key(code):
		get_viewport().set_input_as_handled()


func _handle_game_key(code: Key) -> bool:
	if _settings_modal.is_open:
		_settings_modal.handle_key(code)
		return true
	if _start_mode_modal.is_open:
		_start_mode_modal.handle_key(code)
		return true
	if _save_menu.is_open:
		if code == KEY_ESCAPE and _codex.is_open:
			_audio.play(Audio.Cue.UI_CLICK)
			_save_menu.dismiss()
		else:
			_save_menu.handle_key(code)
		return true
	if _ending_screen != null and _ending_screen.is_active():
		if story_lab and code == KEY_N:
			_reset_story_lab()
		elif code in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_ending_screen.advance()
		return true
	if started and not session.paused and current_location == "Shop" and story_panel != null and story_panel.is_typing():
		if code >= KEY_A and code <= KEY_Z:
			story_panel.submit_letter(OS.get_keycode_string(code))
		elif code == KEY_ESCAPE:
			story_panel.cancel_callout()
		return true
	if day_report != null and day_report.visible:
		if story_lab and code == KEY_N:
			_reset_story_lab()
		elif code in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_close_day_report()
		return true
	if not started:
		return _title_key(code)
	if session.paused:
		return _pause_key(code)
	if story_lab and code == KEY_N:
		_reset_story_lab()
		return true
	if code == KEY_ESCAPE:
		_set_paused(true)
		return true
	if tutorial_active and _tutorial_overlay.handle_key(code):
		return true
	if _rig_slot_cursor >= 0:
		return _rig_key(code)
	if code in [KEY_Q, KEY_E]:
		_cycle_location(-1 if code == KEY_Q else 1)
		return true
	var handled := false
	match current_location:
		"River": handled = _river_key(code)
		"Shop": handled = _reception_key(code)
		"Alchemy": handled = alchemy.handle_key(code)
		"Market": handled = market.handle_key(code)
	if not handled and code == KEY_C and current_location != "River":
		_show_location("River", true)
		return true
	return handled


func _title_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_UP, KEY_S, KEY_DOWN:
			var step := 1 if code in [KEY_S, KEY_DOWN] else -1
			_select_title_button(UI.next_button(_menu_buttons, _menu.cursor, step))
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			UI.activate(_menu_buttons[_menu.cursor])
		_:
			return false
	return true


func _pause_key(code: Key) -> bool:
	match code:
		KEY_ESCAPE, KEY_C:
			_set_paused(false)
			return true
		KEY_F:
			UI.activate(_pause_buttons[0])
			return true
		KEY_R:
			UI.activate(_pause_buttons[1])
			return true
		KEY_T:
			UI.activate(_pause_buttons[2])
			return true
		KEY_G:
			UI.activate(_pause_buttons[3])
			return true
	if _codex.is_open:
		return _codex.handle_key(code)
	return false


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
	var story = _selected_story_runtime()
	if story != null and story.has_pending_steps() and code == KEY_F:
		_story_advance()
		return true
	match code:
		KEY_W, KEY_S:
			_move_dose(1 if code == KEY_S else -1)
		KEY_A, KEY_D:
			_switch_guest(1 if code == KEY_D else -1)
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


func _switch_guest(direction: int) -> void:
	for i in session.souls.size():
		if session.souls[i].id == shop.selected_id:
			var index := posmod(i + direction, session.souls.size())
			shop.select_guest(session.souls[index].id)
			UI.reveal(_queue_box.get_parent() as ScrollContainer, _queue_buttons[index])
			return


func _queue_pull(code: int, direction: int) -> void:
	_held_keys[code] = true
	if (river.casting or session.is_time_suspended() or not qte.is_line_action()
			or (qte.phase == Fishing.Phase.REELING and _requires_release)):
		_requires_release = true
		return
	_audio.play(Audio.Cue.REEL)
	if _pending_directions.is_empty():
		_submit_pending_pull.call_deferred()
	if direction not in _pending_directions:
		_pending_directions.append(direction)


func _submit_pending_pull() -> void:
	if _pending_directions.is_empty():
		return
	var direction := _pending_directions[0] if _pending_directions.size() == 1 else -1
	_pending_directions.clear()
	_requires_release = not _held_keys.is_empty()
	qte.submit_direction(direction)
	# A tap released before deferred input is delivered cannot silently hold a long note.
	if direction >= 0 and not _is_direction_held(direction):
		qte.release_direction(direction)


func _is_direction_held(direction: int) -> bool:
	return _held_keys.has(Fishing.DIRECTION_KEYS[direction]) or _held_keys.has(Fishing.ARROW_KEYS[direction])


func _clear_pull_input() -> void:
	if qte != null:
		qte.suspend_pull()
	_pending_directions.clear()
	_held_keys.clear()
	_requires_release = false


func _refresh_summary() -> void:
	if story_lab:
		_summary.text = "剧情测试　第 %d 天　等候 %d　渡魂币 %d　N 重置全部" % [session.day, session.souls.size(), session.coins]
		return
	_summary.text = "第 %d 天　原液 %d　等候 %d　放行 %d / %d　渡魂币 %d" % [session.day, session.essences.reduce(func(total: int, count: int) -> int: return total + count, 0), session.souls.size(), session.released_count, session.total_guests(), session.coins]


func _show_bone_notice() -> void:
	_bone_notice_remaining = BONE_NOTICE_DURATION
	_refresh_river_notice()


func _refresh_river_notice() -> void:
	var fish_hooked := started and current_location != "River" and qte.phase == Fishing.Phase.AWAITING_RETURN
	_river_bite_alert.visible = fish_hooked
	_river_button.accessibility_name = "有鱼上钩了，返回河岸" if fish_hooked else ""
	_previous_location_button.tooltip_text = "返回河岸（Q）" if fish_hooked else "上一个地点（Q）"
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

	var report: Dictionary = session.get_day_report()
	var report_visible := not report.is_empty()
	if day_report != null:
		day_report.visible = report_visible
		if report_visible:
			day_report.render(report)

	var selected := session.get_soul(shop.selected_id)
	if _codex.is_open:
		_refresh_codex_guest()
	var story = _selected_story_runtime()
	if story == null or current_location != "Shop" or session.paused:
		story_panel.cancel_callout()
	if shop.selected_id != _story_last_soul_id:
		_story_last_soul_id = shop.selected_id
		_story_cue_key = ""
		_story_last_text = ""
		if story_director != null:
			story_director.cancel()
		if story_stage != null:
			story_stage.reset()
	var typing := story_panel.is_typing()
	var judging := judgment_panel != null and judgment_panel.is_active()
	if session.paused:
		if judging:
			judgment_panel.close()
		judging = false
	elif story != null and story.is_awaiting_judgment() and not judging and judgment_panel != null:
		judgment_panel.open(story, session.coins)
		judging = judgment_panel.is_active()
	elif story == null or not story.is_awaiting_judgment():
		if judgment_panel != null and judgment_panel.is_active():
			judgment_panel.close()
		judging = false
	session.set_story_open(typing or judging)
	_dialog_hint.visible = story != null and story.has_pending_steps() and not session.paused and not typing and not judging
	var revealed: bool = story != null and story.is_identity_revealed()
	var linear := story != null and bool(story.case_data.get("linear", false))
	var hearing_done := linear and bool(story.flags.get("judgment.done", false))
	_story_action_button.visible = story != null and not story.is_closed() and (not linear or not revealed) and not hearing_done and not judging
	_story_action_button.disabled = session.paused or judging
	_release_button.size.x = 196 if _story_action_button.visible else 404
	var speaker_name := ""
	var speaker_gold := false
	if story != null:
		if not story.changed.is_connected(_refresh_shared):
			story.changed.connect(_refresh_shared)
		var portrait: String = story.get_portrait_id()
		if portrait.is_empty():
			shop.clear_story_sprite()
		elif not shop.has_story_sprite() or story.is_awaiting_choice() or story.is_closed():
			shop.set_story_sprite(portrait)
		var step: Dictionary = story.current_step()
		speaker_name = str(step.get("speaker_name", ""))
		var line := str(step.get("text", ""))
		if line == "":
			_dialog.text = _story_last_text if _story_last_text != "" else story.get_greeting()
			if speaker_name == "" and not selected.is_empty():
				speaker_name = str(selected.get("name", ""))
		else:
			_dialog.text = line
			_story_last_text = _dialog.text
		speaker_gold = revealed and speaker_name != ""
		_dialog.mouse_filter = Control.MOUSE_FILTER_STOP if story.has_pending_steps() and not judging else Control.MOUSE_FILTER_IGNORE
		if judging:
			_guest_state.text = "将渡魂币放上天平"
		elif story.is_awaiting_choice():
			_guest_state.text = "按 Shift 继续" if linear else "点击可疑处调查"
		elif story.has_pending_steps():
			_guest_state.text = "F / 点击对话继续"
		elif revealed:
			_guest_state.text = "真名已解放"
		else:
			_guest_state.text = "特殊来客"
		_guest_state.add_theme_color_override("font_color", UI.GOOD if revealed else UI.GOLD)
		_service_fee.text = "称心结束后进入结局" if linear else "结果记入账本"
		if story.is_closed():
			_release_button.text = "Shift  结束接待"
		elif linear:
			_release_button.text = "Shift  继续"
		else:
			_release_button.text = "Shift  放行"
		_release_button.disabled = session.paused or typing or judging
		_story_action_button.text = "取消（Esc）" if typing else ("拒绝入境" if revealed and not linear else story.get_callout_button_text())
	else:
		shop.clear_story_sprite()
		_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ready := session.can_release(shop.selected_id)
		_guest_state.text = "达到要求 · 可以放行" if ready else ("窗口空闲" if selected.is_empty() else "等待调配药剂")
		_guest_state.add_theme_color_override("font_color", UI.GOOD if ready else UI.GOLD)
		_release_button.disabled = session.paused or not ready
		_release_button.text = "Shift  放行"

		_service_fee.text = ""
		if not selected.is_empty():
			_service_fee.text = "基础服务费 %d 枚" % selected.fee
			var bonus := session.service_bonus(selected)
			if session.first_service(selected):
				_service_fee.text += "　首次 +%d 枚" % bonus
			if session.has_commission(selected):
				_service_fee.text += "\n个人委托：意志达到 %d　+%d 枚" % [Session.BOATMAN_COMMISSION_WILL, bonus]
			var dose_count := Session.doses_used(selected)
			if ready and dose_count > 1:
				_service_fee.text = "已用 %d 剂　放行奖金 %d 枚" % [dose_count, session.release_reward(selected, selected.stats, dose_count)]
			elif dose_count > 0 and not ready:
				_service_fee.text += "\n已用 %d 剂　再次用药奖金减半" % dose_count

	if not shop.departure_times.is_empty():
		if session.last_story_outcome == "judged":
			_payout_notice.text = "称心结束　天平归位"
		else:
			_payout_notice.text = "未放行　账本已记" if session.last_story_outcome in ["reject", "leave"] else "放行成功　渡魂币 +%d" % session.last_payout
	else:
		_payout_notice.text = ""
	if session.is_complete() and not session.awaiting_day_report:
		_show_ending()
	elif session.is_complete():
		var ending_lines := session.get_ending_lines()
		_dialog.text = "\n".join(ending_lines) if not ending_lines.is_empty() else "五天的灵魂都已放行。"
		speaker_name = ""
		speaker_gold = false
	elif story == null:
		if selected.is_empty():
			_dialog.text = "还没有来客，可以先去冥河备料。"
			speaker_name = ""
		elif selected.served:
			_dialog.text = "饮药后感觉变化明显：\n%s" % Data.effect_text(selected.stats - selected.before)
			speaker_name = str(selected.get("name", ""))
		else:
			_dialog.text = "请帮我补全灵魂，让我能通过冥府之门。"
			speaker_name = str(selected.get("name", ""))

	if speaker_name != "":
		_dialog_speaker.text = speaker_name
		_dialog_speaker.add_theme_color_override("font_color", UI.GOLD if speaker_gold else Color("eef2f8"))
		_dialog_speaker.show()
		_dialog.position = Vector2(516, 146)
		_dialog.size = Vector2(530, 50)
		_dialog.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		_dialog_speaker.text = ""
		_dialog_speaker.hide()
		_dialog.position = Vector2(516, 128)
		_dialog.size = Vector2(530, 68)
		_dialog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_sync_story_cues(story if current_location == "Shop" and not session.paused else null)
	if story_hotspots != null:
		story_hotspots.refresh(story if current_location == "Shop" and not session.paused and not session.awaiting_day_report and not judging else null)
	_refresh_dose()
	alchemy.refresh()
	_refresh_tutorial()


func _rebuild_queue() -> void:
	UI.clear_cards(_queue_box)
	_queue_buttons.clear()
	_queue_empty.visible = session.souls.is_empty()
	for soul in session.souls:
		var sid: int = int(soul["id"])
		var is_sel := sid == shop.selected_id
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(224, 30)
		btn.disabled = session.paused or story_panel.is_typing()
		UI.style_slot_button(btn, is_sel, false)
		btn.pressed.connect(func() -> void: shop.select_guest(sid))
		_queue_box.add_child(btn)
		_queue_buttons.append(btn)
		var eligible := not soul.has("story_case") and session.can_release(sid)
		var dot_col := UI.GOOD if eligible else UI.GOLD
		var queue_name := str(soul.get("story_lab_label", soul.name)) if story_lab else str(soul.name)
		var lbl := UI.label(btn, ("● " if eligible else "") + queue_name, Rect2(10, 2, 204, 26), 15, dot_col if is_sel else UI.CREAM)
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
		_audio.play(Audio.Cue.ESSENCE_SELECT if key[0] else Audio.Cue.MEDICINE_SELECT)
	_rebuild_dose_list()
	_refresh_dose()
	_refresh_tutorial()


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
	var story = _selected_story_runtime()
	if story != null:
		soul_hud.set_state(selected, {}, session.day, session.requirements)
		if judgment_panel != null and judgment_panel.is_active():
			_serve_button.disabled = true
			_dose_preview.text = "正在称量……"
			_dose_preview.add_theme_color_override("font_color", UI.MUTED)
			return
		if story_panel.is_typing():
			_serve_button.disabled = true
			_dose_preview.text = "正在输入真名……"
			_dose_preview.add_theme_color_override("font_color", UI.MUTED)
			return
		if story.can_feed_potion():
			_serve_button.disabled = session.paused or _selected_dose == null
			_dose_preview.text = "按 W / S 选择药剂，再按空格给药" if _selected_dose == null else "按空格端上所选药剂"
			_dose_preview.add_theme_color_override("font_color", UI.GOLD)
		elif story.has_fed_potion():
			_serve_button.disabled = true
			_dose_preview.text = "他喝过了：%s　%s %+d" % [story.get_dose_label(), story.get_score_name(), story.get_dose_score()]
			_dose_preview.add_theme_color_override("font_color", UI.MINT)
		else:
			_serve_button.disabled = true
			_dose_preview.text = "审查结束"
			_dose_preview.add_theme_color_override("font_color", UI.MUTED)
		return

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
		_dose_preview.text = "预览饮后：%d / %d / %d　%s" % [after.x, after.y, after.z, "放行 %d 枚" % int(preview.reward) if ok else "仍需继续调整"]
		_dose_preview.add_theme_color_override("font_color", UI.GOOD if ok else UI.GOLD)


func _serve_dose() -> void:
	if _serve_button.disabled or _selected_dose == null:
		return
	var chosen: Array = _selected_dose
	_selected_dose = null
	var story = _selected_story_runtime()
	if story != null:
		session.feed_story_potion(shop.selected_id, chosen[0], chosen[1])
	else:
		session.serve(shop.selected_id, chosen[0], chosen[1])


func _selected_story_runtime():
	var soul := session.get_soul(shop.selected_id)
	if soul.is_empty() or not soul.has("story_case"):
		return null
	return session.get_story_runtime(shop.selected_id)


func _release_guest() -> void:
	if session.paused or story_panel.is_typing() or judgment_panel.is_active():
		return
	var story = _selected_story_runtime()
	if story == null:
		if shop.begin_departure() and session.last_payout > 0:
			_audio.play(Audio.Cue.COINS)
		return
	story.skip_dialogue()
	if story.is_closed() or story.choose("admit"):
		if shop.begin_story_departure() and session.last_payout > 0:
			_audio.play(Audio.Cue.COINS)


func _story_action() -> void:
	if session.paused or judgment_panel.is_active():
		return
	if story_panel.is_typing():
		story_panel.cancel_callout()
		return
	var story = _selected_story_runtime()
	if story == null or story.is_closed():
		return
	story.skip_dialogue()
	if story.is_identity_revealed():
		if story.choose("refuse"):
			shop.begin_story_departure()
	else:
		story_panel.start_callout(story)


func _on_judgment_submitted(amount: int) -> void:
	var story = _selected_story_runtime()
	if story == null or not story.judgment_active:
		return
	story.resolve_judgment(amount)
	_refresh_shared()


func _on_story_hotspot(choice_id: String) -> void:
	if session.paused or story_panel.is_typing():
		return
	var story = _selected_story_runtime()
	if story == null or not story.is_awaiting_choice():
		return
	if story.choose(choice_id):
		_refresh_shared()


func _story_advance() -> void:
	if session.paused or story_panel.is_typing() or judgment_panel.is_active():
		return
	var story = _selected_story_runtime()
	if story == null or story.is_closed() or not story.has_pending_steps():
		return
	if story_director != null and story_director.blocks_advance():
		story_director.skip()
		return
	story.advance()
	_refresh_shared()


func _on_dialog_input(event: InputEvent) -> void:
	if judgment_panel != null and judgment_panel.is_active():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_story_advance()
		_dialog.accept_event()


func _sync_story_cues(story) -> void:
	if story_director == null:
		return
	if story == null or not story.has_pending_steps():
		_story_cue_key = ""
		story_director.cancel()
		story_stage.finish_inspection()
		return
	var step: Dictionary = story.current_step()
	var identity := "%s|%d|%s" % [story.get_node_id(), story.step_index, str(step.get("key", ""))]
	if identity == _story_cue_key:
		return
	if _story_cue_key.get_slice("|", 0) != story.get_node_id():
		story_director.cancel()
		story_stage.finish_inspection()
	_story_cue_key = identity
	if step.is_empty():
		story_director.cancel()
		return
	story_director.play(str(step.get("key", "")), step.get("cues", []), story.get_context())


func _on_story_view_changed() -> void:
	if story_hotspots != null and story_hotspots.visible and current_location == "Shop" and not session.paused:
		story_hotspots.refresh(_selected_story_runtime())


func _show_ending() -> void:
	if _ending_screen == null or _ending_screen.is_active():
		return
	var lines := session.get_ending_lines()
	if lines.is_empty():
		return
	_hud.visible = false
	_shop_ui.visible = false
	shop.clear_departures()
	shop.selected_id = -1
	if story_director != null:
		story_director.cancel()
	if story_stage != null:
		story_stage.reset()
	_ending_screen.show_ending(lines, str(session.story_state.world.get("world.anubis_result", "")) != "", story_lab)


func _close_day_report() -> void:
	if session.awaiting_day_report:
		_audio.play(Audio.Cue.UI_CLICK)
		session.close_day_report()
		if story_lab and not session.is_complete():
			StoryLab.prepare_day(session)
			shop.clear_departures()
			_story_lab_select_guest()
			session.state_changed.emit()
		_refresh_shared()


func _refresh_rig_slots() -> void:
	var busy := river.casting or qte.is_busy()
	var values := [
		Data.RODS[qte.rod],
		Data.HOOKS[qte.hook],
		"基础握柄",
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

	_beat_panel.visible = qte.phase in [Fishing.Phase.REELING, Fishing.Phase.HOLDING, Fishing.Phase.RELEASE_WAIT, Fishing.Phase.FEEDBACK, Fishing.Phase.TRUE_NAME] and not river.casting
	_beat_info.visible = _beat_panel.visible
	_beat_info.text = "进度 %d / %d　失误 %d / %d　剩余 %.1f 秒" % [qte.progress, qte.target, qte.mistakes, Data.MISTAKE_LIMIT, qte.get_capture_time()]
	if qte.has_tutorial_catch():
		_beat_info.text = "引导练习　%d / %d　失误可重试" % [qte.progress, qte.target]
	if qte.phase == Fishing.Phase.TRUE_NAME:
		_beat_info.text = "%s　　%.1f 秒" % [qte.true_name_hint(), qte.remaining]
	_hit.text = ""
	if river.hit_timer > 0.0 and not river.casting and qte.phase in [Fishing.Phase.REELING, Fishing.Phase.HOLDING, Fishing.Phase.RELEASE_WAIT, Fishing.Phase.FEEDBACK, Fishing.Phase.CAUGHT, Fishing.Phase.ESCAPED]:
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
			_river_hint.text = "空格抛竿，捕获后原液自动入库。"
		Fishing.Phase.WAITING:
			_river_status.text = "候鱼中…"
			_river_hint.text = "按 X 收竿。离开河岸后看到上钩气泡，请在 3 秒内按 Q 返回。"
		Fishing.Phase.PREPARING, Fishing.Phase.REELING, Fishing.Phase.HOLDING, Fishing.Phase.RELEASE_WAIT, Fishing.Phase.FEEDBACK:
			_river_status.text = "四向绷线 · " + ["点拉", "持续绷线", "绷住后松线"][qte.round_action]
			_river_hint.text = qte.get_action_prompt()
			if qte.phase == Fishing.Phase.PREPARING:
				_river_status.text = "有鱼上钩了！"
				_river_hint.text = "读方向后逆向拉鱼：点拉 / 按住绷线 / 金环亮时松手。"
			elif qte.phase == Fishing.Phase.FEEDBACK:
				var next := "重练本拍" if qte.has_tutorial_catch() and not qte.last_success else "准备下一轮"
				_river_hint.text = "%s · 进度 %d / %d，松开按键%s。" % [qte.last_message, qte.progress, qte.target, next]
		Fishing.Phase.TRUE_NAME:
			_river_status.text = "神秘鱼影 · 真名捕获"
			_river_hint.text = "依次输入出现的字母，输错后从头开始。"
		Fishing.Phase.CAUGHT:
			_river_status.text = qte.last_message
			_river_hint.text = "空格抛竿，继续钓鱼。" if qte.locked.has("bone") else "原液已入库，可去炼药台制药，或再抛一竿。"
		Fishing.Phase.ESCAPED:
			_river_status.text = qte.last_message
			_river_hint.text = "可以再次抛竿。"
	if not busy and not qte.can_cast() and not session.paused:
		if qte.durability() == 0 and qte.bait_stock[qte.bait] == 0:
			_river_hint.text = "握柄耐久与当前鱼饵均已耗尽，按 Q 去市场维修并补充鱼饵。"
		elif qte.durability() == 0:
			_river_hint.text = "当前握柄耐久已耗尽，按 Q 去市场维修，或按 Shift 更换备用握柄。"
		elif qte.has_any_bait():
			_river_hint.text = "当前「%s」已耗尽，按 Shift 换饵，或按 Q 去市场购买。" % Data.BAITS[qte.bait]
		else:
			_river_hint.text = "当前「%s」已耗尽，按 Q 去市场补充鱼饵。" % Data.BAITS[qte.bait]


func _update_scene_audio(delta: float) -> void:
	var suspended := session.is_time_suspended()
	_audio.sync_ferry(river.get_ferry_rect().has_area(), suspended)
	_audio.set_paused(Audio.Cue.FOOTSTEPS, session.paused or current_location != "Shop")
	if not river.active or suspended or qte.phase != Fishing.Phase.WAITING:
		_bobber_sound_in = BOBBER_WAIT_INTERVAL
		_audio.stop(Audio.Cue.BOBBER_WAIT)
		return
	_bobber_sound_in -= delta
	if _bobber_sound_in <= 0.0 and qte.remaining > 0.75:
		_audio.play(Audio.Cue.BOBBER_WAIT)
		_bobber_sound_in = BOBBER_WAIT_INTERVAL


func _process(delta: float) -> void:
	if not started:
		return
	if story_director != null:
		story_director.tick(delta)
	_update_scene_audio(delta)
	if _bone_notice_remaining > 0.0 and not session.paused:
		_bone_notice_remaining = maxf(_bone_notice_remaining - delta, 0.0)
		if _bone_notice_remaining == 0.0:
			_refresh_river_notice()
	_refresh_river()
	if story_lab:
		_arrival.text = "N / 点击：重置全部 NPC"
	elif session.tutorial_pause_arrivals:
		_arrival.text = "正在接待首单"
	else:
		_arrival.text = "本班来客已全部到达" if not session.has_more_arrivals() else "%.0f 秒后有新来客" % ceilf(session.spawn_remaining)
