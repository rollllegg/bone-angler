extends Control
## Landmarks, the river silhouette, and ambient details use cover pixels.

const COVER := preload("res://assets/art/demo/cover.png")
const SKY := Color("2e2a4b")
const INK := Color("161221")
const AMBER := Color("ff9d3b")
const GOLD := Color("f5cc66")
const SOUL := Color("46f2e2")
const MINT := Color("7fe8c8")
const BONE := Color("fff8dc")
const LANTERN := Vector2(82, 205)
const GATE := Vector2(203, 121)
const CAULDRON := Vector2(36, 118)
const FERRY := Vector2(344, 132)
const FLOAT := Vector2(303, 226)
const ROD_TIP := Vector2(246, 107)
const FLOAT_PIXELS := [
	"    i    ", "    h    ", "    h    ", "    c    ", "   ici   ",
	"  ihhci  ", " ihhhcci ", " ihcccai ", " iccaaai ", "  iaaai  ", "   iii   ",
]
const FLOAT_COLORS := {"i": INK, "h": BONE, "c": Color("f7ecd2"), "a": Color("b67b48")}
const WATER_TOP := 137
const STARS := [Vector2(17, -11), Vector2(56, -5), Vector2(112, -9), Vector2(168, -12),
	Vector2(219, -5), Vector2(271, -11), Vector2(328, -7), Vector2(376, -10), Vector2(441, -4)]

# Traced from cover.png. Each pair is (row, first water column).
const SHORE := [Vector2(136, 271), Vector2(137, 264), Vector2(139, 262), Vector2(142, 257),
	Vector2(146, 252), Vector2(148, 252), Vector2(155, 242), Vector2(163, 233),
	Vector2(171, 221), Vector2(179, 211), Vector2(188, 199), Vector2(197, 189),
	Vector2(203, 183), Vector2(210, 184), Vector2(219, 177), Vector2(226, 175),
	Vector2(233, 179), Vector2(238, 184), Vector2(243, 184), Vector2(244, 181),
	Vector2(245, 167), Vector2(250, 164), Vector2(251, 118), Vector2(257, 111),
	Vector2(261, 106), Vector2(265, 103), Vector2(267, 98)]
# A sliver of water opens between the stone edge and the nearer boot.
const BOOT_GAP := [Vector3(234, 142, 144), Vector3(236, 141, 143), Vector3(239, 133, 144),
	Vector3(243, 130, 148), Vector3(246, 125, 151), Vector3(250, 119, 155)]
const FERRY_HULL := Rect2(335, 136, 23, 3)
const WAVE_COLORS := [Color("1e5f64"), Color("3f9b99"), MINT, Color("e5c58e")]
const WAVE_DEPTHS := [Vector4(137, 171, 1.9, 9), Vector4(171, 218, 3.7, 17), Vector4(218, 267, 6.4, 29)]
const WAVE_COUNTS := [26, 30, 30]

var _cover_rect: Rect2
var _pixel_size: float
var _time := 0.0
var _parallax := Vector2.ZERO
var _drift: Array[Vector4] = []
var _waves: Array[Vector4] = []
var _water_rows := PackedVector3Array()


func setup(stage_size: Vector2) -> void:
	size = stage_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pixel_size = stage_size.x / COVER.get_width()
	var cover_height := COVER.get_height() * _pixel_size
	_cover_rect = Rect2(0, stage_size.y - cover_height, stage_size.x, cover_height)
	_water_rows.resize(COVER.get_height())
	var gap_segment := 0
	for y in range(WATER_TOP, COVER.get_height()):
		var row := Vector3(ceilf(_edge_x(SHORE, y)), 0, 0)
		if y >= BOOT_GAP[0].x and y <= BOOT_GAP[-1].x:
			while y > BOOT_GAP[gap_segment + 1].x:
				gap_segment += 1
			var first: Vector3 = BOOT_GAP[gap_segment]
			var last: Vector3 = BOOT_GAP[gap_segment + 1]
			var gap := first.lerp(last, inverse_lerp(first.x, last.x, y))
			row.y = ceilf(gap.y)
			row.z = floorf(gap.z)
		_water_rows[y] = row

	var rng := RandomNumberGenerator.new()
	rng.seed = 418235
	for i in 12:
		_drift.append(Vector4(rng.randf_range(7, 408), rng.randf_range(12, 132), rng.randf(), rng.randf()))
	for depth in WAVE_DEPTHS.size():
		var band: Vector4 = WAVE_DEPTHS[depth]
		for i in WAVE_COUNTS[depth]:
			_waves.append(Vector4(rng.randf_range(0.0, COVER.get_width()), rng.randf_range(band.x, band.y),
				rng.randf_range(0.38, 1.0), rng.randf()))


