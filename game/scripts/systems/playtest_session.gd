extends Node

signal state_changed
signal soul_served(id: int)
signal day_finished

const Data := preload("res://scripts/systems/playtest_data.gd")
const StoryDB := preload("res://scripts/story/story_db.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const StoryRuntime := preload("res://scripts/story/story_runtime.gd")
const DAY_COUNT := 5
const GUESTS_PER_DAY := 6
const STAT_MAX := 10
const STAT_CEILING := Vector3i.ONE * STAT_MAX
const RELEASE_BOUNDS: Array[Vector3i] = [Vector3i(7, 7, 7), Vector3i(9, 9, 9)]

var catches: Array[Dictionary] = []
var essences: Array[int] = []
var potions: Array[Dictionary] = []
var souls: Array[Dictionary] = []
var concentrate := 0
var finger_bones := 0
var released_count := 0
var failed_count := 0
var awaiting_next_day := false
var available_species: Callable
var day := 1
var requirements: Array[Vector3i] = RELEASE_BOUNDS.duplicate()
var coins := Data.STARTING_COINS
var last_payout := 0
var _first_services: Dictionary = {}
var spawn_remaining := 0.0
var paused := false
var active := false
var _arrived := 0
var _day_guests: Array[Dictionary] = []
var _day_arrived := 0
var _next_item_id := 1
var _rng := RandomNumberGenerator.new()
var story_db = null
var story_state = null
var story_runtimes: Dictionary = {}
var story_open := false
var rejected_count := 0
var last_story_outcome := ""
var day_story_entries: Array[Dictionary] = []
var pending_day_report: Dictionary = {}
var awaiting_day_report := false


func _ready() -> void:
	_rng.randomize()
	essences.resize(Data.FISH.size())
	essences.fill(0)
	essences[0] = 1
	essences[1] = 1
	spawn_remaining = _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)
	story_db = StoryDB.new()
	story_db.load_all()
	restore_story({})
	story_state.run["run.day"] = day
	story_state.run["run.released"] = released_count


func restore_story(saved: Dictionary) -> void:
	story_state = StoryState.new()
	story_state.init_defaults(story_db.world_decl)
	story_state.restore(saved)
	story_runtimes.clear()


func _process(delta: float) -> void:
	advance(delta)


func is_time_suspended() -> bool:
	return paused or story_open or awaiting_day_report


func set_story_open(value: bool) -> void:
	if story_open == value:
		return
	story_open = value
	state_changed.emit()


func start_shift() -> void:
	_open_day(1)
	active = true


func has_more_arrivals() -> bool:
	return _day_arrived < _day_guests.size()


func is_complete() -> bool:
	return day == DAY_COUNT and souls.is_empty() and not has_more_arrivals()


func total_guests() -> int:
	var remaining := souls.size() + _day_guests.size() - _day_arrived + (DAY_COUNT - day) * GUESTS_PER_DAY
	return mini(Data.SOULS.size(), released_count + rejected_count + failed_count + remaining)


func advance(delta: float) -> void:
	if not active or is_time_suspended() or not has_more_arrivals() or delta <= 0.0:
		return
	spawn_remaining -= delta
	var arrived := false
	while spawn_remaining <= 0.0 and has_more_arrivals():
		var slot := _day_arrived
		var soul := _day_guests[slot].duplicate(true)
		soul.id = _arrived + 1
		var story_case := ""
		if story_db != null:
			story_case = story_db.get_scheduled_case(day, slot)
		if story_case != "":
			soul["story_case"] = story_case
			soul["story_outcome"] = ""
			soul["story_state"] = {}
			soul["name"] = story_db.get_queue_name(story_case)
			soul["stats"] = Vector3i(8, 8, 8)
			soul["before"] = soul["stats"]
			soul["fee"] = Data.RELEASE_REWARD
			soul["perfect_target"] = null
		_day_arrived += 1
		_arrived += 1
		souls.append(soul)
		spawn_remaining += _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)
		arrived = true
	if arrived:
		state_changed.emit()


static func roll_requirements(_number: int, _rng: RandomNumberGenerator) -> Array[Vector3i]:
	return RELEASE_BOUNDS.duplicate()


func _open_day(number: int) -> void:
	day = number
	awaiting_next_day = false
	day_story_entries.clear()
	requirements = RELEASE_BOUNDS.duplicate()
	_day_guests.clear()
	_day_arrived = 0
	_fill_day_roster()
	if story_state != null:
		story_state.run["run.day"] = day


