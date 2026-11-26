extends Node

signal state_changed
signal soul_served(id: int)

const Data := preload("res://scripts/systems/playtest_data.gd")
const StoryDB := preload("res://scripts/story/story_db.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const StoryRuntime := preload("res://scripts/story/story_runtime.gd")
const Planner := preload("res://scripts/systems/soul_planner.gd")
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
const STARTER_LOWER_FISH := [5, 6, 7]
const HIGH_STAT_GUESTS := [4, 3, 7]
const BOATMAN_CASE := 2
const BOATMAN_COMMISSION_WILL := 9
const TUTORIAL_GUEST_CASE := 1
const TUTORIAL_GUEST_ID := 1

var catches: Array[Dictionary] = []
var essences: Array[int] = []
var potions: Array[Dictionary] = []
var codex_fish: Dictionary = {}
var codex_recipes: Dictionary = {}
var codex_sources: Dictionary = {}
var starter_supply_claimed := false
var upper_supply_claimed := false
var _guest_plans: Dictionary = {}
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
var tutorial_pause_arrivals := false
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


func start_shift(tutorial_first_guest: bool = false) -> void:
	tutorial_pause_arrivals = tutorial_first_guest
	if not starter_supply_claimed:
		essences[1] += 3
		essences[2] += 6
		starter_supply_claimed = true
	_open_day(1, tutorial_first_guest)
	active = true
	if tutorial_first_guest:
		ensure_tutorial_guest()


func has_more_arrivals() -> bool:
	return _day_arrived < _day_guests.size()


func is_complete() -> bool:
	return day == DAY_COUNT and souls.is_empty() and not has_more_arrivals()


func total_guests() -> int:
	var remaining := souls.size() + _day_guests.size() - _day_arrived + (DAY_COUNT - day) * GUESTS_PER_DAY
	return mini(DAY_COUNT * GUESTS_PER_DAY, released_count + rejected_count + remaining)


func advance(delta: float) -> void:
	if not active or is_time_suspended() or tutorial_pause_arrivals or not has_more_arrivals() or delta <= 0.0:
		return
	spawn_remaining -= delta
	var arrived := false
	while spawn_remaining <= 0.0 and has_more_arrivals():
		_arrive_next_guest()
		arrived = true
	if arrived:
		state_changed.emit()


func _arrive_next_guest() -> void:
	var slot := _day_arrived
	var guest := _day_guests[slot]
	var echo := day == 3 and slot == GUESTS_PER_DAY - 1 and story_state != null and str(story_state.world.get("world.orpheus_echo", "")) != ""
	if echo:
		guest = Vector2i(Data.DROWNED_LYRE_PLAYER, -1)
	var entry: Array = Data.SOULS[guest.x] if guest.x >= 0 else ["剧情来客", Vector3i(8, 8, 8)]
	var plan: Dictionary = _guest_plans.get(slot, {})
	if echo:
		plan = Planner.generate(guest.x, requirements, _rng)
		if plan.is_empty():
			plan = Planner.generate(guest.x, requirements, _rng, true)
	var stats: Vector3i = plan.get("stats", entry[1])
	var soul := {
		"id": _arrived + 1, "case_id": guest.x, "name": entry[0], "stats": stats,
		"initial": stats, "before": stats, "served": false, "doses_used": 0,
		"fee": int(plan.get("fee", service_fee(stats))),
	}
	var story_case: String = story_db.get_scheduled_case(day, slot) if story_db != null else ""
	if story_case != "":
		soul["case_id"] = 1000 + day
		soul["story_case"] = story_case
		soul["story_outcome"] = ""
		soul["story_state"] = {}
		soul["name"] = story_db.get_queue_name(story_case)
		soul["stats"] = Vector3i(8, 8, 8)
		soul["before"] = soul["stats"]
		soul["fee"] = story_db.get_fee(story_case)
	if guest.x == Data.DROWNED_LYRE_PLAYER:
		soul["story_echo"] = "orpheus"
	_day_arrived += 1
	_arrived += 1
	souls.append(soul)
	spawn_remaining += _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)


func ensure_tutorial_guest() -> void:
	if tutorial_pause_arrivals and day == 1 and _day_arrived == 0 and has_more_arrivals():
		spawn_remaining = 0.0
		_arrive_next_guest()
		state_changed.emit()


