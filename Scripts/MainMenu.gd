extends CanvasLayer

const UITheme = preload("res://Scripts/UITheme.gd")

@onready var title_label: Label = $Control/TitleBlock/TitleShadow
@onready var subtitle_label: Label = $Control/TitleBlock/Subtitle
@onready var menu_panel: PanelContainer = $Control/MenuPanel
@onready var button_box: VBoxContainer = $Control/MenuPanel/VBoxContainer
@onready var play_button: Button = $Control/MenuPanel/VBoxContainer/PlayButton
@onready var settings_button: Button = $Control/MenuPanel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $Control/MenuPanel/VBoxContainer/QuitButton
@onready var footer_label: Label = $Control/FooterLabel

func _ready() -> void:
	if not Engine.is_editor_hint() and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	MusicManager.play_menu_music()
	_style_ui()
	call_deferred("_prepare_button_motion")
	_animate_intro()
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	var settings_menu = get_node_or_null("SettingsMenu")
	if settings_menu:
		settings_menu.hide()

func _style_ui() -> void:
	UITheme.apply_title_label(title_label, 36, UITheme.GOLD_LIGHT)
	UITheme.apply_label(subtitle_label, 9, UITheme.MUTED_TEXT, 0.75)
	UITheme.apply_label(footer_label, 8, Color(1.0, 0.82, 0.48, 0.72), 0.65)
	var menu_style := UITheme.panel_style(Color(0.018, 0.014, 0.026, 0.72), Color(1.0, 0.70, 0.18, 0.78), 7, 2, 12)
	menu_style.content_margin_left = 10.0
	menu_style.content_margin_right = 10.0
	menu_style.content_margin_top = 7.0
	menu_style.content_margin_bottom = 7.0
	menu_panel.add_theme_stylebox_override("panel", menu_style)
	button_box.add_theme_constant_override("separation", 5)
	UITheme.apply_button(play_button, UITheme.GOLD, Vector2(166, 30))
	UITheme.apply_quiet_button(settings_button, Vector2(166, 27))
	UITheme.apply_danger_button(quit_button, Vector2(166, 27))
	for button in [play_button, settings_button, quit_button]:
		_compact_button_styles(button)
		button.add_theme_font_size_override("font_size", 11)

func _compact_button_styles(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var source := button.get_theme_stylebox(state)
		if source is StyleBoxFlat:
			var style := source.duplicate() as StyleBoxFlat
			style.content_margin_left = 10.0
			style.content_margin_right = 10.0
			style.content_margin_top = 4.0
			style.content_margin_bottom = 4.0
			button.add_theme_stylebox_override(state, style)

func _prepare_button_motion() -> void:
	for button in [play_button, settings_button, quit_button]:
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))

func _on_button_mouse_entered(button: Button) -> void:
	_tween_button_scale(button, Vector2(1.025, 1.025))

func _on_button_mouse_exited(button: Button) -> void:
	_tween_button_scale(button, Vector2.ONE)

func _tween_button_scale(button: Button, target_scale: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", target_scale, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_intro() -> void:
	var title_block := $Control/TitleBlock as Control
	title_block.modulate.a = 0.0
	menu_panel.modulate.a = 0.0
	menu_panel.position.y += 10.0
	var tween := create_tween()
	tween.tween_property(title_block, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(menu_panel, "modulate:a", 1.0, 0.35).set_delay(0.12)
	tween.parallel().tween_property(menu_panel, "position:y", menu_panel.position.y - 10.0, 0.42).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_play_pressed() -> void:
	UISound.play_click()
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_settings_pressed() -> void:
	UISound.play_click()
	var settings_menu = get_node_or_null("SettingsMenu")
	if settings_menu:
		settings_menu.show()

func _on_quit_pressed() -> void:
	UISound.play_click()
	get_tree().quit()