func _fill_day_roster() -> void:
	var species: Array = available_species.call() if available_species.is_valid() else Data.BASIC_FISH.duplicate()
	# Daily ordinary service never requires the rare giant ingredient.
	species.erase(Data.VARIANT)
	var pool := build_candidate_pool(species)
	var precise := pool.filter(func(entry: Dictionary) -> bool: return entry.targets.size() >= 2)
	assert(not pool.is_empty() and not precise.is_empty(), "Available fish must support ordinary and exact-target visitors")
	var slots: Array = [1, 2, 3, 4, 5] if day == 1 else [0, 1, 2, 3, 4, 5]
	if story_db != null:
		for slot in slots.duplicate():
			if story_db.get_scheduled_case(day, slot) != "":
				slots.erase(slot)
	var selected: Array[int] = []
	for index in _rng.randi_range(1, 3):
		selected.append(slots.pop_at(_rng.randi_range(0, slots.size() - 1)))
	var used := {}
	for index in GUESTS_PER_DAY:
		var source: Array = precise if selected.has(index) else pool
		var candidate: Dictionary = source[_rng.randi_range(0, source.size() - 1)]
		while used.has(candidate.stats):
			candidate = source[_rng.randi_range(0, source.size() - 1)]
		if day == 1 and index == 0:
			candidate = {"stats": Vector3i(5, 5, 8), "targets": [Vector3i(7, 7, 8)]}
		used[candidate.stats] = true
		var case_id: int = Data.SOUL_ORDER[(day - 1) * GUESTS_PER_DAY + index]
		var target: Variant = null
		if selected.has(index):
			target = candidate.targets[_rng.randi_range(0, candidate.targets.size() - 1)]
		_day_guests.append({
			"id": 0, "case_id": case_id, "name": Data.SOULS[case_id][0],
			"stats": candidate.stats, "before": candidate.stats,
			"served": false, "doses_used": 0, "fee": Data.RELEASE_REWARD,
			"perfect_target": target, "used_variant_compound": false, "medicine_kind": "",
		})


func save_day() -> Dictionary:
	var guests: Array = []
	for guest in _day_guests:
		guests.append(save_soul(guest))
	return {"number": day, "guests": guests, "arrivals": _day_arrived, "daily_quota": GUESTS_PER_DAY, "awaiting_next_day": awaiting_next_day}


func restore_day(saved: Dictionary) -> void:
	day = clampi(int(saved.get("number", 1)), 1, DAY_COUNT)
	awaiting_next_day = bool(saved.get("awaiting_next_day", false))
	requirements = RELEASE_BOUNDS.duplicate()
	_day_guests.clear()
	for guest: Dictionary in saved.get("guests", []):
		_day_guests.append(restore_soul(guest))
	_day_arrived = clampi(int(saved.get("arrivals", 0)), 0, _day_guests.size())
	if _day_guests.is_empty():
		_fill_day_roster()


func get_soul(id: int) -> Dictionary:
	for soul in souls:
		if soul.id == id:
			return soul
	return {}


func can_release(id: int) -> bool:
	var soul := get_soul(id)
	if soul.is_empty() or soul.has("story_case"):
		return false
	return is_eligible(soul.stats)


func is_eligible(stats: Vector3i) -> bool:
	return meets_requirements(stats, requirements)


static func meets_requirements(stats: Vector3i, bounds: Array[Vector3i]) -> bool:
	return stats == stats.clamp(bounds[0], bounds[1])


func service_fee(_stats: Vector3i) -> int:
	return Data.RELEASE_REWARD


func first_service(soul: Dictionary) -> bool:
	return not _first_services.has(soul.case_id)


static func doses_used(soul: Dictionary) -> int:
	return maxi(0, int(soul.get("doses_used", int(soul.get("served", false)))))


func release_reward(soul: Dictionary, stats: Vector3i, _dose_count: int) -> int:
	if not is_eligible(stats):
		return 0
	var perfect: bool = bool(soul.get("used_variant_compound", false)) or (soul.get("perfect_target") != null and stats == soul.perfect_target)
	return Data.PERFECT_REWARD if perfect else Data.RELEASE_REWARD


func spend(cost: int) -> bool:
	if not active or paused or cost < 0 or coins < cost:
		return false
	coins -= cost
	return true


