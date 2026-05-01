extends CharacterBody2D

## ── Enemy Skeleton Archer ────────────────────────────────────────────────────
@export var move_speed: float = 55.0
@export var target_group: StringName = &"player"
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var arrow_damage: int = 1
@export var arrow_speed: float = 200.0
@export var attack_range: float = 100.0
@export var preferred_distance: float = 70.0
@export var shoot_interval: float = 2.5
@export var hurtbox_radius: float = 12.0
@export var contact_hitbox_radius: float = 10.0

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"hurt", &"death"]
const LAYER_PLAYER_HURTBOX: int = 1 << 1
const LAYER_PLAYER_HITBOX:  int = 1 << 2
const LAYER_ENEMY_HURTBOX:  int = 1 << 3
const LAYER_ENEMY_HITBOX:   int = 1 << 4
const ENEMY_ARROW_SCENE: PackedScene = preload("res://Scenes/EnemyArrow.tscn")
const ExpGemScript = preload("res://Scripts/ExpGem.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D
var current_action_animation: StringName = &""
var is_dead: bool = false
var health: int = 0
var hurtbox: Area2D
var contact_hitbox: Area2D
var shoot_timer: Timer

# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")

	# Ghost body — no body‑to‑body physics
	collision_layer = 0
	collision_mask  = 0

	health = max_health
	_setup_combat_areas()
	target = _find_nearest_target()

	_configure_animation_loops()
	animated_sprite.speed_scale = 1.5
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")

	# Shoot timer
	shoot_timer = Timer.new()
	shoot_timer.name = "ShootTimer"
	shoot_timer.wait_time = shoot_interval
	shoot_timer.one_shot = false
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)
	shoot_timer.start()

# ─── Physics ──────────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		target = _find_nearest_target()
		if target == null:
			velocity = Vector2.ZERO
			_play_animation(&"idle")
			move_and_slide()
			return

	var to_target := target.global_position - global_position
	var dist := to_target.length()

	# Try to stay at preferred_distance — move closer if too far, back off if too close
	if dist > preferred_distance + 10.0:
		var direction := to_target.normalized()
		velocity = direction * move_speed
		if direction.x != 0.0:
			animated_sprite.flip_h = direction.x < 0.0
		_play_animation(&"walk")
	elif dist < preferred_distance - 10.0:
		# Back away
		var direction := -to_target.normalized()
		velocity = direction * move_speed * 0.6
		if to_target.x != 0.0:
			animated_sprite.flip_h = to_target.x < 0.0
		_play_animation(&"walk")
	else:
		velocity = Vector2.ZERO
		if to_target.x != 0.0:
			animated_sprite.flip_h = to_target.x < 0.0
		_play_animation(&"idle")

	move_and_slide()

# ─── Shooting ─────────────────────────────────────────────────────────────────

func _on_shoot_timer_timeout() -> void:
	if is_dead or _is_action_locked():
		return
	if target == null or not is_instance_valid(target):
		target = _find_nearest_target()
		return

	var dist := global_position.distance_to(target.global_position)
	if dist > attack_range:
		return

	_shoot_at_target()

func _shoot_at_target() -> void:
	# Face the target
	var to_target := target.global_position - global_position
	if to_target.x != 0.0:
		animated_sprite.flip_h = to_target.x < 0.0

	# Play attack animation
	_play_action(&"attack01")

	# Use direct normalized direction for accurate targeting
	var dir := to_target.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT

	# Spawn enemy arrow
	if ENEMY_ARROW_SCENE == null:
		return
	var arrow = ENEMY_ARROW_SCENE.instantiate() as Area2D
	arrow.direction = dir  # Set direction BEFORE adding to tree (rotation is set in _ready)
	get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector2(0, 4) + dir * 10
	if arrow.get("speed") != null:
		arrow.speed = arrow_speed
	if arrow.get("damage") != null:
		arrow.damage = arrow_damage

# ─── Target finding ──────────────────────────────────────────────────────────

func _find_nearest_target() -> Node2D:
	return CombatUtils.find_priority_target(global_position, get_tree())

# ─── Combat areas ─────────────────────────────────────────────────────────────

func _setup_combat_areas() -> void:
	hurtbox = _get_or_create_area("Hurtbox")
	hurtbox.position = Vector2(0, 4)
	hurtbox.monitorable = true
	hurtbox.monitoring = true
	hurtbox.collision_layer = LAYER_ENEMY_HURTBOX
	hurtbox.collision_mask = LAYER_PLAYER_HITBOX
	if not hurtbox.is_in_group("enemy_hurtbox"):
		hurtbox.add_to_group("enemy_hurtbox")
	_configure_circle_shape(hurtbox, hurtbox_radius)

	contact_hitbox = _get_or_create_area("ContactHitbox")
	contact_hitbox.position = Vector2(0, 4)
	contact_hitbox.monitorable = true
	contact_hitbox.monitoring = true
	contact_hitbox.collision_layer = LAYER_ENEMY_HITBOX
	contact_hitbox.collision_mask = LAYER_PLAYER_HURTBOX
	if not contact_hitbox.is_in_group("enemy_hitbox"):
		contact_hitbox.add_to_group("enemy_hitbox")
	_configure_circle_shape(contact_hitbox, contact_hitbox_radius)

# ─── Damage ───────────────────────────────────────────────────────────────────

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	var applied := maxi(amount, 0)
	if applied <= 0:
		return
	health = maxi(health - applied, 0)
	if health <= 0:
		play_death()
	else:
		play_hurt()

func get_contact_damage() -> int:
	return contact_damage

func play_hurt() -> void:
	_play_action(&"hurt")

func play_death() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if shoot_timer != null:
		shoot_timer.stop()
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if contact_hitbox != null:
		contact_hitbox.set_deferred("monitoring", false)
		contact_hitbox.set_deferred("monitorable", false)
	_play_action(&"death")

# ─── Node helpers ─────────────────────────────────────────────────────────────

func _get_or_create_area(node_name: String) -> Area2D:
	var area := get_node_or_null(node_name) as Area2D
	if area != null:
		return area
	area = Area2D.new()
	area.name = node_name
	add_child(area)
	return area

func _configure_circle_shape(area: Area2D, radius: float) -> void:
	var collision_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		area.add_child(collision_shape)
	var circle := collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision_shape.shape = circle
	circle.radius = max(radius, 1.0)

# ─── Animation helpers ───────────────────────────────────────────────────────

func _play_action(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	current_action_animation = animation_name
	velocity = Vector2.ZERO
	_play_animation(animation_name)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death":
		ExpGemScript.drop_gems(self, 1, randi_range(1, 2))  # Medium tier, 1-2 gems
		queue_free()
		return
	if animated_sprite.animation == current_action_animation:
		current_action_animation = &""

func _is_action_locked() -> bool:
	return current_action_animation != &""

func _play_animation(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _configure_animation_loops() -> void:
	var frames := animated_sprite.sprite_frames
	if frames == null:
		return
	for anim in MOVEMENT_ANIMATIONS:
		if frames.has_animation(anim):
			frames.set_animation_loop(anim, true)
	for anim in ACTION_ANIMATIONS:
		if frames.has_animation(anim):
			frames.set_animation_loop(anim, false)

func _has_animation(animation_name: StringName) -> bool:
	var frames := animated_sprite.sprite_frames
	return frames != null and frames.has_animation(animation_name)
