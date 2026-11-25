extends SceneTree
## Verifies the compiled Wukong and Orpheus content end to end.

const DB := preload("res://scripts/story/story_db.gd")
const Runtime := preload("res://scripts/story/story_runtime.gd")
const State := preload("res://scripts/story/story_state.gd")
const Catalog := preload("res://scripts/story/story_cue_catalog.gd")

var _checks := 0
var _failures := 0
var _db = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_db = DB.new()
	_check(_db.load_all(), "story DB loads")
	_check(_db.cases.has("wukong"), "wukong case exists")
	_check(_db.cases.has("orpheus"), "orpheus case exists")
	_check(_db.get_scheduled_case(1, 5) == "wukong", "wukong is the sixth guest on day 1")
	_check(_db.get_scheduled_case(2, 5) == "orpheus", "orpheus is the sixth guest on day 2")
	_check(_db.get_scheduled_case(5, 5) == "", "the old day 5 story slot is gone")
	_check(_db.get_scheduled_case(2, 1) == "", "day 2 slot 1 is not a story slot")
	_check_cues("wukong")
	_check_cues("orpheus")

	_check_wukong_data()
	_check_wukong_paths()
	_check_orpheus_data()
	_check_orpheus_paths()
	_check_speaker_aliases()

	if _failures == 0:
		print("StoryContent: %d checks, 0 failures" % _checks)
	else:
		print("StoryContent: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_wukong_data() -> void:
	var data: Dictionary = _db.get_case("wukong")
	_check(str(data.get("entry", "")) == "arrival", "wukong entry is arrival")
	_check(not bool(data.get("requires_stats", true)), "wukong does not use the stat gate")
	_check(data.has("potion"), "wukong has a potion rule")
	_check(data.has("callout"), "wukong has a typed callout")
	_check(str(data.get("queue_name", "")) == "史密斯", "wukong queue name hides the monkey")
	_check(str(data.get("callout", {}).get("answer", "")) == "SUNWUKONG", "wukong callout answer is SUNWUKONG")
	_check(str(data.get("callout", {}).get("success", "")) == "identify", "wukong callout success goes to identify")
	_check(str(data.get("callout", {}).get("failure", "")) == "inspect", "wukong callout failure returns to the hub")
	_check(str(data.get("portrait", {}).get("default", "")) == "wukong_disguise", "wukong default portrait is the disguise")
	_check_all_text_keys(data)
	_check_potion_scores(data, -1, 1, 1, "火气")


func _check_wukong_paths() -> void:
	# 1. No clues, no potion, admit: default rage is true.
	var path1 = _new_path("wukong")
	_settle(path1["runtime"])
	var wukong_choices: Array = path1["runtime"].visible_choices()
	_check(_choice_kind(wukong_choices, "admit") == "accept", "wukong accept choice is marked")
	_check(_choice_kind(wukong_choices, "refuse") == "refuse", "wukong refuse choice is marked")
	_check(_choice_kind(wukong_choices, "photo") == "", "wukong clues stay normal choices")
	_choose(path1["runtime"], "admit")
	_settle(path1["runtime"])
	_check(path1["runtime"].is_closed(), "wukong admit path closes")
	_check(path1["runtime"].get_outcome_id() == "admitted", "wukong default admit outcome")
	_check(str(path1["runtime"].get_outcome().get("result", "")) == "release", "wukong admit releases")
	_check(bool(path1["state"].world["world.hades_rampage"]), "wukong admit sets hades rampage")
	_check(bool(path1["state"].world["world.wukong_admitted"]), "wukong admit records admission")
	_check(bool(path1["state"].world["world.wukong_case_seen"]), "wukong canon records the case")
	_check(str(path1["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "史密斯", "wukong unnamed ledger keeps the disguise")
	_check(_ending_id(path1["state"]) == "hades_rampage", "wukong default ending is rampage")

	# 2. Callout success, then refuse: named ledger + rampage.
	var path2 = _new_path("wukong")
	_settle(path2["runtime"])
	var callout: Dictionary = path2["runtime"].start_callout()
	_check(not callout.is_empty(), "wukong callout starts")
	_check(not path2["runtime"].can_callout(), "wukong callout cannot start twice")
	_check(not path2["runtime"].advance(), "wukong advance is blocked during callout")
	_check(not path2["runtime"].choose("photo"), "wukong choices are blocked during callout")
	_check(not path2["runtime"].can_feed_potion(), "wukong potion is blocked during callout")
	_check(path2["runtime"].resolve_callout(true), "wukong callout resolves")
	_settle(path2["runtime"])
	_check(bool(path2["runtime"].flags["named"]), "wukong callout success sets named")
	_check(bool(path2["runtime"].flags["callout.done"]), "wukong callout marks itself done")
	_check(not path2["runtime"].can_callout(), "wukong called-out name hides the button")
	_check(path2["runtime"].get_portrait_id() == "wukong_monkey", "wukong portrait follows the named flag")
	_choose(path2["runtime"], "refuse")
	_settle(path2["runtime"])
	_check(path2["runtime"].get_outcome_id() == "refused", "wukong named refusal outcome")
	_check(bool(path2["state"].world["world.hades_rampage"]), "wukong named refusal still rampages")
	_check(bool(path2["state"].history["case.wukong.named"]), "wukong case snapshot keeps named")
	_check(str(path2["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "孙悟空", "wukong named ledger records the real name")
	var lines := _ending_lines(path2["state"])
	_check(_contains(lines, "孙悟空"), "wukong named epilogue mentions the real name")

	# 3. Calming potion ends the case before accept/refuse.
	var path3 = _new_path("wukong")
	_settle(path3["runtime"])
	_check(path3["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "wukong calming potion accepted")
	_settle(path3["runtime"])
	_check(path3["runtime"].is_closed(), "wukong calming potion closes the case")
	_check(path3["runtime"].get_outcome_id() == "calm", "wukong calming potion uses the calm outcome")
	_check(str(path3["runtime"].get_outcome().get("result", "")) == "leave", "wukong calm outcome leaves")
	_check(not bool(path3["state"].world["world.hades_rampage"]), "wukong calm outcome avoids rampage")
	_check(not bool(path3["state"].world["world.wukong_admitted"]), "wukong calm outcome does not admit")
	_check(str(path3["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "史密斯", "wukong calm unnamed ledger keeps the disguise")
	_check(_ending_id(path3["state"]) == "quiet_shift", "wukong calm ending is quiet")

	# 3b. A zero score is non-positive, so the guest leaves.
	var path3b = _new_path("wukong")
	_settle(path3b["runtime"])
	_check(path3b["runtime"].feed_potion(Vector3i(1, 0, 1), "灰鳞原液"), "wukong zero-score potion accepted")
	_settle(path3b["runtime"])
	_check(path3b["runtime"].is_closed(), "wukong zero score closes the case")
	_check(path3b["runtime"].get_outcome_id() == "calm", "wukong zero score uses the calm outcome")

	# 4. Callout failure returns to the hub, and can be retried.
	var path4 = _new_path("wukong")
	_settle(path4["runtime"])
	path4["runtime"].start_callout()
	_check(path4["runtime"].resolve_callout(false), "wukong callout failure resolves")
	_settle(path4["runtime"])
	_check(not bool(path4["runtime"].flags.get("callout.done", false)), "wukong failed callout can retry")
	_check(path4["runtime"].can_callout(), "wukong callout button returns after failure")
	path4["runtime"].start_callout()
	path4["runtime"].resolve_callout(true)
	_settle(path4["runtime"])
	_check(bool(path4["runtime"].flags["named"]), "wukong retry can identify him")

	# 5. Hot potion keeps rage; second potion is refused.
	var path5 = _new_path("wukong")
	_settle(path5["runtime"])
	_check(path5["runtime"].feed_potion(Vector3i(0, 4, 0), "暖心药"), "wukong hot potion accepted")
	_settle(path5["runtime"])
	_check(bool(path5["runtime"].flags["rage"]), "wukong hot potion keeps rage")
	_check(not path5["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "wukong only one potion per visit")
	_choose(path5["runtime"], "admit")
	_settle(path5["runtime"])
	_check(path5["runtime"].get_outcome_id() == "admitted", "wukong hot potion admit outcome")

	# 6. Default refusal still rampages.
	var path6 = _new_path("wukong")
	_settle(path6["runtime"])
	_choose(path6["runtime"], "refuse")
	_settle(path6["runtime"])
	_check(path6["runtime"].get_outcome_id() == "refused", "wukong default refusal outcome")
	_check(bool(path6["state"].world["world.hades_rampage"]), "wukong default refusal still sets hades rampage")


func _check_orpheus_data() -> void:
	var data: Dictionary = _db.get_case("orpheus")
	_check(str(data.get("entry", "")) == "arrival", "orpheus entry is arrival")
	_check(not bool(data.get("requires_stats", true)), "orpheus does not use the stat gate")
	_check(str(data.get("queue_name", "")) == "亚历克斯", "orpheus queue name is the alias")
	_check(str(data.get("callout", {}).get("answer", "")) == "ORPHEUS", "orpheus callout answer is ORPHEUS")
	_check(str(data.get("callout", {}).get("success", "")) == "identify", "orpheus callout success goes to identify")
	_check(str(data.get("callout", {}).get("failure", "")) == "inspect", "orpheus callout failure returns to the hub")
	_check(str(data.get("portrait", {}).get("default", "")) == "orpheus_front", "orpheus arrives in the hooded portrait")
	_check_all_text_keys(data)
	_check_potion_scores(data, -1, 1, -1, "迷茫")
	_check(int(data.state.flags["confused"].get("default", -1)) == 1, "orpheus starts confused")
	_check(int(data.state.flags["clue.registry"].get("default", -1)) == 0, "orpheus starts without a registry clue")


func _check_orpheus_paths() -> void:
	# 1. No potion (score 1) + accept: he still looks back.
	var path1 = _new_path("orpheus")
	_settle(path1["runtime"])
	var orpheus_choices: Array = path1["runtime"].visible_choices()
	_check(_choice_kind(orpheus_choices, "admit") == "accept", "orpheus accept choice is marked")
	_check(_choice_kind(orpheus_choices, "refuse") == "refuse", "orpheus refuse choice is marked")
	_check(_choice_kind(orpheus_choices, "registry") == "", "orpheus clues stay normal choices")
	_choose(path1["runtime"], "admit")
	_check(_aftermath_text(path1["runtime"]).contains("伪装成亡灵"), "orpheus unnamed aftermath hides the real name")
	_check(not _aftermath_text(path1["runtime"]).contains("俄耳甫斯转世"), "orpheus unnamed aftermath omits the bracket text")
	_check(not _aftermath_text(path1["runtime"]).contains("{{"), "orpheus inline tags are rendered away")
	_settle(path1["runtime"])
	_check(path1["runtime"].is_closed(), "orpheus default accept closes")
	_check(path1["runtime"].get_outcome_id() == "accepted.confused", "orpheus default accept is confused")
	_check(bool(path1["runtime"].flags["confused"]), "orpheus default potion score is positive")
	_check(bool(path1["state"].world["world.orpheus_admitted"]), "orpheus default accept admits")
	_check(not bool(path1["state"].world["world.orpheus_reunion"]), "orpheus default accept loses her")
	_check(bool(path1["state"].world["world.orpheus_lost"]), "orpheus default accept records the loss")
	_check(bool(path1["state"].world["world.orpheus_case_seen"]), "orpheus canon records the case")
	_check(str(path1["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "亚历克斯", "orpheus unnamed ledger keeps the alias")
	_check(_ending_id(path1["state"]) == "quiet_shift", "orpheus default ending is quiet")

	# 2. Clear potion + accept, no monkey rampage: she is still taken.
	var path2 = _new_path("orpheus")
	_settle(path2["runtime"])
	_check(path2["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "orpheus clear potion accepted")
	_settle(path2["runtime"])
	_check(not bool(path2["runtime"].flags["confused"]), "orpheus clear potion removes confusion")
	_choose(path2["runtime"], "admit")
	_settle(path2["runtime"])
	_check(path2["runtime"].get_outcome_id() == "accepted.clear", "orpheus clear accept outcome")
	_check(not bool(path2["state"].world["world.orpheus_reunion"]), "orpheus clear accept without rampage loses her")
	_check(bool(path2["state"].world["world.orpheus_lost"]), "orpheus clear accept records the loss")
	_check(_ending_id(path2["state"]) == "quiet_shift", "orpheus clear ending is quiet")

	# 3. Clear potion + accept + monkey rampage: the monkey breaks the hand.
	var path3 = _new_path("orpheus", true)
	_settle(path3["runtime"])
	_check(path3["runtime"].feed_potion(Vector3i(10, 0, -4), "极识药"), "orpheus reunion potion accepted")
	_settle(path3["runtime"])
	_choose(path3["runtime"], "admit")
	_check(_aftermath_text(path3["runtime"]).contains("伪装成亡灵"), "orpheus reunion unnamed aftermath still hides the name")
	_check(_aftermath_text(path3["runtime"]).contains("猴子"), "orpheus reunion aftermath keeps the monkey rescue")
	_settle(path3["runtime"])
	_check(path3["runtime"].get_outcome_id() == "accepted.reunion", "orpheus reunion outcome")
	_check(bool(path3["state"].world["world.orpheus_reunion"]), "orpheus reunion flag is set")
	_check(not bool(path3["state"].world["world.orpheus_lost"]), "orpheus reunion clears the loss")
	_check(_ending_id(path3["state"]) == "hades_rampage", "orpheus reunion keeps the rampage ending")

	# 4. Rejection, with the real name called out.
	var path4 = _new_path("orpheus")
	_settle(path4["runtime"])
	var callout: Dictionary = path4["runtime"].start_callout()
	_check(str(callout.get("answer", "")) == "ORPHEUS", "orpheus callout reports ORPHEUS")
	_check(path4["runtime"].resolve_callout(true), "orpheus callout succeeds")
	_settle(path4["runtime"])
	_check(bool(path4["runtime"].flags["named"]), "orpheus callout sets named")
	_choose(path4["runtime"], "refuse")
	_settle(path4["runtime"])
	_check(path4["runtime"].get_outcome_id() == "refused", "orpheus refusal outcome")
	_check(not bool(path4["state"].world["world.orpheus_admitted"]), "orpheus refusal does not admit")
	_check(not bool(path4["state"].world["world.orpheus_reunion"]), "orpheus refusal has no reunion")
	_check(str(path4["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "俄耳甫斯", "orpheus named ledger records the real name")
	_check(str(path4["runtime"].get_outcome().get("ledger", {}).get("result", "")) == "未入境", "orpheus refusal ledger result")

	# 5. A zero score is non-positive.
	var path5 = _new_path("orpheus")
	_settle(path5["runtime"])
	_check(path5["runtime"].feed_potion(Vector3i(1, 0, -1), "零值药"), "orpheus zero-score potion accepted")
	_settle(path5["runtime"])
	_check(int(path5["runtime"].flags["dose.score"]) == 0, "orpheus zero score is preserved")
	_check(not bool(path5["runtime"].flags["confused"]), "orpheus zero score is clear-headed")
	_choose(path5["runtime"], "admit")
	_settle(path5["runtime"])
	_check(path5["runtime"].get_outcome_id() == "accepted.clear", "orpheus zero score uses the clear outcome")

	# 6. Named accept includes the bracket text.
	var path6 = _new_path("orpheus")
	_settle(path6["runtime"])
	path6["runtime"].start_callout()
	path6["runtime"].resolve_callout(true)
	_settle(path6["runtime"])
	_choose(path6["runtime"], "admit")
	_check(_aftermath_text(path6["runtime"]).contains("俄耳甫斯转世"), "orpheus named aftermath shows the real name")
	_settle(path6["runtime"])
	_check(str(path6["runtime"].get_outcome().get("ledger", {}).get("who", "")) == "俄耳甫斯", "orpheus named accept ledger")

	# 7. The registry look is a one-time charmed action.
	var path7 = _new_path("orpheus")
	_settle(path7["runtime"])
	_choose(path7["runtime"], "registry")
	_check(path7["runtime"].get_node_id() == "inspect.registry", "orpheus registry node")
	_check(path7["runtime"].advance(), "orpheus registry narration advances")
	_check(_current_text(path7["runtime"]).contains("身份没问题"), "orpheus registry look is charmed")
	_settle(path7["runtime"])
	_check(int(path7["runtime"].flags["clue.registry"]) == 1, "orpheus registry clue is set")
	_check(_has_choice(path7["runtime"], "registry"), "orpheus registry choice stays visible")
	_check(_choice_locked(path7["runtime"].visible_choices(), "registry"), "orpheus registry choice is grayed out")
	_check(_has_choice(path7["runtime"], "eurydice"), "orpheus can still ask about Eurydice")

	# 7b. A used Wukong clue stays visible and disabled.
	var path7b = _new_path("wukong")
	_settle(path7b["runtime"])
	_choose(path7b["runtime"], "photo")
	_settle(path7b["runtime"])
	_check(_has_choice(path7b["runtime"], "photo"), "wukong used clue stays visible")
	_check(_choice_locked(path7b["runtime"].visible_choices(), "photo"), "wukong used clue is grayed out")
	_check(not _choice_locked(path7b["runtime"].visible_choices(), "tail"), "wukong unused clue stays enabled")

	# 8. Callout failure returns to the hub and can be retried.
	var path8 = _new_path("orpheus")
	_settle(path8["runtime"])
	path8["runtime"].start_callout()
	_check(path8["runtime"].resolve_callout(false), "orpheus callout failure resolves")
	_settle(path8["runtime"])
	_check(not bool(path8["runtime"].flags.get("callout.done", false)), "orpheus failed callout can retry")
	_check(path8["runtime"].can_callout(), "orpheus callout returns after failure")


func _check_speaker_aliases() -> void:
	var wukong = _new_path("wukong")
	_check(str(wukong["runtime"].current_step().get("speaker_name", "")) == "史密斯", "wukong speaks as the alias before the callout")
	_check(wukong["runtime"].steps.size() == 1, "wukong arrival contains one greeting")
	_settle(wukong["runtime"])
	wukong["runtime"].start_callout()
	wukong["runtime"].resolve_callout(true)
	_settle(wukong["runtime"])
	_choose(wukong["runtime"], "photo")
	_check(wukong["runtime"].advance(), "wukong photo advances to the speaker")
	_check(str(wukong["runtime"].current_step().get("speaker_name", "")) == "孙悟空", "wukong speaks as the real name after the callout")

	var orpheus = _new_path("orpheus")
	_check(str(orpheus["runtime"].current_step().get("speaker_name", "")) == "亚历克斯", "orpheus speaks as the alias before the callout")
	_check(orpheus["runtime"].steps.size() == 1, "orpheus arrival contains one greeting")
	_settle(orpheus["runtime"])
	orpheus["runtime"].start_callout()
	orpheus["runtime"].resolve_callout(true)
	_check(orpheus["runtime"].get_portrait_id() == "orpheus_revealed", "orpheus's true name reveals his face")
	_settle(orpheus["runtime"])
	_choose(orpheus["runtime"], "eurydice")
	_check(str(orpheus["runtime"].current_step().get("speaker_name", "")) == "俄耳甫斯", "orpheus speaks as the real name after the callout")


func _check_cues(case_id: String) -> void:
	var data: Dictionary = _db.get_case(case_id)
	var cue_steps := 0
	var cue_count := 0
	for node in data.get("nodes", []):
		for step in node.get("steps", []):
			var cues: Array = step.get("cues", [])
			if cues.is_empty():
				continue
			cue_steps += 1
			cue_count += cues.size()
			for cue in cues:
				_check(Catalog.has_type(str(cue.get("type", ""))), "%s cue type is declared" % case_id)
				if str(cue.get("type", "")) == "prop":
					_check(Catalog.has_prop(str(cue.get("id", ""))), "%s prop is declared" % case_id)
				if str(cue.get("type", "")) == "sprite":
					_check(Catalog.has_sprite(str(cue.get("id", ""))), "%s sprite is declared" % case_id)
	_check(cue_steps >= 6, "%s has cue coverage on its action steps" % case_id)
	_check(cue_count >= cue_steps, "%s cue arrays carry actions" % case_id)


func _new_path(case_id: String, rampage: bool = false) -> Dictionary:
	var state = State.new()
	state.init_defaults(_db.world_decl)
	state.world["world.hades_rampage"] = rampage
	var runtime = Runtime.new()
	runtime.setup(_db.get_case(case_id), _db.text, state)
	runtime.start()
	return {"runtime": runtime, "state": state}


func _settle(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 60:
		if not runtime.advance():
			break
		guard += 1


func _choose(runtime, id: String) -> void:
	_check(runtime.choose(id), "choice %s succeeds" % id)


func _has_choice(runtime, id: String) -> bool:
	for choice in runtime.visible_choices():
		if str(choice.get("id", "")) == id:
			return true
	return false


func _choice_locked(choices: Array, id: String) -> bool:
	for choice in choices:
		if str(choice.get("id", "")) == id:
			return bool(choice.get("locked", false))
	return false


func _choice_kind(choices: Array, id: String) -> String:
	for choice in choices:
		if str(choice.get("id", "")) == id:
			return str(choice.get("kind", ""))
	return ""


func _aftermath_text(runtime) -> String:
	return "
".join(runtime.get_aftermath_lines())


func _current_text(runtime) -> String:
	return str(runtime.current_step().get("text", ""))


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
		if str(callout.get("prompt", "")) != "":
			_check(_db.text.has(str(callout.get("prompt", ""))), "callout prompt text exists")
		if str(callout.get("button", "")) != "":
			_check(_db.text.has(str(callout.get("button", ""))), "callout button text exists")


func _check_potion_scores(data: Dictionary, wisdom: int, emotion: int, will: int, score_name: String) -> void:
	var potion: Dictionary = data.get("potion", {})
	var coefficients: Dictionary = potion.get("score", {})
	_check(int(coefficients.get("wisdom", 0)) == wisdom, "wisdom coefficient")
	_check(int(coefficients.get("emotion", 0)) == emotion, "emotion coefficient")
	_check(int(coefficients.get("will", 0)) == will, "will coefficient")
	_check(str(potion.get("score_name", "")) == score_name, "score name is %s" % score_name)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
