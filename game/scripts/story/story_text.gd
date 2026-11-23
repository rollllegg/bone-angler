extends RefCounted
## TextDB for compiled story keys. Missing keys stay visible for debugging.

var entries: Dictionary = {}
var missing: PackedStringArray = PackedStringArray()


func load_file(path: String) -> bool:
	entries.clear()
	if not FileAccess.file_exists(path):
		return false
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return false
	for key in parsed.keys():
		entries[str(key)] = str(parsed[key])
	return true


func has(key: String) -> bool:
	return entries.has(key)


func get_text(key: String) -> String:
	if entries.has(key):
		return str(entries[key])
	if not missing.has(key):
		missing.append(key)
	return "【缺失 %s】" % key
