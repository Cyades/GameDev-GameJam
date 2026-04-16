extends CharacterBody2D

@export var walk_speed: float = 150.0
@export var sprint_speed_multiplier: float = 1.6

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"sprint"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"attack03", &"hurt", &"death"]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing_sign: float = 1.0
var current_action_animation: StringName = &""
var is_dead: bool = false

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	_setup_inputs()
	_configure_animation_loops()
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("die"):
		_trigger_death()
		return

	if is_dead or _is_action_locked():
		return

	if event.is_action_pressed("attack_1"):
		_trigger_action(&"attack01")
	elif event.is_action_pressed("attack_2"):
		_trigger_action(&"attack02")
	elif event.is_action_pressed("attack_3"):
		_trigger_action(&"attack03")
	elif event.is_action_pressed("hurt"):
		_trigger_action(&"hurt")

func _physics_process(_delta: float) -> void:
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		var is_sprinting := Input.is_action_pressed("sprint") and _has_animation(&"sprint")
		var speed := walk_speed * (sprint_speed_multiplier if is_sprinting else 1.0)
		velocity = direction * speed

		if direction.x != 0.0:
			facing_sign = sign(direction.x)
		animated_sprite.flip_h = facing_sign < 0.0
		_play_animation(&"sprint" if is_sprinting else &"walk")
	else:
		velocity = Vector2.ZERO
		_play_animation(&"idle")

	move_and_slide()

func _setup_inputs() -> void:
	var defaults := {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"sprint": KEY_SHIFT,
		"attack_1": KEY_J,
		"attack_2": KEY_K,
		"attack_3": KEY_L,
		"hurt": KEY_H,
		"die": KEY_X
	}

	for action_name in defaults.keys():
		_ensure_action(action_name, defaults[action_name])

func _ensure_action(action_name: StringName, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if not InputMap.action_get_events(action_name).is_empty():
		return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)

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

func _trigger_action(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	current_action_animation = animation_name
	velocity = Vector2.ZERO
	_play_animation(animation_name)

func _trigger_death() -> void:
	if is_dead:
		return
	is_dead = true
	_trigger_action(&"death")

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

func _has_animation(animation_name: StringName) -> bool:
	var frames := animated_sprite.sprite_frames
	return frames != null and frames.has_animation(animation_name)
