extends SceneTree
## Opens the real demo scene, selects Wukong, types SUNWUKONG and resolves the case.

var _checks := 0
var _failures := 0
var _demo = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(_demo)
	await process_frame
	_demo.persist_save = false
	_demo.started = true
	_demo.session.start_shift()
	_demo.session._open_day(5)
	_demo.session.active = true
	for _guest in 6:
		_demo.session.spawn_remaining = 0.0
		_demo.session.advance(0.01)
	_demo._show_location("Shop")
	_demo._refresh_shared()
	await process_frame

	var soul_id := -1
	for soul in _demo.session.souls:
		if soul.has("story_case"):
			soul_id = int(soul.id)
			break
	_check(soul_id > 0, "story guest is in the queue")
	_demo.shop.select_guest(soul_id)
	_demo._refresh_shared()
	await process_frame

	_check(_demo.story_panel.visible, "story panel opens")
	_check(not _demo._dialog.visible, "normal dialog is hidden")
	_check(not _demo._release_button.visible, "normal release is hidden")
	_check(_demo._serve_button.text.contains("请他"), "serve button changes label")

	var runtime = _demo.session.get_story_runtime(soul_id)
	_check(runtime != null, "runtime exists")
	_check(_demo.session.is_time_suspended(), "open story pauses the shift")
	_advance_until_choices(runtime)
	_demo._refresh_shared()
	_check(_demo.story_panel._buttons.size() > 0, "choice buttons render")
	_check(_demo.story_panel._callout_button.visible, "callout button renders")
	_check(_demo.story_panel._callout_button.text.contains("叫破"), "callout button has the right label")
	await _capture("story-panel.png")

	# Typed callout: enter the mode and type the real name.
	_demo.story_panel._callout_button.pressed.emit()
	_check(_demo.story_panel.is_typing(), "callout enters typing mode")
	_check(_demo.story_panel._bubbles.visible, "letter bubbles appear")
	_check(_demo.story_panel._bubbles.get_child_count() == 9, "SUNWUKONG renders nine bubbles")
	_check(not _demo.story_panel._callout_button.visible, "callout button hides while typing")
	_check(_demo.story_panel._cancel_button.visible, "cancel button appears while typing")
	await _capture("story-panel-callout.png")
	var q_event := InputEventKey.new()
	q_event.physical_keycode = KEY_Q
	q_event.pressed = true
	_demo._unhandled_key_input(q_event)
	_check(_demo.current_location == "Shop", "Q is captured by the callout, not the river shortcut")
	_check(_demo.story_panel._typing.mistakes == 1, "wrong typed letter counts as a miss")
	for index in "SUNWUKONG".length():
		_demo.story_panel.submit_letter("SUNWUKONG".substr(index, 1))
	_check(bool(runtime.flags["named"]), "typing the name sets named")
	_check(bool(runtime.flags["callout.done"]), "typed callout marks itself done")
	_advance_until_choices(runtime)
	_demo._refresh_shared()
	_check(not _demo.story_panel._callout_button.visible, "callout button stays hidden after success")

	# Feed a hot potion through the shared dose controls.
	_demo.session._add_potion("test", "暖心药", Vector3i(0, 4, 0), -1, 0)
	_demo._selected_dose = [false, int(_demo.session.potions[0]["id"])]
	_demo._refresh_dose()
	_check(not _demo._serve_button.disabled, "serve button enables with a dose")
	_demo._serve_dose()
	_check(runtime.has_fed_potion(), "UI feeds the potion")
	_advance_until_choices(runtime)
	_check(bool(runtime.flags["rage"]), "hot potion keeps rage")

	# Refuse and finish.
	_demo._story_choice("refuse")
	_demo._refresh_shared()
	while not runtime.is_closed():
		if not runtime.advance():
			break
	_demo._refresh_shared()
	_check(runtime.is_closed(), "story reaches an outcome")
	_check(runtime.get_outcome_id() == "refused", "refused outcome")
	_check(_demo.story_panel._finish.visible, "finish button appears")
	_check(_demo.story_panel._hint.text.contains("审查结束"), "finish hint appears")
	await _capture("story-panel-finished.png")

	_demo._story_finish()
	await process_frame
	_check(_demo.session.get_soul(soul_id).is_empty(), "finish removes the story guest")
	_check(not _demo.story_panel.visible, "panel hides after finish")
	_check(not _demo.session.is_time_suspended(), "finish resumes the shift")
	_check(_demo.session.story_state.ledger.size() == 1, "finish writes the ledger")
	_check(str(_demo.session.story_state.ledger[0].get("who", "")) == "孙悟空", "ledger keeps the real name")

	if _failures == 0:
		print("StoryUI: %d checks, 0 failures" % _checks)
	else:
		print("StoryUI: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _advance_until_choices(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 50:
		if not runtime.advance():
			break
		guard += 1


func _capture(file_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://").path_join("../game/build/validation")
	DirAccess.make_dir_recursive_absolute(directory)
	image.save_png(directory.path_join(file_name))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
