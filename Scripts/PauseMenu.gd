extends CanvasLayer

const UITheme = preload("res://Scripts/UITheme.gd")

@onready var overlay: ColorRect = $Control/Overlay
@onready var dialog_panel: PanelContainer = $Control/DialogPanel
@onready var title_label: Label = $Control/DialogPanel/VBoxContainer/Title
@onready var resume_button: Button = $Control/DialogPanel/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Control/DialogPanel/VBoxContainer/SettingsButton
@onready var main_menu_button: Button = $Control/DialogPanel/VBoxContainer/MainMenuButton
@onready var hint_label: Label = $Control/DialogPanel/VBoxContainer/HintLabel

func _ready() -> void:
	# Ensure the pause menu can process even when the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_style_ui()
	
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _style_ui() -> void:
	dialog_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.018, 0.014, 0.028, 0.92), Color(1.0, 0.74, 0.22, 0.88), 8, 2, 16))
	UITheme.apply_title_label(title_label, 28, UITheme.GOLD_LIGHT)
	UITheme.apply_label(hint_label, 8, Color(0.86, 0.78, 0.62, 0.78), 0.6)
	UITheme.apply_button(resume_button, UITheme.EMERALD, Vector2(226, 40))
	UITheme.apply_quiet_button(settings_button, Vector2(226, 40))
	UITheme.apply_danger_button(main_menu_button, Vector2(226, 40))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			var settings = get_node_or_null("SettingsMenu")
			if settings and settings.visible:
				settings.hide()
			else:
				_unpause()
		else:
			_pause()

func _pause() -> void:
	get_tree().paused = true
	MusicManager.pause_music()
	show()
	_animate_open()

func _unpause() -> void:
	get_tree().paused = false
	MusicManager.unpause_music()
	hide()

func _on_resume_pressed() -> void:
	UISound.play_click()
	_unpause()

func _on_settings_pressed() -> void:
	UISound.play_click()
	var settings = get_node_or_null("SettingsMenu")
	if settings:
		settings.show()

func _on_main_menu_pressed() -> void:
	UISound.play_click()
	_unpause()
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _animate_open() -> void:
	dialog_panel.modulate.a = 0.0
	dialog_panel.position.y += 8.0
	overlay.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(dialog_panel, "modulate:a", 1.0, 0.18).set_delay(0.04)
	tween.parallel().tween_property(dialog_panel, "position:y", dialog_panel.position.y - 8.0, 0.22).set_delay(0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
