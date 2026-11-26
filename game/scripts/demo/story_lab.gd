extends RefCounted
## Tests story guests in day order through the normal reports and world state.

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")


static func populate(session: Session) -> void:
	session.set_block_signals(true)
	session.restore_story({})
	session._first_services.clear()
	session._arrived = 0
	session.released_count = 0
	session.rejected_count = 0
	session.last_story_outcome = ""
	session.last_payout = 0
	session.pending_day_report = {}
	session.awaiting_day_report = false
	session.tutorial_pause_arrivals = false
	session.story_open = false
	session.paused = false
	session.active = true
	session.souls.clear()
	session._open_day(1)
	prepare_day(session)
	session.coins = 200
	session.essences.fill(0)
	session.potions.clear()
	session._next_item_id = 1
	session._add_potion("medicine_02", "暖心药", Vector3i(0, 2, 0), -1, 0)
	session._add_potion("medicine_07", "明识药", Vector3i(4, 0, 1), -1, 0)
	session._add_potion("medicine_10", "镇魂药", Vector3i(-2, -1, -1), -1, 0)
	session.set_block_signals(false)


static func prepare_day(session: Session) -> void:
	var blocked := session.is_blocking_signals()
	session.set_block_signals(true)
	while true:
		# Generate the real day's arrivals, then omit ordinary guests from the lab.
		# In particular, the drowned lyre player must come from the real echo flag.
		session.spawn_remaining = 0.0
		session.advance(Session.GUESTS_PER_DAY * Data.ARRIVAL_MAX + 1.0)
		var guests: Array[Dictionary] = []
		for soul in session.souls:
			var label := ""
			if soul.has("story_case"):
				label = session.story_db.get_title(str(soul.story_case))
				if str(soul.story_case) == "anubis":
					label += "（终审）"
			elif str(soul.get("story_echo", "")) == "orpheus":
				label = "殉情的琴手（回访）"
			if label != "":
				soul["story_lab_label"] = label
				guests.append(soul)
		session.souls.assign(guests)
		# The lab tests dialogue freely; normal runs retain their stat checks.
		session.requirements = [Vector3i.ZERO, Session.STAT_CEILING]
		if not guests.is_empty() or session.awaiting_day_report or session.is_complete():
			break
		# Skip days with no story guest without inventing a service or a report.
		session._advance_day_if_ready()
	session.set_block_signals(blocked)
