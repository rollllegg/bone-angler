extends Node2D
## Existing DirectionFishing rules, with an independent cast and dynamic line.

signal cast_finished

const BACKGROUND := preload("res://assets/art/demo/river.png")
const AMBIENT_ATLAS := preload("res://assets/art/demo/river_ambient.png")
const AMBIENT_STRIP := Rect2(0, 77, 405, 159)
const AMBIENT_COLUMNS := 8
const AMBIENT_FRAME_COUNT := 48
const AMBIENT_FPS := 12.0
const FERRY := preload("res://assets/art/demo/soul_ferry.png")
# The visible hull and passengers inside the sprite's transparent 64-by-64 canvas.
const FERRY_REGION := Rect2(10, 20, 43, 24)
const FERRY_LEAD_TIME := 8.0
const FERRY_START := Vector2(72, 71)
const FERRY_EXIT := Vector2(-FERRY_REGION.size.x, 132)
const ROD := preload("res://assets/art/demo/rod_idle.png")
const CAST_FRAMES := [preload("res://assets/art/demo/cast_01.png"), preload("res://assets/art/demo/cast_02.png"), preload("res://assets/art/demo/cast_03.png"), ROD]
const FRAME_DURATION := 0.25
const TIMING_FRAME := Rect2(125, 112, 78, 72)
const GRIP := Vector2(293, 243)
const ROD_TIP := Vector2(203.5, 64.5)
const CATCH_LINE_END := Vector2(151, 118)
const MINT := Color("b8efdb")
const GOLD := Color("efc875")

const Fishing := preload("res://scripts/systems/playtest_fishing.gd")
const Data := preload("res://scripts/systems/playtest_data.gd")

var qte: Fishing
var active: bool = false
var paused: bool = false
var casting: bool = false
var cast_elapsed: float = 0.0
var clock: float = 0.0
var tension := Vector2.ZERO
var pulse: float = 0.0
var hit_timer: float = 0.0
var last_entry := TIMING_FRAME.get_center()


func bind(value: Fishing) -> void:
	qte = value
	qte.pull_judged.connect(_on_judged)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func start_cast() -> bool:
	if casting or paused or not qte.can_cast():
		return false
	casting = true
	cast_elapsed = 0.0
	tension = Vector2.ZERO
	pulse = 0.0
	hit_timer = 0.0
	queue_redraw()
	return true


func get_cast_frame() -> int:
	return mini(int(cast_elapsed / FRAME_DURATION), 3)


func cancel_cast() -> void:
	casting = false
	queue_redraw()


func advance_cast(delta: float) -> void:
	if not casting or paused or not active:
		return
	cast_elapsed += maxf(delta, 0.0)
	if cast_elapsed >= FRAME_DURATION * 4.0:
		casting = false
		qte.cast()
		cast_finished.emit()
	queue_redraw()


func _process(delta: float) -> void:
	if not active or paused or qte == null:
		return
	clock += delta
	advance_cast(delta)
	pulse = maxf(pulse - delta * 8.0, 0.0)
	hit_timer = maxf(hit_timer - delta, 0.0)
	var target := Vector2.ZERO
	var rate := 28.0
	if not casting and qte.phase == Fishing.Phase.REELING:
		target = Fishing.DIRECTIONS[qte.fish_direction] * qte.get_travel_ratio()
		rate = 16.0
	tension = tension.lerp(target, 1.0 - exp(-delta * rate))
	queue_redraw()


func get_ferry_rect() -> Rect2:
	if not active or qte == null or qte.session == null:
		return Rect2()
	var session := qte.session
	var remaining := session.spawn_remaining
	if not session.active or not session.has_more_arrivals() or remaining <= 0.0 or remaining > FERRY_LEAD_TIME:
		return Rect2()
	var progress := 1.0 - remaining / FERRY_LEAD_TIME
	var position_on_river := FERRY_START.lerp(FERRY_EXIT, progress).round()
	var size_on_river := (FERRY_REGION.size * lerpf(0.75, 1.0, progress)).round()
	return Rect2(position_on_river, size_on_river)


func get_water_entry() -> Vector2:
	return TIMING_FRAME.get_center() + Fishing.DIRECTIONS[qte.fish_direction] * TIMING_FRAME.size * 0.5 * qte.get_travel_ratio()


func get_rod_angle() -> float:
	return tension.x * 0.045 - tension.y * 0.025 + pulse * (-0.025 if qte.last_success else 0.02)


func get_rod_tip() -> Vector2:
	return GRIP + (ROD_TIP - GRIP).rotated(get_rod_angle())


func _on_judged(_success: bool, _message: String) -> void:
	pulse = 1.0
	hit_timer = 0.45
	last_entry = get_water_entry()


