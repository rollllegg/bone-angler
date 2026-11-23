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
	_check(data.has("callout"), "wukong has a typed callout")
	_check(str(data.get("queue_name", "")) == "史密斯", "queue name hides the monkey")
	_check(str(data.get("callout", {}).get("answer", "")) == "SUNWUKONG", "callout answer is SUNWUKONG")
	_check(str(data.get("callout", {}).get("success", "")) == "identify", "callout success goes to identify")
	_check(str(data.get("callout", {}).get("failure", "")) == "callout.fail", "callout failure goes to callout.fail")

	_check_all_text_keys(data)
	_check_potion_scores(data)

	# 1. No clues, no potion, admit: default rage is true.
	var path1 = _new_path()
	_settle(path1["runtime"])
	_choose(path1["runtime"], "admit")
	_settle(path1["runtime"])
	_check(path1["runtime"].is_closed(), "admit path closes")
	_check(path1["runtime"].get_outcome_id() == "admitted", "default admit outcome")
	_check(str(path1["runtime"].get_outcome().get("result", "")) == "release", "admit releases")
	_check(bool(path1["state"].world["world.hades_rampage"]), "default admit sets hades rampage")
	_check(bool(path1["state"].world["world.wukong_admitted"]), "default admit records admission")
	_check(bool(path1["state"].world["world.wukong_case_seen"]), "canon records the case")
	_check(str(path1["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "史密斯", "unnamed ledger keeps the disguise")
	_check(_ending_id(path1["state"]) == "hades_rampage", "default ending is rampage")

	# 2. Callout success, then refuse: named ledger + rampage.
	var path2 = _new_path()
	_settle(path2["runtime"])
	var callout: Dictionary = path2["runtime"].start_callout()
	_check(not callout.is_empty(), "callout starts")
	_check(not path2["runtime"].can_callout(), "callout cannot start twice")
	_check(not path2["runtime"].advance(), "advance is blocked during callout")
	_check(not path2["runtime"].choose("photo"), "choices are blocked during callout")
	_check(not path2["runtime"].can_feed_potion(), "potion is blocked during callout")
	_check(path2["runtime"].resolve_callout(true), "callout resolves")
	_settle(path2["runtime"])
	_check(bool(path2["runtime"].flags["named"]), "callout success sets named")
	_check(bool(path2["runtime"].flags["callout.done"]), "callout marks itself done")
	_check(not path2["runtime"].can_callout(), "called-out name hides the button")
	_choose(path2["runtime"], "refuse")
	_settle(path2["runtime"])
	_check(path2["runtime"].get_outcome_id() == "refused", "named refusal outcome")
	_check(bool(path2["state"].world["world.hades_rampage"]), "named refusal still rampages")
	_check(bool(path2["state"].history["case.wukong.named"]), "case snapshot keeps named")
	_check(str(path2["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "孙悟空", "named ledger records the real name")
	var lines := _ending_lines(path2["state"])
	_check(_contains(lines, "孙悟空"), "named epilogue mentions the real name")

	# 3. Calming potion ends the case before accept/refuse.
	var path3 = _new_path()
	_settle(path3["runtime"])
	_check(path3["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "calming potion accepted")
	_settle(path3["runtime"])
	_check(path3["runtime"].is_closed(), "calming potion closes the case")
	_check(path3["runtime"].get_outcome_id() == "calm", "calming potion uses the calm outcome")
	_check(str(path3["runtime"].get_outcome().get("result", "")) == "leave", "calm outcome leaves")
	_check(not bool(path3["state"].world["world.hades_rampage"]), "calm outcome avoids rampage")
	_check(not bool(path3["state"].world["world.wukong_admitted"]), "calm outcome does not admit")
	_check(str(path3["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "史密斯", "calm unnamed ledger keeps the disguise")
	_check(_ending_id(path3["state"]) == "quiet_shift", "calm ending is quiet")

	# 3b. A zero score is non-positive, so the guest leaves.
	var path3b = _new_path()
	_settle(path3b["runtime"])
	_check(path3b["runtime"].feed_potion(Vector3i(1, 0, 1), "灰鳞原液"), "zero-score potion accepted")
	_settle(path3b["runtime"])
	_check(path3b["runtime"].is_closed(), "zero score closes the case")
	_check(path3b["runtime"].get_outcome_id() == "calm", "zero score uses the calm outcome")

	# 4. Callout failure returns to the hub, and can be retried.
	var path4 = _new_path()
	_settle(path4["runtime"])
	path4["runtime"].start_callout()
	_check(path4["runtime"].resolve_callout(false), "callout failure resolves")
	_settle(path4["runtime"])
	_check(not bool(path4["runtime"].flags.get("callout.done", false)), "failed callout can retry")
	_check(path4["runtime"].can_callout(), "callout button returns after failure")
	path4["runtime"].start_callout()
	path4["runtime"].resolve_callout(true)
	_settle(path4["runtime"])
	_check(bool(path4["runtime"].flags["named"]), "retry can identify him")

	# 5. Hot potion keeps rage; second potion is refused.
	var path5 = _new_path()
	_settle(path5["runtime"])
	_check(path5["runtime"].feed_potion(Vector3i(0, 4, 0), "暖心药"), "hot potion accepted")
	_settle(path5["runtime"])
	_check(bool(path5["runtime"].flags["rage"]), "hot potion keeps rage")
	_check(not path5["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "only one potion per visit")
	_choose(path5["runtime"], "admit")
	_settle(path5["runtime"])
	_check(path5["runtime"].get_outcome_id() == "admitted", "hot potion admit outcome")

	# 6. Default refusal still rampages.
	var path6 = _new_path()
	_settle(path6["runtime"])
	_choose(path6["runtime"], "refuse")
	_settle(path6["runtime"])
	_check(path6["runtime"].get_outcome_id() == "refused", "default refusal outcome")
	_check(bool(path6["state"].world["world.hades_rampage"]), "default refusal still sets hades rampage")

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
	var callout: Dictionary = data.get("callout", {})
	if not callout.is_empty():
		_check(_db.text.has(str(callout.get("prompt", ""))), "callout prompt text exists")
		_check(_db.text.has(str(callout.get("button", ""))), "callout button text exists")


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
