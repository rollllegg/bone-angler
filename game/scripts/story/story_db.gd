extends RefCounted
## Loads compiled story data and answers schedule/ending questions.

const TextDB := preload("res://scripts/story/story_text.gd")
const Expr := preload("res://scripts/story/story_expr.gd")

const MANIFEST_PATH := "res://data/story/manifest.json"

var cases: Dictionary = {}
var text = null
var schedule: Array = []
var world_decl: Dictionary = {}
var endings: Array = []
var loaded := false
var load_error := ""


func load_all() -> bool:
	cases.clear()
	schedule.clear()
	world_decl.clear()
	endings.clear()
	loaded = false
	load_error = ""
	text = TextDB.new()
	var manifest := _read_json(MANIFEST_PATH)
	if manifest.is_empty():
		load_error = "missing or invalid %s" % MANIFEST_PATH
		return false
	var case_ids: Array = manifest.get("cases", [])
	for id in case_ids:
		var case_id := str(id)
		var path := "res://data/story/cases/%s.json" % case_id
		var data := _read_json(path)
		if data.is_empty():
			load_error = "missing or invalid %s" % path
			return false
		cases[case_id] = data
	if not text.load_file(str(manifest.get("text", ""))):
		load_error = "missing or invalid text DB"
		return false
	var schedule_data := _read_json(str(manifest.get("schedule", "")))
	schedule = schedule_data.get("slots", [])
	var world_data := _read_json(str(manifest.get("world", "")))
	world_decl = world_data.get("flags", {})
	var endings_data := _read_json(str(manifest.get("endings", "")))
	endings = endings_data.get("endings", [])
	loaded = true
	return true


func get_case(case_id: String) -> Dictionary:
	return cases.get(case_id, {})


func get_title(case_id: String) -> String:
	return str(get_case(case_id).get("title", case_id))


func get_queue_name(case_id: String) -> String:
	var data := get_case(case_id)
	return str(data.get("queue_name", data.get("title", case_id)))


func get_fee(case_id: String) -> int:
	return int(get_case(case_id).get("fee", 60))


func get_scheduled_case(day: int, slot: int) -> String:
	for entry in schedule:
		if int(entry.get("day", -1)) == day and int(entry.get("slot", -1)) == slot:
			var case_id := str(entry.get("case", ""))
			if cases.has(case_id):
				return case_id
	return ""


func evaluate_ending(state) -> Dictionary:
	var ordered := endings.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	var values: Dictionary = state.context({})
	for ending in ordered:
		var condition := str(ending.get("if", "true"))
		var result: Variant = Expr.eval(condition, values)
		if Expr.last_error != "":
			push_warning("StoryDB: ending %s condition failed: %s" % [str(ending.get("id", "?")), Expr.last_error])
			continue
		if bool(result):
			return ending
	return {}


func ending_lines_for(ending: Dictionary, state) -> PackedStringArray:
	var lines := PackedStringArray()
	if ending.is_empty():
		return lines
	var values: Dictionary = state.context({})
	var text_value: Variant = ending.get("text", "")
	if text_value is Array:
		for key in text_value:
			lines.append(text.render(text.get_text(str(key)), values))
	elif str(text_value) != "":
		lines.append(text.render(text.get_text(str(text_value)), values))
	for extra in ending.get("epilogue", []):
		var result: Variant = Expr.eval(str(extra.get("if", "true")), values)
		if Expr.last_error == "" and bool(result):
			lines.append(text.render(text.get_text(str(extra.get("text", ""))), values))
	return lines


func _read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}
