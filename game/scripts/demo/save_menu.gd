extends "res://scripts/demo/pixel_modal.gd"

signal slot_selected(slot: int)
signal overwrite_confirmed(slot: int)

const UI := preload("res://scripts/demo/demo_ui.gd")
const SaveSlots := preload("res://scripts/demo/save_slots.gd")

var saving := false
var slot_buttons: Array[Button] = []
var confirm_buttons: Array[Button] = []

var _panel: Panel
var _heading: Label
var _status: Label
var _confirmation: Panel
var _prompt: Label
var _slot_cursor := 0
var _confirm_cursor := 0
var _overwrite_slot := 0


func setup(stage_size: Vector2) -> void:
	setup_modal(stage_size)

	var panel_size := Vector2(680, 424)
	_panel = UI.modal_panel(self, Rect2((stage_size - panel_size) * 0.5, panel_size))
	UI.icon_rect(_panel, UI.ICON_SOUL, Rect2(27, 22, 32, 32))
	_heading = UI.label(_panel, "", Rect2(69, 17, 500, 44), 27, UI.GOLD)
	UI.modal_button(_panel, "×", Rect2(606, 18, 46, 38), dismiss)
	for slot in SaveSlots.COUNT:
		var button := UI.modal_button(_panel, "存档 %d" % (slot + 1), Rect2(34, 86 + slot * 74, 612, 59), _choose_slot.bind(slot))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_entered.connect(_select_slot.bind(slot))
		slot_buttons.append(button)
	_status = UI.label(_panel, "", Rect2(34, 312, 612, 34), 19, UI.MINT)
	_show_key_hints(_panel, 369, ["W", "S"])

	var confirm_size := Vector2(540, 242)
	_confirmation = UI.modal_panel(self, Rect2((stage_size - confirm_size) * 0.5, confirm_size))
	_prompt = UI.label(_confirmation, "", Rect2(34, 17, 474, 44), 26, UI.GOLD)
	UI.label(_confirmation, "覆盖后将替换这个位置的存档。", Rect2(34, 82, 472, 34), 20, UI.CREAM)
	confirm_buttons.assign([
		UI.modal_button(_confirmation, "取消", Rect2(34, 130, 220, 46), _cancel_overwrite),
		UI.modal_button(_confirmation, "覆盖存档", Rect2(286, 130, 220, 46), _confirm_overwrite),
	])
	for index in confirm_buttons.size():
		confirm_buttons[index].mouse_entered.connect(_select_confirmation.bind(index))
	_show_key_hints(_confirmation, 195, ["A", "D"])
	_panel.hide()
	_confirmation.hide()


func _show_key_hints(parent: Control, y: float, navigation: Array[String]) -> void:
	var left := 34.0
	left += UI.key_hint(parent, navigation, "选择", Vector2(left, y)) + 20.0
	left += UI.key_hint(parent, ["Space"], "确认", Vector2(left, y)) + 20.0
	UI.key_hint(parent, ["C", "Esc"], "返回", Vector2(left, y))


func open(for_save: bool, entries: Array[Dictionary]) -> void:
	saving = for_save
	_heading.text = "保存游戏" if saving else "读取存档"
	_status.text = ""
	_slot_cursor = 0
	update_slots(entries)
	present(_panel)


func update_slots(entries: Array[Dictionary]) -> void:
	for slot in slot_buttons.size():
		var entry := entries[slot]
		var button := slot_buttons[slot]
		button.text = "存档 %d　　%s" % [slot + 1, entry["summary"]]
		button.disabled = not saving and not bool(entry["readable"])
	if slot_buttons[_slot_cursor].disabled:
		_slot_cursor = UI.next_button(slot_buttons, _slot_cursor, 1)
	_refresh_slot_focus()


func show_status(message: String, failed: bool = false) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", UI.WARN if failed else UI.MINT)


func ask_overwrite(slot: int) -> void:
	_overwrite_slot = slot
	_prompt.text = "覆盖存档 %d？" % (slot + 1)
	_select_confirmation(0)
	present(_confirmation)


func handle_key(code: Key) -> void:
	var confirming := _confirmation.visible
	match code:
		KEY_C, KEY_ESCAPE:
			if confirming:
				_cancel_overwrite()
			else:
				dismiss()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			UI.activate(confirm_buttons[_confirm_cursor] if confirming else slot_buttons[_slot_cursor])
		KEY_W, KEY_UP, KEY_A, KEY_LEFT, KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT:
			var step := -1 if code in [KEY_W, KEY_UP, KEY_A, KEY_LEFT] else 1
			if confirming:
				_select_confirmation(posmod(_confirm_cursor + step, confirm_buttons.size()))
			else:
				_select_slot(UI.next_button(slot_buttons, _slot_cursor, step))


func _choose_slot(slot: int) -> void:
	_select_slot(slot)
	_status.text = ""
	slot_selected.emit(slot)


func _select_slot(slot: int) -> void:
	if slot_buttons[slot].disabled:
		return
	_slot_cursor = slot
	_refresh_slot_focus()


func _refresh_slot_focus() -> void:
	for index in slot_buttons.size():
		var button := slot_buttons[index]
		UI.set_modal_button(button, index == _slot_cursor and not button.disabled)


func _select_confirmation(index: int) -> void:
	_confirm_cursor = index
	for i in confirm_buttons.size():
		UI.set_modal_button(confirm_buttons[i], i == index)


func _cancel_overwrite() -> void:
	present(_panel)


func _confirm_overwrite() -> void:
	_cancel_overwrite()
	overwrite_confirmed.emit(_overwrite_slot)
