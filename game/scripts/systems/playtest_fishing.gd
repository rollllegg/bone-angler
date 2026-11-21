extends Node

signal state_changed
signal pull_judged(success: bool, message: String)

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")
const DIRECTIONS := [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
const DIRECTION_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D]
const ARROW_KEYS := [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]
const RETURN_LIMIT := 3.0
# Temporary special-fish values for the playable test.
const VARIANT_WORD := "FISH"
const VARIANT_LIMIT := 20.0

enum Phase { READY, WAITING, AWAITING_RETURN, PREPARING, REELING, FEEDBACK, TRUE_NAME, CAUGHT, ESCAPED }
enum Judgement { NONE, NORMAL, PERFECT, MISS }

var phase := Phase.READY
var session: Session
var rod := 0
var hook := 0
var grip := 0
var bait := 0
var rods_owned: Array[bool] = [true, false]
var hooks_owned: Array[bool] = [true, false, false]
var grip_durability: Array[int] = [Data.GRIP_CAPACITY]
var charms_owned := 1
var bait_stock: Array[int] = []
var scare := 0.0
var wait_extension := 0.0
var remaining := 0.0
var locked: Dictionary = {}
var progress := 0
var target := 0
var mistakes := 0
var fish_direction := 0
var last_success := true
var last_judgement := Judgement.NONE
var last_progress_gain := 0
var last_message := ""
var bone_bonus := 0
var _snapshot: Dictionary = {}
var _at_river := false
var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _capture_remaining := 0.0
var _direction_run := 0
var _travel := 1.0
var _normal_half := 0.0
var _perfect_half := 0.0
var _typing := FishingQTE.new()


func _ready() -> void:
	_rng.randomize()
	bait_stock.resize(Data.BAITS.size())
	bait_stock.fill(0)
	bait_stock[0] = Data.STARTING_BAIT
	var bank := FishingWordBank.new()
	bank.words = PackedStringArray([VARIANT_WORD])
	_typing.word_bank = bank
	add_child(_typing)
	_typing.set_process(false)
	_typing.word_completed.connect(func(_word: String, _score: int) -> void: _land())


func _process(delta: float) -> void:
	if session.active:
		advance(delta)


func set_at_river(value: bool) -> void:
	_at_river = value
	if _at_river and phase == Phase.AWAITING_RETURN:
		_start_fish_capture()


func is_busy() -> bool:
	return phase not in [Phase.READY, Phase.CAUGHT, Phase.ESCAPED]


func durability() -> int:
	return grip_durability[grip]


func equipped_charms() -> int:
	return mini(rod + 1, charms_owned)


func set_rig(body: int, size_hook: int, handle: int, selected_bait: int) -> void:
	if is_busy() or session.paused:
		return
	if body < 0 or body >= rods_owned.size() or size_hook < 0 or size_hook >= hooks_owned.size():
		return
	if not rods_owned[body] or not hooks_owned[size_hook] or handle < 0 or handle >= grip_durability.size():
		return
	if selected_bait < 0 or selected_bait >= bait_stock.size():
		return
	rod = body
	hook = size_hook
	grip = handle
	bait = selected_bait
	state_changed.emit()


func buy_bait(index: int, quantity: int) -> bool:
	if quantity <= 0 or index < 0 or index >= bait_stock.size() or not session.spend(Data.BAIT_PRICES[index] * quantity):
		return false
	var auto_equipped := bait_stock[bait] == 0 and not is_busy()
	bait_stock[index] += quantity
	if auto_equipped:
		bait = index
	state_changed.emit()
	return true


