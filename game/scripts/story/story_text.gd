extends RefCounted
## TextDB for compiled story keys. Missing keys stay visible for debugging.
## Inline conditionals use {{if expr}}...{{else}}...{{/if}} and are rendered
## against the current story state by the runtime and ending resolver.

const Expr := preload("res://scripts/story/story_expr.gd")

const IF_OPEN := "{{if "
const IF_CLOSE := "{{/if}}"
const ELSE := "{{else}}"

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


func render(raw: String, values: Dictionary) -> String:
	if not raw.contains(IF_OPEN):
		return raw
	return _render_block(raw, values)


static func structure_error(raw: String) -> String:
	var cursor := 0
	var depth := 0
	while cursor < raw.length():
		var open := raw.find(IF_OPEN, cursor)
		var close := raw.find(IF_CLOSE, cursor)
		var alt := raw.find(ELSE, cursor)
		var next := _first_tag(open, close, alt)
		if next < 0:
			break
		if next == open:
			var end := raw.find("}}", open + IF_OPEN.length())
			if end < 0:
				return "inline if is missing }}"
			var condition := raw.substr(open + IF_OPEN.length(), end - (open + IF_OPEN.length())).strip_edges()
			if condition == "":
				return "inline if has no condition"
			depth += 1
			cursor = end + 2
		elif next == close:
			if depth <= 0:
				return "inline /if has no matching if"
			depth -= 1
			cursor = close + IF_CLOSE.length()
		else:
			if depth <= 0:
				return "inline else has no matching if"
			cursor = alt + ELSE.length()
	return "" if depth == 0 else "inline if is missing /if"


static func extract_conditions(raw: String) -> PackedStringArray:
	var result := PackedStringArray()
	var cursor := 0
	while cursor < raw.length():
		var open := raw.find(IF_OPEN, cursor)
		if open < 0:
			break
		var end := raw.find("}}", open + IF_OPEN.length())
		if end < 0:
			break
		var condition := raw.substr(open + IF_OPEN.length(), end - (open + IF_OPEN.length())).strip_edges()
		if condition != "" and not result.has(condition):
			result.append(condition)
		cursor = end + 2
	return result


func _render_block(raw: String, values: Dictionary) -> String:
	var out := ""
	var cursor := 0
	while cursor < raw.length():
		var open := raw.find(IF_OPEN, cursor)
		if open < 0:
			out += raw.substr(cursor)
			break
		out += raw.substr(cursor, open - cursor)
		var tag_end := raw.find("}}", open + IF_OPEN.length())
		if tag_end < 0:
			out += raw.substr(open)
			break
		var condition := raw.substr(open + IF_OPEN.length(), tag_end - (open + IF_OPEN.length())).strip_edges()
		var close := _find_close(raw, tag_end + 2)
		if close < 0:
			out += raw.substr(open)
			break
		var body := raw.substr(tag_end + 2, close - (tag_end + 2))
		var else_pos := _find_else(body)
		var yes := body if else_pos < 0 else body.substr(0, else_pos)
		var no := "" if else_pos < 0 else body.substr(else_pos + ELSE.length())
		var keep := false
		if condition != "":
			var result: Variant = Expr.eval(condition, values)
			if Expr.last_error == "":
				keep = bool(result)
		out += _render_block(yes if keep else no, values)
		cursor = close + IF_CLOSE.length()
	return out


func _find_close(raw: String, start: int) -> int:
	var depth := 1
	var cursor := start
	while cursor < raw.length():
		var open := raw.find(IF_OPEN, cursor)
		var close := raw.find(IF_CLOSE, cursor)
		if close < 0:
			return -1
		if open >= 0 and open < close:
			depth += 1
			cursor = open + IF_OPEN.length()
		else:
			depth -= 1
			if depth == 0:
				return close
			cursor = close + IF_CLOSE.length()
	return -1


func _find_else(body: String) -> int:
	var depth := 0
	var cursor := 0
	while cursor < body.length():
		var open := body.find(IF_OPEN, cursor)
		var close := body.find(IF_CLOSE, cursor)
		var alt := body.find(ELSE, cursor)
		var next := _first_tag(open, close, alt)
		if next < 0:
			break
		if next == open:
			depth += 1
			var end := body.find("}}", open + IF_OPEN.length())
			cursor = (end + 2) if end >= 0 else body.length()
		elif next == close:
			if depth > 0:
				depth -= 1
			cursor = close + IF_CLOSE.length()
		else:
			if depth == 0:
				return alt
			cursor = alt + ELSE.length()
	return -1


static func _first_tag(a: int, b: int, c: int) -> int:
	var result := -1
	for value in [a, b, c]:
		if value < 0:
			continue
		if result < 0 or value < result:
			result = value
	return result