func _draw() -> void:
	draw_texture(BACKGROUND, Vector2.ZERO)
	var frame := int(clock * AMBIENT_FPS) % AMBIENT_FRAME_COUNT
	@warning_ignore("integer_division")
	var cell := Vector2(frame % AMBIENT_COLUMNS, frame / AMBIENT_COLUMNS)
	draw_texture_rect_region(AMBIENT_ATLAS, AMBIENT_STRIP, Rect2(cell * AMBIENT_STRIP.size, AMBIENT_STRIP.size))
	var ferry_rect := get_ferry_rect()
	if ferry_rect.has_area():
		draw_texture_rect_region(FERRY, ferry_rect, FERRY_REGION)
	if qte == null:
		return
	if casting:
		if get_cast_frame() == 3:
			_draw_line_to(TIMING_FRAME.get_center(), false)
		draw_texture(CAST_FRAMES[get_cast_frame()], Vector2.ZERO)
		return
	if qte.phase == Fishing.Phase.CAUGHT:
		if qte.locked.has("species"):
			_draw_line_to(CATCH_LINE_END, false)
	elif qte.phase != Fishing.Phase.READY:
		var entry := TIMING_FRAME.get_center()
		if qte.phase == Fishing.Phase.REELING:
			entry = get_water_entry()
		elif qte.phase == Fishing.Phase.FEEDBACK:
			entry = TIMING_FRAME.get_center().lerp(last_entry, pulse)
		_draw_line_to(entry, qte.is_busy())
	draw_set_transform(GRIP, get_rod_angle())
	draw_texture(ROD, -GRIP)
	draw_set_transform(Vector2.ZERO)
	if qte.phase in [Fishing.Phase.PREPARING, Fishing.Phase.REELING, Fishing.Phase.FEEDBACK]:
		_draw_timing_frame()
	if qte.phase == Fishing.Phase.REELING and not paused:
		_draw_arrow(Vector2(282, 133), Fishing.DIRECTIONS[qte.get_expected_direction()])


func _draw_line_to(entry: Vector2, ripple: bool) -> void:
	var tip := get_rod_tip()
	var points := PackedVector2Array()
	var slack := 2.0 if qte.phase == Fishing.Phase.REELING else 6.0
	for index in 25:
		var t := index / 24.0
		points.append((tip.lerp(entry, t) + Vector2(sin(t * PI) * slack, 0)).round())
	var color := MINT
	if pulse > 0.0:
		color = MINT.lerp(GOLD if qte.last_success else Color("f49b8d"), pulse)
	draw_polyline(points, color, 1.0, false)
	if ripple:
		var radius := 4.0 + sin(clock * 3.0)
		var ring := PackedVector2Array()
		for index in 17:
			var angle := index * TAU / 16.0
			ring.append((entry + Vector2(cos(angle) * radius, sin(angle) * radius * 0.4)).round())
		draw_polyline(ring, Color(MINT, 0.65), 1.0, false)
		if qte.phase == Fishing.Phase.REELING:
			draw_rect(Rect2(entry.round() - Vector2.ONE, Vector2(2, 2)), GOLD)


func _draw_timing_frame() -> void:
	var perfect := qte.is_perfect_timing() and not paused
	var color := GOLD if perfect else Color("85aaa9")
	var a := TIMING_FRAME.position
	var b := TIMING_FRAME.end
	for x in range(int(a.x), int(b.x), 6):
		draw_line(Vector2(x, a.y), Vector2(minf(x + 2, b.x), a.y), color)
		draw_line(Vector2(x, b.y), Vector2(minf(x + 2, b.x), b.y), color)
	for y in range(int(a.y), int(b.y), 6):
		draw_line(Vector2(a.x, y), Vector2(a.x, minf(y + 2, b.y)), color)
		draw_line(Vector2(b.x, y), Vector2(b.x, minf(y + 2, b.y)), color)
	if qte.phase == Fishing.Phase.REELING:
		var direction: Vector2 = Fishing.DIRECTIONS[qte.fish_direction]
		var edge := TIMING_FRAME.get_center() + direction * TIMING_FRAME.size * 0.5
		var tangent := Vector2(-direction.y, direction.x)
		draw_line(edge - tangent * 6, edge + tangent * 6, GOLD if perfect else MINT, 2)


func _draw_arrow(center: Vector2, direction: Vector2) -> void:
	var shape := [Vector2(-9, -2), Vector2(1, -2), Vector2(1, -6), Vector2(10, 0), Vector2(1, 6), Vector2(1, 2), Vector2(-9, 2)]
	var points := PackedVector2Array()
	for point in shape:
		points.append((center + point.rotated(direction.angle())).round())
	draw_colored_polygon(points, MINT)
