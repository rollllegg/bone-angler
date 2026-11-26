extends SceneTree
## Run with -- --capture and the renderer enabled to save gameplay checkpoints.

const Data := preload("res://scripts/systems/playtest_data.gd")
const SaveSlots := preload("res://scripts/demo/save_slots.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const River := preload("res://scripts/demo/pixel_river.gd")
const TitleMenu := preload("res://scripts/demo/title_menu.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")

var demo
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.auto_pause_on_focus_loss = false
	demo.persist_save = false
	root.add_child(demo)
	await process_frame
	_freeze()
	_seed_first_day()
	_check(not demo.started and demo._menu.visible, "The cover is the initial entry")
	var menu_texts := PackedStringArray()
	for lbl: Label in demo._menu.find_children("*", "Label", true, false):
		menu_texts.append(lbl.text)
	var joined_menu := "\n".join(menu_texts)
	_check(not joined_menu.contains("试玩版") and not joined_menu.contains("钓鱼 · 炼药"), "Title menu omits the two prototype subtitle lines")
	_check(demo.start_button.text == "开始游戏" and demo.continue_button.text == "继续游戏" and demo.settings_button.text == "游戏设置" and demo.quit_button.text == "退出游戏", "Title menu exposes four aligned four-character buttons")
	var ui_font := demo.start_button.get_theme_font("font") as FontVariation
	_check(ui_font != null and ui_font.base_font == demo.FONT and demo._river_button.get_theme_font("font") == ui_font and demo.market._detail_name.get_theme_font("font") == ui_font, "Menus, tabs and nested panels inherit Fusion Pixel")
	_check(not demo.session.active and not demo.river.active and not demo.shop.active, "The cover suspends world time")
	var arrival: float = demo.session.spawn_remaining
	demo.session.advance(50.0)
	_check(demo.session.spawn_remaining == arrival, "Waiting at the title does not advance the arrival clock")
	_check(_title_highlight_is(demo.start_button), "Only Start begins selected")
	var fish := demo._menu.get_node("RiverFish") as TitleMenu.RiverFish
	_click(demo.settings_button)
	_check(demo._settings_modal.is_open and _title_highlight_is(demo.settings_button), "Clicking Settings during the title entrance responds immediately")
	_click_at(fish.get_global_transform() * fish._surface.cover_to_stage(Vector2(304, 169)))
	_check(fish._jumps.is_empty() and demo._settings_modal.is_open, "The Settings button and panel absorb clicks over the river")
	_key(KEY_ESCAPE)
	_check(not demo._settings_modal.is_open, "Escape closes Settings during its entrance")
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	_check(_title_highlight_is(demo.start_button), "Arrow navigation wraps to Start during the entrance")
	await _capture("01-cover", 0.82)
	await _check_title_river(fish)
	var continue_disabled: bool = demo.continue_button.disabled
	demo.continue_button.disabled = false
	_key(KEY_S)
	_check(_title_highlight_is(demo.continue_button), "Selecting Continue updates the selected row and pointer target")
	_move_mouse(demo.quit_button.get_global_rect().get_center())
	await process_frame
	_check(_title_highlight_is(demo.quit_button), "Mouse hover selects Quit")
	_key(KEY_S)
	_check(_title_highlight_is(demo.start_button), "Keyboard navigation wraps from Quit and clears its selection")
	demo.continue_button.disabled = continue_disabled
	_key(KEY_S)
	if not demo.continue_button.disabled:
		_key(KEY_S)
	_check(_title_highlight_is(demo.settings_button), "Only Settings is selected after navigating to it")
	await _capture("01c-cover-settings-selected", 0.15)
	_key(KEY_ENTER)
	await process_frame
	_check(demo._settings_panel.visible and demo._settings_modal.is_open, "S skips unavailable Continue and Enter opens Settings")
	await _capture("01b-settings", 0.20)
	_key(KEY_C)
	_check(not demo._settings_modal.is_open and not demo.started, "C releases Settings input without leaving the title screen")
	_key(KEY_UP)
	if not demo.continue_button.disabled:
		_key(KEY_W)
	_key(KEY_SPACE)
	_check(demo._start_mode_modal.is_open and not demo.started, "Space opens the start mode chooser without advancing the shift")
	_key(KEY_ESCAPE)
	_check(not demo._start_mode_modal.is_open and not demo.started, "Escape closes the mode chooser and leaves the cover active")
	_key(KEY_ENTER)
	_key(KEY_DOWN)
	_key(KEY_SPACE)
	_check(demo.started and demo._river_image.visible and not demo._menu.visible and not demo.river.casting and demo._title_transition.visible, "Space enters the river synchronously under the transition without casting")
	_check(not demo.tutorial_active and not demo.session.tutorial_pause_arrivals, "Direct Start keeps the ordinary first-day schedule")
	_check(fish._jumps.is_empty() and fish._bursts.is_empty(), "Entering the game clears title-only fish and ripples")
	await create_timer(0.30).timeout
	await process_frame
	_check(not demo._title_transition.visible and not demo.river.casting, "The title transition finishes without affecting fishing")
	_check(not demo._settings_panel.visible, "The dismissed Settings panel finishes closing after entering the river")
	_check(demo.session.coins == 40 and demo.qte.durability() == 10 and demo.qte.bait_stock[0] == 10 and demo.qte.charms_owned == 0 and demo.qte.hook == 0, "Opening equipment and money match the economy specification")
	_check(demo._rig_hint.text == "稳魂指骨自动装配 0 / 1", "The short rod starts with an empty charm slot")
	_check(not demo.qte.buy_device(1) and not demo.qte.rods_owned[1], "The deep-water rod requires the stated purchase price")
	_check(arrival >= Data.ARRIVAL_MIN and arrival <= Data.ARRIVAL_MAX, "The first arrival keeps the demo interval")
	_check(demo._rig.size() == 4, "Only rod, hook, grip and bait can be selected at the river")
	_check(demo._stage.find_children("*", "OptionButton", true, false).is_empty(), "No native OptionButton dropdowns remain in the redesigned UI")
	_check_location_navigation()
	await _check_rig_picker()
	await _check_ferry_crossing()
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false, false)
	_check(not demo.river.casting, "Repeat events and releases do not cast")
	_key(KEY_SPACE)
	_check(demo.river.casting and demo.qte.phase == Fishing.Phase.READY, "Space starts the art before the bite timer")
	demo.river.advance_cast(0.24)
	_key(KEY_SPACE)
	_check(demo.river.get_cast_frame() == 0 and is_equal_approx(demo.river.cast_elapsed, 0.24), "Repeated Space does not restart casting")
	_key(KEY_E)
	demo.river.advance_cast(9.0)
	_check(is_equal_approx(demo.river.cast_elapsed, 0.24), "Scene switching preserves cast progress")
	demo.session.advance(arrival)
	_check(demo.session.souls[0].stats.y == 6 and demo.shop.selected_id == 1, "The first configured case arrives while river input is suspended")
	_key(KEY_Q)
	_check(not demo.river.get_ferry_rect().has_area(), "The ferry is gone once its soul joins the queue")
	demo.river.advance_cast(0.01)
	_check(demo.river.get_cast_frame() == 1, "Second pose starts after 0.25 seconds")
	_key(KEY_ESCAPE)
	demo.river.advance_cast(10.0)
	_check(demo.river.get_cast_frame() == 1 and demo._pause_banner.visible and demo._pause_banner.get_rect().end.y < 96.0, "Manual pause suspends casting and fits within the top bar")
	_check(demo._pause_button.icon == demo.RESUME_ICON and demo._pause_button.text.is_empty(), "The paused HUD shows the pixel play icon")
	_key(KEY_Q)
	_key(KEY_E)
	_check(demo.current_location == "River", "Q and E leave the location unchanged while paused")
	await _capture("02b-manual-pause")
	_click(demo._pause_button)
	_check(not demo.session.paused and not demo._pause_banner.visible, "The top-bar button resumes manual pause")
	_check(demo._pause_button.icon == demo.PAUSE_ICON and demo._pause_button.text.is_empty(), "The running HUD shows the pixel pause icon")
	_click(demo._pause_button)
	_check(demo.session.paused, "Clicking the running icon pauses gameplay")
	_key(KEY_ESCAPE)
	_check(not demo.session.paused and demo.river.casting, "Escape resumes without another cast")
	demo.river.advance_cast(0.25)
	_check(demo.river.get_cast_frame() == 2, "Third pose starts after 0.5 seconds")
	demo.river.advance_cast(0.25)
	_check(demo.river.get_cast_frame() == 3, "Fourth pose starts after 0.75 seconds")
	demo.river.advance_cast(0.25)
	var fishing: Fishing = demo.qte
	var session: Session = demo.session
	_check(fishing.phase == Fishing.Phase.WAITING and fishing.remaining >= 3.0 and fishing.remaining <= 8.0, "Initial cast waits 3 to 8 seconds after landing")
	_check(fishing.locked.is_empty() and fishing.durability() == 10, "While waiting, the catch is unlocked and no resources are spent")
	fishing.disturb(30.0)
	_check(is_equal_approx(fishing.wait_extension, 2.0) and fishing.remaining <= 10.0, "Scare adds at most two seconds")
	_key(KEY_X)
	_check(fishing.phase == Fishing.Phase.READY and fishing.durability() == 10 and fishing.bait_stock[0] == Data.STARTING_BAIT, "Early retrieval preserves resources")
	_check(not demo._audio._players.has(Audio.Cue.REEL), "Early retrieval does not play the pull QTE cue")
	fishing.scare = 0.0
	await _capture("02-river")
	_check_attribute_baits(fishing)
	var small_hook := fishing.size_weights(0)
	_check(small_hook[0] == 80.0 and small_hook[1] == 65.0 and is_equal_approx(small_hook[2], 1.5) and fishing.size_weights(2)[2] == 60.0, "Only the hook multiplies the base size weights")
	fishing.cast()
	_key(KEY_E)
	var wait_before := fishing.remaining
	fishing._process(0.5)
	_check(is_equal_approx(fishing.remaining, wait_before - 0.5) and not demo._river_notice.visible, "Waiting keeps ticking at reception and the alert only appears on a bite")
	_hook_fish(fishing, 1, 1)
	_check(fishing.phase == Fishing.Phase.AWAITING_RETURN and is_equal_approx(fishing.remaining, 3.0), "A bite away from the river starts a three-second return window")
	_check(not demo._audio._players.has(Audio.Cue.REEL), "An off-river bite does not play the reel cue")
	_check(demo._river_bite_alert.visible and demo._river_bite_alert.text == "!" and demo._river_button.text == "河岸", "A red exclamation mark appears next to the river tab label")
	_check(demo._river_notice.visible and demo._river_notice_title.text == "有鱼上钩了！" and demo._river_notice_detail.text.contains("Q"), "Reception shows the left-side bite bubble and the return shortcut")
	await _capture("02c-bite-alert")
	_key(KEY_E)
	fishing._process(2.9)
	_check(fishing.phase == Fishing.Phase.AWAITING_RETURN and demo._river_notice.visible, "Switching between other locations keeps the same return window and alert")
	_click(demo._river_button)
	_check(demo.current_location == "River" and not demo._river_bite_alert.visible, "Clicking the alert tab returns to the river and clears the alert")
	_check(not demo._river_notice.visible, "Returning to the river dismisses the bite bubble")
	_check(fishing.phase == Fishing.Phase.PREPARING and fishing.durability() == 9 and fishing.bait_stock[0] == Data.STARTING_BAIT - 1, "A locked fish spends one bait and one shared durability")
	_check(not demo._audio._players.has(Audio.Cue.REEL), "Entering the pull QTE waits for player input before playing the reel cue")
	_check(demo._river_status.text == "有鱼上钩了！" and not demo._river_status.text.contains("冥河鲫"), "Hooked status box does not spoil the fish species before landing")
	fishing.advance(Data.PREPARATION)
	_check(fishing.target == 4 and is_equal_approx(fishing.get_capture_time(), 20.0), "The normal carp uses the easy target and full first-round time")
	fishing.advance(fishing.get_target_time())
	demo.river._process(fishing.get_target_time())
	_check(demo.river.tension.length() > 0.8, "Rod bends along fish direction while reeling")
	var direction_key: Key = Fishing.DIRECTION_KEYS[fishing.get_expected_direction()]
	_key(direction_key, true)
	_key(direction_key, false, false)
	_check(not demo._audio._players.has(Audio.Cue.REEL), "A repeated key event and release do not play the reel cue")
	await _capture("03-direction")
	_pull(fishing.get_expected_direction())
	_check(fishing.progress == 2 and fishing.last_judgement == Fishing.Judgement.PERFECT, "A timed opposite key earns two progress")
	var reel := demo._audio._players.get(Audio.Cue.REEL) as AudioStreamPlayer
	_check(reel != null and reel.playing, "The first direction press plays the reel cue")
	demo._audio.stop(Audio.Cue.REEL)
	demo.river._process(Data.ROUND_GAP)
	_check(demo.river.tension.length() < 0.1 and demo.river.hit_timer > 0.0, "Rod returns rapidly toward center during feedback while hit label stays readable")
	fishing.advance(Data.ROUND_GAP)
	_pull(fishing.get_expected_direction())
	_check(fishing.progress == 1 and fishing.mistakes == 1, "An early press costs one progress")
	_check(reel != null and reel.playing, "An early direction press still plays the reel cue")
	demo._audio.stop(Audio.Cue.REEL)
	fishing.advance(Data.ROUND_GAP)
	fishing.advance(fishing.get_target_time() - 0.25)
	_pull(fishing.get_expected_direction(), true)
	_check(fishing.progress == 2 and fishing.last_judgement == Fishing.Judgement.NORMAL, "An ordinary-window press earns one progress")
	_check(reel != null and reel.playing, "An arrow-key press plays the same reel cue")
	demo._audio.stop(Audio.Cue.REEL)
	fishing.advance(Data.ROUND_GAP)
	fishing.advance(fishing.get_target_time() + 0.05)
	_key(KEY_E)
	fishing._process(12.0)
	_check(fishing.phase == Fishing.Phase.REELING and is_equal_approx(fishing.get_travel_ratio(), 1.0 + 0.05 / Data.TRAVEL[0]), "Switching to reception holds the capture time")
	_key(KEY_Q)
	_pull(fishing.get_expected_direction())
	_check(fishing.phase == Fishing.Phase.CAUGHT and session.catches.is_empty() and session.codex_fish["fish_02"].caught == 1, "Capture completes and adds the fish once")
	_check(reel != null and reel.playing, "The final pull plays the reel cue again")
	_check(demo._catch_fish_rect.visible and demo._catch_fish_rect.texture == Data.fish_texture(1, 1), "Caught fish displays the Feishu fish sprite instead of the temporary placeholder")
	var sprite: TextureRect = demo._catch_fish_rect
	var mouth := Vector2(3, 64) * (sprite.size / sprite.texture.get_size())
	_check(is_equal_approx(sprite.rotation_degrees, 90.0), "The caught fish hangs head up and tail down")
	_check((sprite.get_transform() * mouth).is_equal_approx(River.CATCH_LINE_END * 4.0), "The fish mouth aligns with the end of the fishing line")
	_check(fishing.durability() == 9 and fishing.bait_stock[0] == Data.STARTING_BAIT - 1, "Landing does not charge a second time")
	await _capture("03b-caught-fish")

	_key(KEY_E)
	_key(KEY_E)
	_check(demo.alchemy.visible and not demo._shop_ui.visible, "Cycling forward twice from the river opens the alchemy station")
	_check(demo.alchemy.essence_cards.size() == 11 and session.catches.is_empty(), "Alchemy displays the caught fish sprite and previews its potion")
	await _capture("04-alchemy")
	_key(KEY_SPACE)
	_check(session.catches.is_empty() and session.essences[1] == 3 and session.potions.size() == 1, "The captured fish supplies three materials and one pure brew consumes exactly three")
	_click(demo.alchemy._tab_buttons[1])
	await process_frame
	if not demo.alchemy.essence_cards.is_empty():
		_click(demo.alchemy.essence_cards[0])
		await process_frame
		_click(demo.alchemy.essence_cards[0])
	await _capture("04b-alchemy-mix")
	_click(demo.alchemy._tab_buttons[0])
	_key(KEY_Q)
	_check(demo.soul_hud.soul.stats.y == 6 and demo._dose_buttons.size() == 1, "Reception shows soul stats in the top-left HUD and lists potions directly below")
	_check(demo._serve_button.disabled and demo.soul_hud.preview.is_empty(), "No potion preview is active before clicking a potion in the list")
	_click(demo._dose_buttons[0])
	await process_frame
	_check(not demo._serve_button.disabled and session.is_eligible(demo.soul_hud.preview.after) and demo._dose_preview.text.contains("放行"), "Clicking a potion previews all three post-dose values on the top-left HUD")
	await _capture("04c-reception-preview")
	_key(KEY_SPACE)
	_check(session.can_release(1) and session.essences[1] == 3 and session.potions.is_empty(), "Serving consumes one dose and applies signed effects")
	demo.shop.advance_presentation(1.0)
	_check(session.released_count == 0 and not demo._release_button.disabled, "An eligible soul requires explicit release")
	await _capture("05-ready-to-release")
	_key(KEY_SHIFT)
	_check(demo.shop.departure_times == [0.0] and session.released_count == 1 and session.coins == 67, "Shift triggers departure and pays the 25-coin fee plus a first-service bonus")
	demo.shop.advance_presentation(2.0)
	await _capture("06-departure")
	demo.shop.advance_presentation(5.0)
	_check(demo.shop.departure_times.is_empty() and session.released_count == 1 and session.coins == 67, "Departure completion does not award the fee again")

	_key(KEY_E)
	_key(KEY_E)
	_check(demo.market.visible and demo.market.active_filter == demo.market.Filter.ALL, "Cycling to the market shows all wares sorted by category")
	var has_grip_ware: bool = demo.market._filtered_catalog().any(func(item: Dictionary) -> bool: return item.name == "基础握柄")
	_check(not has_grip_ware, "The starter grip is absent from the market's all-wares list")
	_key(KEY_SPACE)
	_check(demo.market.browsing_wares and session.coins == 67, "The first Space enters the item list without making a purchase")
	_key(KEY_W)
	_check(demo.market.selected_key == "device:2", "W wraps from the first buyable device to the last owned device")
	_key(KEY_S)
	await _capture("07-market")
	_check(demo.market._cost_value.text == "160" and demo.market.action_button.disabled, "The new long rod is priced at 160 coins and one release cannot fund it")
	session.coins = 360
	demo.market.refresh()
	_key(KEY_SPACE)
	_check(fishing.rods_owned[1] and session.coins == 200 and fishing.rod == 0, "Buying the 160-coin long rod unlocks it without replacing the active rig")
	var ware_keys: Array = demo.market._filtered_catalog().map(func(item: Dictionary) -> String: return item.key)
	_check(ware_keys.slice(-3) == ["device:0", "device:1", "device:2"], "Owned devices move below baits and temporarily unavailable repairs after checkout")
	_key(KEY_C)
	_check(not demo.market.browsing_wares and demo.market.visible, "C backs out one level from market items")
	_key(KEY_S)
	_check(demo.market.active_filter == demo.market.Filter.ROD, "S selects the next market category after backing out")
	demo.market.select_filter(demo.market.Filter.HOOK)
	ware_keys = demo.market._filtered_catalog().map(func(item: Dictionary) -> String: return item.key)
	_check(ware_keys == ["device:3", "device:4", "device:2"], "The hook category puts the owned hook after hooks still for sale")
	demo.market.select_device(Data.STEADY_CHARM)
	_check(demo.market.active_filter == demo.market.Filter.CHARM and demo.market.ware_buttons.size() == 1, "The charm category lists only the steady charm")
	_check(demo.market._detail_meta.text.contains("0 / 2") and demo.market._cost_value.text == "70", "The market shows both charms available for individual purchase")
	_click(demo.market.action_button)
	_check(fishing.charms_owned == 1 and fishing.equipped_charms() == 1 and session.coins == 130, "The first purchased charm costs 70 coins and fills the short rod slot")
	_check(demo.market._detail_meta.text.contains("1 / 2") and not demo.market.action_button.disabled, "The market shows one charm owned and offers the second")
	demo.market.select_filter(demo.market.Filter.ALL)
	ware_keys = demo.market._filtered_catalog().map(func(item: Dictionary) -> String: return item.key)
	var charm_key := "device:%d" % Data.STEADY_CHARM
	_check(ware_keys.find(charm_key) < ware_keys.find("bait:0"), "The steady charm stays with purchasable gear when one remains")
	_click(demo.market.action_button)
	_check(fishing.charms_owned == 2 and fishing.equipped_charms() == 1 and session.coins == 60, "The second charm costs 70 coins and stays available for a second slot")
	_check(demo.market._detail_meta.text.contains("2 / 2") and demo.market.action_button.disabled and not fishing.buy_device(Data.STEADY_CHARM), "The market caps charm purchases at two")
	ware_keys = demo.market._filtered_catalog().map(func(item: Dictionary) -> String: return item.key)
	_check(ware_keys.back() == charm_key, "The steady charm moves to the bottom after its last purchase")
	_click(demo.market.filter_buttons[4])
	await process_frame
	_check(demo.market.active_filter == demo.market.Filter.BAIT and demo.market.ware_buttons.size() == Data.BAITS.size() + 1, "Left rail Bait filter shows only baits")
	demo.market.select_bait(Data.Bait.EMOTION)
	_check(demo.market._detail_name.text == "情感饵" and demo.market._detail_desc.text.contains("冥河鲫、渡魂鲶、泪纹鲦"), "Market shows the effect and target fish of the selected attribute bait")
	await _capture("07b-market-attribute-bait")
	session.coins = 140
	fishing.unlock_variant_craft()
	demo.market.select_bait(Data.VARIANT_BAIT)
	await _capture("07c-market-bait")
	_click(demo.market.action_button)
	_check(fishing.bait_stock[Data.VARIANT_BAIT] == 1 and session.coins == 52, "The special bait costs 8 coins")
	_click(demo.market.filter_buttons[5])
	await process_frame
	demo.market.select_repair(true)
	_check(demo.market.action_button.disabled and demo.market._cost_value.text == "10", "The full repair price is visible at positive durability, with checkout disabled")
	fishing.grip_durability = 0
	demo.market.select_repair(false)
	await _capture("07d-market-repair")
	_click(demo.market.action_button)
	_check(fishing.durability() == 5 and session.coins == 46 and not fishing.quick_repair_available, "Quick repair costs 6 coins and spends the opportunity")
	fishing.grip_durability = 0
	demo.market.refresh()
	_check(demo.market.action_button.disabled and not fishing.repair(false) and session.coins == 46, "Quick repair cannot be repeated after the restored durability runs out")
	demo.market.select_repair(true)
	_click(demo.market.action_button)
	_check(fishing.durability() == 10 and session.coins == 36 and fishing.quick_repair_available, "Full repair costs 10 coins and restores the quick repair opportunity")

	_check_recipes(session)
	await _check_special_cases(fishing, session)
	_check_missed_bite(fishing, session)
	session.advance(300.0)
	_check(session.day == 1 and demo._queue_buttons.size() == 5, "Day one has six guests and one has already been released")
	_key(KEY_E)
	root.size = Vector2i(960, 576)
	await process_frame
	_check(demo._release_button.get_global_rect().end.x <= demo.get_viewport_rect().size.x, "Reception controls fit the smaller window")
	await _capture("08-small-window")
	await _check_daily_rotation(session)
	_check_grip_restore()
	demo.queue_free()
	await process_frame
	await _check_keyboard_workflows()
	await _check_save_slots()
	_check_dose_rewards()
	await _check_return_to_title()
	unload_current_scene()
	# Let the audio server release playback from the final menu confirmation.
	await create_timer(0.10).timeout
	print("Integrated playtest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_dose_rewards() -> void:
	var model := Session.new()
	root.add_child(model)
	model.active = true
	model.requirements.assign([Vector3i(7,7,7), Vector3i(9,9,9)])
	for count in range(1,4):
		var starting := Vector3i(8,8,7-count*2)
		var soul := {"id": 1, "case_id": 0, "stats": starting, "before": starting, "fee": 25, "served": false}
		model.souls.assign([soul])
		model._first_services.clear()
		for index in count:
			model._add_potion("medicine_03", "定志药", Vector3i(0,0,2), -1, 0)
			_check(model.serve(1,false,model.potions[-1].id), "Each finished medicine is consumed and counted")
		var expected := floori(27.0 * pow(0.5,count-1))
		var balance := model.coins
		_check(model.release_soul(1) and model.coins == balance + expected, "Visit bonus precedes dose reduction and flooring")
	model.free()


func _check_grip_restore() -> void:
	demo.session.coins = 12
	demo._restore_grip({"grip": 1, "grip_durability": [9, 3, 10]})
	_check(demo.qte.durability() == 3 and demo.qte.quick_repair_available and demo.session.coins == 72, "Legacy saves keep the equipped grip's wear and recover the purchase price of duplicate grips")
	demo._restore_grip({"grip_durability": 0, "quick_repair_available": false})
	_check(demo.qte.durability() == 0 and not demo.qte.quick_repair_available and demo.session.coins == 72, "Updated saves preserve exhausted repair opportunities without an additional refund")


func _check_title_river(fish: TitleMenu.RiverFish) -> void:
	fish.set_process(false)
	var surface := fish._surface
	var starting_swim := fish._swimmer_pose(0)
	fish._process(0.48)
	_check(TitleMenu.RiverFish.SWIMMERS.size() == 7 and fish._swimmer_pose(0).x != starting_swim.x, "Seven ambient fish swim before starting a shift")
	var swim_time := fish._time
	var lane: Vector3 = TitleMenu.RiverFish.SWIMMERS[0]
	var leg := fish.size.x + TitleMenu.RiverFish.SWIM_MARGIN - fish._swim_turns[0]
	var turn_time := leg * (1.0 - 2.0 * lane.y) / lane.z
	fish._time = turn_time - 0.25
	var before_turn := fish._swimmer_pose(0)
	fish._time = turn_time
	var at_turn := fish._swimmer_pose(0)
	fish._time = turn_time + 0.25
	var after_turn := fish._swimmer_pose(0)
	_check(before_turn.z < 0.0 and after_turn.z > 0.0 and at_turn.x < before_turn.x
		and is_equal_approx(after_turn.x, before_turn.x) and surface.water_at(Vector2(at_turn.x, at_turn.y)),
		"The fish turns at the left bank while still in the water")
	var exit_time := turn_time + leg / lane.z
	fish._time = exit_time - 0.25
	var leaving := fish._swimmer_pose(0)
	fish._time = exit_time + 0.25
	var entering := fish._swimmer_pose(0)
	_check(leaving.x > fish.size.x and entering.x > fish.size.x and leaving.z > 0.0 and entering.z < 0.0,
		"The fish loops only after swimming out of view on the right")
	fish._time = swim_time

	var rig_time := surface._time
	surface._time = 0.0
	var float_before := surface._float_position()
	var line_before := surface._line_point(0.5, float_before + Vector2(-3, -2))
	surface._time = 1.0
	var float_after := surface._float_position()
	var attachment := float_after + Vector2(-3, -2)
	_check(float_before != float_after and surface._line_point(0.5, attachment) != line_before
		and surface._line_point(0.0, attachment) == TitleMenu.Atmosphere.ROD_TIP
		and surface._line_point(1.0, attachment) == attachment, "The fishing line flexes between the fixed rod tip and moving bobber")
	surface._time = rig_time
	for land: Vector2 in [Vector2(210, 134), Vector2(165, 218), Vector2(179, 240)]:
		_click_at(fish.get_global_transform() * surface.cover_to_stage(land))
	_check(fish._jumps.is_empty(), "Sky, shore and the angler's boots reject fish clicks")
	if demo.continue_button.disabled:
		_click(demo.continue_button)
		_check(fish._jumps.is_empty(), "A disabled Continue row still shields the river")
	fish._rng.seed = 684
	var origin := surface.cover_to_stage(Vector2(245, 221))
	_click_at(fish.get_global_transform() * origin)
	_check(fish._jumps.size() == 1 and fish._bursts.size() == 1, "Clicking the open river launches one fish and one ripple")
	if fish._jumps.is_empty():
		fish.set_process(true)
		return
	var jump := fish._jumps[0]
	fish._process(jump.airtime * 0.5)
	_check(jump.origin.is_equal_approx(origin) and jump.offset(TitleMenu.RiverFish.GRAVITY).y < -20.0
		and not is_zero_approx(jump.velocity.x), "The fish follows an upward arc from the clicked position")
	_check(not demo._audio._players.has(Audio.Cue.TITLE_FISH_SPLASH), "The title fish makes no sound before landing")
	await _capture("01e-title-fish-jump")
	fish._process(jump.airtime * 0.5 + 0.01)
	var splash := fish._bursts.back() as TitleMenu.RiverFish.Burst
	_check(fish._jumps.is_empty() and splash.landing and surface.water_at(splash.origin)
		and is_equal_approx(splash.origin.y, origin.y), "The fish lands at its launch height and creates a splash within the river")
	var player := demo._audio._players.get(Audio.Cue.TITLE_FISH_SPLASH) as AudioStreamPlayer
	_check(player != null and player.playing and player.stream.resource_path.ends_with("/fish_water_plip.wav"),
		"Landing plays the dedicated fish splash on the same frame")
	fish._process(0.20)
	await _capture("01f-title-fish-splash")
	_click_at(fish.get_global_transform() * origin)
	_click_at(fish.get_global_transform() * origin)
	fish._process(1.0)
	_check(fish._jumps.is_empty() and fish._bursts.size() == 2 and player != null and player.playing and player.max_polyphony >= 2,
		"Two fish landing on the same frame trigger splash sounds without cutting each other off")
	# The open gap between Continue and Settings lies within the painted menu scrim.
	_click_at(fish.get_global_transform() * surface.cover_to_stage(Vector2(385, 168)))
	_check(fish._jumps.size() == 1, "The painted gap between the menu rows still accepts water clicks")
	_check(not demo.session.active and not demo.started, "River interaction leaves the shift clock suspended")
	fish.set_process(true)


func _check_return_to_title() -> void:
	var error := change_scene_to_file("res://scenes/demo/demo.tscn")
	_check(error == OK, "The playable scene can be opened through the scene tree")
	if error != OK:
		return
	await scene_changed
	demo = current_scene
	for use_keyboard in [true, false]:
		var old_scene_id: int = demo.get_instance_id()
		demo.auto_pause_on_focus_loss = false
		_click(demo.start_button)
		_click(demo._start_mode_modal.buttons[1])
		demo.session.coins = 99
		_key(KEY_ESCAPE)
		_check(demo._pause_banner.visible, "The active game can open the pause menu before returning to the title")
		if use_keyboard:
			_key(KEY_T)
		else:
			_click(demo._pause_buttons[2])
		_check(current_scene == demo and demo.is_inside_tree(), "Return to Title keeps the viewport attached until input dispatch finishes")
		var click := root.get_node_or_null("UI_CLICK") as AudioStreamPlayer
		_check(click != null and click.playing and not demo._audio._players.has(Audio.Cue.UI_CLICK),
			"Return to Title plays the click once under the scene tree root")
		# Keep the short cue active while the scene reloads, even on slow runners.
		if click != null:
			click.stream_paused = true
		await process_frame
		await process_frame
		var reloaded := current_scene != null and current_scene.get_instance_id() != old_scene_id
		_check(reloaded, "Return to Title reloads the playable scene")
		if not reloaded:
			return
		demo = current_scene
		_check(not demo.started and demo._menu.visible and not demo.session.paused and not demo._pause_banner.is_visible_in_tree(), "Return to Title reopens a fresh cover through the scene tree")
		_check(is_instance_valid(click) and click.get_parent() == root, "The click player survives the scene reload")
		if is_instance_valid(click):
			click.stream_paused = false
			await create_timer(0.25).timeout
			_check(not is_instance_valid(click), "The click player frees itself after playback")
	_click(demo.start_button)
	_click(demo._start_mode_modal.buttons[1])
	_check(demo.started and demo.session.coins == 40 and demo._river_image.visible, "A new game can start normally after returning to the title")


func _check_save_slots() -> void:
	var directory := "res://build/validation/save-slots-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.save_directory = directory
	demo.auto_pause_on_focus_loss = false
	root.add_child(demo)
	demo.session.set_process(false)
	demo.qte.set_process(false)
	_move_mouse(Vector2(24, 24))
	_check(demo.continue_button.disabled, "A fresh profile has no saved game to continue")
	_key(KEY_SPACE)
	_key(KEY_DOWN)
	_key(KEY_SPACE)
	_check(demo._pause_button.position.x == 36 and demo._summary.position.x > demo._pause_button.get_rect().end.x and not demo.has_save(), "The summary follows the top-left pause button and a new game leaves all save slots empty")
	demo.session.coins = 91
	demo.qte.cast()
	demo.qte.advance(0.5)
	_key(KEY_E)
	_key(KEY_E)
	_key(KEY_ESCAPE)
	var wait: float = demo.qte.remaining
	_key(KEY_F)
	var menu = demo._save_menu
	_check(menu.visible and menu.saving and menu.slot_buttons.size() == 5
		and menu.slot_buttons[4].text.contains("空位") and menu.delete_buttons[4].disabled,
		"Pause opens five empty slots with delete actions disabled")
	await _capture("10-save-slots", 0.20)
	_key(KEY_SPACE)
	var first_path := SaveSlots.existing_path(directory, 0)
	_check(not first_path.is_empty() and not menu._confirmation.visible and menu.slot_buttons[0].text.contains("渡魂币 91"), "Space writes to an empty slot immediately and updates its summary")
	demo.session.coins = 137
	_key(KEY_SPACE)
	_check(menu._confirmation.visible and menu._confirm_cursor == 0, "An occupied slot asks for confirmation with Cancel selected")
	await _capture("11-save-overwrite", 0.20)
	_key(KEY_C)
	_check(menu.visible and not menu._confirmation.visible and int(SaveSlots.read(first_path).coins) == 91, "C returns to the slots without overwriting")
	_key(KEY_SPACE)
	_key(KEY_D)
	_key(KEY_SPACE)
	_check(not menu._confirmation.visible and int(SaveSlots.read(first_path).coins) == 137, "Space on the overwrite confirmation replaces only that slot")
	demo.session.coins = 205
	_key(KEY_S)
	_key(KEY_SPACE)
	demo.session.coins = 220
	_key(KEY_S)
	_key(KEY_SPACE)
	demo.session.coins = 224
	_key(KEY_S)
	_key(KEY_SPACE)
	demo.session.coins = 225
	_key(KEY_S)
	_key(KEY_SPACE)
	var second_path := SaveSlots.existing_path(directory, 1)
	var third_path := SaveSlots.existing_path(directory, 2)
	var fourth_path := SaveSlots.existing_path(directory, 3)
	var fifth_path := SaveSlots.existing_path(directory, 4)
	_check(int(SaveSlots.read(second_path).coins) == 205 and int(SaveSlots.read(third_path).coins) == 220
		and int(SaveSlots.read(fourth_path).coins) == 224 and int(SaveSlots.read(fifth_path).coins) == 225,
		"Each of the five save slots stores independent progress")
	_click(menu.delete_buttons[3])
	_check(menu._confirmation.visible and menu._confirm_cursor == 0, "Clicking Delete opens a confirmation with Cancel selected")
	_move_mouse(Vector2(24, 24))
	await _capture("12-save-delete", 0.20)
	_key(KEY_SPACE)
	_check(not menu._confirmation.visible and FileAccess.file_exists(fourth_path), "Cancel keeps the selected save")
	_key(KEY_DELETE)
	_key(KEY_D)
	_key(KEY_SPACE)
	_check(not FileAccess.file_exists(fourth_path) and SaveSlots.existing_path(directory, 4) == fifth_path
		and menu.slot_buttons[3].text.contains("空位") and menu.delete_buttons[3].disabled,
		"Keyboard confirmation deletes only the selected slot and refreshes its row")
	_check(not SaveSlots.write(directory, 5, {}) and not SaveSlots.remove(directory, -1), "Save actions reject slots outside the five-slot range")

	_key(KEY_C)
	_check(not menu.is_open and demo.session.paused, "C from the slot list returns input to the pause menu")
	demo.session.coins = 999
	demo.session.essences[0] = 12
	demo.qte.phase = Fishing.Phase.READY
	_key(KEY_R)
	_check(menu.visible and not menu.saving, "R opens Load directly alongside Save and Return to Title")
	_key(KEY_S)
	_key(KEY_SPACE)
	_check(not menu.is_open and not demo.session.paused and demo.current_location == "Alchemy" and demo.session.coins == 205 and demo.session.essences[0] == 0, "Reading the second slot restores its wallet, inventory and location")
	_check(demo.qte.phase == Fishing.Phase.WAITING and is_equal_approx(demo.qte.remaining, wait), "Reading restores the unfinished fishing timer without charging for another cast")
	_key(KEY_Q)
	_key(KEY_Q)
	_hook_fish(demo.qte, 1, 1)
	demo.qte.advance(Data.PREPARATION)
	demo.qte.advance(demo.qte.get_target_time())
	var direction: int = demo.qte.get_expected_direction()
	_check(demo.save_progress(2), "An active reel-in can be saved")
	demo.qte.retract()
	_check(demo.load_progress(2) and demo.qte.phase == Fishing.Phase.REELING and demo.qte.locked.species == 1, "Reading a reel-in restores the pending fish")
	_check(demo.qte.submit_direction(direction) and demo.qte.progress == 2 and demo.qte.durability() == 9 and demo.qte.bait_stock[0] == 9, "A restored reel-in keeps its timing and consumes no additional bait or durability")
	demo.qte.advance(Data.ROUND_GAP)
	demo.qte.advance(demo.qte.get_target_time())
	direction = demo.qte.get_expected_direction()
	_check(demo.qte.submit_direction(direction) and demo.qte.phase == Fishing.Phase.HOLDING, "The next round starts a sustained input")
	demo.qte.advance(demo.qte.remaining)
	var release_time: float = demo.qte.remaining
	_check(demo.qte.phase == Fishing.Phase.RELEASE_WAIT and demo.save_progress(2), "A pending surge can be saved while the gold ring is active")
	demo.qte.retract()
	_check(demo.load_progress(2) and demo.qte.phase == Fishing.Phase.RELEASE_WAIT and demo.qte.needs_rehold, "Reload preserves the surge and waits for a physical rehold")
	demo.qte.advance(2.0)
	_check(is_equal_approx(demo.qte.remaining, release_time) and demo.qte.mistakes == 0, "Reload leaves the release window frozen until rehold")
	demo.qte.submit_direction(direction)
	demo.qte.advance(demo.qte._release_lead)
	demo.qte.release_direction(direction)
	_check(demo.qte.phase == Fishing.Phase.CAUGHT and demo.session.catches.is_empty() and demo.session.codex_fish["fish_02"].caught == 1, "The restored surge lands exactly one fish")
	demo.session.advance(demo.session.spawn_remaining)
	demo.session.requirements.assign([Vector3i(7, 7, 7), Vector3i(9, 9, 9)])
	var guest: Dictionary = demo.session.souls[0]
	guest.case_id = 0
	guest.stats = Vector3i(6, 5, 7)
	guest.fee = 40
	demo.session._add_potion("medicine_01", "启明药", Vector3i(2,0,0), -1, 0)
	var first_dose: int = demo.session.potions[-1].id
	demo.session._add_potion("medicine_02", "暖心药", Vector3i(0,2,0), -1, 0)
	var second_dose: int = demo.session.potions[-1].id
	var served: bool = demo.session.serve(guest.id, false, first_dose) and demo.session.serve(guest.id, false, second_dose)
	_check(served and demo.save_progress(2) and demo.load_progress(2), "A visitor can be saved after taking two doses")
	var restored_guest: Dictionary = demo.session.get_soul(guest.id)
	_check(Session.doses_used(restored_guest) == 2 and restored_guest.fee == 40, "Reload keeps the two doses and the original base fee")
	_check(demo.session.release_soul(guest.id) and demo.session.last_payout == 22, "A reloaded two-dose visitor still pays half of the original reward")
	var interim := SaveSlots.read(third_path)
	interim["rules_version"] = 15
	interim.erase("grip_durability")
	interim.erase("quick_repair_available")
	interim["shared_wear"] = 3
	interim["bait_stock"] = [2, 0, 0, 0, 3, 0, 0, 1]
	interim["bait"] = 4
	var scheduled: Dictionary = interim.day_schedule
	scheduled.erase("bounds")
	scheduled.guests = scheduled.guests.map(func(entry: Array) -> Dictionary: return {"case_id": entry[0]})
	_check(SaveSlots.write(directory, 2, interim) and demo.load_progress(2), "A slot written during the v1.5 trial remains readable after rollback")
	_check(Session.doses_used(demo.session.get_soul(guest.id)) == 2 and demo.qte.durability() == 7 and demo.qte.bait_stock[0] == 5, "Trial slots retain dose counts, accumulated wear and recovered starter bait")
	_check(demo.load_progress(4) and demo.session.coins == 225, "The fifth save slot can restore progress")
	demo.queue_free()
	await process_frame

	var legacy_path := directory.path_join(SaveSlots.LEGACY_NAME)
	var legacy_data := SaveSlots.read(first_path)
	legacy_data.erase("fishing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(first_path))
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_data))
	legacy_file.close()
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.save_directory = directory
	demo.auto_pause_on_focus_loss = false
	root.add_child(demo)
	demo.session.set_process(false)
	demo.qte.set_process(false)
	_key(KEY_S)
	_key(KEY_SPACE)
	_check(demo._save_menu.visible and not demo.started, "Continue on the title opens the same five-slot load menu")
	var fish := demo._menu.get_node("RiverFish") as TitleMenu.RiverFish
	_click_at(fish.get_global_transform() * fish._surface.cover_to_stage(Vector2(405, 248)))
	_check(fish._jumps.is_empty() and demo._save_menu.is_open, "An open load dialog also blocks clicks outside its panel")
	await _capture("01d-title-load", 0.20)
	_key(KEY_C)
	_check(not demo._save_menu.is_open and not demo.started, "C from the title load menu returns input to the title")
	await create_timer(0.18).timeout
	await process_frame
	_check(not demo._save_menu.visible, "The title load menu finishes closing after its fade")
	_key(KEY_SPACE)
	_key(KEY_SPACE)
	_check(demo.started and demo.session.coins == 137 and demo.qte.phase == Fishing.Phase.READY, "The previous single-file save loads from slot one")
	_check(demo.save_progress(0) and FileAccess.file_exists(legacy_path), "Saving slot one can coexist with the legacy file")
	demo.queue_free()
	await process_frame
	for slot in [1, 2, 4]:
		SaveSlots.remove(directory, slot)
	var damaged_path := FileAccess.open(fourth_path, FileAccess.WRITE)
	damaged_path.store_string("corrupted save")
	damaged_path.close()
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.save_directory = directory
	demo.auto_pause_on_focus_loss = false
	root.add_child(demo)
	await process_frame
	_key(KEY_S)
	_key(KEY_SPACE)
	menu = demo._save_menu
	_key(KEY_DELETE)
	_key(KEY_D)
	_key(KEY_SPACE)
	_check(not FileAccess.file_exists(first_path) and not FileAccess.file_exists(legacy_path),
		"Deleting slot one removes both its current save and the legacy fallback")
	_check(menu.slot_buttons[3].text.contains("存档无法读取") and not menu.delete_buttons[3].disabled,
		"A damaged save is still eligible for deletion")
	_key(KEY_DELETE)
	_key(KEY_D)
	_key(KEY_SPACE)
	_check(not FileAccess.file_exists(fourth_path) and not demo.has_save() and demo.continue_button.disabled
		and _title_highlight_is(demo.start_button), "Deleting the final save disables Continue and selects Start")
	_key(KEY_C)
	_check(not menu.is_open and not demo.started, "The empty save manager returns to the title without loading a game")
	for cue in [Audio.Cue.UI_CLICK, Audio.Cue.UI_CONFIRM]:
		var player := demo._audio._players.get(cue) as AudioStreamPlayer
		if player != null and player.playing:
			await player.finished
	demo.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func _check_keyboard_workflows() -> void:
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.auto_pause_on_focus_loss = false
	demo.persist_save = false
	root.size = Vector2i(1620,972)
	root.add_child(demo)
	await process_frame
	demo._start_game()
	for node in [demo.session,demo.qte,demo.river,demo.shop]:
		node.set_process(false)
	var session: Session = demo.session
	for species in Data.FISH.size():
		session.record_catch({"species": species, "size": 0 if species != Data.VARIANT else 3, "cm": 5.0})
	_key(KEY_E)
	_key(KEY_E)
	for code in [KEY_D,KEY_S,KEY_S,KEY_S]:
		_key(code)
	_check(demo.alchemy.selected_source == Data.VARIANT, "Keyboard selects the final material row")
	_key(KEY_SPACE)
	_check(session.potions.size() == 1 and session.potions[0].kind == "medicine_11", "Space brews three giant materials")
	_key(KEY_SHIFT)
	_key(KEY_X)
	_key(KEY_V)
	_key(KEY_SPACE)
	_check(session.potions[0].attribute == 1 and session.potions[0].adjustment == -1, "Keyboard adjusts one finished dose")
	await _capture("09-keyboard-brewing")
	demo.queue_free()
	await process_frame


