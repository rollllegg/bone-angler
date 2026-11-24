extends Control
## End-of-day report for story outcomes. The reception panel never shows the
## "later..." epilogue; it is deferred here after the guest has left.

signal closed

const UI := preload("res://scripts/demo/demo_ui.gd")

var _frame: Panel
var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _close: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(1620, 972)
	var backdrop := ColorRect.new()
	backdrop.size = size
	backdrop.color = Color(UI.INK, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_frame = UI.panel(self, Rect2(300, 70, 1020, 832), "parchment")
	_title = UI.label(_frame, "", Rect2(36, 22, 948, 44), 32, UI.GOLD)
	_subtitle = UI.label(_frame, "", Rect2(36, 68, 948, 30), 19, UI.MUTED)
	_scroll = UI.create_scroll(_frame, Rect2(28, 112, 964, 620))
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(930, 0)
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)
	_close = UI.button(_frame, "", Rect2(300, 762, 420, 52), func() -> void: closed.emit(), true)
	visible = false


func render(report: Dictionary) -> void:
	var day := int(report.get("day", 1))
	var final := bool(report.get("final", false))
	_title.text = "第 %d 天 · 收工" % day
	_subtitle.text = "接待已经结束。以下后果会在收工后陆续传来。"
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries: Array = report.get("entries", [])
	if entries.is_empty():
		_add_text("今天没有特殊来客。", 20, UI.MUTED)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var who := str(entry.get("who", "特殊来客"))
		var result := str(entry.get("result", ""))
		_add_text("%s　%s" % [who, result], 25, UI.GOLD)
		var note := str(entry.get("note", ""))
		if note != "":
			_add_text(note, 18, UI.MUTED)
		for paragraph in entry.get("aftermath", []):
			_add_text(str(paragraph), 20, UI.CREAM)
		if index < entries.size() - 1:
			var separator := HSeparator.new()
			separator.custom_minimum_size = Vector2(930, 2)
			_list.add_child(separator)
	_close.text = "查看整局结局" if final else "进入第 %d 天" % (day + 1)
	_scroll.scroll_vertical = 0


func _add_text(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(930, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(label)
