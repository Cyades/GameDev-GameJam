@tool
extends Node2D

const UITheme = preload("res://Scripts/UITheme.gd")
## Main.gd — 15-minute wave spawner with scaling difficulty & boss fights

# ═══════════════════════════════════════════════════════════════════
# ENEMY SCENES  (ordered by difficulty tier)
# ═══════════════════════════════════════════════════════════════════
const SLIME          := preload("res://Scenes/Slime.tscn")
const SKELETON       := preload("res://Scenes/Skeleton.tscn")
const ORC            := preload("res://Scenes/Orc.tscn")
const SKELETON_ARCHER:= preload("res://Scenes/SkeletonArcher.tscn")
const ORC_RIDER      := preload("res://Scenes/OrcRider.tscn")
const ARMORED_ORC    := preload("res://Scenes/ArmoredOrc.tscn")
const ELITE_ORC      := preload("res://Scenes/EliteOrc.tscn")
const ARMORED_SKELETON := preload("res://Scenes/ArmoredSkeleton.tscn")
const WEREWOLF       := preload("res://Scenes/Werewolf.tscn")
const BOSS1_SCENE    := preload("res://Scenes/GreatswordSkeleton.tscn")
const BOSS2_SCENE    := preload("res://Scenes/EliteOrc.tscn")
const BOSS3_SCENE    := preload("res://Scenes/Werebear.tscn")

# ═══════════════════════════════════════════════════════════════════
# WAVE CONFIG — 15 phases (1 per minute)
# Each entry: [spawn_interval, [scene_pool], max_enemies_alive]
# ═══════════════════════════════════════════════════════════════════
var wave_config: Array = [
	# Min 0-1: Easy start — Slimes only
	{ "interval": 0.35, "pool": [SLIME, SLIME, SLIME] },
	# Min 1-2: Skeletons join
	{ "interval": 0.32, "pool": [SLIME, SLIME, SKELETON] },
	# Min 2-3: Orcs enter
	{ "interval": 0.3, "pool": [SLIME, SKELETON, ORC] },
	# Min 3-4: Ranged threat
	{ "interval": 0.27, "pool": [SKELETON, ORC, SKELETON_ARCHER] },
	# Min 4-5: Pre-boss 1
	{ "interval": 0.25, "pool": [SKELETON, ORC, SKELETON_ARCHER, ORC, ARMORED_SKELETON] },
	# Min 5-6: BOSS 1 spawned, lighter horde
	{ "interval": 0.35, "pool": [ORC, SKELETON_ARCHER, ORC_RIDER, ARMORED_SKELETON] },
	# Min 6-7: Armored Orcs
	{ "interval": 0.22, "pool": [ORC, ORC_RIDER, ARMORED_ORC, SKELETON_ARCHER, ARMORED_SKELETON] },
	# Min 7-8: Intense
	{ "interval": 0.2, "pool": [ORC_RIDER, ARMORED_ORC, SKELETON_ARCHER, ARMORED_SKELETON] },
	# Min 8-9: Recover
	{ "interval": 0.3, "pool": [SKELETON, ORC, SKELETON_ARCHER] },
	# Min 9-10: Pre-boss 2
	{ "interval": 0.2, "pool": [ORC, ORC_RIDER, ARMORED_ORC] },
	# Min 10-11: BOSS 2 spawned, lighter horde
	{ "interval": 0.35, "pool": [ORC_RIDER, ARMORED_ORC] },
	# Min 11-12: Werewolves appear
	{ "interval": 0.2, "pool": [WEREWOLF, ARMORED_ORC, ARMORED_SKELETON] },
	# Min 12-13: Full horde
	{ "interval": 0.17, "pool": [WEREWOLF, ORC_RIDER, ARMORED_ORC] },
	# Min 13-14: Pre-final boss — maximum intensity
	{ "interval": 0.15, "pool": [WEREWOLF, WEREWOLF, ARMORED_ORC, ORC_RIDER] },
	# Min 14-15: FINAL BOSS — lighter horde
	{ "interval": 0.3, "pool": [WEREWOLF, ARMORED_ORC] },
]

@export var spawn_margin: float = 64.0
@export var spawn_ring_width: float = 120.0
@export var game_duration: float = 900.0  # 15 minutes = 900 seconds