func _check_stillfin() -> void:
	var session: Session = demo.session
	var before := session.essences[7]
	session.record_catch({"species": Data.STILLFIN, "size": 1, "cm": 14.0})
	_check(session.essences[7] == before + 3 and session.essences[Data.STILLFIN] == 0, "Stillfin banks the shared suppression material")
	_check(Data.source_data(Data.STILLFIN).outcomes == Data.source_data(7).outcomes, "Stillfin and echo brew the same medicines")


func _seed_first_day() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 100:
		rng.seed = seed
		if Session.roll_requirements(1, rng)[0] == Vector3i(0, 7, 7):
			demo.session._rng.seed = seed
			return
	_check(false, "Find a deterministic start with the postman and boatman")


func _check_daily_rotation(session: Session) -> void:
	var combinations := {}
	var shapes_match := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 472
	for sample in 72:
		for day_number in range(1, 6):
			var limits := Session.roll_requirements(day_number, rng)
			var lowers := 0
			var uppers := 0
			var ranges := 0
			for axis in 3:
				var has_min := limits[0][axis] > 0
				var has_max := limits[1][axis] < Session.STAT_MAX
				lowers += int(has_min)
				uppers += int(has_max)
				ranges += int(has_min and has_max)
			var expected: Array = [[2, 0, 0], [1, 1, 0], [2, 1, 0], [3, 3, 3], [3, 3, 3]][day_number - 1]
			shapes_match = shapes_match and [lowers, uppers, ranges] == expected
			if day_number == 1:
				combinations[limits[0]] = true
	_check(shapes_match and combinations.size() == 3, "Every day uses its intended rule shape and all three pairs can be drawn on day one")
	_check_starter_cases()

	var snapshot := session.save_day()
	var reload := Session.new()
	root.add_child(reload)
	reload.set_process(false)
	reload.restore_day(JSON.parse_string(JSON.stringify(snapshot)))
	_check(reload.save_day() == snapshot and reload.souls.is_empty(), "Saved rules, itinerary and arrival position survive JSON round-trip")
	reload.souls.assign([session.souls[0].duplicate()])
	reload.restore_day({})
	_check(reload.requirements == [Vector3i(7, 7, 7), Vector3i(9, 9, 9)] and not reload.has_more_arrivals(), "A legacy queue keeps its displayed ranges until its pending guests leave")
	reload.free()
	_check_smaller_roster_save()

	for day_number in range(1, Session.DAY_COUNT + 1):
		_check(session.day == day_number, "The previous day's last release opens exactly one new day")
		session.advance(300.0)
		var already_released := session.released_count + session.rejected_count - (day_number - 1) * Session.GUESTS_PER_DAY
		_check(session.souls.size() + already_released == 6 and not session.has_more_arrivals(), "The day's arrivals stop after six guests")
		if day_number == 4:
			_check(demo.soul_hud._legend_label.text.count("～") == 3, "Reception displays all three day-four target ranges")
			await _capture("09-day-four-requirements")
		for soul in session.souls.duplicate():
			if soul.has("story_case"):
				_check(_resolve_story(session, soul.id), "A scheduled story guest can be resolved")
				continue
			soul.stats = session.requirements[0]
			_check(session.release_soul(soul.id), "A guest meeting the inclusive current bounds can be released")
		if session.awaiting_day_report:
			session.close_day_report()
	_check(session.is_complete() and session.day == 5 and session.released_count + session.rejected_count == 30 and session._first_services.size() <= 30, "All thirty service slots complete while compatible people may return on later days")


