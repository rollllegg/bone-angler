extends RefCounted
## Plays the cue array attached to one story step.
## It owns timing and skip semantics; StoryStage owns the visible result.

signal started(step_key: String)
signal finished(step_key: String)
signal skipped(step_key: String)

const Expr := preload("res://scripts/story/story_expr.gd")
const Catalog := preload("res://scripts/story/story_cue_catalog.gd")

var _stage = null
var _items: Array = []
var _step_key := ""
var _playing := false


func set_stage(stage) -> void:
	_stage = stage
	for item in _items:
		if item.started and not item.done and _stage != null:
			_stage.finish_cue(item.cue)


func get_stage():
	return _stage


func play(step_key: String, cues: Array, context: Dictionary) -> void:
	cancel()
	_step_key = step_key
	for raw in cues:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cue: Dictionary = raw
		if cue.has("if") and not _test(str(cue.if), context):
			continue
		var cue_type := str(cue.get("type", ""))
		var duration := float(cue.get("duration", Catalog.default_duration(cue_type)))
		var delay := float(cue.get("delay", 0.0))
		_items.append({
			"cue": cue.duplicate(true),
			"duration": maxf(duration, 0.0),
			"elapsed": -maxf(delay, 0.0),
			"started": false,
			"done": false,
		})
	_playing = not _items.is_empty()
	if not _playing:
		finished.emit(step_key)
		return
	started.emit(step_key)
	_advance(0.0)
	_maybe_complete()


func tick(delta: float) -> void:
	if not _playing:
		return
	_advance(maxf(delta, 0.0))
	_maybe_complete()


func skip() -> void:
	if not _playing:
		return
	_settle_all()
	_playing = false
	skipped.emit(_step_key)
	finished.emit(_step_key)


func cancel() -> void:
	_settle_all()
	_items.clear()
	_playing = false
	_step_key = ""


func is_playing() -> bool:
	return _playing


func blocks_advance() -> bool:
	for item in _items:
		if item.done:
			continue
		if _blocks(item.cue):
			return true
	return false


func _advance(delta: float) -> void:
	for item in _items:
		if item.done:
			continue
		item.elapsed += delta
		if not item.started and item.elapsed >= 0.0:
			item.started = true
			if _stage != null:
				_stage.begin_cue(item.cue, item.duration)
		if item.started and item.elapsed >= item.duration:
			item.done = true
			if _stage != null:
				_stage.finish_cue(item.cue)


func _maybe_complete() -> void:
	if not _playing:
		return
	for item in _items:
		if item.done:
			continue
		if not item.started:
			return
		if _blocks(item.cue):
			return
	_playing = false
	finished.emit(_step_key)


func _settle_all() -> void:
	for item in _items:
		if item.done:
			continue
		if not item.started:
			item.started = true
			if _stage != null:
				_stage.begin_cue(item.cue, 0.0)
		item.done = true
		if _stage != null:
			_stage.finish_cue(item.cue)


func _blocks(cue: Dictionary) -> bool:
	return bool(cue.get("wait", false)) or str(cue.get("type", "")) == "wait"


func _test(expression: String, context: Dictionary) -> bool:
	var result: Variant = Expr.eval(expression, context)
	if Expr.last_error != "":
		return false
	return bool(result)
