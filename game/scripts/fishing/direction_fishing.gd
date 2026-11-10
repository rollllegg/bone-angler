class_name DirectionFishing
extends Node
## Fixed-length beats: follow the opposite WASD direction, then time the pull
## when the water entry reaches the dashed square for a double-progress hit.

signal state_changed
signal pull_judged(success: bool, reason: String)
signal fish_caught(fish_index: int, total_caught: int)

enum Phase { READY, WAITING, REELING, FEEDBACK, CAUGHT, ESCAPED }
enum Direction { UP, LEFT, DOWN, RIGHT }
enum Judgement { NONE, NORMAL, PERFECT, MISS }

const FISH := [
	{"name": "幽鳍小鱼", "pulls": 3, "color": Color("91ddad"), "stats": Vector3i(4, 1, 1), "scale": 0.78, "tag": "轻巧 · 3 点进度"},
	{"name": "冥河银鲷", "pulls": 5, "color": Color("80b9f0"), "stats": Vector3i(1, 4, 1), "scale": 1.0, "tag": "有力 · 5 点进度"},
	{"name": "深渊骨鲶", "pulls": 8, "color": Color("f18888"), "stats": Vector3i(1, 1, 4), "scale": 1.24, "tag": "顽强 · 8 点进度"},
]
const DIRECTION_NAMES := ["上", "左", "下", "右"]
const KEYS := ["W", "A", "S", "D"]
const VECTORS := [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]

@export_range(0.1, 5.0, 0.1) var bite_delay: float = 1.2
@export_range(0.6, 5.0, 0.05) var beat_duration: float = 1.6
@export_range(0.05, 0.3, 0.01) var perfect_half_window: float = 0.14
@export_range(1, 10) var mistake_limit: int = 3
@export var random_fish_on_cast: bool = true

var phase: Phase = Phase.READY
var fish_index: int = 0
var fish_direction: int = Direction.RIGHT
var successful_pulls: int = 0
var mistakes: int = 0
var remaining: float = 0.0
var paused: bool = false
var caught_counts: Array[int] = [0, 0, 0]
var last_message: String = ""
var last_success: bool = true
var last_judgement: Judgement = Judgement.NONE
var last_progress_gain: int = 0
var perfect_count: int = 0
var successful_inputs: int = 0
var beat_elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _previous_direction: int = -1


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	advance(delta)


func select_fish(index: int) -> bool:
	if is_busy() or index < 0 or index >= FISH.size():
		return false
	fish_index = index
	_reset_attempt()
	state_changed.emit()
	return true


func cast() -> bool:
	if is_busy():
		return false
	if random_fish_on_cast:
		fish_index = _rng.randi_range(0, FISH.size() - 1)
	_reset_attempt()
	phase = Phase.WAITING
	remaining = maxf(bite_delay, 0.0)
	state_changed.emit()
	return true


func advance(delta: float) -> void:
	if paused or not is_busy() or delta <= 0.0:
		return
	if phase == Phase.REELING:
		beat_elapsed = minf(beat_elapsed + delta, get_beat_duration())
		remaining = maxf(get_beat_duration() - beat_elapsed, 0.0)
		if remaining <= 0.0:
			_judge(Judgement.MISS)
	else:
		var overshoot := delta - remaining
		remaining = maxf(remaining - delta, 0.0)
		if remaining <= 0.0:
			_start_round()
			# Preserve the beat across normal frame boundaries. A stalled frame
			# still starts a fresh visible beat instead of missing unseen notes.
			if overshoot > 0.0 and overshoot < 0.1:
				beat_elapsed = overshoot
				remaining = get_beat_duration() - beat_elapsed
	state_changed.emit()


func submit_key(value: String) -> bool:
	var key := value.to_upper()
	if paused or phase != Phase.REELING or not key in KEYS:
		return false
	var success := key == get_expected_key()
	var result := Judgement.MISS
	if success:
		result = Judgement.PERFECT if is_perfect_timing() else Judgement.NORMAL
	_judge(result)
	state_changed.emit()
	return success


func set_paused(value: bool) -> void:
	paused = value and is_busy()
	state_changed.emit()


func is_busy() -> bool:
	return phase in [Phase.WAITING, Phase.REELING, Phase.FEEDBACK]


func get_required_pulls() -> int:
	return FISH[fish_index]["pulls"]


func get_beat_duration() -> float:
	return maxf(beat_duration, 0.6)


func get_target_time() -> float:
	return get_beat_duration() * 0.625


func get_perfect_half_window() -> float:
	return clampf(perfect_half_window, 0.01, get_target_time() * 0.4)


func is_perfect_timing() -> bool:
	return phase == Phase.REELING and absf(beat_elapsed - get_target_time()) <= get_perfect_half_window() + 0.000001


func get_travel_ratio() -> float:
	# One means exactly on the frame; the point travels a little beyond it.
	return clampf(0.16 + 0.84 * beat_elapsed / get_target_time(), 0.16, 1.2)


func get_expected_direction() -> int:
	return (fish_direction + 2) % 4


func get_expected_key() -> String:
	return KEYS[get_expected_direction()]


func get_pull_direction_name() -> String:
	return DIRECTION_NAMES[get_expected_direction()]


func get_total_caught() -> int:
	return caught_counts[0] + caught_counts[1] + caught_counts[2]


func _reset_attempt() -> void:
	phase = Phase.READY
	successful_pulls = 0
	mistakes = 0
	remaining = 0.0
	paused = false
	last_message = ""
	last_judgement = Judgement.NONE
	last_progress_gain = 0
	perfect_count = 0
	successful_inputs = 0
	beat_elapsed = 0.0
	_previous_direction = -1


func _start_round() -> void:
	# Avoid adjacent identical directions so holding/mashing one key cannot win.
	var next_direction := _rng.randi_range(0, 3 if _previous_direction < 0 else 2)
	if _previous_direction >= 0 and next_direction >= _previous_direction:
		next_direction += 1
	fish_direction = next_direction
	_previous_direction = next_direction
	phase = Phase.REELING
	beat_elapsed = 0.0
	remaining = get_beat_duration()


func _judge(result: Judgement) -> void:
	var success := result in [Judgement.NORMAL, Judgement.PERFECT]
	last_success = success
	last_judgement = result
	last_message = ["", "成功", "完美", "失误"][result]
	last_progress_gain = 0
	if success:
		successful_inputs += 1
		var gain := 2 if result == Judgement.PERFECT else 1
		last_progress_gain = mini(gain, get_required_pulls() - successful_pulls)
		successful_pulls += last_progress_gain
		if result == Judgement.PERFECT:
			perfect_count += 1
	else:
		mistakes += 1
	if successful_pulls >= get_required_pulls():
		phase = Phase.CAUGHT
		remaining = 0.0
		caught_counts[fish_index] += 1
		fish_caught.emit(fish_index, get_total_caught())
	elif mistakes >= mistake_limit:
		phase = Phase.ESCAPED
		remaining = 0.0
	else:
		phase = Phase.FEEDBACK
		# Early input cannot bring the next beat forward. Perfect input earns
		# twice the progress on the same clock, so it actually catches faster.
		remaining = maxf(get_beat_duration() - beat_elapsed, 0.12)
	pull_judged.emit(success, last_message)
