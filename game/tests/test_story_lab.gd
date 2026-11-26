extends SceneTree
## Checks the developer story lab: day one start, story-only queue, N to skip a day.

var _checks := 0
var _failures := 0
var _demo


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(demo)
	_demo = demo
	await process_frame
	demo.persist_save = false
	demo._start_story_lab()
	await process_frame
	_check(demo.started, "story lab starts the game")
	_check(not demo.persist_save, "story lab disables saving")
	_check(demo.story_lab, "story lab enables its day shortcut")
	_check(demo.session.day == 1, "story lab starts on day one")
	_check(demo.current_location == "Shop", "story lab opens the reception")
	_check(demo.session.souls.size() == 2, "story lab keeps only the day-one story guests")
	var cases: Array = []
	for soul in demo.session.souls:
		if soul.has("story_case"):
			cases.append(str(soul.story_case))
	_check(cases == ["wukong"], "story lab keeps Wukong on day one")
	var observer: Dictionary = demo.session.souls[1]
	_check(bool(observer.get("fixed_stats", false)) and observer.stats == Vector3i(10, 10, 10), "story lab keeps the disguised observer")
	_check(demo.session.released_count == 4, "story lab skips the four ordinary day-one guests")
	_check(demo.session.potions.size() == 3, "story lab stocks three test potions")
	_check(demo.session.potions[0].effect == Vector3i(0, 4, 0), "story lab hot potion")
	_check(demo.session.potions[1].effect == Vector3i(10, 0, -4), "story lab clear potion")
	_check(demo.session.potions[2].effect == Vector3i(1, 0, -1), "story lab zero potion")
	_check(not demo.story_panel.visible, "story lab uses the ordinary reception layout")
	_check(demo.shop.selected_id == 5, "story lab selects Wukong first")
	_check(demo._story_action_button.visible, "story lab shows the true-name action")
	_check(demo._release_button.visible, "story lab shows the normal release control")
	_check(demo._dose_buttons.size() == 3, "story lab lists the three test potions")
	_check(demo._arrival.text.contains("N"), "story lab shows the next-day shortcut")
	await _capture("story-lab.png")

	_press(KEY_N)
	_check(demo.session.day == 2, "N advances to day two")
	_check(demo.session.souls.size() == 1 and str(demo.session.souls[0].get("story_case", "")) == "orpheus", "day two keeps only Orpheus")
	_check(demo.shop.selected_id == 12, "day two selects Orpheus")
	_check(demo.session.released_count == 9, "N clears the five ordinary day-two guests")

	_press(KEY_N)
	_check(demo.session.day == 3 and demo.session.souls.is_empty(), "day three is empty when Orpheus was not lost")
	_check(demo.session.released_count == 15, "N clears the six ordinary day-three guests")

	_press(KEY_N)
	_check(demo.session.day == 4 and demo.session.souls.is_empty(), "day four has no story guest")
	_check(demo.session.released_count == 21, "N clears the six ordinary day-four guests")

	_press(KEY_N)
	_check(demo.session.day == 5 and demo.session.souls.size() == 1, "day five keeps Anubis")
	_check(str(demo.session.souls[0].get("story_case", "")) == "anubis" and demo.session.souls[0].name == "？？？", "day five selects the hidden Anubis")
	_check(demo.session.released_count == 26, "N clears the five ordinary day-five guests")
	await _capture("story-lab-day5.png")

	_press(KEY_N)
	_check(demo.session.day == 5, "N stops at the last day")
	demo.free()

	if _failures == 0:
		print("StoryLab: %d checks, 0 failures" % _checks)
	else:
		print("StoryLab: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _press(code: Key) -> void:
	# The lab test calls the same handler the real key event reaches.
	_demo._handle_game_key(code)


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