func _check_smaller_roster_save() -> void:
	var model := Session.new()
	root.add_child(model)
	model.active = true
	model.released_count = 4
	model._first_services = {1: true, 2: true, 3: true, 4: true}
	model._arrived = 5
	model.souls.append({"id": 5, "case_id": 8, "stats": Vector3i(8, 6, 8), "fee": 40})
	var old_day := {"number": 3, "bounds": [[6, 0, 6], [10, 8, 10]], "guests": [[8, -1], [0, -1]], "arrivals": 1}
	model.restore_day(old_day)
	var upgraded := model.save_day()
	_check(model.day == 3 and upgraded.bounds == old_day.bounds and upgraded.guests.slice(0, 2) == old_day.guests and upgraded.guests.size() == 6, "An older day keeps its rules and lineup and gains enough guests to reach six")
	model.advance(160.0)
	_check(model.souls.size() == 6 and model.total_guests() == 22 and model.souls[0].id == 5 and model.souls[1].case_id == 0, "Migration preserves the pending guest, future arrival order and historic day counts")
	for soul in model.souls.duplicate():
		soul.stats = model.requirements[0]
		model.release_soul(soul.id)
	_check(model.day == 4 and model.total_guests() == 22 and model.has_more_arrivals(), "Migrated progress advances to the next day without resetting its day number")
	model.free()


