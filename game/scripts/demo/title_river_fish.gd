extends Control
## Title-only animation, with all painted pixels locked to the stage's 3px grid.

const Surface := preload("res://scripts/demo/title_screen_fx.gd")
const Audio := preload("res://scripts/demo/demo_audio.gd")
const GRID := 3.0
const GRAVITY := 615.0
const COLORS := [Color("46f2e2"), Color("7ecbff"), Color("f4a3c8")]
const WATER_SHADE := Color("174c5a")
const BONE := Color("fff8dc")
# Cover depth, fraction of the round trip, and horizontal speed.
const SWIMMERS := [Vector3(153, 0.22, 19), Vector3(169, 0.84, 24), Vector3(181, 0.31, 27),
	Vector3(194, 0.13, 30), Vector3(204, 0.62, 34), Vector3(214, 0.27, 39), Vector3(222, 0.91, 42)]
const SWIM_MARGIN := 9.0 * GRID
const BODY := [
	"   s    ",
	"  s++s  ",
	"s+++++ss",
	"+++++@++",
	" ss++++s",
	"   sss  ",
	"    s   ",
]
const TAIL := [
	["s   ", "ss  ", " ++ ", "  ss", " ss ", " s  ", "    "],
	["    ", "s   ", "ss  ", " ++s", " ss ", "ss  ", "    "],
	["    ", " s  ", " ss ", "  ss", " ++ ", "ss  ", "s   "],
]

var _surface: Surface
var _audio: Audio
var _time := 0.0
var _swim_turns := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _jumps: Array[Jump] = []
var _bursts: Array[Burst] = []


class Jump:
	var origin: Vector2
	var velocity: Vector2
	var airtime: float
	var age := 0.0
	var tint: Color

	func offset(gravity: float) -> Vector2:
		return velocity * age + Vector2(0, 0.5 * gravity * age * age)


class Burst:
	var origin: Vector2
	var tint: Color
	var landing: bool
	var age := 0.0
	var droplets := PackedVector3Array()


func setup(surface: Surface, audio: Audio) -> void:
	_surface = surface
	_audio = audio
	size = surface.size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	for lane: Vector3 in SWIMMERS:
		var shore := 0.0
		for offset in range(-5, 6):
			shore = maxf(shore, surface.water_start(lane.x + offset))
		_swim_turns.append(shore + SWIM_MARGIN)
	visibility_changed.connect(_clear_when_hidden)


func _has_point(point: Vector2) -> bool:
	return _surface != null and _surface.water_at(point)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _surface.water_at(event.position):
			return
		_launch(event.position)
		accept_event()


func _launch(origin: Vector2) -> void:
	var fish := Jump.new()
	fish.origin = origin
	fish.velocity.y = -_rng.randf_range(220.0, 297.0)
	fish.airtime = -2.0 * fish.velocity.y / GRAVITY
	var speed := _rng.randf_range(104.0, 174.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	var edge_speed := GRID * 0.25 / fish.airtime
	for candidate: float in [speed, -speed, speed * 0.25, -speed * 0.25, edge_speed, -edge_speed]:
		var travel := Vector2(candidate * fish.airtime, 0)
		if _surface.water_at(origin + travel) and _surface.water_at(origin + travel * 0.5):
			fish.velocity.x = candidate
			break
	fish.tint = COLORS[_rng.randi_range(0, COLORS.size() - 1)]
	_jumps.append(fish)
	_add_burst(origin, fish.tint, false)


func _add_burst(origin: Vector2, tint: Color, landing: bool) -> void:
	var burst := Burst.new()
	burst.origin = origin
	burst.tint = tint
	burst.landing = landing
	for i in (12 if landing else 6):
		var vx := _rng.randf_range(-96.0, 96.0) if landing else _rng.randf_range(-33.0, 33.0)
		var vy := _rng.randf_range(-154.0, -61.0) if landing else _rng.randf_range(-54.0, -28.0)
		burst.droplets.append(Vector3(vx, vy, _rng.randf_range(0.36, 0.61)))
	_bursts.append(burst)


func _clear_when_hidden() -> void:
	if not is_visible_in_tree():
		_jumps.clear()
		_bursts.clear()
		_audio.stop(Audio.Cue.TITLE_FISH_SPLASH)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i].age += delta
		if _bursts[i].age >= 0.9:
			_bursts.remove_at(i)
	for i in range(_jumps.size() - 1, -1, -1):
		var fish := _jumps[i]
		fish.age = minf(fish.age + delta, fish.airtime)
		if fish.age >= fish.airtime:
			var landing := fish.origin + Vector2(fish.velocity.x * fish.airtime, 0)
			_add_burst(landing, fish.tint, true)
			_jumps.remove_at(i)
			_audio.play(Audio.Cue.TITLE_FISH_SPLASH)
	queue_redraw()