func restore_bait_inventory(saved_stock: Array, equipped_bait: int) -> void:
	if saved_stock.size() == Data.LEGACY_BAIT_MAP.size():
		bait_stock.fill(0)
		for index in saved_stock.size():
			bait_stock[Data.LEGACY_BAIT_MAP[index]] += int(saved_stock[index])
		bait = Data.LEGACY_BAIT_MAP[clampi(equipped_bait, 0, saved_stock.size() - 1)]
		return
	for index in mini(saved_stock.size(), bait_stock.size()):
		bait_stock[index] = int(saved_stock[index])
	bait = clampi(equipped_bait, 0, bait_stock.size() - 1)


func has_any_bait() -> bool:
	for count in bait_stock:
		if count > 0:
			return true
	return false


func can_buy_device(index: int) -> bool:
	match index:
		0, 1:
			return not rods_owned[index]
		2, 3, 4:
			return not hooks_owned[index - 2]
		5:
			return true
		6:
			return charms_owned < 2
	return false


func buy_device(index: int) -> bool:
	if not can_buy_device(index) or not session.spend(Data.DEVICES[index][1]):
		return false
	match index:
		0, 1:
			rods_owned[index] = true
		2, 3, 4:
			hooks_owned[index - 2] = true
		5:
			grip_durability.append(Data.GRIP_CAPACITY)
		6:
			charms_owned += 1
	state_changed.emit()
	return true


func repair_cost(points: int) -> int:
	return ceili(clampi(points, 0, Data.GRIP_CAPACITY - durability()) / 2.0)


func repair(points: int) -> bool:
	var amount := clampi(points, 0, Data.GRIP_CAPACITY - durability())
	if is_busy() or amount == 0 or not session.spend(repair_cost(amount)):
		return false
	grip_durability[grip] += amount
	state_changed.emit()
	return true


func can_cast() -> bool:
	return not session.paused and not is_busy() and durability() > 0 and bait_stock[bait] > 0


func cast() -> bool:
	if not can_cast():
		return false
	_snapshot = {"rod": rod, "hook": hook, "bait": bait, "attachments": equipped_charms()}
	locked = {}
	progress = 0
	target = 0
	mistakes = 0
	bone_bonus = 0
	_direction_run = 0
	last_judgement = Judgement.NONE
	last_message = ""
	phase = Phase.WAITING
	scare = maxf(scare, 10.0)
	wait_extension = minf((scare - 10.0) * 0.1, 2.0)
	var draw := _rng.randf()
	# Sample a triangular distribution so waits near the mode occur more often.
	var early_span := Data.BITE_MODE - Data.BITE_MIN
	var late_span := Data.BITE_MAX - Data.BITE_MODE
	var span := early_span + late_span
	var wait: float
	if draw < early_span / span:
		wait = Data.BITE_MIN + sqrt(draw * span * early_span)
	else:
		wait = Data.BITE_MAX - sqrt((1.0 - draw) * span * late_span)
	remaining = wait + wait_extension
	state_changed.emit()
	return true


func disturb(level: float) -> void:
	var increase := maxf(clampf(level, 0.0, 30.0) - scare, 0.0)
	scare += increase
	if phase == Phase.WAITING:
		var added := minf(increase * 0.1, 2.0 - wait_extension)
		wait_extension += added
		remaining += added


func retract() -> bool:
	if session.paused or not is_busy():
		return false
	if phase == Phase.WAITING:
		phase = Phase.READY
		remaining = 0.0
		disturb(10.0)
		last_message = "已收竿，鱼饵和耐久未消耗。"
		state_changed.emit()
	else:
		_fail("已中断，上钩时已消耗鱼饵和耐久。")
	return true


