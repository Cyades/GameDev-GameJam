extends Node
## GachaSystem — Companion recruitment via RNG every 5 levels
## Autoload or attach to Main scene

# ═══════════════════════════════════════════════════════════════════
# COMPANION POOL — all available gacha companions
# ═══════════════════════════════════════════════════════════════════
const COMPANION_POOL: Array[Dictionary] = [
	{ "name": "Swordsman",      "scene": "res://Scenes/Swordsman.tscn",     "rarity": "Common",   "weight": 20, "color": Color(0.7, 0.7, 0.7) },
	{ "name": "Knight",         "scene": "res://Scenes/Knight.tscn",        "rarity": "Common",   "weight": 18, "color": Color(0.7, 0.7, 0.7) },
	{ "name": "Lancer",         "scene": "res://Scenes/Lancer.tscn",        "rarity": "Uncommon", "weight": 15, "color": Color(0.3, 0.9, 0.3) },
	{ "name": "Armored Axeman", "scene": "res://Scenes/ArmoredAxeman.tscn", "rarity": "Uncommon", "weight": 14, "color": Color(0.3, 0.9, 0.3) },
	{ "name": "Archer",         "scene": "res://Scenes/Archer.tscn",        "rarity": "Rare",     "weight": 12, "color": Color(0.3, 0.5, 1.0) },
	{ "name": "Knight Templar", "scene": "res://Scenes/KnightTemplar.tscn", "rarity": "Rare",     "weight": 10, "color": Color(0.3, 0.5, 1.0) },
	{ "name": "Wizard",         "scene": "res://Scenes/Wizard.tscn",        "rarity": "Epic",     "weight": 7,  "color": Color(0.8, 0.3, 1.0) },
	{ "name": "Priest",         "scene": "res://Scenes/Priest.tscn",        "rarity": "Legendary","weight": 4,  "color": Color(1.0, 0.85, 0.0) },
]

# ═══════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════
var active_companions: Array[Node2D] = []
var gacha_popup_canvas: CanvasLayer
var gacha_panel: PanelContainer
var gacha_name_label: Label
var gacha_rarity_label: Label
var gacha_info_label: Label
var popup_timer: Timer
var is_popup_visible: bool = false

# ═══════════════════════════════════════════════════════════════════
# ROLL — weighted random selection
# ═══════════════════════════════════════════════════════════════════
func roll_companion() -> Dictionary:
	var total_weight: int = 0
	for c in COMPANION_POOL:
		total_weight += c["weight"]
	var roll := randi() % total_weight
	var cumulative: int = 0
	for c in COMPANION_POOL:
		cumulative += c["weight"]
		if roll < cumulative:
			return c
	return COMPANION_POOL[0]  # fallback

# ═══════════════════════════════════════════════════════════════════
# SPAWN — instantiate companion near player
# ═══════════════════════════════════════════════════════════════════
func spawn_companion(player: Node2D) -> void:
	var result := roll_companion()
	var scene_path: String = result["scene"]
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("GachaSystem: Cannot load scene: " + scene_path)
		return
	
	var companion := scene.instantiate() as Node2D
	if companion == null: return
	
	# Position near player with offset
	var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
	companion.global_position = player.global_position + offset
	
	# Add to same parent as player (Main scene)
	var main := player.get_parent()
	if main:
		main.add_child(companion)
	
	active_companions.append(companion)
	
	# Show popup
	_show_gacha_popup(result)
	
	print("[GACHA] Rolled: ", result["name"], " (", result["rarity"], ")")

# ═══════════════════════════════════════════════════════════════════
# CHECK — called from Player._level_up() 
# ═══════════════════════════════════════════════════════════════════
func check_gacha_trigger(player: Node2D, level: int) -> void:
	if level % 5 == 0 and level > 0:
		spawn_companion(player)

# ═══════════════════════════════════════════════════════════════════
# POPUP UI — shows what companion was rolled
# ═══════════════════════════════════════════════════════════════════
func _show_gacha_popup(result: Dictionary) -> void:
	if gacha_popup_canvas == null:
		_create_popup_ui()
	
	var companion_name: String = result["name"]
	var rarity: String = result["rarity"]
	var color: Color = result["color"]
	
	gacha_name_label.text = companion_name
	gacha_name_label.add_theme_color_override("font_color", color)
	
	gacha_rarity_label.text = "★ " + rarity + " ★"
	gacha_rarity_label.add_theme_color_override("font_color", color)
	
	gacha_info_label.text = "New companion joined your squad!"
	
	gacha_panel.visible = true
	is_popup_visible = true
	
	# Auto-hide after 3 seconds
	if popup_timer == null:
		popup_timer = Timer.new()
		popup_timer.name = "GachaPopupTimer"
		popup_timer.one_shot = true
		popup_timer.timeout.connect(_hide_gacha_popup)
		gacha_popup_canvas.add_child(popup_timer)
	popup_timer.start(3.0)

func _hide_gacha_popup() -> void:
	if gacha_panel:
		gacha_panel.visible = false
	is_popup_visible = false

func _create_popup_ui() -> void:
	gacha_popup_canvas = CanvasLayer.new()
	gacha_popup_canvas.name = "GachaPopupCanvas"
	gacha_popup_canvas.layer = 20
	
	# Get the scene tree from any node
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.add_child(gacha_popup_canvas)
	
	# Panel background
	gacha_panel = PanelContainer.new()
	gacha_panel.name = "GachaPanel"
	gacha_panel.set_anchors_preset(Control.PRESET_CENTER)
	gacha_panel.position = Vector2(-140, -70)
	gacha_panel.size = Vector2(280, 120)
	gacha_panel.visible = false
	
	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(1.0, 0.85, 0.0, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	gacha_panel.add_theme_stylebox_override("panel", style)
	gacha_popup_canvas.add_child(gacha_panel)
	
	# VBox for content
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gacha_panel.add_child(vbox)
	
	# "NEW COMPANION!" header
	var header := Label.new()
	header.text = "✦ NEW COMPANION ✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	header.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0, 0.8))
	header.add_theme_constant_override("shadow_offset_x", 1)
	header.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(header)
	
	# Companion name
	gacha_name_label = Label.new()
	gacha_name_label.text = ""
	gacha_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gacha_name_label.add_theme_font_size_override("font_size", 22)
	gacha_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	gacha_name_label.add_theme_constant_override("shadow_offset_x", 2)
	gacha_name_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(gacha_name_label)
	
	# Rarity label
	gacha_rarity_label = Label.new()
	gacha_rarity_label.text = ""
	gacha_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gacha_rarity_label.add_theme_font_size_override("font_size", 14)
	gacha_rarity_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	gacha_rarity_label.add_theme_constant_override("shadow_offset_x", 1)
	gacha_rarity_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(gacha_rarity_label)
	
	# Info label
	gacha_info_label = Label.new()
	gacha_info_label.text = ""
	gacha_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gacha_info_label.add_theme_font_size_override("font_size", 11)
	gacha_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	vbox.add_child(gacha_info_label)
