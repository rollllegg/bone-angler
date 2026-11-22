extends Node2D
## One guest at the counter with independent departures along the path.

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
const COUNTER_CLEAR_TIME := 1.2
const PATH_CORNER_RATIO := 0.40
const START_SCALE := 1.45

const Session := preload("res://scripts/systems/playtest_session.gd")

var session: Session
var active: bool = false
var selected_id: int = -1
var departure_times: Array[float] = []
var fed_flash: float = 0.0
var clock: float = 0.0


func bind(value: Session) -> void:
	session = value
	session.state_changed.connect(_sync_selection)
	session.soul_served.connect(_on_served)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sync_selection()


func _sync_selection() -> void:
	if session.get_soul(selected_id).is_empty():
		selected_id = -1 if session.souls.is_empty() else int(session.souls[0]["id"])
		fed_flash = 0.0
	presentation_changed.emit()
	queue_redraw()


func select_guest(id: int) -> void:
	if session.paused or session.get_soul(id).is_empty():
		return
	selected_id = id
	fed_flash = 0.0
	presentation_changed.emit()
	queue_redraw()


func _on_served(id: int) -> void:
	if id == selected_id:
		fed_flash = 0.65
		presentation_changed.emit()


func begin_departure() -> bool:
	if session.paused or not session.can_release(selected_id):
		return false
	var start := 0.0 if departure_times.is_empty() else minf(0.0, departure_times.back() - COUNTER_CLEAR_TIME)
	departure_times.append(start)
	if not session.release_soul(selected_id):
		departure_times.pop_back()
		return false
	return true


func advance_presentation(delta: float) -> void:
	if not active or session == null or session.is_time_suspended() or delta <= 0.0:
		return
	clock += delta
	fed_flash = maxf(fed_flash - delta, 0.0)
	var had_departures := not departure_times.is_empty()
	for i in range(departure_times.size() - 1, -1, -1):
		departure_times[i] += delta
		if departure_times[i] >= TURN_DURATION + WALK_DURATION + FADE_DURATION:
			departure_times.remove_at(i)
	if had_departures and departure_times.is_empty():
		presentation_changed.emit()
	queue_redraw()


func _process(delta: float) -> void:
	advance_presentation(delta)


func _draw_departure(elapsed: float) -> void:
	var walk_time := elapsed - TURN_DURATION
	var t := clampf(walk_time / WALK_DURATION, 0.0, 1.0)
	var point := COUNTER.lerp(PATH_CORNER, t / PATH_CORNER_RATIO)
	if t >= PATH_CORNER_RATIO:
		point = PATH_CORNER.lerp(GATE, inverse_lerp(PATH_CORNER_RATIO, 1.0, t))
	var opacity := 1.0 - clampf((walk_time - WALK_DURATION) / FADE_DURATION, 0.0, 1.0)
	var step := int(maxf(walk_time, 0.0) / 0.18) % 2
	var texture: Texture2D = TURN if walk_time < 0.0 else BACK[step]
	point.y -= step * (1.0 - t)
	draw_set_transform(point.round(), 0.0, Vector2.ONE * lerpf(START_SCALE, 0.36, t))
	draw_texture(texture, Vector2(-24, -62), Color(1, 1, 1, opacity))
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	draw_texture(BACKGROUND, Vector2.ZERO)
	if session == null:
		return
	for elapsed in departure_times:
		if elapsed >= 0.0:
			_draw_departure(elapsed)
	if not session.get_soul(selected_id).is_empty():
		var opacity := 1.0 if departure_times.is_empty() else smoothstep(TURN_DURATION, COUNTER_CLEAR_TIME, departure_times.back())
		draw_set_transform(COUNTER + Vector2(0, roundf(sin(clock * 2.0))), 0.0, Vector2.ONE * START_SCALE)
		draw_texture(FRONT, Vector2(-24, -62), Color(1, 1, 1, opacity))
		if fed_flash > 0.0:
			draw_texture(FRONT, Vector2(-24, -62), Color(1, 0.94, 0.7, fed_flash * 0.4 * opacity))
		draw_set_transform(Vector2.ZERO)
	# Repaint the original foreground counter so the guest stands behind it.
	draw_texture_rect_region(BACKGROUND, Rect2(0, 194, 405, 49), Rect2(0, 194, 405, 49))
