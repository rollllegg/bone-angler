extends SceneTree
## Saves and reloads a story guest, then restores the previous user save.

const SAVE_PATH := "user://bone_angler_save.json"

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var backup: PackedByteArray = PackedByteArray()
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		backup = FileAccess.get_file_as_bytes(SAVE_PATH)

	var demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	demo.persist_save = false
	demo.started = true
	demo.session.start_shift()
	demo.session._open_day(5)
	demo.session.active = true
	for _guest in 6:
		demo.session.spawn_remaining = 0.0
		demo.session.advance(0.01)
	demo._show_location("Shop")
	demo._refresh_shared()

	var soul_id := -1
	for soul in demo.session.souls:
		if soul.has("story_case"):
			soul_id = int(soul.id)
			break
	_check(soul_id > 0, "story guest present before save")
	var runtime = demo.session.get_story_runtime(soul_id)
	_advance_until_choices(runtime)
	runtime.choose("photo")
	_advance_until_choices(runtime)
	demo.session._add_potion("test", "暖心药", Vector3i(0, 4, 0), -1, 0)
	demo.session.feed_story_potion(soul_id, false, int(demo.session.potions[0]["id"]))
	_advance_until_choices(runtime)
	_check(int(runtime.flags["clue.photo"]) == 1, "clue set before save")
	_check(int(runtime.flags["dose.score"]) == 4, "dose score set before save")

	demo.persist_save = true
	demo.save_progress()
	_check(FileAccess.file_exists(SAVE_PATH), "save file written")
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(payload is Dictionary, "save payload parses")
	var saved_story: Dictionary = payload.get("story", {})
	_check(saved_story.has("world"), "save contains story world state")
	var saved_souls: Array = payload.get("souls", [])
	var saved_soul: Dictionary = {}
	for entry in saved_souls:
		if str(entry.get("story_case", "")) == "wukong":
			saved_soul = entry
			break
	_check(not saved_soul.is_empty(), "save contains the story soul")
	_check(saved_soul.get("story_state", {}).has("flags"), "save contains the runtime snapshot")

	demo.load_progress()
	await process_frame
	var restored_id := -1
	for soul in demo.session.souls:
		if str(soul.get("story_case", "")) == "wukong":
			restored_id = int(soul.id)
			break
	_check(restored_id > 0, "load restores the story soul")
	var restored = demo.session.get_story_runtime(restored_id)
	_check(restored != null, "load rebuilds the story runtime")
	_check(int(restored.flags["clue.photo"]) == 1, "load restores clues")
	_check(int(restored.flags["dose.score"]) == 4, "load restores the potion result")
	_check(restored.has_fed_potion(), "load restores the fed potion")
	_check(str(restored.current_step().get("key", "")).begins_with("wukong."), "load restores the dialogue position")

	demo.persist_save = false
	demo.free()
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	if _failures == 0:
		print("StorySave: %d checks, 0 failures" % _checks)
	else:
		print("StorySave: %d checks, %d failures" % [_checks, _failures])
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
