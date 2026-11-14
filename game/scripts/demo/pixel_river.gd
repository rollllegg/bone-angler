extends Node2D
## Existing DirectionFishing rules, with an independent cast and dynamic line.

signal cast_finished

const BACKGROUND := preload("res://assets/art/demo/river.png")
const ROD := preload("res://assets/art/demo/rod_idle.png")
const CAST_FRAMES := [preload("res://assets/art/demo/cast_01.png"), preload("res://assets/art/demo/cast_02.png"), preload("res://assets/art/demo/cast_03.png"), ROD]
const FRAME_DURATION := 0.25
const TIMING_FRAME := Rect2(125, 112, 78, 72)
const GRIP := Vector2(293, 243)
const ROD_TIP := Vector2(203.5, 64.5)
const MINT := Color("b8efdb")
const GOLD := Color("efc875")

var qte: DirectionFishing
var active: bool = false
var paused: bool = false
var casting: bool = false
var cast_elapsed: float = 0.0
var clock: float = 0.0
var tension := Vector2.ZERO
var pulse: float = 0.0
var last_entry := TIMING_FRAME.get_center()


func bind(value: DirectionFishing) -> void:
	qte = value
	qte.pull_judged.connect(_on_judged)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func start_cast() -> bool:
	if casting or paused or qte.is_busy():
		return false
	casting = true
	cast_elapsed = 0.0
	tension = Vector2.ZERO
	pulse = 0.0
	queue_redraw()
	return true


func get_cast_frame() -> int:
	return mini(int(cast_elapsed / FRAME_DURATION), 3)


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
	pulse = maxf(pulse - delta * 2.5, 0.0)
	var target := Vector2.ZERO
	if not casting and qte.phase == DirectionFishing.Phase.REELING:
		target = DirectionFishing.VECTORS[qte.fish_direction] * qte.get_travel_ratio()
	elif qte.phase == DirectionFishing.Phase.FEEDBACK:
		target = DirectionFishing.VECTORS[qte.fish_direction] * pulse
	tension = tension.lerp(target, 1.0 - exp(-delta * 9.0))
	queue_redraw()


func get_water_entry() -> Vector2:
	return TIMING_FRAME.get_center() + DirectionFishing.VECTORS[qte.fish_direction] * TIMING_FRAME.size * 0.5 * qte.get_travel_ratio()


func get_rod_angle() -> float:
	return tension.x * 0.045 - tension.y * 0.025 + pulse * (-0.025 if qte.last_success else 0.02)


func get_rod_tip() -> Vector2:
	return GRIP + (ROD_TIP - GRIP).rotated(get_rod_angle())


func _on_judged(_success: bool, _message: String) -> void:
	pulse = 1.0
	last_entry = get_water_entry()


func _draw() -> void:
	draw_texture(BACKGROUND, Vector2.ZERO)
	if qte == null:
		return
	if casting:
		if get_cast_frame() == 3:
			_draw_line_to(TIMING_FRAME.get_center(), false)
		draw_texture(CAST_FRAMES[get_cast_frame()], Vector2.ZERO)
		return
	if qte.phase != DirectionFishing.Phase.READY:
		var entry := TIMING_FRAME.get_center()
		if qte.phase == DirectionFishing.Phase.REELING:
			entry = get_water_entry()
		elif qte.phase == DirectionFishing.Phase.FEEDBACK:
			entry = last_entry
		elif qte.phase == DirectionFishing.Phase.CAUGHT:
			entry = Vector2(151, 137)
		_draw_line_to(entry, qte.is_busy())
	draw_set_transform(GRIP, get_rod_angle())
	draw_texture(ROD, -GRIP)
	draw_set_transform(Vector2.ZERO)
	if qte.phase in [DirectionFishing.Phase.WAITING, DirectionFishing.Phase.REELING, DirectionFishing.Phase.FEEDBACK]:
		_draw_timing_frame()
	if qte.phase == DirectionFishing.Phase.REELING and not paused:
		_draw_arrow(Vector2(282, 133), DirectionFishing.VECTORS[qte.get_expected_direction()])
	if qte.phase == DirectionFishing.Phase.CAUGHT:
		_draw_catch()


func _draw_line_to(entry: Vector2, ripple: bool) -> void:
	var tip := get_rod_tip()
	var points := PackedVector2Array()
	var slack := 2.0 if qte.phase == DirectionFishing.Phase.REELING else 6.0
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
		if qte.phase == DirectionFishing.Phase.REELING:
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
	if qte.phase == DirectionFishing.Phase.REELING:
		var direction: Vector2 = DirectionFishing.VECTORS[qte.fish_direction]
		var edge := TIMING_FRAME.get_center() + direction * TIMING_FRAME.size * 0.5
		var tangent := Vector2(-direction.y, direction.x)
		draw_line(edge - tangent * 6, edge + tangent * 6, GOLD if perfect else MINT, 2)


func _draw_arrow(center: Vector2, direction: Vector2) -> void:
	var shape := [Vector2(-9, -2), Vector2(1, -2), Vector2(1, -6), Vector2(10, 0), Vector2(1, 6), Vector2(1, 2), Vector2(-9, 2)]
	var points := PackedVector2Array()
	for point in shape:
		points.append((center + point.rotated(direction.angle())).round())
	draw_colored_polygon(points, MINT)


func _draw_catch() -> void:
	# A small version of the original demo's revealed fish and bone ribs.
	var center := Vector2(164, 137 + roundf(sin(clock * 2.0)))
	var color: Color = DirectionFishing.FISH[qte.fish_index]["color"]
	draw_colored_polygon(PackedVector2Array([center + Vector2(10, 0), center + Vector2(17, -7), center + Vector2(17, 7)]), color.darkened(0.2))
	draw_rect(Rect2(center + Vector2(-11, -4), Vector2(22, 8)), color)
	draw_rect(Rect2(center + Vector2(-7, -6), Vector2(14, 12)), color)
	draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), color.lightened(0.4))
	for x in [-3, 1, 5]:
		draw_line(center + Vector2(x, -3), center + Vector2(x + 1, 3), color.lightened(0.35))
	draw_rect(Rect2(center + Vector2(-8, -2), Vector2(2, 2)), Color("142d35"))
