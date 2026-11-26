extends SceneTree

const Demo := preload("res://scripts/demo/demo.gd")
const Data := preload("res://scripts/systems/playtest_data.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const SaveSlots := preload("res://scripts/demo/save_slots.gd")

var demo: Demo
var checks := 0
var failures := 0
var directory := "res://build/validation/tutorial-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	await _check_entry_and_settings()
	await _check_first_order()
	await _check_skipping()
	await _check_tips()
	await _check_saves()
	for slot in SaveSlots.COUNT:
		SaveSlots.remove(directory, slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	demo.queue_free()
	await process_frame
	print("Tutorial: %d checks, %d failures" % [checks, failures])
	quit(failures)


func _new_demo() -> void:
	if is_instance_valid(demo):
		demo.queue_free()
		await process_frame
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.save_directory = directory
	demo.auto_pause_on_focus_loss = false
	root.add_child(demo)
	demo.session.set_process(false)
	demo.qte.set_process(false)
	demo.river.set_process(false)
	demo.shop.set_process(false)
	demo._tutorial_overlay.set_process(false)
	await process_frame


func _check_entry_and_settings() -> void:
	await _new_demo()
	_click(demo.start_button)
	var modal := demo._start_mode_modal
	_check(modal.is_open and modal._cursor == 0 and not demo.started, "Start opens a mode chooser focused on the tutorial")
	_key(KEY_ESCAPE)
	_check(not modal.is_open and not demo.started, "Esc cancels to the cover")
	_key(KEY_ENTER)
	_key(KEY_C)
	_check(not modal.is_open and not demo.started, "C cancels to the cover")
	_key(KEY_SPACE)
	_click_at(Vector2(40, 40))
	_check(not modal.is_open and not demo.started, "Clicking the shade cancels to the cover")
	_key(KEY_SPACE)
	_click(modal.close_button)
	_check(not modal.is_open and not demo.started, "The close button cancels to the cover")
	_click(demo.settings_button)
	var settings := demo._settings_modal
	_check(settings.is_open and settings.active_tab == 0 and settings.get_parent() == demo._stage, "The cover opens the shared Settings on Basic")
	_key(KEY_E)
	_check(settings.active_tab == 1 and settings._controls.visible, "E opens the operation menu")
	_key(KEY_LEFT)
	_check(settings.active_tab == 0, "Left switches back to basic settings")
	_click(settings._tab_buttons[1])
	_check(settings.active_tab == 1, "Mouse selects the operation menu tab")
	for card: Panel in settings._controls.get_children():
		for label: Label in card.get_children():
			var edge := label.get_rect().end
			_check(edge.x <= card.size.x and edge.y <= card.size.y, "Operation menu text fits its card: " + label.text)
	_key(KEY_C)
	_click(demo.start_button)
	_key(KEY_D)
	_key(KEY_ENTER)
	_check(demo.started and not demo.tutorial_active and not demo.qte.has_tutorial_catch() and demo.session.souls.is_empty(), "Direct Start uses the ordinary shift")
	_key(KEY_ESCAPE)
	_check(demo._pause_banner.get_rect().end.y < 96.0 and demo._pause_banner.get_rect().end.x < demo._previous_location_button.position.x
		and demo._pause_buttons.size() == 4, "All four pause actions stay inside the top bar and clear of location tabs")
	_key(KEY_G)
	_check(settings.is_open and demo.session.paused and settings.active_tab == 0, "G opens basic settings from pause")
	_key(KEY_Q)
	_key(KEY_TAB)
	_check(settings.active_tab == 1 and not demo._codex.is_open, "Open Settings owns tab switching and blocks the codex shortcut")
	_key(KEY_ESCAPE)
	_check(not settings.is_open and demo.session.paused, "Esc closes settings only")
	_click(demo._pause_buttons[3])
	_check(settings.is_open and demo.session.paused, "The last pause button opens the same Settings")
	_key(KEY_C)
	_check(not settings.is_open and demo.session.paused, "C closes settings and keeps the game paused")
	_key(KEY_ESCAPE)
	_check(not demo.session.paused, "Esc can then resume the shift")


func _check_first_order() -> void:
	await _new_demo()
	_click(demo.start_button)
	_click(demo._start_mode_modal.buttons[0])
	var session := demo.session
	var fishing := demo.qte
	_check(demo.tutorial_active and demo.tutorial_step == 1 and demo.current_location == "River", "Choosing the tutorial starts step 1 at the river")
	_check(session.requirements == [Vector3i(0, 7, 7), Vector3i(10, 10, 10)], "Tutorial fixes the day-one admission window")
	var guest := session.get_soul(Session.TUTORIAL_GUEST_ID)
	_check(guest.get("case_id") == 1 and guest.stats.y == 6 and not session.is_eligible(guest.stats) and session.souls.size() == 1, "The postman is the only immediate arrival")
	var interval := session.spawn_remaining
	session.advance(180.0)
	_check(session.tutorial_pause_arrivals and session.spawn_remaining == interval and session.souls.size() == 1, "The tutorial pauses future arrivals")
	_check(demo._tutorial_overlay._opening.has_point(demo._cast_button.get_rect().get_center()), "The spotlight exposes the cast button")
	_click(demo._cast_button)
	demo.river.advance_cast(1.0)
	_check(fishing.phase == Fishing.Phase.WAITING and is_equal_approx(fishing.remaining, 2.0) and demo.tutorial_step == 1, "The tutorial cast waits two seconds")
	fishing.advance(2.0)
	_check(demo.tutorial_step == 2 and fishing.target == 3 and fishing.locked.get("species") == Data.RIVER_CARP and fishing.locked.get("size") == 1,
		"The hook starts step 2 with a normal-size river carp")
	fishing.advance(Data.PREPARATION)
	fishing.advance(Data.FISH_TIME * 2.0)
	_check(fishing.is_busy() and fishing.round_action == Fishing.Action.TAP and fishing.progress == 0 and fishing.mistakes == 0,
		"The tutorial can miss repeatedly past the normal capture deadline")
	_start_retry()
	fishing.advance(fishing.get_target_time() - fishing._elapsed)
	_check(fishing.round_action == Fishing.Action.TAP, "The first successful action must be a tap")
	await _press_pull()
	_release_pull()
	_check(fishing.progress == 1 and fishing.last_judgement == Fishing.Judgement.PERFECT, "A perfect tap advances one point")
	fishing.advance(Data.ROUND_GAP)
	_check(fishing.round_action == Fishing.Action.HOLD, "A hold follows the tap")
	fishing.submit_direction((fishing.get_expected_direction() + 1) % 4)
	_check(fishing.last_message.contains("方向错误"), "Wrong directions show a correction")
	fishing.advance(Data.ROUND_GAP + fishing.get_target_time())
	await _press_pull()
	_release_pull()
	_check(fishing.phase == Fishing.Phase.FEEDBACK and fishing.last_message.contains("过早") and fishing.progress == 1, "Releasing the hold early preserves progress")
	fishing.advance(Data.ROUND_GAP + fishing.get_target_time())
	await _press_pull()
	fishing.advance(fishing._hold_duration)
	_release_pull()
	_check(fishing.progress == 2 and fishing.last_judgement == Fishing.Judgement.PERFECT, "A perfect hold leaves the required surge")
	fishing.advance(Data.ROUND_GAP + fishing.get_target_time())
	_check(fishing.round_action == Fishing.Action.SURGE, "The third round is a surge")
	await _press_pull()
	_release_pull()
	_check(fishing.last_message.contains("等金环") and fishing.progress == 2, "A premature surge release teaches the ring")
	fishing.advance(Data.ROUND_GAP + fishing.get_target_time())
	fishing.submit_direction(fishing.get_expected_direction())
	fishing.advance(fishing._surge_duration + fishing._release_half + 0.01)
	_check(fishing.last_message.contains("太晚") and fishing.progress == 2, "A late surge release gives its own correction")
	fishing.advance(Data.ROUND_GAP + fishing.get_target_time())
	await _press_pull()
	fishing.advance(fishing._surge_duration - fishing._release_lead)
	_check(fishing.phase == Fishing.Phase.RELEASE_WAIT and demo._tutorial_overlay._instructions.text.contains("松开"), "The gold ring updates the guide with the release prompt")
	_release_pull()
	_check(demo.tutorial_step == 3 and session.catches.is_empty() and session.essences[1] == 6 and not fishing.has_tutorial_catch(), "Landing the carp ends fishing protection and advances directly to brewing")

	_click(demo._alchemy_button)
	_check(demo._tutorial_overlay._opening.has_point(demo.alchemy.mix_button.get_rect().get_center()), "The brewing spotlight exposes the real action button")
	_key(KEY_SHIFT)
	_check(demo._tutorial_overlay._heading.text.contains("纯炼制药"), "The guide can recover from a different alchemy tab")
	_click(demo.alchemy._tab_buttons[0])
	_click(demo.alchemy.mix_button)
	_check(demo.tutorial_step == 4 and session.essences[Data.RIVER_CARP] == 3 and session.souls.size() == 1, "Refining yields two doses and guides reception")
	_key(KEY_Q)
	_check(demo._tutorial_overlay._opening.has_point(demo.soul_hud.get_rect().get_center())
		and demo._tutorial_overlay._opening.has_point(demo._dose_scroll.get_rect().get_center()), "Reception exposes the stat ranges and the medicine list together")
	_click(demo._dose_buttons[0])
	_check(demo.tutorial_step == 5 and demo._selected_dose == [false, session.potions[0].id] and session.is_eligible(demo.soul_hud.preview.after), "Selecting medicine previews admission and guides serving")
	_key(KEY_C)
	_check(demo.tutorial_step == 4, "Cancelling a selected dose returns to preview")
	_key(KEY_S)
	_click(demo._serve_button)
	_check(session.can_release(Session.TUTORIAL_GUEST_ID) and session.is_eligible(guest.stats) and session.essences[Data.RIVER_CARP] == 3 and session.potions.is_empty()
		and demo._tutorial_overlay._opening.has_point(demo._release_button.get_rect().get_center()), "One dose qualifies the postman and exposes release")
	_key(KEY_SHIFT)
	_check(demo.tutorial_step == 6 and session.released_count == 1 and session.tutorial_pause_arrivals and not demo._tutorial_overlay._opening.has_area(),
		"Release opens an unshaded summary while keeping the schedule paused")
	_key(KEY_ENTER)
	_check(demo.tutorial_completed and not demo.tutorial_active and not session.tutorial_pause_arrivals and session.total_guests() == 30,
		"Confirming the summary restores regular arrivals and keeps the five-day roster")
	session.advance(interval - 0.1)
	_check(session.souls.is_empty(), "The next guest receives the full arrival interval")
	session.advance(Data.ARRIVAL_MAX * 5)
	_check(session.souls.size() == 5 and not session.has_more_arrivals()
		and not session.souls[3].has("story_case") and not session.souls[3].has("anubis_disguise")
		and not session.souls[3].has("fixed_stats") and session.souls[4].get("story_case") == "wukong",
		"Five guests remain after the tutorial, with an ordinary fifth guest and Wukong last")
	session._open_day(2)
	session.souls.clear()
	session.advance(6.0 * Data.ARRIVAL_MAX)
	_check(session.souls.size() == 6 and session.souls.back().get("story_case") == "orpheus", "Orpheus keeps the sixth seat on day two")


func _check_skipping() -> void:
	await _new_demo()
	demo._start_game(true)
	demo.qte.cast()
	demo.qte.advance(2.0 + Data.PREPARATION)
	var interval := demo.session.spawn_remaining
	_click(demo._tutorial_overlay._skip_button)
	_check(demo.tutorial_completed and not demo.tutorial_active and not demo._tutorial_overlay._guide.visible
		and not demo.qte.has_tutorial_catch() and not demo.session.tutorial_pause_arrivals and demo.session.spawn_remaining == interval,
		"Clicking Skip in an active QTE clears protection and restores arrivals")
	demo.qte.advance(demo.qte.get_target_time())
	demo.qte.submit_direction(demo.qte.get_expected_direction())
	_check(demo.qte.last_progress_gain == 2, "A perfect hit after skipping uses normal scoring")
	demo.qte.advance(Data.ROUND_GAP + demo.qte.get_target_time() + Data.FISH_TIME)
	_check(demo.qte.phase == Fishing.Phase.ESCAPED, "Normal misses or timing can end a catch after skipping")

	await _new_demo()
	demo._start_game(true)
	demo.qte.cast()
	demo.qte.advance(2.0)
	_check(demo.qte.phase == Fishing.Phase.PREPARING and demo.qte.target == 3, "The first bite prepares the three-round lesson")
	_click(demo._tutorial_overlay._skip_button)
	var tier: int = Data.FISH[Data.RIVER_CARP].tier
	_check(demo.qte.target == Data.PROGRESS[tier][1] and not demo.qte.has_tutorial_catch(), "Skipping on the bite restores the ordinary progress target")

	await _new_demo()
	demo._start_game(true)
	demo.session.souls.clear()
	demo.session._day_arrived = 0
	demo.session._arrived = 0
	_click(demo._tutorial_overlay._skip_button)
	_check(demo.session.souls.is_empty(), "Skipping with no guest present does not spawn one")
	demo.session.advance(demo.session.spawn_remaining)
	_check(demo.session.souls.size() == 1, "A missing first guest arrives on the resumed timer")


func _check_tips() -> void:
	await _new_demo()
	demo._start_game(true)
	var session := demo.session
	session.essences[Data.RIVER_CARP] = 2
	demo._show_location("Alchemy")
	_check(demo.seen_tips.is_empty(), "Microtips stay off during the main tutorial")
	_click(demo._tutorial_overlay._skip_button)
	_expect_tip("tip_mix")
	var remaining := demo._tutorial_overlay._tip_remaining
	_key(KEY_ESCAPE)
	demo._tutorial_overlay._process(10.0)
	_check(demo._tutorial_overlay._tip_remaining == remaining and not demo._tutorial_overlay._tip.visible, "Pause freezes and hides a displayed tip")
	_key(KEY_ESCAPE)
	demo._tutorial_overlay._process(6.6)
	_check(demo._tutorial_overlay._tip.visible and demo._tutorial_overlay._tip.modulate.a < 1.0, "A tip fades near the end of its seven seconds")
	demo._tutorial_overlay._process(0.5)
	_check(demo._current_tip.is_empty() and not demo._tutorial_overlay._tip.visible, "The tip dismisses itself after seven seconds")
	demo._show_location("River")
	demo.qte.cast()
	demo._show_location("Alchemy")
	demo.qte.locked = {"species": Data.RIVER_CARP, "size": 1}
	demo.qte.phase = Fishing.Phase.AWAITING_RETURN
	demo.qte.remaining = Fishing.RETURN_LIMIT
	demo.qte.state_changed.emit()
	_expect_tip("tip_off_river_bite")
	_key(KEY_Q)
	_check(demo.current_location == "River" and demo.qte.phase == Fishing.Phase.PREPARING, "A tip leaves the urgent Q shortcut available")
	_close_tip()
	session.record_catch({"species": Data.RIVER_CARP, "size": 1, "cm": 10.0})
	_check(not demo.seen_tips.has("tip_codex"), "The codex tip waits while fish capture is in progress")
	demo.qte.retract()
	_expect_tip("tip_codex")
	_close_tip()
	demo.qte.bait_stock[demo.qte.bait] = 0
	demo.qte.state_changed.emit()
	_expect_tip("tip_market_supply")
	_close_tip()
	session.concentrate = 1
	session.state_changed.emit()
	_expect_tip("tip_concentrate")
	_close_tip()
	session.advance(5 * Data.ARRIVAL_MAX)
	demo._show_location("Shop")
	var story_soul: Dictionary = {}
	for soul in session.souls:
		if soul.get("story_case", "") == "wukong":
			story_soul = soul
			break
	demo.shop.select_guest(int(story_soul.id))
	_expect_tip("tip_story_guest")
	_close_tip()
	session._open_day(2)
	session.state_changed.emit()
	_expect_tip("tip_day2_upper")
	_close_tip()
	demo._show_location("Alchemy")
	session.state_changed.emit()
	demo.qte.state_changed.emit()
	_check(demo.seen_tips.size() == 7 and demo._pending_tips.is_empty() and demo._current_tip.is_empty(), "All seven tips are unique and repeated triggers stay silent")
	_check(demo.save_progress(3) and demo.load_progress(3) and demo.seen_tips.size() == 7 and demo._current_tip.is_empty(),
		"Tips remain deduplicated across a real save and load")


func _check_saves() -> void:
	await _new_demo()
	demo._start_game(true)
	var fishing := demo.qte
	var session := demo.session
	demo.qte.cast()
	fishing.advance(2.0 + Data.PREPARATION + fishing.get_target_time())
	fishing.submit_direction(fishing.get_expected_direction())
	fishing.advance(Data.ROUND_GAP + fishing.get_target_time())
	fishing.submit_direction(fishing.get_expected_direction())
	_check(fishing.phase == Fishing.Phase.HOLDING and demo.save_progress(0), "A tutorial hold can be saved in progress")
	demo._finish_tutorial()
	_check(demo.load_progress(0) and demo.tutorial_active and demo.tutorial_step == 2 and session.tutorial_pause_arrivals
		and fishing.has_tutorial_catch() and fishing.round_action == Fishing.Action.HOLD and fishing.progress == 1 and fishing.needs_rehold,
		"Reloading restores the held tutorial action and its protection")
	fishing.submit_direction(fishing.get_expected_direction())
	fishing.advance(fishing._hold_duration)
	fishing.advance(Data.ROUND_GAP + fishing.get_target_time())
	fishing.submit_direction(fishing.get_expected_direction())
	fishing.advance(fishing._surge_duration - fishing._release_lead)
	fishing.release_direction(fishing.get_expected_direction())
	_check(demo.tutorial_step == 3 and demo.save_progress(1), "The restored tutorial can catch its fish and save before brewing")
	var payload := SaveSlots.read(SaveSlots.existing_path(directory, 1))
	payload.tutorial.step = 1
	_check(SaveSlots.write(directory, 1, payload) and demo.load_progress(1) and demo.tutorial_step == 3 and not fishing.has_tutorial_catch(),
		"Restoring recomputes a stale step from the saved catch")
	session.brew(Data.RIVER_CARP)
	session.serve(Session.TUTORIAL_GUEST_ID, false, session.potions[-1].id)
	session.release_soul(Session.TUTORIAL_GUEST_ID)
	_check(demo.tutorial_step == 6 and demo.save_progress(2), "An unconfirmed summary can be saved")
	_check(demo.load_progress(2) and demo.tutorial_completed and not demo.tutorial_active and not session.tutorial_pause_arrivals,
		"A post-release save resumes at free duty")
	payload.erase("tutorial")
	_check(SaveSlots.write(directory, 4, payload) and demo.load_progress(4) and not demo.tutorial_active and demo.tutorial_completed
		and demo.seen_tips.is_empty() and not session.tutorial_pause_arrivals and not demo._tutorial_overlay._guide.visible,
		"A legacy save restores without a tutorial or microtips")


func _start_retry() -> void:
	if demo.qte.phase == Fishing.Phase.REELING:
		demo.qte.advance(demo.qte.remaining)
	if demo.qte.phase == Fishing.Phase.FEEDBACK:
		demo.qte.advance(Data.ROUND_GAP)


func _press_pull() -> void:
	_key(Fishing.DIRECTION_KEYS[demo.qte.get_expected_direction()], true)
	await process_frame


func _release_pull() -> void:
	_key(Fishing.DIRECTION_KEYS[demo.qte.get_expected_direction()], false, true)


func _expect_tip(id: String) -> void:
	_check(demo._current_tip == id and demo.seen_tips.has(id) and demo._tutorial_overlay._tip.visible, "%s displays on its first trigger" % id)


func _close_tip() -> void:
	_click(demo._tutorial_overlay._tip_close_button)


func _key(code: Key, keep_pressed: bool = false, release_only: bool = false) -> void:
	for pressed in ([false] if release_only else ([true] if keep_pressed else [true, false])):
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click(button: Button) -> void:
	_click_at(button.get_global_rect().get_center())


func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
