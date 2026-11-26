extends "res://scripts/demo/pixel_modal.gd"

const UI := preload("res://scripts/demo/demo_ui.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")

var panel: Panel
var active_tab := 0
var _tab_buttons: Array[Button] = []
var _basic: Control
var _controls: Control
var _pointer: Control
var _buttons: Array[Button] = []
var _confirm: Button
var _cursor := 0
var _fullscreen := false
var _auto_pause := true
var _audio: Audio


func setup(stage_size: Vector2, display_mode: Callable, auto_pause: Callable, audio: Audio) -> void:
	_audio = audio
	setup_modal(stage_size, true)
	var panel_size := Vector2(1064, 706)
	panel = UI.modal_panel(self, Rect2((stage_size - panel_size) * 0.5, panel_size))
	UI.icon_rect(panel, UI.ICON_WRENCH, Rect2(28, 20, 32, 32))
	UI.label(panel, "游戏设置", Rect2(70, 17, 300, 44), 27, UI.GOLD)
	UI.modal_button(panel, "×", Rect2(988, 18, 46, 38), _cancel)
	_tab_buttons.append(UI.tab_button(panel, "基础设置", Rect2(30, 71, 156, 44), _switch_tab.bind(0)))
	_tab_buttons.append(UI.tab_button(panel, "操作菜单", Rect2(194, 71, 156, 44), _switch_tab.bind(1)))
	UI.key_hint(panel, ["Q", "E"], "切换页签", Vector2(372, 80))

	_basic = Control.new()
	_basic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_basic)
	var display := UI.pixel_panel(_basic, Rect2(168, 216, 728, 90), Color("191728"), Color("47435a"), UI.INK)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus := UI.pixel_panel(_basic, Rect2(168, 320, 728, 90), Color("191728"), Color("47435a"), UI.INK)
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.label(_basic, "显示模式", Rect2(192, 238, 240, 46), 22)
	UI.label(_basic, "切出窗口自动暂停", Rect2(192, 342, 240, 46), 22)
	_buttons.assign([
		UI.modal_button(_basic, "窗口模式", Rect2(478, 238, 174, 46), display_mode.bind(false)),
		UI.modal_button(_basic, "全屏模式", Rect2(686, 238, 174, 46), display_mode.bind(true)),
		UI.modal_button(_basic, "开启", Rect2(478, 342, 174, 46), auto_pause.bind(true)),
		UI.modal_button(_basic, "关闭", Rect2(686, 342, 174, 46), auto_pause.bind(false)),
	])

	_controls = Control.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_controls)
	_build_controls()
	_confirm = UI.modal_button(panel, "确定", Rect2(412, 640, 240, 44), dismiss)
	_buttons.append(_confirm)
	_pointer = UI.modal_pointer(panel)
	for i in _buttons.size():
		_buttons[i].mouse_entered.connect(_select.bind(i))
		_buttons[i].pressed.connect(_audio.play.bind(Audio.Cue.UI_CONFIRM))
	_show_tab(0)
	panel.hide()


func _build_controls() -> void:
	_control_card("通用导航", Rect2(30, 130, 494, 122), [
		"Q / E   切换地点（河岸、接待、炼药、市场）",
		"C   取消／返回河岸     Tab   开关冥河图鉴",
		"Esc   暂停／继续",
	])
	_control_card("河岸钓鱼", Rect2(30, 260, 494, 201), [
		"Space  抛竿    X  收竿    Shift  更换钓组",
		"WASD / 方向键  朝鱼拉扯的反方向操作",
		"入水点到边界时点按，或按住等拖拽条耗尽。",
		"猛冲时，等金环亮起再松手。",
		"A–Z  输入深水巨刺的真名",
		"离岸上钩后，在 3 秒内按 Q 返回河岸。",
	])
	_control_card("灵魂接待", Rect2(30, 469, 494, 153), [
		"A / D   切换来客     W / S   选药并预览",
		"Space   端上药剂     C   取消药剂选择",
		"Shift   放行／结束接待",
		"特殊来客可点击按钮呼唤真名，用 A–Z 输入。",
	])
	_control_card("炼药台", Rect2(540, 130, 494, 174), [
		"Shift   切换页签（纯炼、强化）",
		"WASD   选卡片     Space   炼制／强化",
		"F   三份同种原液炼药     C   返回",
		"X   切换强化属性     V   切换增减 1 点",
	])
	_control_card("市场", Rect2(540, 312, 494, 135), [
		"W / S   选类别或商品     A / D   选数量",
		"Space   查看商品／确认购买或维修",
		"C   返回类别",
	])
	_control_card("暂停与图鉴", Rect2(540, 455, 494, 167), [
		"F   保存     R   读取     T   返回封面",
		"G   打开设置和操作菜单",
		"Esc / C   关闭当前菜单",
		"图鉴内 Q / E   换页     WASD / 方向键   选择",
		"成品页 Shift   切换筛选",
	])


func _control_card(title: String, rect: Rect2, lines: Array[String]) -> void:
	var card := UI.pixel_panel(_controls, rect, Color("191728"), Color("47435a"), UI.INK)
	UI.label(card, title, Rect2(16, 9, rect.size.x - 32, 26), 21, UI.MINT)
	for i in lines.size():
		UI.label(card, lines[i], Rect2(16, 37 + i * 24, rect.size.x - 32, 24), 19)


func open() -> void:
	_show_tab(0)
	present(panel)


func sync_options(fullscreen: bool, auto_pause: bool) -> void:
	_fullscreen = fullscreen
	_auto_pause = auto_pause
	_select(_cursor)


func handle_key(code: Key) -> bool:
	match code:
		KEY_Q, KEY_E, KEY_LEFT, KEY_RIGHT:
			_switch_tab(1 - active_tab)
		KEY_W, KEY_UP, KEY_A, KEY_S, KEY_DOWN, KEY_D:
			if active_tab == 0:
				var step := -1 if code in [KEY_W, KEY_UP, KEY_A] else 1
				_select(UI.next_button(_buttons, _cursor, step))
				_audio.play(Audio.Cue.UI_CLICK)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			UI.activate(_buttons[_cursor])
		KEY_C, KEY_ESCAPE:
			_cancel()
		_:
			return false
	return true


func _switch_tab(index: int) -> void:
	if index != active_tab:
		_show_tab(index)
		_audio.play(Audio.Cue.UI_CLICK)


func _show_tab(index: int) -> void:
	active_tab = index
	_basic.visible = index == 0
	_controls.visible = index == 1
	for i in _tab_buttons.size():
		UI.set_tab_active(_tab_buttons[i], i == index)
	_select(0 if index == 0 else _buttons.size() - 1)


func _cancel() -> void:
	_audio.play(Audio.Cue.UI_CLICK)
	dismiss()


func _select(index: int) -> void:
	_cursor = index
	var active := [not _fullscreen, _fullscreen, _auto_pause, not _auto_pause, false]
	for i in _buttons.size():
		UI.set_modal_button(_buttons[i], i == index, active[i])
	var button := _buttons[index]
	_pointer.position = button.position + Vector2(-17, floorf(button.size.y * 0.5))
