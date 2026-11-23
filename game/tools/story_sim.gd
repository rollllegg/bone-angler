extends SceneTree
## Enumerates story paths, clusters outcomes and writes a review report.
## Run: godot --headless --path game --script res://tools/story_sim.gd

const DB := preload("res://scripts/story/story_db.gd")
const Runtime := preload("res://scripts/story/story_runtime.gd")
const State := preload("res://scripts/story/story_state.gd")

var _results: Array = []
var _seen_outcomes: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var db = DB.new()
	if not db.load_all():
		printerr("StorySim: cannot load story DB")
		quit(1)
		return
	for case_id in db.cases.keys():
		_results.clear()
		_seen_outcomes.clear()
		var data: Dictionary = db.get_case(str(case_id))
		var state = State.new()
		state.init_defaults(db.world_decl)
		var runtime = Runtime.new()
		runtime.setup(data, db.text, state)
		runtime.start()
		_walk(runtime, [], true, true)
		_write_report(str(case_id), data)
		var expected: Array = data.get("outcomes", {}).keys()
		var missing: Array = []
		for outcome in expected:
			if not _seen_outcomes.has(str(outcome)):
				missing.append(str(outcome))
		if not missing.is_empty():
			printerr("StorySim: %s missing outcomes: %s" % [case_id, ", ".join(missing)])
			quit(1)
			return
	print("StorySim: reports written to narrative/derived/")
	quit(0)


func _walk(runtime, path: Array, allow_potion: bool, allow_callout: bool) -> void:
	_settle(runtime)
	if runtime.is_closed():
		_results.append({
			"path": path.duplicate(),
			"outcome": runtime.get_outcome_id(),
			"named": bool(runtime.flags.get("named", false)),
			"rage": bool(runtime.flags.get("rage", true)),
			"dose": int(runtime.flags.get("dose.score", 0)),
		})
		_seen_outcomes[runtime.get_outcome_id()] = true
		return
	if path.size() > 40:
		return
	if allow_potion and runtime.can_feed_potion():
		var calm = _clone(runtime)
		calm.feed_potion(Vector3i(10, 0, -4), "极识药")
		_walk(calm, path + ["药:极识"], false, false)
		var hot = _clone(runtime)
		hot.feed_potion(Vector3i(0, 4, 0), "暖心药")
		_walk(hot, path + ["药:暖心"], false, false)
		var zero = _clone(runtime)
		zero.feed_potion(Vector3i(1, 0, 1), "灰鳞原液")
		_walk(zero, path + ["药:灰鳞"], false, false)
	if allow_callout and runtime.can_callout():
		var named = _clone(runtime)
		named.start_callout()
		named.resolve_callout(true)
		_walk(named, path + ["叫破:成功"], false, false)
		var missed = _clone(runtime)
		missed.start_callout()
		missed.resolve_callout(false)
		_walk(missed, path + ["叫破:失败"], false, false)
		allow_callout = false
	var choices: Array = runtime.visible_choices()
	for choice in choices:
		if bool(choice.get("locked", false)):
			continue
		var clone = _clone(runtime)
		var choice_id := str(choice.get("id", ""))
		if not clone.choose(choice_id):
			continue
		_walk(clone, path + [choice_id], false, false)


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


func _write_report(case_id: String, data: Dictionary) -> void:
	var counts: Dictionary = {}
	var named := 0
	var raged := 0
	var choice_counts: Dictionary = {}
	for result in _results:
		counts[result.outcome] = int(counts.get(result.outcome, 0)) + 1
		named += int(result.named)
		raged += int(result.rage)
		for step in result.path:
			if str(step).begins_with("药:") or str(step).begins_with("叫破:"):
				continue
			choice_counts[step] = int(choice_counts.get(step, 0)) + 1
	var lines: Array = []
	lines.append("# 剧情模拟报告 · %s" % case_id)
	lines.append("")
	lines.append("- 终端路径：%d" % _results.size())
	lines.append("- 抽样说明：药和叫破只在第一次接待时各抽样一次，用于验证可达性，不是完整组合数。")
	lines.append("- 叫破身份：%d / %d" % [named, _results.size()])
	lines.append("- 大闹冥府：%d / %d" % [raged, _results.size()])
	lines.append("")
	lines.append("## 结局分布")
	lines.append("")
	lines.append("| 结局 | 路径数 |")
	lines.append("| --- | ---: |")
	var outcome_ids: Array = counts.keys()
	outcome_ids.sort()
	for outcome in outcome_ids:
		lines.append("| %s | %d |" % [outcome, counts[outcome]])
	lines.append("")
	lines.append("## 选项覆盖")
	lines.append("")
	lines.append("| 选择 | 出现次数 |")
	lines.append("| --- | ---: |")
	var choice_ids: Array = choice_counts.keys()
	choice_ids.sort()
	for choice in choice_ids:
		lines.append("| %s | %d |" % [choice, choice_counts[choice]])
	lines.append("")
	var absolute := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var report_dir := absolute.path_join("narrative/derived")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file := FileAccess.open(report_dir.path_join("simulation_report.md"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
	var csv := FileAccess.open(report_dir.path_join("combinations.csv"), FileAccess.WRITE)
	if csv != null:
		csv.store_string("path,outcome,named,rage,dose_score\n")
		for result in _results:
			var path_text := " > ".join(result.path)
			csv.store_string("%s,%s,%s,%s,%d\n" % [path_text, result.outcome, str(result.named), str(result.rage), result.dose])