func resume_tutorial_arrivals() -> void:
	if tutorial_pause_arrivals:
		tutorial_pause_arrivals = false
		if spawn_remaining < Data.ARRIVAL_MIN:
			spawn_remaining = _rng.randf_range(Data.ARRIVAL_MIN, Data.ARRIVAL_MAX)


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


func _open_day(number: int, tutorial_first_guest: bool = false) -> void:
	day = number
	day_story_entries.clear()
	requirements = roll_requirements(day, _rng)
	_day_guests.clear()
	_guest_plans.clear()
	_day_arrived = 0
	if day == 1:
		requirements = [Vector3i(0, 7, 7), STAT_CEILING]
	if tutorial_first_guest:
		_day_guests.append(Vector2i(TUTORIAL_GUEST_CASE, -1))
	_fill_day_roster()
	if day >= 2 and not upper_supply_claimed:
		grant_upper_supply()
	if story_state != null:
		story_state.run["run.day"] = day


func _fill_day_roster() -> void:
	var used: Array[int] = []
	for slot in _day_guests.size():
		var case_id := _day_guests[slot].x
		used.append(case_id)
		if not _guest_plans.has(slot):
			_guest_plans[slot] = Planner.generate(case_id, requirements, _rng, day <= 2)
	var mixed := 0
	var reserved_third := 0
	for potion in potions:
		reserved_third += int(potion.kind == "medicine_11")
	while _day_guests.size() < GUESTS_PER_DAY:
		var slot := _day_guests.size()
		if story_db != null and story_db.get_scheduled_case(day, slot) != "":
			_day_guests.append(Vector2i(-1, -1))
			continue
		var best: Dictionary = {}
		var best_score := -99999
		for allow_repeat in 2:
			for case_id in Data.SOUL_ORDER:
				if used.has(case_id) or (allow_repeat == 0 and _first_services.has(case_id)):
					continue
				var template := Planner.template_for(case_id, requirements)
				var route: Array = template.get("route", [])
				if route.is_empty():
					continue
				if route.size() > 1 and (day < 4 or mixed >= 1):
					continue
				if route.has("medicine_11") and (day < 4 or reserved_third <= 0):
					continue
				if day <= 2:
					var axis := 1 if slot % 2 == 0 else 2
					var sign := -1
					if day == 2:
						for index in 3:
							if slot % 2 == 0 and requirements[0][index] > 0:
								axis = index
							if slot % 2 == 1 and requirements[1][index] < 10:
								axis = index
								sign = 1
					var wanted := Vector3i.ZERO
					wanted[axis] = sign
					if template.defect != wanted:
						continue
				var plan := Planner.generate(case_id, requirements, _rng, day <= 2)
				if plan.is_empty():
					continue
				var score := 0
				for id in route:
					for potion in potions:
						if potion.kind == id:
							score += 20
				if score > best_score:
					best = plan
					best_score = score
			if not best.is_empty():
				break
		if best.is_empty():
			push_error("No compatible guest template for day %d slot %d" % [day, slot])
			break
		used.append(int(best.case_id))
		mixed += int(best.route.size() > 1)
		reserved_third -= int(best.route.has("medicine_11"))
		_guest_plans[slot] = best
		_day_guests.append(Vector2i(best.case_id, -1))


func _schedule_starter(available: Array, preferred: int, axis: int) -> void:
	if available.is_empty():
		return
	var index := available.find(preferred)
	var case_id: int = available.pop_at(maxi(0, index))
	_day_guests.append(Vector2i(case_id, axis))


func _starter_stats(stats: Vector3i, axis: int) -> Vector3i:
	# Only used to decode old saves; new guests use fixed-defect plans.
	var result := stats.clamp(requirements[0].max(Vector3i.ONE), requirements[1])
	result[axis] = maxi(1, requirements[0][axis] - 1) if requirements[0][axis] > 0 else mini(10, requirements[1][axis] + 1)
	return result


