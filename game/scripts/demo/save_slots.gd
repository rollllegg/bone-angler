extends RefCounted

const COUNT := 3


static func _path(directory: String, slot: int) -> String:
	return directory.path_join("bone_angler_v15_slot_%d.json" % (slot + 1))


static func existing_path(directory: String, slot: int) -> String:
	var path := _path(directory, slot)
	if FileAccess.file_exists(path):
		return path
	var previous := directory.path_join("bone_angler_slot_%d.json" % (slot + 1))
	if FileAccess.file_exists(previous) and not read(previous).is_empty():
		return previous
	if slot == 0:
		for name in ["bone_angler_save_v15.json", "bone_angler_save_v14.json"]:
			var legacy := directory.path_join(name)
			if FileAccess.file_exists(legacy):
				return legacy
	return ""


static func read(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("coins") or not parsed.has("released_count") or int(parsed.get("rules_version", 0)) not in [14, 15]:
		return {}
	for key in ["catches", "essences", "potions", "souls", "rods_owned", "hooks_owned", "bait_stock"]:
		if parsed.has(key) and not parsed[key] is Array:
			return {}
	for key in ["day_schedule", "first_services", "fishing", "story", "day_report"]:
		if parsed.has(key) and not parsed[key] is Dictionary:
			return {}
	var day: Dictionary = parsed.get("day_schedule", {})
	if not day.is_empty():
		if not day.get("guests") is Array or not day.has("number") or not day.has("arrivals"):
			return {}
		for guest in day.guests:
			if not guest is Dictionary:
				return {}
			for field in ["stats", "before"]:
				if not guest.get(field) is Array or guest[field].size() != 3:
					return {}
	for group in ["potions", "souls"]:
		for entry in parsed.get(group, []):
			if not entry is Dictionary:
				return {}
			var fields := ["effect"] if group == "potions" else ["stats", "before"]
			for field in fields:
				if entry.has(field) and (not entry[field] is Array or entry[field].size() != 3):
					return {}
	return parsed


static func write(directory: String, slot: int, data: Dictionary) -> bool:
	return _write_path(_path(directory, slot), data)


static func _checkpoint_path(directory: String, run_id: String) -> String:
	if run_id.is_empty() or not run_id.is_valid_filename():
		return ""
	return directory.path_join("bone_angler_v15_run_%s.json" % run_id)


static func write_checkpoint(directory: String, run_id: String, data: Dictionary) -> bool:
	var path := _checkpoint_path(directory, run_id)
	return not path.is_empty() and _write_path(path, data)


static func read_checkpoint(directory: String, run_id: String) -> Dictionary:
	var path := _checkpoint_path(directory, run_id)
	return read(path) if not path.is_empty() and FileAccess.file_exists(path) else {}


static func _write_path(target: String, data: Dictionary) -> bool:
	var directory := target.get_base_dir()
	var absolute_dir := ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute_dir) and DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return false
	var path := ProjectSettings.globalize_path(target)
	var temporary := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK and DirAccess.rename_absolute(temporary, path) == OK:
		return true
	DirAccess.remove_absolute(temporary)
	return false
