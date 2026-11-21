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
	if primary:
		control.add_theme_stylebox_override("normal", box(BTN_GOLD_NORMAL, 12.0, 12.0, 6.0))
		control.add_theme_stylebox_override("hover", box(BTN_GOLD_HOVER, 12.0, 12.0, 6.0))
		control.add_theme_stylebox_override("pressed", box(BTN_GOLD_PRESSED, 12.0, 12.0, 6.0))
	else:
		control.add_theme_stylebox_override("normal", box(BTN_NORMAL, 12.0, 12.0, 6.0))
		control.add_theme_stylebox_override("hover", box(BTN_HOVER, 12.0, 12.0, 6.0))
		control.add_theme_stylebox_override("pressed", box(BTN_PRESSED, 12.0, 12.0, 6.0))
	control.add_theme_stylebox_override("disabled", box(BTN_DISABLED, 12.0, 12.0, 6.0))
	control.pressed.connect(callback)
	parent.add_child(control)
	return control


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
