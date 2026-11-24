extends Control
## The temporary letter challenge displayed below the guest's speech bubble.

const UI := preload("res://scripts/demo/demo_ui.gd")
const TypingChallenge := preload("res://scripts/systems/typing_challenge.gd")
const LetterBubbleRow := preload("res://scripts/demo/letter_bubble_row.gd")

var _runtime = null
var _typing: TypingChallenge
var _bubbles: LetterBubbleRow
var _status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.panel(self, Rect2(Vector2.ZERO, size), "wood_inset")
	_bubbles = LetterBubbleRow.new()
	_bubbles.position = Vector2(16, 8)
	_bubbles.size = Vector2(size.x - 32, 50)
	add_child(_bubbles)
	_status = UI.label(self, "", Rect2(16, 62, size.x - 32, 32), 18, UI.CREAM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_typing = TypingChallenge.new()
	add_child(_typing)
	_typing.state_changed.connect(_refresh)
	_typing.completed.connect(func(_target: String) -> void: _resolve(true))
	_typing.timed_out.connect(func() -> void: _resolve(false))
	hide()
	set_process(false)


func start_callout(runtime) -> void:
	if is_typing() or not runtime.can_callout():
		return
	_runtime = runtime
	var config: Dictionary = runtime.start_callout()
	var answer := str(config.get("answer", ""))
	var bubble_size := clampf(_bubbles.size.x / maxf(float(answer.length()), 1.0) - 6.0, 30.0, 46.0)
	_bubbles.setup(bubble_size, int(bubble_size * 0.48))
	_typing.start(answer, float(config.get("time_limit", 0.0)))
	show()
	set_process(true)


func is_typing() -> bool:
	return _runtime != null


func submit_letter(letter: String) -> void:
	_typing.submit_character(letter)


func cancel_callout() -> void:
	if is_typing():
		var runtime = _stop()
		runtime.cancel_callout()


func _resolve(success: bool) -> void:
	var runtime = _stop()
	runtime.resolve_callout(success)


func _stop():
	var runtime = _runtime
	_runtime = null
	hide()
	set_process(false)
	_typing.stop()
	return runtime


func _process(delta: float) -> void:
	_typing.tick(delta)


func _refresh() -> void:
	if not is_typing():
		return
	_bubbles.render(_typing.target, _typing.typed_count)
	var instruction := "依次输入真名"
	if _typing.typed_count == 0 and _typing.mistakes > 0:
		instruction = "输入有误，从头再试"
	_status.text = "%s　剩余 %.1f 秒" % [instruction, _typing.time_left] if _typing.time_limit > 0.0 else instruction
