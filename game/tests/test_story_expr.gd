extends SceneTree
## Headless checks for the story expression evaluator.

const Expr := preload("res://scripts/story/story_expr.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := {
		"clue.photo": 1,
		"clue.tail": 0,
		"named": false,
		"hp": 10,
		"world.hades": 2,
		"label": "smith",
	}
	_check(Expr.eval("1 + 2 * 3 == 7", flags) == true, "arithmetic precedence")
	_check(Expr.eval("(1 + 2) * 3 == 9", flags) == true, "parentheses")
	_check(Expr.eval("clue.photo == 1 and not named", flags) == true, "boolean logic")
	_check(Expr.eval("clue.photo == 1 && !named", flags) == true, "C-style boolean aliases")
	_check(Expr.eval("clue.photo == 0 || hp == 10", flags) == true, "C-style or alias")
	_check(Expr.eval("clue.photo + clue.tail >= 1", flags) == true, "flag arithmetic")
	_check(Expr.eval("hp > 5 or named", flags) == true, "or")
	_check(Expr.eval("not (hp < 5)", flags) == true, "not")
	_check(Expr.eval("label == 'smith'", flags) == true, "string compare")
	_check(Expr.eval("world.hades == 2", flags) == true, "dotted flag")
	_check(Expr.eval("hp % 3 == 1", flags) == true, "modulo")

	_check(Expr.assign("hp += 2", flags) and flags["hp"] == 12, "compound add")
	_check(Expr.assign("clue.photo = 0", flags) and flags["clue.photo"] == 0, "assign")
	_check(not Expr.assign("1x = 2", flags), "invalid target is rejected")

	_check(Expr.eval("missing_flag == 1", flags) == null and Expr.last_error != "", "unknown flag reports error")
	_check(Expr.eval("1 +", flags) == null and Expr.last_error != "", "syntax error reports error")

	var names := Expr.identifiers("clue.photo + clue.tail >= 2 and not named")
	_check(names.has("clue.photo") and names.has("clue.tail") and names.has("named"), "identifier extraction")
	_check(not names.has("and") and not names.has("not"), "keywords excluded")

	if _failures == 0:
		print("StoryExpr: %d checks, 0 failures" % _checks)
	else:
		print("StoryExpr: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