func release_soul(id: int) -> bool:
	if not active or paused or not can_release(id):
		return false
	var soul := get_soul(id)
	last_story_outcome = ""
	last_payout = reward_for(id)
	coins += last_payout
	_first_services[soul.case_id] = true
	souls.erase(soul)
	released_count += 1
	if story_state != null:
		story_state.run["run.released"] = released_count
	_advance_day_if_ready()
	state_changed.emit()
	return true


func record_catch(result: Dictionary) -> void:
	var catch := result.duplicate()
	catch["id"] = _allocate_item()
	catches.append(catch)
	finger_bones += int(catch.get("finger_bones", 0))
	state_changed.emit()


func refine(id: int) -> bool:
	if not active or paused:
		return false
	for catch in catches:
		if catch.id != id:
			continue
		var species: int = catch.species
		essences[species] += yield_for(catch)
		catches.erase(catch)
		state_changed.emit()
		return true
	return false


static func yield_for(catch: Dictionary) -> int:
	return 2 if catch.species == Data.VARIANT else int(catch.size) + 1


func can_mix(first: int, second: int) -> bool:
	if Data.recipe(first, second).is_empty():
		return false
	return essences[first] >= (2 if first == second else 1) and essences[second] > 0


func mix(first: int, second: int) -> bool:
	if not active or paused or not can_mix(first, second):
		return false
	var recipe := Data.recipe(first, second)
	essences[first] -= 1
	essences[second] -= 1
	_add_potion(recipe.id, recipe.name, recipe.effect, -1, 0)
	state_changed.emit()
	return true


func get_potion(id: int) -> Dictionary:
	for potion in potions:
		if potion.id == id:
			return potion
	return {}


func dose(essence: bool, id: int) -> Dictionary:
	if not essence:
		return get_potion(id)
	if id < 0 or id >= essences.size() or essences[id] == 0:
		return {}
	var fish: Dictionary = Data.FISH[id]
	return {"name": fish.essence, "effect": fish.effect, "kind": fish.id, "attribute": -1}


func preview(id: int, essence: bool, item: int) -> Dictionary:
	var soul := get_soul(id)
	var medicine := dose(essence, item)
	if soul.is_empty() or soul.has("story_case") or medicine.is_empty():
		return {}
	var before: Vector3i = soul.stats
	var effect: Vector3i = medicine.effect
	var after := before + effect
	var in_bounds := after == after.clamp(Vector3i.ZERO, STAT_CEILING)
	var available := in_bounds and not bool(soul.get("served", false)) and int(soul.get("doses_used", 0)) < 1
	var eligible := in_bounds and is_eligible(after)
	var giant := not essence and Data.is_variant_compound(str(medicine.kind))
	var precise: bool = soul.get("perfect_target") != null and after == soul.perfect_target
	var perfect: bool = eligible and (giant or precise)
	return {"name": medicine.name, "kind": medicine.kind, "before": before, "after": after, "effect": effect,
		"available": available, "in_bounds": in_bounds, "eligible": eligible, "perfect": perfect,
		"contains_variant": giant, "reward": (Data.PERFECT_REWARD if perfect else Data.RELEASE_REWARD) if eligible else 0}


func serve(id: int, essence: bool, item: int) -> bool:
	if not active or paused:
		return false
	var change := preview(id, essence, item)
	if change.is_empty() or not change.available:
		return false
	if essence:
		essences[item] -= 1
	else:
		potions.erase(get_potion(item))
	var soul := get_soul(id)
	soul.before = change.before
	soul.stats = change.after
	soul.served = true
	soul["doses_used"] = 1
	soul["medicine_kind"] = change.kind
	soul["used_variant_compound"] = change.contains_variant
	soul_served.emit(id)
	state_changed.emit()
	return true


func strengthen(_essence: bool, _item: int, _attribute: int, _amount: int) -> bool:
	# Disabled in this rules version, including direct API calls and old inventory.
	return false


func has_story_case(id: int) -> bool:
	var soul := get_soul(id)
	return not soul.is_empty() and soul.has("story_case")


