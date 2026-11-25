extends "res://scripts/demo/pixel_modal.gd"

signal mode_selected(with_tutorial: bool)

const UI := preload("res://scripts/demo/demo_ui.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")
const SOUL_GLOW := Color("46f2e2")
const AMBER_GLOW := Color("ff9d3b")
const CARD_WIDTH := 616.0
const CARD_HEIGHT := 92.0

var panel: Panel
var buttons: Array[Button] = []
var close_button: Button
var _cursor := 0
var _pointer: Control
var _audio: Audio
var _cards: Array[Dictionary] = []
var _pulse := 0.0


func setup(stage_size: Vector2, audio: Audio) -> void:
	_audio = audio
	setup_modal(stage_size, true)
	var panel_size := Vector2(692, 412)
	panel = UI.panel(self, Rect2((stage_size - panel_size) * 0.5, panel_size), "popup")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var ornament := Control.new()
	ornament.size = panel_size
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.draw.connect(_draw_panel_ornament.bind(ornament))
	panel.add_child(ornament)

	var icon_badge := UI.panel(panel, Rect2(28, 22, 48, 48), "wood_inset")
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.icon_rect(icon_badge, UI.ICON_ROD, Rect2(8, 8, 32, 32))

	UI.label(panel, "开始值班", Rect2(88, 17, 360, 36), 28, UI.GOLD)
	UI.label(panel, "阿刻戎河 · 第 1 天接待窗口", Rect2(90, 51, 360, 22), 15, UI.MINT)

	close_button = UI.button(panel, "×", Rect2(panel_size.x - 68.0, 24, 42, 40), _cancel, false)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.accessibility_name = "关闭开始值班"

	_add_mode_card(
		0,
		Rect2(38, 108, CARD_WIDTH, CARD_HEIGHT),
		UI.ICON_POTION,
		"开启新手教程",
		"推荐 · 约 2 分钟",
		"在第 1 天首单中练习钓鱼、炼药和接待放行，可随时跳过。",
		true,
		true
	)
	_add_mode_card(
		1,
		Rect2(38, 214, CARD_WIDTH, CARD_HEIGHT),
		UI.ICON_SOUL,
		"直接开始！",
		"跳过引导",
		"直接进入冥河岸边，自由安排垂钓、炼药与灵魂接待。",
		false,
		false
	)

	var footer := UI.panel(panel, Rect2(38, 328, CARD_WIDTH, 50), "wood_inset")
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_x := 22.0
	hint_x += UI.key_hint(footer, ["W", "S"], "选择", Vector2(hint_x, 12)) + 28.0
	hint_x += UI.key_hint(footer, ["Space"], "确认", Vector2(hint_x, 12)) + 28.0
	UI.key_hint(footer, ["Esc", "C"], "返回", Vector2(hint_x, 12))

	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.draw.connect(_draw_pointer)
	panel.add_child(_pointer)

	_select(0)
	panel.hide()


func _add_mode_card(index: int, rect: Rect2, icon: Texture2D, title: String, badge_text: String, desc: String, recommended: bool, with_tutorial: bool) -> void:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.accessibility_name = title
	UI.style_slot_button(btn, false, false)
	btn.pressed.connect(_choose.bind(with_tutorial))
	btn.mouse_entered.connect(_select.bind(index))
	panel.add_child(btn)
	buttons.append(btn)

	var glow := Control.new()
	glow.size = rect.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(_draw_card_glow.bind(glow, index))
	btn.add_child(glow)

	var icon_frame := UI.panel(btn, Rect2(20, 18, 56, 56), "wood_inset")
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.icon_rect(icon_frame, icon, Rect2(10, 10, 36, 36))

	var title_lbl := UI.label(btn, title, Rect2(92, 14, 300, 34), 24, UI.CREAM)
	var desc_lbl := UI.label(btn, desc, Rect2(92, 50, 486, 28), 16, UI.MUTED)
	desc_lbl.clip_text = true

	var badge_w := 148.0 if recommended else 96.0
	var badge := UI.pixel_panel(
		btn,
		Rect2(rect.size.x - badge_w - 42.0, 16, badge_w, 28),
		Color("213a3d") if recommended else Color("242034"),
		Color("64b9a6") if recommended else Color("58506b"),
		Color("120f1c")
	)
	var badge_lbl := UI.label(badge, badge_text, Rect2(0, 0, badge_w, 25), 14, UI.MINT if recommended else UI.MUTED, false)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var chevron := UI.label(btn, "▶", Rect2(rect.size.x - 34.0, 30, 22, 32), 18, UI.GOLD)
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_cards.append({
		"glow": glow,
		"title": title_lbl,
		"desc": desc_lbl,
		"chevron": chevron,
	})