# Arena boundary (centered at origin)
const ARENA_HALF_SIZE: float = 1280.0  # 2560x2560 px total arena
const ENVIRONMENT_COLLISION_SOURCES: Dictionary = {
	&"TileMapLayer3": [0], # Large nature props such as trees
	&"TileMapLayer4": [0, 1, 2, 3], # Village ruins, houses, towers, and camp structures
	&"TileMapLayer5": [0, 1], # Rocks, logs, and any wall structures on the prop layer
}

@onready var player: Node2D = $Player
@onready var spawn_timer: Timer = $EnemySpawnTimer
@onready var enemy_container: Node2D = $Enemies

var player_camera: Camera2D
var elapsed_time: float = 0.0
var current_wave: int = 0
var boss1_spawned: bool = false
var boss2_spawned: bool = false
var boss3_spawned: bool = false
var boss1_alive: bool = false
var boss2_alive: bool = false
var boss3_alive: bool = false
var boss1_incoming_shown: bool = false
var boss2_incoming_shown: bool = false
var boss3_incoming_shown: bool = false
var game_won: bool = false
var kill_count: int = 0

# Timer HUD
var timer_canvas: CanvasLayer
var timer_panel: PanelContainer
var kill_panel: PanelContainer
var boss_warning_panel: PanelContainer
var timer_label: Label
var kill_label: Label
var kill_count_label: Label
var boss_warning_label: Label
var boss_warning_tween: Tween

# Gacha System
var gacha_system: Node

func _ready() -> void:
	# Always create boundary (works in editor + runtime)
	_create_arena_boundary()
	_create_environment_collisions()

	# Skip game logic when running inside the Godot editor
	if Engine.is_editor_hint():
		return

	MusicManager.play_battle_music()

	randomize()
	# Enable Y-sorting: characters lower on screen render in front
	y_sort_enabled = true
	var enemies_node := get_node_or_null("Enemies")
	if enemies_node and enemies_node is Node2D:
		(enemies_node as Node2D).y_sort_enabled = true
	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	_apply_wave(0)
	_create_timer_hud()
	_setup_gacha_system()
	
	# Instantiate Pause Menu
	var pause_menu = preload("res://Scenes/UI/PauseMenu.tscn").instantiate()
	add_child(pause_menu)
	
	if not spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
	spawn_timer.start()


# ═══════════════════════════════════════════════════════════════════
# ARENA BOUNDARY
# ═══════════════════════════════════════════════════════════════════

func _create_arena_boundary() -> void:
	var h := ARENA_HALF_SIZE
	var wall_thickness := 48.0  # thick enough to block fast movement

	# ── 1. Thick collision walls (4 sides) ─────────────────────────
	# Position at the EDGE so inner face = ±h
	var wall_defs := [
		# [center_x, center_y, size_x,        size_y,        visual_color,    name]
		[0.0,    -(h + wall_thickness * 0.5),  h * 2 + wall_thickness * 2, wall_thickness, "574a3b", "WallTop"],
		[0.0,     (h + wall_thickness * 0.5),  h * 2 + wall_thickness * 2, wall_thickness, "574a3b", "WallBottom"],
		[-(h + wall_thickness * 0.5),  0.0,   wall_thickness, h * 2,  "574a3b", "WallLeft"],
		[ (h + wall_thickness * 0.5),  0.0,   wall_thickness, h * 2,  "574a3b", "WallRight"],
	]

	for wd in wall_defs:
		var body := StaticBody2D.new()
		body.name = wd[5]
		body.position = Vector2(wd[0], wd[1])

		# Collision
		var coll := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(wd[2], wd[3])
		coll.shape = rect
		body.add_child(coll)

		# Visual — dark stone wall polygon
		var poly := Polygon2D.new()
		var hw: float = float(wd[2]) * 0.5
		var hh: float = float(wd[3]) * 0.5
		poly.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh),
			Vector2(hw,  hh),  Vector2(-hw,  hh)
		])
		poly.color = Color.from_string(wd[4], Color.DARK_SLATE_GRAY)
		poly.z_index = -2
		body.add_child(poly)

		add_child(body)

	# ── 2. Visual border line (inner edge) ─────────────────────────
	var border_pts := PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h),
		Vector2(h,  h),  Vector2(-h,  h),
		Vector2(-h, -h)
	])
	var border := Line2D.new()
	border.name = "ArenaBorderLine"
	border.points = border_pts
	border.width = 4.0
	border.default_color = Color(1.0, 0.82, 0.3, 1.0)
	border.z_index = 1
	add_child(border)

	# Corner cross markers
	var corner_positions := [
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
	]
	for cp in corner_positions:
		for pts in [
			[cp + Vector2(-28, 0), cp + Vector2(28, 0)],
			[cp + Vector2(0, -28), cp + Vector2(0, 28)]
		]:
			var ln := Line2D.new()
			ln.points = PackedVector2Array(pts)
			ln.width = 4.0
			ln.default_color = Color(1.0, 0.9, 0.4, 1.0)
			ln.z_index = 2
			add_child(ln)

