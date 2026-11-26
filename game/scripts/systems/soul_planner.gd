extends RefCounted
## Generates compatible initial attributes while preserving each person's defect.

const Data := preload("res://scripts/systems/playtest_data.gd")


static func eligible(stats: Vector3i, bounds: Array[Vector3i]) -> bool:
	return stats == stats.clamp(bounds[0], bounds[1])


static func apply_dose(stats: Vector3i, effect: Vector3i) -> Vector3i:
	return (stats + effect).clamp(Vector3i.ZERO, Vector3i.ONE * 10)


static func one_dose_solutions(stats: Vector3i, bounds: Array[Vector3i]) -> Array[String]:
	var result: Array[String] = []
	for id in Data.POTIONS:
		if eligible(apply_dose(stats, Data.POTIONS[id].effect), bounds):
			result.append(id)
	return result


static func quote(stats: Vector3i, bounds: Array[Vector3i]) -> int:
	if eligible(stats, bounds):
		return 0
	var tier := 4
	for id in one_dose_solutions(stats, bounds):
		tier = mini(tier, Data.POTIONS[id].tier)
	return [0, 25, 40, 60][tier] if tier < 4 else 80


static func template_for(case_id: int, bounds: Array[Vector3i]) -> Dictionary:
	if case_id < 0 or case_id >= Data.SOULS.size():
		return {}
	var title: String = Data.SOULS[case_id][0]
	for candidate in Data.Alchemy.GUESTS:
		if candidate.name == title:
			return candidate
	# The story echo is an ordinary service, but keeps its own narrative identity.
	if case_id == Data.DROWNED_LYRE_PLAYER:
		if bounds[0].z == 0:
			return {"name": title, "defect": Vector3i(0, -1, 0), "sample": Vector3i(8, 1, 1), "route": ["medicine_02"]}
		var has_ceiling := bounds[1].y < 10
		return {"name": title, "defect": Vector3i(0, 1 if has_ceiling else 0, -1), "sample": Vector3i(8, 10, 1), "route": ["medicine_05", "medicine_03"] if has_ceiling else ["medicine_03"]}
	return {}


static func matches_defect(stats: Vector3i, defect: Vector3i, bounds: Array[Vector3i]) -> bool:
	for axis in 3:
		var actual := -1 if stats[axis] < bounds[0][axis] else (1 if stats[axis] > bounds[1][axis] else 0)
		if actual != defect[axis]:
			return false
	return true


static func generate(case_id: int, bounds: Array[Vector3i], rng: RandomNumberGenerator, starter: bool = false) -> Dictionary:
	var template := template_for(case_id, bounds)
	if template.is_empty():
		return {}
	if starter:
		return _starter(case_id, template, bounds, rng)
	var route: Array = template.route
	var total := Vector3i.ZERO
	for id in route:
		total += Data.POTIONS[id].effect
	var candidates: Array[Vector3i] = []
	for x in range(maxi(1, bounds[0].x), bounds[1].x + 1):
		for y in range(maxi(1, bounds[0].y), bounds[1].y + 1):
			for z in range(maxi(1, bounds[0].z), bounds[1].z + 1):
				var initial := Vector3i(x, y, z) - total
				if initial != initial.clamp(Vector3i.ONE, Vector3i.ONE * 10) or not matches_defect(initial, template.defect, bounds):
					continue
				var after := initial
				for id in route:
					after = apply_dose(after, Data.POTIONS[id].effect)
				if not eligible(after, bounds) or eligible(initial, bounds):
					continue
				var singles := one_dose_solutions(initial, bounds)
				if route.size() == 1 and (singles.size() != 1 or singles[0] != route[0]):
					continue
				if route.size() > 1 and not singles.is_empty():
					continue
				candidates.append(initial)
	if candidates.is_empty():
		return {}
	var stats := candidates[rng.randi_range(0, candidates.size() - 1)]
	return {"case_id": case_id, "stats": stats, "route": route.duplicate(), "source": source_for(route[0]), "fee": quote(stats, bounds)}


static func source_for(potion_id: String) -> int:
	var best := -1
	for species in Data.essence_indices():
		var source := Data.source_data(species)
		if not source.is_empty() and source.outcomes[0][0] == potion_id:
			best = species
	return best


static func _starter(case_id: int, template: Dictionary, bounds: Array[Vector3i], rng: RandomNumberGenerator) -> Dictionary:
	var axis := -1
	for index in 3:
		if template.defect[index] != 0:
			if axis >= 0:
				return {}
			axis = index
	if axis < 0:
		return {}
	var source: int = [0, 1, 2][axis] if template.defect[axis] < 0 else [5, 6, 7][axis]
	var initial_axis: int = bounds[0][axis] - 1 if template.defect[axis] < 0 else bounds[1][axis] + 1
	if initial_axis < 1 or initial_axis > 10:
		return {}
	var outcomes: Array = Data.source_data(source).outcomes
	var candidates: Array[Vector3i] = []
	for x in range(1, 11):
		for y in range(1, 11):
			for z in range(1, 11):
				var initial := Vector3i(x, y, z)
				if initial[axis] != initial_axis or not matches_defect(initial, template.defect, bounds):
					continue
				var usable := true
				for outcome in outcomes:
					usable = usable and eligible(apply_dose(initial, Data.POTIONS[outcome[0]].effect), bounds)
				if usable:
					candidates.append(initial)
	if candidates.is_empty():
		return {}
	return {"case_id": case_id, "stats": candidates[rng.randi_range(0, candidates.size() - 1)], "route": [outcomes[0][0]], "source": source, "fee": 25}
