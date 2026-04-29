extends Node2D
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
const WEREWOLF       := preload("res://Scenes/Werewolf.tscn")
const BOSS1_SCENE    := preload("res://Scenes/GreatswordSkeleton.tscn")
const BOSS2_SCENE    := preload("res://Scenes/Werebear.tscn")

# ═══════════════════════════════════════════════════════════════════
# WAVE CONFIG — 15 phases (1 per minute)
# Each entry: [spawn_interval, [scene_pool], max_enemies_alive]
# ═══════════════════════════════════════════════════════════════════
var wave_config: Array = [
	# Min 0-1: Easy start — Slimes only
	{ "interval": 1.2, "pool": [SLIME, SLIME, SLIME], "max": 10 },
	# Min 1-2: Skeletons join
	{ "interval": 1.1, "pool": [SLIME, SLIME, SKELETON], "max": 12 },
	# Min 2-3: Orcs enter
	{ "interval": 1.0, "pool": [SLIME, SKELETON, ORC], "max": 14 },
	# Min 3-4: Ranged threat
	{ "interval": 0.9, "pool": [SKELETON, ORC, SKELETON_ARCHER], "max": 16 },
	# Min 4-5: Mixed horde
	{ "interval": 0.85, "pool": [SKELETON, ORC, SKELETON_ARCHER, ORC], "max": 18 },
	# Min 5-6: Orc Riders appear
	{ "interval": 0.8, "pool": [ORC, SKELETON_ARCHER, ORC_RIDER], "max": 20 },
	# Min 6-7: Armored Orcs
	{ "interval": 0.75, "pool": [ORC, ORC_RIDER, ARMORED_ORC, SKELETON_ARCHER], "max": 22 },
	# Min 7-8: Pre-boss — intense  (BOSS at end of min 8)
	{ "interval": 0.7, "pool": [ORC_RIDER, ARMORED_ORC, SKELETON_ARCHER, ELITE_ORC], "max": 24 },
	# Min 8-9: BOSS 1 spawned, lighter horde
	{ "interval": 1.0, "pool": [SKELETON, ORC, SKELETON_ARCHER], "max": 15 },
	# Min 9-10: Post-boss recovery
	{ "interval": 0.9, "pool": [ORC, ORC_RIDER, ARMORED_ORC], "max": 18 },
	# Min 10-11: Elite horde
	{ "interval": 0.8, "pool": [ORC_RIDER, ARMORED_ORC, ELITE_ORC], "max": 22 },
	# Min 11-12: Werewolves appear
	{ "interval": 0.7, "pool": [ELITE_ORC, WEREWOLF, ARMORED_ORC], "max": 24 },
	# Min 12-13: Full horde
	{ "interval": 0.65, "pool": [ELITE_ORC, WEREWOLF, ORC_RIDER, ARMORED_ORC], "max": 26 },
	# Min 13-14: Pre-final boss — maximum intensity
	{ "interval": 0.6, "pool": [ELITE_ORC, WEREWOLF, WEREWOLF, ARMORED_ORC], "max": 28 },
	# Min 14-15: FINAL BOSS — lighter horde
	{ "interval": 0.9, "pool": [WEREWOLF, ELITE_ORC], "max": 16 },
]

@export var spawn_margin: float = 64.0
@export var spawn_ring_width: float = 120.0
@export var game_duration: float = 900.0  # 15 minutes = 900 seconds

@onready var player: Node2D = $Player
@onready var spawn_timer: Timer = $EnemySpawnTimer
@onready var enemy_container: Node2D = $Enemies

var player_camera: Camera2D
var elapsed_time: float = 0.0
var current_wave: int = 0
var boss1_spawned: bool = false
var boss2_spawned: bool = false
var boss1_alive: bool = false
var boss2_alive: bool = false
var game_won: bool = false
var kill_count: int = 0

# Timer HUD
var timer_canvas: CanvasLayer
var timer_label: Label
var kill_label: Label
var boss_warning_label: Label

