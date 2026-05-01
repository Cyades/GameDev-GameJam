extends CanvasLayer

func _ready() -> void:
	# Ensure the pause menu can process even when the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	$Control/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$Control/VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$Control/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

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
