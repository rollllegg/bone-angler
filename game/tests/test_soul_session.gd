extends SceneTree
## Headless rules + real physical-key integration. Add -- --capture to render.

var _checks: int = 0
var _failures: int = 0
var _arrivals: Array[int] = []
var _payments: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var model := SoulSession.new()
	root.add_child(model)
	model.set_process(false)
	model.soul_arrived.connect(func(id: int) -> void: _arrivals.append(id))
	model.soul_released.connect(func(_id: int, reward: int) -> void: _payments.append(reward))
	_check(model.inventory == [0, 0, 0] and model.coins == 0 and model.souls.is_empty(), "Session starts without free fish, souls or coins")
	var initial_delay := model.spawn_remaining
	_check(initial_delay >= 10.0 and initial_delay <= 15.0, "First arrival also waits a random ten to fifteen seconds")
	model.advance(-2.0)
	model.advance(initial_delay - 0.01)
	_check(model.souls.is_empty(), "First soul cannot arrive before its sampled deadline")
	model.advance(0.01)
	_check(model.souls.size() == 1 and _arrivals == [1], "Exactly one soul arrives at the sampled deadline")
	_check(model.get_missing(1) == Vector3i(1, 0, 0), "First soul demonstrates one deficient attribute")
	_check(not model.can_release(1) and not model.release_soul(1), "A deficient soul cannot be released for coins")
	_check(not model.feed_fish(1, 0) and not model.add_fish(-1) and not model.add_fish(3), "Invalid inventory operations cannot mint fish")
	model.add_fish(0)
	var before: Vector3i = model.get_soul(1)["stats"]
	_check(not model.feed_fish(999, 0) and not model.feed_fish(1, -1), "Invalid soul IDs or fish kinds cannot consume inventory")
	_check(model.inventory[0] == 1, "Failed operations preserve the caught fish")
	_check(model.feed_fish(1, 0), "Caught fish can feed the deficient soul")
	_check(model.inventory == [0, 0, 0] and model.get_soul(1)["stats"] == before + Vector3i(4, 1, 1), "Feeding consumes one fish and adds all three attributes")
	_check(model.can_release(1), "All three current-day thresholds allow admission")
	model.add_fish(0)
	_check(not model.feed_fish(1, 0) and model.inventory[0] == 1, "Already complete souls cannot waste extra fish")
	model.set_paused(true)
	var waiting := model.spawn_remaining
	model.advance(30.0)
	_check(model.spawn_remaining == waiting and not model.release_soul(1), "Pause freezes arrivals and admissions")
	model.set_paused(false)
	_check(model.release_soul(1) and model.coins == 10 and model.released_count == 1, "One admission pays ten coins")
	_check(not model.release_soul(1) and _payments == [10] and model.coins == 10, "A removed soul cannot pay a second reward")
	model.advance(30.0)
	_check(model.souls.size() >= 2 and model.souls.size() <= 3 and _arrivals.size() == model.souls.size() + 1, "Long frames preserve arrivals within the slower ten-to-fifteen-second cadence")
	for index in _arrivals.size():
		_check(_arrivals[index] == index + 1, "Every arriving soul retains a unique sequential ID")
	for soul in model.souls:
		_check(not model.can_release(soul["id"]), "Every arriving soul is deficient")
	var old_day := model.day
	model.advance(model.day_remaining)
	_check(model.day == old_day + 1 and model.get_requirements() == Vector3i(4, 3, 4), "New day changes admission requirements at the exact boundary")
	# Recheck current standards, including souls which arrived on an earlier day.
	var earlier_id: int = model.souls[0]["id"]
	model.get_soul(earlier_id)["stats"] = Vector3i(3, 3, 3)
	_check(not model.can_release(earlier_id) and not model.release_soul(earlier_id), "Release rechecks the current day's requirements")
	model.active = false
	var old_time := model.day_remaining
	model.advance(20.0)
	_check(model.day_remaining == old_time, "Isolated legacy practices suspend the live session")
	model.active = true
	model.advance(240.0)
	for soul in model.souls:
		var arrival_required: Vector3i = SoulSession.DAILY_REQUIREMENTS[(int(soul["arrival_day"]) - 1) % 4]
		var stats: Vector3i = soul["stats"]
		if soul["id"] != earlier_id:
			_check(stats.x < arrival_required.x or stats.y < arrival_required.y or stats.z < arrival_required.z, "Generated souls always lack at least one arrival-day requirement")
	model.queue_free()
	await process_frame
	var cadence := SoulSession.new()
	root.add_child(cadence)
	cadence.set_process(false)
	var intervals: Array[float] = []
	for index in 16:
		var interval := cadence.spawn_remaining
		intervals.append(interval)
		_check(interval >= 10.0 and interval <= 15.0, "Every new arrival interval stays within ten to fifteen seconds")
		var count := cadence.souls.size()
		cadence.advance(interval - 0.01)
		_check(cadence.souls.size() == count, "An arrival never fires before its random deadline")
		cadence.advance(0.01)
		_check(cadence.souls.size() == count + 1, "Each random deadline creates just one soul")
	_check(not is_equal_approx(intervals.min(), intervals.max()), "Arrival intervals vary instead of using a fixed delay")
	cadence.queue_free()
	await process_frame
	await _test_live_loop()
	print("Soul session: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_live_loop() -> void:
	root.size = Vector2i(1280, 720)
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var state := main.get_node("SoulSession") as SoulSession
	var river := main.get_node("DirectionPractice")
	var gate := main.get_node("SoulGate")
	var qte := river.get_node("DirectionFishing") as DirectionFishing
	state.set_process(false)
	qte.set_process(false)
	qte.random_fish_on_cast = false
	_check(river.visible and not gate.visible, "Live demo starts at the river")
	_send_key(KEY_E, true)
	_send_key(KEY_E, false, true)
	_send_key(KEY_E, false, false, false)
	_check(river.visible, "Key repeats, shortcuts and releases do not switch location")
	_send_key(KEY_E)
	_check(gate.visible and main.current_module == "Gate", "Physical E opens the underworld gate")
	_check("10～15" in gate._soul_note.text, "Empty gate explains the slower ten-to-fifteen-second cadence")
	await _capture("01-empty-gate")
	_send_key(KEY_SPACE)
	_send_key(KEY_1)
	_check(state.coins == 0 and state.get_inventory_total() == 0, "Empty gate shortcuts cannot create rewards or fish")
	_send_key(KEY_Q)
	state.advance(state.spawn_remaining)
	_check(state.souls.size() == 1 and river.visible, "Souls continue arriving while the player fishes")
	await _capture("02-river-arrival")
	# Catch actual 3/5/8-pull fish through physical WASD input.
	for fish_index in 3:
		qte.select_fish(fish_index)
		_send_key(KEY_SPACE)
		qte.advance(qte.bite_delay)
		for pull in qte.get_required_pulls():
			_send_key(OS.find_keycode_from_string(qte.get_expected_key()))
			if qte.phase == DirectionFishing.Phase.FEEDBACK:
				qte.advance(qte.remaining)
		_check(qte.phase == DirectionFishing.Phase.CAUGHT and state.inventory[fish_index] == 1, "Actual fish kind %d enters shared inventory once" % fish_index)
	_check(state.inventory == [1, 1, 1] and qte.caught_counts == [1, 1, 1], "Fish inventory is separate from lifetime catch statistics")
	await _capture("03-river-inventory")
	_send_key(KEY_E)
	_check(gate.selected_id == 1 and gate._release.disabled, "Gate selects a deficient soul and blocks release")
	await _capture("04-soul-deficit")
	var retained_id: int = gate.selected_id
	state.advance(state.spawn_remaining)
	_check(gate.selected_id == retained_id, "An arriving soul cannot silently change the feeding target")
	_send_key(KEY_1, true)
	_send_key(KEY_1, false, true)
	_send_key(KEY_1, false, false, false)
	_check(state.inventory[0] == 1, "Held keys, shortcuts and releases cannot consume fish")
	_send_key(KEY_1)
	_check(state.inventory == [0, 1, 1] and state.can_release(1), "Number 1 feeds the selected soul using the green fish")
	_check(not gate._release.disabled and "已达标" in gate._attributes[0].text, "UI refreshes deficits and enables admission after feeding")
	await _capture("05-ready-to-release")
	_send_key(KEY_SPACE)
	_check(state.coins == 10 and state.released_count == 1 and state.get_soul(1).is_empty(), "Gate Space releases the completed soul and awards ten coins")
	_check(gate.selected_id == 2, "Selection moves to a real remaining soul after admission")
	await _capture("06-reward")
	# Exercise blue and red feed shortcuts, including their exact attribute data.
	state.get_soul(2)["stats"] = Vector3i.ZERO
	state.state_changed.emit()
	_send_key(KEY_2)
	_check(state.inventory[1] == 0 and state.get_soul(2)["stats"] == Vector3i(1, 4, 1), "Number 2 gives the blue charisma bonus")
	_send_key(KEY_3)
	_check(state.inventory[2] == 0 and state.get_soul(2)["stats"] == Vector3i(2, 5, 5), "Number 3 gives the red courage bonus")
	_check(not state.can_release(2), "Two completed attributes do not bypass the remaining deficit")
	_send_key(KEY_SPACE)
	_check(state.coins == 10, "A failed admission never awards gold")
	# More than six arrivals stay available through pages, with stable selection.
	for index in 7:
		state.advance(state.spawn_remaining)
	_check(state.souls.size() == 8 and not gate._next.disabled, "The queue preserves visitors beyond the visible page")
	gate._next.pressed.emit()
	gate.get_node("Layout/SoulRow1").pressed.emit()
	_check(gate.page == 1 and gate.selected_id == state.souls[7]["id"], "Later pages allow selecting actual waiting souls")
	await _capture("07-queue-pages")
	state.get_soul(gate.selected_id)["stats"] = state.get_requirements()
	state.state_changed.emit()
	gate._release.pressed.emit()
	_check(gate.page == 1 and gate.selected_id == state.souls[6]["id"], "Admitting a later-page soul keeps the next selection on the visible page")
	var prior_day := state.day
	state.advance(state.day_remaining)
	_check(state.day == prior_day + 1, "Day transition updates admission day")
	for index in 3:
		_check(str(state.get_requirements()[index]) in gate._requirements[index].text, "Day transition updates displayed admission requirements")
	await _capture("08-next-day")
	_send_key(KEY_P)
	var clock := state.spawn_remaining
	state.advance(30.0)
	_check(state.paused and state.spawn_remaining == clock, "Gate pause freezes the whole shared session")
	_send_key(KEY_Q)
	_check(state.paused and river.visible and not river.is_pull_arrow_visible(), "Scene switching cannot resume a paused session")
	_send_key(KEY_SPACE)
	_check(not state.paused and qte.phase == DirectionFishing.Phase.CAUGHT, "Space resumes without accidentally starting another cast")
	# An in-progress fish is preserved while serving souls.
	qte.select_fish(2)
	_send_key(KEY_SPACE)
	qte.advance(qte.bite_delay)
	_send_key(OS.find_keycode_from_string(qte.get_expected_key()))
	qte.advance(qte.remaining)
	var remaining := qte.remaining
	_send_key(KEY_E)
	qte.set_process(true)
	await process_frame
	await process_frame
	_check(qte.remaining == remaining and qte.successful_pulls == 1, "Hidden fishing timing and progress are preserved at the gate")
	_send_key(OS.find_keycode_from_string(qte.get_expected_key()))
	_check(qte.successful_pulls == 1 and qte.mistakes == 0, "Gate input never pulls the hidden fish")
	_send_key(KEY_Q)
	qte.set_process(false)
	_check(qte.remaining == remaining and qte.successful_pulls == 1, "Returning to river resumes the same fish")
	_send_key(KEY_E)
	root.size = Vector2i(960, 540)
	await process_frame
	await _capture("09-small-window")
	main.queue_free()
	await process_frame


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
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var error := root.get_texture().get_image().save_png("res://build/validation/soul-%s.png" % label)
	_check(error == OK, "Saved screenshot " + label)
