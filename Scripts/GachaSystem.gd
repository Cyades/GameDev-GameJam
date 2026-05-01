extends Node
## GachaSystem — Full gacha experience with pause, spinning animation, and button
## Game pauses → UI appears → Player clicks ROLL → Spinning roulette → Result → Companion spawns → Resume

# ═══════════════════════════════════════════════════════════════════
# COMPANION POOL
# ═══════════════════════════════════════════════════════════════════
const COMPANION_POOL: Array[Dictionary] = [
	{ "name": "Swordsman",      "scene": "res://Scenes/Swordsman.tscn",     "rarity": "Common",   "weight": 20, "color": Color(0.75, 0.75, 0.75) },
	{ "name": "Knight",         "scene": "res://Scenes/Knight.tscn",        "rarity": "Common",   "weight": 18, "color": Color(0.75, 0.75, 0.75) },
	{ "name": "Lancer",         "scene": "res://Scenes/Lancer.tscn",        "rarity": "Uncommon", "weight": 15, "color": Color(0.3, 0.95, 0.3) },
	{ "name": "Armored Axeman", "scene": "res://Scenes/ArmoredAxeman.tscn", "rarity": "Uncommon", "weight": 14, "color": Color(0.3, 0.95, 0.3) },
	{ "name": "Archer",         "scene": "res://Scenes/Archer.tscn",        "rarity": "Rare",     "weight": 12, "color": Color(0.3, 0.55, 1.0) },
	{ "name": "Knight Templar", "scene": "res://Scenes/KnightTemplar.tscn", "rarity": "Rare",     "weight": 10, "color": Color(0.3, 0.55, 1.0) },
	{ "name": "Wizard",         "scene": "res://Scenes/Wizard.tscn",        "rarity": "Epic",     "weight": 7,  "color": Color(0.8, 0.3, 1.0) },
	{ "name": "Priest",         "scene": "res://Scenes/Priest.tscn",        "rarity": "Legendary","weight": 4,  "color": Color(1.0, 0.85, 0.0) },
]

# ═══════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════
var active_companions: Array[Node2D] = []
var pending_player: Node2D = null  # Player ref for spawning after roll

# UI nodes
var gacha_canvas: CanvasLayer
var dimmer: ColorRect          # Dark overlay
var main_panel: PanelContainer
var roll_button: Button
var spin_label: Label          # Shows spinning names
var result_name_label: Label
var result_rarity_label: Label
var result_info_label: Label
var close_button: Button

# Spin state
var is_spinning: bool = false
var spin_speed: float = 0.0       # Names per second
var spin_timer: float = 0.0
var spin_index: int = 0
var spin_decel: float = 0.0       # Deceleration rate
var final_result: Dictionary = {}
var spin_started: bool = false
var result_shown: bool = false

# ═══════════════════════════════════════════════════════════════════
# PROCESS — runs during pause (process_mode = ALWAYS)
# ═══════════════════════════════════════════════════════════════════
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_spinning: return
	
	spin_timer += delta
	
	# Calculate interval between name switches (slows down over time)
	var interval := 1.0 / maxf(spin_speed, 0.5)
	
	if spin_timer >= interval:
		spin_timer -= interval
		spin_index = (spin_index + 1) % COMPANION_POOL.size()
		var current := COMPANION_POOL[spin_index]
		if spin_label:
			spin_label.text = current["name"]
			spin_label.add_theme_color_override("font_color", current["color"])
	
	# Decelerate
	spin_speed -= spin_decel * delta
	
	# Stop when slow enough
	if spin_speed <= 0.5:
		is_spinning = false
		spin_speed = 0.0
		_show_final_result()

# ═══════════════════════════════════════════════════════════════════
# ROLL — weighted random
# ═══════════════════════════════════════════════════════════════════
func _roll_companion() -> Dictionary:
	var total_weight: int = 0
	for c in COMPANION_POOL:
		total_weight += c["weight"]
	var roll := randi() % total_weight
	var cumulative: int = 0
	for c in COMPANION_POOL:
		cumulative += c["weight"]
		if roll < cumulative:
			return c
	return COMPANION_POOL[0]

# ═══════════════════════════════════════════════════════════════════
# CHECK — called from Player._level_up()
# ═══════════════════════════════════════════════════════════════════
func check_gacha_trigger(player: Node2D, level: int) -> void:
	if level % 5 == 0 and level > 0:
		_open_gacha_ui(player)

