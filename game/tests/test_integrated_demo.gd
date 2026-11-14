extends SceneTree
## End-to-end input, cast timing, shared inventory and departure regression.
## Add -- --capture (without --headless) for real renderer checkpoints.

var demo
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.auto_pause_on_focus_loss = false
	root.add_child(demo)
	await process_frame
	_freeze()
	_check(not demo.started and demo._menu.visible, "Cover is the initial entry")
	_check(not demo.session.active and not demo.river.active and not demo.shop.active, "Menu cannot advance world clocks")
	var arrival: float = demo.session.spawn_remaining
	demo.session.advance(50.0)
	_key(KEY_SPACE)
	_check(demo.session.spawn_remaining == arrival and not demo.river.casting, "Cover Space creates neither fish nor time")
	await _capture("01-cover")
	_click(demo.start_button)
	_check(demo.started and demo.current_location == "River" and demo._river_image.visible, "Clicking Start opens the pixel river")
	_check(not demo._shop_image.visible and not demo._menu.visible, "Menu and shop stop covering the river")
	_check(demo.session.spawn_remaining == arrival and arrival >= 20.0 and arrival <= 25.0, "First demo guest keeps the same 20-to-25-second interval as later guests")
	demo.qte.random_fish_on_cast = false
	demo.qte.select_fish(0)
	await _capture("02-river")
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false, true)
	_key(KEY_SPACE, false, false, false)
	_check(not demo.river.casting, "Repeats, shortcuts and key releases cannot cast")
	_key(KEY_SPACE)
	_check(demo.river.casting and demo.qte.phase == DirectionFishing.Phase.READY, "Space begins artwork animation before the bite timer")
	_check(demo.river.get_cast_frame() == 0, "First pose starts at zero")
	await _capture("03-cast-1")
	demo.river.advance_cast(0.24)
	_key(KEY_SPACE)
	_check(demo.river.get_cast_frame() == 0 and is_equal_approx(demo.river.cast_elapsed, 0.24), "First frame lasts 0.25s and mashing cannot restart it")
	_key(KEY_E)
	var cast_clock: float = demo.river.cast_elapsed
	demo.river.advance_cast(9.0)
	_check(demo.current_location == "Shop" and demo.river.cast_elapsed == cast_clock, "Scene switch freezes an unfinished cast")
	demo.session.advance(demo.session.spawn_remaining)
	_check(demo.session.souls.size() == 1 and demo.shop.selected_id == 1, "Shared arrival reaches the shop while fishing is suspended")
	_key(KEY_Q)
	demo.river.advance_cast(0.01)
	_check(demo.river.get_cast_frame() == 1, "Second pose starts at 0.25s")
	await _capture("04-cast-2")
	_key(KEY_P)
	demo.river.advance_cast(100.0)
	_check(demo.river.get_cast_frame() == 1 and demo.session.paused, "Pause freezes the animation clock")
	_key(KEY_SPACE)
	_check(not demo.session.paused and demo.river.casting, "Space resumes without another cast")
	demo.river.advance_cast(0.25)
	_check(demo.river.get_cast_frame() == 2, "Third pose starts at 0.5s")
	await _capture("05-cast-3")
	demo.river.advance_cast(0.25)
	_check(demo.river.get_cast_frame() == 3, "Static pose starts at 0.75s")
	await _capture("06-cast-4")
	demo.river.advance_cast(0.24)
	_check(demo.qte.phase == DirectionFishing.Phase.READY, "Fourth pose is held for its full quarter-second")
	demo.river.advance_cast(0.01)
	_check(not demo.river.casting and demo.qte.phase == DirectionFishing.Phase.WAITING, "Bite timer starts exactly after all four poses")
	_check(is_equal_approx(demo.qte.remaining, demo.qte.bite_delay), "Animation consumes none of the original bite delay")
	await _capture("07-waiting")
	demo.qte.advance(demo.qte.bite_delay)
	demo.qte.advance(demo.qte.get_target_time())
	demo.river._process(0.25)
	var edge: Vector2 = demo.river.TIMING_FRAME.get_center() + DirectionFishing.VECTORS[demo.qte.fish_direction] * demo.river.TIMING_FRAME.size * 0.5
	_check(demo.river.get_water_entry().is_equal_approx(edge), "Dynamic line uses the actual original judgement clock")
	_check(not demo.river.get_rod_tip().is_equal_approx(demo.river.ROD_TIP), "Line start follows the transformed pixel rod tip")
	await _capture("08-perfect-window")
	var original_direction: int = demo.qte.fish_direction
	for direction in 4:
		demo.qte.fish_direction = direction
		demo.river._process(0.25)
		var visible_edge: Vector2 = demo.river.TIMING_FRAME.get_center() + DirectionFishing.VECTORS[direction] * demo.river.TIMING_FRAME.size * 0.5
		_check(demo.river.get_water_entry().is_equal_approx(visible_edge), "All four directions share visible line and judgement positions")
		await _capture("08-line-direction-%d" % direction)
	demo.qte.fish_direction = original_direction
	_key(KEY_E)
	var beat_clock: float = demo.qte.beat_elapsed
	await process_frame
	await process_frame
	_check(demo.qte.beat_elapsed == beat_clock, "Hidden fishing does not silently miss beats")
	_key(OS.find_keycode_from_string(demo.qte.get_expected_key()))
	_check(demo.qte.successful_pulls == 0, "Shop WASD never pulls a hidden fish")
	_key(KEY_Q)
	_key(KEY_X, false, false, true, OS.find_keycode_from_string(demo.qte.get_expected_key()))
	_check(demo.qte.successful_pulls == 2 and demo.qte.perfect_count == 1, "Original perfect judgement accepts physical WASD")
	demo.qte.advance(demo.qte.remaining)
	_key(OS.find_keycode_from_string(demo.qte.get_expected_key()))
	_check(demo.qte.phase == DirectionFishing.Phase.CAUGHT and demo.session.inventory == [1, 0, 0], "A real fish catch enters shared inventory exactly once")
	_key(KEY_W)
	_check(demo.session.get_inventory_total() == 1, "Extra keys cannot duplicate a catch")
	await _capture("09-caught")
	_key(KEY_E)
	_check(demo.shop.get_guest_pose() == "front" and not demo._feed_buttons[0].disabled, "Front-facing guest can eat the caught fish")
	_check(demo._feed_buttons[1].disabled and demo._feed_buttons[2].disabled, "Unavailable fish cannot be fed")
	await _capture("10-shop-guest")
	var selected: int = demo.shop.selected_id
	demo.session.advance(demo.session.spawn_remaining)
	_check(demo.shop.selected_id == selected, "New arrivals cannot change the feeding target")
	_click(demo._feed_buttons[0])
	_check(demo.session.inventory == [0, 0, 0] and demo.session.can_release(selected), "Mouse feeding consumes the actual fish and satisfies the first guest")
	demo.shop.advance_presentation(0.74)
	_check(not demo.shop.departing, "Feeding result is visible before turning")
	await _capture("11-fed")
	demo.shop.advance_presentation(0.02)
	_check(demo.shop.departing and demo.shop.get_guest_pose() == "turn", "Satisfied guest automatically turns toward the gate")
	_check(demo.session.get_soul(selected).is_empty() and demo.session.coins == 10, "Admission pays once and removes the served ID")
	_check(not demo.shop.feed(0) and not demo.shop.begin_departure(), "Departing guest cannot eat or settle twice")
	await _capture("12-turn")
	demo.shop.advance_presentation(0.4)
	_check(demo.shop.get_guest_pose() == "back", "Back-facing art replaces the face before walking away")
	demo.shop.advance_presentation(2.0)
	_check(demo.shop.get_guest_position().x > demo.shop.COUNTER.x and demo.shop.get_guest_position().y < demo.shop.COUNTER.y, "Guest follows the stone path toward the actual background gate")
	_check(demo.shop.get_guest_scale() < demo.shop.START_SCALE and demo.shop.get_guest_scale() > 0.36, "Guest shrinks with perspective")
	await _capture("13-walk")
	_key(KEY_P)
	var walk_clock: float = demo.shop.departure_elapsed
	demo.shop.advance_presentation(100.0)
	_check(demo.shop.departure_elapsed == walk_clock, "Pause freezes departure and settlement presentation")
	await _capture("14-paused")
	_key(KEY_Q)
	_check(demo.session.paused and demo.river.paused, "Changing view never bypasses pause")
	_key(KEY_SPACE)
	demo.shop.advance_presentation(100.0)
	_check(demo.shop.departure_elapsed == walk_clock, "Walking is retained while away from the shop")
	_key(KEY_E)
	demo.shop.advance_presentation(2.1)
	_check(demo.shop.get_guest_position().is_equal_approx(demo.shop.GATE), "Fade starts only after reaching the gate")
	await _capture("15-gate")
	demo.shop.advance_presentation(0.5)
	_check(not demo.shop.departing and demo.shop.selected_id == 2, "Guest disappears, then the next real soul takes the counter")
	_check(demo.session.released_count == 1 and demo.session.coins == 10, "Fade completion cannot award a second reward")
	for index in 7:
		demo.session.advance(demo.session.spawn_remaining)
	_check(demo._queue.item_count == demo.session.souls.size() and demo._queue.item_count > 6, "Scrollable queue keeps every soul accessible")
	await _capture("16-next-guest")
	root.size = Vector2i(960, 576)
	await process_frame
	_check(demo._feed_buttons[2].get_global_rect().end.x <= demo.get_viewport_rect().size.x, "Feed controls remain inside the logical viewport in a smaller window")
	await _capture("17-small-window")
	demo.queue_free()
	await process_frame
	print("Integrated demo: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _freeze() -> void:
	demo.session.set_process(false)
	demo.qte.set_process(false)
	demo.river.set_process(false)
	demo.shop.set_process(false)


func _key(code: Key, echo: bool = false, control: bool = false, pressed: bool = true, physical: Key = KEY_NONE) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code if physical == KEY_NONE else physical
	event.pressed = pressed
	event.echo = echo
	event.ctrl_pressed = control
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_freeze()


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	_freeze()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation/demo")
	var error := root.get_texture().get_image().save_png("res://build/validation/demo/%s.png" % label)
	_check(error == OK, "Saved rendered checkpoint " + label)
