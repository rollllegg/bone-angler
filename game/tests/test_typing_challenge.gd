extends SceneTree
## Headless checks for the reusable typing challenge and letter bubbles.

const TypingChallenge := preload("res://scripts/systems/typing_challenge.gd")
const LetterBubbleRow := preload("res://scripts/demo/letter_bubble_row.gd")

var _checks := 0
var _failures := 0
var _completed := ""
var _missed := false
var _timed_out := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var typing = TypingChallenge.new()
	root.add_child(typing)
	typing.completed.connect(func(target: String) -> void: _completed = target)
	typing.missed.connect(func(_received: String, _expected: String) -> void: _missed = true)
	typing.timed_out.connect(func() -> void: _timed_out = true)

	typing.start("sunwukong", 10.0)
	_check(typing.target == "SUNWUKONG", "target is uppercased")
	_check(typing.typed_count == 0 and typing.active, "nothing is typed or revealed at start")
	_check(typing.submit_character("s"), "lowercase input matches")
	_check(typing.typed_count == 1, "one letter typed")
	typing.tick(0.25)
	_check(typing.typed_count == 1, "time passing does not reveal the next letter")
	for index in range(1, "SUNWUKONG".length()):
		typing.submit_character("SUNWUKONG".substr(index, 1))
	_check(_completed == "SUNWUKONG" and not typing.active, "completion fires once")

	_completed = ""
	_missed = false
	typing.start("AB", 0.0)
	typing.submit_character("A")
	_check(not typing.submit_character("X"), "wrong letter is rejected")
	_check(typing.typed_count == 0 and typing.mistakes == 1, "wrong letter resets the word")
	_check(_missed, "miss signal fires")
	typing.submit_character("A")
	typing.submit_character("B")
	_check(_completed == "AB", "retry can complete")

	_timed_out = false
	typing.start("AB", 1.0)
	typing.tick(0.5)
	_check(typing.time_left == 0.5 and typing.active, "timer counts down")
	typing.tick(0.6)
	_check(_timed_out and not typing.active, "timer fires timeout")
	typing.stop()

	var row = LetterBubbleRow.new()
	row.position = Vector2.ZERO
	row.size = Vector2(530, 64)
	root.add_child(row)
	row.setup(56.0, 24.0)
	row.render("SUNWUKONG", 0)
	_check(row.get_child_count() == 9, "nine bubbles for SUNWUKONG")
	_check(_letter(row, 0) == "·", "target letters stay hidden before typing")
	row.render("SUNWUKONG", 1)
	_check(_letter(row, 0) == "S" and _letter(row, 1) == "·", "only typed letters are shown")
	row.render("SUNWUKONG", 3)
	_check(_letter(row, 0) == "S" and _letter(row, 1) == "U" and _letter(row, 2) == "N", "typed letters stay visible")
	row.render("ORPHEUS", 0)
	_check(row.get_child_count() == 7 and _letter(row, 0) == "·", "row rebuilds for a new hidden word")

	if _failures == 0:
		print("TypingComponents: %d checks, 0 failures" % _checks)
	else:
		print("TypingComponents: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _letter(row, index: int) -> String:
	var bubble := row.get_child(index) as PanelContainer
	if bubble == null or bubble.get_child_count() == 0:
		return ""
	return str((bubble.get_child(0) as Label).text)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