# ═══════════════════════════════════════════════════════════════════
# OPEN GACHA — pause game + show UI
# ═══════════════════════════════════════════════════════════════════
func _open_gacha_ui(player: Node2D) -> void:
	pending_player = player
	result_shown = false
	
	# Pause the game
	get_tree().paused = true
	
	# Build UI if needed
	if gacha_canvas == null:
		_create_gacha_ui()
	
	# Reset UI state
	spin_label.text = "???"
	spin_label.add_theme_color_override("font_color", Color(1, 1, 1))
	result_name_label.text = ""
	result_rarity_label.text = ""
	result_info_label.text = ""
	roll_button.visible = true
	roll_button.disabled = false
	close_button.visible = false
	main_panel.visible = true
	dimmer.visible = true
	
	# Pre-determine the result (but animate the spin first)
	final_result = _roll_companion()

# ═══════════════════════════════════════════════════════════════════
# SPIN ANIMATION
# ═══════════════════════════════════════════════════════════════════
func _on_roll_button_pressed() -> void:
	if is_spinning: return
	
	# Hide button, start spin
	roll_button.visible = false
	result_name_label.text = ""
	result_rarity_label.text = ""
	result_info_label.text = ""
	
	# Start spinning
	is_spinning = true
	spin_started = true
	spin_speed = 20.0         # Start fast (20 names/sec)
	spin_decel = 4.5          # Decelerate over ~4 seconds
	spin_timer = 0.0
	spin_index = randi() % COMPANION_POOL.size()

func _show_final_result() -> void:
	if result_shown: return
	result_shown = true
	
	# Show the pre-determined result
	var name_text: String = final_result["name"]
	var rarity: String = final_result["rarity"]
	var color: Color = final_result["color"]
	
	# Update spin label to final result
	spin_label.text = name_text
	spin_label.add_theme_color_override("font_color", color)
	
	# Show result details
	result_name_label.text = name_text
	result_name_label.add_theme_color_override("font_color", color)
	
	result_rarity_label.text = _get_rarity_stars(rarity)
	result_rarity_label.add_theme_color_override("font_color", color)
	
	result_info_label.text = "New companion joined your squad!"
	
	# Show close button
	close_button.visible = true
	
	# Spawn the companion (while still paused)
	_spawn_companion_from_result()
	
	print("[GACHA] Rolled: ", name_text, " (", rarity, ")")

func _get_rarity_stars(rarity: String) -> String:
	match rarity:
		"Common":    return "★ Common ★"
		"Uncommon":  return "★★ Uncommon ★★"
		"Rare":      return "★★★ Rare ★★★"
		"Epic":      return "★★★★ Epic ★★★★"
		"Legendary": return "★★★★★ Legendary ★★★★★"
		_:           return "★ " + rarity + " ★"

# ═══════════════════════════════════════════════════════════════════
# SPAWN COMPANION
# ═══════════════════════════════════════════════════════════════════
func _spawn_companion_from_result() -> void:
	if pending_player == null or not is_instance_valid(pending_player): return
	
	var scene_path: String = final_result["scene"]
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("GachaSystem: Cannot load scene: " + scene_path)
		return
	
	var companion := scene.instantiate() as Node2D
	if companion == null: return
	
	var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
	companion.global_position = pending_player.global_position + offset
	
	var main := pending_player.get_parent()
	if main:
		main.add_child(companion)
	
	active_companions.append(companion)

# ═══════════════════════════════════════════════════════════════════
# CLOSE — unpause game
# ═══════════════════════════════════════════════════════════════════
func _on_close_button_pressed() -> void:
	main_panel.visible = false
	dimmer.visible = false
	result_shown = false
	spin_started = false
	
	# Unpause game
	get_tree().paused = false

