extends Node
## Reusable sequential typing challenge: reveals hints, resets on a miss,
## and owns an optional time limit. Presentation is left to the caller.

signal state_changed
signal completed(target: String)
signal missed(received: String, expected: String)
signal timed_out

@export var hint_delay: float = 0.2
@export var case_sensitive: bool = false

var target: String = ""
var typed_count: int = 0
var revealed_count: int = 0
var mistakes: int = 0
var time_limit: float = 0.0
var time_left: float = 0.0
var active: bool = false

var _hint_remaining: float = 0.0
var _hint_pending: bool = false


func start(value: String, limit: float = 0.0) -> void:
	target = value if case_sensitive else value.to_upper()
	typed_count = 0
	revealed_count = 1 if not target.is_empty() else 0
	mistakes = 0
	time_limit = maxf(limit, 0.0)
	time_left = time_limit
	active = not target.is_empty()
	_hint_remaining = 0.0
	_hint_pending = false
	state_changed.emit()


func tick(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	if time_limit > 0.0:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			active = false
			_hint_pending = false
			timed_out.emit()
			state_changed.emit()
			return
	advance_hint(delta)


func advance_hint(delta: float) -> void:
	if not active or not _hint_pending:
		return
	_hint_remaining -= maxf(delta, 0.0)
	if _hint_remaining <= 0.0:
		_reveal_next()
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
		_reset_attempt()
		state_changed.emit()
		missed.emit(character, expected)
		return false
	typed_count += 1
	revealed_count = maxi(revealed_count, typed_count)
	if typed_count == target.length():
		active = false
		state_changed.emit()
		completed.emit(target)
	else:
		_hint_remaining = maxf(hint_delay, 0.0)
		_hint_pending = true
		if _hint_remaining <= 0.0:
			_reveal_next()
		state_changed.emit()
	return true


func stop() -> void:
	active = false
	_hint_pending = false
	time_left = 0.0
	state_changed.emit()


func _char_at(index: int) -> String:
	if index < 0 or index >= target.length():
		return ""
	return target.substr(index, 1)


func _reset_attempt() -> void:
	typed_count = 0
	revealed_count = 1 if not target.is_empty() else 0
	_hint_remaining = 0.0
	_hint_pending = false


func _reveal_next() -> void:
	revealed_count = mini(typed_count + 1, target.length())
	_hint_pending = false