func _resolve_story(session, id: int) -> bool:
	var runtime = session.get_story_runtime(id)
	if runtime == null:
		return false
	var guard := 0
	while not runtime.is_closed() and guard < 80:
		if runtime.is_awaiting_judgment():
			var config: Dictionary = runtime.start_judgment(session.coins)
			if config.is_empty():
				break
			runtime.resolve_judgment(int(config.get("max", 0)) / 2)
			continue
		var choices: Array = runtime.visible_choices()
		if choices.is_empty():
			if not runtime.advance():
				break
		else:
			var picked := false
			for choice in choices:
				if bool(choice.get("locked", false)):
					continue
				runtime.choose(str(choice.get("id", "")))
				picked = true
				break
			if not picked:
				break
		guard += 1
	if not runtime.is_closed():
		return false
	return session.finish_story(id)


func _check_starter_cases() -> void:
	var planner := preload("res://scripts/systems/soul_planner.gd")
	var all_compatible := true
	for seed_value in 12:
		var model := Session.new()
		root.add_child(model)
		model.set_process(false)
		model._rng.seed = seed_value
		model.start_shift()
		for day_number in [1, 2]:
			model._open_day(day_number)
			for plan in model._guest_plans.values():
				for outcome in Data.source_data(plan.source).outcomes:
					all_compatible = all_compatible and planner.eligible(planner.apply_dose(plan.stats, Data.POTIONS[outcome[0]].effect), model.requirements)
		model.free()
	_check(all_compatible, "Both base and upgrade outcomes solve every early teaching order")


