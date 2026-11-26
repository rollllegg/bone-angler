extends SceneTree
## Saves and reloads a story guest in an isolated save directory.

const SaveSlots := preload("res://scripts/demo/save_slots.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var directory := "res://build/validation/story-save-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]

	var demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	demo.persist_save = false
	demo.started = true
	demo.session.start_shift()
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
	runtime.start_callout()
	runtime.resolve_callout(true)
	_advance_until_choices(runtime)

	demo.persist_save = true
	demo.save_directory = directory
	_check(demo.save_progress(0), "save file written")
	var save_path := SaveSlots.existing_path(directory, 0)
	var payload := SaveSlots.read(save_path)
	_check(not payload.is_empty(), "save payload parses")
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

	# A save from the retired observer implementation must load as an ordinary guest.
	for entry in saved_souls:
		if int(entry.get("id", 0)) == 5:
			_check(not entry.has("fixed_stats") and not entry.has("anubis_disguise"), "new saves do not write observer flags")
			entry["stats"] = [10, 10, 10]
			entry["before"] = [10, 10, 10]
			entry["fee"] = 40
			entry["fixed_stats"] = true
			entry["anubis_disguise"] = true
	_check(SaveSlots.write(directory, 0, payload), "legacy observer fixture is written")

	_check(demo.load_progress(0), "saved slot loads")
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
	_check(restored.get_node_id() == "inspect" and not restored.visible_choices().is_empty(), "load restores the choice hub")
	demo.shop.select_guest(restored_id)
	_check(demo.shop.story_sprite == "wukong_monkey" and demo._story_action_button.text == "拒绝入境", "load restores the revealed portrait and refusal action")

	var ordinary: Dictionary = demo.session.get_soul(5)
	_check(not ordinary.has("fixed_stats") and not ordinary.has("anubis_disguise") and not ordinary.has("story_case"), "loading retires the old observer flags")
	_check(ordinary.stats == Vector3i(10, 10, 10), "migration preserves saved guest attributes")
	_check(int(ordinary.fee) == demo.session.service_fee(ordinary.before), "migration restores ordinary service pricing")
	demo.session._add_potion("test", "旧存档测试药", Vector3i(-1, -1, -1), -1, 0)
	var potion_id := int(demo.session.potions.back().id)
	_check(demo.session.preview(5, false, potion_id).after == Vector3i(9, 9, 9), "migrated guest previews normal potion effects")
	_check(demo.session.serve(5, false, potion_id) and ordinary.stats == Vector3i(9, 9, 9), "migrated guest's attributes change after drinking")
	ordinary.stats = Vector3i.ZERO
	_check(not demo.session.can_release(5), "migrated guest must meet the ordinary requirements")
	_check(demo.save_progress(0), "migrated save can be written again")
	for entry in SaveSlots.read(save_path).get("souls", []):
		_check(not entry.has("fixed_stats") and not entry.has("anubis_disguise"), "resaving removes legacy observer flags")

	demo.persist_save = false
	demo.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

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
