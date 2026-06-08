extends CanvasLayer

const UITheme = preload("res://Scripts/UITheme.gd")

@onready var overlay: ColorRect = $Control/Overlay
@onready var dialog_panel: PanelContainer = $Control/DialogPanel
@onready var title_label: Label = $Control/DialogPanel/VBoxContainer/Title
@onready var subtitle_label: Label = $Control/DialogPanel/VBoxContainer/Subtitle
@onready var retry_button: Button = $Control/DialogPanel/VBoxContainer/RetryButton
@onready var main_menu_button: Button = $Control/DialogPanel/VBoxContainer/MainMenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_ui()
	_animate_open()
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _style_ui() -> void:
	dialog_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.052, 0.014, 0.018, 0.94), Color(1.0, 0.28, 0.18, 0.88), 8, 2, 16))
	UITheme.apply_title_label(title_label, 32, Color(1.0, 0.35, 0.26, 1.0))
	UITheme.apply_label(subtitle_label, 9, Color(1.0, 0.78, 0.62, 0.86), 0.75)
	UITheme.apply_button(retry_button, UITheme.GOLD, Vector2(226, 40))
	UITheme.apply_danger_button(main_menu_button, Vector2(226, 40))

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

func _animate_open() -> void:
	dialog_panel.modulate.a = 0.0
	dialog_panel.position.y += 8.0
	overlay.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(dialog_panel, "modulate:a", 1.0, 0.20).set_delay(0.05)
	tween.parallel().tween_property(dialog_panel, "position:y", dialog_panel.position.y - 8.0, 0.24).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_victory() -> void:
	# Note: This should be called before or right after adding to the scene tree
	if not is_node_ready():
		await ready
	title_label.text = "VICTORY"
	subtitle_label.text = "The legion stands absolute."
	# Change overlay from red to dark golden tint for victory
	overlay.color = Color(0.06, 0.05, 0.02, 0.72)
	dialog_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.02, 0.03, 0.05, 0.94), UITheme.GOLD, 8, 2, 16))
	UITheme.apply_title_label(title_label, 32, UITheme.GOLD)
	UITheme.apply_label(subtitle_label, 9, UITheme.TEXT, 0.75)
