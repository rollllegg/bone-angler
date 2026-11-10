class_name FishingQTE
extends Node
## Input advances immediately; the hint clock never gates correctness checks.

signal state_changed
signal word_completed(word: String, total_score: int)
signal input_missed(received: String, expected: String)

@export var word_bank: FishingWordBank = preload("res://data/fishing/practice_words.tres")
@export_range(0.0, 2.0, 0.05) var hint_delay: float = 0.2

var score: int = 0
var current_word: String = ""
var typed_count: int = 0
var revealed_count: int = 0

var _words: PackedStringArray = PackedStringArray()
var _word_index: int = 0
var _hint_remaining: float = 0.0
var _hint_pending: bool = false


func _ready() -> void:
	restart_session()


func _process(delta: float) -> void:
	advance_hint(delta)


func restart_session() -> void:
	_words.clear()
	if word_bank != null:
		for entry in word_bank.words:
			var word := entry.strip_edges().to_upper()
			if is_valid_word(word):
				_words.append(word)
	if _words.is_empty():
		_words.append("FISH")
	score = 0
	_word_index = 0
	_start_word()


func submit_letter(value: String) -> bool:
	var letter := value.to_upper()
	if letter.length() != 1 or not is_valid_word(letter) or current_word.is_empty():
		return false
	var expected := current_word.substr(typed_count, 1)
	if letter != expected:
		_reset_attempt()
		state_changed.emit()
		input_missed.emit(letter, expected)
		return false

	typed_count += 1
	# A guessed hidden letter is shown as correct immediately.
	revealed_count = maxi(revealed_count, typed_count)
	if typed_count == current_word.length():
		var completed_word := current_word
		score += 1
		_word_index = (_word_index + 1) % _words.size()
		# Later key events in this same frame can already reach the next word.
		_start_word()
		word_completed.emit(completed_word, score)
	else:
		_hint_remaining = maxf(hint_delay, 0.0)
		_hint_pending = true
		if _hint_remaining <= 0.0:
			_reveal_next()
		state_changed.emit()
	return true


func advance_hint(delta: float) -> void:
	if not _hint_pending:
		return
	_hint_remaining -= maxf(delta, 0.0)
	if _hint_remaining <= 0.0:
		_reveal_next()
		state_changed.emit()


func _start_word() -> void:
	current_word = _words[_word_index]
	_reset_attempt()
	state_changed.emit()


func _reset_attempt() -> void:
	typed_count = 0
	revealed_count = 1
	_hint_remaining = 0.0
	_hint_pending = false


func _reveal_next() -> void:
	revealed_count = mini(typed_count + 1, current_word.length())
	_hint_pending = false


static func is_valid_word(word: String) -> bool:
	if word.is_empty():
		return false
	for index in word.length():
		var character := word.unicode_at(index)
		if character < 65 or character > 90:
			return false
	return true
