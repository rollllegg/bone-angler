extends SceneTree
## Exercises the special guests through the shared reception UI.

const Audio := preload("res://scripts/demo/demo_audio.gd")
const CLICK_SOUND := preload("res://assets/audio/ui_click.wav")
const WUKONG_LINE := "喂，你这妖精，还不赶快放俺老s……俺史密斯过去。"
const ORPHEUS_LINE := "欧律狄刻......"

var _demo
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	_demo = preload("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(_demo)
	_demo.persist_save = false
	_demo.auto_pause_on_focus_loss = false
	_demo.session.set_process(false)
	_demo.shop.set_process(false)
	_demo._start_game()
	_press(KEY_E)
	var session = _demo.session
	session.essences.fill(0)

	_arrive(4)
	_check(session.souls.all(func(soul: Dictionary) -> bool: return not soul.has("story_case")), "Day one starts with four ordinary guests")
	_check(not _demo._story_action_button.visible, "Ordinary guests show only the existing release button")
	_check(not _demo.soul_hud._bar_labels[0].text.contains("?"), "Ordinary guest attributes stay visible")
	_arrive(1)
	var ordinary: Dictionary = session.souls[4]
	_check(not ordinary.name.is_empty() and not ordinary.has("story_case") and not ordinary.has("fixed_stats") and not ordinary.has("anubis_disguise"), "The fifth guest is an ordinary NPC")
	_check(not session.can_release(int(ordinary.id)), "The fifth guest must meet the ordinary requirements")
	_demo.shop.select_guest(int(ordinary.id))
	_demo._refresh_shared()
	_check(_demo.soul_hud._state_label.text == "待调配", "The fifth guest HUD shows that medicine is required")
	for axis in 3:
		if session.requirements[0][axis] > 0 or session.requirements[1][axis] < 10:
			_check(_demo.soul_hud._status_labels[axis].text != "免检", "The fifth guest HUD checks each required attribute")
	_arrive(1)
	_check(str(session.souls[5].get("story_case", "")) == "wukong", "Wukong is the sixth and final guest on day one")
	_demo.shop.select_guest(6)
	_check_reception(WUKONG_LINE, "史密斯", "wukong_disguise")
	var wukong = session.get_story_runtime(6)
	_check(wukong.has_pending_steps() and _demo.story_hotspots.visible, "Investigation is available during the greeting")
	_check(_demo._dialog_hint.visible and _demo._dialog_hint.text == "F 继续", "The speech bubble shows its F prompt")
	_press(KEY_SPACE)
	_check(wukong.get_node_id() == "arrival", "Space does not advance dialogue")
	await _capture("story-reception-wukong.png")

	_check(wukong.is_awaiting_choice() and _demo.story_hotspots.visible, "The greeting does not gate portrait hotspots")
	_check(_demo.story_hotspots._entries.size() == 2, "Wukong exposes two investigation hotspots")
	_check(_hotspot_ids() == ["photo", "staff"], "Wukong has face and staff hotspots, with no tail investigation")
	for entry in _demo.story_hotspots._entries:
		_check(not entry["rects"].is_empty() and entry["rects"][0].size.x > 0.0, "Hotspot %s has a screen rect" % entry["id"])
	_demo._codex_tab()
	_check(session.paused and _demo._codex.is_open, "Tab opens the field guide over the reception")
	_check(not _demo.story_hotspots.visible, "Hotspots step aside while the field guide is open")
	_demo._set_paused(false)
	_check(not session.paused and _demo.story_hotspots.visible, "Closing the field guide restores the hotspots")
	await _capture("story-hotspots-wukong.png")

	# Investigate directly from the greeting, without advancing it first.
	_click_hotspot("photo")
	_check(wukong.get_node_id() == "inspect.photo", "Clicking the face directly opens its inspection")
	_check(_demo._dialog.text == "你说俺脸上有毛……哈哈，俺天生毛长得快，死前没洁面。", "Inspection dialogue has no speaker prefix")
	_check(not _demo.story_hotspots.visible, "Hotspots hide while the inspection line plays")
	_press(KEY_SPACE)
	_check(wukong.get_node_id() == "inspect.photo", "Space cannot dismiss an investigation line")
	_advance_story()
	_check(wukong.is_awaiting_choice() and _demo.story_hotspots.visible and not _demo._dialog_hint.visible, "F finishes the inspection and hides the continuation prompt")
	_check(_hotspot_locked("photo"), "The inspected face stays visible and marked as investigated")
	_click_hotspot("photo")
	_check(wukong.get_node_id() == "inspect", "Clicking an investigated hotspot does nothing")
	await _capture("story-hotspots-investigated.png")

	# Potion reaction is shown, not skipped.
	session._add_potion("test", "暖心药", Vector3i(0, 4, 0), -1, 0)
	session.state_changed.emit()
	_press(KEY_S)
	_check(not _demo._serve_button.disabled and _demo._serve_button.text.begins_with("空格"), "The ordinary dose button is ready")
	_press(KEY_F)
	_check(not wukong.has_fed_potion() and session.potions.size() == 1, "F does not serve a potion")
	_press(KEY_SPACE)
	_check(wukong.has_fed_potion() and session.potions.is_empty(), "Space serves the selected potion once")
	_check(_demo._dialog.text.begins_with("俺已成正法") and _demo._dialog_hint.visible, "Potion reaction is displayed without a speaker prefix")
	_check(_demo.soul_hud.preview.is_empty(), "Giving medicine keeps the hidden attributes")
	_advance_story()
	_check(wukong.is_awaiting_choice(), "Potion reaction returns to the investigation")

	_click_hotspot("staff")
	_check(wukong.get_node_id() == "inspect.staff", "Clicking the staff opens its inspection")
	_check(_demo.story_stage.get_prop_ids().has("staff") and _demo.shop.story_props.layer_for("staff") == "front", "Wukong takes out the standalone staff in front of himself")
	_check(_demo.shop.get_story_texture() == _demo.shop.PROP_FREE_SPRITES["wukong_disguise"], "showing the staff removes it from Wukong's back")
	await _capture("story-wukong-staff.png")
	_advance_story()
	_check(_demo.story_stage.get_prop_ids().has("staff"), "The whole staff stays visible through its description")
	_demo.shop.select_guest(int(ordinary.id))
	_check(_demo.story_stage.get_prop_ids().is_empty(), "Switching guests clears the displayed object")
	_demo.shop.select_guest(6)
	_check(_demo.story_stage.get_prop_ids().has("staff"), "Returning to the second line restores the displayed staff")
	_advance_story()
	_check(wukong.is_awaiting_choice() and _hotspot_locked("staff") and not _demo.story_stage.get_prop_ids().has("staff"), "Finishing the description puts the staff away")
	_check(_demo.shop.get_story_texture() == _demo.shop.STORY_SPRITES["wukong_disguise"], "putting the staff away restores Wukong's carried sprite")
	_check(_demo.story_hotspots._entries.all(func(entry: Dictionary) -> bool: return bool(entry["locked"])), "All investigated hotspots stay visible")

	_press(KEY_D)
	_check(_demo.shop.selected_id != 6 and not _demo._story_action_button.visible and not session.get_soul(_demo.shop.selected_id).has("story_case"), "D switches back to normal reception")
	_demo.shop.select_guest(6)
	_demo._story_action_button.pressed.emit()
	_check(_demo.story_panel.visible and _demo.story_panel.is_typing() and session.story_open, "Clicking true name starts the typing challenge")
	_check(_demo.story_panel._bubbles.get_child_count() == 9 and _bubble_letter(0) == "·", "Wukong has nine hidden letters")
	_check(_demo._release_button.disabled and _demo._story_action_button.text.contains("Esc"), "Only the cancel action stays available while typing")
	_press(KEY_SHIFT)
	_check(not wukong.is_closed(), "Release cannot bypass typing")
	_press(KEY_X)
	_check(_demo.story_panel._typing.mistakes == 1, "A wrong letter resets the challenge")
	_press(KEY_ESCAPE)
	_check(not _demo.story_panel.visible and not session.story_open and _demo._story_action_button.text == "真名解放", "Escape cancels and restores the original action")
	_demo._story_action_button.pressed.emit()
	_demo.story_panel._process(21.0)
	_check(not _demo.story_panel.is_typing() and not wukong.is_identity_revealed(), "Timeout leaves Wukong disguised")
	_demo._story_action_button.pressed.emit()
	await _capture("story-reception-callout.png")
	_type_name("SUNWUKONG")
	_check_reveal(wukong, "孙悟空", "wukong_monkey")
	await _capture("story-reception-wukong-revealed.png")
	_advance_story()
	_check(wukong.is_awaiting_choice() and _demo.story_hotspots.visible, "Revealed Wukong keeps his portrait hotspots")
	await _capture("story-hotspots-wukong-revealed.png")
	_demo._story_action_button.pressed.emit()
	_check(session.get_soul(6).is_empty() and session.rejected_count == 1, "The new action refuses and removes Wukong")
	_check(session.story_state.ledger[0].who == "孙悟空", "The ledger records the revealed name")

	_finish_ordinary_guests()
	_check(_demo.day_report.visible and session.get_day_report().day == 1, "Wukong's aftermath is shown at the end of day one")
	var click_player := _demo._audio._players.get(Audio.Cue.UI_CLICK) as AudioStreamPlayer
	if click_player != null and click_player.playing:
		await click_player.finished
		await process_frame
	if click_player != null:
		click_player.stream = null
	var next_day := _demo.day_report._close as Button
	_click(next_day)
	_check(session.day == 2 and not session.awaiting_day_report, "Closing the report allows the next day")
	_demo.shop.clear_departures()
	click_player = _demo._audio._players.get(Audio.Cue.UI_CLICK) as AudioStreamPlayer
	_check(click_player != null and click_player.stream == CLICK_SOUND, "Clicking Next Day triggers the UI click cue")
	_arrive(5)
	_check(session.souls.all(func(soul: Dictionary) -> bool: return not soul.has("story_case")), "Day two starts with five ordinary guests")
	_arrive(1)
	_check(str(session.souls[5].get("story_case", "")) == "orpheus", "Orpheus is the sixth guest on day two")
	_demo.shop.select_guest(12)
	_check_reception(ORPHEUS_LINE, "亚历克斯", "orpheus_front")
	var orpheus = session.get_story_runtime(12)
	_check(orpheus.is_awaiting_choice() and _demo.story_hotspots.visible, "Orpheus immediately offers investigation")
	_check(_demo.story_hotspots._entries.size() == 1, "Orpheus exposes only the lyre hotspot")
	_check(_hotspot_ids() == ["lyre"], "Orpheus has no face investigation")
	await _capture("story-hotspots-orpheus.png")

	_click_hotspot("lyre")
	_check(orpheus.get_node_id() == "inspect.lyre", "Clicking the lyre opens its inspection")
	_check(_demo._dialog.text == "你要看我的里拉琴？" and _demo.story_stage.get_prop_ids().has("lyre"), "The standalone lyre is shown with the requested line")
	_check(_demo.shop.story_props.layer_for("lyre") == "front", "The whole lyre appears in front of the NPC")
	_check(_demo.shop.get_story_texture() == _demo.shop.PROP_FREE_SPRITES["orpheus_front"], "showing the lyre removes the old instrument from Orpheus' back")
	await _capture("story-orpheus-lyre.png")
	_advance_story()
	_check(orpheus.is_awaiting_choice() and _hotspot_locked("lyre") and not _demo.story_stage.get_prop_ids().has("lyre"), "F puts the lyre away and returns to investigation")
	_check(_demo.shop.get_story_texture() == _demo.shop.STORY_SPRITES["orpheus_front"], "putting the lyre away restores Orpheus' carried sprite")

	_demo._story_action_button.pressed.emit()
	_check(_demo.story_panel._bubbles.get_child_count() == 7 and _bubble_letter(0) == "·", "Orpheus has seven hidden letters")
	_type_name("ORPHEUS")
	_check_reveal(orpheus, "俄耳普斯", "orpheus_revealed")
	await _capture("story-reception-orpheus-revealed.png")
	_advance_story()
	_check(orpheus.is_awaiting_choice(), "The true-name line returns to the investigation")
	_check(_demo.story_hotspots.visible and _hotspot_ids() == ["lyre"], "Revealed Orpheus keeps only his lyre hotspot")
	await _capture("story-hotspots-orpheus-revealed.png")
	session._add_potion("test", "极识药", Vector3i(10, 0, -4), -1, 0)
	session.state_changed.emit()
	_press(KEY_S)
	_press(KEY_SPACE)
	_check(orpheus.has_fed_potion() and _demo._dialog.text == "......好吧", "Orpheus uses the requested short potion reaction")
	_advance_story()
	_check(orpheus.is_awaiting_choice() and not bool(orpheus.flags["confused"]), "The potion branch clears Orpheus' confusion")
	_press(KEY_SHIFT)
	_check(session.get_soul(12).is_empty() and orpheus.get_outcome_id() == "accepted.reunion", "Shift admits Orpheus and preserves the cross-day ending")
	_finish_ordinary_guests()
	_check(session.get_day_report().entries.size() == 1 and session.get_day_report().day == 2, "Orpheus has his own day-two report")
	if click_player != null and click_player.playing:
		await click_player.finished
		await process_frame
	if click_player != null:
		click_player.stream = null
	_press(KEY_ENTER)
	_check(session.day == 3 and click_player != null and click_player.stream == CLICK_SOUND, "Keyboard confirmation advances the day and triggers the UI click cue")

	for player: AudioStreamPlayer in _demo._audio._players.values():
		var clip := player.stream as AudioStreamWAV
		if player.playing and clip != null and clip.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			await player.finished
	_demo.queue_free()
	await process_frame
	print("StoryUI: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_reception(line: String, alias: String, portrait: String) -> void:
	_check(_demo._dialog.visible and _demo._dialog.text == line and not _demo.story_panel.visible, "The shared speech bubble shows only dialogue text")
	_check(_demo.soul_hud.visible and _demo.soul_hud._name_label.text == alias, "The normal HUD displays the guest's alias")
	_check(_demo.soul_hud._bar_labels.all(func(label: Label) -> bool: return label.text.ends_with(" ?")), "All three attributes are unknown")
	_check(_demo._story_action_button.visible and _demo._story_action_button.text == "真名解放", "The extra bottom-right action is immediately available")
	_check(_demo._release_button.get_rect().end.x <= _demo._story_action_button.position.x, "Release and true name buttons do not overlap")
	_check(_demo.shop.story_sprite == portrait, "The guest portrait uses the story sprite")
	_check(_demo.story_hotspots.visible, "Hotspots are available without advancing the greeting")


func _check_reveal(runtime, name: String, portrait: String) -> void:
	_check(runtime.is_identity_revealed() and not _demo.story_panel.visible, "Correct letters complete the challenge")
	_check(_demo.shop.story_sprite == portrait and _demo.soul_hud._name_label.text == name, "The true portrait and name appear immediately")
	_check(_demo._story_action_button.text == "拒绝入境", "Refusal replaces true name")
	_check(_demo._dialog.text == str(runtime.current_step().get("text", "")), "The true-name line has no speaker prefix")
	_check(not _demo.story_hotspots.visible, "Hotspots stay hidden during the true-name line")


func _advance_story() -> void:
	if _demo.story_director.blocks_advance():
		_demo.story_director.skip()
	_press(KEY_F)


func _click_hotspot(id: String) -> void:
	for entry in _demo.story_hotspots._entries:
		if str(entry["id"]) != id:
			continue
		var point: Vector2 = entry["rects"][0].get_center()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = point
		_demo.story_hotspots._gui_input(event)
		return
	_check(false, "hotspot exists: " + id)


func _hotspot_ids() -> Array:
	return _demo.story_hotspots._entries.map(func(entry: Dictionary) -> String: return str(entry["id"]))


func _hotspot_locked(id: String) -> bool:
	for entry in _demo.story_hotspots._entries:
		if str(entry["id"]) == id:
			return bool(entry["locked"])
	return false


func _press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	_demo._unhandled_key_input(event)


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _type_name(value: String) -> void:
	for letter in value:
		_press(OS.find_keycode_from_string(letter))


func _bubble_letter(index: int) -> String:
	var bubble: PanelContainer = _demo.story_panel._bubbles.get_child(index)
	return (bubble.get_child(0) as Label).text


func _arrive(count: int) -> void:
	for _guest in count:
		_demo.session.spawn_remaining = 0.0
		_demo.session.advance(0.01)


func _finish_ordinary_guests() -> void:
	var session = _demo.session
	for soul in session.souls.duplicate():
		soul.stats = session.requirements[0]
		_check(session.release_soul(int(soul.id)), "An eligible ordinary guest can still be released")


func _capture(file_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	var directory := ProjectSettings.globalize_path("res://build/validation")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(file_name))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
