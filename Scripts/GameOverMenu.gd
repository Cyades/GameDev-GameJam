extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Control/VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$Control/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

func _on_retry_pressed() -> void:
	UISound.play_click()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	queue_free()

func _on_main_menu_pressed() -> void:
	UISound.play_click()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
	queue_free()
