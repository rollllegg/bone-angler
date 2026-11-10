extends SceneTree
## Run: Godot --headless --path game --script res://tests/test_fishing_qte.gd

var _failures: int = 0
var _checks: int = 0
var _completed: Array[String] = []
var _misses: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var practice := preload("res://scenes/fishing/fishing_practice.tscn").instantiate()
	root.add_child(practice)
	root.size = Vector2i(1280, 720)
	await process_frame
	var qte := practice.get_node("FishingQTE") as FishingQTE
	qte.set_process(false)
	qte.word_completed.connect(func(word: String, _score: int) -> void: _completed.append(word))
	qte.input_missed.connect(func(_received: String, _expected: String) -> void: _misses += 1)

	_check(qte.current_word == "FISH" and qte.revealed_count == 1, "Only the first letter is revealed at start")
	await _capture("01-initial")
	_send_key("f")
	_check(qte.typed_count == 1 and qte.revealed_count == 1, "Lowercase keyboard input advances before the next hint")
	qte.advance_hint(0.19)
	_check(qte.revealed_count == 1, "Hint remains hidden before its delay")
	qte.advance_hint(0.02)
	_check(qte.revealed_count == 2, "Next letter appears after the configured delay")
	await _capture("02-next-hint")
	_send_key("I")
	_send_key("S")
	_send_key("H")
	_check(qte.score == 1 and _completed == ["FISH"], "Unrevealed letters complete a word and award exactly one point")
	_check(qte.current_word == "BONE" and qte.typed_count == 0 and qte.revealed_count == 1, "Completion immediately starts the next word")
	await _capture("03-scored")

	# Deliberately no frame or timer waits: all eight characters arrive together.
	for character in "BONESOUL":
		_send_key(character)
	_check(qte.score == 3 and qte.current_word == "RIVER", "A same-frame burst crosses word boundaries without losing keys")
	_send_key("R")
	_send_key("I")
	_send_key("X")
	_check(_misses == 1 and qte.typed_count == 0 and qte.revealed_count == 1, "A hidden-letter mismatch resets progress and hints")
	_check(qte.score == 3 and qte.current_word == "RIVER", "Mistakes preserve the score and current word")
	qte.advance_hint(5.0)
	_check(qte.revealed_count == 1, "Old reveal clocks cannot leak into a reset attempt")
	await _capture("04-mistake")
	for character in "RIVERSHIFT":
		_send_key(character)
	_check(qte.score == 5 and qte.current_word == "FISH", "Retry completes normally and the bank loops")

	practice.get_node("Restart").pressed.emit()
	_check(qte.score == 0 and qte.current_word == "FISH" and qte.typed_count == 0, "Restart button clears the session")
	_send_key("F", true)
	_send_key("F", false, true)
	_send_key("F", false, false, false)
	_send_key(" ")
	_check(qte.typed_count == 0 and _misses == 1, "Hold repeats, shortcuts, releases and nonletters are ignored")
	_send_key("F")
	_send_key("F", true)
	_check(qte.typed_count == 1 and _misses == 1, "OS key repeat cannot reset an attempt")
	_send_key("F")
	_check(qte.typed_count == 0 and _misses == 2, "A separate wrong key press still resets")

	var custom_bank := FishingWordBank.new()
	custom_bank.words = PackedStringArray([" eel ", "A", "invalid1", "", "X-Y"])
	qte.word_bank = custom_bank
	qte.hint_delay = 0.0
	qte.restart_session()
	_send_key("e")
	_check(qte.current_word == "EEL" and qte.revealed_count == 2, "Custom words normalize and a zero delay reveals immediately")
	_send_key("e")
	_send_key("l")
	_send_key("A")
	_check(qte.score == 2 and qte.current_word == "EEL", "Repeated letters, one-letter words and invalid-bank filtering work")
	_check(not qte.submit_letter("EL") and qte.typed_count == 0, "Only one letter per input is accepted")
	custom_bank.words = PackedStringArray()
	qte.restart_session()
	_check(qte.current_word == "FISH", "An empty bank falls back to a playable word")
	qte.word_bank = null
	qte.restart_session()
	_check(qte.current_word == "FISH", "A missing bank also falls back safely")

	practice.queue_free()
	await process_frame
	print("Fishing QTE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _send_key(character: String, echo: bool = false, control: bool = false, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = character.to_upper().unicode_at(0)
	event.physical_keycode = event.keycode
	event.unicode = character.unicode_at(0)
	event.pressed = pressed
	event.echo = echo
	event.ctrl_pressed = control
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var result := root.get_texture().get_image().save_png("res://build/validation/fishing-%s.png" % label)
	_check(result == OK, "Screenshot saved: " + label)
