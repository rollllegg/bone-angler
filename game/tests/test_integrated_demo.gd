extends SceneTree
## Run with -- --capture and the renderer enabled to save gameplay checkpoints.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const River := preload("res://scripts/demo/pixel_river.gd")
const UI := preload("res://scripts/demo/demo_ui.gd")

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
	_check(_title_highlight_is(demo.start_button), "Only Start begins with the gold title style")
	await _capture("01-cover")
	var continue_disabled: bool = demo.continue_button.disabled
	demo.continue_button.disabled = false
	_key(KEY_S)
	_check(_title_highlight_is(demo.continue_button), "Selecting Continue makes it gold and restores Start to blue")
	_move_mouse(demo.quit_button.get_global_rect().get_center())
	await process_frame
	_check(_title_highlight_is(demo.quit_button), "Mouse hover moves the gold highlight to Quit")
	_key(KEY_S)
	_check(_title_highlight_is(demo.start_button), "Keyboard navigation wraps from Quit and restores its blue style")
	demo.continue_button.disabled = continue_disabled
	_key(KEY_S)
	if not demo.continue_button.disabled:
		_key(KEY_S)
	_check(_title_highlight_is(demo.settings_button), "Only Settings is gold after navigating to it")
	await _capture("01c-cover-settings-selected")
	_key(KEY_SPACE)
	await process_frame
	_check(demo._settings_panel.visible, "S moves to Settings, skipping Continue when unavailable, and Space opens it")
	await _capture("01b-settings")
	_key(KEY_C)
	await process_frame
	_check(not demo._settings_panel.visible and not demo.started, "C closes Settings without leaving the title screen")
	_key(KEY_W)
	if not demo.continue_button.disabled:
		_key(KEY_W)
	_key(KEY_SPACE)
	_check(demo.started and demo._river_image.visible and not demo._menu.visible and not demo.river.casting, "W and Space can start the game without also casting")
	_check(demo.session.coins == 40 and demo.qte.durability() == 10 and demo.qte.bait_stock[0] == 10 and demo.qte.equipped_charms() == 1 and demo.qte.hook == 0, "Opening equipment and money match the economy specification")
	_check(not demo.qte.buy_device(1) and not demo.qte.rods_owned[1], "The deep-water rod requires the stated purchase price")
	_check(arrival >= Data.ARRIVAL_MIN and arrival <= Data.ARRIVAL_MAX, "The first arrival keeps the demo interval")
	_check(demo._rig.size() == 4, "Only rod, hook, grip and bait can be selected at the river")
	_check(demo._stage.find_children("*", "OptionButton", true, false).is_empty(), "No native OptionButton dropdowns remain in the redesigned UI")
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
	_check(demo.session.souls[0].stats == Vector3i(8, 5, 8) and demo.shop.selected_id == 1, "The first configured case arrives while river input is suspended")
	_key(KEY_Q)
	_check(not demo.river.get_ferry_rect().has_area(), "The ferry is gone once its soul joins the queue")
	demo.river.advance_cast(0.01)
	_check(demo.river.get_cast_frame() == 1, "Second pose starts after 0.25 seconds")
	_key(KEY_P)
	demo.river.advance_cast(10.0)
	_check(demo.river.get_cast_frame() == 1 and demo._pause_banner.visible and demo._pause_banner.get_rect().end.y < 96.0, "Manual pause suspends casting and fits within the top bar")
	await _capture("02b-manual-pause")
	_click(demo._pause_button)
	_check(not demo.session.paused and not demo._pause_banner.visible, "The top-bar button resumes manual pause")
	_key(KEY_P)
	_key(KEY_SPACE)
	_check(not demo.session.paused and demo.river.casting, "Space resumes without another cast")
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
	_check(demo._river_bite_alert.visible and demo._river_bite_alert.text == "!" and demo._river_button.text.is_empty(), "A red exclamation mark replaces the Q in the river tab")
	_check(demo._river_notice.visible and demo._river_notice_title.text == "有鱼上钩了！" and demo._river_notice_detail.text.contains("Q"), "Reception shows the left-side bite bubble and the return shortcut")
	await _capture("02c-bite-alert")
	_key(KEY_R)
	fishing._process(2.9)
	_check(fishing.phase == Fishing.Phase.AWAITING_RETURN and demo._river_notice.visible, "Switching between other locations keeps the same return window and alert")
	_click(demo._river_button)
	_check(demo.current_location == "River" and not demo._river_bite_alert.visible and demo._river_button.text == "Q 河岸", "Clicking the alert returns to the river and restores Q")
	_check(not demo._river_notice.visible, "Returning to the river dismisses the bite bubble")
	_check(fishing.phase == Fishing.Phase.PREPARING and fishing.durability() == 9 and fishing.bait_stock[0] == Data.STARTING_BAIT - 1, "A locked fish spends one bait and one shared durability")
	_check(demo._river_status.text == "有鱼上钩了！" and not demo._river_status.text.contains("冥河鲫"), "Hooked status box does not spoil the fish species before landing")
	fishing.advance(Data.PREPARATION)
	_check(fishing.target == 4 and is_equal_approx(fishing.get_capture_time(), 20.0), "The normal carp uses the easy target and full first-round time")
	fishing.advance(fishing.get_target_time())
	demo.river._process(fishing.get_target_time())
	_check(demo.river.tension.length() > 0.8, "Rod bends along fish direction while reeling")
	await _capture("03-direction")
	_pull(fishing.get_expected_direction())
	_check(fishing.progress == 2 and fishing.last_judgement == Fishing.Judgement.PERFECT, "A timed opposite key earns two progress")
	demo.river._process(Data.ROUND_GAP)
	_check(demo.river.tension.length() < 0.1 and demo.river.hit_timer > 0.0, "Rod returns rapidly toward center during feedback while hit label stays readable")
	fishing.advance(Data.ROUND_GAP)
	_pull(fishing.get_expected_direction())
	_check(fishing.progress == 1 and fishing.mistakes == 1, "An early press costs one progress")
	fishing.advance(Data.ROUND_GAP)
	fishing.advance(fishing.get_target_time() - 0.25)
	_pull(fishing.get_expected_direction())
	_check(fishing.progress == 2 and fishing.last_judgement == Fishing.Judgement.NORMAL, "An ordinary-window press earns one progress")
	fishing.advance(Data.ROUND_GAP)
	fishing.advance(fishing.get_target_time() + 0.05)
	_key(KEY_E)
	fishing._process(12.0)
	_check(fishing.phase == Fishing.Phase.REELING and is_equal_approx(fishing.get_travel_ratio(), 1.0 + 0.05 / Data.TRAVEL[0]), "Switching to reception holds the capture time")
	_key(KEY_Q)
	_pull(fishing.get_expected_direction())
	_check(fishing.phase == Fishing.Phase.CAUGHT and session.catches.size() == 1, "Capture completes and adds the fish once")
	_check(demo._catch_fish_rect.visible and demo._catch_fish_rect.texture == Data.fish_texture(1, 1), "Caught fish displays the Feishu fish sprite instead of the temporary placeholder")
	var sprite: TextureRect = demo._catch_fish_rect
	var mouth := Vector2(3, 64) * (sprite.size / sprite.texture.get_size())
	_check(is_equal_approx(sprite.rotation_degrees, 90.0), "The caught fish hangs head up and tail down")
	_check((sprite.get_transform() * mouth).is_equal_approx(River.CATCH_LINE_END * 4.0), "The fish mouth aligns with the end of the fishing line")
	_check(fishing.durability() == 9 and fishing.bait_stock[0] == Data.STARTING_BAIT - 1, "Landing does not charge a second time")
	await _capture("03b-caught-fish")

	_key(KEY_R)
	_check(demo.alchemy.visible and not demo._shop_ui.visible, "R opens the alchemy station")
	_check(demo.alchemy.fish_cards.size() == 1 and demo.alchemy._refine_fish_tex.texture == Data.fish_texture(1, 1), "Alchemy displays the caught fish sprite and previews its potion")
	await _capture("04-alchemy")
	_key(KEY_SPACE)
	_check(session.catches.is_empty() and session.essences[1] == 2, "The caught normal fish refines into two separate doses")
	_click(demo.alchemy._tab_buttons[1])
	await process_frame
	if not demo.alchemy.essence_cards.is_empty():
		_click(demo.alchemy.essence_cards[0])
		await process_frame
		_click(demo.alchemy.essence_cards[0])
	await _capture("04b-alchemy-mix")
	_click(demo.alchemy._tab_buttons[0])
	_key(KEY_E)
	_check(demo.soul_hud.soul.stats == Vector3i(8, 5, 8) and demo._dose_buttons.size() == 1, "Reception shows soul stats in the top-left HUD and lists potions directly below")
	_check(demo._serve_button.disabled and demo.soul_hud.preview.is_empty(), "No potion preview is active before clicking a potion in the list")
	_click(demo._dose_buttons[0])
	await process_frame
	_check(not demo._serve_button.disabled and demo.soul_hud.preview.after == Vector3i(8, 7, 8) and demo._dose_preview.text.contains("8 / 7 / 8"), "Clicking a potion previews all three post-dose values on the top-left HUD")
	await _capture("04c-reception-preview")
	_key(KEY_SPACE)
	_check(session.get_soul(1).stats == Vector3i(8, 7, 8) and session.essences[1] == 1, "Serving consumes one dose and applies signed effects")
	demo.shop.advance_presentation(1.0)
	_check(session.released_count == 0 and not demo._release_button.disabled, "An eligible soul requires explicit release")
	await _capture("05-ready-to-release")
	_key(KEY_SHIFT)
	_check(demo.shop.departure_times == [0.0] and session.released_count == 1 and session.coins == 88, "Shift triggers departure and pays the 40-coin fee plus a first-service bonus")
	demo.shop.advance_presentation(2.0)
	await _capture("06-departure")
	demo.shop.advance_presentation(5.0)
	_check(demo.shop.departure_times.is_empty() and session.released_count == 1 and session.coins == 88, "Departure completion does not award the fee again")

	_key(KEY_T)
	_check(demo.market.visible and demo.market.active_filter == demo.market.Filter.ALL, "T opens the Octopath-style market showing ALL wares sorted by category")
	_key(KEY_SPACE)
	_check(demo.market.browsing_wares and session.coins == 88, "The first Space enters the item list without making a purchase")
	_key(KEY_W)
	_check(demo.market.selected_key == "device:0", "W moves to the previous market item")
	_key(KEY_S)
	await _capture("07-market")
	_key(KEY_SPACE)
	_check(fishing.rods_owned[1] and session.coins == 8 and fishing.rod == 0, "Buying the 80-coin long rod unlocks it without replacing the active rig")
	_key(KEY_C)
	_check(not demo.market.browsing_wares and demo.market.visible, "C backs out one level from market items")
	_key(KEY_S)
	_check(demo.market.active_filter == demo.market.Filter.ROD, "S selects the next market category after backing out")
	_click(demo.market.filter_buttons[4])
	await process_frame
	_check(demo.market.active_filter == demo.market.Filter.BAIT and demo.market.ware_buttons.size() == Data.BAITS.size(), "Left rail Bait filter shows only baits")
	demo.market.select_bait(Data.Bait.HATRED)
	_check(demo.market._detail_name.text == "憎恨饵" and demo.market._detail_desc.text == "降低情感的鱼，权重 ×3\n链颌鱼、墨眼鳉、泪纹鲦", "Market shows the effect and target fish of the selected attribute bait")
	await _capture("07b-market-attribute-bait")
	demo.market.select_bait(Data.VARIANT_BAIT)
	await _capture("07c-market-bait")
	_click(demo.market.action_button)
	_check(fishing.bait_stock[Data.VARIANT_BAIT] == 1 and session.coins == 2, "The special bait costs six coins")
	_click(demo.market.filter_buttons[5])
	await process_frame
	demo.market.select_repair(true)
	await _capture("07d-market-repair")
	_click(demo.market.action_button)
	_check(fishing.durability() == 10 and session.coins == 1, "Repair rounds one missing point up to one coin")

	_check_recipes(session)
	await _check_special_cases(fishing, session)
	_check_missed_bite(fishing, session)
	session.advance(300.0)
	_check(session.day == 1 and demo._queue_buttons.size() == 4, "Day one has six guests and two have already been released")
	_key(KEY_E)
	root.size = Vector2i(960, 576)
	await process_frame
	_check(demo._release_button.get_global_rect().end.x <= demo.get_viewport_rect().size.x, "Reception controls fit the smaller window")
	await _capture("08-small-window")
	await _check_daily_rotation(session)
	demo.queue_free()
	await process_frame
	await _check_keyboard_workflows()
	print("Integrated playtest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_keyboard_workflows() -> void:
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.auto_pause_on_focus_loss = false
	demo.persist_save = false
	root.size = Vector2i(1620, 972)
	root.add_child(demo)
	await process_frame
	_seed_first_day()
	_key(KEY_SPACE)
	var session: Session = demo.session
	for species in Data.FISH.size():
		session.record_catch({"species": Data.LANTERN if species == Data.VARIANT else species, "size": 0, "cm": 5.0})
	var lantern: int = session.catches[Data.VARIANT].id
	_key(KEY_R)
	for code in [KEY_D, KEY_S, KEY_A, KEY_S, KEY_S, KEY_D]:
		_key(code)
	await process_frame
	await process_frame
	var basket_scroll := demo.alchemy._fish_grid.get_parent() as ScrollContainer
	_check(demo.alchemy.selected_fish_id == lantern and basket_scroll.scroll_vertical > 0, "WASD moves by rows and columns and scrolls the selected catch into view")
	_key(KEY_SPACE)
	_check(session.catches.size() == Data.FISH.size() - 1 and session.essences[Data.LANTERN] == 1 and session.concentrate == 1, "Space refines the highlighted fish")
	_key(KEY_SPACE)
	_key(KEY_SHIFT)
	_key(KEY_SPACE)
	_key(KEY_D)
	_key(KEY_SPACE)
	_check(demo.alchemy.mix_first == 0 and demo.alchemy.mix_second == Data.LANTERN, "Space places the highlighted essence in the next recipe slot")
	_key(KEY_C)
	_check(demo.alchemy.mix_first == 0 and demo.alchemy.mix_second == -1, "C removes the last essence from the recipe")
	_key(KEY_SPACE)
	_key(KEY_F)
	_check(session.potions.size() == 1 and session.essences[0] == 0 and session.essences[Data.LANTERN] == 0, "F crafts the selected recipe even when it uses the last doses")
	_key(KEY_SHIFT)
	_key(KEY_X)
	_key(KEY_V)
	_key(KEY_SPACE)
	_check(session.potions[0].attribute == Data.Attribute.EMOTION and session.potions[0].adjustment == -1, "The keyboard can select an attribute, change direction and strengthen a potion")

	for species in [1, Data.LANTERN]:
		session.record_catch({"species": species, "size": 1, "cm": 15.0})
		session.refine(session.catches.back().id)
	session.advance(session.spawn_remaining)
	session.advance(session.spawn_remaining)
	var first_id: int = session.souls[0].id
	var second_id: int = session.souls[1].id
	_key(KEY_E)
	_key(KEY_D)
	_check(demo.shop.selected_id == second_id, "D selects the next waiting soul")
	_key(KEY_A)
	_key(KEY_W)
	_key(KEY_S)
	_check(demo.shop.selected_id == first_id and demo._selected_dose == [true, 1], "A selects the previous guest and W/S cycles the available medicines")
	_key(KEY_SPACE)
	_key(KEY_SHIFT)
	_check(demo.shop.departure_times == [0.0] and demo.soul_hud.soul.id == second_id and demo._queue_buttons.size() == 1, "The next guest takes over the counter and HUD immediately on release")
	for _dose_number in 2:
		_key(KEY_S)
		_key(KEY_S)
		_key(KEY_SPACE)
	_check(session.get_soul(second_id).stats.z == 9 and not demo._release_button.disabled, "The second guest accepts doses while the first is departing")
	_key(KEY_SHIFT)
	_check(demo.shop.departure_times.size() == 2 and session.released_count == 2, "The second departure starts without waiting for the first to finish")
	demo.shop.advance_presentation(1.4)
	_check(demo.shop.departure_times.size() == 2 and demo.shop.departure_times[1] > 0.0, "Both departure animations are playing at the same time")
	await _capture("09-overlapping-departures")
	var balance := session.coins
	_key(KEY_P)
	var paused_times: Array[float] = demo.shop.departure_times.duplicate()
	demo.shop.advance_presentation(10.0)
	_check(demo.shop.departure_times == paused_times, "Pause freezes every departure")
	_key(KEY_SPACE)
	demo.shop.advance_presentation(10.0)
	_check(demo.shop.departure_times.is_empty() and session.coins == balance, "All animations finish with no extra payouts")

	_key(KEY_T)
	for i in 4:
		_key(KEY_S)
	_key(KEY_SPACE)
	_key(KEY_D)
	_key(KEY_SPACE)
	_check(demo.qte.bait_stock[Data.Bait.DEFAULT] == Data.STARTING_BAIT + 5 and session.coins == balance - 10, "The keyboard can choose a market category, set a quantity and buy the selected bait")
	_key(KEY_C)
	_key(KEY_C)
	_check(demo.current_location == "River", "Two back steps leave the item list and return to the river")
	await _check_stillfin()
	demo.queue_free()
	await process_frame


func _check_stillfin() -> void:
	var fishing: Fishing = demo.qte
	var session: Session = demo.session
	_key(KEY_SPACE)
	demo.river.advance_cast(1.0)
	_hook_fish(fishing, Data.STILLFIN, 1)
	_check(fishing.phase == Fishing.Phase.PREPARING and fishing.locked.species == Data.STILLFIN and fishing.target == 4, "Stillfin bites in shallow water and uses the easy regular-fish QTE")
	fishing.advance(Data.PREPARATION)
	for _round in 2:
		fishing.advance(fishing.get_target_time())
		_pull(fishing.get_expected_direction())
		if fishing.phase == Fishing.Phase.FEEDBACK:
			fishing.advance(Data.ROUND_GAP)
	var landed: Dictionary = session.catches.back()
	_check(fishing.phase == Fishing.Phase.CAUGHT and landed.species == Data.STILLFIN, "Completing the QTE lands the stillfin in the basket")
	_check(demo._catch_fish_rect.visible and demo._catch_fish_rect.texture == Data.fish_texture(Data.STILLFIN), "The landed stillfin displays its own sprite")
	await _capture("10-stillfin-caught")
	_key(KEY_R)
	_key(KEY_SHIFT)
	demo.alchemy.fish_cards.back().pressed.emit()
	_check(demo.alchemy._refine_fish_tex.texture == Data.fish_texture(Data.STILLFIN), "The fish basket previews the stillfin sprite")
	await _capture("11-stillfin-refinement")
	_key(KEY_SPACE)
	_check(session.essences[Data.STILLFIN] == 2 and session.dose(true, Data.STILLFIN).effect == Vector3i(0, 0, -1), "The normal stillfin yields two doses that only lower will")
	session.advance(session.spawn_remaining)
	var guest: Dictionary = session.souls[0]
	session.requirements[1] = Vector3i(10, 10, 8)
	guest.stats = Vector3i(6, 8, 9)
	_key(KEY_E)
	_key(KEY_S)
	_key(KEY_S)
	_check(demo._selected_dose == [true, Data.STILLFIN] and demo.soul_hud.preview.after == Vector3i(6, 8, 8), "Reception previews the stillfin lowering just the excess will")
	_key(KEY_SPACE)
	_check(guest.stats == Vector3i(6, 8, 8) and session.essences[Data.STILLFIN] == 1, "Serving the stillfin dose makes the guest eligible")
	_key(KEY_SHIFT)
	_check(session.get_soul(guest.id).is_empty(), "The adjusted guest can be released")
	session.record_catch({"species": Data.STILLFIN, "size": 0, "cm": 7.0})
	session.refine(session.catches.back().id)
	_check(session.mix(Data.STILLFIN, Data.STILLFIN) and session.potions.back().effect == Vector3i(0, 0, -2), "Two stillfin doses make a pure minus-two-will compound")


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
		var already_released := session.released_count - (day_number - 1) * Session.GUESTS_PER_DAY
		_check(session.souls.size() + already_released == 6 and not session.has_more_arrivals(), "The day's arrivals stop after six guests")
		if day_number == 4:
			_check(demo.soul_hud._legend_label.text.count("～") == 3, "Reception displays all three day-four target ranges")
			await _capture("09-day-four-requirements")
		for soul in session.souls.duplicate():
			soul.stats = session.requirements[0]
			_check(session.release_soul(soul.id), "A guest meeting the inclusive current bounds can be released")
	_check(session.is_complete() and session.day == 5 and session.released_count == 30 and session._first_services.size() == 30, "All thirty guests complete the five-day shift without duplicate cases")


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


func _check_starter_cases() -> void:
	var single_dose_for_all := true
	var new_dose_solves_will := true
	var will_cases := 0
	for seed in 48:
		var model := Session.new()
		root.add_child(model)
		model._rng.seed = seed
		model.start_shift()
		for _day in 2:
			model.advance(160.0)
			single_dose_for_all = single_dose_for_all and model.souls.size() == 6
			for soul in model.souls.duplicate():
				var stats: Vector3i = soul.stats
				var violations := 0
				for axis in 3:
					violations += int(stats[axis] < model.requirements[0][axis] or stats[axis] > model.requirements[1][axis])
				var suitable := false
				for fish: Dictionary in Data.FISH:
					if fish.water[0] > 0:
						var after := (stats + Vector3i(fish.effect)).clamp(Vector3i.ZERO, Session.STAT_CEILING)
						suitable = suitable or model.is_eligible(after)
				single_dose_for_all = single_dose_for_all and violations == 1 and suitable
				if stats.z > model.requirements[1].z:
					will_cases += 1
					new_dose_solves_will = new_dose_solves_will and model.is_eligible(stats + Vector3i(0, 0, -1))
				soul.stats = model.requirements[0]
				model.release_soul(soul.id)
		model.free()
	_check(single_dose_for_all, "The first two days' cases each miss one requirement and are solvable with a single shallow-water essence")
	_check(will_cases > 0 and new_dose_solves_will, "Each early excess-will case can use one stillfin dose")


func _check_attribute_baits(fishing: Fishing) -> void:
	var targets := {
		Data.Bait.WISDOM: [0, 8, 9],
		Data.Bait.EMOTION: [1, 4],
		Data.Bait.WILL: [2, 3],
		Data.Bait.FOOLISHNESS: [4, 5, 7],
		Data.Bait.HATRED: [3, 5, 6],
		Data.Bait.DAZE: [7, 9, Data.STILLFIN],
	}
	_check(Data.BAITS.size() == 9 and Data.BAIT_PRICES.size() == 9, "The catalog has six attribute baits and no old size baits")
	for water in Data.RODS.size():
		var base := fishing.fish_weights(water, Data.Bait.DEFAULT)
		for idx: int in targets:
			var expected := base.duplicate()
			var has_target := false
			for species: int in targets[idx]:
				has_target = has_target or expected[species] > 0.0
				expected[species] *= 3.0
			_check(has_target and fishing.fish_weights(water, idx) == expected, "Only listed fish in this water receive the bonus: %s / %s" % [Data.BAITS[idx], Data.RODS[water]])
	_check(fishing.fish_weights(1, Data.Bait.WILL, 1)[Data.LANTERN] == 135.0, "School and attribute bait multiply")
	_check(fishing.fish_weights(0, Data.Bait.DAZE)[Data.STILLFIN] == 45.0 and fishing.fish_weights(1, Data.Bait.DAZE)[Data.STILLFIN] == 15.0, "Daze attracts the stillfin in both waters, more often in shallow water")
	_check(Data.VARIANT == 10 and fishing.fish_weights(1, Data.Bait.DAZE)[Data.VARIANT] == 0.0, "The existing variant inventory slot is preserved and remains outside normal bites")

	var original_stock := fishing.bait_stock.duplicate()
	var original_bait := fishing.bait
	var original_seed := fishing._rng.state
	var original_snapshot := fishing._snapshot.duplicate()
	var identical_sizes := true
	for hook in Data.HOOKS.size():
		fishing._snapshot = {"hook": hook}
		for sample_seed in 40:
			fishing._rng.seed = sample_seed
			var default_roll := fishing._roll_fish(1, Data.Bait.DEFAULT)
			for idx: int in targets:
				fishing._rng.seed = sample_seed
				identical_sizes = identical_sizes and fishing._roll_fish(1, idx).size == default_roll.size
	fishing._rng.state = original_seed
	fishing._snapshot = original_snapshot
	_check(identical_sizes, "Every attribute bait rolls the same size as the default bait given the same hook and random draw")
	var legacy_stock := [4, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
	fishing.restore_bait_inventory(legacy_stock, 14)
	_check(fishing.bait_stock == [5, 23, 9, 9, 7, 8, 9, 12, 13] and fishing.bait == Data.VARIANT_BAIT, "Old saves merge size and fish-specific inventory and preserve special bait")
	fishing.restore_bait_inventory(legacy_stock, 9)
	_check(fishing.bait == Data.Bait.FOOLISHNESS and fishing.bait_stock[Data.Bait.FOOLISHNESS] == 7, "An equipped old negative-stat fish bait converts to the matching attribute bait")
	fishing.restore_bait_inventory([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 2)
	_check(fishing.bait_stock == [10, 5, 6, 7, 8, 9, 10, 11, 12] and fishing.bait == Data.Bait.DEFAULT, "Existing size bait stock and equipped bait convert to the default bait")
	fishing.restore_bait_inventory(original_stock, original_bait)
	_check(fishing.bait_stock == original_stock and fishing.bait == original_bait, "New bait inventories load directly")


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
	_key(KEY_P)
	session.advance(1.0)
	_check(demo.river.get_ferry_rect() == crossing, "The ferry freezes with the arrival clock during pause")
	_key(KEY_P)
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
	_key(KEY_P)
	_check(demo.session.paused and not demo._rig_popup.visible and demo._rig_slot_cursor == -1, "P still pauses the game from the picker")
	_key(KEY_P)
	_click(rig_slot)
	await process_frame
	_click(demo._rig_option_buttons[0])
	await process_frame
	demo.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(demo.session.paused and demo._pause_banner.visible, "Actual application focus loss still pauses")
	demo.auto_pause_on_focus_loss = false
	_click(demo._pause_button)


func _check_recipes(session: Session) -> void:
	_check(Data.RECIPES.size() == 78, "All 78 recipes are present")
	var unmatched := 0
	var reactions := 0
	for first in Data.FISH.size():
		for second in range(first, Data.FISH.size()):
			var recipe := Data.recipe(first, second)
			if recipe.is_empty() or recipe != Data.recipe(second, first):
				unmatched += 1
				continue
			var expected: Vector3i = Data.FISH[first].effect + Data.FISH[second].effect
			if not recipe.reaction.is_empty():
				reactions += 1
				if [first, second] == [1, 3]:
					expected.y += 1
				elif [first, second] == [0, 4]:
					expected.x += 1
				elif [first, second] == [2, Data.VARIANT]:
					expected.z += 2
			if recipe.effect != expected:
				unmatched += 1
	_check(unmatched == 0 and reactions == 3, "Every pair resolves in both orders with the correct effects and exactly three special reactions")
	_check(not session.mix(1, 1) and session.essences[1] == 1, "A same-type compound does not consume a single available dose")
	session.record_catch({"species": Data.LANTERN, "size": 0, "cm": 12.0})
	_check(session.concentrate == 0 and session.refine(session.catches[0].id), "Capture does not award the lantern concentrate before refinement")
	_check(session.concentrate == 1 and session.essences[Data.LANTERN] == 1, "A small lantern refines into one dose and one concentrate")
	session.record_catch({"species": 6, "size": 0, "cm": 6.0})
	session.refine(session.catches[0].id)
	_check(session.mix(6, 1) and session.essences[6] == 0 and session.essences[1] == 0, "Mixing atomically spends one dose of each reagent")
	var medicine: Dictionary = session.potions[0]
	_check(medicine.effect == Vector3i.ZERO and session.strengthen(false, medicine.id, 1, 1), "Zero-effect potion can be adjusted after mixing")
	_check(medicine.effect == Vector3i(0, 1, 0) and not session.strengthen(false, medicine.id, 1, 1), "Each dose can only be strengthened once")
	var limits: Array[Vector3i] = [Vector3i(6, 4, 7), Vector3i(8, 7, 9)]
	_check(Session.meets_requirements(Vector3i(6, 7, 9), limits) and not Session.meets_requirements(Vector3i(6, 7, 10), limits), "Release includes both endpoints and excludes excessive attributes")


func _check_special_cases(fishing: Fishing, session: Session) -> void:
	_key(KEY_Q)
	fishing.set_rig(1, 0, 0, Data.VARIANT_BAIT)
	_check(fishing.equipped_charms() == 1, "The long rod only equips the owned charm")
	fishing.cast()
	var rng := RandomNumberGenerator.new()
	for seed in 1000:
		rng.seed = seed
		if rng.randf() < 0.80 and rng.randf() < Data.VARIANT_CHANCE:
			fishing._rng.seed = seed
			break
	_key(KEY_T)
	fishing._process(fishing.remaining)
	_check(fishing.phase == Fishing.Phase.AWAITING_RETURN and demo._river_notice.visible, "A variant also raises an alert away from the river")
	_key(KEY_Q)
	_check(fishing.phase == Fishing.Phase.TRUE_NAME and fishing.locked.species == Data.VARIANT, "The deep-water bait opens the independent variant branch")
	_check(is_equal_approx(fishing.remaining, Fishing.VARIANT_LIMIT), "Returning to the river starts the full true-name timer")
	_check(demo._river_status.text == "神秘鱼影 · 真名捕获" and not demo._river_status.text.contains("巨刺灰鳞鱼"), "True-name status box also keeps the species hidden before capture")
	for character in Fishing.VARIANT_WORD:
		_key(OS.find_keycode_from_string(character))
	_check(fishing.phase == Fishing.Phase.CAUGHT and session.catches[0].species == Data.VARIANT, "Typing the whole true name lands an independent variant")
	session.refine(session.catches[0].id)
	_check(session.essences[Data.VARIANT] == 2 and session.mix(Data.VARIANT, Data.VARIANT), "A variant refines into two doses for its compound")
	session.advance(session.spawn_remaining)
	var boatman: Dictionary = session.souls.back()
	session.record_catch({"species": Data.LANTERN, "size": 1, "cm": 21.0})
	session.refine(session.catches[0].id)
	session.serve(boatman.id, true, Data.LANTERN)
	session.serve(boatman.id, true, Data.LANTERN)
	_check(session.release_soul(boatman.id) and session.last_payout == 56 and session.coins == 57, "The boatman pays the first-service and commission bonuses when will is 9")
	session.advance(session.spawn_remaining)
	var worker: Dictionary = session.souls.back()
	var change := session.preview(worker.id, false, session.potions.back().id)
	_check(change.after.x == 10, "Potion preview clamps after applying the whole dose")
	_check(fishing.buy_bait(Data.BONE_BAIT, 2) and session.coins == 51, "Two bone baits cost six coins")
	_check(fishing.bait == Data.BONE_BAIT and fishing.can_cast(), "Buying bait when the equipped bait is empty automatically equips the new bait")
	fishing.charms_owned = 2
	fishing.set_rig(0, 0, 0, Data.BONE_BAIT)
	_check(fishing.equipped_charms() == 1, "The short rod automatically equips one of two owned charms")
	fishing.cast()
	for seed in 1000:
		rng.seed = seed
		if rng.randf() >= 0.40:
			fishing._rng.seed = seed
			break
	_key(KEY_R)
	fishing._process(fishing.remaining)
	_check(fishing.phase == Fishing.Phase.CAUGHT and fishing.durability() == 8 and fishing.bait_stock[Data.BONE_BAIT] == 1, "A bone lands automatically and consumes one bait and one durability")
	_check(demo._river_notice.visible and demo._river_notice_title.text == "钓到了遗骨！" and demo._river_notice_detail.text == "已回收遗骨 ×1" and not demo._river_bite_alert.visible, "Automatic bone recovery shows a distinct left-side notice in alchemy")
	await _capture("07e-bone-notice")
	_key(KEY_Q)
	_check(demo._river_notice.visible, "Returning to the river keeps the bone recovery notice visible")
	demo._process(4.0)
	fishing.state_changed.emit()
	_check(not demo._river_notice.visible, "The bone notice expires and subsequent refreshes do not show it again")
	_check(session.recovered_bones == 1 and session.catches.is_empty(), "Automatic recovery awards one bone and no fish")
	_check(not demo._cast_button.disabled and demo._retract_button.disabled and not demo._catch_fish_rect.visible, "After automatic recovery the rod is ready for the next cast")
	fishing.cast()
	_hook_fish(fishing, 1, 1)
	_key(KEY_X)
	_check(fishing.phase == Fishing.Phase.ESCAPED and fishing.durability() == 7 and session.catches.is_empty(), "Abandoning a locked catch preserves the charge")
	_check(fishing.buy_device(5), "The market sells an additional basic grip")
	fishing.set_rig(0, 0, 1, 0)
	_check(fishing.durability() == 10, "A newly purchased grip starts at full durability")
	fishing.set_rig(0, 0, 0, 0)
	_check(fishing.durability() == 7, "Reinstalling the previous grip restores its saved wear")
	fishing.set_rig(0, 0, 0, 3)
	demo._refresh_river()
	_check(demo._cast_button.disabled and demo._cast_button.text == "当前鱼饵 ×0" and demo._river_hint.text.contains("Shift 换饵"), "Selecting an empty bait clearly explains how to switch bait")
	fishing.set_rig(0, 0, 0, 0)


func _check_missed_bite(fishing: Fishing, session: Session) -> void:
	var durability_before := fishing.durability()
	var bait_before := fishing.bait_stock[fishing.bait]
	var catch_count := session.catches.size()
	fishing.cast()
	_key(KEY_T)
	_hook_fish(fishing, 1, 1)
	fishing._process(2.75)
	_key(KEY_P)
	fishing._process(10.0)
	_check(fishing.phase == Fishing.Phase.AWAITING_RETURN and is_equal_approx(fishing.remaining, 0.25), "Pausing freezes the bite alert countdown")
	_key(KEY_P)
	fishing._process(0.25)
	_check(fishing.phase == Fishing.Phase.ESCAPED and demo._river_button.text == "Q 河岸" and not demo._river_notice.visible, "At three seconds the fish escapes and the bite bubble closes")
	_key(KEY_Q)
	_check(fishing.phase == Fishing.Phase.ESCAPED and demo._river_status.text.contains("鱼脱钩了"), "Returning after the deadline shows the escaped fish status")
	_check(fishing.durability() == durability_before - 1 and fishing.bait_stock[fishing.bait] == bait_before - 1 and session.catches.size() == catch_count, "A missed bite charges exactly once and gives no catch")


func _hook_fish(fishing: Fishing, species: int, size: int) -> void:
	for seed in 2000:
		fishing._rng.seed = seed
		if fishing._rng.randf() >= (0.40 if fishing.bait == Data.BONE_BAIT else 0.80):
			continue
		var sample: Dictionary = fishing._roll_fish(fishing.rod, fishing.bait)
		if sample.species == species and sample.size == size:
			fishing._rng.seed = seed
			fishing.advance(fishing.remaining)
			return
	_check(false, "Could not find a deterministic regular catch")


func _pull(direction: int) -> void:
	var code: Key = Fishing.DIRECTION_KEYS[direction]
	_key(code)
	demo._submit_pending_pull()
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
	for button: Button in demo._menu_buttons:
		var style := button.get_theme_stylebox("normal") as StyleBoxTexture
		var expected := UI.BTN_GOLD_NORMAL if button == selected else UI.BTN_NORMAL
		if style.texture != expected:
			return false
	return is_equal_approx(demo._menu_pointer.position.y, selected.position.y)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	demo.river.queue_redraw()
	demo.shop.queue_redraw()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation/playtest")
	var error := root.get_texture().get_image().save_png("res://build/validation/playtest/%s.png" % label)
	_check(error == OK, "Saved rendered checkpoint " + label)
