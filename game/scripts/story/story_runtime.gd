extends RefCounted
## One active case: reads steps, offers choices, applies effects and closes.
## It knows nothing about fishing, potions or money; the adapter supplies those.

signal changed
signal case_closed(outcome_id: String)
signal text_missing(key: String)

const Expr := preload("res://scripts/story/story_expr.gd")

var case_data: Dictionary = {}
var text_db = null
var shared = null
var flags: Dictionary = {}
var node_id := ""
var step_index := 0
var steps: Array = []
var closed := false
var outcome_id := ""
var started := false
var dose_fed := false
var dose_score := 0
var dose_label := ""
var last_step: Dictionary = {}
var last_error := ""

var _nodes: Dictionary = {}
var _enter_guard := 0


func setup(data: Dictionary, story_text, story_state) -> void:
	case_data = data
	text_db = story_text
	shared = story_state
	_nodes.clear()
	for node in case_data.get("nodes", []):
		_nodes[str(node.get("id", ""))] = node
	flags.clear()
	for key in case_data.get("state", {}).get("flags", {}).keys():
		var decl: Dictionary = case_data.state.flags[key]
		var value: Variant = decl.get("default", 0)
		match str(decl.get("type", "")):
			"int":
				value = int(value)
			"bool":
				value = bool(value)
			"string":
				value = str(value)
		flags[str(key)] = value


func start() -> bool:
	if started:
		return true
	started = true
	var entry := str(case_data.get("entry", ""))
	if entry == "":
		_fail("case has no entry")
		return false
	_enter(entry)
	return last_error == ""


func current_step() -> Dictionary:
	if step_index < steps.size():
		return _step_dict(steps[step_index])
	if not last_step.is_empty():
		return last_step
	return {}


func advance() -> bool:
	if closed:
		return false
	if steps.is_empty():
		var node := _node(node_id)
		if node.has("choices"):
			return false
		return _resolve_exit()
	if step_index < steps.size() - 1:
		step_index += 1
		last_step = _step_dict(steps[step_index])
		changed.emit()
		return true
	return _resolve_exit()


func visible_choices() -> Array:
	var result: Array = []
	var node := _node(node_id)
	for choice in node.get("choices", []):
		if choice.has("if") and not _test(str(choice.if)):
			continue
		var locked := false
		if choice.has("locked_if"):
			locked = _test(str(choice.locked_if))
		var reason := ""
		if choice.has("locked_text"):
			reason = _text(str(choice.locked_text))
		result.append({
			"id": str(choice.get("id", "")),
			"text": _text(str(choice.get("text", ""))),
			"locked": locked,
			"reason": reason,
		})
	return result


func choose(choice_id: String) -> bool:
	if closed:
		return false
	var node := _node(node_id)
	for choice in node.get("choices", []):
		if str(choice.get("id", "")) != choice_id:
			continue
		if choice.has("if") and not _test(str(choice.if)):
			return false
		if choice.has("locked_if") and _test(str(choice.locked_if)):
			return false
		_apply(choice.get("set", []))
		_enter(str(choice.get("next", "")))
		changed.emit()
		return last_error == ""
	return false


func can_feed_potion() -> bool:
	return not closed and not dose_fed and case_data.has("potion")


func feed_potion(effect: Vector3i, label: String) -> bool:
	if not can_feed_potion():
		return false
	var potion: Dictionary = case_data.get("potion", {})
	var coefficients: Dictionary = potion.get("score", {})
	dose_score = effect.x * int(coefficients.get("wisdom", 0)) \
		+ effect.y * int(coefficients.get("emotion", 0)) \
		+ effect.z * int(coefficients.get("will", 0))
	dose_fed = true
	dose_label = label
	flags["dose.fed"] = true
	flags["dose.score"] = dose_score
	flags["dose.label"] = label
	var next := str(potion.get("node", ""))
	if next == "":
		_fail("potion has no reaction node")
		return false
	_enter(next)
	changed.emit()
	return last_error == ""


func close(id: String) -> void:
	if closed:
		return
	var outcome: Dictionary = case_data.get("outcomes", {}).get(id, {})
	if outcome.is_empty():
		_fail("unknown outcome '%s'" % id)
		return
	_apply(case_data.get("canon", []))
	_apply(outcome.get("effects", []))
	outcome_id = id
	flags["outcome"] = id
	closed = true
	var case_id := str(case_data.get("id", "case"))
	for key in flags.keys():
		shared.history["case.%s.%s" % [case_id, str(key)]] = flags[key]
	shared.history["case.%s.outcome" % case_id] = id
	shared.history["case.%s.closed" % case_id] = true
	changed.emit()
	case_closed.emit(id)


func is_closed() -> bool:
	return closed


func get_outcome() -> Dictionary:
	var result: Dictionary = case_data.get("outcomes", {}).get(outcome_id, {}).duplicate(true)
	result["id"] = outcome_id
	return result


func get_outcome_id() -> String:
	return outcome_id


func get_node_id() -> String:
	return node_id


