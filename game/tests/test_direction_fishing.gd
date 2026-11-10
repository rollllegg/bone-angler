extends SceneTree
## Run headless for rules; omit --headless and add -- --capture for visual QA.

var _checks: int = 0
var _failures: int = 0
var _catches: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var screen := main.get_node("DirectionPractice")
	var qte := screen.get_node("DirectionFishing") as DirectionFishing
	_check(qte.random_fish_on_cast, "Normal play encounters a random, hidden fish on each cast")
	qte.random_fish_on_cast = false
	qte.set_process(false)
	qte.fish_caught.connect(func(index: int, _total: int) -> void: _catches.append(index))
	_check(screen.visible and qte.phase == DirectionFishing.Phase.READY, "Direction demo is the default entry")
	_check(not main.get_node("RodPractice").visible and not main.get_node("FishingPractice").visible, "Other modules start inactive")
	_check(not screen.is_fish_revealed() and not screen.is_pull_arrow_visible(), "Ready view contains no fish or pull prompt")
	for entry in screen._discovered_fish:
		_check(entry.text == "未知鱼种    未发现", "Undiscovered fish names are hidden")
	_check(not qte.select_fish(-1) and not qte.select_fish(3), "Invalid fish cannot change the selection")
	await _capture("01-ready")
	_send_key(KEY_W)
	_send_key(KEY_SPACE, true)
	_send_key(KEY_SPACE, false, true)
	_send_key(KEY_SPACE, false, false, false)
	_check(qte.phase == DirectionFishing.Phase.READY and qte.successful_pulls == 0, "Idle direction keys, repeats, shortcuts and releases do nothing")
	_send_key(KEY_SPACE)
	_check(qte.phase == DirectionFishing.Phase.WAITING, "Space casts without also pulling")
	_check(not screen.is_fish_revealed() and not screen.is_pull_arrow_visible(), "Waiting view keeps the fish underwater")
	_check(not qte.cast() and not qte.select_fish(1), "Casting and selection lock during an attempt")
	_send_key(KEY_D)
	_check(qte.mistakes == 0, "Direction presses before the bite are ignored")
	await _capture("02-waiting")
	qte.advance(1.0)
	_check(qte.phase == DirectionFishing.Phase.WAITING, "Casting includes a visible wait for a bite")
	qte.advance(0.3)
	_check(qte.phase == DirectionFishing.Phase.REELING and qte.remaining > qte.get_target_time(), "Bite begins a complete rhythm beat")
	qte.advance(qte.get_target_time() - qte.beat_elapsed)
	for direction in 4:
		qte.fish_direction = direction
		var expected: String = ["S", "D", "W", "A"][direction]
		_check(qte.get_expected_key() == expected, "Prompt is opposite to fish direction %d" % direction)
		qte.state_changed.emit()
		screen._process(1.0)
		_check(screen.get_pull_arrow_direction() == -DirectionFishing.VECTORS[direction], "Single player arrow opposes hidden fish movement")
		_check(screen._rod_tension.dot(DirectionFishing.VECTORS[direction]) > 0.8, "Rod tip tension follows hidden fish movement")
		var entry: Vector2 = screen.get_water_entry()
		var expected_edge: Vector2 = screen.TIMING_FRAME.get_center() + DirectionFishing.VECTORS[direction] * screen.TIMING_FRAME.size * 0.5
		_check(entry.is_equal_approx(expected_edge), "Visible entry reaches the correct frame edge at the exact target time")
		_check(screen.is_pull_arrow_visible() and not screen.is_fish_revealed(), "Only the player arrow appears during a pull")
		_check(screen._prompt.text.is_empty() and screen._prompt_note.text.is_empty() and screen._status.text.is_empty() and screen._instruction.text.is_empty(), "Pull view has no textual direction or key reminder")
		await _capture("03-direction-%d" % direction)
	qte.fish_direction = DirectionFishing.Direction.LEFT
	qte.beat_elapsed = 0.0
	qte.remaining = qte.get_beat_duration()
	qte.state_changed.emit()
	_check(screen._prompt.text.is_empty() and screen.get_pull_arrow_direction() == Vector2.RIGHT, "Right pull is shown by a green right arrow without text")
	await _capture("03-pull-right")
	var initial_time := qte.remaining
	_send_key(KEY_D, true)
	_send_key(KEY_D, false, true)
	_send_key(KEY_D, false, false, false)
	_send_key(KEY_X)
	_check(qte.successful_pulls == 0 and qte.mistakes == 0, "Hold repeats, shortcuts, releases and unrelated keys do not judge")
	_send_key(KEY_D, false, false, true, KEY_A)
	_check(qte.successful_pulls == 1, "Physical WASD position works independently of logical keyboard layout")
	_check(qte.phase == DirectionFishing.Phase.FEEDBACK, "A successful press receives a separate feedback beat")
	_check(not screen.is_pull_arrow_visible() and not screen.is_fish_revealed(), "Feedback hides the arrow until the next actionable round")
	_send_key(KEY_D)
	_check(qte.successful_pulls == 1, "Same-frame mashing cannot consume a hidden next prompt")
	main._set_paused(true)
	_check(not screen.is_pull_arrow_visible(), "Pause hides the actionable arrow")
	qte.advance(10.0)
	_check(qte.phase == DirectionFishing.Phase.FEEDBACK, "Pause freezes feedback as well as reaction timing")
	_send_key(KEY_P)
	qte.advance(qte.remaining)
	_check(qte.phase == DirectionFishing.Phase.REELING and is_equal_approx(qte.remaining, initial_time), "Resuming gives the next prompt its full window")
	main._set_paused(true)
	_send_key(OS.find_keycode_from_string(qte.get_expected_key()))
	qte.advance(10.0)
	_check(qte.successful_pulls == 1 and is_equal_approx(qte.remaining, initial_time), "Paused input and timers cannot change the fish")
	await _capture("04-paused")
	_send_key(KEY_SPACE)
	_check(not qte.paused and qte.successful_pulls == 1, "Space resumes the same attempt")
	# Finish exactly 3, 5 and 8 valid physical-key pulls; no early catches.
	for fish_index in 3:
		if fish_index > 0:
			qte.select_fish(fish_index)
			_send_key(KEY_SPACE)
			qte.advance(qte.bite_delay + 0.01)
		_check(qte.get_required_pulls() == [3, 5, 8][fish_index], "Fish %d has the requested pull count" % fish_index)
		while qte.successful_pulls < qte.get_required_pulls():
			_check(qte.phase != DirectionFishing.Phase.CAUGHT, "Cannot catch fish before all pulls")
			_send_key(OS.find_keycode_from_string(qte.get_expected_key()))
			if qte.phase == DirectionFishing.Phase.FEEDBACK:
				qte.advance(qte.remaining)
		_check(qte.phase == DirectionFishing.Phase.CAUGHT and qte.caught_counts[fish_index] == 1, "Fish %d is caught once at exactly its pull count" % fish_index)
		_check(screen.is_fish_revealed() and not screen.is_pull_arrow_visible(), "Caught fish is finally revealed with no active arrow")
		_check(DirectionFishing.FISH[fish_index]["name"] in screen._discovered_fish[fish_index].text, "Species name is revealed after a successful catch")
		_send_key(KEY_W)
		qte.advance(100.0)
		_check(qte.caught_counts[fish_index] == 1, "Finished fish cannot be awarded twice")
		await _capture("05-caught-%d" % fish_index)
	_check(_catches == [0, 1, 2] and qte.get_total_caught() == 3, "All three kinds report catches exactly once")
	_send_key(KEY_SPACE)
	qte.advance(100.0)
	_check(qte.phase == DirectionFishing.Phase.REELING and is_equal_approx(qte.remaining, qte.get_beat_duration()), "Slow waiting frame does not instantly expire a new beat")
	var previous: int = qte.fish_direction
	_send_key(OS.find_keycode_from_string(DirectionFishing.KEYS[qte.fish_direction]))
	_check(qte.mistakes == 1 and qte.successful_pulls == 0, "Following the fish instead of the hint is a mistake, not a pull")
	await _capture("06-wrong-direction")
	qte.advance(qte.remaining)
	_check(qte.fish_direction != previous, "Adjacent prompts use different directions")
	_check(screen._prompt.text.is_empty() and screen._instruction.text.is_empty(), "Wrong input never adds a directional text reminder")
	qte.advance(qte.remaining)
	_check(qte.mistakes == 2 and qte.phase == DirectionFishing.Phase.FEEDBACK, "An expired prompt counts exactly one mistake")
	qte.advance(100.0)
	_check(qte.mistakes == 2 and qte.phase == DirectionFishing.Phase.REELING, "A slow feedback frame cannot chain invisible timeouts")
	qte.advance(qte.remaining)
	_check(qte.phase == DirectionFishing.Phase.ESCAPED and qte.mistakes == 3, "Three mistakes release the fish")
	_check(not screen.is_fish_revealed() and not screen.is_pull_arrow_visible(), "Escaped fish is never revealed")
	_check(qte.get_total_caught() == 3, "A failed attempt preserves prior catches")
	await _capture("07-escaped")
	_send_key(KEY_SPACE)
	_check(qte.successful_pulls == 0 and qte.mistakes == 0 and qte.phase == DirectionFishing.Phase.WAITING, "Recasting clears only the current attempt")
	qte.advance(2.0)
	# Switching modules pauses timers and isolates physical-key inputs.
	main.get_node("ModuleNav/Rod").pressed.emit()
	var remaining := qte.remaining
	qte.set_process(true)
	await process_frame
	await process_frame
	_check(qte.remaining == remaining and not screen.visible, "Hidden direction module does not advance")
	_send_key(KEY_SHIFT)
	_check(main.get_node("RodPractice/RodQTE").phase == RodQTE.Phase.SWEEP, "Existing rod module remains playable")
	_send_key(OS.find_keycode_from_string(qte.get_expected_key()))
	_check(qte.successful_pulls == 0 and qte.mistakes == 0, "Hidden direction module cannot consume inputs")
	main.get_node("ModuleNav/Fishing").pressed.emit()
	_send_key(KEY_F)
	_check(main.get_node("FishingPractice/FishingQTE").typed_count == 1, "Existing letter fishing remains playable")
	main.get_node("ModuleNav/Direction").pressed.emit()
	qte.set_process(false)
	_check(screen.visible and qte.remaining == remaining, "Returning to direction fishing preserves the attempt")
	# The rod, line and single player arrow fit a smaller viewport.
	root.size = Vector2i(960, 540)
	await process_frame
	await _capture("08-small-window")
	main.queue_free()
	await process_frame
	await _test_rhythm_rules()
	await _capture_rhythm()
	print("Direction fishing: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_rhythm_rules() -> void:
	# Window boundaries are inclusive; crossing them gives ordinary progress.
	for boundary in [-1.0, 1.0, -1.01, 1.01]:
		var qte := DirectionFishing.new()
		root.add_child(qte)
		qte.set_process(false)
		qte.random_fish_on_cast = false
		qte.select_fish(2)
		qte.cast()
		qte.advance(qte.bite_delay)
		qte.advance(qte.get_target_time() + boundary * qte.get_perfect_half_window())
		var perfect: bool = absf(boundary) <= 1.0
		_check(qte.submit_key(qte.get_expected_key()), "Correct direction succeeds on either side of the timing window")
		_check(qte.last_judgement == (DirectionFishing.Judgement.PERFECT if perfect else DirectionFishing.Judgement.NORMAL), "Timing boundary returns the correct judgement")
		_check(qte.successful_pulls == (2 if perfect else 1) and qte.successful_inputs == 1, "One perfect press gives two progress, ordinary press gives one")
		var progress := qte.successful_pulls
		var expected_total := qte.get_beat_duration()
		_check(is_equal_approx(qte.beat_elapsed + qte.remaining, expected_total), "Each judged input still uses the complete fixed-length beat")
		qte.submit_key(qte.get_expected_key())
		_check(qte.successful_pulls == progress, "A second press cannot be judged on an already consumed beat")
		qte.queue_free()
	await process_frame
	# Perfect play must be faster in elapsed time, not just fewer key presses.
	for fish_index in 3:
		var ordinary := _measure_catch(fish_index, false)
		var perfect := _measure_catch(fish_index, true)
		_check(perfect["time"] < ordinary["time"], "Perfect timing catches fish %d sooner in actual game time" % fish_index)
		_check(ordinary["inputs"] == [3, 5, 8][fish_index], "Ordinary pulls retain the requested 3/5/8 baseline")
		_check(perfect["inputs"] == ceili([3, 5, 8][fish_index] / 2.0), "Perfect timing needs half as many successful presses, rounded up")
		_check(perfect["progress"] == [3, 5, 8][fish_index] and perfect["catches"] == 1, "Double progress is clamped to the target and awards one fish")
	await process_frame
	var early := DirectionFishing.new()
	root.add_child(early)
	early.set_process(false)
	early.random_fish_on_cast = false
	early.cast()
	early.advance(early.bite_delay)
	early.submit_key(early.get_expected_key())
	_check(early.last_judgement == DirectionFishing.Judgement.NORMAL and is_equal_approx(early.remaining, early.get_beat_duration()), "Immediate reaction gets ordinary progress and cannot accelerate the next beat")
	early.advance(early.get_beat_duration() - 0.01)
	_check(early.phase == DirectionFishing.Phase.FEEDBACK and early.successful_pulls == 1, "Early mashing cannot skip the rest of the beat")
	early.advance(0.02)
	_check(early.phase == DirectionFishing.Phase.REELING and is_equal_approx(early.beat_elapsed, 0.01), "Small frame overshoot preserves a steady rhythm clock")
	early.advance(early.get_target_time() - early.beat_elapsed)
	early.submit_key(DirectionFishing.KEYS[early.fish_direction])
	_check(early.last_judgement == DirectionFishing.Judgement.MISS and early.mistakes == 1 and early.successful_pulls == 1, "Wrong direction remains a miss even at perfect time")
	early.queue_free()
	await process_frame


func _measure_catch(fish_index: int, timed: bool) -> Dictionary:
	var qte := DirectionFishing.new()
	root.add_child(qte)
	qte.set_process(false)
	qte.random_fish_on_cast = false
	qte.select_fish(fish_index)
	var catches: Array[int] = []
	qte.fish_caught.connect(func(index: int, _total: int) -> void: catches.append(index))
	qte.cast()
	qte.advance(qte.bite_delay)
	var elapsed := qte.bite_delay
	while qte.phase != DirectionFishing.Phase.CAUGHT:
		if timed:
			var wait := qte.get_target_time() - qte.beat_elapsed
			qte.advance(wait)
			elapsed += wait
		qte.submit_key(qte.get_expected_key())
		if qte.phase == DirectionFishing.Phase.FEEDBACK:
			elapsed += qte.remaining
			qte.advance(qte.remaining)
	var summary := {"time": elapsed, "inputs": qte.successful_inputs, "progress": qte.successful_pulls, "catches": catches.size()}
	qte.queue_free()
	return summary


func _capture_rhythm() -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	root.size = Vector2i(1280, 720)
	var screen := preload("res://scenes/fishing/direction_practice.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var qte := screen.get_node("DirectionFishing") as DirectionFishing
	qte.set_process(false)
	qte.random_fish_on_cast = false
	qte.select_fish(2)
	qte.cast()
	qte.advance(qte.bite_delay)
	qte.fish_direction = DirectionFishing.Direction.RIGHT
	qte.advance(qte.get_target_time() * 0.5)
	await _capture("09-rhythm-approach")
	qte.advance(qte.get_target_time() - qte.beat_elapsed)
	await _capture("10-rhythm-edge")
	_send_key(KEY_A)
	_check(qte.successful_pulls == 2 and qte.perfect_count == 1, "Rendered frame-edge input awards double progress")
	await _capture("11-rhythm-perfect")
	qte.advance(qte.remaining)
	_send_key(OS.find_keycode_from_string(qte.get_expected_key()))
	_check(qte.successful_pulls == 3 and qte.last_judgement == DirectionFishing.Judgement.NORMAL, "Rendered early input receives ordinary progress")
	await _capture("12-rhythm-ordinary")
	screen.queue_free()
	await process_frame


func _send_key(physical: Key, echo: bool = false, control: bool = false, pressed: bool = true, logical: Key = KEY_NONE) -> void:
	var event := InputEventKey.new()
	event.keycode = physical if logical == KEY_NONE else logical
	event.physical_keycode = physical
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
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var result := root.get_texture().get_image().save_png("res://build/validation/direction-%s.png" % label)
	_check(result == OK, "Screenshot saved: " + label)