func cover_to_stage(point: Vector2) -> Vector2:
	return _cover_rect.position + point * _pixel_size


func water_start(cover_y: float) -> float:
	return cover_to_stage(Vector2(_water_rows[floori(cover_y)].x, cover_y)).x


func water_at(point: Vector2, footprint: float = 0.0) -> bool:
	var start := (point - _cover_rect.position) / _pixel_size
	var end := start + Vector2.ONE * (maxf(footprint - 0.001, 0.0) / _pixel_size)
	if start.x < 0.0 or end.x >= COVER.get_width() or start.y < WATER_TOP or end.y >= COVER.get_height():
		return false
	if Rect2(start, end - start + Vector2(0.001, 0.001)).intersects(FERRY_HULL):
		return false
	for y in range(floori(start.y), floori(end.y) + 1):
		var row := _water_rows[y]
		if start.x < row.x and (start.x < row.y or end.x >= row.z):
			return false
	return true


func _edge_x(points: Array, y: float) -> float:
	for index in range(1, points.size()):
		var last: Vector2 = points[index]
		if y <= last.x:
			var first: Vector2 = points[index - 1]
			return lerpf(first.y, last.y, inverse_lerp(first.x, last.x, y))
	return points[-1].y


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var target := ((get_local_mouse_position() / size) * 2.0 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
	_parallax = _parallax.lerp(target, 1.0 - exp(-delta * 4.0))
	queue_redraw()


func _draw() -> void:
	if _pixel_size <= 0.0:
		return
	_draw_sky()
	draw_texture_rect(COVER, _cover_rect, false)
	_draw_lights()
	var bobber := _float_position()
	_draw_water(bobber)
	_draw_rig(bobber)
	_draw_drift()
	_draw_vignette()


func _draw_sky() -> void:
	var height := ceilf(_cover_rect.position.y)
	if height <= 0.0:
		return
	# Join the sky at the seam and carry the cropped roof's diagonal toward the top edge.
	draw_rect(Rect2(0, 0, size.x, height), SKY)
	var band_count := ceili(height / _pixel_size / 2.0)
	for band in band_count:
		var y := float(band - band_count) * 2.0
		var top := cover_to_stage(Vector2(0, y)).y
		var bottom := cover_to_stage(Vector2(0, y + 2.0)).y
		var band_rect := Rect2(0, roundf(top), size.x, roundf(bottom) - roundf(top))
		var fade := pow(float(band_count - 1 - band) / maxf(band_count - 1, 1.0), 1.35)
		var roof_shift := floorf((-y - 2.0) * 0.67)
		var roof_width := 118.0 - roof_shift
		var roof_band := Rect2(band_rect.position, Vector2(roundf(roof_width * _pixel_size), band_rect.size.y))
		draw_texture_rect_region(COVER, roof_band, Rect2(roof_shift, 0, roof_width, 1), Color(1, 1, 1, 1.0 - fade * 0.42))
		var sky_band := Rect2(roof_band.end.x, band_rect.position.y, size.x - roof_band.end.x, band_rect.size.y)
		draw_texture_rect_region(COVER, sky_band, Rect2(118, 0, COVER.get_width() - 118, 1), Color(1, 1, 1, 1.0 - fade))
		draw_rect(band_rect, Color(INK, fade * 0.13))
	for index in STARS.size():
		var pulse := 0.5 + 0.5 * sin(_time * (0.74 + index * 0.07) + index * 2.3)
		_pixel(STARS[index], Vector2.ONE, Color(BONE if index % 3 == 0 else MINT, 0.07 + 0.26 * pulse * pulse))


func _draw_lights() -> void:
	var flicker := 0.76 + 0.13 * sin(_time * 3.7) + 0.08 * sin(_time * 8.9 + 1.2)
	_glow(LANTERN, Vector2(18, 12), AMBER, 0.065 * flicker)
	_glow(LANTERN, Vector2(10, 8), AMBER, 0.115 * flicker)
	_glow(LANTERN, Vector2(5, 4), GOLD, 0.22 * flicker)
	var breath := 0.72 + 0.28 * sin(_time * 1.62 + 0.5)
	_glow(GATE, Vector2(10, 15), SOUL, 0.10 * breath)
	_glow(GATE + Vector2(0, 2), Vector2(5, 10), SOUL, 0.17 * breath)
	for i in 2:
		_ember(LANTERN, _time + i * 2.3 + 0.95, 4.9 + i * 0.6, 1.55, i * 3.0, GOLD)
		_ember(GATE, _time + i * 2.98 + 1.28, 6.5 + i * 0.75, 1.9, i * 4.0, SOUL)
	for i in 4:
		var age := fposmod(_time * 0.23 + i * 0.25, 1.0)
		var offset := Vector2(sin(age * 5.0 + i * 1.3) * (1.0 + age * 4.0), -age * 22.0)
		var opacity := sin(age * PI) * 0.19
		_glow(CAULDRON + offset, Vector2(1.0 + floorf(age * 3.0), 1.0 + floorf(age * 2.0)), MINT, opacity)
	var ferry_light := 0.55 + 0.45 * sin(_time * 1.3 + 0.6)
	_glow(FERRY, Vector2(4, 3), AMBER, 0.09 * ferry_light)
	_pixel(FERRY, Vector2.ONE, Color(GOLD, 0.58 * ferry_light))
	_water_strip(FERRY + Vector2(-3 - roundf(ferry_light), 9), 5.0, Color(GOLD, 0.14 * ferry_light))
	_water_strip(FERRY + Vector2(-2, 11), 3.0, Color(AMBER, 0.08 * ferry_light))


func _glow(center: Vector2, radius: Vector2, color: Color, alpha: float) -> void:
	var rows := int(radius.y)
	for y in range(-rows, rows + 1):
		var half_width := floorf(radius.x * sqrt(maxf(0.0, 1.0 - pow(float(y) / (radius.y + 0.5), 2.0))))
		_pixel(center + Vector2(-half_width, y), Vector2(half_width * 2 + 1, 1), Color(color, alpha))


func _ember(origin: Vector2, clock: float, cycle: float, lifetime: float, phase: float, tint: Color) -> void:
	var age := fposmod(clock, cycle) / lifetime
	if age <= 1.0:
		var offset := Vector2(sin(age * 4.0 + phase) * 3.0 + phase * 0.5, -5.0 - age * 16.0)
		_pixel(origin + offset, Vector2.ONE, Color(tint, 0.64 * sin(age * PI)))


func _draw_water(bobber: Vector2) -> void:
	var wave_index := 0
	for depth in WAVE_DEPTHS.size():
		var band: Vector4 = WAVE_DEPTHS[depth]
		for i in WAVE_COUNTS[depth]:
			var wave := _waves[wave_index]
			wave_index += 1
			var width := roundf(2.0 + band.w * wave.z)
			var distance := COVER.get_width() + width * 2.0
			var x := fposmod(wave.x + _time * band.z * (0.70 + wave.z * 0.60), distance) - width
			var pulse := 0.50 + 0.50 * sin(_time * (0.72 + wave.z) + wave.w * TAU)
			var tint: Color = WAVE_COLORS[3 if i == 0 else (i % 3)]
			var opacity := (0.12 + 0.13 * pulse) * (1.0 if i % 3 < 2 else 0.58)
			_water_strip(Vector2(x, wave.y), width, Color(tint, opacity))
			if depth > 0 and i % 4 == 1:
				_water_strip(Vector2(x + 2.0, wave.y + 1.0), floorf(width * 0.68), Color(tint, opacity * 0.38))

	for y in range(142, COVER.get_height() - 1, 2):
		# The visible shore leaves the main span where the character meets the water.
		if y >= 203 and y < 234:
			continue
		var row := _water_rows[y]
		var x := row.y if y <= 250 and row.z > row.y else row.x
		var pulse := maxf(0.0, sin(y * 0.34 - _time * 1.65))
		if pulse > 0.08:
			_water_strip(Vector2(x + 1.0, y), 1.0, Color(MINT, pulse * 0.24))

	for ring in 3:
		var age := fposmod(_time + 1.0 - ring * 0.72, 3.3) / 2.6
		if age >= 1.0:
			continue
		var radius := 4.0 + age * 24.0
		var depth := 1.0 + age * 6.0
		var tint := Color(MINT, 0.51 * sin(age * PI))
		for x in range(-floori(radius), floori(radius) + 1):
			var dy := roundf(depth * sqrt(maxf(0.0, 1.0 - pow(x / radius, 2.0))))
			_water_strip(bobber + Vector2(x, dy), 1.0, tint)
			if dy > 0:
				_water_strip(bobber + Vector2(x, -dy), 1.0, Color(tint, tint.a * 0.62))


func _float_position() -> Vector2:
	return FLOAT + Vector2(roundf(sin(_time * 1.55) * 2.4),
		roundf(sin(_time * 2.1 + 0.4) + 0.35 * sin(_time * 4.2)))


func _line_point(progress: float, attachment: Vector2) -> Vector2:
	var point := ROD_TIP.lerp(attachment, progress)
	var sway := 2.5 * sin(_time * 1.55 - progress * 3.0) + sin(_time * 2.9 - progress * 8.0)
	point.x += sin(progress * PI) * (-15.0 + sway)
	return point.round()


func _draw_rig(bobber: Vector2) -> void:
	var attachment := bobber + Vector2(-3, -2)
	var travel := roundi(attachment.y - ROD_TIP.y)
	var last := ROD_TIP
	for row in range(1, travel + 1):
		var progress := float(row) / travel
		var point := _line_point(progress, attachment)
		var glint := pow(maxf(0.0, sin(progress * 15.0 - _time * 3.2)), 8.0)
		var tint := Color(Color("a2eff0").lerp(BONE, glint * 0.65), 0.87)
		var start := Vector2(minf(last.x + 1.0, point.x), point.y)
		_pixel(start, Vector2(maxf(last.x - 1.0, point.x) - start.x + 1.0, 1), tint)
		last = point

	var tilt := roundf(sin(_time * 1.55 - 0.9))
	for y in FLOAT_PIXELS.size():
		var shape: String = FLOAT_PIXELS[y]
		var lean := roundf(tilt * maxf(0.0, 1.0 - y / 8.0))
		for x in shape.length():
			if shape[x] != " ":
				_pixel(bobber + Vector2(x - 4 + lean, y - 8), Vector2.ONE, FLOAT_COLORS[shape[x]])
	_water_strip(bobber + Vector2(-5, 3), 11.0, Color(MINT, 0.30))


func _water_strip(origin: Vector2, width: float, tint: Color) -> void:
	var y := roundi(origin.y)
	if y < WATER_TOP or y >= COVER.get_height():
		return
	var start := roundf(origin.x)
	var end := start + width
	var row := _water_rows[y]
	if row.z > row.y:
		_strip_span(y, maxf(start, row.y), minf(end, row.z), tint)
	start = maxf(start, row.x)
	end = minf(end, COVER.get_width())
	if y < FERRY_HULL.end.y:
		_strip_span(y, start, minf(end, FERRY_HULL.position.x), tint)
		start = maxf(start, FERRY_HULL.end.x)
	_strip_span(y, start, end, tint)


func _strip_span(y: int, start: float, end: float, tint: Color) -> void:
	if end > start:
		_pixel(Vector2(start, y), Vector2(end - start, 1), tint)


func _draw_drift() -> void:
	for i in _drift.size():
		var dust := _drift[i]
		var point := Vector2(dust.x + 5.0 * sin(_time * 0.28 + dust.z * TAU),
			fposmod(dust.y - _time * (0.64 + dust.w), 133.0))
		var alpha := (0.13 + 0.18 * sin(_time * 0.52 + dust.z * TAU) ** 2)
		alpha *= clampf(minf(point.y, 133.0 - point.y) / 12.0, 0.0, 1.0)
		if not Rect2(224, 0, 230, 78).has_point(point):
			_pixel(point + _parallax.round(), Vector2.ONE, Color(GOLD if i % 3 == 0 else SOUL, alpha))


func _draw_vignette() -> void:
	for band in 9:
		var alpha := 0.23 * pow(1.0 - float(band) / 9.0, 1.8)
		var side := float(band * 13)
		var edge := float(band * 8)
		draw_rect(Rect2(side, 0, 13, size.y), Color(INK, alpha))
		draw_rect(Rect2(size.x - side - 13, 0, 13, size.y), Color(INK, alpha * 0.70))
		draw_rect(Rect2(0, edge, size.x, 8), Color(INK, alpha * 0.45))
		draw_rect(Rect2(0, size.y - edge - 8, size.x, 8), Color(INK, alpha))


func _pixel(origin: Vector2, extent: Vector2, tint: Color) -> void:
	var start := origin.round()
	var top_left := cover_to_stage(start).round()
	var end := cover_to_stage(start + extent).round()
	draw_rect(Rect2(top_left, end - top_left), tint)
