extends RefCounted

const COUNT := 5
const LEGACY_NAME := "bone_angler_save.json"


static func _path(directory: String, slot: int) -> String:
	return directory.path_join("bone_angler_slot_%d.json" % (slot + 1))


static func existing_path(directory: String, slot: int) -> String:
	if slot < 0 or slot >= COUNT:
		return ""
	var path := _path(directory, slot)
	if FileAccess.file_exists(path):
		return path
	if slot == 0:
		var legacy := directory.path_join(LEGACY_NAME)
		if FileAccess.file_exists(legacy):
			return legacy
	return ""


static func read(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	var decoder := JSON.new()
	if decoder.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = decoder.data
	if not parsed is Dictionary or not parsed.has("coins") or not parsed.has("released_count"):
		return {}
	for key in ["catches", "essences", "potions", "souls", "rods_owned", "hooks_owned", "bait_stock"]:
		if parsed.has(key) and not parsed[key] is Array:
			return {}
	for key in ["day_schedule", "first_services", "fishing", "story", "day_report", "tutorial"]:
		if parsed.has(key) and not parsed[key] is Dictionary:
			return {}
	var tutorial: Dictionary = parsed.get("tutorial", {})
	if not tutorial.get("seen_tips", []) is Array:
		return {}
	var day: Dictionary = parsed.get("day_schedule", {})
	if not day.is_empty():
		if not day.get("guests") is Array or not day.has("number") or not day.has("arrivals"):
			return {}
		if not day.has("bounds") and int(parsed.get("rules_version", 0)) == 15:
			for guest in day.guests:
				if not guest is Dictionary:
					return {}
		else:
			var bounds: Variant = day.get("bounds")
			if not bounds is Array or bounds.size() != 2:
				return {}
			for value in bounds:
				if not value is Array or value.size() != 3:
					return {}
			for guest in day.guests:
				if not guest is Array or guest.size() != 2:
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
	if slot < 0 or slot >= COUNT:
		return false
	var absolute_dir := ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute_dir) and DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return false
	var path := ProjectSettings.globalize_path(_path(directory, slot))
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


static func remove(directory: String, slot: int) -> bool:
	if slot < 0 or slot >= COUNT:
		return false
	# Remove the legacy fallback first so it cannot reappear after removing slot one.
	if slot == 0 and not _remove_file(directory.path_join(LEGACY_NAME)):
		return false
	return _remove_file(_path(directory, slot))


static func _remove_file(path: String) -> bool:
	return not FileAccess.file_exists(path) or DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