func _check_attribute_baits(fishing: Fishing) -> void:
	_check(Data.BAITS.size() == 5 and Data.BAIT_PRICES == [2,4,4,4,8], "Five baits use the approved prices")
	_check(fishing.fish_weights(0, Data.Bait.WILL)[Data.STILLFIN] == 15.0 and fishing.fish_weights(1, Data.Bait.WILL)[Data.STILLFIN] == 0.0, "Will bait attracts the shallow Stillfin")
	_check(fishing.fish_weights(0, Data.Bait.WISDOM)[5] == 60.0 and fishing.fish_weights(0, Data.Bait.WISDOM)[0] == 75.0, "Attribute bait includes both directions")
	_check(fishing.size_weights(0)[0] == 80.0 and is_equal_approx(fishing.size_weights(0)[2], 1.5) and fishing.size_weights(1)[1] == 260.0, "Only hooks determine small, medium and large fish weights")


func _check_ferry_crossing() -> void:
	var session: Session = demo.session
	var original_arrival := session.spawn_remaining
	_check(not demo.river.get_ferry_rect().has_area(), "The ferry is hidden outside the eight-second arrival window")
	session.advance(original_arrival - 8.0)
	var distant: Rect2 = demo.river.get_ferry_rect()
	_check(distant.has_area() and distant.end.y == 89.0, "The ferry appears at the far bank exactly eight seconds before the arrival")
	await _capture("02d-ferry-far-bank")
	session.advance(4.0)
	var crossing: Rect2 = demo.river.get_ferry_rect()
	_check(crossing.position.x < distant.position.x and crossing.end.y > distant.end.y, "The ferry crosses the river down and left")
	await _capture("02e-ferry-crossing")
	_key(KEY_ESCAPE)
	session.advance(1.0)
	_check(demo.river.get_ferry_rect() == crossing, "The ferry freezes with the arrival clock during pause")
	_key(KEY_ESCAPE)
	_key(KEY_E)
	_check(not demo.river.get_ferry_rect().has_area(), "The ferry only draws in the fishing view")
	session.advance(1.0)
	_key(KEY_Q)
	var resumed: Rect2 = demo.river.get_ferry_rect()
	_check(resumed.has_area() and resumed.position.x < crossing.position.x, "Returning to the river uses the current arrival time")
	session.advance(session.spawn_remaining - 0.1)
	var leaving: Rect2 = demo.river.get_ferry_rect()
	_check(leaving.position.x < 0.0 and leaving.end.x <= 1.0, "The ferry clears the left edge at the end of the crossing")
	session.spawn_remaining = original_arrival