func save_day() -> Dictionary:
	var bounds: Array = []
	for limit in requirements:
		bounds.append([limit.x, limit.y, limit.z])
	var guests: Array = []
	for guest in _day_guests:
		guests.append([guest.x, guest.y])
	var plans := {}
	for slot in _guest_plans:
		var plan: Dictionary = _guest_plans[slot].duplicate()
		if plan.has("stats"):
			var stats: Vector3i = plan.stats
			plan.stats = [stats.x, stats.y, stats.z]
		plans[str(slot)] = plan
	return {"number": day, "bounds": bounds, "guests": guests, "plans": plans, "arrivals": _day_arrived, "daily_quota": GUESTS_PER_DAY}


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
	_guest_plans.clear()
	for key in saved.get("plans", {}):
		var plan: Dictionary = saved.plans[key].duplicate()
		for field in ["case_id", "source", "fee"]:
			if plan.has(field):
				plan[field] = int(plan[field])
		if plan.has("stats"):
			plan.stats = Vector3i(int(plan.stats[0]), int(plan.stats[1]), int(plan.stats[2]))
		_guest_plans[int(key)] = plan
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
	return Planner.quote(stats, requirements)


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
	if str(soul.get("story_echo", "")) == "orpheus":
		_append_orpheus_echo()
	_advance_day_if_ready()
	state_changed.emit()
	return true


func record_catch(result: Dictionary) -> void:
	var species := int(result.get("species", -1))
	if species < 0 or species >= Data.FISH.size():
		return
	_record_codex_catch(result)
	essences[Data.essence_source(species)] += yield_for(result)
	if species == Data.LANTERN and int(result.size) == 0:
		concentrate += 1
	finger_bones += int(result.get("finger_bones", 0))
	state_changed.emit()


func _record_codex_catch(catch: Dictionary) -> void:
	var species := int(catch.species)
	if species < 0 or species >= Data.FISH.size():
		return
	var progress := _codex_fish_entry(Data.FISH[species].id)
	progress.caught += 1
	progress.max_cm = maxf(progress.max_cm, float(catch.cm))
	if species == Data.LANTERN and int(catch.size) == 0:
		progress.is_new = progress.is_new or not progress.condensed
		progress.condensed = true


func _codex_fish_entry(id: String) -> Dictionary:
	if not codex_fish.has(id):
		codex_fish[id] = {"caught": 0, "max_cm": 0.0, "condensed": false, "is_new": true}
	return codex_fish[id]


func has_unseen_codex() -> bool:
	for entries in [codex_fish, codex_recipes]:
		for entry in entries.values():
			if entry.is_new:
				return true
	return false


func restore_codex(saved: Dictionary) -> void:
	codex_fish.clear()
	codex_recipes.clear()
	codex_sources.clear()
	for fish in Data.FISH:
		var entry: Variant = saved.get("codex_fish", {}).get(fish.id)
		if entry is Dictionary and int(entry.get("caught", 0)) > 0:
			codex_fish[fish.id] = {"caught": int(entry.caught), "max_cm": maxf(0.0, float(entry.get("max_cm", 0.0))), "condensed": bool(entry.get("condensed", false)), "is_new": bool(entry.get("is_new", false))}
	for id in Data.POTIONS:
		if saved.get("codex_recipes", {}).has(id):
			codex_recipes[id] = {"is_new": bool(saved.codex_recipes[id].get("is_new", false))}
	for source in saved.get("codex_sources", {}):
		var species := Data.fish_index(source)
		if species < 0:
			continue
		var known := {}
		for outcome in Data.source_data(species).outcomes:
			if saved.codex_sources[source].get(outcome[0], false):
				known[outcome[0]] = true
		codex_sources[source] = known
	if not saved.has("codex_fish"):
		for catch in saved.get("catches", []):
			if int(catch.get("species", -1)) >= 0 and int(catch.species) < Data.FISH.size():
				_record_codex_catch(catch)
	_backfill_codex(not saved.has("codex_fish"), false)


func _backfill_codex(restore_fish: bool, restore_recipes: bool) -> void:
	if restore_fish:
		for species in Data.essence_indices():
			if species == 7 and codex_fish.has(Data.FISH[Data.STILLFIN].id):
				continue
			if essences[species] > 0 and not codex_fish.has(Data.FISH[species].id):
				_codex_fish_entry(Data.FISH[species].id).caught = 1
	for potion in potions:
		if Data.POTIONS.has(potion.kind) and not codex_recipes.has(potion.kind):
			codex_recipes[potion.kind] = {"is_new": true}


func record_bone() -> void:
	recovered_bones += 1
	state_changed.emit()


func refine(id: int) -> bool:
	return false # Fish now become materials at capture; only legacy migration uses catches.