# Build solid collision from configured map prop tile sources.
func _create_environment_collisions() -> void:
	var old_existing := get_node_or_null("EnvironmentBuildingCollisions")
	if old_existing:
		old_existing.free()

	var existing := get_node_or_null("EnvironmentCollisions")
	if existing:
		existing.free()

	var collision_body := StaticBody2D.new()
	collision_body.name = "EnvironmentCollisions"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 1
	add_child(collision_body)

	for layer_name: StringName in ENVIRONMENT_COLLISION_SOURCES:
		var layer := get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue

		var solid_cells: Dictionary = {}
		var source_ids: Array = ENVIRONMENT_COLLISION_SOURCES[layer_name]
		for cell: Vector2i in layer.get_used_cells():
			if source_ids.has(layer.get_cell_source_id(cell)):
				solid_cells[cell] = true

		_add_merged_tile_collisions(collision_body, layer, solid_cells)

func _add_merged_tile_collisions(body: StaticBody2D, layer: TileMapLayer, solid_cells: Dictionary) -> void:
	var cells_by_row: Dictionary = {}
	for cell: Vector2i in solid_cells:
		if not cells_by_row.has(cell.y):
			cells_by_row[cell.y] = []
		cells_by_row[cell.y].append(cell.x)

	for row_y: int in cells_by_row:
		var row_cells: Array = cells_by_row[row_y]
		row_cells.sort()
		if row_cells.is_empty():
			continue

		var run_start: int = row_cells[0]
		var previous_x: int = row_cells[0]
		for index in range(1, row_cells.size()):
			var cell_x: int = row_cells[index]
			if cell_x != previous_x + 1:
				_add_tile_collision_run(body, layer, row_y, run_start, previous_x)
				run_start = cell_x
			previous_x = cell_x
		_add_tile_collision_run(body, layer, row_y, run_start, previous_x)

func _add_tile_collision_run(body: StaticBody2D, layer: TileMapLayer, row_y: int, start_x: int, end_x: int) -> void:
	var first_local := layer.map_to_local(Vector2i(start_x, row_y))
	var last_local := layer.map_to_local(Vector2i(end_x, row_y))
	var center_global := layer.to_global((first_local + last_local) * 0.5)
	var tile_size := Vector2(layer.tile_set.tile_size)

	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(absf(last_local.x - first_local.x) + tile_size.x, tile_size.y)

	var collision := CollisionShape2D.new()
	collision.position = body.to_local(center_global)
	collision.shape = rectangle
	body.add_child(collision)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if game_won: return
	elapsed_time += delta
	
	# Update timer HUD
	_update_timer_hud()
	
	# Update wave based on elapsed minutes
	var minute := int(elapsed_time / 60.0)
	minute = clampi(minute, 0, wave_config.size() - 1)
	if minute != current_wave:
		current_wave = minute
		_apply_wave(current_wave)
		
	# Trigger Boss Music 5 seconds before spawn
	if not boss1_spawned and elapsed_time >= 295.0 and elapsed_time < 300.0 and MusicManager.current_state != "boss":
		MusicManager.play_boss_music()
	if not boss2_spawned and elapsed_time >= 595.0 and elapsed_time < 600.0 and MusicManager.current_state != "boss":
		MusicManager.play_boss_music()
	if not boss3_spawned and elapsed_time >= 895.0 and elapsed_time < 900.0 and MusicManager.current_state != "boss":
		MusicManager.play_boss_music()

	if not boss1_incoming_shown and not boss1_spawned and elapsed_time >= 295.0 and elapsed_time < 300.0:
		boss1_incoming_shown = true
		_show_boss_warning_once("BOSS INCOMING", UITheme.RUBY)
	if not boss2_incoming_shown and not boss2_spawned and elapsed_time >= 595.0 and elapsed_time < 600.0:
		boss2_incoming_shown = true
		_show_boss_warning_once("BOSS INCOMING", UITheme.RUBY)
	if not boss3_incoming_shown and not boss3_spawned and elapsed_time >= 895.0 and elapsed_time < 900.0:
		boss3_incoming_shown = true
		_show_boss_warning_once("FINAL BOSS INCOMING", UITheme.RUBY)
	
	# BOSS 1 — spawn at minute 5 (300s)
	if not boss1_spawned and elapsed_time >= 300.0:
		boss1_spawned = true; boss1_alive = true
		_spawn_boss(BOSS1_SCENE, 1)
		
	# BOSS 2 — spawn at minute 10 (600s)
	if not boss2_spawned and elapsed_time >= 600.0:
		boss2_spawned = true; boss2_alive = true
		_spawn_boss(BOSS2_SCENE, 2)
	
	# BOSS 3 — spawn at minute 15 (900s)
	if not boss3_spawned and elapsed_time >= 900.0:
		boss3_spawned = true; boss3_alive = true
		_spawn_boss(BOSS3_SCENE, 3)

