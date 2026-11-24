extends RefCounted
## Shared story state: world flags, closed-case snapshots, run values and ledger.

var world: Dictionary = {}
var history: Dictionary = {}
var run: Dictionary = {}
var ledger: Array = []


func init_defaults(declarations: Dictionary) -> void:
	world.clear()
	for key in declarations.keys():
		var decl: Dictionary = declarations[key]
		var value: Variant = decl.get("default", false)
		match str(decl.get("type", "")):
			"int":
				value = int(value)
			"bool":
				value = bool(value)
			"string":
				value = str(value)
		world[str(key)] = value


func context(case_flags: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	for key in world.keys():
		values[key] = world[key]
	for key in history.keys():
		values[key] = history[key]
	for key in run.keys():
		values[key] = run[key]
	for key in case_flags.keys():
		values[key] = case_flags[key]
	return values


func snapshot() -> Dictionary:
	return {
		"world": world.duplicate(true),
		"history": history.duplicate(true),
		"run": run.duplicate(true),
		"ledger": ledger.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	world = data.get("world", {}).duplicate(true)
	history = data.get("history", {}).duplicate(true)
	run = data.get("run", {}).duplicate(true)
	ledger = data.get("ledger", []).duplicate(true)


func duplicate_state():
	var copy = get_script().new()
	copy.restore(snapshot())
	return copy
