extends SceneTree
## Verifies that PlaytestSession attaches the scheduled story case and resolves it.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	session.start_shift()
	_check(session.story_db != null and session.story_db.loaded, "session loads story DB")

	for _guest in 6:
		session.spawn_remaining = 0.0
		session.advance(0.01)
	_check(session.souls.size() == 6 and str(session.souls[5].get("story_case", "")) == "wukong", "Wukong is the sixth guest on day one")
	var story_soul: Dictionary = {}
	for soul in session.souls:
		if soul.has("story_case"):
			story_soul = soul
			break
	_check(str(story_soul.get("story_case", "")) == "wukong", "first story guest is wukong")
	_check(str(story_soul.get("name", "")) == "史密斯", "queue name is the disguise")
	_check(not session.can_release(int(story_soul.id)), "story guest bypasses the normal release gate")

	var soul_id := int(story_soul.id)
	var runtime = session.get_story_runtime(soul_id)
	_check(runtime != null, "story runtime is created")
	_settle(runtime)
	_check(_has_choice(runtime, "photo"), "runtime offers inspection")
	_check(runtime.choose("photo"), "inspection choice works")
	_settle(runtime)

	session._add_potion("test", "暖心药", Vector3i(0, 4, 0), -1, 0)
	var potion_id := int(session.potions[0]["id"])
	_check(session.feed_story_potion(soul_id, false, potion_id), "story potion is consumed")
	_check(session.potions.is_empty(), "potion leaves the inventory")
	_settle(runtime)
	_check(bool(runtime.flags["rage"]), "hot potion keeps rage")
	_check(not session.feed_story_potion(soul_id, false, -1), "missing potion is refused")

	# Runtime is rebuilt from the soul snapshot after being dropped.
	session.story_runtimes.erase(soul_id)
	var restored = session.get_story_runtime(soul_id)
	_check(restored != null, "runtime rebuilds from snapshot")
	_check(int(restored.flags["clue.photo"]) == 1, "restored clue survives")
	_check(int(restored.flags["dose.score"]) == 4, "restored dose score survives")

	_check(restored.can_callout(), "callout is available")
	var callout: Dictionary = restored.start_callout()
	_check(str(callout.get("answer", "")) == "SUNWUKONG", "callout target is SUNWUKONG")
	_check(restored.resolve_callout(true), "callout succeeds")
	_settle(restored)
	_check(bool(restored.flags["named"]), "callout sets named")
	_check(restored.choose("refuse"), "refusal works")
	_settle(restored)
	_check(restored.is_closed(), "story closes on refusal")
	_check(restored.get_outcome_id() == "refused", "named refusal outcome")
	_check(session.finish_story(soul_id), "session finishes the story")
	_check(session.get_soul(soul_id).is_empty(), "story soul leaves the queue")
	_check(session.released_count == 0 and session.rejected_count == 1, "refusal counts as processed")
	_check(session.coins == Data.STARTING_COINS, "refusal pays nothing")
	_check(session.story_state.ledger.size() == 1, "ledger gets one entry")
	_check(str(session.story_state.ledger[0].get("result", "")) == "未入境", "ledger records refusal")
	_check(str(session.story_state.ledger[0].get("who", "")) == "孙悟空", "ledger records the called-out name")
	_check(bool(session.story_state.world["world.hades_rampage"]), "named refusal still rampages")
	_check(session.get_ending_lines().size() > 0, "ending lines resolve")

	# Orpheus follows Wukong and uses the rampage flag.
	for soul in session.souls.duplicate():
		soul.stats = session.requirements[0]
		session.release_soul(int(soul.id))
	_check(session.get_day_report().day == 1, "Wukong's report belongs to day one")
	session.close_day_report()
	_check(session.day == 2 and not session.awaiting_day_report, "the next shift opens after the report")
	for _guest in 6:
		session.spawn_remaining = 0.0
		session.advance(0.01)
	_check(session.souls.size() == 6 and str(session.souls[5].get("story_case", "")) == "orpheus", "Orpheus is the sixth guest on day two")
	var coins_before_orpheus := session.coins
	var orpheus_soul: Dictionary = {}
	for soul in session.souls:
		if str(soul.get("story_case", "")) == "orpheus":
			orpheus_soul = soul
			break
	_check(not orpheus_soul.is_empty(), "orpheus is waiting after wukong")
	_check(str(orpheus_soul.get("name", "")) == "亚历克斯", "orpheus queue name is the alias")
	var orpheus_id := int(orpheus_soul.id)
	var orpheus = session.get_story_runtime(orpheus_id)
	_check(orpheus != null, "orpheus runtime is created")
	_settle(orpheus)
	session._add_potion("test", "极识药", Vector3i(10, 0, -4), -1, 0)
	var orpheus_potion := int(session.potions[0]["id"])
	_check(session.feed_story_potion(orpheus_id, false, orpheus_potion), "orpheus potion is consumed")
	_settle(orpheus)
	_check(int(orpheus.flags["dose.score"]) == -6, "orpheus confusion score")
	_check(not bool(orpheus.flags["confused"]), "orpheus potion clears confusion")
	_check(orpheus.choose("admit"), "orpheus admission works")
	_settle(orpheus)
	_check(orpheus.is_closed(), "orpheus story closes")
	_check(orpheus.get_outcome_id() == "accepted.reunion", "orpheus reunion with wukong rampage")
	_check(session.finish_story(orpheus_id), "session finishes orpheus")
	_check(session.released_count == 6 and session.rejected_count == 1, "orpheus release counts")
	_check(session.coins == coins_before_orpheus + 60, "orpheus pays the fee")
	_check(session.story_state.ledger.size() == 2, "ledger gets two entries")
	_check(str(session.story_state.ledger[1].get("who", "")) == "亚历克斯", "orpheus ledger keeps the alias")
	_check(str(session.story_state.ledger[1].get("result", "")) == "已入境", "orpheus ledger records admission")
	_check(bool(session.story_state.world["world.orpheus_reunion"]), "orpheus reunion reaches the world state")
	_open_day_three(session)
	_check_day_three_guests(session, false)
	_check_orpheus_loss("admit", false, "accepted.confused")
	_check_orpheus_loss("admit", true, "accepted.clear")
	_check_orpheus_loss("refuse", false, "refused")

	# Story panel suspends the shift clock.
	var clock := Session.new()
	root.add_child(clock)
	clock.set_process(false)
	clock._open_day(1)
	clock.active = true
	clock.spawn_remaining = 5.0
	clock.set_story_open(true)
	clock.advance(1.0)
	_check(clock.spawn_remaining == 5.0, "open story suspends arrivals")
	clock.set_story_open(false)
	clock.advance(1.0)
	_check(clock.spawn_remaining < 5.0, "closed story resumes arrivals")
	clock.free()

	if _failures == 0:
		print("StoryIntegration: %d checks, 0 failures" % _checks)
	else:
		print("StoryIntegration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_orpheus_loss(choice: String, clear_head: bool, outcome: String) -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	session._open_day(2)
	session.active = true
	session.advance(6.0 * Data.ARRIVAL_MAX + 1.0)
	var soul := session.souls.back() as Dictionary
	var runtime = session.get_story_runtime(int(soul.id))
	_settle(runtime)
	if clear_head:
		session._add_potion("test", "极识药", Vector3i(10, 0, -4), -1, 0)
		_check(session.feed_story_potion(int(soul.id), false, int(session.potions[0].id)), "Orpheus takes the clearing dose")
		_settle(runtime)
	_check(runtime.choose(choice), "Orpheus choice is available")
	_settle(runtime)
	_check(runtime.get_outcome_id() == outcome and session.finish_story(int(soul.id)), "Orpheus reaches %s" % outcome)
	_open_day_three(session)
	# Save and restore the day and story before the conditional guest arrives.
	session.restore_story(session.story_state.snapshot())
	session.restore_day(session.save_day())
	_check_day_three_guests(session, true)
	session.free()


func _open_day_three(session: Session) -> void:
	for soul in session.souls.duplicate():
		soul.stats = session.requirements[0]
		_check(session.release_soul(int(soul.id)), "Day two ordinary guest can be released")
	session.close_day_report()
	_check(session.day == 3, "Closing the day two report opens day three")


func _check_day_three_guests(session: Session, expect_lyre_player: bool) -> void:
	session.advance(6.0 * Data.ARRIVAL_MAX + 1.0)
	_check(session.souls.size() == 6 and not session.has_more_arrivals(), "Day three has exactly six guests")
	var lyre_players := session.souls.filter(func(soul: Dictionary) -> bool: return soul.case_id == Data.DROWNED_LYRE_PLAYER)
	_check(lyre_players.size() == int(expect_lyre_player), "The lyre player arrives once only if Orpheus lost Eurydice")
	if expect_lyre_player and not lyre_players.is_empty():
		var guest: Dictionary = lyre_players[0]
		_check(guest == session.souls[5] and guest.name == "殉情的琴手", "The lyre player is the sixth guest")
		_check(guest.stats == Vector3i(8, 10, 0) and guest.before == guest.stats and not guest.has("story_case"), "The lyre player has visible stats and uses the regular admission rules")


func _settle(runtime) -> void:
	var guard := 0
	while not runtime.is_closed() and runtime.visible_choices().is_empty() and guard < 50:
		if not runtime.advance():
			break
		guard += 1


func _has_choice(runtime, id: String) -> bool:
	for choice in runtime.visible_choices():
		if str(choice.get("id", "")) == id:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