static func yield_for(catch: Dictionary) -> int:
	return 3 if int(catch.species) == Data.VARIANT else int(catch.size) + 2


func can_mix(first: int, second: int = -1) -> bool:
	return (second == -1 or Data.essence_source(first) == Data.essence_source(second)) and can_brew(first)


func mix(first: int, second: int = -1) -> bool:
	return can_mix(first, second) and brew(first)


func get_potion(id: int) -> Dictionary:
	for potion in potions:
		if potion.id == id:
			return potion
	return {}


func dose(essence: bool, id: int) -> Dictionary:
	return {} if essence else get_potion(id)


func preview(id: int, essence: bool, item: int) -> Dictionary:
	var soul := get_soul(id)
	var medicine := dose(essence, item)
	if soul.is_empty() or soul.has("story_case") or medicine.is_empty():
		return {}
	var before: Vector3i = soul.stats
	var effect: Vector3i = medicine.effect
	var after := (before + effect).clamp(Vector3i.ZERO, STAT_CEILING)
	var dose_count := doses_used(soul) + 1
	var eligible := is_eligible(after)
	return {
		"name": medicine.name, "before": before, "after": after, "effect": effect,
		"doses_used": dose_count,
		"reward": release_reward(soul, after, dose_count) if eligible else 0,
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
	if essence or not active or paused or concentrate <= 0 or attribute < 0 or attribute >= 3 or absi(amount) != 1:
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
	var tally := bool(outcome.get("tally", true))
	if result == "release" or result == "judged":
		if result == "release":
			last_payout = int(outcome.get("payout", soul.fee))
			coins += last_payout
		if tally:
			released_count += 1
	elif tally:
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
	var aftermath: Array = runtime.get_aftermath_lines()
	if str(soul.story_case) == "orpheus" and bool(story_state.world.get("world.orpheus_lost", false)):
		# The loss is not told at Orpheus' window; the drowned lyre player
		# returns on the next day and carries the deferred epilogue.
		story_state.world["world.orpheus_echo"] = runtime.get_outcome_id()
		aftermath = []
	var report_entry := {
		"case": str(soul.story_case),
		"who": str(ledger.get("who", soul.name)),
		"result": str(ledger.get("result", "")),
		"note": str(ledger_entry.get("note", "")),
		"aftermath": aftermath,
	}
	if bool(outcome.get("report", true)):
		day_story_entries.append(report_entry)
	_first_services[soul.case_id] = true
	souls.erase(soul)
	story_runtimes.erase(id)
	_advance_day_if_ready()
	state_changed.emit()
	return true


func _append_orpheus_echo() -> void:
	if story_state == null or story_db == null:
		return
	var echo := str(story_state.world.get("world.orpheus_echo", ""))
	if echo == "":
		return
	var data: Dictionary = story_db.get_case("orpheus")
	var outcome: Dictionary = data.get("outcomes", {}).get(echo, {})
	if outcome.is_empty():
		story_state.world["world.orpheus_echo"] = ""
		return
	var lines: Array = []
	for key in outcome.get("aftermath", []):
		lines.append(story_db.text.render(story_db.text.get_text(str(key)), story_state.context({})))
	var ledger: Dictionary = outcome.get("ledger", {})
	var note := ""
	var note_key := str(ledger.get("note", ""))
	if note_key != "":
		note = story_db.text.render(story_db.text.get_text(note_key), story_state.context({}))
	day_story_entries.append({
		"case": "orpheus",
		"who": "殉情的琴手",
		"result": "已放行",
		"note": note,
		"aftermath": lines,
	})
	story_state.world["world.orpheus_echo"] = ""


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


func can_brew(species: int) -> bool:
	return species >= 0 and species < essences.size() and not Data.source_data(species).is_empty() and essences[Data.essence_source(species)] >= 3


func brew(species: int) -> bool:
	if not active or paused or not can_brew(species):
		return false
	species = Data.essence_source(species)
	var outcomes: Array = Data.source_data(species).outcomes
	var roll := _rng.randi_range(1, 100)
	var result: String = outcomes[-1][0]
	for outcome in outcomes:
		roll -= int(outcome[1])
		if roll <= 0:
			result = outcome[0]
			break
	essences[species] -= 3
	var potion: Dictionary = Data.POTIONS[result]
	_add_potion(result, potion.name, potion.effect, -1, 0)
	if not codex_recipes.has(result):
		codex_recipes[result] = {"is_new": true}
	var source_id: String = Data.FISH[species].id
	if not codex_sources.has(source_id):
		codex_sources[source_id] = {}
	codex_sources[source_id][result] = true
	state_changed.emit()
	return true


func grant_upper_supply() -> void:
	if upper_supply_claimed or requirements[1] == STAT_CEILING:
		return
	upper_supply_claimed = true
	var plans: Array = _guest_plans.values().filter(func(plan: Dictionary) -> bool: return plan.has("stats"))
	# Match each stocked dose to at most one guest using augmenting paths.
	var assignments := {}
	for guest in plans.size():
		_match_stock(guest, plans, assignments, {})
	var covered := {}
	for guest in assignments.values():
		covered[guest] = true
	var remaining: Array = []
	for guest in plans.size():
		if not covered.has(guest):
			remaining.append(plans[guest])
	remaining.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _source_weight(a.source) < _source_weight(b.source))
	var virtual_stock := essences.duplicate()
	var target := mini(5, plans.size())
	var count := covered.size()
	for plan in remaining:
		if count >= target:
			break
		var source := int(plan.source)
		var missing := maxi(0, 3 - virtual_stock[source])
		essences[source] += missing
		virtual_stock[source] += missing - 3
		count += 1
	# For a sixth ordinary guest, keep one tail rather than a sixth guaranteed dose.
	if plans.size() > target and remaining.size() > target - covered.size():
		var source := int(remaining[target - covered.size()].source)
		if virtual_stock[source] <= 0:
			essences[source] += 1


