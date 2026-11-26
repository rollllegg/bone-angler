extends SceneTree
## Compiles narrative/derived/*.graph.json + narrative/prose/*.md into game/data/story/.
## Run: godot --headless --path game --script res://tools/story_build.gd

const Expr := preload("res://scripts/story/story_expr.gd")
const StoryText := preload("res://scripts/story/story_text.gd")
const CueCatalog := preload("res://scripts/story/story_cue_catalog.gd")

var errors: Array = []
var warnings: Array = []
var text_map: Dictionary = {}
var used_keys: Dictionary = {}
var cue_totals: Dictionary = {}
var project_dir := ""
var repo_dir := ""
var narrative_dir := ""
var out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	project_dir = ProjectSettings.globalize_path("res://")
	repo_dir = project_dir.path_join("..").simplify_path()
	narrative_dir = repo_dir.path_join("narrative")
	out_dir = project_dir.path_join("data/story")

	var world_data := _read_json(narrative_dir.path_join("derived/world.json"))
	var schedule_data := _read_json(narrative_dir.path_join("derived/schedule.json"))
	var endings_data := _read_json(narrative_dir.path_join("derived/endings.json"))
	var world_decl: Dictionary = world_data.get("flags", {})

	var graph_files := _list_graphs()
	if graph_files.is_empty():
		_error("no *.graph.json found in narrative/derived")
	var compiled: Dictionary = {}
	var case_ids: Array = []
	for path in graph_files:
		var filename: String = str(path).get_file()
		var case_id: String = filename.trim_suffix(".graph.json")
		var graph := _read_json(path)
		if graph.is_empty():
			_error("cannot read %s" % path)
			continue
		if str(graph.get("id", "")) != case_id:
			_error("%s: id '%s' does not match filename '%s'" % [path, str(graph.get("id", "")), case_id])
			continue
		var prose_path := narrative_dir.path_join("prose").path_join("%s.md" % case_id)
		var parsed := _parse_prose(prose_path, graph.get("speakers", {}))
		var case_text := _build_text(parsed, case_id + ".")
		_check_inline_text(case_text, graph.get("state", {}).get("flags", {}), world_decl, case_id)
		for key in case_text.keys():
			if text_map.has(key):
				_error("duplicate text key: %s" % key)
			text_map[key] = case_text[key]
		_validate_case(graph, world_decl)
		_attach_cues(graph, case_id, case_text, world_decl)
		compiled[case_id] = graph
		case_ids.append(case_id)

	# Common ending prose uses keys without a case prefix.
	var common_path := narrative_dir.path_join("prose/endings.md")
	if FileAccess.file_exists(common_path):
		var parsed_common := _parse_prose(common_path, {})
		var common_text := _build_text(parsed_common, "")
		_check_inline_text(common_text, {}, world_decl, "endings")
		for key in common_text.keys():
			if text_map.has(key):
				_error("duplicate text key: %s" % key)
			text_map[key] = common_text[key]

	_validate_schedule(schedule_data, case_ids, world_decl)
	_validate_endings(endings_data, world_decl, compiled)

	for key in text_map.keys():
		if not used_keys.has(key):
			_error("unused prose key: %s" % key)

	if not errors.is_empty():
		_write_report(compiled, case_ids, world_decl, endings_data)
		for message in errors:
			printerr("ERROR: " + message)
		print("Story build failed: %d errors, %d warnings" % [errors.size(), warnings.size()])
		quit(1)
		return

	_write_outputs(compiled, case_ids, world_data, schedule_data, endings_data)
	_write_report(compiled, case_ids, world_decl, endings_data)
	print("Story build: %d case(s), %d text key(s), 0 errors" % [compiled.size(), text_map.size()])
	quit(0)


func _list_graphs() -> Array:
	var path := narrative_dir.path_join("derived")
	var dir := DirAccess.open(path)
	var result: Array = []
	if dir == null:
		_error("cannot open %s" % path)
		return result
	for file in dir.get_files():
		if file.ends_with(".graph.json"):
			result.append(path.path_join(file))
	result.sort()
	return result


