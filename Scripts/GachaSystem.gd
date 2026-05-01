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
var slot_window: Control       # Window that clips the strip
var slot_strip: HBoxContainer  # The moving strip of character boxes
var result_name_label: Label
var result_rarity_label: Label
var result_info_label: Label
var close_button: Button

# Spin state
var is_spinning: bool = false
var final_result: Dictionary = {}
var spin_started: bool = false
var result_shown: bool = false
var sprite_cache: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════
# PROCESS — runs during pause (process_mode = ALWAYS)
# ═══════════════════════════════════════════════════════════════════
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	slot_strip.position.x = 0
	for child in slot_strip.get_children():
		child.queue_free()
		
	result_name_label.text = ""
	result_rarity_label.text = ""
	result_info_label.text = ""
	roll_button.visible = true
	roll_button.disabled = false
	close_button.visible = false
	main_panel.visible = true
	dimmer.visible = true
	
	# Pre-determine the result
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
	
	is_spinning = true
	spin_started = true
	
	_populate_slot_strip()
	
	# To ensure perfect alignment even before UI updates, we calculate the exact target position mathematically
	var winning_index = 35
	var box_width = 80.0
	var separation = 10.0
	
	var box_center_x = (winning_index * (box_width + separation)) + (box_width / 2.0)
	var center_of_window = 340.0 / 2.0 # slot_container width is 340
	var target_x = center_of_window - box_center_x
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(slot_strip, "position:x", target_x, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_show_final_result)

func _populate_slot_strip() -> void:
	var total_boxes = 40
	var winning_index = 35
	
	for i in range(total_boxes):
		var companion: Dictionary
		if i == winning_index:
			companion = final_result
		else:
			companion = _roll_companion()
			
		var box = Panel.new()
		box.custom_minimum_size = Vector2(80, 90)
		box.clip_contents = true
		
		var box_style = StyleBoxFlat.new()
		var base_color = companion["color"] as Color
		box_style.bg_color = base_color.lerp(Color(0.1, 0.1, 0.1), 0.7)
		box_style.border_width_top = 2; box_style.border_width_bottom = 2
		box_style.border_width_left = 2; box_style.border_width_right = 2
		box_style.border_color = base_color
		box_style.corner_radius_top_left = 6; box_style.corner_radius_top_right = 6
		box_style.corner_radius_bottom_left = 6; box_style.corner_radius_bottom_right = 6
		box.add_theme_stylebox_override("panel", box_style)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(vbox)
		
		var sprite_space = Control.new()
		sprite_space.custom_minimum_size = Vector2(70, 50)
		vbox.add_child(sprite_space)
		
		var frames = _get_sprite_frames(companion["name"], companion["scene"])
		if frames:
			var sprite = AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.animation = "idle"
			sprite.play()
			sprite.position = Vector2(35, 30)
			sprite.scale = Vector2(1.5, 1.5)
			sprite_space.add_child(sprite)
			
		var lbl = Label.new()
		lbl.text = companion["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.text_overrun_behavior = 3 # OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(lbl)
		
		slot_strip.add_child(box)

func _get_sprite_frames(comp_name: String, scene_path: String) -> SpriteFrames:
	if sprite_cache.has(comp_name):
		return sprite_cache[comp_name]
		
	var scene = load(scene_path) as PackedScene
	if scene:
		var instance = scene.instantiate()
		var src_sprite = instance.get_node_or_null("AnimatedSprite2D")
		if src_sprite:
			var frames = src_sprite.sprite_frames
			sprite_cache[comp_name] = frames
			instance.free()
			return frames
		instance.free()
	return null

func _show_final_result() -> void:
	if result_shown: return
	result_shown = true
	is_spinning = false
	
	var name_text: String = final_result["name"]
	var rarity: String = final_result["rarity"]
	var color: Color = final_result["color"]
	
	result_name_label.text = name_text
	result_name_label.add_theme_color_override("font_color", color)
	
	result_rarity_label.text = _get_rarity_stars(rarity)
	result_rarity_label.add_theme_color_override("font_color", color)
	
	result_info_label.text = "New companion joined your squad!"
	
	close_button.visible = true
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
	
	var player_lvl := pending_player.get("current_level") as int if pending_player.get("current_level") != null else 1
	var level_multiplier := 1.0 + (player_lvl * 0.1)
	
	if companion.get("max_health") != null:
		companion.set("max_health", int(companion.get("max_health") * level_multiplier))
	for dmg_prop in ["attack_damage", "attack01_damage", "attack02_damage", "attack03_damage", "arrow_damage", "knockback_force"]:
		if companion.get(dmg_prop) != null:
			companion.set(dmg_prop, int(companion.get(dmg_prop) * level_multiplier))
	
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
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.visible = false
	gacha_canvas.add_child(dimmer)
	
	# ── Main Panel ──
	main_panel = PanelContainer.new()
	main_panel.name = "GachaMainPanel"
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.position = Vector2(-200, -180)
	main_panel.size = Vector2(400, 360)
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
	vbox.add_theme_constant_override("separation", 8)
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
	
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer1)
	
	# ── Slot Machine Window ──
	var slot_container := Control.new()
	slot_container.custom_minimum_size = Vector2(340, 100)
	vbox.add_child(slot_container)
	
	var slot_bg := ColorRect.new()
	slot_bg.color = Color(0.03, 0.03, 0.08, 1.0)
	slot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_container.add_child(slot_bg)
	
	slot_window = Control.new()
	slot_window.name = "SlotWindow"
	slot_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_window.clip_contents = true
	slot_container.add_child(slot_window)
	
	slot_strip = HBoxContainer.new()
	slot_strip.name = "SlotStrip"
	slot_strip.add_theme_constant_override("separation", 10)
	slot_strip.position = Vector2(0, 5)
	slot_window.add_child(slot_strip)
	
	# Center Overlay (Golden Frame)
	var overlay_center = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_container.add_child(overlay_center)
	
	var center_frame := Panel.new()
	center_frame.custom_minimum_size = Vector2(88, 98) # Slightly larger than the 80x90 character box
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_width_top = 4; frame_style.border_width_bottom = 4
	frame_style.border_width_left = 4; frame_style.border_width_right = 4
	frame_style.border_color = Color(1.0, 0.85, 0.0, 0.9)
	frame_style.corner_radius_top_left = 8; frame_style.corner_radius_top_right = 8
	frame_style.corner_radius_bottom_left = 8; frame_style.corner_radius_bottom_right = 8
	center_frame.add_theme_stylebox_override("panel", frame_style)
	
	center_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_center.add_child(center_frame)
	
	# Highlight Glow for Center
	var glow := Panel.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 1.0, 0.8, 0.1)
	glow_style.corner_radius_top_left = 8; glow_style.corner_radius_top_right = 8
	glow_style.corner_radius_bottom_left = 8; glow_style.corner_radius_bottom_right = 8
	glow.add_theme_stylebox_override("panel", glow_style)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_frame.add_child(glow)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer2)
	
	# ── Result labels ──
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
	result_name_label.add_theme_font_size_override("font_size", 14)
	result_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	vbox.add_child(result_name_label)
	
	result_info_label = Label.new()
	result_info_label.name = "InfoLabel"
	result_info_label.text = ""
	result_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_info_label.add_theme_font_size_override("font_size", 11)
	result_info_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	vbox.add_child(result_info_label)
	
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer3)
	
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
	roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# ── CLOSE Button ──
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
