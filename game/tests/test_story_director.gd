extends SceneTree
## Verifies cue timing, blocking, conditions and skip semantics without a scene.

const Director := preload("res://scripts/story/story_director.gd")
const Catalog := preload("res://scripts/story/story_cue_catalog.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Catalog.PROP_IDS.size() == 8, "eight placeholder props are declared")
	_check(Catalog.has_prop("lyre") and Catalog.has_prop("gray_hand"), "prop catalog contains the story props")
	_check(not Catalog.has_prop("dragon"), "unknown props are rejected")

	_test_empty()
	_test_blocking()
	_test_parallel()
	_test_condition()
	_test_delay()
	_test_skip()
	_test_replace()

	if _failures == 0:
		print("StoryDirector: %d checks, 0 failures" % _checks)
	else:
		print("StoryDirector: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_empty() -> void:
	var stage := FakeStage.new()
	var director := Director.new()
	director.set_stage(stage)
	var events: Array = []
	director.finished.connect(func(key: String) -> void: events.append(key))
	director.play("empty", [], {})
	_check(not director.is_playing(), "empty cue list is not playing")
	_check(not director.blocks_advance(), "empty cue list does not block")
	_check(events == ["empty"], "empty cue list still reports finished")
	_check(stage.began.is_empty(), "empty cue list starts no cue")


func _test_blocking() -> void:
	var stage := FakeStage.new()
	var director := Director.new()
	director.set_stage(stage)
	var events: Array = []
	director.started.connect(func(key: String) -> void: events.append("started:" + key))
	director.finished.connect(func(key: String) -> void: events.append("done:" + key))
	director.play("blocking", [
		{"type": "shake", "strength": 4, "duration": 0.5, "wait": true},
	], {})
	_check(director.is_playing(), "blocking cue starts playing")
	_check(director.blocks_advance(), "wait cue blocks text")
	_check(stage.began.size() == 1, "blocking cue reaches the stage")
	director.tick(0.2)
	_check(director.is_playing(), "blocking cue still plays before its duration")
	_check(stage.finished.is_empty(), "blocking cue is not settled early")
	director.tick(0.31)
	_check(not director.is_playing(), "blocking cue finishes after its duration")
	_check(not director.blocks_advance(), "finished cue no longer blocks")
	_check(stage.finished.size() == 1, "blocking cue settles on the stage")
	_check(events == ["started:blocking", "done:blocking"], "blocking cue emits started then finished")


func _test_parallel() -> void:
	var stage := FakeStage.new()
	var director := Director.new()
	director.set_stage(stage)
	director.play("parallel", [
		{"type": "flash", "color": "#ffffff", "duration": 0.6},
		{"type": "prop", "id": "lyre", "action": "show"},
	], {})
	_check(not director.is_playing(), "non-blocking cues finish as soon as they start")
	_check(not director.blocks_advance(), "non-blocking cues never block text")
	_check(stage.began.size() == 2, "both non-blocking cues reach the stage")
	_check(stage.finished.size() == 1, "zero-duration prop settles immediately")
	director.tick(1.0)
	_check(stage.finished.size() == 1, "finished director stops ticking")


func _test_condition() -> void:
	var stage := FakeStage.new()
	var director := Director.new()
	director.set_stage(stage)
	director.play("condition", [
		{"type": "flash", "if": "named", "duration": 0.2},
	], {"named": false})
	_check(stage.began.is_empty(), "false condition skips the cue")
	director.play("condition", [
		{"type": "flash", "if": "named", "duration": 0.2},
	], {"named": true})
	_check(stage.began.size() == 1, "true condition runs the cue")


func _test_delay() -> void:
	var stage := FakeStage.new()
	var director := Director.new()
	director.set_stage(stage)
	director.play("delay", [
		{"type": "prop", "id": "coins", "action": "show", "delay": 0.4},
	], {})
	_check(stage.began.is_empty(), "delayed cue waits before starting")
	_check(director.is_playing(), "delayed cue keeps the director alive")
	_check(not director.blocks_advance(), "delayed non-blocking cue does not block text")
	director.tick(0.2)
	_check(stage.began.is_empty(), "delayed cue still waits")
	director.tick(0.3)
	_check(stage.began.size() == 1, "delayed cue starts after its delay")
	_check(not director.is_playing(), "delayed cue releases the director")


func _test_skip() -> void:
	var stage := FakeStage.new()
	var director := Director.new()
	director.set_stage(stage)
	var events: Array = []
	director.skipped.connect(func(key: String) -> void: events.append("skipped:" + key))
	director.finished.connect(func(key: String) -> void: events.append("done:" + key))
	director.play("skip", [
		{"type": "shake", "strength": 6, "duration": 1.0, "wait": true},
		{"type": "prop", "id": "staff", "action": "show", "delay": 0.6},
	], {})
	director.tick(0.2)
	director.skip()
	_check(not director.is_playing(), "skip stops the director")
	_check(not director.blocks_advance(), "skip releases text")
	_check(stage.began.size() == 2, "skip starts a pending delayed cue")
	_check(stage.finished.size() == 2, "skip settles every cue")
	_check(events == ["skipped:skip", "done:skip"], "skip emits skipped then finished")


func _test_replace() -> void:
	var stage := FakeStage.new()
	var director := Director.new()
	director.set_stage(stage)
	director.play("first", [
		{"type": "shake", "strength": 6, "duration": 1.0, "wait": true},
	], {})
	director.tick(0.1)
	director.play("second", [
		{"type": "flash", "color": "#ffffff", "duration": 0.2},
	], {})
	_check(stage.finished.size() == 1, "a new step settles the previous cue")
	_check(stage.began.size() == 2, "a new step starts its own cue")
	_check(not director.is_playing(), "a non-blocking new step completes immediately")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)


class FakeStage:
	var began: Array = []
	var finished: Array = []

	func begin_cue(cue: Dictionary, duration: float) -> void:
		began.append({"cue": cue.duplicate(true), "duration": duration})

	func finish_cue(cue: Dictionary) -> void:
		finished.append(cue.duplicate(true))
