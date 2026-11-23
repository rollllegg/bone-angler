extends SceneTree
## Opens the real demo scene, selects Wukong, types SUNWUKONG and resolves the case.

var _checks := 0
var _failures := 0
var _demo = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_demo = load("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(_demo)
	await process_frame
	_demo.persist_save = false
	_demo.started = true
	_demo.session.start_shift()
	_demo.session._open_day(5)
	_demo.session.active = true
	for _guest in 6:
		_demo.session.spawn_remaining = 0.0
		_demo.session.advance(0.01)
	_demo._show_location("Shop")
	_demo._refresh_shared()
	await process_frame

	var soul_id := -1
	for soul in _demo.session.souls:
		if soul.has("story_case"):
			soul_id = int(soul.id)
			break
	_check(soul_id > 0, "story guest is in the queue")
	_demo.shop.select_guest(soul_id)
	_demo._refresh_shared()
	await process_frame

	_check(_demo.story_panel.visible, "story panel opens")
	_check(not _demo._dialog.visible, "normal dialog is hidden")
	_check(not _demo._release_button.visible, "normal release is hidden")
	_check(_demo._serve_button.text.contains("请他"), "serve button changes label")

	var runtime = _demo.session.get_story_runtime(soul_id)
	_check(runtime != null, "runtime exists")
	_check(_demo.session.is_time_suspended(), "open story pauses the shift")
	_check(runtime.advance(), "Wukong arrival advances to the speaker")
	_demo._refresh_shared()
	_check(_demo.story_panel._speaker.text == "史密斯", "Wukong speaker uses the alias before the callout")
	_check(_demo.shop.story_sprite == "wukong_disguise", "Wukong starts with the disguise portrait")
	await _capture("story-panel-alias.png")
	_advance_until_choices(runtime)
	_demo._refresh_shared()
	_check(_demo.story_panel._buttons.size() == 4, "four clue buttons render")
	_check(_demo.story_panel._decision_buttons.size() == 2, "accept and refuse are separate")
	_check(_demo.story_panel._decision_buttons[0].text == "接受入境", "accept button label")
	_check(_demo.story_panel._decision_buttons[1].text == "拒绝入境", "refuse button label")
	var accept_fill := _decision_fill(0)
	var refuse_fill := _decision_fill(1)
	_check(accept_fill.g > accept_fill.r, "accept button is green")
	_check(refuse_fill.r > refuse_fill.g, "refuse button is red")
	_check(_demo.story_panel._decision_buttons[0].position.y >= 500, "decision buttons sit at the bottom")
	_check(_demo.story_panel._callout_button.visible, "callout button renders")
	_check(_demo.story_panel._callout_button.text.contains("叫破"), "callout button has the right label")
	await _capture("story-panel.png")

	# The tail clue drives the first prop cue end to end.
	_check(_demo.story_stage != null, "story stage is bound to the demo")
	_demo._story_choice("tail")
	_demo._refresh_shared()
	_check(_demo.story_stage.has_prop("tail"), "tail prop appears with the clue line")
	await _capture("story-panel-effects-tail.png")
	_demo._story_advance()
	_demo._refresh_shared()
	await _capture("story-panel-effects-shake.png")
	_check(_demo.story_panel.blocks_advance(), "tail reaction blocks on its cue")
	var step_before_skip: int = runtime.step_index
	var space_event := InputEventKey.new()
	space_event.physical_keycode = KEY_SPACE
	space_event.pressed = true
	_demo._unhandled_key_input(space_event)
	_check(runtime.step_index == step_before_skip, "Space skips the cue group without advancing")
	_check(not _demo.story_stage.has_prop("tail"), "skipping settles the tail to hidden")
	_demo._story_advance()
	_demo._refresh_shared()
	_advance_until_choices(runtime)
	_demo._refresh_shared()
	_check(_demo.story_panel._buttons.size() == 4, "the used tail clue stays in the hub")
	_check(_demo.story_panel._buttons[1].disabled, "the used tail clue is grayed out")
	_check(_demo.story_panel._buttons[1].text.contains("已调查"), "the used tail clue explains why it is disabled")
	_demo._story_choice("staff")
	_demo._refresh_shared()
	_check(_demo.story_stage.has_prop("staff"), "staff prop appears with the back clue")
	await _capture("story-panel-effects-staff.png")
	_advance_until_choices(runtime)
	_demo._refresh_shared()
	_check(_demo.story_panel._buttons.size() == 4, "used clues stay in the hub")
	_check(_demo.story_panel._buttons[2].disabled, "the used staff clue is grayed out")
	await _capture("story-panel-used-choices.png")

	# Typed callout: enter the mode and type the real name.
	_demo.story_panel._callout_button.pressed.emit()
	_check(_demo.story_panel.is_typing(), "callout enters typing mode")
	_check(_demo.story_panel._bubbles.visible, "letter bubbles appear")
	_check(_demo.story_panel._bubbles.get_child_count() == 9, "SUNWUKONG renders nine bubbles")
	_check(_bubble_letter(_demo.story_panel._bubbles, 0) == "·", "Wukong callout hides the first letter")
	_check(not _demo.story_panel._callout_button.visible, "callout button hides while typing")
	_check(_demo.story_panel._cancel_button.visible, "cancel button appears while typing")
	await _capture("story-panel-callout.png")
	var esc_event := InputEventKey.new()
	esc_event.physical_keycode = KEY_ESCAPE
	esc_event.pressed = true
	_demo._unhandled_key_input(esc_event)
	_check(not _demo.story_panel.is_typing(), "Escape cancels the callout")
	_check(_demo.current_location == "Shop", "cancel stays in the shop")
	_check(_demo.story_panel._callout_button.visible, "callout button returns after cancel")
	_demo.story_panel._callout_button.pressed.emit()
	_check(_demo.story_panel.is_typing(), "callout can restart after cancel")
	var q_event := InputEventKey.new()
	q_event.physical_keycode = KEY_Q
	q_event.pressed = true
	_demo._unhandled_key_input(q_event)
	_check(_demo.current_location == "Shop", "Q is captured by the callout, not the river shortcut")
	_check(_demo.story_panel._typing.mistakes == 1, "wrong typed letter counts as a miss")
	for index in "SUNWUKONG".length():
		_demo.story_panel.submit_letter("SUNWUKONG".substr(index, 1))
	_check(bool(runtime.flags["named"]), "typing the name sets named")
	_check(bool(runtime.flags["callout.done"]), "typed callout marks itself done")
	_demo._refresh_shared()
	_check(_demo.shop.story_sprite == "wukong_monkey", "Wukong reveal swaps to the monkey portrait")
	await _capture("story-panel-wukong-monkey.png")
	_advance_until_choices(runtime)
	_demo._refresh_shared()
	_check(not _demo.story_panel._callout_button.visible, "callout button stays hidden after success")
	_demo._story_choice("photo")
	_check(runtime.advance(), "Wukong photo advances to the speaker")
	_demo._refresh_shared()
	_check(_demo.story_panel._speaker.text == "孙悟空", "Wukong speaker uses the real name after the callout")
	await _capture("story-panel-realname.png")
	_advance_until_choices(runtime)

	# Feed a hot potion through the shared dose controls.
	_demo.session._add_potion("test", "暖心药", Vector3i(0, 4, 0), -1, 0)
	_demo._selected_dose = [false, int(_demo.session.potions[0]["id"])]
	_demo._refresh_dose()
	_check(not _demo._serve_button.disabled, "serve button enables with a dose")
	_demo._serve_dose()
	_check(runtime.has_fed_potion(), "UI feeds the potion")
	await _capture("story-panel-effects-bowl.png")
	_advance_until_choices(runtime)
	_check(bool(runtime.flags["rage"]), "hot potion keeps rage")

	# Refuse: the reception ends at once; the aftermath is deferred to the day report.
	_demo._story_choice("refuse")
	_demo._refresh_shared()
	_check(runtime.is_closed(), "the choice closes the reception immediately")
	_check(runtime.get_outcome_id() == "refused", "refused outcome")
	_check(_demo.story_panel._finish.visible, "finish button appears after the choice")
	_check(not _demo.story_panel._advance.visible, "the reception no longer asks to read the epilogue")
	_check(_demo.story_panel._hint.text.contains("审查结束"), "finish hint appears after the choice")
	await _capture("story-panel-finished.png")

	_demo._story_finish()
	await process_frame
	_check(_demo.session.get_soul(soul_id).is_empty(), "finish removes the story guest")
	_check(not _demo.story_panel.visible, "panel hides after finish")
	_check(not _demo.session.is_time_suspended(), "finish resumes the shift")
	_check(_demo.session.story_state.ledger.size() == 1, "finish writes the ledger")
	_check(str(_demo.session.story_state.ledger[0].get("who", "")) == "孙悟空", "ledger keeps the real name")
	_check(bool(_demo.session.story_state.world["world.hades_rampage"]), "wukong refusal sets the world flag")

	# Orpheus follows Wukong. His clear potion plus the monkey rampage
	# should reach the reunion ending.
	var orpheus_id := -1
	for soul in _demo.session.souls:
		if str(soul.get("story_case", "")) == "orpheus":
			orpheus_id = int(soul.id)
			break
	_check(orpheus_id > 0, "orpheus is in the queue")
	_demo.shop.select_guest(orpheus_id)
	_demo._refresh_shared()
	await process_frame
	_check(_demo.story_panel.visible, "orpheus panel opens")
	var orpheus = _demo.session.get_story_runtime(orpheus_id)
	_check(orpheus != null, "orpheus runtime exists")
	_check(_demo.shop.story_sprite == "orpheus_front", "Orpheus starts with the front portrait")
	_check(orpheus.advance(), "Orpheus arrival advances to the speaker")
	_demo._refresh_shared()
	_check(_demo.story_panel._speaker.text == "亚历克斯", "Orpheus speaker uses the alias before the callout")
	await _capture("story-panel-orpheus-alias.png")
	_advance_until_choices(orpheus)
	_demo._refresh_shared()
	_check(_demo.story_panel._callout_button.visible, "orpheus callout button renders")
	_check(_demo.story_panel._callout_button.text.contains("叫破"), "orpheus callout label")
	await _capture("story-panel-orpheus.png")

	# Type ORPHEUS.
	_demo.story_panel._callout_button.pressed.emit()
	_check(_demo.story_panel.is_typing(), "orpheus callout enters typing mode")
	_check(_demo.story_panel._bubbles.visible, "orpheus bubbles appear")
	_check(_demo.story_panel._bubbles.get_child_count() == 7, "ORPHEUS renders seven bubbles")
	_check(_bubble_letter(_demo.story_panel._bubbles, 0) == "·", "Orpheus callout hides the first letter")
	await _capture("story-panel-orpheus-callout.png")
	for index in "ORPHEUS".length():
		_demo.story_panel.submit_letter("ORPHEUS".substr(index, 1))
	_check(bool(orpheus.flags["named"]), "typing ORPHEUS sets named")
	_advance_until_choices(orpheus)
	_demo._refresh_shared()
	_check(_demo.story_panel._body.text == "", "orpheus hub adds no dialogue")
	_check(_demo.story_panel._buttons.size() == 3, "orpheus hub has three clue buttons")
	_check(_demo.story_panel._decision_buttons.size() == 2, "orpheus accept and refuse are separate")
	_check(not _demo.story_panel._buttons[2].disabled, "orpheus lyre clue starts enabled")
	_demo._story_choice("lyre")
	_demo._refresh_shared()
	await _capture("story-panel-effects-lyre.png")
	_demo._story_advance()
	_demo._refresh_shared()
	_demo._story_advance()
	_demo._refresh_shared()
	_demo._story_advance()
	_demo._refresh_shared()
	_check(_demo.shop.story_sprite == "orpheus_turn", "Orpheus turns away when asked to show his back")
	await _capture("story-panel-orpheus-turn.png")
	_demo._story_advance()
	_demo._refresh_shared()
	_check(_demo.shop.story_sprite == "orpheus_front", "Orpheus turns back to the front")
	_advance_until_choices(orpheus)
	_demo._refresh_shared()
	_check(_demo.story_panel._buttons[2].disabled, "the used lyre clue is grayed out")
	_demo._story_choice("eurydice")
	_demo._refresh_shared()
	_check(_demo.story_panel._speaker.text == "俄耳普斯", "Orpheus speaker uses the real name after the callout")
	await _capture("story-panel-orpheus-realname.png")
	_advance_until_choices(orpheus)

	# Feed the clear potion through the same dose controls.
	_demo.session._add_potion("test", "极识药", Vector3i(10, 0, -4), -1, 0)
	_demo._selected_dose = [false, int(_demo.session.potions[0]["id"])]
	_demo._refresh_dose()
	_demo._serve_dose()
	_check(orpheus.has_fed_potion(), "orpheus potion is fed")
	_advance_until_choices(orpheus)
	_check(int(orpheus.flags["dose.score"]) == -6, "orpheus confusion score is negative")
	_check(not bool(orpheus.flags["confused"]), "orpheus is clear-headed")

	# Accept: the reception ends at once; the epilogue waits for the day report.
	_demo._story_choice("admit")
	_demo._refresh_shared()
	_check(orpheus.is_closed(), "orpheus choice closes the reception immediately")
	_check(orpheus.get_outcome_id() == "accepted.reunion", "orpheus reaches the reunion outcome")
	_check(_demo.story_panel._finish.visible, "orpheus finish button appears")
	await _capture("story-panel-orpheus-finished.png")

	_demo._story_finish()
	await process_frame
	_check(_demo.session.get_soul(orpheus_id).is_empty(), "orpheus leaves the queue")
	_check(_demo.session.story_state.ledger.size() == 2, "orpheus writes the second ledger entry")
	_check(str(_demo.session.story_state.ledger[1].get("who", "")) == "俄耳普斯", "orpheus ledger keeps the real name")
	_check(bool(_demo.session.story_state.world["world.orpheus_reunion"]), "orpheus reunion is recorded")

	# The test setup leaves normal guests behind; clear them so the day can end.
	for soul in _demo.session.souls.duplicate():
		_demo.session.souls.erase(soul)
	_demo.session._advance_day_if_ready()
	_demo._refresh_shared()
	# The day is over: the aftermath is shown in a separate report.
	_check(_demo.session.awaiting_day_report, "finishing the last guest queues the day report")
	_check(_demo.day_report.visible, "the day report panel opens")
	var report: Dictionary = _demo.session.get_day_report()
	_check(report.get("entries", []).size() == 2, "the report lists both story guests")
	var combined := ""
	for item in report.get("entries", []):
		for paragraph in item.get("aftermath", []):
			combined += str(paragraph) + "
"
	_check(combined.contains("俄耳普斯转世"), "the report keeps the named aftermath")
	_check(combined.contains("猴子"), "the report keeps the reunion aftermath")
	await _capture("day-report.png")
	_demo._close_day_report()
	await process_frame
	_check(not _demo.session.awaiting_day_report, "closing the report leaves the report state")
	_check(_demo.session.is_complete(), "the run completes after the final report")
	_check(not _demo.day_report.visible, "the report panel hides after closing")
	_check(_demo._dialog.text.length() > 0, "the run ending appears after the report")

	# Show every placeholder prop once for the visual record.
	var showcase := ["lyre", "staff", "tail", "coins", "bowl", "gray_hand", "peach", "cloud"]
	var spots := [
		Vector2(150, 120), Vector2(195, 120), Vector2(240, 120), Vector2(285, 120),
		Vector2(330, 120), Vector2(150, 180), Vector2(210, 180), Vector2(285, 185),
	]
	for index in showcase.size():
		_demo.story_stage.begin_cue({
			"type": "prop",
			"id": showcase[index],
			"action": "show",
			"position": [spots[index].x, spots[index].y],
		}, 0.0)
	_check(_demo.story_stage.get_prop_ids().size() == showcase.size(), "every prop renders in the shop")
	await _capture("story-panel-effects-props.png")
	_demo.story_stage.reset()

	if _failures == 0:
		print("StoryUI: %d checks, 0 failures" % _checks)
	else:
		print("StoryUI: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _advance_until_choices(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 50:
		if not runtime.advance():
			break
		guard += 1


func _decision_fill(index: int) -> Color:
	var style: StyleBox = _demo.story_panel._decision_buttons[index].get_theme_stylebox("normal")
	if style is StyleBoxFlat:
		return (style as StyleBoxFlat).bg_color
	return Color.BLACK


func _bubble_letter(row, index: int) -> String:
	var bubble := row.get_child(index) as PanelContainer
	if bubble == null or bubble.get_child_count() == 0:
		return ""
	return str((bubble.get_child(0) as Label).text)


func _capture(file_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://").path_join("../game/build/validation")
	DirAccess.make_dir_recursive_absolute(directory)
	image.save_png(directory.path_join(file_name))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
