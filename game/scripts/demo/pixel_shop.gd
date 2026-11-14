extends Node2D
## One stable guest at the counter, followed by a turn, walk and gate fade.

signal presentation_changed

const BACKGROUND := preload("res://assets/art/demo/shop.png")
const FRONT := preload("res://assets/art/demo/guest_front.png")
const TURN := preload("res://assets/art/demo/guest_turn.png")
const BACK := [preload("res://assets/art/demo/guest_back_01.png"), preload("res://assets/art/demo/guest_back_02.png")]
const COUNTER := Vector2(201, 194)
const PATH_CORNER := Vector2(276, 177)
const GATE := Vector2(310, 134)
const TURN_DURATION := 0.4
const WALK_DURATION := 4.0
const FADE_DURATION := 0.45
const START_SCALE := 1.45

var session: SoulSession
var active: bool = false
var selected_id: int = -1
var departing: bool = false
var departure_elapsed: float = 0.0
var departure_soul: Dictionary = {}
var satisfied_elapsed: float = 0.0
var fed_flash: float = 0.0
var clock: float = 0.0


func bind(value: SoulSession) -> void:
	session = value
	session.state_changed.connect(_sync_selection)
	session.soul_fed.connect(_on_fed)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sync_selection()


func _sync_selection() -> void:
	if not departing and session.get_soul(selected_id).is_empty():
		selected_id = -1 if session.souls.is_empty() else int(session.souls[0]["id"])
		satisfied_elapsed = 0.0
	presentation_changed.emit()
	queue_redraw()


func select_guest(id: int) -> void:
	if departing or session.paused or session.get_soul(id).is_empty():
		return
	selected_id = id
	satisfied_elapsed = 0.0
	presentation_changed.emit()
	queue_redraw()


func feed(index: int) -> bool:
	if departing:
		return false
	return session.feed_fish(selected_id, index)


func _on_fed(id: int, _fish_index: int) -> void:
	if id == selected_id:
		fed_flash = 0.65
		satisfied_elapsed = 0.0
		presentation_changed.emit()


func begin_departure() -> bool:
	if departing or session.paused or not session.can_release(selected_id):
		return false
	departure_soul = session.get_soul(selected_id).duplicate(true)
	departing = true
	departure_elapsed = 0.0
	if not session.release_soul(selected_id):
		departing = false
		return false
	selected_id = -1
	presentation_changed.emit()
	queue_redraw()
	return true


func advance_presentation(delta: float) -> void:
	if not active or session == null or session.paused or delta <= 0.0:
		return
	clock += delta
	fed_flash = maxf(fed_flash - delta, 0.0)
	if departing:
		departure_elapsed += delta
		if departure_elapsed >= TURN_DURATION + WALK_DURATION + FADE_DURATION:
			departing = false
			departure_soul = {}
			_sync_selection()
	elif session.can_release(selected_id):
		satisfied_elapsed += delta
		if satisfied_elapsed >= 0.75:
			begin_departure()
	queue_redraw()


func _process(delta: float) -> void:
	advance_presentation(delta)


func get_walk_ratio() -> float:
	return clampf((departure_elapsed - TURN_DURATION) / WALK_DURATION, 0.0, 1.0)


func get_guest_position() -> Vector2:
	var t := get_walk_ratio()
	return COUNTER.lerp(PATH_CORNER, t / 0.55) if t < 0.55 else PATH_CORNER.lerp(GATE, (t - 0.55) / 0.45)


func get_guest_scale() -> float:
	return lerpf(START_SCALE, 0.36, get_walk_ratio())


func get_guest_pose() -> String:
	if not departing:
		return "front"
	return "turn" if departure_elapsed < TURN_DURATION else "back"


func _draw() -> void:
	draw_texture(BACKGROUND, Vector2.ZERO)
	if session == null:
		return
	if departing:
		var t := get_walk_ratio()
		var point := get_guest_position()
		var opacity := 1.0 - clampf((departure_elapsed - TURN_DURATION - WALK_DURATION) / FADE_DURATION, 0.0, 1.0)
		var texture: Texture2D = TURN if departure_elapsed < TURN_DURATION else BACK[int((departure_elapsed - TURN_DURATION) / 0.18) % 2]
		point.y -= float(int(departure_elapsed / 0.18) % 2) * (1.0 - t) if get_guest_pose() == "back" else 0.0
		draw_set_transform(point.round(), 0.0, Vector2.ONE * get_guest_scale())
		draw_texture(texture, Vector2(-24, -62), Color(1, 1, 1, opacity))
		draw_set_transform(Vector2.ZERO)
	elif not session.get_soul(selected_id).is_empty():
		draw_set_transform(COUNTER + Vector2(0, roundf(sin(clock * 2.0))), 0.0, Vector2.ONE * START_SCALE)
		draw_texture(FRONT, Vector2(-24, -62))
		if fed_flash > 0.0:
			draw_texture(FRONT, Vector2(-24, -62), Color(1, 0.94, 0.7, fed_flash * 0.4))
		draw_set_transform(Vector2.ZERO)
	# Repaint the original foreground counter so the guest stands behind it.
	draw_texture_rect_region(BACKGROUND, Rect2(0, 194, 405, 49), Rect2(0, 194, 405, 49))
