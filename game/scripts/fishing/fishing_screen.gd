extends Control
## Presentation and keyboard input for the standalone fishing practice scene.

const MINT := Color("8fdbbd")
const CREAM := Color("f3e6c6")
const MUTED := Color("839a9d")
const CORAL := Color("ff9a8b")

@onready var qte: FishingQTE = $FishingQTE
@onready var bubble_row: HBoxContainer = %Bubbles
@onready var score_label: Label = %Score
@onready var progress_label: Label = %Progress
@onready var feedback_label: Label = %Feedback
@onready var progress_bar: ProgressBar = %ProgressBar

var _displayed_word: String = ""
var _feedback_remaining: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	qte.state_changed.connect(_refresh)
	qte.input_missed.connect(_on_missed)
	qte.word_completed.connect(_on_completed)
	%Restart.pressed.connect(_restart)
	_refresh()
	print("BoneFishing typing QTE ready | Godot ", Engine.get_version_info()["string"])


func _process(delta: float) -> void:
	_elapsed += delta
	if _feedback_remaining > 0.0:
		_feedback_remaining -= delta
		if _feedback_remaining <= 0.0:
			_show_default_feedback()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var letter := ""
	if (key.unicode >= 65 and key.unicode <= 90) or (key.unicode >= 97 and key.unicode <= 122):
		letter = String.chr(key.unicode)
	elif key.unicode == 0 and key.keycode >= KEY_A and key.keycode <= KEY_Z:
		letter = String.chr(key.keycode)
	if not letter.is_empty():
		qte.submit_letter(letter)
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _displayed_word != qte.current_word:
		_displayed_word = qte.current_word
		for child in bubble_row.get_children():
			bubble_row.remove_child(child)
			child.queue_free()
		for index in qte.current_word.length():
			var bubble := PanelContainer.new()
			bubble.custom_minimum_size = Vector2(76, 76)
			bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var letter := Label.new()
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			letter.add_theme_font_size_override("font_size", 34)
			bubble.add_child(letter)
			bubble_row.add_child(bubble)

	for index in bubble_row.get_child_count():
		var bubble := bubble_row.get_child(index) as PanelContainer
		var letter := bubble.get_child(0) as Label
		var correct := index < qte.typed_count
		var visible_hint := index < qte.revealed_count
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(38)
		style.set_border_width_all(2)
		style.bg_color = Color("123c39") if correct else Color("14292f")
		style.border_color = MINT if correct else (CREAM if visible_hint else Color("2c454a"))
		bubble.add_theme_stylebox_override("panel", style)
		letter.text = qte.current_word.substr(index, 1) if visible_hint else "·"
		letter.add_theme_color_override("font_color", MINT if correct else (CREAM if visible_hint else Color("496167")))
	score_label.text = "%02d" % qte.score
	progress_label.text = "%d / %d 字母" % [qte.typed_count, qte.current_word.length()]
	progress_bar.max_value = qte.current_word.length()
	progress_bar.value = qte.typed_count
	if _feedback_remaining <= 0.0:
		_show_default_feedback()


func _show_default_feedback() -> void:
	feedback_label.text = "按下泡泡里的字母，也可以凭记忆提前连打"
	feedback_label.add_theme_color_override("font_color", MUTED)


func _on_missed(_received: String, _expected: String) -> void:
	_feedback_remaining = 1.6
	feedback_label.text = "输入有误 · 当前单词从第一个字母重来"
	feedback_label.add_theme_color_override("font_color", CORAL)


func _on_completed(word: String, _total_score: int) -> void:
	_feedback_remaining = 1.6
	feedback_label.text = "钓获成功！%s 完成 · +1 分" % word
	feedback_label.add_theme_color_override("font_color", MINT)


func _restart() -> void:
	_feedback_remaining = 0.0
	qte.restart_session()


func _draw() -> void:
	# Code-drawn river backdrop; no external art is needed for this prototype.
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	draw_rect(Rect2(0, 0, 1280, 720), Color("0b1b24"))
	draw_circle(Vector2(1040, 125), 49, Color("213e43"))
	draw_circle(Vector2(1057, 113), 45, Color("0b1b24"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 340), Vector2(110, 250), Vector2(195, 315), Vector2(320, 218), Vector2(470, 342), Vector2(600, 270), Vector2(760, 350), Vector2(910, 262), Vector2(1040, 325), Vector2(1170, 240), Vector2(1280, 310), Vector2(1280, 720), Vector2(0, 720)]), Color("142e35"))
	draw_rect(Rect2(0, 395, 1280, 325), Color("102c33"))
	for index in 22:
		var x := fmod(float(index * 173) + sin(_elapsed * 0.35 + index) * 14.0 + 1280.0, 1280.0)
		var y := 420.0 + float((index * 43) % 290)
		draw_line(Vector2(x, y), Vector2(x + 22 + (index % 4) * 14, y), Color(0.26, 0.48, 0.49, 0.22), 1.5, true)
	var rod_start := Vector2(1180, 735)
	var rod_end := Vector2(1010, 324)
	draw_line(rod_start, rod_end, CREAM.darkened(0.28), 8, true)
	for index in 6:
		var joint := rod_start.lerp(rod_end, float(index) / 5.0)
		draw_circle(joint, 6, CREAM.darkened(0.2))
	var bobber := Vector2(925, 525 + sin(_elapsed * 2.0) * 3.0)
	draw_polyline(PackedVector2Array([rod_end, Vector2(985, 410), bobber]), Color(0.56, 0.86, 0.74, 0.55), 1.5, true)
	draw_arc(bobber + Vector2(0, 9), 23 + sin(_elapsed * 2.0) * 3, 0.0, TAU, 36, Color(0.56, 0.86, 0.74, 0.28), 1.0, true)
	draw_circle(bobber, 5, MINT)
	draw_set_transform(Vector2.ZERO)
