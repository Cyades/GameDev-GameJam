extends RefCounted

const UI_FONT: FontFile = preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Font/NormalFont.ttf")
const UI_SPACE_EXTRA: int = 4

static var _readable_ui_font: FontVariation

const INK := Color(0.035, 0.027, 0.05, 0.96)
const INK_SOFT := Color(0.075, 0.055, 0.09, 0.92)
const GOLD := Color(1.0, 0.74, 0.22, 1.0)
const GOLD_DARK := Color(0.58, 0.34, 0.10, 1.0)
const GOLD_LIGHT := Color(1.0, 0.92, 0.48, 1.0)
const RUBY := Color(0.92, 0.18, 0.14, 1.0)
const EMERALD := Color(0.18, 0.82, 0.42, 1.0)
const BLUE := Color(0.22, 0.58, 1.0, 1.0)
const TEXT := Color(1.0, 0.93, 0.78, 1.0)
const MUTED_TEXT := Color(0.73, 0.69, 0.62, 1.0)

static func get_ui_font() -> Font:
	if _readable_ui_font == null:
		_readable_ui_font = FontVariation.new()
		_readable_ui_font.base_font = UI_FONT
		_readable_ui_font.spacing_space = UI_SPACE_EXTRA
	return _readable_ui_font

static func panel_style(
	bg_color: Color = INK,
	border_color: Color = GOLD,
	radius: int = 8,
	border_width: int = 2,
	shadow_size: int = 10
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 5.0)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style

static func thin_panel_style(bg_color: Color = Color(0.02, 0.018, 0.032, 0.78), border_color: Color = Color(1.0, 0.74, 0.22, 0.42)) -> StyleBoxFlat:
	var style := panel_style(bg_color, border_color, 5, 1, 4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style

static func button_style(base: Color, border: Color, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base
	style.border_color = border
	style.border_width_top = 2
	style.border_width_bottom = 3
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func apply_button(button: Button, accent: Color = GOLD, min_size: Vector2 = Vector2(226, 44)) -> void:
	if button == null:
		return

	var base := accent.darkened(0.42)
	var normal := button_style(base, accent)
	var hover := button_style(accent.darkened(0.20), GOLD_LIGHT)
	var pressed := button_style(accent.darkened(0.58), GOLD_DARK)
	var disabled := button_style(Color(0.13, 0.12, 0.13, 0.85), Color(0.35, 0.32, 0.28, 1.0))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_override("font", get_ui_font())
	button.add_theme_font_size_override("font_size", 16)
	var accent_luma := accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114
	var hover_text := Color(0.08, 0.04, 0.02, 1.0) if accent_luma > 0.58 else TEXT
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", hover_text)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.82, 0.50, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.45, 0.40, 1.0))
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func apply_quiet_button(button: Button, min_size: Vector2 = Vector2(226, 40)) -> void:
	apply_button(button, Color(0.44, 0.36, 0.28, 1.0), min_size)

static func apply_danger_button(button: Button, min_size: Vector2 = Vector2(226, 40)) -> void:
	apply_button(button, RUBY, min_size)

static func apply_label(label: Label, font_size: int, color: Color = TEXT, shadow_alpha: float = 0.75) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", get_ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, shadow_alpha))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)

static func apply_title_label(label: Label, font_size: int, color: Color = GOLD_LIGHT) -> void:
	apply_label(label, font_size, color, 0.95)
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.04, 0.015, 1.0))
	label.add_theme_constant_override("outline_size", maxi(2, roundi(float(font_size) * 0.11)))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 4)

static func apply_slider(slider: HSlider) -> void:
	if slider == null:
		return

	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.08, 0.07, 0.08, 0.95)
	rail.corner_radius_top_left = 4
	rail.corner_radius_top_right = 4
	rail.corner_radius_bottom_left = 4
	rail.corner_radius_bottom_right = 4
	rail.content_margin_top = 4.0
	rail.content_margin_bottom = 4.0

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.62, 0.20, 1.0)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	fill.content_margin_top = 4.0
	fill.content_margin_bottom = 4.0

	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.custom_minimum_size = Vector2(0.0, 22.0)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func apply_progress_bar(bar: ProgressBar, fill_color: Color, height: float = 8.0) -> void:
	if bar == null:
		return

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.035, 0.027, 0.04, 0.88)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.45)
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bg.content_margin_left = 0.0
	bg.content_margin_right = 0.0
	bg.content_margin_top = 0.0
	bg.content_margin_bottom = 0.0

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	fill.content_margin_left = 0.0
	fill.content_margin_right = 0.0
	fill.content_margin_top = 0.0
	fill.content_margin_bottom = 0.0

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.custom_minimum_size = Vector2(0.0, height)
