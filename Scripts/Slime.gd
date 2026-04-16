extends CharacterBody2D

@export var move_speed: float = 70.0
@export var target_group: StringName = &"player"

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"hurt", &"death"]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D
var current_action_animation: StringName = &""
var is_dead: bool = false

func _ready() -> void:
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
	_trigger_action(&"death")

func _trigger_action(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	current_action_animation = animation_name
	velocity = Vector2.ZERO
	_play_animation(animation_name)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death":
		animated_sprite.pause()
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