func _check_rig_picker() -> void:
	var rig_slot: Button = demo._rig[3]
	demo.auto_pause_on_focus_loss = true
	var arrival: float = demo.session.spawn_remaining
	_key(KEY_SHIFT)
	_check(demo._rig_slot_cursor == 0 and not demo._rig_popup.visible, "Shift enters the slot selector")
	demo.session.advance(0.2)
	_check(is_equal_approx(demo.session.spawn_remaining, arrival - 0.2), "Arrival time advances in the slot selector")
	_key(KEY_C)
	_check(demo._rig_slot_cursor == -1 and not demo._cast_button.disabled, "C at slot level returns to fishing")
	_key(KEY_SHIFT)
	_key(KEY_SPACE)
	_check(demo._rig_open_slot == 0, "Space opens the rod body list")
	_key(KEY_C)
	_check(demo._rig_slot_cursor == 0 and not demo._rig_popup.visible and demo._cast_button.disabled, "C returns from the rod list to its slot")
	_key(KEY_W)
	_key(KEY_SPACE)
	await process_frame
	_check(demo._rig_popup.visible and not demo.session.is_time_suspended() and not demo.river.paused and demo._summary.text.contains("第 1 天"), "Opening the bait list keeps the river and session running")
	demo.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not demo.session.paused, "Moving window focus while choosing cannot activate manual pause")
	demo.session.advance(2.0)
	_check(is_equal_approx(demo.session.spawn_remaining, arrival - 2.2), "Arrival time advances while browsing bait")
	await _capture("02a-rig-picker")
	_key(KEY_D)
	_check(demo._rig_option_cursor == Data.Bait.WISDOM, "D moves to the adjacent bait in the same row")
	_key(KEY_S)
	_check(demo._rig_option_cursor == Data.Bait.WILL, "S moves down one row in the same column")
	_key(KEY_A)
	_check(demo._rig_option_cursor == Data.Bait.EMOTION, "A moves left within the current row")
	_key(KEY_W)
	_check(demo._rig_option_cursor == Data.Bait.DEFAULT, "W moves up one row in the same column")
	_key(KEY_D)
	_key(KEY_SPACE)
	await process_frame
	_check(not demo._rig_popup.visible and demo._rig_slot_cursor == -1 and demo.qte.bait == Data.Bait.WISDOM, "Confirming bait equips it and returns to fishing")
	_key(KEY_SHIFT)
	_key(KEY_W)
	_key(KEY_SPACE)
	_key(KEY_S)
	_key(KEY_C)
	_check(demo._rig_slot_cursor == 3 and not demo._rig_popup.visible and demo.qte.bait == Data.Bait.WISDOM, "C returns to the bait slot without equipping the highlighted bait")
	_click(rig_slot)
	await process_frame
	_key(KEY_ESCAPE)
	_check(demo.session.paused and not demo._rig_popup.visible and demo._rig_slot_cursor == -1, "Escape pauses the game from the picker")
	_key(KEY_ESCAPE)
	_click(rig_slot)
	await process_frame
	_click(demo._rig_option_buttons[0])
	await process_frame
	demo.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(demo.session.paused and demo._pause_banner.visible, "Actual application focus loss still pauses")
	demo.auto_pause_on_focus_loss = false
	_click(demo._pause_button)


