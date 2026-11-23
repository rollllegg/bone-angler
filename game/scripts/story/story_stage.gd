extends Node
## Applies story cues to the shop view: props, camera shake/zoom and screen flash/fade.
## Screen colours sit below the UI, so dialogue and buttons stay readable.

const Catalog := preload("res://scripts/story/story_cue_catalog.gd")
const PropLayer := preload("res://scripts/story/story_prop_layer.gd")

const SHOP_CENTER := Vector2(202.5, 121.5)

var _shop = null
var _props = null
var _screen: Control = null
var _flash: ColorRect = null
var _fade: ColorRect = null

var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _clock := 0.0

var _shake_remaining := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0

var _zoom_scale := 1.0
var _zoom_start := 1.0
var _zoom_target := 1.0
var _zoom_elapsed := 0.0
var _zoom_duration := 0.0

var _flash_base_alpha := 0.0
var _flash_elapsed := 0.0
var _flash_duration := 0.0
var _flash_color := Color.WHITE

var _fade_from := 0.0
var _fade_target := 0.0
var _fade_elapsed := 0.0
var _fade_duration := 0.0
var _fade_color := Color.BLACK


func bind(shop: Node2D, screen: Control) -> void:
	_shop = shop
	_screen = screen
	_base_position = shop.position
	_base_scale = shop.scale
	_props = PropLayer.new()
	if _shop.has_method("bind_story_props"):
		_shop.bind_story_props(_props)
	_flash = ColorRect.new()
	_flash.name = "StoryFlash"
	_flash.size = screen.size
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(_flash_color, 0.0)
	screen.add_child(_flash)
	_fade = ColorRect.new()
	_fade.name = "StoryFade"
	_fade.size = screen.size
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(_fade_color, 0.0)
	screen.add_child(_fade)
	set_process(true)


func begin_cue(cue: Dictionary, duration: float) -> void:
	match str(cue.get("type", "")):
		"shake":
			_start_shake(float(cue.get("strength", 4.0)), duration)
		"flash":
			_start_flash(_cue_color(cue, Color.WHITE), duration, float(cue.get("alpha", 0.55)))
		"fade":
			var color := _cue_color(cue, Color.BLACK)
			var from_value := float(cue.get("from", color.a if color.a > 0.0 else _fade.color.a))
			var to_value := float(cue.get("to", 1.0))
			_start_fade(color, from_value, to_value, duration)
		"zoom":
			_start_zoom(float(cue.get("scale", 1.0)), duration)
		"prop":
			_apply_prop(cue)
		"sprite":
			_apply_sprite(cue)


func finish_cue(cue: Dictionary) -> void:
	match str(cue.get("type", "")):
		"shake":
			_shake_remaining = 0.0
			_update_transform()
		"flash":
			if _flash != null:
				_flash.color = Color(_flash_color, 0.0)
			_flash_elapsed = _flash_duration
		"fade":
			if _fade != null:
				_fade.color = Color(_fade_color, _fade_target)
			_fade_elapsed = _fade_duration
		"zoom":
			_zoom_scale = _zoom_target
			_zoom_elapsed = _zoom_duration
			_update_transform()
		"prop":
			_apply_prop(cue)


func reset() -> void:
	if _props != null:
		_props.clear()
	if _shop != null and _shop.has_method("clear_story_sprite"):
		_shop.clear_story_sprite()
	_refresh_shop()
	_flash_base_alpha = 0.0
	_flash_elapsed = 0.0
	_flash_duration = 0.0
	if _flash != null:
		_flash.color = Color(_flash_color, 0.0)
	_fade_from = 0.0
	_fade_target = 0.0
	_fade_elapsed = 0.0
	_fade_duration = 0.0
	if _fade != null:
		_fade.color = Color(_fade_color, 0.0)
	_shake_remaining = 0.0
	_shake_duration = 0.0
	_shake_strength = 0.0
	_zoom_scale = 1.0
	_zoom_start = 1.0
	_zoom_target = 1.0
	_zoom_elapsed = 0.0
	_zoom_duration = 0.0
	_update_transform()


func has_prop(id: String) -> bool:
	return _props != null and _props.has_prop(id)


func get_prop_ids() -> Array:
	return [] if _props == null else _props.get_prop_ids()


func is_shaking() -> bool:
	return _shake_remaining > 0.0


func get_flash_alpha() -> float:
	return 0.0 if _flash == null else _flash.color.a


func get_fade_alpha() -> float:
	return 0.0 if _fade == null else _fade.color.a


func get_zoom_scale() -> float:
	return _zoom_scale


