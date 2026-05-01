extends Area2D

@export var speed: float = 350.0
@export var damage: int = 1
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	z_index = 1
	# Start a timer to destroy the arrow if it doesn't hit anything
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
	
	# Connect collision signal
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			enemy.take_damage(damage)
			queue_free() # Destroy arrow on hit