func open() -> void:
	_pulse = 0.0
	_select(0)
	present(panel)


func _process(delta: float) -> void:
	if is_open:
		_pulse += delta * 4.2
		_pointer.queue_redraw()


func handle_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_S, KEY_A, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			_select(1 - _cursor)
			_audio.play(Audio.Cue.UI_CLICK)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			UI.activate(buttons[_cursor])
		KEY_C, KEY_ESCAPE:
			_cancel()
		_:
			return false
	return true


func _select(index: int) -> void:
	_cursor = index
	for i in buttons.size():
		var active := i == _cursor
		UI.style_slot_button(buttons[i], active, false)
		var card: Dictionary = _cards[i]
		(card["title"] as Label).add_theme_color_override("font_color", UI.GOLD if active else UI.CREAM)
		(card["desc"] as Label).add_theme_color_override("font_color", UI.CREAM if active else UI.MUTED)
		(card["chevron"] as Label).visible = active
		(card["glow"] as Control).queue_redraw()
	var button := buttons[_cursor]
	_pointer.position = button.position + Vector2(-18, floorf(button.size.y * 0.5))
	_pointer.queue_redraw()


func _draw_panel_ornament(layer: Control) -> void:
	var w := layer.size.x
	var y := 86.0
	layer.draw_rect(Rect2(28, y, w - 56.0, 2), Color("5b483d", 0.9))
	layer.draw_rect(Rect2(28, y + 2, w - 56.0, 2), Color(SOUL_GLOW, 0.28))
	var cx := floorf(w * 0.5)
	layer.draw_rect(Rect2(cx - 56.0, y, 112.0, 2), Color(UI.GOLD, 0.72))
	layer.draw_rect(Rect2(cx - 1.0, y - 4.0, 4, 10), UI.GOLD)
	layer.draw_rect(Rect2(cx - 4.0, y - 1.0, 10, 4), UI.GOLD)
	layer.draw_rect(Rect2(cx, y, 2, 2), Color("fff8dc"))


func _draw_card_glow(layer: Control, index: int) -> void:
	if index != _cursor:
		return
	var h := layer.size.y
	var inset_x := 8.0
	var inset_y := 8.0
	var inner_h := h - 16.0
	for strip in 16:
		var fade := pow(1.0 - float(strip) / 16.0, 1.8)
		layer.draw_rect(Rect2(inset_x + strip * 22.0, inset_y, 22.0, inner_h), Color(AMBER_GLOW, 0.16 * fade))
	layer.draw_rect(Rect2(inset_x, inset_y + 2.0, 4.0, inner_h - 4.0), Color(SOUL_GLOW, 0.85))
	layer.draw_rect(Rect2(inset_x, inset_y + 2.0, 4.0, 14.0), UI.GOLD)


func _draw_pointer() -> void:
	var bob := roundf(sin(_pulse) * 2.0)
	_pointer.draw_rect(Rect2(bob - 1.0, -3.0, 12.0, 6.0), UI.INK)
	_pointer.draw_rect(Rect2(bob + 2.0, -6.0, 6.0, 12.0), UI.INK)
	_pointer.draw_rect(Rect2(bob, -2.0, 10.0, 4.0), UI.GOLD)
	_pointer.draw_rect(Rect2(bob + 3.0, -5.0, 4.0, 10.0), UI.GOLD)
	_pointer.draw_rect(Rect2(bob + 4.0, -1.0, 2.0, 2.0), Color("fff8dc"))


func _choose(with_tutorial: bool) -> void:
	if is_open:
		_audio.play(Audio.Cue.UI_CONFIRM)
		dismiss()
		mode_selected.emit(with_tutorial)


func _cancel() -> void:
	_audio.play(Audio.Cue.UI_CLICK)
	dismiss()


func _backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		_cancel()
