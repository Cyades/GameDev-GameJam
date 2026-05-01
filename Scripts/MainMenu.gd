extends CanvasLayer

func _ready() -> void:
	MusicManager.play_menu_music()
	$Control/VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$Control/VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$Control/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

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
