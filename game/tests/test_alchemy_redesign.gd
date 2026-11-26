extends SceneTree
## Fixed medicines, viable orders, supply matching, economy and integrated save/UI.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const Planner := preload("res://scripts/systems/soul_planner.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const Demo := preload("res://scripts/demo/demo.gd")
const Alchemy := preload("res://scripts/demo/alchemy_panel.gd")

var checks := 0
var failures := 0
var demo: Demo


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	root.size = Vector2i(1620, 972)
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	session.start_shift()
	_check(Data.POTIONS.size() == 11 and Data.FISH.size() == 12 and Data.essence_indices().size() == 11, "12 fish share 11 materials and 11 standard medicines")
	_check(session.essences[1] == 3 and session.essences[2] == 6, "New saves receive the one-time 3/6 starter grant")
	var before := session.essences.duplicate()
	session.start_shift()
	_check(session.essences == before, "Restarting a shift cannot duplicate supplies")
	for size in 3:
		session.record_catch({"species": 1, "size": size, "cm": 10.0})
	_check(session.essences[1] == before[1] + 9 and session.catches.is_empty(), "Small/medium/large catches immediately bank 2/3/4 materials")
	session.record_catch({"species": Data.STILLFIN, "size": 0, "cm": 8.0})
	session.record_catch({"species": 7, "size": 1, "cm": 24.0})
	_check(session.essences[7] == 5 and session.essences[Data.STILLFIN] == 0, "Stillfin and echo materials share tails")
	_check(session.codex_fish.has("fish_11") and session.codex_fish.has("fish_08"), "Shared materials preserve distinct fish discoveries")
	session.record_catch({"species": Data.LANTERN, "size": 0, "cm": 15.0})
	_check(session.concentrate == 1, "Condensed lantern bonus is awarded on capture")
	_check(session.dose(true, 1).is_empty() and not session.serve(1, true, 1), "Materials cannot be served directly")
	session.essences[0] = 2
	_check(not session.brew(0) and session.essences[0] == 2, "Two tails cannot brew or lose materials")
	session.essences[0] = 30000
	var upgraded := 0
	for index in 10000:
		session.brew(0)
		upgraded += int(session.potions[-1].kind == "medicine_07")
	_check(upgraded > 2800 and upgraded < 3200 and session.essences[0] == 0, "First-tier brewing has 30% upgrades and costs exactly 3")
	_check(session.codex_sources.fish_01.size() == 2, "Only discovered source outcomes unlock their probabilities")
	session.potions.clear()
	session.essences[8] = 15000
	upgraded = 0
	for index in 5000:
		session.brew(8)
		upgraded += int(session.potions[-1].kind == "medicine_11")
	_check(upgraded > 870 and upgraded < 1130, "Second-tier brewing has 20% third-tier outcomes")
	session.potions.clear()
	session.essences[10] = 3
	_check(session.brew(10) and session.potions[-1].effect == Vector3i(5, 4, 4), "Giant materials guarantee the fixed third-tier medicine")
	var potion_id: int = session.potions[-1].id
	_check(session.strengthen(false, potion_id, 1, -1) and not session.strengthen(false, potion_id, 1, -1), "A finished dose may be adjusted exactly once")
	_check(Alchemy.medicine_rows(session).size() == session.potions.size(), "Reception lists only finished medicines")
	var bounds: Array[Vector3i] = [Vector3i(6, 7, 4), Vector3i(8, 9, 7)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for template in Data.Alchemy.GUESTS:
		var case_id := _case_id(template.name)
		var plan := Planner.generate(case_id, bounds, rng)
		_check(not plan.is_empty(), "Template can be generated: " + template.name)
		if plan.is_empty():
			continue
		var stats: Vector3i = plan.stats
		_check(stats == stats.clamp(Vector3i.ONE, Vector3i.ONE * 10) and not Planner.eligible(stats, bounds), "Initial values are legal and need treatment")
		for id in plan.route:
			stats = Planner.apply_dose(stats, Data.POTIONS[id].effect)
		_check(Planner.eligible(stats, bounds), "Recommended route reaches the day's interval")
		_check(plan.fee == (80 if plan.route.size() == 2 else [0, 25, 40, 60][Data.POTIONS[plan.route[0]].tier]), "Quote follows the minimum standard solution")
	for day in [4, 5]:
		for order in Session.STAT_ORDERS:
			var low := Vector3i.ZERO
			var high := Vector3i.ZERO
			var bands: Array = Session.DAY_FOUR_BANDS if day == 4 else Session.DAY_FIVE_BANDS
			for axis in 3:
				low[order[axis]] = bands[axis].x
				high[order[axis]] = bands[axis].y
			var limits: Array[Vector3i] = [low, high]
			for template in Data.Alchemy.GUESTS:
				_check(not Planner.generate(_case_id(template.name), limits, rng).is_empty(), "Fixed defects work in every late-game interval")
	session.requirements = bounds
	_check(session.service_fee(Vector3i(5, 9, 7)) == 25 and session.service_fee(Vector3i(1, 3, 1)) == 60, "Expensive medicine cannot increase a simple case quote")
	var soul := {"case_id": 0, "fee": 25, "served": false}
	_check(session.release_reward(soul, Vector3i(7, 9, 7), 2) == 13, "First-visit bonus is included before halving and flooring")
	soul.fee = 80
	session._first_services[0] = true
	_check(session.release_reward(soul, Vector3i(7, 9, 7), 2) == 40, "A native two-dose case normally pays 40")
	for seed_value in range(1, 19):
		session._rng.seed = seed_value
		session._first_services.clear()
		session.potions.clear()
		session.essences.fill(0)
		session.upper_supply_claimed = false
		for day in range(1, 6):
			session._open_day(day)
			_check(session._day_guests.size() == 6, "Each day has a complete roster including story slots")
			var seen := {}
			for plan in session._guest_plans.values():
				_check(not seen.has(plan.case_id), "No ordinary person is duplicated within one day")
				seen[plan.case_id] = true
				var stats: Vector3i = plan.stats
				for id in plan.route:
					stats = Planner.apply_dose(stats, Data.POTIONS[id].effect)
				_check(session.is_eligible(stats), "Every scheduled ordinary order is solvable")
				_check(not plan.route.has("medicine_11"), "Third-tier orders are not forced without stocked medicine")
			if day == 2:
				var stock := session.essences.duplicate()
				for plan in session._guest_plans.values():
					stock[plan.source] -= 3
					_check(stock[plan.source] >= 0, "Upper-limit grant covers the five actual ordinary guests")
				before = session.essences.duplicate()
				session.grant_upper_supply()
				_check(before == session.essences, "Upper-limit grant cannot repeat")
			for plan in session._guest_plans.values():
				session._first_services[plan.case_id] = true
	var fishing := Fishing.new()
	fishing.session = session
	root.add_child(fishing)
	fishing.set_process(false)
	_check(fishing.fish_weights(0, 0).reduce(func(a: float, b: float) -> float: return a + b, 0.0) == 100.0, "Shallow total remains 100 after bringing back Stillfin")
	_check(fishing.fish_weights(0, Data.Bait.WILL)[Data.STILLFIN] == 15.0 and fishing.fish_weights(0, Data.Bait.WILL)[2] == 45.0, "Attribute bait boosts positive and negative fish")
	_check(fishing.size_weights(0)[0] == 80.0 and is_equal_approx(fishing.size_weights(0)[2], 1.5) and fishing.size_weights(1)[1] == 260.0, "Only hook selection changes the size weights")
	for hook in 3:
		fishing._snapshot = {"hook": hook}
		for seed_value in 40:
			fishing._rng.seed = seed_value
			var baseline: int = fishing._roll_fish(0, Data.Bait.DEFAULT).size
			for bait in Data.BAITS.size():
				fishing._rng.seed = seed_value
				_check(fishing._roll_fish(0, bait).size == baseline, "Changing bait never changes the hook's size roll")
	session.coins = 300
	_check(not fishing.buy_bait(Data.VARIANT_BAIT, 1), "Special bait is locked behind its craft")
	_check(fishing.buy_device(1) and fishing.unlock_variant_craft() and session.coins == 60, "Deep rod plus standalone craft costs 160 + 80")
	_check(fishing.buy_bait(Data.VARIANT_BAIT, 1) and session.coins == 52, "Unlocked special bait costs 8")
	fishing.grip_durability = 0
	_check(fishing.repair(false) and session.coins == 46 and fishing.durability() == 5, "Quick repair costs 6 for 5 durability")
	fishing.grip_durability = 0
	_check(fishing.repair(true) and session.coins == 36 and fishing.durability() == 10, "Full repair costs 10 for 10 durability")
	fishing.restore_bait_inventory([1, 2, 3, 4, 5, 6, 7, 8, 9], 5)
	_check(fishing.bait_stock == [10, 7, 9, 11, 8] and fishing.bait == Data.Bait.EMOTION, "Nine-slot saves remap positive/negative baits without loss")
	fishing.restore_bait_inventory([1,2,3,4,5,6,7,8],7)
	_check(fishing.bait_stock == [10,5,6,7,8] and fishing.bait == Data.VARIANT_BAIT, "Retired size baits fold into base bait and special bait stays equipped")
	session.queue_free()
	fishing.queue_free()
	await _integrated()
	# Let the audio mixer release the final scene's brew playback.
	await create_timer(0.25).timeout
	print("Alchemy redesign: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))


func _case_id(title: String) -> int:
	for index in Data.SOULS.size():
		if Data.SOULS[index][0] == title:
			return index
	return -1


func _integrated() -> void:
	demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.persist_save = true
	demo.save_directory = "res://build/validation/alchemy-save-%d" % OS.get_process_id()
	demo.auto_pause_on_focus_loss = false
	root.add_child(demo)
	await process_frame
	for node in [demo.session, demo.qte, demo.river, demo.shop]:
		node.set_process(false)
	demo._start_game(true)
	_check(demo.tutorial_step == 1 and demo.session.essences[1] == 3, "Starter materials do not skip fishing tutorial")
	demo.session.record_catch({"species": 1, "size": 1, "cm": 10.0})
	demo._show_location("Alchemy")
	_check(demo.tutorial_step == 3 and demo.alchemy._tab_buttons.size() == 2, "After capture the tutorial goes straight to brewing")
	demo.alchemy._brew()
	_check(demo.tutorial_step == 4 and Alchemy.medicine_rows(demo.session).size() == 1, "A finished dose advances the tutorial to reception")
	var id: int = demo.session.potions[0].id
	_check(demo.session.serve(1, false, id) and demo.session.can_release(1), "Either first brew outcome completes the tutorial order")
	demo._finish_tutorial()
	demo.session.paused = true
	_check(demo.save_progress(0), "New rules and supplies save successfully")
	var expected := demo.session.essences.duplicate()
	var rules := demo.session.save_rules()
	demo.session.paused = false
	demo.session.essences[1] += 30
	_check(demo.load_progress(0) and demo.session.essences == expected and demo.session.save_rules() == rules, "Loading preserves materials, one-time flags and random state")
	demo.session.paused = false
	demo.session.essences[1] += 3
	demo.session.brew(1)
	var first_kind: String = demo.session.potions[-1].kind
	demo.load_progress(0)
	demo.session.paused = false
	demo.session.essences[1] += 3
	demo.session.brew(1)
	_check(demo.session.potions[-1].kind == first_kind, "Reloading resumes the same brewing random sequence")
	demo._codex._set_codex_page(1)
	demo._codex._open_source(1)
	_check(demo._codex._source_page and demo._codex._entry_ids.size() == 11, "Codex has a dedicated eleven-material page")
	demo._codex._set_codex_page(2)
	_check(demo._codex._entry_ids.size() == 11, "Finished medicine codex has eleven entries")
	demo.qte.phase = Fishing.Phase.WAITING
	demo.qte._snapshot = {"rod": 1, "hook": 0, "bait": Data.VARIANT_BAIT, "attachments": 0}
	demo.qte.remaining = 4.0
	_check(demo.save_progress(0), "A pending cast saves under the current bait layout")
	var saves := preload("res://scripts/demo/save_slots.gd")
	var old_layout := saves.read(saves.existing_path(demo.save_directory, 0))
	old_layout.bait_stock = [1,2,3,4,5,6,7,8]
	old_layout.bait = 7
	old_layout.fishing.snapshot.bait = 7
	old_layout.variant_craft_unlocked = true
	_check(saves.write(demo.save_directory, 0, old_layout) and demo.load_progress(0), "The retired eight-bait layout remains loadable")
	_check(demo.qte.bait == Data.VARIANT_BAIT and demo.qte.bait_stock == [10,5,6,7,8] and demo.qte._snapshot.bait == Data.VARIANT_BAIT, "Pending casts and inventory remap together when size baits retire")
	demo.qte.phase = Fishing.Phase.READY
	if "--capture" in OS.get_cmdline_user_args():
		demo.session.concentrate = 2
		demo._show_location("Alchemy")
		demo._codex.hide()
		await _capture("alchemy-workbench")
		demo.alchemy._switch_tab(1)
		await _capture("alchemy-strengthen")
		demo._set_paused(true, true)
		demo._codex._open_source(1)
		await _capture("alchemy-source-codex")
		demo._codex._set_codex_page(2)
		demo._codex._set_filter_from_bar(1)
		await _capture("alchemy-medicine-codex")
		demo._set_paused(false)
		demo._show_location("Market")
		demo.market.select_bait(Data.Bait.WILL)
		await _capture("alchemy-market")
	preload("res://scripts/demo/save_slots.gd").remove(demo.save_directory, 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(demo.save_directory))
	demo.queue_free()
	await process_frame


func _capture(title: String) -> void:
	await create_timer(0.45).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://build/validation/%s.png" % title)
