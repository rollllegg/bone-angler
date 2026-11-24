extends "res://scripts/demo/pixel_modal.gd"

const UI := preload("res://scripts/demo/demo_ui.gd")

var panel: Panel
var _pointer: Control
var _buttons: Array[Button] = []
var _cursor := 0
var _fullscreen := false
var _auto_pause := true


func setup(stage_size: Vector2, display_mode: Callable, auto_pause: Callable) -> void:
	setup_modal(stage_size, true)
	var panel_size := Vector2(680, 522)
	panel = UI.modal_panel(self, Rect2((stage_size - panel_size) * 0.5, panel_size))
	UI.icon_rect(panel, UI.ICON_WRENCH, Rect2(26, 20, 32, 32))
	UI.label(panel, "游戏设置", Rect2(70, 17, 300, 44), 27, UI.GOLD)
	UI.modal_button(panel, "×", Rect2(606, 18, 46, 38), dismiss)

	UI.label(panel, "显示模式", Rect2(34, 89, 220, 46), 22)
	UI.label(panel, "切出窗口自动暂停", Rect2(34, 149, 230, 46), 22)
	_buttons.assign([
		UI.modal_button(panel, "窗口模式", Rect2(286, 89, 164, 46), display_mode.bind(false)),
		UI.modal_button(panel, "全屏模式", Rect2(478, 89, 164, 46), display_mode.bind(true)),
		UI.modal_button(panel, "开启", Rect2(286, 149, 164, 46), auto_pause.bind(true)),
		UI.modal_button(panel, "关闭", Rect2(478, 149, 164, 46), auto_pause.bind(false)),
	])

	var keys := UI.pixel_panel(panel, Rect2(34, 221, 612, 204), Color("191728"), Color("47435a"), Color("151222"))
	UI.label(keys, "操作按键", Rect2(17, 7, 140, 30), 20, UI.MINT)
	UI.key_hint(keys, ["Q"], "河岸", Vector2(17, 43))
	UI.key_hint(keys, ["E"], "接待", Vector2(152, 43))
	UI.key_hint(keys, ["R"], "炼药", Vector2(302, 43))
	UI.key_hint(keys, ["T"], "市场", Vector2(465, 43))
	UI.key_hint(keys, ["WASD"], "选择／拉鱼", Vector2(17, 81))
	UI.key_hint(keys, ["Space"], "确认／抛竿", Vector2(302, 81))
	UI.key_hint(keys, ["Shift"], "更换部件／放行", Vector2(17, 119))
	UI.key_hint(keys, ["C"], "取消／返回", Vector2(302, 119))
	UI.key_hint(keys, ["X"], "收竿", Vector2(17, 157))
	UI.key_hint(keys, ["P", "Esc"], "暂停／继续", Vector2(302, 157))
	_buttons.append(UI.modal_button(panel, "确定", Rect2(220, 450, 240, 44), dismiss))

	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.draw.connect(_draw_pointer)
	panel.add_child(_pointer)
	for i in _buttons.size():
		_buttons[i].mouse_entered.connect(_select.bind(i))
	_select(0)
	panel.hide()


func open() -> void:
	_select(0)
	present(panel)


func sync_options(fullscreen: bool, auto_pause: bool) -> void:
	_fullscreen = fullscreen
	_auto_pause = auto_pause
	_select(_cursor)


func handle_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_UP, KEY_A, KEY_LEFT, KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT:
			var step := -1 if code in [KEY_W, KEY_UP, KEY_A, KEY_LEFT] else 1
			_select(UI.next_button(_buttons, _cursor, step))
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			UI.activate(_buttons[_cursor])
		KEY_C, KEY_ESCAPE:
			dismiss()
		_:
			return false
	return true


func _select(index: int) -> void:
	_cursor = index
	var active := [not _fullscreen, _fullscreen, _auto_pause, not _auto_pause, false]
	for i in _buttons.size():
		UI.set_modal_button(_buttons[i], i == index, active[i])
	var button := _buttons[index]
	_pointer.position = button.position + Vector2(-17, floorf(button.size.y * 0.5))


func _draw_pointer() -> void:
	_pointer.draw_rect(Rect2(0, -2, 10, 4), UI.GOLD)
	_pointer.draw_rect(Rect2(3, -5, 4, 10), UI.GOLD)
	_pointer.draw_rect(Rect2(4, -1, 2, 2), Color("fff8dc"))