func _process(delta: float) -> void:
	_clock += delta
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - delta, 0.0)
	if _zoom_duration > 0.0 and _zoom_elapsed < _zoom_duration:
		_zoom_elapsed = minf(_zoom_elapsed + delta, _zoom_duration)
		var zoom_t := smoothstep(0.0, 1.0, _zoom_elapsed / _zoom_duration)
		_zoom_scale = lerpf(_zoom_start, _zoom_target, zoom_t)
	elif _zoom_duration <= 0.0:
		_zoom_scale = _zoom_target
	if _flash_duration > 0.0 and _flash_elapsed < _flash_duration and _flash != null:
		_flash_elapsed = minf(_flash_elapsed + delta, _flash_duration)
		var flash_t := _flash_elapsed / _flash_duration
		_flash.color = Color(_flash_color, _flash_base_alpha * (1.0 - flash_t))
	if _fade_duration > 0.0 and _fade_elapsed < _fade_duration and _fade != null:
		_fade_elapsed = minf(_fade_elapsed + delta, _fade_duration)
		var fade_t := smoothstep(0.0, 1.0, _fade_elapsed / _fade_duration)
		_fade.color = Color(_fade_color, lerpf(_fade_from, _fade_target, fade_t))
	_update_transform()


func _start_shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(strength, 0.0)
	_shake_duration = maxf(duration, 0.01)
	_shake_remaining = _shake_duration


func _start_flash(color: Color, duration: float, alpha: float) -> void:
	_flash_color = color
	_flash_base_alpha = clampf(alpha, 0.0, 1.0)
	_flash_duration = maxf(duration, 0.0)
	_flash_elapsed = 0.0
	if _flash != null:
		_flash.color = Color(_flash_color, 0.0 if _flash_duration <= 0.0 else _flash_base_alpha)


func _start_fade(color: Color, from_value: float, to_value: float, duration: float) -> void:
	_fade_color = color
	_fade_from = clampf(from_value, 0.0, 1.0)
	_fade_target = clampf(to_value, 0.0, 1.0)
	_fade_duration = maxf(duration, 0.0)
	_fade_elapsed = 0.0
	if _fade != null:
		_fade.color = Color(_fade_color, _fade_target if _fade_duration <= 0.0 else _fade_from)


func _start_zoom(scale: float, duration: float) -> void:
	_zoom_start = _zoom_scale
	_zoom_target = maxf(scale, 0.5)
	_zoom_duration = maxf(duration, 0.0)
	_zoom_elapsed = 0.0
	if _zoom_duration <= 0.0:
		_zoom_scale = _zoom_target
		_update_transform()


func _apply_prop(cue: Dictionary) -> void:
	if _props == null:
		return
	var id := str(cue.get("id", ""))
	if not Catalog.has_prop(id):
		return
	if str(cue.get("action", "show")) == "hide":
		_props.hide_prop(id)
		_refresh_shop()
		return
	var point := Catalog.default_position(id)
	if cue.has("position"):
		var raw = cue.position
		if raw is Array and raw.size() >= 2:
			point = Vector2(float(raw[0]), float(raw[1]))
		elif raw is Vector2:
			point = raw
	_props.show_prop(id, point, float(cue.get("scale", 1.0)))
	_refresh_shop()


func _apply_sprite(cue: Dictionary) -> void:
	if _shop == null or not _shop.has_method("set_story_sprite"):
		return
	var id := str(cue.get("id", ""))
	if id == "":
		return
	_shop.set_story_sprite(id, bool(cue.get("flip", false)))


func ensure_story_sprite(id: String) -> void:
	if id == "" or _shop == null or not _shop.has_method("set_story_sprite"):
		return
	if _shop.has_method("has_story_sprite") and _shop.has_story_sprite():
		return
	_shop.set_story_sprite(id)


func _refresh_shop() -> void:
	if _shop != null:
		_shop.queue_redraw()


func _cue_color(cue: Dictionary, fallback: Color) -> Color:
	var raw := str(cue.get("color", ""))
	if raw == "":
		return fallback
	return Color.from_string(raw, fallback)


func _update_transform() -> void:
	if _shop == null:
		return
	var offset := Vector2.ZERO
	var shake_scale := 1.0
	if _shake_remaining > 0.0 and _shake_strength > 0.0:
		var progress := 1.0 - _shake_remaining / _shake_duration
		var amplitude := _shake_strength * (1.0 - progress)
		offset = Vector2(sin(_clock * 83.0), cos(_clock * 61.0)) * amplitude
		shake_scale = 1.04
	var total_scale := _zoom_scale * shake_scale
	_shop.scale = _base_scale * total_scale
	_shop.position = _base_position + SHOP_CENTER * (1.0 - total_scale) + offset