func _check_recipes(session: Session) -> void:
	_check(Data.POTIONS.size() == 11, "The complete fixed medicine table has eleven entries")
	var before := session.potions.size()
	session.essences[0] += 3
	_check(session.brew(0) and session.potions.size() == before + 1, "One pure brew always produces a medicine")
	var medicine := session.potions[-1]
	_check(medicine.effect == Data.POTIONS[medicine.kind].effect, "Finished effects are fixed by product identity")
	session.concentrate += 1
	_check(session.strengthen(false, medicine.id, 1, 1) and not session.strengthen(false, medicine.id, 1, 1), "A finished dose supports one adjustment")
	_check(not session.mix(0, 1) and session.dose(true, 0).is_empty(), "Mixed brewing and direct material serving are unavailable")


func _check_special_cases(fishing: Fishing, session: Session) -> void:
	var bones := session.recovered_bones
	for seed_value in 30:
		fishing._rng.seed = seed_value
		fishing.phase = Fishing.Phase.WAITING
		fishing._snapshot = {"rod": 0, "hook": 0, "bait": 0, "attachments": 0}
		fishing.bait_stock[0] += 1
		fishing.grip_durability = 10
		fishing._bite()
		_check(not fishing.locked.has("bone"), "Ordinary bites always enter the fish branch")
	_check(session.recovered_bones == bones, "Retired bone events cannot add resources")
	fishing.phase = Fishing.Phase.READY
	fishing.set_at_river(true)
	fishing._snapshot = {"rod": 1, "hook": 0, "bait": Data.VARIANT_BAIT, "attachments": 0}
	fishing.locked = {"species": Data.VARIANT, "size": 3, "cm": 35.0}
	fishing._start_fish_capture()
	_check(fishing.phase == Fishing.Phase.TRUE_NAME, "The giant retains its true-name capture")
	fishing.retract()


