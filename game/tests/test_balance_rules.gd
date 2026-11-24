extends SceneTree
## Accepted v1.5 balance, campaign, inventory, save and live UI regression.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_catalog()
	_test_candidate_pools()
	await _test_doses_and_rewards()
	await _test_economy()
	await _test_campaign()
	await _test_live_ui_and_save()
	print("Balance and integrated demo: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_catalog() -> void:
	var expected := [Vector3i(2, 0, 0), Vector3i(0, 2, 0), Vector3i(0, 0, 2), Vector3i(1, -1, 4), Vector3i(-1, 4, 1), Vector3i(-1, -1, 0), Vector3i(0, -1, -1), Vector3i(-1, 0, -1), Vector3i(2, 0, 2), Vector3i(4, 1, -1), Vector3i(4, 0, -1)]
	_check(Data.FISH.size() == 11 and Data.RECIPES.size() == 66, "Exactly eleven fish and sixty-six compounds remain")
	var vectors := {}
	for index in expected.size():
		_check(Data.FISH[index].effect == expected[index], "Confirmed raw vector %d" % index)
		vectors[Data.FISH[index].effect] = true
	_check(vectors.size() == 11, "Every raw species retains a distinct effect")
	var recipe_ids := {}
	var giants := 0
	for first in 11:
		for second in range(first, 11):
			var recipe := Data.recipe(first, second)
			_check(not recipe.is_empty() and Data.recipe(second, first) == recipe, "Recipes are complete and order-independent")
			recipe_ids[recipe.id] = true
			var effect: Vector3i = expected[first] + expected[second]
			if first == 0 and second == 4:
				effect.x += 1
			if first == 1 and second == 3:
				effect.y += 1
			if first == 2 and second == 10:
				effect.z += 1
			_check(recipe.effect == effect, "Recipe result matches fixed ingredients and the three specified neutralizations")
			var has_giant := first == 10 or second == 10
			_check(Data.is_variant_compound(recipe.id) == has_giant, "Giant privilege follows recipe provenance")
			giants += int(has_giant)
	_check(recipe_ids.size() == 66 and giants == 11, "Stable unique recipe IDs and exactly eleven giant recipes")
	_check(Data.recipe(10, 10).effect == Vector3i(8, 0, -2), "Extreme knowledge is plus eight wisdom, minus two will")
	_check(Data.recipe(2, 10).effect == Vector3i(4, 0, 2), "Steady knowledge still neutralizes giant will loss")
	_check(not Data.is_variant_compound("fish_01_variant") and not Data.is_variant_compound("unknown"), "Raw giant and unknown IDs never get compound privilege")
	_check(Data.fish_name(2, 0) == "幽灯鱼" and Data.fish_texture(2, 0) == Data.fish_texture(2, 1), "Small lantern fish is ordinary in name and art")
	for size in 3:
		_check(Session.yield_for({"species": 2, "size": size}) == size + 1, "Ordinary lantern yields one, two, three")
	_check(Session.yield_for({"species": 10, "size": 3}) == 2, "Giant yields two raw portions")
	_check(Data.BAITS.size() == 8 and not "愚笨饵" in Data.BAITS and "细屑饵" in Data.BAITS, "Only the documented bait types remain")
	var targets := {1: [0, 5, 8, 9], 2: [1, 6, 4], 3: [2, 7, 3]}
	for bait in targets:
		for species in 11:
			_check(Data.bait_matches_fish(bait, species) == targets[bait].has(species), "Attribute bait targets stay fixed, including negative fish")


func _test_candidate_pools() -> void:
	var stages := [Data.BASIC_FISH, range(10), range(11)]
	var expected := [Vector2i(130, 16), Vector2i(429, 240), Vector2i(455, 291)]
	for index in stages.size():
		var pool := Session.build_candidate_pool(stages[index])
		var precise := 0
		for entry in pool:
			_check(not _passes(entry.stats), "Generated state is not initially compliant")
			for basic: int in [0, 1, 2, 5, 6, 7]:
				_check(not _passes(entry.stats + Data.FISH[basic].effect), "No basic raw alone solves a candidate")
			_check(not entry.targets.is_empty(), "Every admitted state has at least one real single-dose solution")
			for target: Vector3i in entry.targets:
				_check(_passes(target), "Every candidate endpoint lies inside all three release ranges")
			precise += int(entry.targets.size() >= 2)
		_check(Vector2i(pool.size(), precise) == expected[index], "Exhaustive stage pool matches independently verified counts")
	var extreme_states := 0
	for w in 11:
		for e in 11:
			for v in 11:
				var result := Vector3i(w, e, v) + Vector3i(8, 0, -2)
				if _passes(result):
					extreme_states += 1
	_check(extreme_states == 12, "Extreme knowledge has twelve legal one-dose initial states")


func _test_doses_and_rewards() -> void:
	var model := Session.new()
	root.add_child(model)
	model.set_process(false)
	model.active = true
	model.day = 5
	# Giant compound works without a target, with a different target, and with an exact target.
	for target in [null, Vector3i(8, 9, 7), Vector3i(8, 8, 7)]:
		var soul := _soul(1, Vector3i(0, 8, 9), target)
		model.souls.assign([soul])
		model.essences[10] = 2
		_check(model.mix(10, 10), "Two giant portions make one extreme knowledge dose")
		var item: int = model.potions.back().id
		var change := model.preview(1, false, item)
		_check(change.after == Vector3i(8, 8, 7) and change.perfect and change.reward == 130, "Preview guarantees one thirty-percent bonus after compliant giant compound")
		var before := model.coins
		_check(model.serve(1, false, item) and model.potions.is_empty() and soul.doses_used == 1, "One compound is consumed exactly once")
		model.essences[0] = 1
		_check(not model.serve(1, true, 0) and model.essences[0] == 1, "A second dose cannot consume inventory")
		_check(model.release_soul(1) and model.coins - before == 130, "Giant and exact match never stack above one hundred thirty")
		_check(not model.release_soul(1) and model.coins - before == 130, "A released soul cannot pay twice")
	model.souls.assign([_soul(2, Vector3i(4, 8, 9))])
	model.essences[10] = 1
	_check(model.serve(2, true, 10) and model.can_release(2) and not model.is_perfect(2), "Single giant raw can release but has no automatic perfect privilege")
	_check(model.release_soul(2) and model.last_payout == 100, "Single giant raw pays the ordinary flat reward")
	for exact in [false, true]:
		model.souls.assign([_soul(3, Vector3i(7, 7, 10), Vector3i(8, 7, 9))])
		model.essences.fill(2)
		_check(model.mix(0 if exact else 1, 7 if exact else 6), "Basic ingredients can make the two exact-target alternatives")
		var item: int = model.potions.back().id
		_check(model.serve(3, false, item) and model.release_soul(3), "Both alternatives satisfy ordinary release")
		_check(model.last_payout == (130 if exact else 100), "Only the precise ordinary recipe earns the extra thirty")
	model.souls.assign([_soul(4, Vector3i(8, 8, 8))])
	model.essences[10] = 1
	var stock := model.essences[10]
	_check(not model.preview(4, true, 10).in_bounds and not model.serve(4, true, 10), "Out-of-bounds dosage is rejected without clamping")
	_check(model.essences[10] == stock and not model.get_soul(4).served, "Rejected dosage preserves stock and the unique dose")
	model.souls.assign([_soul(5, Vector3i(0, 0, 0))])
	model.essences[10] = 2
	model.mix(10, 10)
	var giant: int = model.potions.back().id
	_check(not model.preview(5, false, giant).in_bounds and not model.serve(5, false, giant), "Giant compound cannot bypass bounds")
	model.souls.assign([_soul(6, Vector3i(0, 0, 2))])
	_check(model.serve(6, false, giant) and not model.can_release(6) and model.reward_for(6) == 0, "Noncompliant giant compound does not trigger perfect or a payout")
	var money := model.coins
	_check(model.dismiss_soul(6) and model.coins == money, "A failed one-dose attempt can leave without softlocking or paying")
	model.record_catch({"species": 2, "size": 0, "cm": 12.0})
	var raw_before := model.essences[2]
	_check(model.refine(model.catches.back().id) and model.concentrate == 0 and model.essences[2] == raw_before + 1, "Small lantern refining awards one ordinary raw and no concentrate")
	model.concentrate = 10
	_check(not model.strengthen(true, 2, 0, 1) and model.concentrate == 10, "Enhancement cannot be invoked through the old API")
	model.queue_free()
	await process_frame


func _test_economy() -> void:
	var model := Session.new()
	root.add_child(model)
	model.active = true
	model.set_process(false)
	var fishing := Fishing.new()
	fishing.session = model
	root.add_child(fishing)
	fishing.set_process(false)
	_check(model.coins == 0 and model.essences[0] == 1 and model.essences[1] == 1, "Opening has zero coins and the two tutorial ingredients")
	_check(fishing.hook == 1 and fishing.grip_capacity() == 12 and fishing.charms_owned == 0, "Opening rig is short rod, medium hook and balanced grip")
	_check(fishing.buy_bait(0, 10) and model.coins == 0 and fishing.bait_stock[0] == 20, "Base bait is repeatedly claimable without gold")
	_check(not fishing.buy_bait(1, 1) and not fishing.unlock_bait(7), "Locked baits cannot be bought and giant prerequisites cannot be bypassed")
	model.coins = 400
	for device in [1, 2, 4, 6, 7, 8]:
		_check(fishing.buy_device(device), "Every documented new gear craft can be unlocked")
	_check(model.coins == 0 and fishing.all_gear_unlocked() and not fishing.buy_device(7), "All gear costs exactly four hundred with no repeated purchase")
	model.coins = 500
	for bait in [1, 2, 3, 4, 5, 6]:
		_check(fishing.unlock_bait(bait), "Non-giant bait craft unlock succeeds")
	_check(model.coins == 0 and not fishing.bait_unlocked[7], "Non-giant bait unlocks cost five hundred")
	model.coins = 500
	model.day = 3
	_check(fishing.unlock_bait(7) and model.coins == 0 and not fishing.is_bait_available(7), "Third-day giant unlock costs five hundred and waits until next day")
	model.day = 4
	model.coins = 10
	_check(fishing.buy_bait(7, 2) and model.coins == 6, "Giant bait becomes available next day at two coins each")
	fishing.shared_wear = 7
	fishing._sync_durability()
	for grip in [1, 2, 0, 1, 0]:
		fishing.set_rig(0, 1, grip, 0)
		_check(fishing.durability() == Data.GRIP_CAPACITIES[grip] - 7, "Switching grips preserves all shared wear")
	_check(fishing.repair(1) and model.coins == 1 and fishing.durability() == 12 and fishing.shared_wear == 0, "Any repair request repairs the shared set for five coins")
	_check(not fishing.repair(12) and model.coins == 1, "Full durability cannot consume another repair fee")
	for bait in [4, 5, 6]:
		var regular := fishing.size_weights(1)
		var biased := fishing.size_weights(1, bait)
		for size in 3:
			_check(is_equal_approx(biased[size], regular[size] * (3.0 if size == bait - 4 else 1.0)), "Size bait multiplies only its selected size")
	for bait in [1, 2, 3]:
		var regular := fishing.fish_weights(1, 0)
		var biased := fishing.fish_weights(1, bait)
		for species in 11:
			_check(is_equal_approx(biased[species], regular[species] * (3.0 if Data.bait_matches_fish(bait, species) else 1.0)), "Fixed attribute targets retain water eligibility and times-three weight")
	model.paused = true
	_check(not fishing.buy_bait(0, 10), "Paused state blocks even free supply mutation")
	fishing.queue_free()
	model.queue_free()
	await process_frame


func _test_campaign() -> void:
	var model := Session.new()
	root.add_child(model)
	model.set_process(false)
	model.story_db = null # Ordinary numeric campaign; story integration has a separate suite.
	model._rng.seed = 141123
	model.start_shift()
	var known := {}
	for day in range(1, 6):
		_check(model.day == day and model.requirements == [Vector3i(7, 7, 7), Vector3i(9, 9, 9)], "Release bounds stay seven to nine on all days")
		model.advance(1000.0)
		_check(model.souls.size() == 6 and not model.has_more_arrivals(), "Each day admits exactly six visitors")
		var exact := 0
		for soul in model.souls.duplicate():
			_check(not known.has(soul.case_id), "Visitor names/cases are not repeated during the campaign")
			known[soul.case_id] = true
			var stats: Vector3i = soul.stats
			_check(not _passes(stats) and not Session.basics_can_release(stats), "All campaign souls require a compound or advanced raw")
			var targets := Session.qualifying_targets(stats, Session.medicine_effects(Data.BASIC_FISH))
			_check(not targets.is_empty(), "Default campaign visitors have a shallow-water one-dose solution")
			if soul.perfect_target != null:
				exact += 1
				_check(targets.size() >= 2 and targets.has(soul.perfect_target), "Public target is reachable with at least two distinct alternatives")
			# Model-only campaign traversal: inventory/time feasibility is tested separately in the playable scene.
			soul.stats = targets[0]
			_check(model.release_soul(soul.id), "Each solved visitor can leave once")
		_check(exact >= 1 and exact <= 3, "Exactly one to three natural precise targets per day")
		if day < 5:
			_check(model.day == day and model.awaiting_next_day, "The last visitor opens the same day's night market")
			_check(model.start_next_day() and not model.awaiting_next_day, "Only an explicit next-day action advances the schedule")
	_check(model.is_complete() and model.released_count == 30 and known.size() == 30, "Five-day campaign closes after thirty unique successful visitors")
	model.queue_free()
	await process_frame


func _test_live_ui_and_save() -> void:
	root.size = Vector2i(1620, 972)
	var demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.auto_pause_on_focus_loss = false
	demo.persist_save = false
	demo.save_directory = "user://balance-v15-test-%d" % Time.get_ticks_usec()
	root.add_child(demo)
	await process_frame
	_freeze(demo)
	_check(not demo.started and demo._menu.visible, "Live scene starts at the cover")
	_key(KEY_SPACE)
	_freeze(demo)
	_check(demo.started and demo.current_location == "River", "Keyboard starts the playable scene")
	demo.session.advance(demo.session.spawn_remaining)
	_key(KEY_E)
	_check(demo.current_location == "Shop" and demo.shop.selected_id == 1, "Reception selects the actual tutorial visitor")
	_check(demo.session.souls[0].stats == Vector3i(5, 5, 8), "Tutorial requires the two gifted ingredients")
	_key(KEY_R)
	_key(KEY_SHIFT)
	_check(demo.alchemy.active_tab == 1 and demo.alchemy._tab_buttons.size() == 2, "Only refining and mixing tabs are accessible")
	demo.alchemy.mix_first = 0
	demo.alchemy.mix_second = 1
	demo.alchemy.refresh()
	await _capture("00-compound-preview")
	_key(KEY_F)
	_check(demo.session.potions.size() == 1 and demo.session.essences[0] == 0 and demo.session.essences[1] == 0, "Keyboard craft spends the two tutorial raw portions")
	_key(KEY_E)
	_key(KEY_S)
	_check(not demo._serve_button.disabled and "普通100" in demo._dose_preview.text, "Live dose preview shows the correct ordinary reward")
	await _capture("01-tutorial-preview")
	_key(KEY_SPACE)
	_check(demo.session.can_release(1) and demo._serve_button.disabled and "1/1" in demo._dose_preview.text, "Live UI disables all further medication after the first dose")
	_key(KEY_SHIFT)
	_check(demo.session.coins == 100 and demo.session.released_count == 1, "Keyboard release pays exactly one hundred")
	_key(KEY_T)
	demo.market.select_bait(4)
	_check(demo.market.action_button.text == "解锁鱼饵工艺", "Market distinguishes a permanent unlock from supply purchase")
	demo.market._execute_selected()
	_check(demo.session.coins == 40 and demo.qte.bait_unlocked[4] and demo.qte.bait_stock[4] == 0, "Market unlock spends sixty without silently creating consumables")
	demo.market._execute_selected()
	_check(demo.session.coins == 39 and demo.qte.bait_stock[4] == 1, "Subsequent market action purchases one bait at its unit price")
	await _capture("02-market-unlock-and-stock")
	# Run a complete normal fish QTE; no inventory injection is used for this capture.
	_key(KEY_Q)
	demo.qte._rng.seed = 1
	_check(demo.qte.cast(), "The starter rig can cast with a free base bait")
	var stock: int = demo.qte.bait_stock[0]
	demo.qte.advance(demo.qte.remaining)
	_check(demo.qte.bait_stock[0] == stock - 1 and demo.qte.shared_wear == 1, "A hooked event spends exactly one bait and one shared durability")
	if demo.qte.phase != Fishing.Phase.CAUGHT:
		while demo.qte.is_busy():
			if demo.qte.phase == Fishing.Phase.REELING:
				demo.qte.advance(demo.qte._travel)
				demo.qte.submit_direction(demo.qte.get_expected_direction())
			elif demo.qte.phase == Fishing.Phase.RELEASE_WAIT:
				demo.qte.advance(demo.qte._release_lead)
				demo.qte.release_direction(demo.qte.get_expected_direction())
			else:
				demo.qte.advance(demo.qte.remaining)
	_check(demo.qte.phase == Fishing.Phase.CAUGHT, "Complete fishing capture still works under the updated economy")
	# Save a genuine giant compound after serving to verify provenance and the consumed dose across reload.
	demo.session.souls.assign([_soul(99, Vector3i(0, 8, 9), Vector3i(8, 8, 7))])
	demo.session.essences[10] = 2
	demo.session.mix(10, 10)
	var giant: int = demo.session.potions.back().id
	_check(demo.session.serve(99, false, giant), "Prepared save contains an actually consumed giant compound")
	demo.session.state_changed.emit()
	demo.shop.select_guest(99)
	_key(KEY_E)
	_check("完美" in demo._guest_state.text and "130" in demo._service_fee.text, "Live reception identifies giant perfect redemption")
	await _capture("03-giant-perfect-result")
	demo.persist_save = true
	demo.save_progress(0)
	var saved_target: Variant = demo.session.get_soul(99).perfect_target
	var scheduled: Dictionary = JSON.parse_string(JSON.stringify(demo.session.save_day()))
	demo.session.get_soul(99).stats = Vector3i.ZERO
	demo.session.coins = 999
	demo.qte.shared_wear = 0
	_check(demo.load_progress(0), "New version save can be loaded")
	_check(demo.session.get_soul(99).stats == Vector3i(8, 8, 7) and demo.session.get_soul(99).perfect_target == saved_target, "Reload keeps result and exact target unchanged")
	_check(demo.session.reward_for(99) == 130 and demo.session.get_soul(99).doses_used == 1, "Reload retains giant provenance and the exhausted dose")
	_check(JSON.parse_string(JSON.stringify(demo.session.save_day())) == scheduled, "Reload does not reroll future visitors or precise targets")
	_check(demo.qte.bait_unlocked[4] and demo.qte.shared_wear == 1, "Reload restores unlocks and shared wear")
	demo.session.essences[0] = 1
	_check(not demo.session.serve(99, true, 0), "Reload never resets the dose limit")
	demo.persist_save = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(demo.SaveSlots.existing_path(demo.save_directory, 0)))
	var current_day: int = demo.session.day
	demo.session._day_arrived = demo.session._day_guests.size()
	_key(KEY_SHIFT)
	_check(demo.current_location == "Market" and demo.market.next_day_button.visible and demo.session.day == current_day, "Last departure opens the same night's market and shows the next-day control")
	await _capture("05-night-market")
	_key(KEY_F)
	_check(demo.session.day == current_day + 1 and not demo.session.awaiting_next_day and not demo.market.next_day_button.visible, "Market F starts the next day once, after night purchases")
	root.size = Vector2i(960, 576)
	await process_frame
	await _capture("04-small-window")
	_key(KEY_Q)
	demo._open_rig_popup(2)
	_check(demo._rig_option_buttons.size() == 3 and demo._rig_option_buttons[1].disabled, "Rig popup exposes three grips with permanent unlock requirements")
	await _capture("06-grip-selection")
	demo.queue_free()
	await process_frame


func _passes(stats: Vector3i) -> bool:
	return stats.x >= 7 and stats.x <= 9 and stats.y >= 7 and stats.y <= 9 and stats.z >= 7 and stats.z <= 9


func _soul(id: int, stats: Vector3i, target: Variant = null) -> Dictionary:
	return {"id": id, "case_id": id, "name": "验证灵魂", "stats": stats, "before": stats, "served": false, "doses_used": 0, "fee": 100, "perfect_target": target, "used_variant_compound": false, "medicine_kind": ""}


func _freeze(demo) -> void:
	for node in [demo.session, demo.qte, demo.river, demo.shop]:
		node.set_process(false)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/validation/v15")
	_check(root.get_texture().get_image().save_png("res://build/validation/v15/%s.png" % label) == OK, "Saved rendered checkpoint " + label)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
