extends Node

signal state_changed
signal soul_served(id: int)

const Data := preload("res://scripts/systems/playtest_data.gd")
const StoryDB := preload("res://scripts/story/story_db.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const StoryRuntime := preload("res://scripts/story/story_runtime.gd")
const DAY_COUNT := 5
const GUESTS_PER_DAY := 6
const OLD_SHIFT_TOTAL := 12
const STAT_MAX := 10
const STAT_CEILING := Vector3i.ONE * STAT_MAX
const STAT_ORDERS := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
const DAY_FOUR_BANDS := [Vector2i(4, 7), Vector2i(5, 8), Vector2i(6, 9)]
const DAY_FIVE_BANDS := [Vector2i(4, 7), Vector2i(6, 8), Vector2i(7, 9)]
const LEGACY_REQUIREMENTS: Array[Vector3i] = [Vector3i(7, 7, 7), Vector3i(9, 9, 9)]
const STARTER_RAISE_FISH := [0, 1, Data.LANTERN]
const STARTER_LOWER_FISH := [5, 6, Data.STILLFIN]
const HIGH_STAT_GUESTS := [4, 3, 7]
const BOATMAN_CASE := 2
const BOATMAN_COMMISSION_WILL := 9

var catches: Array[Dictionary] = []
var essences: Array[int] = []
var potions: Array[Dictionary] = []
var souls: Array[Dictionary] = []
var concentrate := 0
var recovered_bones := 0
var finger_bones := 0
var released_count := 0
var day := 1
var requirements: Array[Vector3i] = [Vector3i.ZERO, STAT_CEILING]
var coins := Data.STARTING_COINS
var last_payout := 0
var _first_services: Dictionary = {}
var spawn_remaining := 0.0
var paused := false
var active := false
var _arrived := 0
var _day_guests: Array[Vector2i] = []
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
	return mini(DAY_COUNT * GUESTS_PER_DAY, released_count + rejected_count + remaining)


func advance(delta: float) -> void:
	if not active or is_time_suspended() or not has_more_arrivals() or delta <= 0.0:
		return
	spawn_remaining -= delta
	var arrived := false
	while spawn_remaining <= 0.0 and has_more_arrivals():
		var slot := _day_arrived
		var guest := _day_guests[slot]
		if day == 3 and slot == GUESTS_PER_DAY - 1 and story_state != null and bool(story_state.world.get("world.orpheus_lost", false)):
			guest = Vector2i(Data.DROWNED_LYRE_PLAYER, -1)
		var entry: Array = Data.SOULS[guest.x]
		var stats: Vector3i = entry[1]
		if guest.y >= 0:
			stats = _starter_stats(stats, guest.y)
		var soul := {
			"id": _arrived + 1, "case_id": guest.x, "name": entry[0], "stats": stats,
			"before": stats, "served": false, "doses_used": 0, "fee": service_fee(stats),
		}
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
			soul["fee"] = story_db.get_fee(story_case)
		_day_arrived += 1
		_arrived += 1
		souls.append(soul)
		spawn_remaining += _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)
		arrived = true
	if arrived:
		state_changed.emit()


static func roll_requirements(number: int, rng: RandomNumberGenerator) -> Array[Vector3i]:
	var order: Array = STAT_ORDERS[rng.randi_range(0, STAT_ORDERS.size() - 1)]
	var lower := Vector3i.ZERO
	var upper := STAT_CEILING
	match number:
		1:
			lower[order[0]] = 7
			lower[order[1]] = 7
		2:
			lower[order[0]] = rng.randi_range(6, 7)
			upper[order[1]] = rng.randi_range(8, 9)
		3:
			lower[order[0]] = rng.randi_range(6, 8)
			lower[order[1]] = rng.randi_range(6, 8)
			upper[order[2]] = rng.randi_range(7, 9)
		_:
			var bands: Array = DAY_FOUR_BANDS if number == 4 else DAY_FIVE_BANDS
			for index in 3:
				lower[order[index]] = bands[index].x
				upper[order[index]] = bands[index].y
	return [lower, upper]


