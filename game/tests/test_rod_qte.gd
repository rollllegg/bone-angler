extends SceneTree
## Godot --headless --path game --script res://tests/test_rod_qte.gd
## Omit --headless and append -- --capture for rendered checkpoints.

var _failures: int = 0
var _checks: int = 0
var _completions: Array[Dictionary] = []
var _judgements: Array[int] = []
var _recoveries: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	root.size = Vector2i(1280, 720)
	root.add_child(main)
	await process_frame
	main.get_node("ModuleNav/Rod").pressed.emit()
	var practice := main.get_node("RodPractice")
	var qte := practice.get_node("RodQTE") as RodQTE
	qte.set_process(false)
	qte.checkpoint_judged.connect(func(_index: int, result: int) -> void: _judgements.append(result))
	qte.recovery_started.connect(func(duration: float) -> void: _recoveries.append(duration))
	qte.operation_completed.connect(func(mode: int, summary: Dictionary) -> void: _completions.append({"mode": mode, "summary": summary}))
	_check(qte.phase == RodQTE.Phase.IDLE and practice.visible, "Navigation opens an idle rod module")
	_check(not main.get_node("FishingPractice").visible, "Fishing prototype is available but inactive")
	_check(qte.get_joint_name(0) == "握把 — 竿体" and qte.get_joint_name(2) == "鱼线 — 鱼钩", "Assembly uses grip, line, hook order")
	_check(qte.submit() == RodQTE.Result.PENDING and _judgements.is_empty(), "Idle input cannot judge a joint")
	await _capture("01-ready")

	# Keyboard path: start is separate from the three judgement presses.
	_send_key(KEY_A)
	_send_key(KEY_SHIFT, true)
	_send_key(KEY_SHIFT, false, true)
	_send_key(KEY_SHIFT, false, false, false)
	_check(qte.phase == RodQTE.Phase.IDLE, "Non-Shift keys, repeats, shortcuts and releases cannot start")
	_send_key(KEY_SHIFT)
	_check(qte.phase == RodQTE.Phase.SWEEP and _judgements.is_empty(), "First Shift starts without also missing the first checkpoint")
	_check(practice.get_node("Layout/Assemble").disabled and practice.get_node("Layout/Disassemble").disabled, "Mode selection locks while active")
	practice.get_node("Layout/Start").pressed.emit()
	_check(qte.phase == RodQTE.Phase.SWEEP and qte.current_index == 0, "Start cannot reset an active run")
	_move_to(qte, 0.22)
	_send_key(KEY_SHIFT, true)
	_send_key(KEY_SHIFT, false, true)
	_send_key(KEY_SHIFT, false, false, false)
	_check(qte.current_index == 0, "Holding or releasing Shift cannot judge")
	_send_key(KEY_SHIFT)
	_check(qte.perfect_count == 1 and qte.current_index == 1, "A fresh Shift in the center awards one perfect")
	await _capture("02-perfect")
	_move_to(qte, 0.50)
	_send_key(KEY_SHIFT)
	_move_to(qte, 0.78)
	_send_key(KEY_SHIFT)
	_check(qte.phase == RodQTE.Phase.COMPLETE and qte.recovery_duration == 0.0, "Three perfects skip recovery immediately")
	_check(_completions.size() == 1 and _recoveries == [0.0], "Zero-second recovery emits start and completion exactly once")
	_check(_completions[0]["summary"]["perfect"] == 3, "Completion summary contains all three perfects")
	qte.advance(10.0)
	_check(_completions.size() == 1, "Finished timers cannot complete a second time")
	await _capture("03-zero-recovery")

	# Normal success uses the outer green area, leaving recovery at its base.
	qte.start()
	for index in 3:
		_move_to(qte, RodQTE.CHECKPOINTS[index] - 0.05)
		_check(qte.submit() == RodQTE.Result.GOOD, "Green area succeeds without perfect bonus")
	_check(qte.phase == RodQTE.Phase.RECOVERY and qte.recovery_duration == 3.0, "Three ordinary successes retain three seconds")
	var count_before := _judgements.size()
	_check(qte.submit() == RodQTE.Result.PENDING and _judgements.size() == count_before, "Shift during recovery cannot alter results")
	qte.advance(-1.0)
	_check(qte.recovery_remaining == 3.0, "Negative time cannot increase recovery")
	qte.advance(2.9)
	_check(qte.phase == RodQTE.Phase.RECOVERY, "Operation stays active until recovery really finishes")
	qte.advance(0.11)
	_check(qte.phase == RodQTE.Phase.COMPLETE and _completions.size() == 2, "Recovery completes once after the remaining time")

	qte.start()
	_move_to(qte, 0.22)
	qte.submit()
	_move_to(qte, 0.45)
	qte.submit()
	_move_to(qte, 0.70)
	_check(qte.submit() == RodQTE.Result.MISS, "Pressing before the green area counts as one miss")
	_check(qte.perfect_count == 1 and qte.good_count == 1 and qte.miss_count == 1 and qte.recovery_duration == 3.0, "Perfect and miss modifiers cancel")
	await _capture("04-mixed-recovery")

	# Entire sweep in one slow frame: three misses, with leftover time in recovery.
	qte.start()
	qte.advance(5.0)
	_check(qte.miss_count == 3 and qte.current_index == 3, "Unpressed windows each auto-miss once even in a slow frame")
	_check(qte.recovery_duration == 6.0 and is_equal_approx(qte.recovery_remaining, 5.25), "Slow-frame leftover time is charged to six-second recovery")
	await _capture("05-all-missed")
	qte.advance(100.0)
	_check(qte.phase == RodQTE.Phase.COMPLETE and _completions.size() == 3, "A large recovery delta still completes only once")

	# Outer boundary is inclusive, just outside it is not.
	qte.start()
	_move_to(qte, 0.22 - qte.get_success_half_width())
	_check(qte.submit() == RodQTE.Result.GOOD, "Leading success boundary is inclusive")
	qte.start()
	_move_to(qte, 0.22 + qte.get_success_half_width())
	_check(qte.submit() == RodQTE.Result.GOOD, "Trailing success boundary is inclusive")
	qte.start()
	_move_to(qte, 0.22 - qte.get_success_half_width() - 0.001)
	_check(qte.submit() == RodQTE.Result.MISS, "A key outside the window fails the current joint")
	qte.start()
	_move_to(qte, 0.22 + qte.get_perfect_half_width())
	_check(qte.submit() == RodQTE.Result.PERFECT, "Perfect boundary is inclusive")
	qte.start()
	qte.submit()
	qte.submit()
	qte.submit()
	_check(qte.miss_count == 3 and qte.recovery_duration == 6.0, "Mashing early cannot earn successes or escape the miss penalty")

	qte.reset(RodQTE.Mode.DISASSEMBLE)
	_check(qte.perfect_count == 0 and qte.miss_count == 0 and qte.recovery_remaining == 0.0, "Reset clears old outcomes and recovery")
	_check(qte.results == [0, 0, 0] and qte.current_index == 0, "Reset clears each checkpoint")
	_check(qte.get_joint_name(0) == "鱼线 — 鱼钩" and qte.get_joint_name(2) == "握把 — 竿体", "Disassembly reverses the connection order")
	practice.get_node("Layout/Disassemble").pressed.emit()
	await _capture("06-disassembly")
	_send_key(KEY_SHIFT)
	for index in 3:
		_move_to(qte, RodQTE.CHECKPOINTS[index])
		_send_key(KEY_SHIFT)
	_check(qte.phase == RodQTE.Phase.COMPLETE and _completions[-1]["mode"] == RodQTE.Mode.DISASSEMBLE, "Disassembly has the same three-point rules and correct completion mode")
	_check(_completions[0]["summary"]["results"] == [2, 2, 2], "Saved completion results are independent of later runs")

	# Scene integration: hidden prototypes neither advance nor consume keyboard input.
	_send_key(KEY_SHIFT)
	_move_to(qte, 0.10)
	qte.set_process(true)
	main.get_node("ModuleNav/Fishing").pressed.emit()
	var paused_time := qte.sweep_elapsed
	await process_frame
	await process_frame
	_check(qte.sweep_elapsed == paused_time and not practice.visible, "Switching away pauses the sweep")
	_send_key(KEY_SHIFT)
	_check(qte.current_index == 0, "Hidden rod module does not consume Shift")
	_send_key(KEY_F)
	_check(main.get_node("FishingPractice/FishingQTE").typed_count == 1, "Fishing module still receives letters")
	main.get_node("ModuleNav/Rod").pressed.emit()
	qte.set_process(false)
	_check(practice.visible and qte.sweep_elapsed == paused_time, "Switching back preserves the current rod attempt")
	_send_key(KEY_I)
	_check(main.get_node("FishingPractice/FishingQTE").typed_count == 1, "Hidden fishing module does not consume letters")
	_move_to(qte, 0.22)
	_send_key(KEY_SHIFT)
	_check(qte.perfect_count == 1, "Resumed rod attempt still accepts judgement input")

	main.queue_free()
	await process_frame
	print("Rod QTE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _move_to(qte: RodQTE, progress: float) -> void:
	qte.advance(maxf(progress * qte.get_sweep_duration() - qte.sweep_elapsed, 0.0))


func _send_key(code: Key, echo: bool = false, control: bool = false, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
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
	# Allow the presentation to finish moving the rod parts at a frozen QTE time.
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var result := root.get_texture().get_image().save_png("res://build/validation/rod-%s.png" % label)
	_check(result == OK, "Screenshot saved: " + label)