# Gacha System
var gacha_system: Node

func _ready() -> void:
	randomize()
	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	_apply_wave(0)
	_create_timer_hud()
	_setup_gacha_system()
	if not spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
	spawn_timer.start()

func _process(delta: float) -> void:
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
	
	# BOSS 1 — spawn at minute 8 (480s)
	if not boss1_spawned and elapsed_time >= 480.0:
		boss1_spawned = true; boss1_alive = true
		_spawn_boss(BOSS1_SCENE, true)
	
	# BOSS 2 — spawn at minute 15 (900s)
	if not boss2_spawned and elapsed_time >= 900.0:
		boss2_spawned = true; boss2_alive = true
		_spawn_boss(BOSS2_SCENE, false)

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
	enemy.global_position = _get_spawn_position_outside_camera()
	enemy_container.add_child(enemy)
	
	# Track kills via tree_exiting
	enemy.tree_exiting.connect(_on_enemy_killed)

func _on_enemy_killed() -> void:
	kill_count += 1

func _spawn_boss(boss_scene: PackedScene, is_first_boss: bool) -> void:
	var boss := boss_scene.instantiate() as Node2D
	if boss == null: return
	boss.global_position = _get_spawn_position_outside_camera()
	enemy_container.add_child(boss)
	
	# Connect boss_defeated signal
	if boss.has_signal("boss_defeated"):
		if is_first_boss:
			boss.boss_defeated.connect(_on_boss1_defeated)
		else:
			boss.boss_defeated.connect(_on_boss2_defeated)

func _on_boss1_defeated() -> void:
	boss1_alive = false
	print("[BOSS] Greatsword Skeleton defeated!")

func _on_boss2_defeated() -> void:
	boss2_alive = false
	game_won = true
	print("[GAME] YOU WIN! Werebear defeated!")
	# TODO: Show victory screen

func _get_spawn_position_outside_camera() -> Vector2:
	var center := player.global_position
	var viewport_size := get_viewport().get_visible_rect().size
	if player_camera != null and player_camera.enabled:
		viewport_size *= player_camera.zoom
	var min_radius := (viewport_size.length() * 0.5) + spawn_margin
	var max_radius := min_radius + spawn_ring_width
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(min_radius, max_radius)
	return center + Vector2.RIGHT.rotated(angle) * radius

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
	var mins := int(remaining) / 60
	var secs := int(remaining) % 60
	if timer_label:
		timer_label.text = "%02d:%02d" % [mins, secs]
		# Flash red in last 30 seconds
		if remaining <= 30.0:
			var pulse := 0.5 + 0.5 * sin(elapsed_time * 4.0)
			timer_label.add_theme_color_override("font_color", Color(1.0, pulse, pulse, 1.0))
	
	# Update kill count
	if kill_label:
		kill_label.text = "Kills: " + str(kill_count)
	
	# Boss warnings
	if boss_warning_label:
		# 5 seconds before boss 1
		if not boss1_spawned and elapsed_time >= 475.0 and elapsed_time < 480.0:
			boss_warning_label.text = "⚔ BOSS INCOMING ⚔"
			boss_warning_label.visible = true
		# 5 seconds before boss 2
		elif not boss2_spawned and elapsed_time >= 895.0 and elapsed_time < 900.0:
			boss_warning_label.text = "🐻 FINAL BOSS INCOMING 🐻"
			boss_warning_label.visible = true
		# Show when boss is alive
		elif boss1_alive and not boss2_spawned:
			boss_warning_label.text = "⚔ GREATSWORD SKELETON ⚔"
			boss_warning_label.visible = true
		elif boss2_alive:
			boss_warning_label.text = "🐻 WEREBEAR 🐻"
			boss_warning_label.visible = true
		elif game_won:
			boss_warning_label.text = "🏆 YOU WIN! 🏆"
			boss_warning_label.visible = true
			boss_warning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
		else:
			boss_warning_label.visible = false
