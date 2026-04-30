extends CharacterBody2D
## Swordsman — Melee Dash Attacker companion
## attack01: Quick slash (low dmg, fast), attack02: Heavy combo (high dmg, slow),
## attack03: Dash Attack — lunges forward toward enemy

@export var move_speed: float = 140.0
@export var follow_distance: float = 35.0
@export var max_health: int = 18
@export var attack01_damage: int = 2
@export var attack02_damage: int = 4
@export var attack03_damage: int = 6
@export var attack_range: float = 35.0
@export var dash_range: float = 60.0
@export var dash_speed: float = 300.0
@export var action_interval: float = 1.5

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"attack03", &"hurt", &"death"]
const LAYER_ENEMY_HURTBOX: int = 1 << 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 0
var is_dead: bool = false
var current_action_animation: StringName = &""
var action_timer: Timer
var leader: Node2D
var attack_cycle: int = 0
var dash_target_pos: Vector2 = Vector2.ZERO
var is_dashing: bool = false

func _ready() -> void:
	if not is_in_group("companion"): add_to_group("companion")
	if not is_in_group("player"): add_to_group("player")
	health = max_health
	leader = get_tree().get_first_node_in_group("player") as Node2D
	collision_layer = 0; collision_mask = 0
	_configure_animation_loops()
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")
	action_timer = Timer.new(); action_timer.name = "ActionTimer"
	action_timer.wait_time = action_interval; action_timer.one_shot = false
	action_timer.timeout.connect(_on_action_timer_timeout)
	add_child(action_timer); action_timer.start()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO; move_and_slide(); return
	if is_dashing:
		var to_dash := dash_target_pos - global_position
		if to_dash.length() > 5.0:
			velocity = to_dash.normalized() * dash_speed
		else:
			velocity = Vector2.ZERO; is_dashing = false
		move_and_slide(); return
	if _is_action_locked():
		velocity = Vector2.ZERO; move_and_slide(); return
	if leader == null or not is_instance_valid(leader):
		leader = get_tree().get_first_node_in_group("player") as Node2D
	if leader == null:
		velocity = Vector2.ZERO; _play_animation(&"idle"); move_and_slide(); return
	var to_leader := leader.global_position - global_position
	if to_leader.length() > follow_distance:
		var dir := to_leader.normalized()
		velocity = dir * move_speed
		if dir.x != 0.0: animated_sprite.flip_h = dir.x < 0.0
		_play_animation(&"walk")
	else:
		velocity = Vector2.ZERO; _play_animation(&"idle")
	move_and_slide()

func _on_action_timer_timeout() -> void:
	if is_dead or _is_action_locked(): return
	var enemy := _find_nearest_enemy()
	if enemy == null: return
	_face(enemy)
	var dist := global_position.distance_to(enemy.global_position)
	match attack_cycle % 3:
		0:  # Quick slash
			if dist <= attack_range:
				_play_action(&"attack01")
				_damage_enemy(enemy, attack01_damage)
		1:  # Heavy combo
			if dist <= attack_range:
				_play_action(&"attack02")
				_damage_enemy(enemy, attack02_damage)
		2:  # Dash attack — lunge toward enemy
			if dist <= dash_range:
				_play_action(&"attack03")
				dash_target_pos = enemy.global_position
				is_dashing = true
				_damage_enemy(enemy, attack03_damage)
	attack_cycle += 1

func _damage_enemy(enemy: Node2D, dmg: int) -> void:
	if enemy.has_method("take_damage"): enemy.call("take_damage", dmg)

func _find_nearest_enemy() -> Node2D:
	return CombatUtils.find_enemy_near_player(global_position, get_tree(), dash_range)

func _face(t: Node2D) -> void:
	animated_sprite.flip_h = t.global_position.x < global_position.x

func take_damage(amount: int = 1) -> void:
	if is_dead: return
	health = maxi(health - maxi(amount, 0), 0)
	if health <= 0: _trigger_death(); return
	if _has_animation(&"hurt"): _play_action(&"hurt")

func receive_heal(amount: int) -> void:
	if is_dead: return; health = mini(health + amount, max_health)

func get_contact_damage() -> int: return 0

func _trigger_death() -> void:
	if is_dead: return; is_dead = true; velocity = Vector2.ZERO
	if action_timer: action_timer.stop()
	_play_action(&"death")

func _play_action(a: StringName) -> void:
	if not _has_animation(a): return
	current_action_animation = a; velocity = Vector2.ZERO; _play_animation(a)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death": animated_sprite.pause(); return
	if animated_sprite.animation == current_action_animation:
		current_action_animation = &""; is_dashing = false

func _is_action_locked() -> bool: return current_action_animation != &""

func _play_animation(a: StringName) -> void:
	if not _has_animation(a): return
	if animated_sprite.animation != a or not animated_sprite.is_playing(): animated_sprite.play(a)

func _configure_animation_loops() -> void:
	var f := animated_sprite.sprite_frames; if f == null: return
	for a in MOVEMENT_ANIMATIONS:
		if f.has_animation(a): f.set_animation_loop(a, true)
	for a in ACTION_ANIMATIONS:
		if f.has_animation(a): f.set_animation_loop(a, false)

func _has_animation(a: StringName) -> bool:
	var f := animated_sprite.sprite_frames; return f != null and f.has_animation(a)
