extends SceneTree
## Run headless for behavior. Omit --headless and add -- --capture for visual checkpoints.

const Demo := preload("res://scripts/demo/demo.gd")
const Data := preload("res://scripts/systems/playtest_data.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const SaveSlots := preload("res://scripts/demo/save_slots.gd")
const UI := preload("res://scripts/demo/demo_ui.gd")
const SILHOUETTE := Color(0.08, 0.06, 0.12, 0.85)

var _demo: Demo
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(Demo.BASE_SIZE)
	_demo = preload("res://scenes/demo/demo.tscn").instantiate()
	_demo.auto_pause_on_focus_loss = false
	_demo.save_directory = "res://build/validation/codex-saves-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(_demo)
	for node in [_demo.session, _demo.qte, _demo.river, _demo.shop]:
		node.set_process(false)
	_tap(KEY_TAB)
	_check(not _demo.session.paused and not _demo._codex.visible, "Tab is blocked at the title")
	_demo._start_game()
	await _check_pause_and_input()
	await _check_discoveries()
	await _check_guest_and_guards()
	_check_save_compatibility()
	for slot in [0, 1]:
		SaveSlots.remove(_demo.save_directory, slot)
	DirAccess.remove_absolute(_demo.save_directory)
	print("Codex panel: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _check_pause_and_input() -> void:
	var codex := _demo._codex
	_tap(KEY_P)
	_check(not _demo.session.paused and not codex.visible and _demo._pause_button.tooltip_text == "暂停游戏（Esc）", "P no longer pauses")
	_tap(KEY_ESCAPE)
	_check(_demo.session.paused and codex.visible and not codex.is_open and not codex._drawer.visible, "Escape reveals only the bookmark")
	_check(_demo._pause_button.has_focus() and _demo._pause_button.tooltip_text == "继续游戏（Esc）", "Top-left resume button owns focus")
	_tap(KEY_P)
	_check(_demo.session.paused, "P no longer resumes")
	await _settle_slide()
	_check(codex._bookmark_track.position.x == 0 and codex._arrow.text == "▶", "Bookmark settles on the screen edge")
	await _capture("01-pause")
	_tap(KEY_TAB)
	_check(codex.is_open and codex.nav_focus == codex.NavFocus.GRID and codex._drawer.has_focus(), "Tab opens the drawer directly into grid navigation")
	_tap(KEY_TAB)
	_check(_demo.session.paused and not codex.is_open and _demo._pause_button.has_focus(), "A second Tab returns to pure pause")
	await _settle_slide()
	_click(codex._bookmark)
	await _settle_slide()
	_check(codex.is_open and codex._drawer.position.x == 14 and codex._bookmark_track.position.x == 614 and codex._arrow.text == "◀" and is_equal_approx(codex._shade.color.a, 0.45), "Mouse opens the drawer and shade and docks the bookmark")
	_click(codex._drawer.get_node("Close"))
	_check(_demo.session.paused and not codex.is_open, "Close button returns to pure pause")
	await _settle_slide()
	_click(codex._bookmark)
	await _settle_slide()
	_click(codex._bookmark)
	_check(_demo.session.paused and not codex.is_open, "Docked bookmark also closes the drawer")
	_tap(KEY_TAB)
	_click_at(Vector2(1100, 540))
	_check(_demo.session.paused and not codex.is_open, "Clicking the shade closes only the drawer")
	_tap(KEY_F)
	_check(_demo._save_menu.is_open and _demo._save_menu.saving, "F opens Save directly from pure pause")
	_tap(KEY_TAB)
	_check(_demo._save_menu.is_open and not codex.is_open, "The save modal blocks Tab")
	_tap(KEY_ESCAPE)
	_tap(KEY_ESCAPE)
	_check(not _demo.session.paused, "Escape closes the modal before resuming")
	_click(_demo._pause_button)
	_check(_demo.session.paused and not codex.is_open, "Clicking Pause enters pure pause")
	_tap(KEY_ESCAPE)
	_demo._set_auto_pause(true)
	_demo.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_demo._set_auto_pause(false)
	_check(_demo.session.paused and not codex.is_open, "Focus loss enters pure pause")
	_tap(KEY_ESCAPE)
	_demo._toggle_rig_popup(0)
	_check(_demo._rig_popup.visible, "The river rig picker is open before pausing")
	_tap(KEY_TAB)
	_check(_demo.session.paused and codex.is_open and codex.nav_focus == codex.NavFocus.GRID and _demo._pause_banner.visible, "Tab from gameplay pauses and opens the drawer directly into the grid")
	_check(not _demo._rig_popup.visible and _demo._rig_slot_cursor == -1, "Tab pause dismisses the rig picker")
	_tap(KEY_F)
	_check(_demo._save_menu.is_open and _demo._save_menu.saving and codex.is_open, "F opens Save directly even while the drawer is open")
	_tap(KEY_TAB)
	_check(_demo._save_menu.is_open and codex.is_open, "Tab keeps the open modal and drawer in place")
	_tap(KEY_ESCAPE)
	_check(not _demo._save_menu.is_open and _demo.session.paused and codex.is_open, "The first Escape closes only the save modal")
	_click(_demo._pause_buttons[0])
	_click(_demo._save_menu.slot_buttons[0])
	_click(_demo._save_menu.slot_buttons[0])
	_check(_demo._save_menu._confirmation.visible, "Saving to an occupied slot opens a confirmation over the drawer")
	_tap(KEY_ESCAPE)
	_check(not _demo._save_menu.is_open and _demo.session.paused and codex.is_open, "Escape dismisses the save modal even during confirmation")
	_tap(KEY_R)
	_check(_demo._save_menu.is_open and not _demo._save_menu.saving and codex.is_open, "R opens Load directly while the drawer is open")
	_tap(KEY_ESCAPE)
	_tap(KEY_TAB)
	_check(not _demo.session.paused and not codex.is_open, "Tab resumes a shortcut pause")
	_tap(KEY_TAB)
	_tap(KEY_ESCAPE)
	_tap(KEY_TAB)
	_tap(KEY_TAB)
	await _settle_slide()
	_check(not codex.visible and not codex._drawer.visible and codex._drawer.position.x == -620 and codex._bookmark_track.position.x == -50 and codex._shade.color.a == 0.0 and _demo._pause_button.scale == Vector2.ONE, "Rapid Tab and Escape settle all animations at their hidden positions")


func _check_discoveries() -> void:
	var codex := _demo._codex
	var session := _demo.session
	_tap(KEY_TAB)
	_check(codex._entry_ids.size() == 12 and codex._progress.text == "鱼类 0 / 12", "All fish begin undiscovered despite starting materials")
	_tap(KEY_D)
	_tap(KEY_S)
	_check(codex._selection == 4, "WASD moves through the three-column fish grid")
	_tap(KEY_E)
	_check(codex._source_page and codex._entry_ids.size() == 11, "E opens the dedicated source page")
	_tap(KEY_E)
	_check(codex._recipe_page and codex._entry_ids.size() == 11 and codex._progress.text == "成品 0 / 11", "The third page contains eleven fixed medicines")
	_tap(KEY_W)
	_check(codex.nav_focus == codex.NavFocus.FILTER, "Up from the top medicine row selects filters")
	_tap(KEY_S)
	_check(codex.nav_focus == codex.NavFocus.GRID, "Down returns to the medicine grid")
	_tap(KEY_TAB)
	session.record_catch({"species": 0, "size": 1, "cm": 4.5})
	session.record_catch({"species": 0, "size": 2, "cm": 8.5})
	session.record_catch({"species": 0, "size": 0, "cm": 1.2})
	session.record_catch({"species": Data.LANTERN, "size": 0, "cm": 17.0})
	_check(session.concentrate == 1 and session.catches.is_empty(), "Fish automatically bank materials and the lantern bonus")
	_check(session.brew(0), "Three materials produce a fixed medicine")
	var id: String = session.potions[-1].kind
	_tap(KEY_TAB)
	codex._set_codex_page(0)
	var detail := _detail_text()
	_check(detail.contains("灰鳞鱼") and detail.contains("累计捕获 3 次") and detail.contains("8.5 cm"), "Fish retain count and measured length independently of material use")
	_check(detail.contains("浅水 权重 25（25.0%）") and detail.contains("1级材料"), "Fish detail uses the revised weights and material grade")
	await _capture("02-fish")
	codex._open_source(0)
	_check(_detail_text().contains(Data.POTIONS[id].name) and _detail_text().contains("概率待发现"), "A source reveals only the outcome actually brewed")
	await _capture("02b-source")
	codex._set_codex_page(2)
	codex._set_filter_from_bar(1)
	_check(codex._entry_ids == [id], "Discovered filter shows the actual finished medicine")
	_check(_detail_text().contains(Data.POTIONS[id].name) and _detail_text().contains("固定药效"), "Medicine detail shows its standard effect and source links")
	_tap(KEY_TAB)


func _check_guest_and_guards() -> void:
	var session := _demo.session
	var codex := _demo._codex
	_demo.day_report.show()
	_tap(KEY_TAB)
	_check(not session.paused and not codex.is_open, "The day report blocks Tab")
	_demo.day_report.hide()
	_demo.qte.locked = {"species": Data.VARIANT, "size": 3, "cm": 34.0}
	_demo.qte._start_fish_capture()
	_tap(KEY_TAB)
	_check(not session.paused and _demo.qte.phase == Fishing.Phase.TRUE_NAME, "The rare fish true-name challenge blocks Tab")
	_demo.qte.phase = Fishing.Phase.READY
	_tap(KEY_E)
	_tap(KEY_TAB)
	_check(codex.is_open and not codex._guest.visible, "Reception with no selected guest skips the guest strip")
	_tap(KEY_TAB)
	session.advance(Data.ARRIVAL_MAX * 6 + 1.0)
	_demo.shop.select_guest(1)
	var guest := session.get_soul(1)
	guest.stats = Vector3i(3, 6, 9)
	session.requirements = [Vector3i(4, 5, 6), Vector3i(8, 7, 8)]
	_tap(KEY_TAB)
	_check(codex._guest.visible and codex._guest_name.text == guest.name and codex._guest_stats[0].text == "智慧 3 [4–8]", "Reception drawer shows the selected guest, current values, and thresholds")
	_check(codex._guest_stats[0].get_theme_color("font_color") == Color("8ce0ff") and codex._guest_stats[1].get_theme_color("font_color") == UI.GOOD and codex._guest_stats[2].get_theme_color("font_color") == UI.WARN, "Guest strip distinguishes below, within, and above the required range")
	_click(codex._filter_buttons[2])
	_tap(KEY_S)
	await _capture("03-reception-recipe")
	_tap(KEY_TAB)
	_demo.shop.select_guest(6)
	_demo._story_action()
	_check(_demo.story_panel.is_typing(), "The story true-name challenge is active")
	_tap(KEY_TAB)
	_check(_demo.story_panel.is_typing() and not session.paused and not codex.is_open, "The story true-name challenge retains ownership of Tab")
	_tap(KEY_ESCAPE)


func _check_save_compatibility() -> void:
	var session := _demo.session
	var history := session.codex_fish.duplicate(true)
	var known := session.codex_sources.duplicate(true)
	_check(_demo.save_progress(0) and _demo.load_progress(0), "Current rules save and reload")
	_check(session.codex_fish == history and session.codex_sources == known, "Catch history and per-source probabilities survive material consumption")
	var old_save := {"coins": 40, "released_count": 0, "essences": [0,0,0,0,0,0,0,1,0,0,0,2], "catches": [{"species": Data.LANTERN, "size": 0, "cm": 16.4}], "potions": [{"id": 30, "kind": "potion_08", "name": "暖心药", "effect": [0,4,0], "attribute": -1, "adjustment": 0}]}
	_check(SaveSlots.write(_demo.save_directory, 1, old_save) and _demo.load_progress(1), "A pre-redesign save migrates")
	_check(session.catches.is_empty() and session.essences[7] == 3 and session.essences[Data.STILLFIN] == 0, "Old fish and shared tails convert once")
	_check(session.potions[0].kind == "medicine_02" and session.potions[0].effect == Vector3i(0,2,0), "Old same-name medicines adopt the approved fixed values")
	_check(session.starter_supply_claimed and session.upper_supply_claimed, "Old saves cannot re-claim the new one-time grants")
	old_save.potions = [{"kind": "potion_08", "effect": [0,4,0]}, {"kind": "potion_14", "effect": [0,0,4]}]
	_check(SaveSlots.write(_demo.save_directory, 1, old_save) and _demo.load_progress(1), "Older unnamed doses also migrate")
	_check(session.potions[0].kind == "medicine_02" and session.potions[1].kind == "medicine_03" and session.potions[0].id != session.potions[1].id, "Legacy names and missing item IDs normalize without collisions")


func _detail_text() -> String:
	var labels := PackedStringArray()
	for label in _demo._codex._detail.find_children("*", "Label", true, false):
		labels.append(label.text)
	for button in _demo._codex._detail.find_children("*", "Button", true, false):
		labels.append(button.text)
	return "\n".join(labels)


func _settle_slide() -> void:
	var slide := _demo._codex._slide
	if slide and slide.is_running():
		await slide.finished


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


func _click(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


func _click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event)


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await create_timer(0.28).timeout
	await RenderingServer.frame_post_draw
	var path := "res://build/validation/codex"
	DirAccess.make_dir_recursive_absolute(path)
	_check(root.get_texture().get_image().save_png(path.path_join(label + ".png")) == OK, "Captured " + label)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
