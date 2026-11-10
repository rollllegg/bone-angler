class_name RodQTE
extends Node
## One sweep, three joints, then a recovery adjusted by the judgement results.
## No inventory or fishing dependency: callers listen for operation_completed.

signal state_changed
signal checkpoint_judged(index: int, result: int)
signal recovery_started(duration: float)
signal operation_completed(mode: int, summary: Dictionary)

enum Mode { ASSEMBLE, DISASSEMBLE }
enum Phase { IDLE, SWEEP, RECOVERY, COMPLETE }
enum Result { PENDING, GOOD, PERFECT, MISS }

const CHECKPOINTS := [0.22, 0.50, 0.78]
const JOINT_NAMES := ["握把 — 竿体", "竿体 — 鱼线", "鱼线 — 鱼钩"]

@export_range(1.0, 15.0, 0.1) var sweep_duration: float = 5.0
@export_range(0.02, 0.24, 0.01) var success_width: float = 0.14
@export_range(0.005, 0.10, 0.005) var perfect_width: float = 0.04
@export_range(0.0, 10.0, 0.1) var base_recovery: float = 3.0
@export_range(0.0, 5.0, 0.1) var perfect_bonus: float = 1.0
@export_range(0.0, 5.0, 0.1) var miss_penalty: float = 1.0

var mode: Mode = Mode.ASSEMBLE
var phase: Phase = Phase.IDLE
var results: Array[int] = [Result.PENDING, Result.PENDING, Result.PENDING]
var current_index: int = 0
var sweep_elapsed: float = 0.0
var recovery_duration: float = 0.0
var recovery_remaining: float = 0.0
var perfect_count: int = 0
var good_count: int = 0
var miss_count: int = 0


func _process(delta: float) -> void:
	advance(delta)


func reset(next_mode: Mode = Mode.ASSEMBLE) -> void:
	mode = next_mode
	phase = Phase.IDLE
	results = [Result.PENDING, Result.PENDING, Result.PENDING]
	current_index = 0
	sweep_elapsed = 0.0
	recovery_duration = 0.0
	recovery_remaining = 0.0
	perfect_count = 0
	good_count = 0
	miss_count = 0
	state_changed.emit()


func start(next_mode: Mode = Mode.ASSEMBLE) -> void:
	reset(next_mode)
	phase = Phase.SWEEP
	state_changed.emit()


func advance(delta: float) -> void:
	if phase not in [Phase.SWEEP, Phase.RECOVERY] or delta <= 0.0:
		return
	var remaining := maxf(delta, 0.0)
	# Consume time at each missed window boundary. A slow frame can miss several
	# joints and still spend only its leftover time in recovery.
	while phase == Phase.SWEEP and remaining > 0.0:
		var deadline: float = (CHECKPOINTS[current_index] + get_success_half_width()) * get_sweep_duration()
		var until_deadline := maxf(deadline - sweep_elapsed, 0.0)
		if remaining <= until_deadline:
			sweep_elapsed += remaining
			remaining = 0.0
		else:
			sweep_elapsed = deadline
			remaining -= until_deadline
			_resolve(Result.MISS)
	if phase == Phase.RECOVERY:
		recovery_remaining = maxf(recovery_remaining - remaining, 0.0)
		if recovery_remaining <= 0.0:
			_complete()
	state_changed.emit()


func submit() -> int:
	if phase != Phase.SWEEP:
		return Result.PENDING
	var distance: float = absf(get_progress() - CHECKPOINTS[current_index])
	var result := Result.MISS
	if distance <= get_perfect_half_width() + 0.000001:
		result = Result.PERFECT
	elif distance <= get_success_half_width() + 0.000001:
		result = Result.GOOD
	_resolve(result)
	state_changed.emit()
	return result


func get_progress() -> float:
	return clampf(sweep_elapsed / get_sweep_duration(), 0.0, 1.0)


func get_sweep_duration() -> float:
	return maxf(sweep_duration, 0.001)


func get_success_half_width() -> float:
	return clampf(success_width, 0.02, 0.24) * 0.5


func get_perfect_half_width() -> float:
	return clampf(perfect_width, 0.0, get_success_half_width() * 2.0) * 0.5


func get_joint_index(checkpoint_index: int) -> int:
	return checkpoint_index if mode == Mode.ASSEMBLE else 2 - checkpoint_index


func get_joint_name(checkpoint_index: int) -> String:
	return JOINT_NAMES[get_joint_index(checkpoint_index)]


func get_recovery_total() -> float:
	return maxf(base_recovery - perfect_count * perfect_bonus + miss_count * miss_penalty, 0.0)


func get_summary() -> Dictionary:
	return {
		"perfect": perfect_count,
		"good": good_count,
		"miss": miss_count,
		"recovery": recovery_duration,
		"results": results.duplicate(),
	}


func _resolve(result: int) -> void:
	var index := current_index
	results[index] = result
	match result:
		Result.PERFECT: perfect_count += 1
		Result.GOOD: good_count += 1
		Result.MISS: miss_count += 1
	current_index += 1
	checkpoint_judged.emit(index, result)
	if current_index == CHECKPOINTS.size():
		phase = Phase.RECOVERY
		recovery_duration = get_recovery_total()
		recovery_remaining = recovery_duration
		recovery_started.emit(recovery_duration)
		if recovery_remaining <= 0.0:
			_complete()


func _complete() -> void:
	phase = Phase.COMPLETE
	operation_completed.emit(mode, get_summary())
