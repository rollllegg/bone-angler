extends SceneTree
## Headless checks for the story runtime using a small fixture case.

const Runtime := preload("res://scripts/story/story_runtime.gd")
const State := preload("res://scripts/story/story_state.gd")
const TextDB := preload("res://scripts/story/story_text.gd")

var _checks := 0
var _failures := 0
var _closed_id := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = _state()
	var text = _text()
	var runtime = _runtime(state, text)
	runtime.case_closed.connect(func(id: String) -> void: _closed_id = id)
	_check(runtime.start(), "case starts")
	_check(runtime.get_score_name() == "火气", "score name comes from the case")
	_settle(runtime)
	_check(runtime.current_step().get("text", "") == "hub", "arrives at hub")
	var choices := _ids(runtime.visible_choices())
	_check(choices.has("look") and choices.has("end"), "hub offers look and end")
	_check(not choices.has("name"), "name is hidden before a clue")

	_check(runtime.choose("look"), "choosing look succeeds")
	_settle(runtime)
	_check(int(runtime.flags["seen"]) == 1, "look sets seen")
	choices = _ids(runtime.visible_choices())
	_check(choices.has("name"), "clue unlocks the name choice")

	var snapshot: Dictionary = runtime.snapshot()
	var restored = _runtime(state, text)
	_check(restored.restore(snapshot), "snapshot restores")
	_check(int(restored.flags["seen"]) == 1, "restored flags keep seen")
	_check(restored.current_step().get("text", "") == "hub", "restored node is hub")

	_check(runtime.choose("name"), "choosing name succeeds")
	_settle(runtime)
	_check(bool(runtime.flags["named"]), "name sets named")
	_check(runtime.current_step().get("text", "") == "hub!", "inline text follows the named flag")
	var named_choices: Array = runtime.visible_choices()
	_check(_choice_text(named_choices, "end") == "end!", "choice text renders inline conditions")
	_check(runtime.can_feed_potion(), "potion can be offered once")
	_check(runtime.feed_potion(Vector3i(10, 0, -4), "极识药"), "calming potion feeds")
	_settle(runtime)
	_check(int(runtime.flags["dose.score"]) == -14, "potion score is computed")
	_check(not bool(runtime.flags["rage"]), "negative score calms the guest")
	_check(not runtime.can_feed_potion(), "second potion is refused")

	_check(runtime.choose("end"), "choosing end succeeds")
	_settle(runtime)
	_check(runtime.is_closed(), "case closes")
	_check(runtime.get_outcome_id() == "done", "outcome is done")
	_check(_closed_id == "done", "case_closed signal fires")
	_check(bool(state.world["world.flag"]), "world effect applied")
	_check(bool(state.history["case.fixture.named"]), "case snapshot keeps named")
	_check(state.history["case.fixture.outcome"] == "done", "case snapshot keeps outcome")

	var other_state = _state()
	var other = _runtime(other_state, text)
	other.start()
	_settle(other)
	other.choose("look")
	_settle(other)
	other.feed_potion(Vector3i(0, 4, 0), "暖心药")
	_settle(other)
	_check(bool(other.flags["rage"]), "positive score keeps the guest hot")
	other.choose("end")
	_settle(other)
	_check(other.is_closed() and other.get_outcome_id() == "done", "second path closes")

	if _failures == 0:
		print("StoryRuntime: %d checks, 0 failures" % _checks)
	else:
		print("StoryRuntime: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _settle(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 50:
		if not runtime.advance():
			break
		guard += 1


func _ids(choices: Array) -> Array:
	var result: Array = []
	for choice in choices:
		if not choice.get("locked", false):
			result.append(choice.get("id", ""))
	return result


func _choice_text(choices: Array, id: String) -> String:
	for choice in choices:
		if str(choice.get("id", "")) == id:
			return str(choice.get("text", ""))
	return ""


func _state():
	var state = State.new()
	state.init_defaults({"world.flag": {"type": "bool", "default": false}})
	return state


func _text():
	var text = TextDB.new()
	text.entries = {
		"f.start.1": "start",
		"f.hub.1": "hub{{if named}}!{{/if}}",
		"f.choice.look": "look",
		"f.choice.name": "name",
		"f.choice.end": "end{{if named}}!{{/if}}",
		"f.look.1": "look result",
		"f.name.1": "name result",
		"f.potion.1": "potion result",
		"f.finish.1": "finish",
		"f.ledger": "ledger",
	}
	return text


func _runtime(state, text):
	var data := {
		"id": "fixture",
		"entry": "start",
		"speakers": {"A": {"name": "甲"}, "B": {"name": "乙"}},
		"state": {"flags": {
			"seen": {"type": "int", "default": 0},
			"named": {"type": "bool", "default": false},
			"rage": {"type": "bool", "default": true},
			"dose.fed": {"type": "bool", "default": false},
			"dose.score": {"type": "int", "default": 0},
		}},
		"potion": {"score": {"wisdom": -1, "emotion": 1, "will": 1}, "score_name": "火气", "node": "potion"},
		"nodes": [
			{"id": "start", "steps": [{"speaker": "A", "text": "f.start.1"}], "next": "hub"},
			{"id": "hub", "steps": [{"text": "f.hub.1"}], "choices": [
				{"id": "look", "text": "f.choice.look", "if": "seen == 0", "set": ["seen = 1"], "next": "look"},
				{"id": "name", "text": "f.choice.name", "if": "seen >= 1 && !named", "next": "name"},
				{"id": "end", "text": "f.choice.end", "next": "finish"},
			]},
			{"id": "look", "steps": [{"speaker": "B", "text": "f.look.1"}], "next": "hub"},
			{"id": "name", "steps": [{"speaker": "A", "text": "f.name.1"}], "set": ["named = true"], "next": "hub"},
			{"id": "potion", "steps": [{"text": "f.potion.1"}], "branch": [
				{"if": "dose.score >= 0", "set": ["rage = true"], "next": "hub"},
				{"if": "dose.score < 0", "set": ["rage = false"], "next": "hub"},
			], "next": "hub"},
			{"id": "finish", "steps": [{"text": "f.finish.1"}], "outcome": "done"},
		],
		"outcomes": {"done": {
			"result": "release",
			"effects": ["world.flag = true"],
			"ledger": {"who": "甲", "result": "放行", "note": "f.ledger"},
		}},
	}
	var runtime = Runtime.new()
	runtime.setup(data, text, state)
	return runtime


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
