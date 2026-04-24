extends Area2D

@export var exp_amount: int = 1
@export var max_speed: float = 400.0
@export var accel: float = 800.0

var target: Node2D = null
var current_speed: float = 0.0

func _ready() -> void:
	if not is_in_group("exp_gem"):
		add_to_group("exp_gem")

func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		current_speed += accel * delta
		current_speed = min(current_speed, max_speed)
		position += direction * current_speed * delta

func fly_to(player_node: Node2D) -> void:
	target = player_node

func collect() -> int:
	queue_free()
	return exp_amount