func get_story_runtime(id: int):
	var soul := get_soul(id)
	if soul.is_empty() or not soul.has("story_case") or story_db == null:
		return null
	if story_runtimes.has(id):
		return story_runtimes[id]
	var case_id := str(soul.story_case)
	var data: Dictionary = story_db.get_case(case_id)
	if data.is_empty():
		return null
	var runtime = StoryRuntime.new()
	runtime.setup(data, story_db.text, story_state)
	var saved: Variant = soul.get("story_state", {})
	if saved is Dictionary and not saved.is_empty() and runtime.restore(saved):
		pass
	else:
		runtime = StoryRuntime.new()
		runtime.setup(data, story_db.text, story_state)
		runtime.start()
	story_runtimes[id] = runtime
	runtime.changed.connect(_on_story_changed.bind(id))
	runtime.case_closed.connect(_on_story_closed.bind(id))
	_sync_story_snapshot(id, false)
	return runtime


func feed_story_potion(id: int, essence: bool, item: int) -> bool:
	var soul := get_soul(id)
	if not active or paused or soul.is_empty() or not soul.has("story_case"):
		return false
	var runtime = get_story_runtime(id)
	if runtime == null or not runtime.can_feed_potion():
		return false
	var medicine := dose(essence, item)
	if medicine.is_empty():
		return false
	if essence:
		essences[item] -= 1
	else:
		potions.erase(get_potion(item))
	if not runtime.feed_potion(medicine.effect, str(medicine.name)):
		return false
	soul.served = true
	soul["doses_used"] = 1
	soul["medicine_kind"] = medicine.kind
	soul_served.emit(id)
	state_changed.emit()
	return true


func finish_story(id: int) -> bool:
	var soul := get_soul(id)
	var runtime = story_runtimes.get(id)
	if soul.is_empty() or runtime == null or not runtime.is_closed():
		return false
	var outcome: Dictionary = runtime.get_outcome()
	var result := str(outcome.get("result", "stay"))
	if result == "stay":
		return false
	last_payout = 0
	last_story_outcome = result
	if result == "release":
		last_payout = Data.RELEASE_REWARD
		coins += last_payout
		released_count += 1
	else:
		rejected_count += 1
	var ledger: Dictionary = outcome.get("ledger", {})
	var ledger_entry: Dictionary = {}
	if not ledger.is_empty() and story_db != null and story_state != null:
		ledger_entry = ledger.duplicate(true)
		ledger_entry["case"] = str(soul.story_case)
		ledger_entry["day"] = day
		var note_key := str(ledger_entry.get("note", ""))
		if note_key != "":
			var note_text: String = story_db.text.get_text(note_key)
			ledger_entry["note"] = story_db.text.render(note_text, story_state.context({}))
		else:
			ledger_entry["note"] = ""
		story_state.ledger.append(ledger_entry)
	if story_state != null:
		story_state.run["run.released"] = released_count
		story_state.run["run.rejected"] = rejected_count
	var report_entry := {
		"case": str(soul.story_case),
		"who": str(ledger.get("who", soul.name)),
		"result": str(ledger.get("result", "")),
		"note": str(ledger_entry.get("note", "")),
		"aftermath": runtime.get_aftermath_lines(),
	}
	day_story_entries.append(report_entry)
	_first_services[soul.case_id] = true
	souls.erase(soul)
	story_runtimes.erase(id)
	_advance_day_if_ready()
	state_changed.emit()
	return true


func _advance_day_if_ready() -> void:
	if not souls.is_empty() or has_more_arrivals():
		return
	if not day_story_entries.is_empty():
		pending_day_report = {
			"day": day,
			"final": is_complete(),
			"entries": day_story_entries.duplicate(true),
		}
		awaiting_day_report = true
		return
	if is_complete():
		return
	awaiting_next_day = true
	day_finished.emit()


func get_day_report() -> Dictionary:
	return pending_day_report if awaiting_day_report else {}


func close_day_report() -> void:
	if not awaiting_day_report:
		return
	var final := bool(pending_day_report.get("final", false))
	awaiting_day_report = false
	pending_day_report = {}
	if final:
		state_changed.emit()
		return
	awaiting_next_day = true
	day_finished.emit()
	state_changed.emit()


func get_ending_lines() -> PackedStringArray:
	if story_db == null or story_state == null:
		return PackedStringArray()
	var ending: Dictionary = story_db.evaluate_ending(story_state)
	return story_db.ending_lines_for(ending, story_state)


func _on_story_changed(id: int) -> void:
	_sync_story_snapshot(id, true)


func _on_story_closed(outcome_id: String, id: int) -> void:
	var soul := get_soul(id)
	if not soul.is_empty():
		soul["story_outcome"] = outcome_id
	_sync_story_snapshot(id, true)


