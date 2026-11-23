extends SceneTree
## Verifies the compiled Wukong content end to end.

const DB := preload("res://scripts/story/story_db.gd")
const Runtime := preload("res://scripts/story/story_runtime.gd")
const State := preload("res://scripts/story/story_state.gd")

var _checks := 0
var _failures := 0
var _db = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_db = DB.new()
	_check(_db.load_all(), "story DB loads")
	_check(_db.cases.has("wukong"), "wukong case exists")
	_check(_db.get_scheduled_case(5, 5) == "wukong", "wukong is scheduled for day 5 slot 5")
	_check(_db.get_scheduled_case(2, 1) == "", "day 2 slot 1 is not a story slot")

	var data: Dictionary = _db.get_case("wukong")
	_check(str(data.get("entry", "")) == "arrival", "entry is arrival")
	_check(not bool(data.get("requires_stats", true)), "story guest does not use stat gate")
	_check(data.has("potion"), "wukong has a potion rule")
	_check(str(data.get("queue_name", "")) == "史密斯", "queue name hides the monkey")

	_check_all_text_keys(data)
	_check_potion_scores(data)

	# 1. No clues, no potion, admit: default rage is true.
	var path1 = _new_path()
	_settle(path1["runtime"])
	_choose(path1["runtime"], "admit")
	_settle(path1["runtime"])
	_check(path1["runtime"].is_closed(), "admit path closes")
	_check(path1["runtime"].get_outcome_id() == "admitted.rage", "default admit ends in rage")
	_check(bool(path1["state"].world["world.hades_rampage"]), "default admit sets hades rampage")
	_check(bool(path1["state"].world["world.wukong_admitted"]), "default admit records admission")
	_check(bool(path1["state"].world["world.wukong_case_seen"]), "canon records the case")
	_check(bool(path1["state"].history["case.wukong.named"]) == false, "default admit is unnamed")
	_check(_ending_id(path1["state"]) == "hades_rampage", "default ending is rampage")

	# 2. Two clues, name, calming potion, refuse: calm + named.
	var path2 = _new_path()
	_settle(path2["runtime"])
	_choose(path2["runtime"], "photo")
	_settle(path2["runtime"])
	_choose(path2["runtime"], "tail")
	_settle(path2["runtime"])
	_check(_has_choice(path2["runtime"], "name"), "two clues unlock the name choice")
	_choose(path2["runtime"], "name")
	_settle(path2["runtime"])
	_check(bool(path2["runtime"].flags["named"]), "name choice sets named")
	_check(path2["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "calming potion accepted")
	_settle(path2["runtime"])
	_check(bool(path2["runtime"].flags["rage"]) == false, "calming potion lowers rage")
	_choose(path2["runtime"], "refuse")
	_settle(path2["runtime"])
	_check(path2["runtime"].get_outcome_id() == "refused.calm", "named calm refusal outcome")
	_check(bool(path2["state"].world["world.hades_rampage"]) == false, "calm refusal avoids rampage")
	_check(bool(path2["state"].history["case.wukong.named"]), "case snapshot keeps named")
	# 2b. Named + rage: the rampage epilogue remembers the name.
	var path2b = _new_path()
	_settle(path2b["runtime"])
	_choose(path2b["runtime"], "photo")
	_settle(path2b["runtime"])
	_choose(path2b["runtime"], "staff")
	_settle(path2b["runtime"])
	_choose(path2b["runtime"], "name")
	_settle(path2b["runtime"])
	_choose(path2b["runtime"], "refuse")
	_settle(path2b["runtime"])
	_check(path2b["runtime"].get_outcome_id() == "refused.rage", "named refusal defaults to rage")
	var lines := _ending_lines(path2b["state"])
	_check(_contains(lines, "孙悟空"), "named epilogue mentions the real name")

	# 3. One clue is not enough to call him out.
	var path3 = _new_path()
	_settle(path3["runtime"])
	_choose(path3["runtime"], "photo")
	_settle(path3["runtime"])
	_check(not _has_choice(path3["runtime"], "name"), "one clue does not unlock the name choice")

	# 4. Hot potion + admit still rampages; second potion is refused.
	var path4 = _new_path()
	_settle(path4["runtime"])
	_check(path4["runtime"].feed_potion(Vector3i(0, 4, 0), "暖心药"), "hot potion accepted")
	_settle(path4["runtime"])
	_check(bool(path4["runtime"].flags["rage"]), "hot potion keeps rage")
	_check(not path4["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "only one potion per visit")
	_choose(path4["runtime"], "admit")
	_settle(path4["runtime"])
	_check(path4["runtime"].get_outcome_id() == "admitted.rage", "hot potion admit rampages")

	# 5. Canon must not depend on the release choice.
	var path5 = _new_path()
	_settle(path5["runtime"])
	_choose(path5["runtime"], "refuse")
	_settle(path5["runtime"])
	_check(path5["runtime"].get_outcome_id() == "refused.rage", "default refusal still rampages")
	_check(bool(path5["state"].world["world.hades_rampage"]), "refusal still sets hades rampage")

	if _failures == 0:
		print("StoryContent: %d checks, 0 failures" % _checks)
	else:
		print("StoryContent: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _new_path() -> Dictionary:
	var state = State.new()
	state.init_defaults(_db.world_decl)
	var runtime = Runtime.new()
	runtime.setup(_db.get_case("wukong"), _db.text, state)
	runtime.start()
	return {"runtime": runtime, "state": state}


func _settle(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 50:
		if not runtime.advance():
			break
		guard += 1


func _choose(runtime, id: String) -> void:
	_check(runtime.choose(id), "choice %s succeeds" % id)


func _has_choice(runtime, id: String) -> bool:
	for choice in runtime.visible_choices():
		if str(choice.get("id", "")) == id and not bool(choice.get("locked", false)):
			return true
	return false


func _ending_id(state) -> String:
	return str(_db.evaluate_ending(state).get("id", ""))


func _ending_lines(state) -> PackedStringArray:
	var ending: Dictionary = _db.evaluate_ending(state)
	return _db.ending_lines_for(ending, state)


func _contains(lines: PackedStringArray, needle: String) -> bool:
	for line in lines:
		if line.contains(needle):
			return true
	return false


func _check_all_text_keys(data: Dictionary) -> void:
	for node in data.get("nodes", []):
		for step in node.get("steps", []):
			_check(_db.text.has(str(step.get("text", ""))), "text exists: %s" % str(step.get("text", "")))
		for choice in node.get("choices", []):
			_check(_db.text.has(str(choice.get("text", ""))), "choice text exists: %s" % str(choice.get("text", "")))
	for outcome_id in data.get("outcomes", {}).keys():
		var ledger: Dictionary = data.outcomes[outcome_id].get("ledger", {})
		_check(_db.text.has(str(ledger.get("note", ""))), "ledger note exists for %s" % outcome_id)


func _check_potion_scores(data: Dictionary) -> void:
	var coefficients: Dictionary = data.get("potion", {}).get("score", {})
	_check(int(coefficients.get("wisdom", 0)) == -1, "wisdom lowers rage")
	_check(int(coefficients.get("emotion", 0)) == 1, "emotion raises rage")
	_check(int(coefficients.get("will", 0)) == 1, "will raises rage")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
