extends CharacterBody2D

const SPEED = 150.0

@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D

func _ready():
	_setup_inputs()

func _setup_inputs():
	var mapping = {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D
	}
	
	for action in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventKey.new()
			event.physical_keycode = mapping[action]
			InputMap.action_add_event(action, event)

func _physics_process(_delta):
	var direction = Vector2.ZERO
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")
	
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * SPEED
		if animation_player.has_animation("run"):
			animation_player.play("run")
		
		# Flip sprite based on horizontal direction
		if direction.x != 0:
			sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

	move_and_slide()