func advance(delta: float) -> void:
	if session.is_time_suspended() or delta <= 0.0:
		return
	while delta > 0.000001 and is_busy():
		if not _at_river and phase not in [Phase.WAITING, Phase.AWAITING_RETURN]:
			break
		var timed := phase in [Phase.REELING, Phase.FEEDBACK]
		var step := minf(delta, minf(remaining, _capture_remaining) if timed else remaining)
		delta -= step
		remaining -= step
		scare = maxf(scare - step * 2.0, 0.0)
		if timed:
			_capture_remaining -= step
		if phase == Phase.REELING:
			_elapsed += step
		elif phase == Phase.TRUE_NAME:
			_typing.advance_hint(step)
		if timed and _capture_remaining <= 0.000001:
			_fail("拉鱼超时。")
		elif remaining <= 0.000001:
			match phase:
				Phase.WAITING:
					_bite()
				Phase.AWAITING_RETURN:
					_fail("未及时返回河岸，鱼脱钩了。")
				Phase.PREPARING:
					_capture_remaining = Data.FISH_TIME
					_start_round()
				Phase.REELING:
					_judge(Judgement.MISS, "漏按")
				Phase.FEEDBACK:
					_start_round()
				Phase.TRUE_NAME:
					_fail("真名捕获超时。")
	scare = maxf(scare - delta * 2.0, 0.0)


func get_expected_direction() -> int:
	return (fish_direction + 2) % 4


func get_travel_ratio() -> float:
	return _elapsed / _travel


func get_target_time() -> float:
	return _travel


func get_capture_time() -> float:
	return _capture_remaining


func is_perfect_timing() -> bool:
	return phase == Phase.REELING and absf(_elapsed - _travel) <= _perfect_half + 0.000001


func submit_direction(direction: int) -> bool:
	if session.paused or phase != Phase.REELING:
		return false
	if direction != get_expected_direction():
		_judge(Judgement.MISS, "方向错误")
		return false
	if absf(_elapsed - _travel) > _normal_half + 0.000001:
		_judge(Judgement.MISS, "过早")
		return false
	_judge(Judgement.PERFECT if is_perfect_timing() else Judgement.NORMAL, "")
	return true


func submit_letter(value: String) -> void:
	if phase == Phase.TRUE_NAME and not session.paused:
		_typing.submit_letter(value)


func true_name_hint() -> String:
	var letters := PackedStringArray()
	for index in VARIANT_WORD.length():
		letters.append(VARIANT_WORD[index] if index < _typing.revealed_count else "○")
	return "　".join(letters)


func _bite() -> void:
	var selected_bait: int = _snapshot.bait
	var water: int = _snapshot.rod
	if _rng.randf() >= (0.40 if selected_bait == Data.BONE_BAIT else 0.80):
		locked = {"bone": true}
	elif water == 1 and selected_bait == Data.VARIANT_BAIT and _rng.randf() < Data.VARIANT_CHANCE:
		locked = {"species": Data.VARIANT, "size": 3, "cm": _rng.randf_range(30.0001, 38.0)}
	else:
		locked = _roll_fish(water, selected_bait)
	if locked.is_empty():
		phase = Phase.READY
		last_message = "此处没有可上钩的鱼。"
		state_changed.emit()
		return
	bait_stock[selected_bait] -= 1
	grip_durability[grip] -= 1
	if locked.has("bone"):
		_land()
		return
	if not _at_river:
		phase = Phase.AWAITING_RETURN
		remaining = RETURN_LIMIT
		state_changed.emit()
		return
	_start_fish_capture()


func _start_fish_capture() -> void:
	if locked.species == Data.VARIANT:
		phase = Phase.TRUE_NAME
		remaining = VARIANT_LIMIT
		_typing.restart_session()
	else:
		var tier: int = Data.FISH[locked.species]["tier"]
		var multiplier := 1.0 + Data.SLOT_BONUS * int(_snapshot.attachments)
		target = Data.PROGRESS[tier][locked.size]
		_travel = Data.TRAVEL[tier]
		_normal_half = Data.NORMAL_HALF_WINDOW[tier] * multiplier
		_perfect_half = Data.PERFECT_HALF_WINDOW[tier] * multiplier
		phase = Phase.PREPARING
		remaining = Data.PREPARATION
	state_changed.emit()