func _apply_wave(wave_idx: int) -> void:
	if wave_idx < 0 or wave_idx >= wave_config.size(): return
	var cfg: Dictionary = wave_config[wave_idx]
	spawn_timer.wait_time = cfg["interval"]

func _on_enemy_spawn_timer_timeout() -> void:
	if player == null or game_won: return
	var wave_idx := clampi(current_wave, 0, wave_config.size() - 1)
	var cfg: Dictionary = wave_config[wave_idx]
	var pool: Array = cfg["pool"]
	
	var scene: PackedScene = pool[randi() % pool.size()]
	if scene == null: return
	var enemy := scene.instantiate() as Node2D
	if enemy == null: return
	enemy.z_index = 1
	
	# Apply HP scaling based on time
	var minute := int(elapsed_time / 60.0)
	var hp_multiplier = 1.0 + (minute * 0.3)
	if enemy.get("max_health") != null:
		enemy.set("max_health", int(enemy.get("max_health") * hp_multiplier))
	
	enemy.global_position = _get_spawn_position_outside_camera()
	enemy_container.add_child(enemy)
	
	# Track kills via tree_exiting
	enemy.tree_exiting.connect(_on_enemy_killed)

func _on_enemy_killed() -> void:
	kill_count += 1

func _spawn_boss(boss_scene: PackedScene, boss_index: int) -> void:
	var boss := boss_scene.instantiate() as Node2D
	if boss == null: return
	boss.z_index = 1
	
	if boss_index == 2:
		boss.add_to_group("boss")
		boss.scale = Vector2(3.0, 3.0)
		if boss.get("max_health") != null:
			boss.set("max_health", 1500)
			
	boss.global_position = _get_spawn_position_outside_camera()
	enemy_container.add_child(boss)
	_show_boss_warning_once(_get_boss_display_name(boss_index), UITheme.RUBY)
	
	# Connect boss_defeated signal
	if boss.has_signal("boss_defeated"):
		if boss_index == 1:
			boss.boss_defeated.connect(_on_boss1_defeated)
		elif boss_index == 2:
			boss.boss_defeated.connect(_on_boss2_defeated)
		elif boss_index == 3:
			boss.boss_defeated.connect(_on_boss3_defeated)

func _on_boss1_defeated() -> void:
	boss1_alive = false
	print("[BOSS] Greatsword Skeleton defeated!")
	MusicManager.resume_battle_music()

func _on_boss2_defeated() -> void:
	boss2_alive = false
	print("[BOSS] Elite Orc defeated!")
	MusicManager.resume_battle_music()

func _on_boss3_defeated() -> void:
	boss3_alive = false
	game_won = true
	print("[GAME] YOU WIN! Werebear defeated!")
	MusicManager.play_win_music()
	_show_boss_warning_once("YOU WIN!", UITheme.GOLD_LIGHT, 2.0)
	
	# Show victory screen after a short delay
	await get_tree().create_timer(1.8).timeout
	var win_menu = preload("res://Scenes/UI/GameOverMenu.tscn").instantiate()
	get_tree().root.add_child(win_menu)
	win_menu.set_victory()
	get_tree().paused = true

