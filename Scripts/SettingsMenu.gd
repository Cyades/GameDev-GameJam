extends Control

const UITheme = preload("res://Scripts/UITheme.gd")

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var subtitle_label: Label = $Panel/Subtitle
@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterHBox/MasterSlider
@onready var bgm_slider: HSlider = $Panel/VBoxContainer/BGMHBox/BGMSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXHBox/SFXSlider
@onready var close_button: Button = $Panel/CloseButton

func _ready() -> void:
	# Settings should process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_style_ui()
	
	# Create buses if they don't exist
	_ensure_bus_exists("BGM")
	_ensure_bus_exists("SFX")
	
	# Initialize sliders with current volume
	master_slider.value = _get_bus_volume("Master")
	bgm_slider.value = _get_bus_volume("BGM")
	sfx_slider.value = _get_bus_volume("SFX")
	_update_value_labels()
	
	close_button.pressed.connect(_on_close_pressed)
	master_slider.value_changed.connect(func(v): _on_volume_changed("Master", v))
	bgm_slider.value_changed.connect(func(v): _on_volume_changed("BGM", v))
	sfx_slider.value_changed.connect(func(v): _on_volume_changed("SFX", v))

func _style_ui() -> void:
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.018, 0.014, 0.028, 0.95), Color(1.0, 0.74, 0.22, 0.86), 8, 2, 16))
	UITheme.apply_title_label(title_label, 24, UITheme.GOLD_LIGHT)
	UITheme.apply_label(subtitle_label, 9, UITheme.MUTED_TEXT, 0.65)
	for path in [
		"Panel/VBoxContainer/MasterHBox/Label",
		"Panel/VBoxContainer/BGMHBox/Label",
		"Panel/VBoxContainer/SFXHBox/Label",
		"Panel/VBoxContainer/MasterHBox/MasterValue",
		"Panel/VBoxContainer/BGMHBox/BGMValue",
		"Panel/VBoxContainer/SFXHBox/SFXValue"
	]:
		UITheme.apply_label(get_node(path) as Label, 9, UITheme.TEXT, 0.65)
	UITheme.apply_slider(master_slider)
	UITheme.apply_slider(bgm_slider)
	UITheme.apply_slider(sfx_slider)
	UITheme.apply_button(close_button, UITheme.GOLD, Vector2(200, 36))

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
		var db = linear_to_db(maxf(linear_value, 0.001))
		# Mute if value is 0
		AudioServer.set_bus_mute(idx, linear_value <= 0.01)
		AudioServer.set_bus_volume_db(idx, db)
	_update_value_labels()

func _on_close_pressed() -> void:
	UISound.play_click()
	hide()

func _update_value_labels() -> void:
	_set_value_label("Panel/VBoxContainer/MasterHBox/MasterValue", master_slider.value)
	_set_value_label("Panel/VBoxContainer/BGMHBox/BGMValue", bgm_slider.value)
	_set_value_label("Panel/VBoxContainer/SFXHBox/SFXValue", sfx_slider.value)

func _set_value_label(path: String, value: float) -> void:
	var label := get_node_or_null(path) as Label
	if label:
		label.text = str(roundi(value * 100.0)) + "%"
