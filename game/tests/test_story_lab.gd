extends SceneTree
## Checks the developer story lab starts on day 5 with both cases ready.

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	demo.persist_save = false
	demo._start_story_lab()
	await process_frame
	_check(demo.started, "story lab starts the game")
	_check(not demo.persist_save, "story lab disables saving")
	_check(demo.session.day == 5, "story lab opens day 5")
	_check(demo.current_location == "Shop", "story lab opens the reception")
	_check(demo.session.souls.size() == 2, "story lab keeps two guests")
	var cases: Array = []
	for soul in demo.session.souls:
		cases.append(str(soul.get("story_case", "")))
	_check(cases.has("wukong") and cases.has("orpheus"), "story lab keeps both story cases")
	_check(demo.session.released_count == 28, "story lab releases the four normal guests")
	_check(demo.session.potions.size() == 3, "story lab stocks three test potions")
	_check(demo.session.potions[0].effect == Vector3i(0, 4, 0), "story lab hot potion")
	_check(demo.session.potions[1].effect == Vector3i(10, 0, -4), "story lab clear potion")
	_check(demo.session.potions[2].effect == Vector3i(1, 0, -1), "story lab zero potion")
	_check(demo.story_panel.visible, "story lab opens the selected story panel")
	var selected := -1
	for soul in demo.session.souls:
		if soul.has("story_case"):
			selected = int(soul.id)
			break
	_check(selected > 0, "story lab has a selected story guest")
	var runtime = demo.session.get_story_runtime(selected)
	_check(runtime != null, "story lab runtime exists")
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 50:
		if not runtime.advance():
			break
		guard += 1
	demo._refresh_shared()
	_check(demo.story_panel._buttons.size() > 0, "story lab reaches the choice hub")
	_check(demo.story_panel._decision_buttons.size() == 2, "story lab shows the accept/refuse buttons")
	_check(demo.story_panel._callout_button.visible, "story lab shows the callout button")
	_check(demo._dose_buttons.size() == 3, "story lab lists the three test potions")
	await _capture("story-lab.png")
	demo.free()

	if _failures == 0:
		print("StoryLab: %d checks, 0 failures" % _checks)
	else:
		print("StoryLab: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


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
