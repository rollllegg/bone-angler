extends SceneTree
## Enumerates story paths, clusters outcomes and writes a review report.
## Run: godot --headless --path game --script res://tools/story_sim.gd

const DB := preload("res://scripts/story/story_db.gd")
const Runtime := preload("res://scripts/story/story_runtime.gd")
const State := preload("res://scripts/story/story_state.gd")

const POTION_LABELS := {"positive": "药:正", "negative": "药:负", "zero": "药:零"}

var _case_results: Dictionary = {}
var _case_outcomes: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var db = DB.new()
	if not db.load_all():
		printerr("StorySim: cannot load story DB")
		quit(1)
		return
	for case_id in db.cases.keys():
		var id := str(case_id)
		var data: Dictionary = db.get_case(id)
		var results: Array = []
		var seen: Dictionary = {}
		for rampage in [false, true]:
			var state = State.new()
			state.init_defaults(db.world_decl)
			state.world["world.hades_rampage"] = rampage
			var runtime = Runtime.new()
			runtime.setup(data, db.text, state)
			runtime.start()
			_walk(runtime, [], true, true, rampage, results, seen)
		_case_results[id] = results
		_case_outcomes[id] = seen
		var missing: Array = []
		for outcome in data.get("outcomes", {}).keys():
			if not seen.has(str(outcome)):
				missing.append(str(outcome))
		if not missing.is_empty():
			printerr("StorySim: %s missing outcomes: %s" % [id, ", ".join(missing)])
			quit(1)
			return
	_write_report(db)
	_write_csv()
	print("StorySim: %d case(s), reports written to narrative/derived/" % db.cases.size())
	quit(0)


func _walk(runtime, path: Array, allow_potion: bool, allow_callout: bool, world_rampage: bool, results: Array, seen: Dictionary) -> void:
	_settle(runtime)
	if runtime.is_closed():
		results.append({
			"path": path.duplicate(),
			"outcome": runtime.get_outcome_id(),
			"named": bool(runtime.flags.get("named", false)),
			"confused": bool(runtime.flags.get("confused", false)),
			"rage": bool(runtime.flags.get("rage", false)),
			"dose": int(runtime.flags.get("dose.score", 0)),
			"world_rampage": world_rampage,
		})
		seen[runtime.get_outcome_id()] = true
		return
	if path.size() > 60:
		return
	if allow_potion and runtime.can_feed_potion():
		var coefficients: Dictionary = runtime.case_data.get("potion", {}).get("score", {})
		for mode in ["positive", "negative", "zero"]:
			var clone = _clone(runtime)
			if not clone.feed_potion(_effect_for(coefficients, mode), POTION_LABELS[mode]):
				continue
			_walk(clone, path + [POTION_LABELS[mode]], false, false, world_rampage, results, seen)
	if allow_callout and runtime.can_callout():
		var named = _clone(runtime)
		named.start_callout()
		named.resolve_callout(true)
		_walk(named, path + ["叫破:成功"], false, false, world_rampage, results, seen)
		var missed = _clone(runtime)
		missed.start_callout()
		missed.resolve_callout(false)
		_walk(missed, path + ["叫破:失败"], false, false, world_rampage, results, seen)
		allow_callout = false
	for choice in runtime.visible_choices():
		if bool(choice.get("locked", false)):
			continue
		var clone = _clone(runtime)
		var choice_id := str(choice.get("id", ""))
		if not clone.choose(choice_id):
			continue
		_walk(clone, path + [choice_id], false, false, world_rampage, results, seen)


func _effect_for(coefficients: Dictionary, mode: String) -> Vector3i:
	var c := Vector3i(
		int(coefficients.get("wisdom", 0)),
		int(coefficients.get("emotion", 0)),
		int(coefficients.get("will", 0))
	)
	for x in range(-4, 5):
		for y in range(-4, 5):
			for z in range(-4, 5):
				var effect := Vector3i(x, y, z)
				if effect == Vector3i.ZERO:
					continue
				var score := effect.x * c.x + effect.y * c.y + effect.z * c.z
				if mode == "positive" and score > 0:
					return effect
				if mode == "negative" and score < 0:
					return effect
				if mode == "zero" and score == 0:
					return effect
	return Vector3i.ZERO