func get_dose_score() -> int:
	return dose_score


func get_dose_label() -> String:
	return dose_label


func has_fed_potion() -> bool:
	return dose_fed


func get_signature() -> String:
	return "%s|%d|%s|%s" % [node_id, step_index, str(closed), JSON.stringify(flags, "", true)]


func snapshot() -> Dictionary:
	return {
		"started": started,
		"node": node_id,
		"step": step_index,
		"flags": flags.duplicate(true),
		"closed": closed,
		"outcome": outcome_id,
		"dose_fed": dose_fed,
		"dose_score": dose_score,
		"dose_label": dose_label,
	}


func restore(data: Dictionary) -> bool:
	if data.is_empty() or not data.has("node"):
		return false
	flags = data.get("flags", {}).duplicate(true)
	node_id = str(data.get("node", ""))
	step_index = int(data.get("step", 0))
	closed = bool(data.get("closed", false))
	outcome_id = str(data.get("outcome", ""))
	dose_fed = bool(data.get("dose_fed", false))
	dose_score = int(data.get("dose_score", 0))
	dose_label = str(data.get("dose_label", ""))
	started = true
	var node := _node(node_id)
	if node.is_empty():
		_fail("restore: missing node '%s'" % node_id)
		return false
	_build_steps()
	step_index = clampi(step_index, 0, maxi(0, steps.size() - 1))
	last_step = _step_dict(steps[step_index]) if not steps.is_empty() else {}
	return true


func _enter(id: String) -> void:
	if _enter_guard > 64:
		_fail("node chain too deep at '%s'" % id)
		return
	_enter_guard += 1
	var node := _node(id)
	if node.is_empty():
		_fail("missing node '%s'" % id)
		_enter_guard -= 1
		return
	node_id = id
	_apply(node.get("set", []))
	_build_steps()
	step_index = 0
	last_step = {}
	if not steps.is_empty():
		last_step = _step_dict(steps[0])
	if steps.is_empty():
		_resolve_exit()
	_enter_guard -= 1
	changed.emit()


func _resolve_exit() -> bool:
	var node := _node(node_id)
	if node.has("choices"):
		return false
	if node.has("branch"):
		for entry in node.get("branch", []):
			if entry.has("if") and not _test(str(entry.if)):
				continue
			_apply(entry.get("set", []))
			_enter(str(entry.get("next", "")))
			return true
		if node.has("next"):
			_enter(str(node.next))
			return true
		_fail("branch node '%s' has no fallback" % node_id)
		return false
	if node.has("outcome"):
		close(str(node.outcome))
		return true
	if node.has("next"):
		_enter(str(node.next))
		return true
	_fail("node '%s' has no exit" % node_id)
	return false


func _build_steps() -> void:
	steps.clear()
	var node := _node(node_id)
	for raw in node.get("steps", []):
		if raw.has("if") and not _test(str(raw.if)):
			continue
		steps.append(raw)


func _step_dict(raw: Dictionary) -> Dictionary:
	var key := str(raw.get("text", ""))
	var speaker_key := str(raw.get("speaker", ""))
	var speaker_name := ""
	if speaker_key != "":
		var speaker: Dictionary = case_data.get("speakers", {}).get(speaker_key, {})
		speaker_name = str(speaker.get("name", speaker_key))
	return {
		"speaker": speaker_key,
		"speaker_name": speaker_name,
		"text": _text(key),
		"key": key,
	}


func _text(key: String) -> String:
	if text_db == null:
		return key
	if not text_db.has(key):
		text_missing.emit(key)
	return text_db.get_text(key)


func _context() -> Dictionary:
	return shared.context(flags)


func _test(expression: String) -> bool:
	var values := _context()
	var result: Variant = Expr.eval(expression, values)
	if Expr.last_error != "":
		_fail("condition '%s': %s" % [expression, Expr.last_error])
		return false
	return bool(result)


func _apply(effects: Array) -> void:
	for effect in effects:
		if not _apply_effect(str(effect)):
			return


func _apply_effect(statement: String) -> bool:
	var key := _effect_key(statement)
	if key == "":
		_fail("invalid effect '%s'" % statement)
		return false
	var values := _context()
	if not Expr.assign(statement, values):
		_fail("effect '%s': %s" % [statement, Expr.last_error])
		return false
	var value: Variant = values[key]
	if key.begins_with("world."):
		shared.world[key] = value
	elif key.begins_with("run."):
		shared.run[key] = value
	elif key.begins_with("case."):
		shared.history[key] = value
	else:
		flags[key] = value
	return true


func _effect_key(statement: String) -> String:
	var text := statement.strip_edges()
	var index := text.find("+=")
	if index < 0:
		index = text.find("-=")
	if index < 0:
		index = text.find("=")
	if index <= 0:
		return ""
	return text.substr(0, index).strip_edges()


func _node(id: String) -> Dictionary:
	return _nodes.get(id, {})


func _fail(message: String) -> void:
	if last_error == "":
		last_error = message
	push_error("StoryRuntime: %s" % message)
