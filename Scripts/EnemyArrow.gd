extends Area2D

@export var speed: float = 250.0
@export var damage: int = 1
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Destroy after lifetime
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	# Damage player or companion hurtboxes
	if area.is_in_group("player_hurtbox"):
		var target = area.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(damage)
			queue_free()
