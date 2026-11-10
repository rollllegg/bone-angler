extends Control
## River and gate share a live session; the old isolated practices remain available.

@onready var rod: Control = $RodPractice
@onready var fishing: Control = $FishingPractice
@onready var direction: Control = $DirectionPractice
@onready var gate: Control = $SoulGate
@onready var session: SoulSession = $SoulSession

var current_module: String = "Direction"
var _footer: Control
var _summary: Label
var _shortcuts: Label


func _ready() -> void:
	$ModuleNav/Rod.pressed.connect(func() -> void: _show_module("Rod"))
	$ModuleNav/Fishing.pressed.connect(func() -> void: _show_module("Fishing"))
	$ModuleNav/Direction.pressed.connect(func() -> void: _show_module("Direction"))
	$ModuleNav/Gate.pressed.connect(func() -> void: _show_module("Gate"))
	direction.bind_session(session)
	gate.bind_session(session)
	direction.pause_requested.connect(_toggle_pause)
	direction.get_node("DirectionFishing").fish_caught.connect(func(index: int, _total: int) -> void: session.add_fish(index))
	_build_footer()
	session.state_changed.connect(_refresh_footer)
	resized.connect(_resize_footer)
	_show_module("Direction")
	print("BoneFishing startup OK | Godot ", Engine.get_version_info()["string"])


func _show_module(selected: String) -> void:
	current_module = selected
	var modules := {"Rod": rod, "Fishing": fishing, "Direction": direction, "Gate": gate}
	for module_name in modules:
		var module: Control = modules[module_name]
		var active: bool = module_name == selected
		module.visible = active
		module.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		get_node("ModuleNav/" + module_name).disabled = active
	session.active = selected in ["Direction", "Gate"]
	_footer.visible = session.active
	_refresh_footer()


func _input(event: InputEvent) -> void:
	if not session.active or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code == KEY_Q:
		_show_module("Direction")
	elif code == KEY_E:
		_show_module("Gate")
	elif code == KEY_P or (code == KEY_SPACE and session.paused):
		_toggle_pause()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(session) and session.active:
		_set_paused(true)


func _toggle_pause() -> void:
	_set_paused(not session.paused)


func _set_paused(value: bool) -> void:
	session.set_paused(value)
	direction.get_node("DirectionFishing").set_paused(value)
	_refresh_footer()


func _build_footer() -> void:
	_footer = Control.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_theme_font_override("font", preload("res://assets/fonts/NotoSansSC.ttf"))
	add_child(_footer)
	_shortcuts = Label.new()
	_shortcuts.position = Vector2(48, 686)
	_shortcuts.size = Vector2(550, 25)
	_shortcuts.add_theme_font_size_override("font_size", 13)
	_shortcuts.add_theme_color_override("font_color", Color("91ddc5"))
	_footer.add_child(_shortcuts)
	_summary = Label.new()
	_summary.position = Vector2(590, 686)
	_summary.size = Vector2(642, 25)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary.add_theme_font_size_override("font_size", 13)
	_summary.add_theme_color_override("font_color", Color("efc875"))
	_footer.add_child(_summary)
	_resize_footer()


func _resize_footer() -> void:
	if _footer != null:
		_footer.scale = size / Vector2(1280, 720)


func _refresh_footer() -> void:
	_shortcuts.text = "Q 冥河岸    E 冥府大门    P 暂停" if not session.paused else "已暂停    P / 空格继续    Q 冥河岸    E 冥府大门"
	_summary.text = "第 %d 天    等候 %d 魂    鱼篓 %d 条    已放行 %d 魂    金币 %d" % [session.day, session.souls.size(), session.get_inventory_total(), session.released_count, session.coins]