func fish_weights(water: int, selected_bait: int, selected_school: int = 0) -> Array[float]:
	var weights: Array[float] = []
	for index in Data.SPECIES_COUNT:
		var weight: float = Data.FISH[index]["water"][water]
		if Data.bait_matches_fish(selected_bait, index):
			weight *= Data.ATTRIBUTE_BAIT_MULTIPLIER
		if Data.SCHOOL_SPECIES[selected_school] == index:
			weight *= 3.0
		weights.append(weight)
	return weights


func size_weights(species: int, selected_hook: int, selected_bait: int) -> Array[float]:
	var base: Array = Data.LANTERN_SIZE_WEIGHTS if species == Data.LANTERN else Data.SIZE_WEIGHTS
	var weights: Array[float] = []
	for size in 3:
		var multiplier := 3.0 if selected_bait == size + 1 else 1.0
		weights.append(base[size] * Data.HOOK_WEIGHTS[selected_hook][size] * multiplier)
	return weights


func _roll_fish(water: int, selected_bait: int) -> Dictionary:
	var species := _weighted_index(fish_weights(water, selected_bait))
	if species < 0:
		return {}
	var size := _weighted_index(size_weights(species, _snapshot.hook, selected_bait))
	var bounds: Vector2 = Data.FISH[species]["cm"]
	var from := [bounds.x * 0.5, bounds.x, bounds.y + 0.0001]
	var to := [bounds.x - 0.0001, bounds.y, bounds.y * 1.5]
	return {"species": species, "size": size, "cm": _rng.randf_range(from[size], to[size])}


func _weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return -1
	var draw := _rng.randf() * total
	var last := -1
	for index in weights.size():
		if weights[index] <= 0.0:
			continue
		last = index
		draw -= weights[index]
		if draw < 0.0:
			return index
	return last


func _start_round() -> void:
	var candidates := [0, 1, 2, 3]
	if _direction_run >= 2:
		candidates.erase(fish_direction)
	var next: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_direction_run = _direction_run + 1 if next == fish_direction else 1
	fish_direction = next
	_elapsed = 0.0
	remaining = _travel + _normal_half + 0.00001
	phase = Phase.REELING
	state_changed.emit()


func _judge(judgement: Judgement, reason: String) -> void:
	last_judgement = judgement
	last_success = judgement != Judgement.MISS
	var previous := progress
	if last_success:
		progress = mini(progress + (2 if judgement == Judgement.PERFECT else 1), target)
	else:
		mistakes += 1
		progress = maxi(progress - 1, 0)
	last_progress_gain = progress - previous
	pull_judged.emit(last_success, reason)
	if progress >= target:
		_land()
	elif mistakes >= Data.MISTAKE_LIMIT:
		_fail("累计三次失误，鱼脱钩了。")
	else:
		phase = Phase.FEEDBACK
		remaining = Data.ROUND_GAP
		last_message = reason
		state_changed.emit()


func _land() -> void:
	phase = Phase.CAUGHT
	remaining = 0.0
	if locked.has("bone"):
		disturb(10.0)
		session.record_bone()
		last_message = "已自动回收遗骨 ×1。"
	else:
		var species: int = locked.species
		var size: int = locked.size
		if species == Data.CHAIN:
			if size == 1:
				bone_bonus = int(_rng.randf() < 0.60)
			elif size == 2:
				bone_bonus = 1 + int(_rng.randf() < 0.50)
		locked["finger_bones"] = bone_bonus
		disturb([15.0, 20.0, 25.0, 30.0][size])
		session.record_catch(locked)
		last_message = "%s　%s，已入鱼篓。" % [Data.fish_name(species, size), Data.size_label(locked)]
		if bone_bonus > 0:
			last_message += " 指骨 +%d" % bone_bonus
	state_changed.emit()


func _fail(message: String) -> void:
	phase = Phase.ESCAPED
	remaining = 0.0
	disturb(15.0)
	last_message = message
	state_changed.emit()
