extends Control
## A modal remains drawable during dismissal after yielding keyboard and mouse input.

const SHADE := Color("161221", 0.69)

var is_open := false
var _shade: ColorRect
var _surface: Panel
var _animation: Tween


func setup_modal(stage_size: Vector2, dismiss_on_backdrop: bool = false) -> void:
	size = stage_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	_shade.size = stage_size
	_shade.color = SHADE
	_shade.modulate.a = 0.0
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	if dismiss_on_backdrop:
		gui_input.connect(_backdrop_input)
	hide()


func present(panel: Panel) -> void:
	if _animation:
		_animation.kill()
	if _surface != panel or not visible:
		if _surface:
			_surface.hide()
		_surface = panel
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2.ONE * 0.94
		panel.modulate.a = 0.0
		_set_offset(14.0)
	is_open = true
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	show()
	panel.show()
	_animation = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_shade, "modulate:a", 1.0, 0.16)
	_animation.tween_property(panel, "modulate:a", 1.0, 0.18)
	_animation.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_animation.tween_method(_set_offset, panel.position.y - _center().y, 0.0, 0.18).set_trans(Tween.TRANS_BACK)


func dismiss() -> void:
	if not is_open:
		return
	is_open = false
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_animation.kill()
	_animation = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_animation.tween_property(_shade, "modulate:a", 0.0, 0.12)
	_animation.tween_property(_surface, "modulate:a", 0.0, 0.12)
	_animation.tween_property(_surface, "scale", Vector2.ONE * 0.94, 0.12)
	_animation.tween_method(_set_offset, _surface.position.y - _center().y, 14.0, 0.12)
	_animation.chain().tween_callback(_finish_dismiss)


func _finish_dismiss() -> void:
	_surface.hide()
	hide()


func _center() -> Vector2:
	return ((size - _surface.size) * 0.5).round()


func _set_offset(offset: float) -> void:
	_surface.position = _center() + Vector2(0, roundf(offset))


func _backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		dismiss()
