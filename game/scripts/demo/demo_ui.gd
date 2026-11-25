extends RefCounted
## Pixel-art UI kit inspired by Stardew Valley & Soul Knight, matched to Acheron's palette.

const Data := preload("res://scripts/systems/playtest_data.gd")

const INK := Color("161221")
const CREAM := Color("f7ecd2")
const MINT := Color("7fe8c8")
const MUTED := Color("b4b6c7")
const GOLD := Color("f5cc66")
const WARN := Color("f28b75")
const GOOD := Color("6fe0a4")
const DARK_TEXT := Color("2b1c1c")

const PANEL_DARK_WOOD := preload("res://assets/art/ui/panel_dark_wood.png")
const PANEL_HUD_WOOD := preload("res://assets/art/ui/panel_hud_wood.png")
const PANEL_POPUP := preload("res://assets/art/ui/panel_popup.png")
const PANEL_PARCHMENT := preload("res://assets/art/ui/panel_parchment.png")

const SLOT_NORMAL := preload("res://assets/art/ui/slot_normal.png")
const SLOT_HOVER := preload("res://assets/art/ui/slot_hover.png")
const SLOT_SELECTED := preload("res://assets/art/ui/slot_selected.png")
const SLOT_LOCKED := preload("res://assets/art/ui/slot_locked.png")
const SLOT_WOOD_INSET := preload("res://assets/art/ui/slot_wood_inset.png")

const BTN_NORMAL := preload("res://assets/art/ui/btn_normal.png")
const BTN_HOVER := preload("res://assets/art/ui/btn_hover.png")
const BTN_PRESSED := preload("res://assets/art/ui/btn_pressed.png")
const BTN_DISABLED := preload("res://assets/art/ui/btn_disabled.png")

const BTN_GOLD_NORMAL := preload("res://assets/art/ui/btn_gold_normal.png")
const BTN_GOLD_HOVER := preload("res://assets/art/ui/btn_gold_hover.png")
const BTN_GOLD_PRESSED := preload("res://assets/art/ui/btn_gold_pressed.png")

const TAB_NORMAL := preload("res://assets/art/ui/tab_normal.png")
const TAB_ACTIVE := preload("res://assets/art/ui/tab_active.png")

const ICON_WISDOM := preload("res://assets/art/ui/icon_wisdom.png")
const ICON_EMOTION := preload("res://assets/art/ui/icon_emotion.png")
const ICON_WILL := preload("res://assets/art/ui/icon_will.png")
const STAT_ICONS := [ICON_WISDOM, ICON_EMOTION, ICON_WILL]

const ICON_ROD := preload("res://assets/art/ui/icon_rod.png")
const ICON_HOOK := preload("res://assets/art/ui/icon_hook.png")
const ICON_GRIP := preload("res://assets/art/ui/icon_grip.png")
const ICON_BAIT := preload("res://assets/art/ui/icon_bait.png")
const RIG_ICONS := [ICON_ROD, ICON_HOOK, ICON_GRIP, ICON_BAIT]

const ICON_POTION := preload("res://assets/art/ui/icon_potion.png")
const ICON_ESSENCE := preload("res://assets/art/ui/icon_essence.png")
const ICON_COIN := preload("res://assets/art/ui/icon_coin.png")
const ICON_BASKET := preload("res://assets/art/ui/icon_basket.png")
const ICON_SOUL := preload("res://assets/art/ui/icon_soul.png")
const ICON_CONCENTRATE := preload("res://assets/art/ui/icon_concentrate.png")
const ICON_WRENCH := preload("res://assets/art/ui/icon_wrench.png")
const ICON_EXIT := preload("res://assets/art/ui/icon_exit.png")


static func box(texture: Texture2D, margin: float = 15.0, pad_x: float = 12.0, pad_y: float = 8.0) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = texture
	result.texture_margin_left = margin
	result.texture_margin_top = margin
	result.texture_margin_right = margin
	result.texture_margin_bottom = margin
	result.content_margin_left = pad_x
	result.content_margin_top = pad_y
	result.content_margin_right = pad_x
	result.content_margin_bottom = pad_y
	result.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	result.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return result


static func panel(parent: Node, rect: Rect2, variant: String = "dark_wood") -> Panel:
	var control := Panel.new()
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = PANEL_DARK_WOOD
	var margin := 15.0
	match variant:
		"hud_wood":
			tex = PANEL_HUD_WOOD
		"popup":
			tex = PANEL_POPUP
		"parchment":
			tex = PANEL_PARCHMENT
		"slot":
			tex = SLOT_NORMAL
			margin = 12.0
		"slot_selected":
			tex = SLOT_SELECTED
			margin = 12.0
		"wood_inset":
			tex = SLOT_WOOD_INSET
			margin = 12.0
	control.add_theme_stylebox_override("panel", box(tex, margin, 10.0, 8.0))
	parent.add_child(control)
	return control


