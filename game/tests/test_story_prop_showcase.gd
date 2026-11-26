extends SceneTree
## Verifies prop-free portraits through real investigation and true-name input.

var _demo
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	_demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(_demo)
	_demo.auto_pause_on_focus_loss = false
	_demo.session.set_process(false)
	_demo.shop.set_process(false)
	_demo._start_story_lab()
	for sprite_id in ["wukong_disguise", "wukong_monkey", "orpheus_front", "orpheus_revealed"]:
		_demo._reset_story_lab()
		var wukong := str(sprite_id).begins_with("wukong")
		var named: bool = sprite_id in ["wukong_monkey", "orpheus_revealed"]
		var soul_id := 6 if wukong else 12
		var prop_id := "staff" if wukong else "lyre"
		if not wukong:
			_open_orpheus_day()
		_demo.shop.select_guest(soul_id)
		if named:
			_demo._story_action()
			var answer := "SUNWUKONG" if wukong else "ORPHEUS"
			for letter in answer:
				_demo._handle_game_key(OS.find_keycode_from_string(letter))
			_demo.story_director.skip()
			_demo._handle_game_key(KEY_F)
		_check(_demo.shop.story_sprite == sprite_id, "the expected identity is selected: " + str(sprite_id))
		var resting: Texture2D = _demo.shop.get_story_texture()
		var ui_transform: Transform2D = _demo._shop_ui.get_global_transform()
		var dialogue_scale: Vector2 = _demo._dialog.get_global_transform().get_scale()
		_click_hotspot(prop_id)
		_check(_demo.shop.is_showing_held_prop(), "investigation presents the held object: " + str(sprite_id))
		var empty: Texture2D = _demo.shop.get_story_texture()
		_check(empty == _demo.shop.PROP_FREE_SPRITES[sprite_id] and empty != resting, "the back object disappears: " + str(sprite_id))
		_check(_demo.shop.get_story_shadow() == _demo.shop.PROP_FREE_SHADOWS[sprite_id], "the carried object's old shadow disappears: " + str(sprite_id))
		_check(empty.get_size() == Vector2(48, 64), "the portrait keeps its exact canvas: " + str(sprite_id))
		var face := Rect2i(12, 6, 20, 28)
		_check(empty.get_image().get_region(face).get_data() == resting.get_image().get_region(face).get_data(), "the original face remains pixel-identical: " + str(sprite_id))
		await create_timer(0.3).timeout
		_check(is_equal_approx(_demo.story_stage.get_zoom_scale(), 1.12), "inspection smoothly zooms the shop by twelve percent: " + str(sprite_id))
		# Text wrapping can change a Label's minimum size without any camera zoom.
		_check(_demo._shop_ui.get_global_transform() == ui_transform and _demo._dialog.get_global_transform().get_scale().is_equal_approx(dialogue_scale), "the dialogue UI is not enlarged: " + str(sprite_id))
		if "--capture" in OS.get_cmdline_user_args():
			await process_frame
			var path := ProjectSettings.globalize_path("res://build/validation/story-showcase-%s.png" % str(sprite_id))
			root.get_texture().get_image().save_png(path)
		for _step in 2:
			_demo.story_director.skip()
			_demo._handle_game_key(KEY_F)
		_check(not _demo.shop.is_showing_held_prop() and _demo.shop.get_story_texture() == resting, "ending the inspection puts the object back: " + str(sprite_id))
		await create_timer(0.3).timeout
		_check(is_equal_approx(_demo.story_stage.get_zoom_scale(), 1.0), "ending inspection smoothly restores the camera: " + str(sprite_id))
		if sprite_id == "wukong_disguise":
			# Click the visible upper edge of the face after the zoom-out.
			# A stale enlarged hitbox misses this point.
			var portrait: Rect2 = _demo.shop.get_story_portrait_rect()
			var point := (portrait.position + Vector2(24, 22.25) * portrait.size.x / 48.0) * 4.0
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = point - _demo.story_hotspots.position
			_demo.story_hotspots._gui_input(click)
			_check(_demo.session.get_story_runtime(soul_id).get_node_id() == "inspect.photo", "investigation hitboxes follow the returning camera")
	_demo._reset_story_lab()
	_click_hotspot("staff")
	await create_timer(0.3).timeout
	_demo._set_paused(true)
	await create_timer(0.3).timeout
	_check(is_equal_approx(_demo.story_stage.get_zoom_scale(), 1.0), "pausing clears the inspection close-up")
	_demo._set_paused(false)
	await create_timer(0.3).timeout
	_check(is_equal_approx(_demo.story_stage.get_zoom_scale(), 1.12), "resuming restores the current inspection close-up")
	_demo._show_location("Alchemy")
	await create_timer(0.3).timeout
	_check(is_equal_approx(_demo.story_stage.get_zoom_scale(), 1.0), "leaving the reception restores the camera")
	_demo._show_location("Shop")
	await create_timer(0.3).timeout
	_check(is_equal_approx(_demo.story_stage.get_zoom_scale(), 1.12), "returning to the reception restores the current close-up")
	_demo._handle_game_key(KEY_N)
	_check(is_equal_approx(_demo.story_stage.get_zoom_scale(), 1.0) and not _demo.shop.is_showing_held_prop(), "resetting the lab clears the close-up")
	_demo.queue_free()
	await process_frame
	print("StoryPropShowcase: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _open_orpheus_day() -> void:
	var wukong = _demo.session.get_story_runtime(6)
	wukong.skip_dialogue()
	_check(wukong.choose("admit"), "Wukong's actual result opens the next story day")
	wukong.skip_dialogue()
	_demo._release_guest()
	_check(_demo.day_report.visible, "Orpheus' portrait test passes through day one's report")
	_demo._close_day_report()


func _click_hotspot(id: String) -> void:
	for entry in _demo.story_hotspots._entries:
		if str(entry.id) != id:
			continue
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = entry.rects[0].get_center()
		_demo.story_hotspots._gui_input(event)
		return
	_check(false, "missing investigation hotspot: " + id)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
