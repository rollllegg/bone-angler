extends SceneTree
## Checks chronological lab arrivals, native daily reports and conditional returns.

var _checks := 0
var _failures := 0
var _demo


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	var demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(demo)
	_demo = demo
	await process_frame
	demo.auto_pause_on_focus_loss = false
	demo.session.set_process(false)
	demo._start_story_lab()
	await process_frame
	_check(demo.started and demo.story_lab, "story lab starts the chronological test run")
	_check(not demo.persist_save, "story lab disables saving")
	_check(demo.current_location == "Shop", "story lab opens the reception")
	_check_day(1, 6)
	_check(demo.session.get_soul(5).is_empty(), "the retired observer is not included in the lab")
	_check(demo.session.get_soul(12).is_empty() and demo.session.get_soul(18).is_empty() and demo.session.get_soul(30).is_empty(), "future guests are not created before their day")
	_check(demo.session.released_count == 0 and demo.session.coins == 200, "the lab starts without fabricated services")
	_check(not bool(demo.session.story_state.world["world.orpheus_lost"]) and str(demo.session.story_state.world["world.orpheus_echo"]) == "", "the lab does not fabricate an Orpheus ending")
	_check(demo.session.potions.size() == 3, "story lab stocks three test potions")
	_check(demo.session.potions[0].effect == Vector3i(0, 2, 0), "story lab hot potion")
	_check(demo.session.potions[1].effect == Vector3i(4, 0, 1), "story lab clear potion")
	_check(demo.session.potions[2].effect == Vector3i(-2, -1, -1), "story lab zero potion")
	_check(not demo.story_panel.visible and demo._story_action_button.visible and demo._release_button.visible, "story lab uses the ordinary reception controls")
	_check(demo._dose_buttons.size() == 3, "story lab lists the three test potions")
	_check(demo._arrival.text.contains("重置") and demo._summary.text.contains("第 1 天"), "the lab explains its current day and reset action")
	_check(_queue_label(0).contains("孙悟空"), "the queue identifies the current special guest")
	await _capture("story-lab.png")

	# Future guests must wait for the player's explicit dismissal of each report.
	_resolve_case(6, "admit")
	_check_report(1, "wukong")
	_check(bool(demo.session.story_state.world["world.hades_rampage"]), "Wukong changes the shared world state")
	demo.session.advance(10000.0)
	_check(demo.session.day == 1 and demo.session.souls.is_empty() and demo.session.story_runtimes.is_empty(), "time cannot spawn Orpheus behind day one's report")
	_check(not demo._ending_screen.is_active(), "day one's report does not end the run")
	await _capture("story-lab-day-1-report.png")
	_press(KEY_SPACE)
	_check_day(2, 12)
	_check(demo.session.story_state.ledger.size() == 1 and bool(demo.session.story_state.world["world.hades_rampage"]), "day two inherits the actual day one ending")
	_resolve_case(12, "admit", 1)
	_check(bool(demo.session.story_state.world["world.orpheus_reunion"]), "Orpheus can reunite using Wukong's actual result")
	_check_report(2, "orpheus")
	_check(demo.session.potions.size() == 2, "continuing to the next day retains consumed potions")
	_check(str(demo.session.story_state.world["world.orpheus_echo"]) == "", "the reunion does not schedule a drowned return")
	await _capture("story-lab-day-2-report.png")
	_press(KEY_ENTER)
	_check_day(5, 30)
	_check(demo.session.get_soul(18).is_empty(), "the reunion skips the return guest and days with no story content")
	_check(demo.session.souls[0].name == "？？？", "the final hearing still begins with its hidden identity")

	# Reset must escape a live scale input, whose LineEdit owns keyboard focus.
	_open_judgment()
	_check(demo.judgment_panel.is_active() and demo.session.story_open, "the final hearing retains its normal input flow")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	demo._arrival.gui_input.emit(click)
	_check(not demo.judgment_panel.is_active() and not demo.session.story_open, "clicking reset cancels the scale")
	_check_reset()

	# All three tragic results must create the return guest only on the next day.
	for spec in [
		{"choice": "admit", "potion": -1, "outcome": "accepted.confused", "judgment": "zero"},
		{"choice": "admit", "potion": 1, "outcome": "accepted.clear", "judgment": "all"},
		{"choice": "refuse", "potion": -1, "outcome": "refused", "judgment": "other"},
	]:
		_resolve_case(6, "", 2)
		_check_report(1, "wukong")
		_check(not bool(demo.session.story_state.world["world.hades_rampage"]), "the calm Wukong ending survives into day two")
		_press(KEY_ENTER)
		_check_day(2, 12)
		_resolve_case(12, str(spec.choice), int(spec.potion))
		_check_report(2, "orpheus")
		_check(demo.session.day_story_entries[0].aftermath.is_empty(), "Orpheus' tragic epilogue waits for the return guest")
		_check(str(demo.session.story_state.world["world.orpheus_echo"]) == spec.outcome and demo.session.get_soul(18).is_empty(), "the actual ending schedules a return without spawning it before the report")
		_press(KEY_ENTER)
		_check_day(3, 18)
		_check(demo.session.souls[0].name == "殉情的琴手" and _queue_label(0).contains("回访"), "the conditional return guest is identified in the queue")
		_check(demo.session.can_release(18), "testing the return guest does not require grinding ingredients")
		demo._release_guest()
		_check_report(3, "orpheus")
		_check(str(demo.session.story_state.world["world.orpheus_echo"]) == "" and not demo.session.day_story_entries[0].aftermath.is_empty(), "the return guest resolves the real deferred epilogue once")
		await _capture("story-lab-day-3-report.png")
		_press(KEY_SPACE)
		_check_day(5, 30)
		var anubis = _open_judgment()
		var amount := 0 if spec.judgment == "zero" else (int(demo.session.coins) if spec.judgment == "all" else 1)
		demo.judgment_panel._set_value(amount)
		demo.judgment_panel._submit()
		demo.judgment_panel.finish_animation()
		_settle(anubis)
		_check(anubis.is_closed() and anubis.get_outcome_id() == "judged." + str(spec.judgment), "the chronological lab preserves the scale ending")
		demo._release_guest()
		_check(demo.session.is_complete() and not demo.day_report.visible, "the final hearing retains its normal direct ending")
		_check(demo._ending_screen.is_active() and not demo._shop_ui.visible, "the lab reaches the final ending card")
		_press(KEY_N)
		_check_reset()

	# N also restarts while the native daily report is open.
	_resolve_case(6, "admit")
	_check_report(1, "wukong")
	_press(KEY_N)
	_check_reset()
	_check(not demo.day_report.visible and not demo.session.awaiting_day_report, "reset clears a pending daily report")
	demo.free()

	print("StoryLab: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_day(day: int, soul_id: int) -> void:
	_check(_demo.session.day == day and _demo.session.souls.size() == 1 and not _demo.session.get_soul(soul_id).is_empty(), "only the current day's special guest is present on day %d" % day)
	_check(not _demo.session.has_more_arrivals(), "ordinary guests cannot interrupt day %d" % day)
	_check(_demo.shop.selected_id == soul_id, "day %d selects its actual guest" % day)
	_check(not _demo.day_report.visible and not _demo.session.awaiting_day_report, "day %d opens after the previous report closes" % day)


func _check_report(day: int, case_id: String) -> void:
	var report: Dictionary = _demo.session.get_day_report()
	_check(_demo.day_report.visible and int(report.get("day", -1)) == day, "day %d shows the original daily report" % day)
	_check(_demo.day_report._title.text == "第 %d 天 · 收工" % day, "the daily report uses the original title")
	var entries: Array = report.get("entries", [])
	_check(entries.size() == 1 and str(entries[0].get("case", "")) == case_id, "the daily report contains only the current day's result")
	var rendered := ""
	for child in _demo.day_report._list.get_children():
		if child is Label:
			rendered += child.text + "\n"
	for entry in entries:
		for paragraph in entry.get("aftermath", []):
			_check(rendered.contains(str(paragraph)), "the report renders the actual aftermath text")
	_check(_demo.session.is_time_suspended() and _demo.session.souls.is_empty(), "the report blocks the next guest until it is dismissed")


func _check_reset() -> void:
	_check_day(1, 6)
	_check(not _demo._ending_screen.is_active() and _demo._shop_ui.visible and _demo._hud.visible, "reset restores the reception from any ending")
	_check(_demo.session.potions.size() == 3 and _demo.session.coins == 200, "reset restores test potions and coins")
	_check(_demo.session.story_state.ledger.is_empty() and _demo.session.released_count == 0 and _demo.session.rejected_count == 0, "reset clears previous services and the ledger")
	_check(not bool(_demo.session.story_state.world["world.hades_rampage"]) and not bool(_demo.session.story_state.world["world.orpheus_reunion"]) and str(_demo.session.story_state.world["world.anubis_result"]) == "", "reset clears outcomes across all story days")


func _queue_label(index: int) -> String:
	for child in _demo._queue_buttons[index].get_children():
		if child is Label:
			return child.text
	return ""


func _resolve_case(id: int, choice: String, potion: int = -1) -> void:
	_demo.shop.select_guest(id)
	var runtime = _demo.session.get_story_runtime(id)
	_settle(runtime)
	if potion >= 0:
		_demo._select_dose([false, int(_demo.session.potions[potion].id)])
		_demo._serve_dose()
		_settle(runtime)
	if not choice.is_empty():
		_check(runtime.choose(choice), "the test guest accepts %s" % choice)
		_settle(runtime)
	_check(runtime.is_closed(), "the test guest reaches a real ending")
	_demo._release_guest()
	_check(_demo.session.get_soul(id).is_empty(), "the tested guest leaves the day's queue")


func _open_judgment():
	_demo.shop.select_guest(30)
	var runtime = _demo.session.get_story_runtime(30)
	_settle(runtime)
	_check(runtime.choose("admit"), "Anubis continues into the hearing")
	_settle(runtime)
	return runtime


func _settle(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and not runtime.is_awaiting_choice() and not runtime.is_awaiting_judgment() and guard < 100:
		if not runtime.advance():
			break
		guard += 1


func _press(code: Key) -> void:
	_demo._handle_game_key(code)


func _capture(file_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://build/validation")
	DirAccess.make_dir_recursive_absolute(directory)
	image.save_png(directory.path_join(file_name))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
