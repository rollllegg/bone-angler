class_name SoulSession
extends Node
## Shared inventory and admission rules continue in both live locations.

signal state_changed
signal soul_arrived(soul_id: int)
signal soul_fed(soul_id: int, fish_index: int)
signal soul_released(soul_id: int, reward: int)
signal day_changed(day_number: int)

const ATTRIBUTE_NAMES := ["智慧", "情感", "意志"]
const ATTRIBUTE_COLORS := [Color("91ddad"), Color("80b9f0"), Color("f18888")]
const DAILY_REQUIREMENTS := [Vector3i(3, 3, 3), Vector3i(4, 3, 4), Vector3i(3, 5, 4), Vector3i(5, 4, 3)]
const SOUL_NAMES := ["迷路的旅人", "沉默的诗人", "疲惫的守卫", "年轻的学徒", "漂泊的歌者", "胆怯的骑士"]

@export_range(0.1, 60.0, 0.1) var spawn_interval_min: float = 20.0
@export_range(0.1, 60.0, 0.1) var spawn_interval_max: float = 25.0
@export_range(10.0, 600.0, 1.0) var day_duration: float = 90.0
@export_range(1, 1000) var release_reward: int = 10

var inventory: Array[int] = [0, 0, 0]
var souls: Array[Dictionary] = []
var coins: int = 0
var released_count: int = 0
var day: int = 1
var spawn_remaining: float = 0.0
var day_remaining: float = 90.0
var paused: bool = false
var active: bool = true
var _next_id: int = 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	spawn_remaining = _roll_spawn_interval()
	day_remaining = maxf(day_duration, 1.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if paused or not active or delta <= 0.0:
		return
	var left := delta
	# Consume boundaries in time order so long frames neither skip arrivals nor
	# generate a soul against a day that has not started yet.
	while left > 0.000001:
		var step := minf(left, minf(spawn_remaining, day_remaining))
		spawn_remaining -= step
		day_remaining -= step
		left -= step
		if day_remaining <= 0.000001:
			day += 1
			day_remaining = maxf(day_duration, 1.0)
			day_changed.emit(day)
			state_changed.emit()
		if spawn_remaining <= 0.000001:
			spawn_remaining = _roll_spawn_interval()
			_spawn_soul()


func get_requirements() -> Vector3i:
	return DAILY_REQUIREMENTS[(day - 1) % DAILY_REQUIREMENTS.size()]


func get_arrival_description() -> String:
	return "每 %s～%s 秒有一位灵魂来到门前" % [String.num(minf(spawn_interval_min, spawn_interval_max), 1).trim_suffix(".0"), String.num(maxf(spawn_interval_min, spawn_interval_max), 1).trim_suffix(".0")]


func _roll_spawn_interval() -> float:
	var lower := maxf(minf(spawn_interval_min, spawn_interval_max), 0.1)
	var upper := maxf(maxf(spawn_interval_min, spawn_interval_max), lower)
	return _rng.randf_range(lower, upper)


func get_soul(soul_id: int) -> Dictionary:
	for soul in souls:
		if soul["id"] == soul_id:
			return soul
	return {}


func get_missing(soul_id: int) -> Vector3i:
	var soul := get_soul(soul_id)
	if soul.is_empty():
		return Vector3i.ZERO
	var stats: Vector3i = soul["stats"]
	var required := get_requirements()
	return Vector3i(maxi(required.x - stats.x, 0), maxi(required.y - stats.y, 0), maxi(required.z - stats.z, 0))


func can_release(soul_id: int) -> bool:
	return not get_soul(soul_id).is_empty() and get_missing(soul_id) == Vector3i.ZERO


func add_fish(fish_index: int) -> bool:
	if fish_index < 0 or fish_index >= inventory.size():
		return false
	inventory[fish_index] += 1
	state_changed.emit()
	return true


func can_feed(soul_id: int, fish_index: int) -> bool:
	return not paused and fish_index >= 0 and fish_index < inventory.size() and inventory[fish_index] > 0 and not get_soul(soul_id).is_empty() and not can_release(soul_id)


func feed_fish(soul_id: int, fish_index: int) -> bool:
	if not can_feed(soul_id, fish_index):
		return false
	var soul := get_soul(soul_id)
	var bonus: Vector3i = DirectionFishing.FISH[fish_index]["stats"]
	var current: Vector3i = soul["stats"]
	inventory[fish_index] -= 1
	soul["stats"] = current + bonus
	soul_fed.emit(soul_id, fish_index)
	state_changed.emit()
	return true


func release_soul(soul_id: int) -> bool:
	if paused or not can_release(soul_id):
		return false
	for index in souls.size():
		if souls[index]["id"] == soul_id:
			souls.remove_at(index)
			coins += release_reward
			released_count += 1
			soul_released.emit(soul_id, release_reward)
			state_changed.emit()
			return true
	return false


func get_inventory_total() -> int:
	return inventory[0] + inventory[1] + inventory[2]


func set_paused(value: bool) -> void:
	paused = value
	state_changed.emit()


func _spawn_soul() -> void:
	var required := get_requirements()
	var stats := Vector3i(_rng.randi_range(0, required.x), _rng.randi_range(0, required.y), _rng.randi_range(0, required.z))
	var deficient_index := _rng.randi_range(0, 2)
	stats[deficient_index] = _rng.randi_range(0, required[deficient_index] - 1)
	# First visitor needs just one point: every kind of freshly caught fish
	# demonstrates the complete feed-and-release loop immediately.
	if _next_id == 1:
		stats = required - Vector3i(1, 0, 0)
	var soul := {"id": _next_id, "name": SOUL_NAMES[(_next_id - 1) % SOUL_NAMES.size()], "stats": stats, "arrival_day": day}
	souls.append(soul)
	_next_id += 1
	soul_arrived.emit(soul["id"])
	state_changed.emit()
