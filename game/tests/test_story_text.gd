extends SceneTree
## Headless checks for inline conditional story text.

const TextDB := preload("res://scripts/story/story_text.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var text = TextDB.new()
	_check(text.render("A{{if named}}B{{/if}}C", {"named": true}) == "ABC", "inline if keeps the true branch")
	_check(text.render("A{{if named}}B{{/if}}C", {"named": false}) == "AC", "inline if drops the false branch")
	_check(text.render("A{{if named}}B{{else}}C{{/if}}D", {"named": true}) == "ABD", "else picks the true branch")
	_check(text.render("A{{if named}}B{{else}}C{{/if}}D", {"named": false}) == "ACD", "else picks the false branch")
	_check(text.render("A{{if named}}B{{if rage}}C{{else}}D{{/if}}E{{else}}F{{/if}}G", {"named": true, "rage": true}) == "ABCEG", "nested true branches")
	_check(text.render("A{{if named}}B{{if rage}}C{{else}}D{{/if}}E{{else}}F{{/if}}G", {"named": true, "rage": false}) == "ABDEG", "nested else branch")
	_check(text.render("A{{if named}}B{{if rage}}C{{else}}D{{/if}}E{{else}}F{{/if}}G", {"named": false}) == "AFG", "outer false branch skips nested text")
	_check(text.render("{{if !named}}A{{/if}}{{if named}}B{{/if}}", {"named": true}) == "B", "not and repeated tags render")
	_check(text.render("{{if world.hades_rampage}}闹{{else}}静{{/if}}", {"world.hades_rampage": true}) == "闹", "world flag condition works")
	_check(text.render("{{if missing}}A{{else}}B{{/if}}", {}) == "B", "unknown flag falls back to the false branch")
	_check(text.render("plain", {}) == "plain", "text without tags is unchanged")

	_check(text.structure_error("A{{if named}}B{{/if}}C") == "", "balanced inline if is valid")
	_check(text.structure_error("A{{if named}}B") != "", "missing close is reported")
	_check(text.structure_error("A{{/if}}") != "", "stray close is reported")
	_check(text.structure_error("A{{else}}B") != "", "stray else is reported")
	_check(text.structure_error("A{{if }}B{{/if}}") != "", "empty condition is reported")
	var conditions: PackedStringArray = text.extract_conditions("{{if named}}A{{/if}}{{if world.hades_rampage}}B{{/if}}{{if named}}C{{/if}}")
	_check(conditions.size() == 2 and conditions[0] == "named" and conditions[1] == "world.hades_rampage", "conditions are extracted once")

	text.entries = {"known": "hello {{if named}}you{{/if}}"}
	_check(text.get_text("known") == "hello {{if named}}you{{/if}}", "get_text returns the raw template")
	_check(text.get_text("unknown").contains("缺失"), "missing keys stay visible")

	if _failures == 0:
		print("StoryText: %d checks, 0 failures" % _checks)
	else:
		print("StoryText: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