func _clone(runtime):
	var state = runtime.shared.duplicate_state()
	var clone = Runtime.new()
	clone.setup(runtime.case_data, runtime.text_db, state)
	clone.restore(runtime.snapshot())
	return clone


func _settle(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 60:
		if not runtime.advance():
			break
		guard += 1


func _write_report(db) -> void:
	var lines: Array = []
	lines.append("# 剧情模拟报告")
	lines.append("")
	lines.append("- 案例：%s" % ", ".join(db.cases.keys()))
	lines.append("- 世界预设：`world.hades_rampage` 为 false 和 true 各跑一遍。")
	lines.append("- 抽样说明：药按正/负/零各抽样一次，叫破按成功/失败各抽样一次；用于验证可达性，不是完整组合数。")
	for case_id in db.cases.keys():
		var id := str(case_id)
		var data: Dictionary = db.get_case(id)
		var results: Array = _case_results.get(id, [])
		var counts: Dictionary = {}
		var named := 0
		var confused := 0
		var raged := 0
		var choice_counts: Dictionary = {}
		for result in results:
			counts[result.outcome] = int(counts.get(result.outcome, 0)) + 1
			named += int(result.named)
			confused += int(result.confused)
			raged += int(result.rage)
			for step in result.path:
				var text := str(step)
				if text.begins_with("药:") or text.begins_with("叫破:") or text.begins_with("世界:"):
					continue
				choice_counts[text] = int(choice_counts.get(text, 0)) + 1
		lines.append("")
		lines.append("## %s" % id)
		lines.append("")
		lines.append("- 终端路径：%d" % results.size())
		var cue_steps := 0
		var cue_count := 0
		var total_steps := 0
		for node in data.get("nodes", []):
			for step in node.get("steps", []):
				total_steps += 1
				var cues: Array = step.get("cues", [])
				if not cues.is_empty():
					cue_steps += 1
					cue_count += cues.size()
		lines.append("- 演出覆盖：%d / %d 个 step，%d 条 cue" % [cue_steps, total_steps, cue_count])
		var flags: Dictionary = data.get("state", {}).get("flags", {})
		if flags.has("named"):
			lines.append("- 叫破身份：%d / %d" % [named, results.size()])
		if flags.has("confused"):
			lines.append("- 迷茫为正：%d / %d" % [confused, results.size()])
		if flags.has("rage"):
			lines.append("- 大闹冥府：%d / %d" % [raged, results.size()])
		lines.append("")
		lines.append("### 结局分布")
		lines.append("")
		lines.append("| 结局 | 路径数 |")
		lines.append("| --- | ---: |")
		var outcome_ids: Array = counts.keys()
		outcome_ids.sort()
		for outcome in outcome_ids:
			lines.append("| %s | %d |" % [outcome, counts[outcome]])
		lines.append("")
		lines.append("### 选项覆盖")
		lines.append("")
		lines.append("| 选择 | 出现次数 |")
		lines.append("| --- | ---: |")
		var choice_ids: Array = choice_counts.keys()
		choice_ids.sort()
		for choice in choice_ids:
			lines.append("| %s | %d |" % [choice, choice_counts[choice]])
	var absolute := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var report_dir := absolute.path_join("narrative/derived")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file := FileAccess.open(report_dir.path_join("simulation_report.md"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")


func _write_csv() -> void:
	var absolute := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var report_dir := absolute.path_join("narrative/derived")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var csv := FileAccess.open(report_dir.path_join("combinations.csv"), FileAccess.WRITE)
	if csv == null:
		return
	csv.store_string("case,world_rampage,path,outcome,named,confused,rage,dose_score\n")
	for case_id in _case_results.keys():
		for result in _case_results[case_id]:
			var path_text := " > ".join(result.path)
			csv.store_string("%s,%s,%s,%s,%s,%s,%s,%d\n" % [
				str(case_id),
				str(result.world_rampage),
				path_text,
				str(result.outcome),
				str(result.named),
				str(result.confused),
				str(result.rage),
				int(result.dose),
			])
