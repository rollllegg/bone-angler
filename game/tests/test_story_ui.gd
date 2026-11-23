extends SceneTree
## Opens the real demo scene, selects Wukong, and drives the story panel.

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
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var directory := ProjectSettings.globalize_path("res://").path_join("../game/build/validation")
		DirAccess.make_dir_recursive_absolute(directory)
		image.save_png(directory.path_join("story-panel.png"))

	_demo._story_choice("photo")
	_demo._refresh_shared()
	_check(int(runtime.flags["clue.photo"]) == 1, "UI choice reaches the runtime")
	_advance_until_choices(runtime)

	# Give a calming potion through the shared dose controls.
	_demo.session._add_potion("test", "极识药", Vector3i(10, 0, -4), -1, 0)
	_demo._selected_dose = [false, int(_demo.session.potions[0]["id"])]
	_demo._refresh_dose()
	_check(not _demo._serve_button.disabled, "serve button enables with a dose")
	_demo._serve_dose()
	_check(runtime.has_fed_potion(), "UI feeds the potion")
	_advance_until_choices(runtime)
	_check(not bool(runtime.flags["rage"]), "UI potion calms the guest")

	while not runtime.is_closed():
		var choices: Array = runtime.visible_choices()
		if choices.is_empty():
			if not runtime.advance():
				break
		else:
			var picked := false
			for choice in choices:
				if not bool(choice.get("locked", false)):
					_demo._story_choice(str(choice.get("id", "")))
					picked = true
					break
			if not picked:
				break
	_demo._refresh_shared()
	_check(runtime.is_closed(), "story reaches an outcome")
	_check(_demo.story_panel._finish.visible, "finish button appears")
	_check(_demo.story_panel._hint.text.contains("审查结束"), "finish hint appears")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var directory := ProjectSettings.globalize_path("res://").path_join("../game/build/validation")
		DirAccess.make_dir_recursive_absolute(directory)
		image.save_png(directory.path_join("story-panel-finished.png"))

	_demo._story_finish()
	await process_frame
	_check(_demo.session.get_soul(soul_id).is_empty(), "finish removes the story guest")
	_check(not _demo.story_panel.visible, "panel hides after finish")
	_check(not _demo.session.is_time_suspended(), "finish resumes the shift")

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


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
