extends SceneTree
## Probability boundaries, retired-resource migration and committed-action persistence.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const Slots := preload("res://scripts/demo/save_slots.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _probabilities()
	await _migration()
	print("v1.5 migration and fishing: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _probabilities() -> void:
	var model := Session.new()
	root.add_child(model)
	model.active = true
	model.set_process(false)
	var fishing := Fishing.new()
	fishing.session = model
	root.add_child(fishing)
	fishing.set_process(false)
	fishing.set_at_river(true)
	var shallow := fishing.fish_weights(0, 0)
	var deep := fishing.fish_weights(1, 0)
	var shallow_total := 0.0
	var deep_basic := 0.0
	var deep_advanced := 0.0
	for species in 11:
		shallow_total += shallow[species]
		_check(shallow[species] == (10.0 if species in Data.BASIC_FISH else 0.0), "Shallow eligibility and equal basic weights")
		var expected := 0.0
		if species in [1, 2, 6, 7]:
			expected = 10.0
			deep_basic += deep[species]
		elif species in [3, 4, 8, 9]:
			expected = 15.0
			deep_advanced += deep[species]
		_check(deep[species] == expected, "Deep eligibility and implicit-effect groups")
	_check(shallow_total == 60.0 and deep_basic == 40.0 and deep_advanced == 60.0, "Normalized shallow sixths and deep forty/sixty split")
	for scenario in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 7), Vector2i(1, 7)]:
		fishing._rng.seed = 151124
		var counts: Array[int] = []
		counts.resize(11)
		counts.fill(0)
		var size_counts := [0, 0, 0]
		fishing.bait_stock[scenario.y] = 30000
		fishing.shared_wear = 0
		for trial in 20000:
			fishing._snapshot = {"rod": scenario.x, "hook": 1, "bait": scenario.y, "attachments": 0}
			fishing._bite()
			_check(fishing.locked.has("species") and not fishing.locked.has("bone"), "Every hooked event is a fish")
			counts[fishing.locked.species] += 1
			if fishing.locked.species == Data.LANTERN:
				size_counts[fishing.locked.size] += 1
		_check(fishing.bait_stock[scenario.y] == 10000 and fishing.shared_wear == 20000, "Each hook spends exactly one bait and shared durability")
		var giant_rate := counts[Data.VARIANT] / 20000.0
		_check(absf(giant_rate - (0.20 if scenario == Vector2i(1, 7) else 0.0)) < 0.015, "Giant branch is twenty percent only for deep variant bait")
		if scenario == Vector2i(0, 0):
			for species in Data.BASIC_FISH:
				_check(absf(counts[species] / 20000.0 - 1.0 / 6.0) < 0.015, "Actual shallow sampling remains uniform")
			var weights := fishing.size_weights(1)
			var total: float = weights[0] + weights[1] + weights[2]
			var lantern_total: float = counts[Data.LANTERN]
			for size in 3:
				_check(absf(size_counts[size] / lantern_total - weights[size] / total) < 0.03, "Lantern uses ordinary sizes and existing hook bias")
		if scenario == Vector2i(1, 7):
			for species in [1, 2, 6, 7, 3, 4, 8, 9]:
				_check(absf(counts[species] / 20000.0 - (0.08 if species in Data.BASIC_FISH else 0.12)) < 0.015, "Variant fallback produces eight/twelve percent species rates")
	# Unbitten retraction is free; the chain's finger bones remain a separate catch resource.
	fishing.phase = Fishing.Phase.READY
	fishing.bait = 0
	fishing.shared_wear = 0
	fishing._sync_durability()
	var stock: int = fishing.bait_stock[0]
	_check(fishing.cast() and fishing.retract() and fishing.bait_stock[0] == stock and fishing.shared_wear == 0, "Retracting before a bite preserves stock and wear")
	fishing.locked = {"species": Data.CHAIN, "size": 2, "cm": 70.0}
	fishing._land()
	_check(model.finger_bones >= 1 and model.catches.back().species == Data.CHAIN, "Chain catch still awards finger bones")
	fishing.queue_free()
	model.queue_free()
	await process_frame


func _migration() -> void:
	var directory := "user://v15-migration-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var demo = preload("res://scenes/demo/demo.tscn").instantiate()
	demo.persist_save = false
	demo.auto_pause_on_focus_loss = false
	demo.save_directory = directory
	root.add_child(demo)
	await process_frame
	for node in [demo.session, demo.qte, demo.river, demo.shop]:
		node.set_process(false)
	demo._start_game()
	demo.session.advance(demo.session.spawn_remaining)
	demo.persist_save = true
	_check(demo.save_progress(0), "Write a real v1.5 slot")
	var path := Slots.existing_path(directory, 0)
	var old := Slots.read(path)
	old.erase("run_id")
	old.rules_version = 14
	old.coins = 42
	old["recovered_bones"] = 17
	old["concentrate"] = 12
	old.bait = 8
	old.bait_stock.append(7)
	old.bait_unlocked[1] = true
	old.bait_unlocked.append(true)
	old.shared_wear = 4
	var legacy_path := directory.path_join("bone_angler_save_v14.json")
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var original := FileAccess.get_file_as_string(legacy_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(demo.load_progress(0), "Load and migrate a v1.4 save")
	_check(demo.session.coins == 129 and demo.qte.bait == 0 and demo.qte.bait_stock.size() == 8, "Refund eighty plus seven remaining retired baits, switch to free bait")
	_check(demo.qte.bait_unlocked[1] and demo.qte.shared_wear == 4 and demo.session.concentrate == 0, "Keep prior craft and wear without price adjustment or enhancement")
	_check(FileAccess.get_file_as_string(legacy_path) == original, "Original save stays byte-for-byte unchanged")
	var migrated := Slots.read(Slots.existing_path(directory, 0))
	_check(migrated.rules_version == 15 and not migrated.has("recovered_bones") and migrated.bait_stock.size() == 8, "Migrated file is separate and contains no retired resource")
	_check(demo.load_progress(0) and demo.session.coins == 129, "Repeated continue does not refund twice")
	# Save before medication. A subsequent committed dose must survive loading that older slot.
	var soul_id: int = demo.session.souls[0].id
	_check(demo.session.mix(0, 1), "Prepare the tutorial compound")
	var potion_id: int = demo.session.potions.back().id
	_check(demo.save_progress(1), "Manual save before serving")
	_check(demo.session.serve(soul_id, false, potion_id), "Commit the unique dose")
	_check(demo.load_progress(1) and demo.session.get_soul(soul_id).doses_used == 1 and demo.session.potions.is_empty(), "Older same-run slot cannot rewind dosage or consumed inventory")
	var coins: int = demo.session.coins
	_check(demo.session.release_soul(soul_id), "Release the dosed guest")
	_check(demo.load_progress(1) and demo.session.get_soul(soul_id).is_empty() and demo.session.coins == coins + 100, "Older same-run slot cannot duplicate a settled reward")
	demo.persist_save = false
	demo.free()
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
