extends Node
## Reusable sequential typing challenge: resets on a miss and owns an optional
## time limit. Presentation is left to the caller.

signal state_changed
signal completed(target: String)
signal missed(received: String, expected: String)
signal timed_out

@export var case_sensitive: bool = false

var target: String = ""
var typed_count: int = 0
var mistakes: int = 0
var time_limit: float = 0.0
var time_left: float = 0.0
var active: bool = false


func start(value: String, limit: float = 0.0) -> void:
	target = value if case_sensitive else value.to_upper()
	typed_count = 0
	mistakes = 0
	time_limit = maxf(limit, 0.0)
	time_left = time_limit
	active = not target.is_empty()
	state_changed.emit()


func tick(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	if time_limit > 0.0:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			active = false
			timed_out.emit()
			state_changed.emit()


func submit_character(value: String) -> bool:
	if not active:
		return false
	var character := value if case_sensitive else value.to_upper()
	if character.length() != 1:
		return false
	var expected := _char_at(typed_count)
	if expected == "":
		return false
	if character != expected:
		mistakes += 1
		typed_count = 0
		state_changed.emit()
		missed.emit(character, expected)
		return false
	typed_count += 1
	if typed_count == target.length():
		active = false
		state_changed.emit()
		completed.emit(target)
	else:
		state_changed.emit()
	return true


func stop() -> void:
	active = false
	time_left = 0.0
	state_changed.emit()


func _char_at(index: int) -> String:
	if index < 0 or index >= target.length():
		return ""
	return target.substr(index, 1)