func _check_missed_bite(fishing: Fishing, session: Session) -> void:
	var durability_before := fishing.durability()
	var bait_before := fishing.bait_stock[fishing.bait]
	var catch_count := session.catches.size()
	fishing.cast()
	_key(KEY_Q)
	_hook_fish(fishing, 1, 1)
	fishing._process(2.75)
	_key(KEY_ESCAPE)
	fishing._process(10.0)
	_check(fishing.phase == Fishing.Phase.AWAITING_RETURN and is_equal_approx(fishing.remaining, 0.25), "Pausing freezes the bite alert countdown")
	_key(KEY_ESCAPE)
	fishing._process(0.25)
	_check(fishing.phase == Fishing.Phase.ESCAPED and not demo._river_bite_alert.visible and not demo._river_notice.visible, "At three seconds the fish escapes and the bite bubble closes")
	_key(KEY_E)
	_check(fishing.phase == Fishing.Phase.ESCAPED and demo._river_status.text.contains("鱼脱钩了"), "Returning after the deadline shows the escaped fish status")
	_check(fishing.durability() == durability_before - 1 and fishing.bait_stock[fishing.bait] == bait_before - 1 and session.catches.size() == catch_count, "A missed bite charges exactly once and gives no catch")


func _check_location_navigation() -> void:
	for location in ["Shop", "Alchemy", "Market", "River"]:
		_key(KEY_E)
		_check(demo.current_location == location, "E cycles forward to %s" % location)
	for location in ["Market", "Alchemy", "Shop", "River"]:
		_key(KEY_Q)
		_check(demo.current_location == location, "Q cycles backward to %s" % location)
	_key(KEY_R)
	_key(KEY_T)
	_key(KEY_E, true)
	_check(demo.current_location == "River", "R, T and held-key repeats do not change location")
	_click(demo._alchemy_button)
	_check(demo.alchemy.visible and demo._alchemy_button.disabled, "Clicking the alchemy tab opens and selects it")
	_click(demo._previous_location_button)
	_check(demo._shop_ui.visible and demo._shop_button.disabled, "The Q button goes to the previous location")
	_click(demo._next_location_button)
	_check(demo.alchemy.visible and demo._alchemy_button.disabled, "The E button goes to the next location")
	_click(demo._river_button)


func _hook_fish(fishing: Fishing, species: int, size: int) -> void:
	for seed_value in 20000:
		fishing._rng.seed = seed_value
		var candidate := fishing._roll_fish(fishing.rod, fishing.bait)
		if candidate.get("species") == species and candidate.get("size") == size:
			fishing._rng.seed = seed_value
			fishing.advance(fishing.remaining)
			return
	_check(false, "A reachable fish/size pair can be selected")


func _pull(direction: int, use_arrow: bool = false) -> void:
	var code: Key = Fishing.ARROW_KEYS[direction] if use_arrow else Fishing.DIRECTION_KEYS[direction]
	_key(code)
	demo._submit_pending_pull()
	if demo.qte.phase == Fishing.Phase.HOLDING:
		demo.qte.advance(demo.qte.remaining)
	if demo.qte.phase == Fishing.Phase.RELEASE_WAIT:
		demo.qte.advance(demo.qte._release_lead)
	_key(code, false, false)


func _freeze() -> void:
	demo.session.set_process(false)
	demo.qte.set_process(false)
	demo.river.set_process(false)
	demo.shop.set_process(false)


func _key(code: Key, echo: bool = false, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_freeze()


func _click(button: Button) -> void:
	_click_at(button.get_global_rect().get_center())


func _click_at(point: Vector2) -> void:
	_move_mouse(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	_freeze()


func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_freeze()


func _title_highlight_is(selected: Button) -> bool:
	for button: TitleMenu.Row in demo._menu_buttons:
		if button.selected != (button == selected):
			return false
	return is_equal_approx(demo._menu_pointer.position.y, selected.position.y)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _capture(label: String, settle: float = 0.0) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	if settle > 0.0:
		await create_timer(settle).timeout
	demo.river.queue_redraw()
	demo.shop.queue_redraw()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation/playtest")
	var error := root.get_texture().get_image().save_png("res://build/validation/playtest/%s.png" % label)
	_check(error == OK, "Saved rendered checkpoint " + label)