func _source_weight(source: int) -> int:
	var weight := int(Data.FISH[source].water[0])
	if source == 7:
		weight += int(Data.FISH[Data.STILLFIN].water[0])
	return weight


func _match_stock(guest: int, plans: Array, assignments: Dictionary, visited: Dictionary) -> bool:
	for index in potions.size():
		if visited.has(index) or not Planner.eligible(Planner.apply_dose(plans[guest].stats, potions[index].effect), requirements):
			continue
		visited[index] = true
		if not assignments.has(index) or _match_stock(assignments[index], plans, assignments, visited):
			assignments[index] = guest
			return true
	return false


func save_rules() -> Dictionary:
	return {"starter_supply": starter_supply_claimed, "upper_supply": upper_supply_claimed, "rng_state": str(_rng.state), "rng_seed": str(_rng.seed)}


func restore_rules(saved: Dictionary, legacy: bool = false) -> void:
	starter_supply_claimed = bool(saved.get("starter_supply", legacy))
	upper_supply_claimed = bool(saved.get("upper_supply", legacy or day >= 2))
	if saved.has("rng_seed"):
		_rng.seed = int(saved.rng_seed)
		_rng.state = int(saved.rng_state)


func migrate_legacy_inventory() -> void:
	essences[7] += essences[Data.STILLFIN]
	essences[Data.STILLFIN] = 0
	for catch in catches:
		if int(catch.species) >= 0 and int(catch.species) < Data.FISH.size():
			essences[Data.essence_source(int(catch.species))] += yield_for(catch)
			if int(catch.species) == Data.LANTERN and int(catch.size) == 0:
				concentrate += 1
	catches.clear()
	var converted: Array[Dictionary] = []
	for potion in potions:
		var title: String = potion.get("name", Data.LEGACY_POTION_NAMES.get(potion.kind, ""))
		if title.is_empty():
			title = Data.LEGACY_POTION_NAMES.get(potion.kind, "")
		var standard := Data.potion_by_name(title)
		if standard.is_empty():
			var effect: Vector3i = potion.effect
			var best_distance := 99999
			for candidate in Data.POTIONS.values():
				var distance: Vector3i = (candidate.effect - effect).abs()
				var total := distance.x + distance.y + distance.z
				if total < best_distance:
					standard = candidate
					best_distance = total
		converted.append({"id": potion.id, "kind": standard.id, "name": standard.name, "effect": standard.effect, "attribute": -1, "adjustment": 0})
	potions = converted
	var used := {}
	for potion in potions:
		_next_item_id = maxi(_next_item_id, int(potion.id) + 1)
	for potion in potions:
		if int(potion.id) <= 0 or used.has(int(potion.id)):
			potion.id = _allocate_item()
		used[int(potion.id)] = true
