extends SceneTree
## Four-way actions, physical key lifecycle, pause/location resume and capture boundaries.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := Session.new()
	root.add_child(session)
	session.active = true
	session.set_process(false)
	var fishing := Fishing.new()
	fishing.session = session
	root.add_child(fishing)
	fishing.set_process(false)
	fishing.set_at_river(true)
	for species in Data.FISH.size():
		if species == Data.VARIANT:
			continue
		fishing.locked = {"species": species, "size": 1, "cm": 50.0}
		fishing._snapshot = {"attachments": 0}
		fishing._start_fish_capture()
		fishing.advance(fishing.remaining)
		_check(fishing.round_action == Data.FISHING_ACTION_PATTERNS[species][0], "Species starts its own action pattern")
		for action in [Fishing.Action.TAP, Fishing.Action.HOLD, Fishing.Action.SURGE]:
			_check(Data.FISHING_ACTION_PATTERNS[species].has(action), "Every ordinary species has all three actions")
	_model_checks(fishing)
	_all_captures(fishing)
	fishing.queue_free()
	session.queue_free()
	await process_frame
	await _live_checks()
	print("Four-way fishing: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _prepare(fishing, action: int) -> void:
	fishing.session.paused = false
	fishing.set_at_river(true)
	fishing.locked = {"species": 0, "size": 1, "cm": 5.0}
	fishing._snapshot = {"attachments": 0}
	fishing._start_fish_capture()
	fishing.advance(fishing.remaining)
	fishing.round_action = action
	fishing.progress = 0
	fishing.target = 100
	fishing.mistakes = 0
	fishing.last_judgement = Fishing.Judgement.NONE
	fishing.last_progress_gain = 0
	fishing.fish_direction = 2 # Fish down; W/up is the inverse pull.


func _press_at_line(fishing) -> void:
	fishing.advance(fishing.get_target_time())
	_check(fishing.submit_direction(0), "Correct opposite input at the edge is accepted")


func _model_checks(fishing) -> void:
	_prepare(fishing, Fishing.Action.TAP)
	fishing.advance(fishing.get_target_time() + fishing._perfect_half + 0.02)
	fishing.submit_direction(0)
	_check(fishing.progress == 1 and fishing.last_judgement == Fishing.Judgement.NORMAL, "Ordinary tap is one progress")
	fishing.release_direction(0)
	_check(not fishing.submit_direction(0) and fishing.progress == 1, "A completed action cannot score twice")
	_prepare(fishing, Fishing.Action.TAP)
	fishing.advance(0.01)
	fishing.submit_direction(0)
	_check(fishing.mistakes == 1 and fishing.progress == 0, "An early correct direction is one error at zero progress")
	_prepare(fishing, Fishing.Action.HOLD)
	_press_at_line(fishing)
	_check(fishing.is_holding() and fishing.progress == 0, "A hold head does not award progress")
	fishing.advance(0.20)
	var held_time: float = fishing._hold_elapsed
	fishing.submit_direction(0)
	_check(fishing._hold_elapsed == held_time and fishing.progress == 0, "Repeated held direction cannot restart or score the note")
	fishing.advance(fishing.remaining)
	_check(fishing.progress == 2 and fishing.phase == Fishing.Phase.FEEDBACK, "Full perfect hold scores exactly once")
	fishing.release_direction(0)
	_check(fishing.progress == 2 and fishing.mistakes == 0, "Release after completion cannot undo or repeat the score")
	_prepare(fishing, Fishing.Action.HOLD)
	_press_at_line(fishing)
	fishing.advance(0.20)
	fishing.release_direction(0)
	fishing.release_direction(0)
	_check(fishing.mistakes == 1, "Early hold release is one error, never per-frame damage")
	_prepare(fishing, Fishing.Action.SURGE)
	_press_at_line(fishing)
	fishing.advance(fishing.remaining)
	_check(fishing.phase == Fishing.Phase.RELEASE_WAIT and fishing.progress == 0, "Gold-ring cue opens before surge end without awarding progress")
	fishing.advance(fishing._release_lead)
	fishing.release_direction(0)
	_check(fishing.progress == 2 and fishing.last_judgement == Fishing.Judgement.PERFECT, "Timed surge release combines head and release accuracy")
	_prepare(fishing, Fishing.Action.SURGE)
	_press_at_line(fishing)
	fishing.advance(0.10)
	fishing.release_direction(0)
	_check(fishing.mistakes == 1, "Surge released before the cue fails once")
	_prepare(fishing, Fishing.Action.SURGE)
	_press_at_line(fishing)
	fishing.advance(fishing.remaining)
	fishing.advance(fishing.remaining)
	_check(fishing.mistakes == 1 and fishing.phase == Fishing.Phase.FEEDBACK, "Surge held beyond the late window fails once")
	_prepare(fishing, Fishing.Action.HOLD)
	_press_at_line(fishing)
	fishing.advance(0.10)
	fishing.suspend_pull()
	var clock: float = fishing.get_capture_time()
	var hold_clock: float = fishing._hold_elapsed
	fishing.advance(2.0)
	fishing.release_direction(0)
	_check(fishing.needs_rehold and fishing._hold_elapsed == hold_clock and fishing.get_capture_time() == clock and fishing.mistakes == 0, "Suspension neither advances nor interprets key-up as release")
	fishing.submit_direction(0)
	fishing.advance(fishing.remaining)
	_check(fishing.progress == 2 and not fishing.needs_rehold, "Rehold resumes the same remaining hold")
	_prepare(fishing, Fishing.Action.SURGE)
	_press_at_line(fishing)
	fishing.advance(fishing.remaining)
	fishing.session.paused = true
	clock = fishing.remaining
	fishing.advance(3.0)
	fishing.release_direction(0)
	_check(fishing.remaining == clock and fishing.mistakes == 0, "Paused release cue and capture timer remain frozen")
	fishing.session.paused = false
	_prepare(fishing, Fishing.Action.HOLD)
	_press_at_line(fishing)
	fishing._capture_remaining = 0.05
	fishing.advance(0.06)
	_check(fishing.phase == Fishing.Phase.ESCAPED, "Capture time limit also applies during a hold")
	_prepare(fishing, Fishing.Action.HOLD)
	fishing.target = 1
	var catches: int = fishing.session.catches.size()
	_press_at_line(fishing)
	_check(fishing.session.catches.size() == catches, "Hold head cannot prematurely award a fish")
	fishing.advance(fishing.remaining)
	fishing.release_direction(0)
	_check(fishing.phase == Fishing.Phase.CAUGHT and fishing.session.catches.size() == catches + 1, "Completed hold commits one fish exactly once")
	_prepare(fishing, Fishing.Action.TAP)
	fishing.locked = {"species": Data.VARIANT, "size": 3, "cm": 35.0}
	fishing._start_fish_capture()
	_check(fishing.phase == Fishing.Phase.TRUE_NAME and not fishing.submit_direction(0), "Giant true-name branch stays separate")
	# Equipment widening also widens the actual late-release expiry.
	fishing.locked = {"species": 0, "size": 1, "cm": 5.0}
	fishing._snapshot = {"attachments": 1}
	fishing._start_fish_capture()
	_check(is_equal_approx(fishing._release_half, Data.RELEASE_HALF_WINDOW[0] * (1.0 + Data.SLOT_BONUS)), "Equipment modifier is applied to release window")


func _all_captures(fishing) -> void:
	for species in Data.FISH.size():
		if species == Data.VARIANT:
			continue
		for size in 3:
			for perfect in [false, true]:
				_prepare(fishing, Fishing.Action.TAP)
				fishing.locked = {"species": species, "size": size, "cm": 50.0}
				fishing._start_fish_capture()
				var catches: int = fishing.session.catches.size()
				var guard := 0
				while fishing.is_busy() and guard < 100:
					guard += 1
					match fishing.phase:
						Fishing.Phase.REELING:
							fishing.advance(fishing.get_target_time() + (0.0 if perfect else fishing._perfect_half + 0.02))
							fishing.submit_direction(fishing.get_expected_direction())
						Fishing.Phase.RELEASE_WAIT:
							fishing.advance(fishing._release_lead)
							fishing.release_direction(fishing.get_expected_direction())
						_:
							fishing.advance(fishing.remaining)
				_check(fishing.phase == Fishing.Phase.CAUGHT and fishing.mistakes == 0 and fishing.session.catches.size() == catches + 1, "Species %d size %d perfect=%s captures within the time budget without errors or duplicate inventory" % [species, size, perfect])


func _live_checks() -> void:
	root.size = Vector2i(1620, 972)
	var demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.auto_pause_on_focus_loss = false
	demo.persist_save = false
	root.add_child(demo)
	await process_frame
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	for node in [demo.session, demo.qte, demo.river, demo.shop]:
		node.set_process(false)
	_prepare(demo.qte, Fishing.Action.HOLD)
	demo.qte.advance(demo.qte.get_target_time())
	_key(KEY_W, true)
	await process_frame
	_check(demo.qte.is_holding() and demo.qte.progress == 0, "Live physical key-down starts a hold")
	demo.qte.advance(0.20)
	_key(KEY_P, true)
	_key(KEY_P, false)
	_key(KEY_W, false)
	_check(demo.session.paused and demo.qte.needs_rehold and demo.qte.mistakes == 0, "Live pause does not turn key release into an error")
	_key(KEY_P, true)
	_key(KEY_P, false)
	var held_clock: float = demo.qte._hold_elapsed
	demo.qte.advance(2.0)
	_check(demo.qte._hold_elapsed == held_clock and "重新按住" in demo.qte.get_action_prompt(), "Resume waits for a physical rehold")
	_key(KEY_W, true)
	await process_frame
	demo.qte.advance(demo.qte.remaining)
	_key(KEY_W, false)
	_check(demo.qte.progress == 2 and demo.qte.mistakes == 0, "Live rehold completes the same action once")
	demo._clear_pull_input()
	_prepare(demo.qte, Fishing.Action.SURGE)
	demo.qte.advance(demo.qte.get_target_time())
	_key(KEY_W, true)
	await process_frame
	demo.qte.advance(0.20)
	_key(KEY_E, true)
	_key(KEY_E, false)
	_key(KEY_W, false)
	_check(demo.current_location == "Shop" and demo.qte.needs_rehold, "Leaving the river suspends a long action")
	held_clock = demo.qte._hold_elapsed
	demo.qte.advance(2.0)
	_key(KEY_Q, true)
	_key(KEY_Q, false)
	_check(demo.qte._hold_elapsed == held_clock and demo.qte.mistakes == 0, "Location transition does not expire or complete the hold")
	_key(KEY_W, true)
	await process_frame
	demo.qte.advance(demo.qte.remaining)
	demo._refresh_river()
	_check(demo.qte.phase == Fishing.Phase.RELEASE_WAIT and "松开" in demo._river_hint.text, "Live HUD announces release while the gold ring is active")
	await _capture("03-release", demo)
	demo.qte.advance(demo.qte._release_lead)
	_key(KEY_W, false)
	_check(demo.qte.progress == 2 and demo.qte.mistakes == 0, "Physical key-up completes a timed surge")
	demo._clear_pull_input()
	_prepare(demo.qte, Fishing.Action.HOLD)
	demo.qte.advance(demo.qte.get_target_time())
	_key(KEY_W, true)
	_key(KEY_W, false)
	await process_frame
	_check(demo.qte.mistakes == 1, "Quick press/release in one deferred frame cannot auto-hold")
	demo._clear_pull_input()
	_prepare(demo.qte, Fishing.Action.TAP)
	demo.qte.advance(demo.qte.get_target_time())
	_key(KEY_W, true)
	_key(KEY_D, true)
	await process_frame
	_key(KEY_W, false)
	_key(KEY_D, false)
	_check(demo.qte.mistakes == 1, "Simultaneous opposing directions count as one error")
	demo._clear_pull_input()
	_prepare(demo.qte, Fishing.Action.HOLD)
	demo.qte.advance(demo.qte.get_target_time())
	_key(KEY_W, true)
	await process_frame
	_key(KEY_UP, true)
	await process_frame
	_key(KEY_W, false)
	_check(demo.qte.is_holding() and demo.qte.mistakes == 0, "Releasing WASD while its arrow alias is held preserves the hold")
	demo.qte.advance(demo.qte.remaining)
	_key(KEY_UP, false)
	_check(demo.qte.progress == 2, "Arrow alias hold finishes once")
	# Actual scene screenshots at each playable stage; all images come from the engine.
	for action in [Fishing.Action.TAP, Fishing.Action.HOLD]:
		demo._clear_pull_input()
		_prepare(demo.qte, action)
		demo.qte.advance(demo.qte.get_target_time() * (0.8 if action == Fishing.Action.TAP else 1.0))
		if action == Fishing.Action.HOLD:
			_key(KEY_W, true)
			await process_frame
			demo.qte.advance(0.20)
		demo._refresh_river()
		await _capture("01-tap" if action == Fishing.Action.TAP else "02-hold", demo)
		_key(KEY_W, false)
	demo.queue_free()
	await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _capture(label: String, demo) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	demo.river.hit_timer = 0.0
	demo.qte.target = Data.PROGRESS[Data.FISH[demo.qte.locked.species].tier][demo.qte.locked.size]
	demo._refresh_river()
	demo.river.queue_redraw()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation/four-way")
	_check(root.get_texture().get_image().save_png("res://build/validation/four-way/%s.png" % label) == OK, "Saved actual scene " + label)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
