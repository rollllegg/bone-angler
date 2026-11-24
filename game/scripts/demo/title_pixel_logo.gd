extends Control
## Each stroke is drawn at the font's native 12px, then enlarged by integer scales.

const FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
const TITLE := "骨灰级钓手"
const SUBTITLE := ["Skeletons Have Incredible", "Fishing Talent"]
const INK := Color("161221")
const CREAM := Color("f7ecd2")
const CENTER_X := 1170.0
const BONE_PIXEL := 4
const BONE_OUTLINE := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
const BONE := [
	"   ##        ",
	"## ###       ",
	"######       ",
	" #####       ",
	"   ####      ",
	"     ####    ",
	"       ####  ",
	"        #####",
	"       ######",
	"       ## ###",
	"           ##",
]

var _bone_x := 0.0


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pixel_font := FONT.duplicate() as FontFile
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	pixel_font.oversampling = 1.0
	pixel_font.keep_rounding_remainders = false

	var lettering := FontVariation.new()
	lettering.base_font = pixel_font
	lettering.spacing_glyph = 1
	var main := _add_line(TITLE, lettering, 166.0, 8.0)
	_bone_x = main.position.x - 34.0
	for i in SUBTITLE.size():
		_add_line(SUBTITLE[i], lettering, 285.0 + i * 39.0, 3.0)


func _add_line(caption: String, font: FontVariation, top: float, magnification: float) -> PixelLine:
	var line := PixelLine.new()
	line.caption = caption
	line.font = font
	line.position = Vector2(roundf(CENTER_X - font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * magnification * 0.5), top)
	line.scale = Vector2.ONE * magnification
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	return line


func _draw() -> void:
	for side: float in [-1.0, 1.0]:
		var center := CENTER_X + side * (CENTER_X - _bone_x)
		var origin := Vector2(roundf(center - BONE[0].length() * BONE_PIXEL * 0.5), 199.0)
		var pixels := PackedVector2Array()
		for y in BONE.size():
			for x in BONE[y].length():
				if BONE[y][x] == "#":
					var column: int = x if side < 0.0 else BONE[y].length() - 1 - x
					pixels.append(origin + Vector2(column, y) * BONE_PIXEL)
		for pixel in pixels:
			for offset: Vector2 in BONE_OUTLINE:
				draw_rect(Rect2(pixel + offset * BONE_PIXEL, Vector2.ONE * BONE_PIXEL), INK)
		for pixel in pixels:
			draw_rect(Rect2(pixel, Vector2.ONE * BONE_PIXEL), CREAM)


class PixelLine extends Control:
	var caption: String
	var font: FontVariation

	func _draw() -> void:
		var baseline := Vector2(0, roundf(font.get_ascent(12)))
		_paint(baseline + Vector2(0, 2), Color(INK, 0.83))
		_paint(baseline + Vector2(1, 2), Color(INK, 0.83))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx != 0 or dy != 0:
					_paint(baseline + Vector2(dx, dy), INK)
		_paint(baseline, CREAM)

	func _paint(baseline: Vector2, tint: Color) -> void:
		draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
