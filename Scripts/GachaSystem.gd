extends Node

const UITheme = preload("res://Scripts/UITheme.gd")
const GACHA_TOTAL_BOXES := 40
const GACHA_WINNING_INDEX := 35
const GACHA_CARD_SIZE := Vector2(80, 90)
const GACHA_CARD_GAP := 10
const GACHA_SLOT_HEIGHT := 100
const GACHA_SLOT_PADDING_Y := 5
@export_range(1, 20, 1) var gacha_level_interval: int = 3
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
var winning_slot_box: Control
var selection_frame: Control
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
	if level > 0 and level % maxi(gacha_level_interval, 1) == 0:
		_open_gacha_ui(player)

# ═══════════════════════════════════════════════════════════════════
# OPEN GACHA — pause game + show UI
# ═══════════════════════════════════════════════════════════════════
func _open_gacha_ui(player: Node2D) -> void:
	pending_player = player
	result_shown = false
	
	# Pause the game
	get_tree().paused = true
	MusicManager.play_gacha_music()
	
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
	_animate_gacha_open()
	
	# Pre-determine the result
	final_result = _roll_companion()

func _animate_gacha_open() -> void:
	main_panel.modulate.a = 0.0
	main_panel.position.y += 8.0
	dimmer.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(main_panel, "modulate:a", 1.0, 0.20).set_delay(0.04)
	tween.parallel().tween_property(main_panel, "position:y", main_panel.position.y - 8.0, 0.24).set_delay(0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	await get_tree().process_frame
	await get_tree().process_frame
	slot_strip.position.x = 0.0
	var target_x := _get_winning_snap_x()
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(slot_strip, "position:x", target_x, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_snap_strip_to_winner"))
	tween.finished.connect(_show_final_result)

func _populate_slot_strip() -> void:
	winning_slot_box = null
	
	for i in range(GACHA_TOTAL_BOXES):
		var companion: Dictionary
		if i == GACHA_WINNING_INDEX:
			companion = final_result
		else:
			companion = _roll_companion()
			
		var box = Panel.new()
		box.custom_minimum_size = GACHA_CARD_SIZE
		box.clip_contents = true
		
		var box_style = StyleBoxFlat.new()
		var base_color = companion["color"] as Color
		box_style.bg_color = base_color.lerp(Color(0.1, 0.1, 0.1), 0.7)
		box_style.border_width_top = 2; box_style.border_width_bottom = 2
		box_style.border_width_left = 2; box_style.border_width_right = 2
		box_style.border_color = base_color
		box_style.corner_radius_top_left = 6; box_style.corner_radius_top_right = 6
		box_style.corner_radius_bottom_left = 6; box_style.corner_radius_bottom_right = 6
		box_style.shadow_color = Color(0, 0, 0, 0.35)
		box_style.shadow_size = 3
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
		lbl.custom_minimum_size = Vector2(72, 16)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_label(lbl, 9, UITheme.TEXT, 0.55)
		lbl.clip_text = true
		lbl.text_overrun_behavior = 3 # OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(lbl)
		
		slot_strip.add_child(box)
		if i == GACHA_WINNING_INDEX:
			winning_slot_box = box

func _get_winning_snap_x() -> float:
	if winning_slot_box == null or not is_instance_valid(winning_slot_box):
		var center_of_window := slot_window.size.x * 0.5
		if center_of_window <= 0.0:
			center_of_window = 176.0
		return center_of_window - (float(GACHA_WINNING_INDEX) * float(GACHA_CARD_SIZE.x + GACHA_CARD_GAP) + GACHA_CARD_SIZE.x * 0.5)
	var target_center_x := _get_selection_center_global_x()
	var box_center_x := winning_slot_box.get_global_rect().get_center().x
	return slot_strip.position.x + (target_center_x - box_center_x)

func _get_selection_center_global_x() -> float:
	if selection_frame != null and is_instance_valid(selection_frame) and selection_frame.size.x > 0.0:
		return selection_frame.get_global_rect().get_center().x
	if slot_window != null and is_instance_valid(slot_window) and slot_window.size.x > 0.0:
		return slot_window.get_global_rect().get_center().x
	return 176.0

func _snap_strip_to_winner() -> void:
	if slot_strip:
		slot_strip.position.x = _get_winning_snap_x()

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
	_snap_strip_to_winner()
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
		"Common":    return "* Common *"
		"Uncommon":  return "** Uncommon **"
		"Rare":      return "*** Rare ***"
		"Epic":      return "**** Epic ****"
		"Legendary": return "***** Legendary *****"
		_:           return "* " + rarity + " *"

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
	companion.z_index = 1
	
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
	MusicManager.resume_battle_music()

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
	dimmer.color = Color(0.01, 0.006, 0.012, 0.78)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.visible = false
	gacha_canvas.add_child(dimmer)
	
	# ── Main Panel ──
	main_panel = PanelContainer.new()
	main_panel.name = "GachaMainPanel"
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.position = Vector2(-212, -170)
	main_panel.size = Vector2(424, 340)
	main_panel.visible = false
	main_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	main_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.035, 0.027, 0.045, 0.98), Color(1.0, 0.76, 0.22, 0.90), 8, 2, 16))
	gacha_canvas.add_child(main_panel)
	
	# ── VBox layout ──
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	main_panel.add_child(vbox)
	
	# ── Title ──
	var title := Label.new()
	title.text = "MERCENARY GACHA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_title_label(title, 18, UITheme.GOLD_LIGHT)
	vbox.add_child(title)
	
	# ── Subtitle ──
	var subtitle := Label.new()
	subtitle.text = "Level 5 reached! Recruit a companion!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_label(subtitle, 10, UITheme.MUTED_TEXT, 0.65)
	vbox.add_child(subtitle)
	
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer1)
	
	# ── Slot Machine Window ──
	var slot_container := Control.new()
	slot_container.custom_minimum_size = Vector2(352, GACHA_SLOT_HEIGHT)
	vbox.add_child(slot_container)
	
	var slot_bg := Panel.new()
	slot_bg.add_theme_stylebox_override("panel", UITheme.thin_panel_style(Color(0.018, 0.016, 0.030, 1.0), Color(1.0, 0.75, 0.20, 0.42)))
	slot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_container.add_child(slot_bg)
	
	slot_window = Control.new()
	slot_window.name = "SlotWindow"
	slot_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_window.clip_contents = true
	slot_container.add_child(slot_window)
	
	slot_strip = HBoxContainer.new()
	slot_strip.name = "SlotStrip"
	slot_strip.add_theme_constant_override("separation", GACHA_CARD_GAP)
	slot_strip.position = Vector2(0, GACHA_SLOT_PADDING_Y)
	slot_window.add_child(slot_strip)
	
	# Center Overlay (Golden Frame)
	var overlay_center = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_container.add_child(overlay_center)
	
	var center_frame := Panel.new()
	center_frame.custom_minimum_size = GACHA_CARD_SIZE
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
	selection_frame = center_frame
	
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
	UITheme.apply_label(result_rarity_label, 13, UITheme.GOLD_LIGHT, 0.75)
	vbox.add_child(result_rarity_label)
	
	result_name_label = Label.new()
	result_name_label.name = "ResultName"
	result_name_label.text = ""
	result_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_label(result_name_label, 14, UITheme.TEXT, 0.75)
	vbox.add_child(result_name_label)
	
	result_info_label = Label.new()
	result_info_label.name = "InfoLabel"
	result_info_label.text = ""
	result_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_label(result_info_label, 10, Color(0.62, 1.0, 0.68, 1.0), 0.60)
	vbox.add_child(result_info_label)
	
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer3)
	
	# ── ROLL Button ──
	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.text = "ROLL"
	roll_button.custom_minimum_size = Vector2(200, 40)
	roll_button.text = "ROLL"
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
	UITheme.apply_button(roll_button, UITheme.GOLD, Vector2(208, 40))
	
	roll_button.pressed.connect(_on_roll_button_pressed)
	vbox.add_child(roll_button)
	roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# ── CLOSE Button ──
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CONTINUE"
	close_button.custom_minimum_size = Vector2(200, 36)
	close_button.text = "CONTINUE"
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
	UITheme.apply_button(close_button, UITheme.EMERALD, Vector2(208, 36))
	
	close_button.pressed.connect(_on_close_button_pressed)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_button)
