extends CharacterBody2D

@export var move_speed: float = 70.0
@export var target_group: StringName = &"player"
@export var collide_with_bodies: bool = false
@export var max_health: int = 1
@export var contact_damage: int = 1
@export var hurtbox_radius: float = 12.0
@export var contact_hitbox_radius: float = 10.0

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"hurt", &"death"]
const LAYER_PLAYER_HURTBOX: int = 1 << 1
const LAYER_PLAYER_HITBOX: int = 1 << 2
const LAYER_ENEMY_HURTBOX: int = 1 << 3
const LAYER_ENEMY_HITBOX: int = 1 << 4
const ExpGemScript = preload("res://Scripts/ExpGem.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D
var current_action_animation: StringName = &""
var is_dead: bool = false
var health: int = 0
var hurtbox: Area2D
var contact_hitbox: Area2D

func _ready() -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")

	if not collide_with_bodies:
		collision_layer = 0
		collision_mask = 0

	health = max_health
	_setup_combat_areas()
	target = get_tree().get_first_node_in_group(target_group) as Node2D
	_configure_animation_loops()
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")

func _physics_process(_delta: float) -> void:
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(target_group) as Node2D
		if target == null:
			velocity = Vector2.ZERO
			_play_animation(&"idle")
			move_and_slide()
			return

	var to_target := target.global_position - global_position
	if to_target.length_squared() > 4.0:
		var direction := to_target.normalized()
		velocity = direction * move_speed
		if direction.x != 0.0:
			animated_sprite.flip_h = direction.x < 0.0
		_play_animation(&"walk")
	else:
		velocity = Vector2.ZERO
		_play_animation(&"idle")

	move_and_slide()

func play_attack(use_second_attack: bool = false) -> void:
	_trigger_action(&"attack02" if use_second_attack else &"attack01")

func play_hurt() -> void:
	_trigger_action(&"hurt")

func play_death() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	# Use set_deferred because this may be called from inside a physics
	# signal (area_entered / take_damage chain), where the physics server
	# is locked and direct property writes to monitorable/monitoring crash.
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if contact_hitbox != null:
		contact_hitbox.set_deferred("monitoring", false)
		contact_hitbox.set_deferred("monitorable", false)

	_trigger_action(&"death")

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	var applied_damage: int = maxi(amount, 0)
	if applied_damage <= 0:
		return

	health = maxi(health - applied_damage, 0)
	if health <= 0:
		play_death()
	else:
		play_hurt()

func get_contact_damage() -> int:
	return contact_damage

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

func _trigger_action(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	current_action_animation = animation_name
	velocity = Vector2.ZERO
	_play_animation(animation_name)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death":
		ExpGemScript.drop_gems(self, 0, 1)  # Weak tier, 1 gem
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

	for animation_name in MOVEMENT_ANIMATIONS:
		if frames.has_animation(animation_name):
			frames.set_animation_loop(animation_name, true)

	for animation_name in ACTION_ANIMATIONS:
		if frames.has_animation(animation_name):
			frames.set_animation_loop(animation_name, false)

func _has_animation(animation_name: StringName) -> bool:
	var frames := animated_sprite.sprite_frames
	return frames != null and frames.has_animation(animation_name)
