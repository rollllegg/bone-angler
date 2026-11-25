extends Node2D
## One guest at the counter with independent departures along the path.

signal presentation_changed
signal walk_started

const BACKGROUND := preload("res://assets/art/demo/shop.png")
const FRONT := preload("res://assets/art/demo/guest_front.png")
const TURN := preload("res://assets/art/demo/guest_turn.png")
const BACK := [preload("res://assets/art/demo/guest_back_01.png"), preload("res://assets/art/demo/guest_back_02.png")]
const DROWNED_SPRITE := "drowned_lyre_player"
const DROWNED_FRONT := preload("res://assets/art/demo/drowned_lyre_front.png")
const DROWNED_TURN := preload("res://assets/art/demo/drowned_lyre_turn.png")
const DROWNED_BACK := [preload("res://assets/art/demo/drowned_lyre_back_01.png"), preload("res://assets/art/demo/drowned_lyre_back_02.png")]
const STORY_SPRITES := {
	"wukong_disguise": preload("res://assets/art/story/sprites/wukong_disguise.png"),
	"wukong_disguise_turn": preload("res://assets/art/story/sprites/wukong_disguise_turn.png"),
	"wukong_monkey": preload("res://assets/art/story/sprites/wukong_monkey.png"),
	"wukong_turn": preload("res://assets/art/story/sprites/wukong_turn.png"),
	"orpheus_front": preload("res://assets/art/story/sprites/orpheus_front.png"),
	"orpheus_revealed": preload("res://assets/art/story/sprites/orpheus_revealed.png"),
	"orpheus_turn": preload("res://assets/art/story/sprites/orpheus_turn.png"),
}
const STORY_SHADOWS := {
	"wukong_disguise": preload("res://assets/art/story/sprites/wukong_disguise_shadow.png"),
	"wukong_disguise_turn": preload("res://assets/art/story/sprites/wukong_disguise_turn_shadow.png"),
	"wukong_monkey": preload("res://assets/art/story/sprites/wukong_monkey_shadow.png"),
	"wukong_turn": preload("res://assets/art/story/sprites/wukong_turn_shadow.png"),
	"orpheus_front": preload("res://assets/art/story/sprites/orpheus_front_shadow.png"),
	"orpheus_revealed": preload("res://assets/art/story/sprites/orpheus_revealed_shadow.png"),
	"orpheus_turn": preload("res://assets/art/story/sprites/orpheus_turn_shadow.png"),
}
const STORY_TURNS := {
	"wukong_disguise": "wukong_disguise_turn",
	"wukong_monkey": "wukong_turn",
	"orpheus_front": "orpheus_turn",
	"orpheus_revealed": "orpheus_turn",
}
const COUNTER := Vector2(201, 194)
const PATH_CORNER := Vector2(276, 177)
const GATE := Vector2(310, 134)
const TURN_DURATION := 0.4
const WALK_DURATION := 4.0
const FADE_DURATION := 0.45
const COUNTER_CLEAR_TIME := 1.2
const PATH_CORNER_RATIO := 0.40
const START_SCALE := 1.45
const GUEST_OFFSET := Vector2(-24, -62)

const Data := preload("res://scripts/systems/playtest_data.gd")
const Session := preload("res://scripts/systems/playtest_session.gd")

var session: Session
var active: bool = false
var selected_id: int = -1
var departure_times: Array[float] = []
var departure_sprites: Array[String] = []
var departure_ids: Array[int] = []
var story_sprite := ""
var story_sprite_flip := false
var story_props = null
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
		clear_story_sprite()
		selected_id = -1 if session.souls.is_empty() else int(session.souls[0]["id"])
		fed_flash = 0.0
	presentation_changed.emit()
	queue_redraw()


func select_guest(id: int) -> void:
	if session.paused or session.get_soul(id).is_empty():
		return
	var current_story = session.get_story_runtime(selected_id)
	if current_story != null and current_story.callout_active:
		return
	if id != selected_id:
		clear_story_sprite()
	selected_id = id
	fed_flash = 0.0
	presentation_changed.emit()
	queue_redraw()


func bind_story_props(value) -> void:
	story_props = value
	queue_redraw()


func set_story_sprite(id: String, flip: bool = false) -> void:
	if not STORY_SPRITES.has(id) or (story_sprite == id and story_sprite_flip == flip):
		return
	story_sprite = id
	story_sprite_flip = flip
	queue_redraw()


func clear_story_sprite() -> void:
	if story_sprite == "" and not story_sprite_flip:
		return
	story_sprite = ""
	story_sprite_flip = false
	queue_redraw()


func has_story_sprite() -> bool:
	return story_sprite != ""


func clear_departures() -> void:
	if departure_times.is_empty():
		return
	departure_times.clear()
	departure_sprites.clear()
	departure_ids.clear()
	queue_redraw()


func _on_served(id: int) -> void:
	if id == selected_id:
		fed_flash = 0.65
		presentation_changed.emit()


func begin_departure() -> bool:
	if session.paused or not session.can_release(selected_id):
		return false
	var soul := session.get_soul(selected_id)
	var start := 0.0 if departure_times.is_empty() else minf(0.0, departure_times.back() - COUNTER_CLEAR_TIME)
	departure_times.append(start)
	departure_sprites.append(DROWNED_SPRITE if soul.case_id == Data.DROWNED_LYRE_PLAYER else "")
	departure_ids.append(selected_id)
	if not session.release_soul(selected_id):
		departure_times.pop_back()
		departure_sprites.pop_back()
		departure_ids.pop_back()
		return false
	return true


