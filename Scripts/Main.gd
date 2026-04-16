extends Node2D

@export var enemy_scene: PackedScene = preload("res://Scenes/Slime.tscn")
@export var spawn_interval: float = 1.0
@export var spawn_margin: float = 64.0
@export var spawn_ring_width: float = 120.0

@onready var player: Node2D = $Player
@onready var spawn_timer: Timer = $EnemySpawnTimer
@onready var enemy_container: Node2D = $Enemies

var player_camera: Camera2D

func _ready() -> void:
	randomize()
	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	spawn_timer.wait_time = spawn_interval

	if not spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)

	spawn_timer.start()

func _on_enemy_spawn_timer_timeout() -> void:
	if enemy_scene == null or player == null:
		return

	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return

	enemy.global_position = _get_spawn_position_outside_camera()
	enemy_container.add_child(enemy)

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
