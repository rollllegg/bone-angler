extends SceneTree
## Exercises the special guests through the shared reception UI.

const WUKONG_LINE := "还不赶快放俺老s……俺过去。"
const ORPHEUS_LINE := "欧律狄刻现在在哪，她是我的爱人，比我早逝去。我来和她相会了"

var _demo
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	_demo = preload("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(_demo)
	_demo.persist_save = false
	_demo.auto_pause_on_focus_loss = false
	_demo.session.set_process(false)
	_demo.shop.set_process(false)
	_demo._start_game()
	_press(KEY_E)
	var session = _demo.session
	session.essences.fill(0)

	_arrive(5)
	_check(session.souls.all(func(soul: Dictionary) -> bool: return not soul.has("story_case")), "Day one starts with five ordinary guests")
	_check(not _demo._story_action_button.visible, "Ordinary guests show only the existing release button")
	_check(not _demo.soul_hud._bar_labels[0].text.contains("?"), "Ordinary guest attributes stay visible")
	_arrive(1)
	_check(str(session.souls[5].get("story_case", "")) == "wukong", "Wukong is the sixth guest on day one")
	_demo.shop.select_guest(6)
	_check_reception(WUKONG_LINE, "史密斯", "wukong_disguise")
	await _capture("story-reception-wukong.png")

	session._add_potion("test", "暖心药", Vector3i(0, 4, 0), -1, 0)
	session.state_changed.emit()
	var wukong = session.get_story_runtime(6)
	_press(KEY_S)
	_check(not _demo._serve_button.disabled and _demo._serve_button.text.begins_with("空格"), "The ordinary dose button is ready")
	_press(KEY_F)
	_check(not wukong.has_fed_potion() and session.potions.size() == 1, "F does not serve a potion")
	_press(KEY_SPACE)
	_check(wukong.has_fed_potion() and session.potions.is_empty(), "Space serves the selected potion once")
	_check(_demo._dialog.text == WUKONG_LINE and _demo.soul_hud.preview.is_empty(), "Giving medicine preserves the single line and hidden attributes")
	_press(KEY_D)
	_check(_demo.shop.selected_id == 1 and not _demo._story_action_button.visible, "D switches back to normal reception")

	_demo.shop.select_guest(6)
	_demo._story_action_button.pressed.emit()
	_check(_demo.story_panel.visible and _demo.story_panel.is_typing() and session.story_open, "Clicking true name starts the typing challenge")
	_check(_demo.story_panel._bubbles.get_child_count() == 9 and _bubble_letter(0) == "·", "Wukong has nine hidden letters")
	_check(_demo._release_button.disabled and _demo._story_action_button.text.contains("Esc"), "Only the cancel action stays available while typing")
	_press(KEY_SHIFT)
	_check(not wukong.is_closed(), "Release cannot bypass typing")
	_press(KEY_X)
	_check(_demo.story_panel._typing.mistakes == 1, "A wrong letter resets the challenge")
	_press(KEY_ESCAPE)
	_check(not _demo.story_panel.visible and not session.story_open and _demo._story_action_button.text == "真名解放", "Escape cancels and restores the original action")
	_demo._story_action_button.pressed.emit()
	_demo.story_panel._process(21.0)
	_check(not _demo.story_panel.is_typing() and not wukong.is_identity_revealed(), "Timeout leaves Wukong disguised")
	_demo._story_action_button.pressed.emit()
	await _capture("story-reception-callout.png")
	_type_name("SUNWUKONG")
	_check_reveal(wukong, "孙悟空", "wukong_monkey", WUKONG_LINE)
	await _capture("story-reception-wukong-revealed.png")
	_demo._story_action_button.pressed.emit()
	_check(session.get_soul(6).is_empty() and session.rejected_count == 1, "The new action refuses and removes Wukong")
	_check(session.story_state.ledger[0].who == "孙悟空", "The ledger records the revealed name")

	_finish_ordinary_guests()
	_check(_demo.day_report.visible and session.get_day_report().day == 1, "Wukong's aftermath is shown at the end of day one")
	_demo._close_day_report()
	_check(session.day == 2 and not session.awaiting_day_report, "Closing the report allows the next day")
	_press(KEY_E)
	_arrive(5)
	_check(session.souls.all(func(soul: Dictionary) -> bool: return not soul.has("story_case")), "Day two starts with five ordinary guests")
	_arrive(1)
	_check(str(session.souls[5].get("story_case", "")) == "orpheus", "Orpheus is the sixth guest on day two")
	_demo.shop.select_guest(12)
	_check_reception(ORPHEUS_LINE, "亚历克斯", "")

	_demo._story_action_button.pressed.emit()
	_check(_demo.story_panel._bubbles.get_child_count() == 7 and _bubble_letter(0) == "·", "Orpheus has seven hidden letters")
	_type_name("ORPHEUS")
	var orpheus = session.get_story_runtime(12)
	_check_reveal(orpheus, "俄耳甫斯", "orpheus_front", ORPHEUS_LINE)
	await _capture("story-reception-orpheus-revealed.png")
	session._add_potion("test", "极识药", Vector3i(10, 0, -4), -1, 0)
	session.state_changed.emit()
	_press(KEY_S)
	_press(KEY_SPACE)
	_check(orpheus.has_fed_potion() and not bool(orpheus.flags["confused"]), "Giving Orpheus a potion preserves his reaction")
	_press(KEY_SHIFT)
	_check(session.get_soul(12).is_empty() and orpheus.get_outcome_id() == "accepted.reunion", "Shift admits Orpheus and preserves the cross-day ending")
	_finish_ordinary_guests()
	_check(session.get_day_report().entries.size() == 1 and session.get_day_report().day == 2, "Orpheus has his own day-two report")

	_demo.free()
	print("StoryUI: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_reception(line: String, alias: String, portrait: String) -> void:
	_check(_demo._dialog.visible and _demo._dialog.text == line and not _demo.story_panel.visible, "The only greeting uses the shared speech bubble")
	_check(_demo.soul_hud.visible and _demo.soul_hud._name_label.text == alias, "The normal HUD displays the guest's alias")
	_check(_demo.soul_hud._bar_labels.all(func(label: Label) -> bool: return label.text.ends_with(" ?")), "All three attributes are unknown")
	_check(_demo._story_action_button.visible and _demo._story_action_button.text == "真名解放", "The extra bottom-right action is immediately available")
	_check(_demo._release_button.get_rect().end.x <= _demo._story_action_button.position.x, "Release and true name buttons do not overlap")
	_check(_demo.shop.story_sprite == portrait, "The guest starts disguised")


func _check_reveal(runtime, name: String, portrait: String, line: String) -> void:
	_check(runtime.is_identity_revealed() and not _demo.story_panel.visible, "Correct letters complete the challenge")
	_check(_demo.shop.story_sprite == portrait and _demo.soul_hud._name_label.text == name, "The true portrait and name appear immediately")
	_check(_demo._story_action_button.text == "拒绝入境" and _demo._dialog.text == line, "Refusal replaces true name and the greeting stays the same")


func _press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	_demo._unhandled_key_input(event)


func _type_name(value: String) -> void:
	for letter in value:
		_press(OS.find_keycode_from_string(letter))


func _bubble_letter(index: int) -> String:
	var bubble: PanelContainer = _demo.story_panel._bubbles.get_child(index)
	return (bubble.get_child(0) as Label).text


func _arrive(count: int) -> void:
	for _guest in count:
		_demo.session.spawn_remaining = 0.0
		_demo.session.advance(0.01)


func _finish_ordinary_guests() -> void:
	var session = _demo.session
	for soul in session.souls.duplicate():
		soul.stats = session.requirements[0]
		_check(session.release_soul(int(soul.id)), "An eligible ordinary guest can still be released")


func _capture(file_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	var directory := ProjectSettings.globalize_path("res://build/validation")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(file_name))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
