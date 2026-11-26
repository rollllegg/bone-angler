extends SceneTree
## Exercises Anubis' final hearing and the soul-coin scale in the real UI.

const Data := preload("res://scripts/systems/playtest_data.gd")

var _demo
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1620, 972)
	_demo = preload("res://scenes/demo/demo.tscn").instantiate()
	root.add_child(_demo)
	_demo.persist_save = false
	_demo.auto_pause_on_focus_loss = false
	_demo.session.set_process(false)
	_demo.shop.set_process(false)
	_demo._start_game()
	var session = _demo.session
	session._open_day(5)
	session.advance(6.0 * Data.ARRIVAL_MAX + 1.0)
	_check(session.souls.size() == 6, "Day five opens with six guests")
	var anubis: Dictionary = {}
	for soul in session.souls:
		if str(soul.get("story_case", "")) == "anubis":
			anubis = soul
	_check(not anubis.is_empty() and anubis.name == "？？？", "Anubis waits under a hidden name")
	for soul in session.souls.duplicate():
		if soul.has("story_case"):
			continue
		soul.stats = session.requirements[0]
		_check(session.release_soul(int(soul.id)), "The ordinary day-five guests leave first")
	_check(session.souls.size() == 1 and not session.awaiting_day_report, "Anubis is the last guest of the shift")

	_demo._show_location("Shop")
	_demo.shop.select_guest(int(anubis.id))
	_demo._refresh_shared()
	_check(_demo.shop.story_sprite == "", "Anubis uses the ordinary guest portrait")
	_check(_demo._release_button.text.contains("继续") and _demo._story_action_button.visible, "The hearing offers continue and true name")
	_check(_demo.judgment_panel.get_rect().end.y < 560.0, "The scale panel stays above the guest's face")
	var runtime = session.get_story_runtime(int(anubis.id))
	_check(runtime != null, "Anubis runtime is created")
	_settle(runtime)
	_check(runtime.is_awaiting_choice(), "Anubis pauses for the hearing")
	var callout: Dictionary = runtime.start_callout()
	_check(str(callout.get("answer", "")) == "ANUBIS", "Anubis asks for ANUBIS")
	_check(runtime.resolve_callout(true), "The true name resolves")
	_settle(runtime)
	_check(session.get_soul(int(anubis.id)).name == "阿努比斯", "The queue shows the true name after reveal")
	_demo._refresh_shared()
	_check(_demo.shop.story_sprite == "anubis", "The true name reveals the placeholder Anubis portrait")
	_check(not _demo._story_action_button.visible, "A revealed linear hearing hides the refusal action")

	_demo._release_guest()
	_settle(runtime)
	_check(runtime.is_awaiting_judgment() and _demo.judgment_panel.visible and session.story_open, "The scale opens and pauses the shift")
	_check(_demo.judgment_panel._range.text.contains("0"), "The scale shows the coin range")
	await _capture("story-anubis-judgment.png")

	_demo.judgment_panel._set_value(0)
	_demo.judgment_panel._submit()
	_demo.judgment_panel.finish_animation()
	_check(not _demo.judgment_panel.visible and runtime.get_node_id() == "end.zero", "A zero offering enters the zero branch")
	_check(not _demo._story_action_button.visible, "The true-name action leaves after the hearing")
	_check(not session.story_open, "The shift resumes after the scale settles")
	for _step in 5:
		_demo._story_advance()
	_check(_demo._dialog.text.contains("子路受牛") or runtime.current_step().get("text", "").contains("子路受牛"), "The zero branch plays its teaching")
	for _step in 2:
		_demo._story_advance()
	_check(_demo._dialog.text.contains("卢苇原") or runtime.current_step().get("text", "").contains("卢苇原"), "The revealed hearing shows the bracketed offer")
	for _step in 12:
		_demo._story_advance()
	_check(runtime.is_closed() and runtime.get_outcome_id() == "judged.zero", "The zero offering closes the hearing")
	_demo._release_guest()
	_check(session.get_soul(int(anubis.id)).is_empty(), "Shift finishes the final guest")
	_check(session.is_complete(), "The five-day shift is complete")
	_check(session.get_day_report().is_empty(), "Anubis closes the game without another day report")
	var ending := "\n".join(session.get_ending_lines())
	_check(ending.contains("天平") and ending.contains("冥河"), "The Anubis ending resolves")
	await create_timer(2.6).timeout
	_check(_demo._ending_screen.visible and _demo._ending_screen.is_active(), "The ending card replaces the reception")
	_check(not _demo._hud.visible and not _demo._shop_ui.visible, "The ending hides the side reception UI")
	_check(_demo._ending_screen._anubis.visible and _demo._ending_screen._scale.visible, "The ending shows Anubis and his scale")
	_check(_demo._ending_screen._text.text.contains("天平"), "The ending card shows the epilogue")
	await _capture("story-anubis-ending.png")

	_demo.queue_free()
	await process_frame
	print("StoryAnubis: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _settle(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and not runtime.is_awaiting_judgment() and guard < 80:
		if not runtime.advance():
			break
		guard += 1


func _capture(file_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://build/validation")
	DirAccess.make_dir_recursive_absolute(directory)
	image.save_png(directory.path_join(file_name))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