func _parse_prose(path: String, speakers: Dictionary) -> Dictionary:
	var sections: Dictionary = {}
	if not FileAccess.file_exists(path):
		_error("missing prose: %s" % path)
		return sections
	var raw := FileAccess.get_file_as_string(path)
	var current := ""
	for line_value in raw.split("\n"):
		var line := str(line_value).strip_edges()
		if line.begins_with("## "):
			current = line.substr(3).strip_edges()
			sections[current] = []
			continue
		if line.is_empty() or line.begins_with("# ") or line.begins_with(">"):
			continue
		if current == "":
			_error("%s: line outside a section: %s" % [path, line])
			continue
		var entry := {"speaker": "", "text": line}
		var colon := line.find("：")
		if colon > 0:
			var prefix := line.substr(0, colon).strip_edges()
			var speaker_key := _speaker_key(prefix, speakers)
			if speaker_key != "":
				entry["speaker"] = speaker_key
				entry["text"] = line.substr(colon + 1).strip_edges()
		sections[current].append(entry)
	return sections


func _build_text(parsed: Dictionary, prefix: String) -> Dictionary:
	var result: Dictionary = {}
	for section in parsed.keys():
		var entries: Array = parsed[section]
		if str(section).begins_with("choice."):
			if entries.size() != 1:
				_error("section '%s' must contain exactly one choice line" % section)
				continue
			result[prefix + str(section)] = entries[0]["text"]
		else:
			for index in entries.size():
				var key := "%s%s.%d" % [prefix, str(section), index + 1]
				result[key] = entries[index]["text"]
	return result


func _check_inline_text(text_map: Dictionary, case_flags: Dictionary, world_decl: Dictionary, context: String) -> void:
	for key in text_map.keys():
		var raw := str(text_map[key])
		var problem := StoryText.structure_error(raw)
		if problem != "":
			_error("%s %s: %s" % [context, str(key), problem])
		for condition in StoryText.extract_conditions(raw):
			_check_condition(condition, case_flags, world_decl, "%s %s inline" % [context, str(key)])


func _validate_case(graph_data: Dictionary, world_decl: Dictionary) -> void:
	var case_id := str(graph_data.get("id", "?"))
	var case_flags: Dictionary = graph_data.get("state", {}).get("flags", {})
	var nodes: Array = graph_data.get("nodes", [])
	var node_ids: Dictionary = {}
	for node in nodes:
		var id := str(node.get("id", ""))
		if id == "":
			_error("%s: node without id" % case_id)
			continue
		if node_ids.has(id):
			_error("%s: duplicate node '%s'" % [case_id, id])
		node_ids[id] = node
	if not node_ids.has(str(graph_data.get("entry", ""))):
		_error("%s: entry node '%s' does not exist" % [case_id, str(graph_data.get("entry", ""))])
	if graph_data.has("initial_choices"):
		var initial_id := str(graph_data.initial_choices)
		if not node_ids.has(initial_id) or not node_ids.get(initial_id, {}).has("choices"):
			_error("%s: initial_choices must name a choice node" % case_id)

	var outcomes: Dictionary = graph_data.get("outcomes", {})
	for outcome_id in outcomes.keys():
		var outcome: Dictionary = outcomes[outcome_id]
		var result := str(outcome.get("result", ""))
		if result not in ["release", "reject", "stay", "leave", "judged"]:
			_error("%s: outcome '%s' has invalid result '%s'" % [case_id, outcome_id, result])
		var ledger: Dictionary = outcome.get("ledger", {})
		if ledger.is_empty():
			_error("%s: outcome '%s' has no ledger" % [case_id, outcome_id])
		else:
			for field in ["who", "result", "note"]:
				if str(ledger.get(field, "")) == "":
					_error("%s: outcome '%s' ledger misses %s" % [case_id, outcome_id, field])
			for rule in ledger.get("who_if", []):
				if str(rule.get("who", "")) == "":
					_error("%s: outcome '%s' ledger who_if misses who" % [case_id, outcome_id])
				_check_condition(str(rule.get("if", "true")), case_flags, world_decl, "%s ledger who_if" % outcome_id)
			_check_text_key(str(ledger.get("note", "")), "%s ledger note" % outcome_id)
		_check_effects(outcome.get("effects", []), case_flags, world_decl, "%s outcome %s" % [case_id, outcome_id])
		var aftermath = outcome.get("aftermath", [])
		if typeof(aftermath) != TYPE_ARRAY:
			_error("%s: outcome '%s' aftermath must be an array" % [case_id, outcome_id])
		else:
			for key in aftermath:
				_check_text_key(str(key), "%s outcome %s aftermath" % [case_id, outcome_id])

	_check_effects(graph_data.get("canon", []), case_flags, world_decl, "%s canon" % case_id)
	_validate_potion(graph_data, node_ids, case_id)
	_validate_callout(graph_data, node_ids, case_id)
	_validate_speakers(graph_data, case_flags, world_decl, case_id)
	_validate_portrait(graph_data, case_flags, world_decl, case_id)
	_validate_nodes(graph_data, node_ids, outcomes, case_flags, world_decl, case_id)
	_validate_reachability(graph_data, node_ids, case_id)