func begin_story_departure() -> bool:
	if session.paused or session.get_soul(selected_id).is_empty():
		return false
	var start := 0.0 if departure_times.is_empty() else minf(0.0, departure_times.back() - COUNTER_CLEAR_TIME)
	departure_times.append(start)
	departure_sprites.append(story_sprite)
	departure_ids.append(selected_id)
	if not session.finish_story(selected_id):
		departure_times.pop_back()
		departure_sprites.pop_back()
		departure_ids.pop_back()
		return false
	return true


func advance_presentation(delta: float) -> void:
	if not active or session == null or session.paused or delta <= 0.0:
		return
	clock += delta
	fed_flash = maxf(fed_flash - delta, 0.0)
	var had_departures := not departure_times.is_empty()
	for i in range(departure_times.size() - 1, -1, -1):
		var was_turning := departure_times[i] < TURN_DURATION
		departure_times[i] += delta
		if departure_times[i] >= TURN_DURATION + WALK_DURATION + FADE_DURATION:
			departure_times.remove_at(i)
			if i < departure_sprites.size():
				departure_sprites.remove_at(i)
			if i < departure_ids.size():
				departure_ids.remove_at(i)
		elif was_turning and departure_times[i] >= TURN_DURATION:
			walk_started.emit()
	if had_departures and departure_times.is_empty():
		presentation_changed.emit()
	queue_redraw()


func _process(delta: float) -> void:
	advance_presentation(delta)


func _draw_departure(elapsed: float, sprite_id: String) -> void:
	var walk_time := elapsed - TURN_DURATION
	var t := clampf(walk_time / WALK_DURATION, 0.0, 1.0)
	var point := COUNTER.lerp(PATH_CORNER, t / PATH_CORNER_RATIO)
	if t >= PATH_CORNER_RATIO:
		point = PATH_CORNER.lerp(GATE, inverse_lerp(PATH_CORNER_RATIO, 1.0, t))
	var opacity := 1.0 - clampf((walk_time - WALK_DURATION) / FADE_DURATION, 0.0, 1.0)
	var step := int(maxf(walk_time, 0.0) / 0.18) % 2
	var texture: Texture2D = TURN if walk_time < 0.0 else BACK[step]
	var turn_id := str(STORY_TURNS.get(sprite_id, sprite_id))
	if sprite_id == DROWNED_SPRITE:
		texture = DROWNED_TURN if walk_time < 0.0 else DROWNED_BACK[step]
	elif STORY_SPRITES.has(turn_id):
		texture = STORY_SPRITES[turn_id]
	point.y -= step * (1.0 - t)
	draw_set_transform(point.round(), 0.0, Vector2.ONE * lerpf(START_SCALE, 0.36, t))
	var shadow: Texture2D = STORY_SHADOWS.get(turn_id)
	if shadow != null:
		draw_texture(shadow, GUEST_OFFSET, Color(1, 1, 1, 0.35 * opacity))
	draw_texture(texture, GUEST_OFFSET, Color(1, 1, 1, opacity))
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	draw_texture(BACKGROUND, Vector2.ZERO)
	if session == null:
		return
	for index in departure_times.size():
		if departure_times[index] >= 0.0:
			var sprite_id := departure_sprites[index] if index < departure_sprites.size() else ""
			_draw_departure(departure_times[index], sprite_id)
	_draw_story_props("behind")
	var selected := session.get_soul(selected_id)
	if not selected.is_empty():
		var departure_elapsed := -1.0
		for index in departure_ids.size():
			if departure_ids[index] == selected_id:
				departure_elapsed = departure_times[index]
				break
		var opacity := 1.0 if departure_elapsed < 0.0 else smoothstep(TURN_DURATION, COUNTER_CLEAR_TIME, departure_elapsed)
		var texture: Texture2D = DROWNED_FRONT if selected.case_id == Data.DROWNED_LYRE_PLAYER else FRONT
		if story_sprite != "" and selected.has("story_case"):
			texture = STORY_SPRITES.get(story_sprite, FRONT)
		var flip := -START_SCALE if story_sprite_flip else START_SCALE
		draw_set_transform(COUNTER + Vector2(0, roundf(sin(clock * 2.0))), 0.0, Vector2(flip, START_SCALE))
		if story_sprite != "":
			var shadow: Texture2D = STORY_SHADOWS.get(story_sprite)
			if shadow != null:
				draw_texture(shadow, GUEST_OFFSET, Color(1, 1, 1, 0.35 * opacity))
		draw_texture(texture, GUEST_OFFSET, Color(1, 1, 1, opacity))
		if fed_flash > 0.0:
			draw_texture(texture, GUEST_OFFSET, Color(1, 0.94, 0.7, fed_flash * 0.4 * opacity))
		draw_set_transform(Vector2.ZERO)
	_draw_story_props("front")
	# Repaint the original foreground counter so the guest stands behind it.
	draw_texture_rect_region(BACKGROUND, Rect2(0, 194, 405, 49), Rect2(0, 194, 405, 49))


func _draw_story_props(layer: String) -> void:
	if story_props == null:
		return
	for id in story_props.get_prop_ids():
		if story_props.layer_for(str(id)) != layer:
			continue
		var texture: Texture2D = story_props.get_texture(str(id))
		if texture == null:
			continue
		var state: Dictionary = story_props.get_state(str(id))
		var point: Vector2 = state.position
		draw_set_transform(point.round(), 0.0, Vector2.ONE * float(state.scale))
		draw_texture(texture, -texture.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO)
