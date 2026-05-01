extends Control

func _ready() -> void:
	# Settings should process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	$Panel/CloseButton.pressed.connect(_on_close_pressed)
	
	var master_slider = $Panel/VBoxContainer/MasterHBox/MasterSlider
	var bgm_slider = $Panel/VBoxContainer/BGMHBox/BGMSlider
	var sfx_slider = $Panel/VBoxContainer/SFXHBox/SFXSlider
	
	master_slider.value_changed.connect(func(v): _on_volume_changed("Master", v))
	bgm_slider.value_changed.connect(func(v): _on_volume_changed("BGM", v))
	sfx_slider.value_changed.connect(func(v): _on_volume_changed("SFX", v))
	
	# Initialize sliders with current volume
	master_slider.value = _get_bus_volume("Master")
	
	# Create buses if they don't exist
	_ensure_bus_exists("BGM")
	_ensure_bus_exists("SFX")
	
	bgm_slider.value = _get_bus_volume("BGM")
	sfx_slider.value = _get_bus_volume("SFX")

func _ensure_bus_exists(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)

func _get_bus_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		var db = AudioServer.get_bus_volume_db(idx)
		# Convert db to linear scale (0.0 to 1.0)
		return db_to_linear(db)
	return 1.0

func _on_volume_changed(bus_name: String, linear_value: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		# Convert linear to db
		var db = linear_to_db(linear_value)
		# Mute if value is 0
		AudioServer.set_bus_mute(idx, linear_value <= 0.01)
		AudioServer.set_bus_volume_db(idx, db)

func _on_close_pressed() -> void:
	UISound.play_click()
	hide()