func _validate_portrait(graph_data: Dictionary, case_flags: Dictionary, world_decl: Dictionary, case_id: String) -> void:
	if not graph_data.has("portrait"):
		return
	var portrait = graph_data.portrait
	if typeof(portrait) != TYPE_DICTIONARY:
		_error("%s: portrait must be an object" % case_id)
		return
	var default_id := str(portrait.get("default", ""))
	if not default_id.is_empty() and not CueCatalog.has_sprite(default_id):
		_error("%s: portrait default '%s' has no asset" % [case_id, default_id])
	for rule in portrait.get("rules", []):
		if typeof(rule) != TYPE_DICTIONARY:
			_error("%s: portrait rule must be an object" % case_id)
			continue
		var rule_id := str(rule.get("id", ""))
		if not CueCatalog.has_sprite(rule_id):
			_error("%s: portrait rule '%s' has no asset" % [case_id, rule_id])
		_check_condition(str(rule.get("if", "true")), case_flags, world_decl, "%s portrait" % case_id)


func _attach_cues(graph_data: Dictionary, case_id: String, case_text: Dictionary, world_decl: Dictionary) -> void:
	var path := narrative_dir.path_join("derived/cues").path_join("%s.cues.json" % case_id)
	if not FileAccess.file_exists(path):
		return
	var raw := _read_json(path)
	if raw.is_empty():
		_error("%s: cannot parse %s" % [case_id, path])
		return
	var case_flags: Dictionary = graph_data.get("state", {}).get("flags", {})
	var step_keys: Dictionary = {}
	for node in graph_data.get("nodes", []):
		for step in node.get("steps", []):
			step_keys[str(step.get("text", ""))] = true
	var attached_steps := 0
	var attached_cues := 0
	for key in raw.keys():
		var cue_key := str(key)
		if not case_text.has(cue_key):
			_error("%s: cue key '%s' has no prose" % [case_id, cue_key])
			continue
		var cues = raw[key]
		if typeof(cues) != TYPE_ARRAY:
			_error("%s: cue key '%s' must hold an array" % [case_id, cue_key])
			continue
		if cues.is_empty():
			_warn("%s: cue key '%s' has an empty array" % [case_id, cue_key])
			continue
		_validate_cues(cues, case_flags, world_decl, "%s cue %s" % [case_id, cue_key])
		if not step_keys.has(cue_key):
			_warn("%s: cue key '%s' is not used by a step" % [case_id, cue_key])
			continue
		for node in graph_data.get("nodes", []):
			for step in node.get("steps", []):
				if str(step.get("text", "")) != cue_key:
					continue
				step["cues"] = cues.duplicate(true)
		attached_steps += 1
		attached_cues += cues.size()
	cue_totals[case_id] = {"steps": attached_steps, "cues": attached_cues}