func _draw() -> void:
	if _surface == null:
		return
	for i in SWIMMERS.size():
		var swimmer := _swimmer_pose(i)
		var frame := floori(_time * 5.0 + i) % TAIL.size()
		var tint := Color(COLORS[i % COLORS.size()], 0.36 + 0.09 * sin(_time * 1.7 + i * 1.6))
		var point := Vector2(swimmer.x, swimmer.y)
		_glow(point, tint)
		_draw_fish(point, swimmer.z, frame, tint, true)
	for burst in _bursts:
		_draw_burst(burst)
	for fish in _jumps:
		var frame := floori(fish.age * 16.0) % TAIL.size()
		_draw_fish(fish.origin + fish.offset(GRAVITY), fish.velocity.x, frame, fish.tint, false)


func _swimmer_pose(index: int) -> Vector3:
	var lane: Vector3 = SWIMMERS[index]
	var left := _swim_turns[index]
	var leg := size.x + SWIM_MARGIN - left
	var distance := fposmod(lane.y * 2.0 * leg + _time * lane.z, 2.0 * leg)
	var x := left + absf(distance - leg)
	var y := _surface.cover_to_stage(Vector2(0, lane.x)).y
	y += sin(_time * (1.6 + index * 0.12) + index * 2.0) * (3.0 + index * 0.55)
	return Vector3(x, y, -1.0 if distance < leg else 1.0)


func _glow(center: Vector2, tint: Color) -> void:
	for row in range(-3, 4):
		var half_width := floori(8.0 * sqrt(maxf(0.0, 1.0 - pow(row / 3.6, 2.0))))
		for column in range(-half_width, half_width + 1):
			var alpha := (0.08 + 0.12 * (1.0 - absf(column) / 9.0)) * tint.a
			_pixel(center + Vector2(column, row) * GRID, GRID, Color(tint, alpha), true)


func _draw_fish(center: Vector2, facing: float, frame: int, tint: Color, submerged: bool) -> void:
	var palette := {
		"s": Color(tint.lerp(WATER_SHADE, 0.60), tint.a),
		"+": tint,
		"@": Color(tint.lerp(BONE, 0.82), tint.a),
	}
	var direction := -1.0 if facing < 0.0 else 1.0
	for y in BODY.size():
		var body: String = BODY[y]
		var tail: String = TAIL[frame][y]
		var row := tail + body
		for x in row.length():
			var value := row[x]
			if value != " ":
				_pixel(center + Vector2((x - 6) * direction, y - 3) * GRID, GRID, palette[value], submerged)


func _draw_burst(burst: Burst) -> void:
	var age := burst.age / 0.9
	var opacity := (1.0 - age) * (0.78 if burst.landing else 0.64)
	_draw_ring(burst.origin, age, Color(burst.tint, opacity))
	if age > 0.20:
		_draw_ring(burst.origin, (age - 0.20) / 0.80, Color(burst.tint, opacity * 0.52))
	for i in burst.droplets.size():
		var droplet := burst.droplets[i]
		if burst.age >= droplet.z:
			continue
		var drift := Vector2(droplet.x, droplet.y) * burst.age
		if burst.landing:
			drift.y += 0.5 * GRAVITY * burst.age * burst.age
			if drift.y > 0.0:
				continue
		var tint := burst.tint.lerp(BONE, 0.62 if i % 3 == 0 else 0.16)
		_pixel(burst.origin + drift, GRID, Color(tint, (1.0 - burst.age / droplet.z) * 0.86), false)


func _draw_ring(center: Vector2, age: float, tint: Color) -> void:
	var radius := roundi(2.0 + 17.0 * age)
	var depth := roundi(1.0 + 4.0 * age)
	for y in range(-depth, depth + 1):
		var outer := floori(radius * sqrt(maxf(0.0, 1.0 - pow(float(y) / depth, 2.0))))
		var inner := floori(radius * sqrt(maxf(0.0, 1.0 - pow((absf(y) + 1.0) / depth, 2.0))))
		for x in range(mini(inner + 1, outer), outer + 1):
			_pixel(center + Vector2(x, y) * GRID, GRID, tint, true)
			if x > 0:
				_pixel(center + Vector2(-x, y) * GRID, GRID, tint, true)


func _pixel(point: Vector2, step: float, tint: Color, water_only: bool) -> void:
	var aligned := point.snapped(Vector2.ONE * GRID)
	if not water_only or _surface.water_at(aligned, step):
		draw_rect(Rect2(aligned, Vector2.ONE * step), tint)