func _open_day(number: int) -> void:
	day = number
	day_story_entries.clear()
	requirements = roll_requirements(day, _rng)
	_day_guests.clear()
	_day_arrived = 0
	_fill_day_roster()
	if story_state != null:
		story_state.run["run.day"] = day


func _fill_day_roster() -> void:
	var scheduled := _day_guests.map(func(guest: Vector2i) -> int: return guest.x)
	var available := Data.SOUL_ORDER.filter(func(case_id: int) -> bool:
		return not _first_services.has(case_id) and not scheduled.has(case_id)
	)
	var raise_axes: Array[int] = []
	if day <= 2:
		for axis in [Data.Attribute.EMOTION, Data.Attribute.WILL, Data.Attribute.WISDOM]:
			if requirements[0][axis] > 0:
				raise_axes.append(axis)
		if scheduled.is_empty():
			for axis in raise_axes:
				_schedule_starter(available, axis, axis)
			if day == 2:
				for axis in 3:
					if requirements[1][axis] < STAT_MAX:
						_schedule_starter(available, HIGH_STAT_GUESTS[axis], axis)
	var seats := maxi(0, GUESTS_PER_DAY - _day_guests.size())
	for index in mini(seats, available.size()):
		# Extra guests on the first two days can still be served with one shallow-water dose.
		var focus := -1 if raise_axes.is_empty() else raise_axes[index % raise_axes.size()]
		_day_guests.append(Vector2i(available[index], focus))


func _schedule_starter(available: Array, preferred: int, axis: int) -> void:
	if available.is_empty():
		return
	var index := available.find(preferred)
	var case_id: int = available.pop_at(maxi(0, index))
	_day_guests.append(Vector2i(case_id, axis))


func _starter_stats(stats: Vector3i, axis: int) -> Vector3i:
	var lower := requirements[0]
	var upper := requirements[1]
	var raises := lower[axis] > 0
	var fish: int = STARTER_RAISE_FISH[axis] if raises else STARTER_LOWER_FISH[axis]
	var effect: Vector3i = Data.FISH[fish].effect
	# Keep the other required attributes in bounds both before and after one dose.
	var safe_low := lower.max(lower - effect)
	var safe_high := upper.min(upper - effect)
	for index in 3:
		if lower[index] == 0:
			safe_low[index] = 0
		if upper[index] == STAT_MAX:
			safe_high[index] = STAT_MAX
	var starter := stats.clamp(safe_low, safe_high)
	starter[axis] = maxi(0, lower[axis] - effect[axis]) if raises else mini(STAT_MAX, upper[axis] - effect[axis])
	return starter


func save_day() -> Dictionary:
	var bounds: Array = []
	for limit in requirements:
		bounds.append([limit.x, limit.y, limit.z])
	var guests: Array = []
	for guest in _day_guests:
		guests.append([guest.x, guest.y])
	return {"number": day, "bounds": bounds, "guests": guests, "arrivals": _day_arrived, "daily_quota": GUESTS_PER_DAY}


func restore_day(saved: Dictionary) -> void:
	if saved.is_empty():
		day = mini(DAY_COUNT, 1 + floori(float(released_count) / GUESTS_PER_DAY))
		if souls.is_empty() and released_count < OLD_SHIFT_TOTAL:
			_open_day(day)
			return
		# Unscheduled legacy queues keep their original admission terms.
		day = DAY_COUNT if souls.is_empty() else ceili(float(released_count + souls.size()) / GUESTS_PER_DAY)
		requirements = LEGACY_REQUIREMENTS.duplicate()
		_day_guests.clear()
		for soul in souls:
			_day_guests.append(Vector2i(soul.case_id, -1))
		_day_arrived = _day_guests.size()
		return
	day = int(saved.number)
	if saved.has("bounds"):
		var low: Array = saved.bounds[0]
		var high: Array = saved.bounds[1]
		requirements = [Vector3i(int(low[0]), int(low[1]), int(low[2])), Vector3i(int(high[0]), int(high[1]), int(high[2]))]
	else:
		# Slots written during the v1.5 trial omitted bounds and stored guest records.
		requirements = LEGACY_REQUIREMENTS.duplicate()
	_day_guests.clear()
	for guest in saved.guests:
		if guest is Dictionary:
			var case_id := clampi(int(guest.get("case_id", 0)), 0, Data.SOULS.size() - 1)
			_day_guests.append(Vector2i(case_id, -1))
		else:
			_day_guests.append(Vector2i(int(guest[0]), int(guest[1])))
	_day_arrived = int(saved.arrivals)
	if int(saved.get("daily_quota", 0)) < GUESTS_PER_DAY and not is_complete():
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