# ═══════════════════════════════════════════════════════════════════
# CREATE UI — all built in code, works during pause
# ═══════════════════════════════════════════════════════════════════
func _create_gacha_ui() -> void:
	gacha_canvas = CanvasLayer.new()
	gacha_canvas.name = "GachaCanvas"
	gacha_canvas.layer = 50
	gacha_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(gacha_canvas)
	
	# ── Dark dimmer overlay ──
	dimmer = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks behind
	dimmer.visible = false
	gacha_canvas.add_child(dimmer)
	
	# ── Main Panel ──
	main_panel = PanelContainer.new()
	main_panel.name = "GachaMainPanel"
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.position = Vector2(-180, -140)
	main_panel.size = Vector2(360, 280)
	main_panel.visible = false
	main_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.12, 0.97)
	panel_style.border_width_top = 3; panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3; panel_style.border_width_right = 3
	panel_style.border_color = Color(1.0, 0.75, 0.0, 0.9)
	panel_style.corner_radius_top_left = 12; panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12; panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(1.0, 0.75, 0.0, 0.15)
	panel_style.shadow_size = 8
	main_panel.add_theme_stylebox_override("panel", panel_style)
	gacha_canvas.add_child(main_panel)
	
	# ── VBox layout ──
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	main_panel.add_child(vbox)
	
	# ── Title ──
	var title := Label.new()
	title.text = "✦ MERCENARY GACHA ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title.add_theme_color_override("font_shadow_color", Color(0.4, 0.25, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)
	
	# ── Subtitle ──
	var subtitle := Label.new()
	subtitle.text = "Level 5 reached! Recruit a companion!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)
	
	# ── Spacer ──
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer1)
	
	# ── Spin display box ──
	var spin_panel := PanelContainer.new()
	spin_panel.custom_minimum_size = Vector2(280, 50)
	var spin_style := StyleBoxFlat.new()
	spin_style.bg_color = Color(0.03, 0.03, 0.08, 1.0)
	spin_style.border_width_top = 2; spin_style.border_width_bottom = 2
	spin_style.border_width_left = 2; spin_style.border_width_right = 2
	spin_style.border_color = Color(0.5, 0.4, 0.1, 0.6)
	spin_style.corner_radius_top_left = 6; spin_style.corner_radius_top_right = 6
	spin_style.corner_radius_bottom_left = 6; spin_style.corner_radius_bottom_right = 6
	spin_panel.add_theme_stylebox_override("panel", spin_style)
	vbox.add_child(spin_panel)
	
	spin_label = Label.new()
	spin_label.name = "SpinLabel"
	spin_label.text = "???"
	spin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spin_label.add_theme_font_size_override("font_size", 26)
	spin_label.add_theme_color_override("font_color", Color(1, 1, 1))
	spin_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	spin_label.add_theme_constant_override("shadow_offset_x", 2)
	spin_label.add_theme_constant_override("shadow_offset_y", 2)
	spin_panel.add_child(spin_label)
	
	# ── Result labels (hidden until spin finishes) ──
	result_rarity_label = Label.new()
	result_rarity_label.name = "RarityLabel"
	result_rarity_label.text = ""
	result_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_rarity_label.add_theme_font_size_override("font_size", 14)
	result_rarity_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	result_rarity_label.add_theme_constant_override("shadow_offset_x", 1)
	result_rarity_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(result_rarity_label)
	
	result_name_label = Label.new()
	result_name_label.name = "ResultName"
	result_name_label.text = ""
	result_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_name_label.add_theme_font_size_override("font_size", 12)
	result_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	vbox.add_child(result_name_label)
	
	result_info_label = Label.new()
	result_info_label.name = "InfoLabel"
	result_info_label.text = ""
	result_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_info_label.add_theme_font_size_override("font_size", 11)
	result_info_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	vbox.add_child(result_info_label)
	
	# ── Spacer ──
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer2)
	
	# ── ROLL Button ──
	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.text = "🎲  ROLL  🎲"
	roll_button.custom_minimum_size = Vector2(200, 40)
	roll_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.85, 0.6, 0.0, 1.0)
	btn_style.corner_radius_top_left = 8; btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8; btn_style.corner_radius_bottom_right = 8
	btn_style.border_width_top = 2; btn_style.border_width_bottom = 2
	btn_style.border_width_left = 2; btn_style.border_width_right = 2
	btn_style.border_color = Color(1.0, 0.85, 0.3)
	roll_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(1.0, 0.75, 0.0, 1.0)
	roll_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed := btn_style.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.7, 0.5, 0.0, 1.0)
	roll_button.add_theme_stylebox_override("pressed", btn_pressed)
	
	roll_button.add_theme_font_size_override("font_size", 18)
	roll_button.add_theme_color_override("font_color", Color(0.05, 0.02, 0.0))
	roll_button.add_theme_color_override("font_hover_color", Color(0.1, 0.05, 0.0))
	
	roll_button.pressed.connect(_on_roll_button_pressed)
	vbox.add_child(roll_button)
	
	# Center the button
	roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# ── CLOSE Button (hidden until result shown) ──
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "✦ Continue ✦"
	close_button.custom_minimum_size = Vector2(200, 36)
	close_button.visible = false
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.15, 0.5, 0.15, 1.0)
	close_style.corner_radius_top_left = 8; close_style.corner_radius_top_right = 8
	close_style.corner_radius_bottom_left = 8; close_style.corner_radius_bottom_right = 8
	close_style.border_width_top = 2; close_style.border_width_bottom = 2
	close_style.border_width_left = 2; close_style.border_width_right = 2
	close_style.border_color = Color(0.3, 0.8, 0.3)
	close_button.add_theme_stylebox_override("normal", close_style)
	
	var close_hover := close_style.duplicate() as StyleBoxFlat
	close_hover.bg_color = Color(0.2, 0.65, 0.2, 1.0)
	close_button.add_theme_stylebox_override("hover", close_hover)
	
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Color(1, 1, 1))
	
	close_button.pressed.connect(_on_close_button_pressed)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_button)