func _get_boss_display_name(boss_index: int) -> String:
	match boss_index:
		1: return "GREATSWORD SKELETON"
		2: return "ELITE ORC"
		3: return "WEREBEAR"
		_: return "BOSS"

func _get_spawn_position_outside_camera() -> Vector2:
	var center := player.global_position
	var viewport_size := get_viewport().get_visible_rect().size
	if player_camera != null and player_camera.enabled:
		viewport_size *= player_camera.zoom
	var min_radius := (viewport_size.length() * 0.5) + spawn_margin
	var max_radius := min_radius + spawn_ring_width
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(min_radius, max_radius)
	var raw_pos := center + Vector2.RIGHT.rotated(angle) * radius
	# Clamp inside arena walls (with a small margin so enemy isn't inside wall)
	var wall_margin := 24.0
	var limit := ARENA_HALF_SIZE - wall_margin
	return Vector2(
		clampf(raw_pos.x, -limit, limit),
		clampf(raw_pos.y, -limit, limit)
	)

func get_elapsed_time() -> float: return elapsed_time
func get_kill_count() -> int: return kill_count
func get_game_duration() -> float: return game_duration

# ═══════════════════════════════════════════════════════════════════
# GACHA SYSTEM
# ═══════════════════════════════════════════════════════════════════
const GachaSystemScript = preload("res://Scripts/GachaSystem.gd")

func _setup_gacha_system() -> void:
	gacha_system = Node.new()
	gacha_system.name = "GachaSystem"
	gacha_system.set_script(GachaSystemScript)
	add_child(gacha_system)
	# Set player reference so gacha can be triggered from Player._level_up()
	if player and player.has_method("set_gacha_system"):
		player.set_gacha_system(gacha_system)

# ═══════════════════════════════════════════════════════════════════
# TIMER HUD
# ═══════════════════════════════════════════════════════════════════
func _create_timer_hud() -> void:
	timer_canvas = CanvasLayer.new()
	timer_canvas.name = "TimerHUD"
	timer_canvas.layer = 10
	add_child(timer_canvas)

	timer_panel = PanelContainer.new()
	timer_panel.name = "TimerPanel"
	timer_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_panel.position = Vector2(-40, 6)
	timer_panel.size = Vector2(80, 20)
	timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.add_theme_stylebox_override("panel", UITheme.thin_panel_style(Color(0.02, 0.018, 0.03, 0.82), Color(1.0, 0.74, 0.22, 0.42)))
	timer_canvas.add_child(timer_panel)

	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "15:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_label(timer_label, 12, UITheme.GOLD_LIGHT, 0.8)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.add_child(timer_label)

	kill_panel = PanelContainer.new()
	kill_panel.name = "KillPanel"
	kill_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kill_panel.position = Vector2(-88, 6)
	kill_panel.size = Vector2(82, 20)
	kill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_panel.add_theme_stylebox_override("panel", UITheme.thin_panel_style(Color(0.02, 0.018, 0.03, 0.78), Color(1.0, 0.74, 0.22, 0.30)))
	timer_canvas.add_child(kill_panel)

	var kill_row := HBoxContainer.new()
	kill_row.name = "KillRow"
	kill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	kill_row.add_theme_constant_override("separation", 5)
	kill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_panel.add_child(kill_row)

	kill_label = Label.new()
	kill_label.name = "KillTitle"
	kill_label.text = "KILLS"
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_label(kill_label, 8, UITheme.TEXT, 0.7)
	kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_row.add_child(kill_label)

	kill_count_label = Label.new()
	kill_count_label.name = "KillCount"
	kill_count_label.text = "0"
	kill_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kill_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_label(kill_count_label, 8, UITheme.TEXT, 0.7)
	kill_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_row.add_child(kill_count_label)

	boss_warning_panel = PanelContainer.new()
	boss_warning_panel.name = "BossWarningPanel"
	boss_warning_panel.set_anchors_preset(Control.PRESET_CENTER)
	boss_warning_panel.position = Vector2(-140, -48)
	boss_warning_panel.size = Vector2(280, 32)
	boss_warning_panel.visible = false
	boss_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_warning_panel.add_theme_stylebox_override("panel", UITheme.thin_panel_style(Color(0.075, 0.012, 0.018, 0.88), Color(1.0, 0.28, 0.16, 0.88)))
	timer_canvas.add_child(boss_warning_panel)

	boss_warning_label = Label.new()
	boss_warning_label.name = "BossWarning"
	boss_warning_label.text = ""
	boss_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_title_label(boss_warning_label, 13, UITheme.RUBY)
	boss_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_warning_panel.add_child(boss_warning_label)