func service_fee(stats: Vector3i) -> int:
	var adjustment := (stats - stats.clamp(requirements[0], requirements[1])).abs()
	var total := adjustment.x + adjustment.y + adjustment.z
	if total >= 8:
		return 50
	if total >= 5:
		return 40
	if total >= 3:
		return 30
	return 20 if total > 0 else 0


func first_service(soul: Dictionary) -> bool:
	return not _first_services.has(soul.case_id)


func has_commission(soul: Dictionary) -> bool:
	return soul.case_id == BOATMAN_CASE and requirements[0].z <= BOATMAN_COMMISSION_WILL and requirements[1].z >= BOATMAN_COMMISSION_WILL


func service_bonus(soul: Dictionary) -> int:
	return int(soul.fee * 0.10)


static func doses_used(soul: Dictionary) -> int:
	return maxi(0, int(soul.get("doses_used", int(soul.get("served", false)))))


func release_reward(soul: Dictionary, stats: Vector3i, dose_count: int) -> int:
	var bonuses := int(first_service(soul))
	if has_commission(soul) and stats.z == BOATMAN_COMMISSION_WILL:
		bonuses += 1
	var full_reward := int(soul.fee) + service_bonus(soul) * bonuses
	return floori(full_reward * pow(0.5, maxi(0, dose_count - 1)))


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
	last_payout = release_reward(soul, soul.stats, doses_used(soul))
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


func record_bone() -> void:
	recovered_bones += 1
	state_changed.emit()


func refine(id: int) -> bool:
	if not active or paused:
		return false
	for catch in catches:
		if catch.id != id:
			continue
		var species: int = catch.species
		essences[species] += yield_for(catch)
		if species == Data.LANTERN and catch.size == 0:
			concentrate += 1
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
	var after := (before + effect).clamp(Vector3i.ZERO, STAT_CEILING)
	var dose_count := doses_used(soul) + 1
	return {
		"name": medicine.name, "before": before, "after": after, "effect": effect,
		"doses_used": dose_count,
		"reward": release_reward(soul, after, dose_count) if is_eligible(after) else 0,
	}


func serve(id: int, essence: bool, item: int) -> bool:
	if not active or paused:
		return false
	var change := preview(id, essence, item)
	if change.is_empty():
		return false
	if essence:
		essences[item] -= 1
	else:
		potions.erase(get_potion(item))
	var soul := get_soul(id)
	soul.before = change.before
	soul.stats = change.after
	soul.served = true
	soul["doses_used"] = change.doses_used
	soul_served.emit(id)
	state_changed.emit()
	return true


func strengthen(essence: bool, item: int, attribute: int, amount: int) -> bool:
	if not active or paused or concentrate <= 0 or attribute < 0 or attribute >= 3 or absi(amount) != 1:
		return false
	var medicine := dose(essence, item)
	if medicine.is_empty() or medicine.attribute >= 0:
		return false
	var effect: Vector3i = medicine.effect
	effect[attribute] += amount
	concentrate -= 1
	if essence:
		essences[item] -= 1
		_add_potion(medicine.kind, medicine.name, effect, attribute, amount)
	else:
		medicine.effect = effect
		medicine.attribute = attribute
		medicine.adjustment = amount
	state_changed.emit()
	return true


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
		last_payout = int(outcome.get("payout", soul.fee))
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
	_open_day(day + 1)
	spawn_remaining = _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)


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
	_open_day(day + 1)
	spawn_remaining = _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)
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
	potions.append({"id": _allocate_item(), "kind": kind, "name": title, "effect": effect, "attribute": attribute, "adjustment": adjustment})


func _allocate_item() -> int:
	var id := _next_item_id
	_next_item_id += 1
	return id