func _sync_story_snapshot(id: int, emit_change: bool) -> void:
	var runtime = story_runtimes.get(id)
	var soul := get_soul(id)
	if runtime == null or soul.is_empty():
		return
	soul["story_state"] = runtime.snapshot()
	if runtime.is_identity_revealed():
		soul.name = story_db.get_title(str(soul.story_case))
	if emit_change:
		state_changed.emit()


func _add_potion(kind: String, title: String, effect: Vector3i, attribute: int, adjustment: int) -> void:
	potions.append({"id": _allocate_item(), "kind": kind, "name": title, "effect": effect, "attribute": attribute, "adjustment": adjustment, "contains_variant": Data.is_variant_compound(kind)})


func _allocate_item() -> int:
	var id := _next_item_id
	_next_item_id += 1
	return id


static func medicine_effects(species: Array) -> Array[Vector3i]:
	var unique := {}
	for first: int in species:
		unique[Data.FISH[first].effect] = true
		for second: int in species:
			if second < first:
				continue
			var recipe := Data.recipe(first, second)
			if not recipe.is_empty():
				unique[recipe.effect] = true
	var result: Array[Vector3i] = []
	for effect: Vector3i in unique:
		result.append(effect)
	return result


static func qualifying_targets(stats: Vector3i, effects: Array[Vector3i]) -> Array[Vector3i]:
	var targets: Array[Vector3i] = []
	for effect in effects:
		var after := stats + effect
		if meets_requirements(after, RELEASE_BOUNDS) and not targets.has(after):
			targets.append(after)
	return targets


static func basics_can_release(stats: Vector3i) -> bool:
	for species: int in Data.BASIC_FISH:
		if meets_requirements(stats + Data.FISH[species].effect, RELEASE_BOUNDS):
			return true
	return false


static func build_candidate_pool(species: Array) -> Array[Dictionary]:
	var effects := medicine_effects(species)
	var pool: Array[Dictionary] = []
	for wisdom in 11:
		for emotion in 11:
			for will in 11:
				var stats := Vector3i(wisdom, emotion, will)
				if meets_requirements(stats, RELEASE_BOUNDS) or basics_can_release(stats):
					continue
				var targets := qualifying_targets(stats, effects)
				if not targets.is_empty():
					pool.append({"stats": stats, "targets": targets})
	return pool


static func save_soul(soul: Dictionary) -> Dictionary:
	var out := soul.duplicate(true)
	for key in ["stats", "before", "perfect_target"]:
		if out.get(key) is Vector3i:
			var value: Vector3i = out[key]
			out[key] = [value.x, value.y, value.z]
	return out


static func restore_soul(saved: Dictionary) -> Dictionary:
	var out := saved.duplicate(true)
	for key in ["stats", "before", "perfect_target"]:
		if out.get(key) is Array:
			var value: Array = out[key]
			out[key] = Vector3i(int(value[0]), int(value[1]), int(value[2]))
	out["doses_used"] = int(out.get("doses_used", int(out.get("served", false))))
	out["used_variant_compound"] = Data.is_variant_compound(str(out.get("medicine_kind", "")))
	out["perfect_target"] = out.get("perfect_target")
	out["fee"] = Data.RELEASE_REWARD
	return out


func is_perfect(id: int) -> bool:
	var soul := get_soul(id)
	if soul.is_empty() or soul.has("story_case") or not is_eligible(soul.stats):
		return false
	return bool(soul.get("used_variant_compound", false)) or (soul.get("perfect_target") != null and soul.stats == soul.perfect_target)


func reward_for(id: int) -> int:
	if not can_release(id):
		return 0
	return Data.PERFECT_REWARD if is_perfect(id) else Data.RELEASE_REWARD


func dismiss_soul(id: int) -> bool:
	var soul := get_soul(id)
	if not active or paused or soul.is_empty() or soul.has("story_case") or not soul.get("served", false) or can_release(id):
		return false
	souls.erase(soul)
	failed_count += 1
	last_payout = 0
	last_story_outcome = "failed"
	_advance_day_if_ready()
	state_changed.emit()
	return true


func start_next_day() -> bool:
	if not active or paused or awaiting_day_report or not awaiting_next_day or day >= DAY_COUNT:
		return false
	_open_day(day + 1)
	spawn_remaining = _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)
	state_changed.emit()
	return true
