extends Area2D

@export var speed: float = 250.0
@export var damage: int = 1
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	z_index = 1
	# Destroy after lifetime
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	
	var launch_audio = AudioStreamPlayer2D.new()
	launch_audio.stream = preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Launch.wav")
	launch_audio.bus = "SFX"
	add_child(launch_audio)
	launch_audio.play()

	# Set rotation to match direction for accurate visual
	rotation = direction.angle()

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Use normalized direction for consistent speed at all angles
	var move_dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	position += move_dir * speed * delta

func _on_area_entered(area: Area2D) -> void:
	# Damage player or companion hurtboxes
	if area.is_in_group("player_hurtbox"):
		var target = area.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(damage)
			queue_free()