static func label(parent: Node, text: String, rect: Rect2, font_size: int = 21, color: Color = CREAM, with_shadow: bool = true) -> Label:
	var control := Label.new()
	control.text = text
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	if with_shadow:
		control.add_theme_color_override("font_shadow_color", Color(INK, 0.85))
		control.add_theme_constant_override("shadow_offset_x", 2)
		control.add_theme_constant_override("shadow_offset_y", 2)
	control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(control)
	return control


static func icon_rect(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var control := TextureRect.new()
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.position = rect.position
	control.size = rect.size
	control.texture = texture
	parent.add_child(control)
	return control


static func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var control := Button.new()
	control.text = text
	control.position = rect.position
	control.size = rect.size
	control.focus_mode = Control.FOCUS_NONE
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.add_theme_font_size_override("font_size", 22)
	control.add_theme_color_override("font_color", CREAM)
	control.add_theme_color_override("font_hover_color", Color("ffffff"))
	control.add_theme_color_override("font_pressed_color", GOLD)
	control.add_theme_color_override("font_disabled_color", Color("7a788a"))
	control.add_theme_color_override("font_shadow_color", Color(INK, 0.9))
	control.add_theme_constant_override("shadow_offset_x", 2)
	control.add_theme_constant_override("shadow_offset_y", 2)
	set_button_primary(control, primary)
	control.add_theme_stylebox_override("disabled", box(BTN_DISABLED, 12.0, 12.0, 6.0))
	control.pressed.connect(callback)
	parent.add_child(control)
	return control


static func set_button_primary(control: Button, primary: bool) -> void:
	control.add_theme_stylebox_override("normal", box(BTN_GOLD_NORMAL if primary else BTN_NORMAL, 12.0, 12.0, 6.0))
	control.add_theme_stylebox_override("hover", box(BTN_GOLD_HOVER if primary else BTN_HOVER, 12.0, 12.0, 6.0))
	control.add_theme_stylebox_override("pressed", box(BTN_GOLD_PRESSED if primary else BTN_PRESSED, 12.0, 12.0, 6.0))


static func set_tab_active(control: Button, is_active: bool) -> void:
	control.add_theme_stylebox_override("normal", box(TAB_ACTIVE if is_active else TAB_NORMAL, 12.0, 12.0, 6.0))
	control.add_theme_stylebox_override("hover", box(TAB_ACTIVE if is_active else BTN_GOLD_HOVER, 12.0, 12.0, 6.0))
	control.add_theme_stylebox_override("pressed", box(TAB_ACTIVE, 12.0, 12.0, 6.0))
	control.add_theme_stylebox_override("disabled", box(TAB_ACTIVE if is_active else BTN_DISABLED, 12.0, 12.0, 6.0))
	control.add_theme_color_override("font_color", Color("fff8dc") if is_active else CREAM)
	control.add_theme_color_override("font_disabled_color", Color("fff8dc") if is_active else Color("7a788a"))


static func tab_button(parent: Node, text: String, rect: Rect2, callback: Callable, is_active: bool = false) -> Button:
	var control := button(parent, text, rect, callback, false)
	set_tab_active(control, is_active)
	return control


static func style_slot_button(control: Button, selected: bool = false, locked: bool = false) -> void:
	control.focus_mode = Control.FOCUS_NONE
	control.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if locked:
		control.add_theme_stylebox_override("normal", box(SLOT_LOCKED, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("hover", box(SLOT_LOCKED, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("pressed", box(SLOT_LOCKED, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("disabled", box(SLOT_LOCKED, 12.0, 8.0, 6.0))
	elif selected:
		control.add_theme_stylebox_override("normal", box(SLOT_SELECTED, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("hover", box(SLOT_SELECTED, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("pressed", box(SLOT_SELECTED, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("disabled", box(SLOT_SELECTED, 12.0, 8.0, 6.0))
	else:
		control.add_theme_stylebox_override("normal", box(SLOT_NORMAL, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("hover", box(SLOT_HOVER, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("pressed", box(SLOT_SELECTED, 12.0, 8.0, 6.0))
		control.add_theme_stylebox_override("disabled", box(SLOT_LOCKED, 12.0, 8.0, 6.0))


static func create_scroll(parent: Node, rect: Rect2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	parent.add_child(scroll)
	return scroll


static func activate(button: Button) -> void:
	if not button.disabled:
		button.pressed.emit()


static func next_button(buttons: Array[Button], current: int, step: int) -> int:
	for offset in range(1, buttons.size() + 1):
		var index := posmod(current + step * offset, buttons.size())
		if not buttons[index].disabled:
			return index
	return current


static func clear_cards(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func reveal(scroll: ScrollContainer, card: Control) -> void:
	await scroll.get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(card) and scroll.is_ancestor_of(card):
		scroll.ensure_control_visible(card)


static func make_effect_row(effect: Vector3i, icon_size: int = 24, font_size: int = 19, show_names: bool = false, highlight_stat: int = -1) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12 if show_names else 10)
	for index in 3:
		var value := effect[index]
		var chip := HBoxContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_constant_override("separation", 5)
		var icon := TextureRect.new()
		icon.texture = STAT_ICONS[index]
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if value == 0 and highlight_stat != index:
			icon.modulate = Color(1, 1, 1, 0.45)
		chip.add_child(icon)
		var txt := Label.new()
		txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sign_str := "+%d" % value if value > 0 else str(value)
		txt.text = "%s %s" % [Data.STAT_NAMES[index], sign_str] if show_names else sign_str
		txt.add_theme_font_size_override("font_size", font_size)
		var col: Color = Data.STAT_COLORS[index] if value > 0 else (WARN if value < 0 else Color(MUTED, 0.55))
		if highlight_stat == index:
			col = GOLD
		txt.add_theme_color_override("font_color", col)
		txt.add_theme_color_override("font_shadow_color", Color(INK, 0.9))
		txt.add_theme_constant_override("shadow_offset_x", 2)
		txt.add_theme_constant_override("shadow_offset_y", 2)
		chip.add_child(txt)
		row.add_child(chip)
	return row


static func style(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(3)
	result.set_content_margin_all(10)
	return result


static func pixel_panel(parent: Node, rect: Rect2, fill: Color, edge: Color, base: Color) -> Panel:
	var control := Panel.new()
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_stylebox_override("panel", _pixel_box(fill, edge, base))
	parent.add_child(control)
	return control



static func modal_panel(parent: Node, rect: Rect2) -> Panel:
	var control := pixel_panel(parent, rect, Color("221c31"), Color("76614f"), Color("100e1a"))
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	var rule := ColorRect.new()
	rule.position = Vector2(24, 70)
	rule.size = Vector2(rect.size.x - 48, 2)
	rule.color = Color("42605f")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(rule)
	return control


static func modal_button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var control := button(parent, text, rect, callback)
	control.add_theme_font_size_override("font_size", 20)
	control.add_theme_color_override("font_pressed_color", Color("fff8dc"))
	control.add_theme_color_override("font_disabled_color", Color("8d96b2"))
	control.add_theme_stylebox_override("disabled", _pixel_box(Color("241f32"), Color("3d374b"), INK))
	set_modal_button(control, false)
	return control


static func set_modal_button(control: Button, focused: bool, selected: bool = false) -> void:
	var fill := Color("43303a") if focused else (Color("263e43") if selected else Color("2b263c"))
	var edge := Color("bb8f56") if focused else (Color("548a7c") if selected else Color("4e465f"))
	control.add_theme_stylebox_override("normal", _pixel_box(fill, edge, INK))
	control.add_theme_stylebox_override("hover", _pixel_box(fill.lightened(0.06), edge.lightened(0.18), INK))
	control.add_theme_stylebox_override("pressed", _pixel_box(fill.lightened(0.13), GOLD, INK))
	control.add_theme_color_override("font_color", Color("fff8dc") if focused else (MINT if selected else CREAM))


static func modal_pointer(parent: Control) -> Control:
	var pointer := Control.new()
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.draw.connect(func() -> void:
		pointer.draw_rect(Rect2(0, -2, 10, 4), GOLD)
		pointer.draw_rect(Rect2(3, -5, 4, 10), GOLD)
		pointer.draw_rect(Rect2(4, -1, 2, 2), Color("fff8dc")))
	parent.add_child(pointer)
	return pointer


static func key_hint(parent: Control, keys: Array[String], caption: String, origin: Vector2) -> float:
	var font := parent.get_theme_default_font()
	var x := origin.x
	for key in keys:
		var width := maxf(25, ceilf(font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) + 12)
		var cap := pixel_panel(parent, Rect2(x, origin.y, width, 25), Color("2a263a"), Color("766858"), Color("110e1c"))
		var key_label := label(cap, key, Rect2(0, 0, width, 23), 15, GOLD, false)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x += width + 4
	x += 4
	var caption_width := ceilf(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
	label(parent, caption, Rect2(x, origin.y, caption_width, 25), 17, CREAM)
	return x + caption_width - origin.x


static func _pixel_box(fill: Color, edge: Color, base: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.border_width_bottom = 3
	box.border_blend = false
	box.anti_aliasing = false
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.shadow_color = base
	box.shadow_size = 2
	box.shadow_offset = Vector2(0, 2)
	return box