func _validate_cues(cues: Array, case_flags: Dictionary, world_decl: Dictionary, context: String) -> void:
	for index in cues.size():
		var raw = cues[index]
		var at := "%s[%d]" % [context, index]
		if typeof(raw) != TYPE_DICTIONARY:
			_error("%s: cue must be an object" % at)
			continue
		var cue: Dictionary = raw
		var cue_type := str(cue.get("type", ""))
		if not CueCatalog.has_type(cue_type):
			_error("%s: unknown type '%s'" % [at, cue_type])
			continue
		if cue.has("if"):
			if typeof(cue.if) != TYPE_STRING:
				_error("%s: if must be a string" % at)
			else:
				_check_condition(str(cue.if), case_flags, world_decl, at)
		if cue.has("wait") and typeof(cue.wait) != TYPE_BOOL:
			_error("%s: wait must be a bool" % at)
		if cue.has("target") and str(cue.target) not in ["shop", "screen", "stage"]:
			_error("%s: unknown target '%s'" % [at, str(cue.target)])
		_check_cue_number(cue, "delay", at, 0.0, CueCatalog.MAX_DELAY)
		_check_cue_number(cue, "duration", at, 0.0, CueCatalog.MAX_DURATION)
		match cue_type:
			"shake":
				_check_cue_number(cue, "strength", at, 0.0, 24.0)
			"flash":
				_check_cue_color(cue, at)
				_check_cue_number(cue, "alpha", at, 0.0, 1.0)
			"fade":
				_check_cue_color(cue, at)
				_check_cue_number(cue, "from", at, 0.0, 1.0)
				_check_cue_number(cue, "to", at, 0.0, 1.0)
			"zoom":
				_check_cue_number(cue, "scale", at, 0.5, 3.0)
			"prop":
				var prop_id := str(cue.get("id", ""))
				if not CueCatalog.has_prop(prop_id):
					_error("%s: undeclared prop '%s'" % [at, prop_id])
				var action := str(cue.get("action", "show"))
				if not CueCatalog.has_prop_action(action):
					_error("%s: unknown prop action '%s'" % [at, action])
				if cue.has("position"):
					var point = cue.position
					if typeof(point) != TYPE_ARRAY or point.size() != 2:
						_error("%s: position must be [x, y]" % at)
					elif typeof(point[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(point[1]) not in [TYPE_INT, TYPE_FLOAT]:
						_error("%s: position must be numeric" % at)
				_check_cue_number(cue, "scale", at, 0.1, 4.0)
			"sprite":
				var sprite_id := str(cue.get("id", ""))
				if not CueCatalog.has_sprite(sprite_id):
					_error("%s: sprite '%s' has no asset yet" % [at, sprite_id])
				if cue.has("pose") and typeof(cue.pose) != TYPE_STRING:
					_error("%s: pose must be a string" % at)
			"sound":
				var sound_id := str(cue.get("id", ""))
				if not CueCatalog.has_sound(sound_id):
					_error("%s: sound '%s' has no asset" % [at, sound_id])
			"wait":
				pass


func _check_cue_number(cue: Dictionary, field: String, context: String, low: float, high: float) -> void:
	if not cue.has(field):
		return
	var value = cue[field]
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		_error("%s: %s must be a number" % [context, field])
		return
	var number := float(value)
	if number < low or number > high:
		_error("%s: %s must be between %.2f and %.2f" % [context, field, low, high])


func _check_cue_color(cue: Dictionary, context: String) -> void:
	if not cue.has("color"):
		return
	if typeof(cue.color) != TYPE_STRING or not Color.html_is_valid(str(cue.color)):
		_error("%s: color must be #rrggbb or #rrggbbaa" % context)


func _validate_nodes(graph_data: Dictionary, node_ids: Dictionary, outcomes: Dictionary, case_flags: Dictionary, world_decl: Dictionary, case_id: String) -> void:
	var speakers: Dictionary = graph_data.get("speakers", {})
	for node in graph_data.get("nodes", []):
		var id := str(node.get("id", ""))
		var exits := 0
		var has_branch: bool = node.has("branch")
		if node.has("next") and not has_branch:
			exits += 1
			_check_node_ref(node.next, node_ids, "%s node '%s' next" % [case_id, id])
		if node.has("choices"):
			exits += 1
			_validate_choices(node, node_ids, case_flags, world_decl, case_id, speakers)
		if has_branch:
			exits += 1
			_validate_branch(node, node_ids, case_flags, world_decl, case_id)
		if node.has("outcome"):
			exits += 1
			if not outcomes.has(str(node.outcome)):
				_error("%s node '%s': unknown outcome '%s'" % [case_id, id, str(node.outcome)])
		if exits != 1:
			_error("%s node '%s' must have exactly one exit (found %d)" % [case_id, id, exits])
		_check_effects(node.get("set", []), case_flags, world_decl, "%s node %s set" % [case_id, id])
		_validate_judgment(node, case_flags, case_id)
		for step in node.get("steps", []):
			_check_text_key(str(step.get("text", "")), "%s node %s step" % [case_id, id])
			if step.has("if"):
				_check_condition(str(step.if), case_flags, world_decl, "%s node %s step" % [case_id, id])
			var speaker := str(step.get("speaker", ""))
			if speaker != "" and not speakers.has(speaker):
				_error("%s node '%s': undeclared speaker '%s'" % [case_id, id, speaker])


func _validate_judgment(node: Dictionary, case_flags: Dictionary, case_id: String) -> void:
	if not node.has("judgment"):
		return
	if node.has("choices"):
		_error("%s node '%s': judgment cannot share a node with choices" % [case_id, str(node.get("id", ""))])
	var raw = node.get("judgment")
	if typeof(raw) != TYPE_DICTIONARY:
		_error("%s node '%s': judgment must be an object" % [case_id, str(node.get("id", ""))])
		return
	var config: Dictionary = raw
	if not config.has("min") or typeof(config.get("min")) not in [TYPE_INT, TYPE_FLOAT]:
		_error("%s node '%s': judgment needs a numeric min" % [case_id, str(node.get("id", ""))])
	_check_text_key(str(config.get("prompt", "")), "%s node %s judgment prompt" % [case_id, str(node.get("id", ""))])
	if not node.has("branch") and not node.has("next"):
		_error("%s node '%s': judgment needs a branch or next" % [case_id, str(node.get("id", ""))])


func _validate_choices(node: Dictionary, node_ids: Dictionary, case_flags: Dictionary, world_decl: Dictionary, case_id: String, speakers: Dictionary) -> void:
	var node_id := str(node.get("id", ""))
	var choices: Array = node.get("choices", [])
	if choices.is_empty():
		_error("%s node '%s': choices is empty" % [case_id, node_id])
		return
	var unconditional := 0
	var choice_ids: Dictionary = {}
	for choice in choices:
		var choice_id := str(choice.get("id", ""))
		if choice_id == "":
			_error("%s node '%s': choice without id" % [case_id, node_id])
		if choice_ids.has(choice_id):
			_error("%s node '%s': duplicate choice '%s'" % [case_id, node_id, choice_id])
		choice_ids[choice_id] = true
		if choice.has("kind") and str(choice.kind) not in ["accept", "refuse"]:
			_error("%s node '%s': choice '%s' has invalid kind '%s'" % [case_id, node_id, choice_id, str(choice.kind)])
		_check_text_key(str(choice.get("text", "")), "%s choice %s" % [case_id, choice_id])
		_check_node_ref(choice.get("next", ""), node_ids, "%s choice %s next" % [case_id, choice_id])
		_check_effects(choice.get("set", []), case_flags, world_decl, "%s choice %s set" % [case_id, choice_id])
		if choice.has("if"):
			_check_condition(str(choice.if), case_flags, world_decl, "%s choice %s" % [case_id, choice_id])
		else:
			unconditional += 1
		if choice.has("locked_if"):
			_check_condition(str(choice.locked_if), case_flags, world_decl, "%s choice %s locked" % [case_id, choice_id])
		if choice.has("locked_text"):
			_check_text_key(str(choice.locked_text), "%s choice %s locked text" % [case_id, choice_id])
		if not choice.has("kind"):
			_check_hotspot(choice, case_id, choice_id)
	if unconditional == 0:
		_error("%s node '%s': no unconditional choice (player can be stuck)" % [case_id, node_id])


func _check_hotspot(choice: Dictionary, case_id: String, choice_id: String) -> void:
	if not choice.has("hotspot"):
		_error("%s choice %s: missing hotspot" % [case_id, choice_id])
		return
	var hotspot = choice.get("hotspot")
	if typeof(hotspot) != TYPE_DICTIONARY:
		_error("%s choice %s: hotspot must be an object" % [case_id, choice_id])
		return
	_check_hotspot_rects(hotspot.get("rects", []), case_id, choice_id, "hotspot")
	var variants = hotspot.get("variants", {})
	if typeof(variants) != TYPE_DICTIONARY:
		_error("%s choice %s: hotspot variants must be an object" % [case_id, choice_id])
		return
	for key in variants:
		_check_hotspot_rects(variants[key], case_id, choice_id, "hotspot variant %s" % str(key))


func _check_hotspot_rects(rects, case_id: String, choice_id: String, label: String) -> void:
	if typeof(rects) != TYPE_ARRAY or rects.is_empty():
		_error("%s choice %s: %s needs a non-empty rects array" % [case_id, choice_id, label])
		return
	for index in rects.size():
		var raw = rects[index]
		if typeof(raw) != TYPE_ARRAY or raw.size() != 4:
			_error("%s choice %s: %s rect %d needs 4 numbers" % [case_id, choice_id, label, index])
			continue
		var x := float(raw[0])
		var y := float(raw[1])
		var w := float(raw[2])
		var h := float(raw[3])
		if w <= 0.0 or h <= 0.0 or x < 0.0 or y < 0.0 or x + w > 48.0 or y + h > 64.0:
			_error("%s choice %s: %s rect %d is outside the 48x64 portrait" % [case_id, choice_id, label, index])


func _validate_branch(node: Dictionary, node_ids: Dictionary, case_flags: Dictionary, world_decl: Dictionary, case_id: String) -> void:
	var node_id := str(node.get("id", ""))
	var branches: Array = node.get("branch", [])
	if branches.is_empty():
		_error("%s node '%s': branch is empty" % [case_id, node_id])
	var fallbacks := 0
	for entry in branches:
		if entry.has("if"):
			_check_condition(str(entry.if), case_flags, world_decl, "%s node %s branch" % [case_id, node_id])
		else:
			fallbacks += 1
		_check_node_ref(entry.get("next", ""), node_ids, "%s node %s branch next" % [case_id, node_id])
		_check_effects(entry.get("set", []), case_flags, world_decl, "%s node %s branch set" % [case_id, node_id])
	if fallbacks == 0 and not node.has("next"):
		_error("%s node '%s': branch has no fallback" % [case_id, node_id])


func _validate_potion(graph_data: Dictionary, node_ids: Dictionary, case_id: String) -> void:
	if not graph_data.has("potion"):
		return
	var potion: Dictionary = graph_data.get("potion", {})
	var node := str(potion.get("node", ""))
	if not node_ids.has(node):
		_error("%s: potion node '%s' does not exist" % [case_id, node])
	var score: Dictionary = potion.get("score", {})
	if score.is_empty():
		_error("%s: potion has no score coefficients" % case_id)
	for key in ["wisdom", "emotion", "will"]:
		if not score.has(key) or typeof(score[key]) not in [TYPE_INT, TYPE_FLOAT]:
			_error("%s: potion score misses numeric %s" % [case_id, key])
	if potion.has("score_name"):
		if typeof(potion.score_name) != TYPE_STRING or str(potion.score_name).strip_edges() == "":
			_error("%s: potion score_name must be a non-empty string" % case_id)


func _validate_speakers(graph_data: Dictionary, case_flags: Dictionary, world_decl: Dictionary, case_id: String) -> void:
	for key in graph_data.get("speakers", {}).keys():
		var speaker: Dictionary = graph_data.speakers[key]
		if str(speaker.get("name", "")).strip_edges() == "":
			_error("%s: speaker '%s' has no name" % [case_id, str(key)])
		for rule in speaker.get("name_if", []):
			if str(rule.get("name", "")).strip_edges() == "":
				_error("%s: speaker '%s' name_if has no name" % [case_id, str(key)])
			_check_condition(str(rule.get("if", "true")), case_flags, world_decl, "%s speaker %s" % [case_id, str(key)])


func _validate_callout(graph_data: Dictionary, node_ids: Dictionary, case_id: String) -> void:
	if not graph_data.has("callout"):
		return
	var callout: Dictionary = graph_data.get("callout", {})
	var answer := str(callout.get("answer", ""))
	var answers: Array = callout.get("answers", [])
	if answer == "" and answers.is_empty():
		_error("%s: callout has no answer" % case_id)
	for item in answers:
		if str(item) == "":
			_error("%s: callout has an empty answer" % case_id)
	if callout.has("prompt"):
		_check_text_key(str(callout.prompt), "%s callout prompt" % case_id)
	if callout.has("button"):
		_check_text_key(str(callout.button), "%s callout button" % case_id)
	_check_node_ref(callout.get("success", ""), node_ids, "%s callout success" % case_id)
	_check_node_ref(callout.get("failure", ""), node_ids, "%s callout failure" % case_id)
	if callout.has("time_limit") and typeof(callout.time_limit) not in [TYPE_INT, TYPE_FLOAT]:
		_error("%s: callout time_limit must be numeric" % case_id)
	if callout.has("case_sensitive") and typeof(callout.case_sensitive) != TYPE_BOOL:
		_error("%s: callout case_sensitive must be bool" % case_id)
	if callout.has("once") and typeof(callout.once) != TYPE_BOOL:
		_error("%s: callout once must be bool" % case_id)


func _validate_reachability(graph_data: Dictionary, node_ids: Dictionary, case_id: String) -> void:
	var entry := str(graph_data.get("entry", ""))
	var seen: Dictionary = {}
	var queue: Array = [entry]
	if graph_data.has("potion"):
		queue.append(str(graph_data.get("potion", {}).get("node", "")))
	if graph_data.has("callout"):
		queue.append(str(graph_data.get("callout", {}).get("success", "")))
		queue.append(str(graph_data.get("callout", {}).get("failure", "")))
	while not queue.is_empty():
		var id := str(queue.pop_front())
		if seen.has(id) or not node_ids.has(id):
			continue
		seen[id] = true
		var node: Dictionary = node_ids[id]
		if node.has("next"):
			queue.append(str(node.next))
		for choice in node.get("choices", []):
			queue.append(str(choice.get("next", "")))
		for entry_branch in node.get("branch", []):
			queue.append(str(entry_branch.get("next", "")))
	for id in node_ids.keys():
		if not seen.has(id):
			_error("%s: node '%s' is unreachable from entry" % [case_id, id])


func _validate_schedule(schedule_data: Dictionary, case_ids: Array, world_decl: Dictionary) -> void:
	var slots: Array = schedule_data.get("slots", [])
	var used: Dictionary = {}
	for entry in slots:
		var day := int(entry.get("day", 0))
		var slot := int(entry.get("slot", -1))
		var case_id := str(entry.get("case", ""))
		if day < 1 or day > 5:
			_error("schedule: day %d out of range" % day)
		if slot < 0 or slot > 5:
			_error("schedule: slot %d out of range" % slot)
		if not case_ids.has(case_id):
			_error("schedule: unknown case '%s'" % case_id)
		var key := "%d:%d" % [day, slot]
		if used.has(key):
			_error("schedule: duplicate day %d slot %d" % [day, slot])
		used[key] = true


func _validate_endings(endings_data: Dictionary, world_decl: Dictionary, compiled: Dictionary) -> void:
	var endings: Array = endings_data.get("endings", [])
	var ids: Dictionary = {}
	for ending in endings:
		var id := str(ending.get("id", ""))
		if id == "":
			_error("ending without id")
			continue
		if ids.has(id):
			_error("duplicate ending '%s'" % id)
		ids[id] = true
		_check_condition(str(ending.get("if", "true")), {}, world_decl, "ending %s" % id)
		var text_value: Variant = ending.get("text", "")
		if text_value is Array:
			for key in text_value:
				_check_text_key(str(key), "ending %s" % id)
		elif str(text_value) != "":
			_check_text_key(str(text_value), "ending %s" % id)
		for extra in ending.get("epilogue", []):
			_check_condition(str(extra.get("if", "true")), {}, world_decl, "ending %s epilogue" % id)
			_check_text_key(str(extra.get("text", "")), "ending %s epilogue" % id)
	for ending in endings:
		_check_case_refs(str(ending.get("if", "true")), compiled)
		for extra in ending.get("epilogue", []):
			_check_case_refs(str(extra.get("if", "true")), compiled)
	var has_fallback := false
	for ending in endings:
		if str(ending.get("if", "true")).strip_edges() == "true":
			has_fallback = true
	if not has_fallback:
		_warn("no unconditional fallback ending")


func _check_case_refs(expression: String, compiled: Dictionary) -> void:
	for name in Expr.identifiers(expression):
		if not name.begins_with("case."):
			continue
		var parts := name.split(".")
		if parts.size() >= 3 and not compiled.has(parts[1]):
			_error("condition references unknown case '%s'" % parts[1])


func _check_node_ref(value: Variant, node_ids: Dictionary, context: String) -> void:
	var id := str(value)
	if id == "" or not node_ids.has(id):
		_error("%s: unknown node '%s'" % [context, id])


func _check_text_key(key: String, context: String) -> void:
	if key == "":
		_error("%s: empty text key" % context)
	elif not text_map.has(key):
		_error("%s: missing text key '%s'" % [context, key])
	else:
		used_keys[key] = true


func _check_condition(expression: String, case_flags: Dictionary, world_decl: Dictionary, context: String) -> void:
	if expression.strip_edges() == "":
		_error("%s: empty condition" % context)
		return
	var sample := _sample_context(case_flags, world_decl)
	for name in Expr.identifiers(expression):
		if sample.has(name):
			continue
		if name.begins_with("case.") or name.begins_with("run.") or name.begins_with("dose."):
			sample[name] = 0
		elif name.begins_with("world."):
			_error("%s: undeclared world flag '%s'" % [context, name])
			sample[name] = 0
		else:
			_error("%s: undeclared flag '%s'" % [context, name])
	Expr.eval(expression, sample)
	if Expr.last_error != "":
		_error("%s: condition '%s': %s" % [context, expression, Expr.last_error])


func _check_effects(effects: Array, case_flags: Dictionary, world_decl: Dictionary, context: String) -> void:
	var sample := _sample_context(case_flags, world_decl)
	for effect in effects:
		var statement := str(effect)
		var target := _effect_target(statement)
		if target == "":
			_error("%s: invalid effect '%s'" % [context, statement])
			continue
		if target.begins_with("world."):
			if not world_decl.has(target):
				_error("%s: undeclared world flag '%s'" % [context, target])
		elif not target.begins_with("run.") and not target.begins_with("case.") and not case_flags.has(target):
			_error("%s: undeclared effect target '%s'" % [context, target])
		if not Expr.assign(statement, sample):
			_error("%s: effect '%s': %s" % [context, statement, Expr.last_error])


func _effect_target(statement: String) -> String:
	var text := statement.strip_edges()
	var index := text.find("+=")
	if index < 0:
		index = text.find("-=")
	if index < 0:
		index = text.find("=")
	if index <= 0:
		return ""
	return text.substr(0, index).strip_edges()


func _sample_context(case_flags: Dictionary, world_decl: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	for key in world_decl.keys():
		values[str(key)] = _default_value(world_decl[key])
	for key in case_flags.keys():
		values[str(key)] = _default_value(case_flags[key])
	values["dose.score"] = 0
	values["dose.fed"] = false
	values["dose.label"] = ""
	return values


func _default_value(declaration: Dictionary) -> Variant:
	var value: Variant = declaration.get("default", 0)
	match str(declaration.get("type", "")):
		"int":
			return int(value)
		"bool":
			return bool(value)
		"string":
			return str(value)
	return value


func _speaker_key(name: String, speakers: Dictionary) -> String:
	if speakers.has(name):
		return name
	for key in speakers.keys():
		var speaker: Dictionary = speakers[key]
		if str(speaker.get("name", "")) == name:
			return str(key)
		for rule in speaker.get("name_if", []):
			if str(rule.get("name", "")) == name:
				return str(key)
	return ""


func _write_outputs(compiled: Dictionary, case_ids: Array, world_data: Dictionary, schedule_data: Dictionary, endings_data: Dictionary) -> void:
	var cases_dir := out_dir.path_join("cases")
	DirAccess.make_dir_recursive_absolute(cases_dir)
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("text"))
	for case_id in case_ids:
		_write_json(cases_dir.path_join("%s.json" % case_id), compiled[case_id])
	_write_json(out_dir.path_join("text/zh.json"), text_map)
	_write_json(out_dir.path_join("world.json"), world_data)
	_write_json(out_dir.path_join("schedule.json"), schedule_data)
	_write_json(out_dir.path_join("endings.json"), endings_data)
	var manifest := {
		"cases": case_ids,
		"text": "res://data/story/text/zh.json",
		"world": "res://data/story/world.json",
		"schedule": "res://data/story/schedule.json",
		"endings": "res://data/story/endings.json",
	}
	_write_json(out_dir.path_join("manifest.json"), manifest)


func _write_report(compiled: Dictionary, case_ids: Array, world_decl: Dictionary, endings_data: Dictionary) -> void:
	var lines: Array = []
	lines.append("# 剧情构建报告")
	lines.append("")
	lines.append("- 案例：%s" % ", ".join(case_ids))
	lines.append("- 文本 key：%d" % text_map.size())
	var total_chars := 0
	for key in text_map.keys():
		total_chars += str(text_map[key]).length()
	lines.append("- 正文总字数：%d" % total_chars)
	for case_id in case_ids:
		var case_chars := 0
		for key in text_map.keys():
			if str(key).begins_with(str(case_id) + "."):
				case_chars += str(text_map[key]).length()
		lines.append("  - %s：%d 字" % [case_id, case_chars])
		var cues: Dictionary = cue_totals.get(str(case_id), {})
		lines.append("    演出 cue：%d 个 step，%d 条" % [int(cues.get("steps", 0)), int(cues.get("cues", 0))])
	lines.append("- 世界 flag：%d" % world_decl.size())
	lines.append("- 整局结局：%d" % endings_data.get("endings", []).size())
	lines.append("")
	if warnings.is_empty():
		lines.append("- 警告：无")
	else:
		lines.append("## 警告")
		for message in warnings:
			lines.append("- " + message)
	lines.append("")
	if errors.is_empty():
		lines.append("- 错误：无")
	else:
		lines.append("## 错误")
		for message in errors:
			lines.append("- " + message)
	var path := narrative_dir.path_join("derived/story_build_report.md")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("cannot write %s" % path)
		return
	file.store_string(JSON.stringify(data, "  ", true) + "\n")


func _error(message: String) -> void:
	errors.append(message)


func _warn(message: String) -> void:
	warnings.append(message)
