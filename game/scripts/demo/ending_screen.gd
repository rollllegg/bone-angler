extends Control
## Final ending card. The reception UI is hidden before this appears, so the
## last shot is only the shop scene, Anubis, the scale and the epilogue.

signal finished

const UI := preload("res://scripts/demo/demo_ui.gd")
const ANUBIS := preload("res://assets/art/story/sprites/anubis.png")
const ANUBIS_TURN := preload("res://assets/art/story/sprites/anubis_turn.png")
const ANUBIS_SHADOW := preload("res://assets/art/story/sprites/anubis_shadow.png")
const SCALE := preload("res://assets/art/story/props/scale.png")

var _vignette: ColorRect
var _title: Label
var _subtitle: Label
var _shadow: TextureRect
var _anubis: TextureRect
var _anubis_turn: TextureRect
var _scale: TextureRect
var _panel: Panel
var _text: Label
var _hint: Label
var _active := false
var _tween: Tween
var _turn_tween: Tween


func _ready() -> void:
	size = Vector2(1620, 972)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vignette = ColorRect.new()
	_vignette.size = size
	_vignette.color = Color(0.04, 0.03, 0.07, 0.62)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	_title = UI.label(self, "", Rect2(0, 72, 1620, 46), 36, UI.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = UI.label(self, "", Rect2(0, 124, 1620, 28), 18, UI.MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_shadow = _sprite_rect(ANUBIS_SHADOW, Rect2(560, 250, 192, 256))
	_shadow.modulate = Color(1, 1, 1, 0.38)
	_anubis = _sprite_rect(ANUBIS, Rect2(560, 250, 192, 256))
	_anubis_turn = _sprite_rect(ANUBIS_TURN, Rect2(560, 250, 192, 256))
	_anubis_turn.modulate.a = 0.0
	_scale = _sprite_rect(SCALE, Rect2(820, 360, 200, 200))

	_panel = UI.panel(self, Rect2(300, 720, 1020, 170), "parchment")
	_text = UI.label(self, "", Rect2(336, 742, 948, 126), 20, UI.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint = UI.label(self, "空格 / 点击　返回标题", Rect2(0, 916, 1620, 28), 16, UI.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	hide()
	set_process_input(false)


func _sprite_rect(texture: Texture2D, rect: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.position = rect.position
	view.size = rect.size
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	return view


func show_ending(lines: PackedStringArray, anubis: bool, story_lab: bool = false) -> void:
	if _active or lines.is_empty():
		return
	_active = true
	_title.text = "第五天 · 称心" if anubis else "第五天 · 收工"
	_subtitle.text = "阿努比斯收起了天平。" if anubis else "冥河渡口，最后一班船。"
	_shadow.visible = anubis
	_anubis.visible = anubis
	_anubis_turn.visible = anubis
	_anubis.modulate.a = 1.0
	_anubis_turn.modulate.a = 0.0
	_scale.visible = anubis
	_text.text = "\n".join(lines)
	_hint.text = "空格 / 点击　返回标题" + ("　　N 重置剧情测试" if story_lab else "")
	_text.visible_ratio = 0.0
	_hint.modulate.a = 0.0
	modulate.a = 0.0
	show()
	set_process_input(true)
	var duration := clampf(lines[0].length() * 0.018, 1.0, 2.4)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.55)
	_tween.tween_property(_text, "visible_ratio", 1.0, duration)
	_tween.tween_property(_hint, "modulate:a", 1.0, 0.35)
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	if anubis:
		_turn_tween = create_tween()
		_turn_tween.tween_interval(1.1)
		_turn_tween.set_parallel(true)
		_turn_tween.tween_property(_anubis, "modulate:a", 0.0, 0.45)
		_turn_tween.tween_property(_anubis_turn, "modulate:a", 1.0, 0.45)


func is_active() -> bool:
	return _active


func close() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	_active = false
	hide()
	set_process_input(false)


func advance() -> void:
	if not _active:
		return
	if _text.visible_ratio < 1.0:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_text.visible_ratio = 1.0
		_hint.modulate.a = 1.0
		return
	_active = false
	hide()
	set_process_input(false)
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()