func _set_boss_warning(text: String, color: Color = Color(0.92, 0.18, 0.14, 1.0)) -> void:
	if boss_warning_label == null:
		return
	boss_warning_label.text = text
	boss_warning_label.add_theme_color_override("font_color", color)
	if boss_warning_panel:
		boss_warning_panel.visible = not text.is_empty()

func _show_boss_warning_once(text: String, color: Color = Color(0.92, 0.18, 0.14, 1.0), duration: float = 2.4) -> void:
	if boss_warning_label == null or boss_warning_panel == null:
		return
	if boss_warning_tween != null:
		boss_warning_tween.kill()

	boss_warning_panel.modulate.a = 1.0
	_set_boss_warning(text, color)

	boss_warning_tween = create_tween()
	boss_warning_tween.tween_interval(duration)
	boss_warning_tween.tween_property(boss_warning_panel, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	boss_warning_tween.tween_callback(Callable(self, "_hide_boss_warning"))

func _hide_boss_warning() -> void:
	_set_boss_warning("")
	if boss_warning_panel:
		boss_warning_panel.modulate.a = 1.0
	boss_warning_tween = null

func _create_timer_hud_old() -> void:
	timer_canvas = CanvasLayer.new()
	timer_canvas.name = "TimerHUD"
	timer_canvas.layer = 10
	add_child(timer_canvas)
	
	# Timer label — top center
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "15:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.position = Vector2(-60, 8)
	timer_label.size = Vector2(120, 30)
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	timer_label.add_theme_constant_override("shadow_offset_x", 2)
	timer_label.add_theme_constant_override("shadow_offset_y", 2)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_canvas.add_child(timer_label)
	
	# Kill count label — top right
	kill_label = Label.new()
	kill_label.name = "KillLabel"
	kill_label.text = "Kills: 0"
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kill_label.position = Vector2(-140, 8)
	kill_label.size = Vector2(130, 24)
	kill_label.add_theme_font_size_override("font_size", 16)
	kill_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	kill_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	kill_label.add_theme_constant_override("shadow_offset_x", 1)
	kill_label.add_theme_constant_override("shadow_offset_y", 1)
	kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_canvas.add_child(kill_label)
	
	# Boss warning label — center screen (hidden by default)
	boss_warning_label = Label.new()
	boss_warning_label.name = "BossWarning"
	boss_warning_label.text = ""
	boss_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_warning_label.set_anchors_preset(Control.PRESET_CENTER)
	boss_warning_label.position = Vector2(-200, -60)
	boss_warning_label.size = Vector2(400, 40)
	boss_warning_label.add_theme_font_size_override("font_size", 28)
	boss_warning_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	boss_warning_label.add_theme_color_override("font_shadow_color", Color(0.3, 0, 0, 0.9))
	boss_warning_label.add_theme_constant_override("shadow_offset_x", 2)
	boss_warning_label.add_theme_constant_override("shadow_offset_y", 2)
	boss_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_warning_label.visible = false
	timer_canvas.add_child(boss_warning_label)

func _update_timer_hud() -> void:
	# Update timer — show remaining time
	var remaining := maxf(game_duration - elapsed_time, 0.0)
	@warning_ignore("integer_division")
	var mins := int(remaining) / 60
	@warning_ignore("integer_division")
	var secs := int(remaining) % 60
	if timer_label:
		timer_label.text = "%02d:%02d" % [mins, secs]
		# Flash red in last 30 seconds
		if remaining <= 30.0:
			var pulse := 0.5 + 0.5 * sin(elapsed_time * 4.0)
			timer_label.add_theme_color_override("font_color", Color(1.0, pulse, pulse, 1.0))
		else:
			timer_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	
	# Update kill count
	if kill_count_label:
		kill_count_label.text = str(kill_count)
